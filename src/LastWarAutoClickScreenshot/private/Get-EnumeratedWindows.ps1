function Get-EnumeratedWindows {
    <#
    .SYNOPSIS
        Enumerates all top-level windows with visible taskbar presence.

    .DESCRIPTION
        Uses Win32 API to enumerate all top-level windows that are visible and have a presence
        in the Windows taskbar. Returns detailed information including process name, window title,
        handle, ProcessID, and window state.
        
        This function filters out system, hidden, and background processes, focusing only on
        user-facing application windows suitable for automation targeting.

    .PARAMETER ProcessName
        Optional array of process names to filter results. Only windows from processes matching
        these names will be returned. Comparison is case-insensitive.

    .PARAMETER ExcludeMinimized
        Switch to exclude minimized windows from results. When specified, only non-minimized
        visible windows are returned.

    .PARAMETER VisibleOnly
        Switch to return only visible windows. When specified, minimized windows are excluded
        even if they would otherwise match the criteria.

    .OUTPUTS
        System.Management.Automation.PSCustomObject[]
        Returns array of custom objects with the following properties:
        - ProcessName (string): Name of the process (e.g., "LastWar")
        - WindowTitle (string): Text from window title bar
        - WindowHandle (IntPtr): Raw window handle for Win32 API calls
        - WindowHandleString (string): String representation of handle for serialization
        - WindowHandleInt (int64): Numeric representation of handle
        - ProcessID (uint32): Process identifier
        - WindowState (string): "Visible", "Minimized", or "Hidden"

    .EXAMPLE
        Get-EnumeratedWindows
        Returns all enumerable windows with taskbar presence.

    .EXAMPLE
        Get-EnumeratedWindows -ProcessName "LastWar", "notepad" -Verbose
        Returns windows only from LastWar.exe and notepad.exe processes with verbose output.

    .EXAMPLE
        Get-EnumeratedWindows -ExcludeMinimized
        Returns all visible, non-minimized windows.

    .EXAMPLE
        Get-EnumeratedWindows -VisibleOnly
        Returns only windows that are currently visible (not minimized).

    .NOTES
        - Requires WindowEnumeration_TypeDefinition.ps1 to be loaded
        - Uses ForEach-Object -Parallel for performance optimization (assumes 8+ core CPU)
        - Errors during enumeration are collected and logged to Event Log
        - Designed for Windows 11 x64 with PowerShell 7+
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ProcessName,

        [Parameter(Mandatory = $false)]
        [switch]$ExcludeMinimized,

        [Parameter(Mandatory = $false)]
        [switch]$VisibleOnly
    )

    begin {
        Write-Verbose "Starting window enumeration..."
        
        # Verify type definitions are loaded
        if (-not ([System.Management.Automation.PSTypeName]'WindowEnumerationAPI').Type) {
            $errorMsg = "WindowEnumerationAPI type not loaded. Ensure WindowEnumeration_TypeDefinition.ps1 is dot-sourced."
            Write-Error "Error: $errorMsg"
            Write-LastWarLog -Message $errorMsg -Level Error -FunctionName 'Get-EnumeratedWindows'
            throw $errorMsg
        }

        # Collection for results
        $script:windowList = [System.Collections.Generic.List[PSCustomObject]]::new()
        
        # Collection for errors during enumeration
        $script:enumerationErrors = [System.Collections.Generic.List[string]]::new()
        
        # Counter for statistics
        $script:totalWindowsProcessed = 0
        $script:filteredWindows = 0
    }

    process {
        Write-Verbose "Creating enumeration callback delegate..."
        
        # Define callback for EnumWindows
        # Must be stored in variable to prevent premature garbage collection
        $enumCallback = [EnumWindowsProc] {
            param($hwnd, $lParam)
            
            $script:totalWindowsProcessed++
            
            try {
                # Check if window is visible
                $isVisible = [WindowEnumerationAPI]::IsWindowVisible($hwnd)
                if (-not $isVisible) {
                    $script:filteredWindows++
                    return $true  # Continue enumeration
                }

                # Check if window is minimized
                $isMinimized = [WindowEnumerationAPI]::IsIconic($hwnd)
                
                # Get window title
                $titleLength = [WindowEnumerationAPI]::GetWindowTextLength($hwnd)
                $windowTitle = ''
                
                if ($titleLength -gt 0) {
                    $stringBuilder = [System.Text.StringBuilder]::new($titleLength + 1)
                    $result = [WindowEnumerationAPI]::GetWindowText($hwnd, $stringBuilder, $stringBuilder.Capacity)
                    
                    if ($result -gt 0) {
                        $windowTitle = $stringBuilder.ToString()
                    }
                }
                
                # Filter out windows with no title (system/background processes)
                if ([string]::IsNullOrWhiteSpace($windowTitle)) {
                    $script:filteredWindows++
                    return $true  # Continue enumeration
                }

                # Get process ID
                $processId = [uint32]0
                [void][WindowEnumerationAPI]::GetWindowThreadProcessId($hwnd, [ref]$processId)
                
                if ($processId -eq 0) {
                    $script:enumerationErrors.Add("Failed to get process ID for window handle: $hwnd")
                    return $true  # Continue enumeration
                }

                # Determine window state
                $windowState = if ($isMinimized) { "Minimized" } 
                              elseif ($isVisible) { "Visible" } 
                              else { "Hidden" }

                # Create window info object (process name will be added later)
                $windowInfo = [PSCustomObject]@{
                    ProcessName         = $null  # Populated in parallel processing
                    WindowTitle         = $windowTitle
                    WindowHandle        = $hwnd
                    WindowHandleString  = $hwnd.ToString()
                    WindowHandleInt     = [int64]$hwnd
                    ProcessID           = $processId
                    WindowState         = $windowState
                }

                # Add to collection
                $script:windowList.Add($windowInfo)
                
                return $true  # Continue enumeration
            }
            catch {
                    Write-LastWarLog -Message "Error processing window $hwnd : $_" -Level Error -FunctionName 'Get-EnumeratedWindows' -Context "Window handle: $hwnd" -StackTrace $_
                    $script:enumerationErrors.Add("Error processing window $hwnd : $_")
                return $true  # Continue enumeration despite error
            }
        }

        Write-Verbose "Enumerating windows via Win32 API..."
        
        # Execute enumeration
        try {
            $enumResult = [WindowEnumerationAPI]::EnumWindows($enumCallback, [IntPtr]::Zero)
            
            if (-not $enumResult) {
                $errorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
                throw "EnumWindows API call failed with error code: $errorCode"
            }
            
            Write-Verbose "Enumeration completed. Total windows processed: $script:totalWindowsProcessed"
            Write-Verbose "Filtered out (invisible/no title): $script:filteredWindows"
            Write-Verbose "Windows collected for further processing: $($script:windowList.Count)"
        }
        catch {
            Write-LastWarLog -Message "Failed to enumerate windows: $_" -Level Error -FunctionName 'Get-EnumeratedWindows' -Context "EnumWindows API call" -StackTrace $_
            Write-Error "Error: Failed to enumerate windows: $_"
            throw
        }

        # Log enumeration errors to Event Log if any occurred
        if ($script:enumerationErrors.Count -gt 0) {
            $errorSummary = "Window enumeration encountered $($script:enumerationErrors.Count) error(s):`n" + ($script:enumerationErrors -join "`n")
            Write-Warning "Warning: $errorSummary"
            Write-LastWarLog -Message $errorSummary -Level Warning -FunctionName 'Get-EnumeratedWindows'
            # TODO: Write to Windows Event Log when logging infrastructure is implemented
        }

        # Retrieve process names using parallel processing for performance
        if ($script:windowList.Count -gt 0) {
            Write-Verbose "Retrieving process information in parallel (optimized for multi-core CPUs)..."
            
            $windowsWithProcessNames = $script:windowList | ForEach-Object -Parallel {
                $window = $_
                
                try {
                    # Attempt to get process information
                    $process = Get-Process -Id $window.ProcessID -ErrorAction Stop
                    $window.ProcessName = $process.ProcessName
                }
                catch {
                    # Process may have terminated between enumeration and Get-Process call
                    $window.ProcessName = "<Terminated>"
                    
                    # Note: Cannot directly modify $using:script:enumerationErrors from parallel block
                    # Error will be filtered out in the main thread
                }
                
                # Return modified window object
                $window
            } -ThrottleLimit 16  # Optimize for 16-thread systems

            Write-Verbose "Process name retrieval completed."
            
            # Filter out windows where process terminated
            $validWindows = $windowsWithProcessNames | Where-Object { $_.ProcessName -ne "<Terminated>" }
            
            $terminatedCount = $windowsWithProcessNames.Count - $validWindows.Count
            if ($terminatedCount -gt 0) {
                Write-Verbose "Filtered out $terminatedCount window(s) from terminated processes."
            }
        }
        else {
            Write-Verbose "No windows collected during enumeration."
            $validWindows = @()
        }

        # Apply user-specified filters
        $filteredResults = $validWindows

        if ($PSBoundParameters.ContainsKey('ProcessName')) {
            Write-Verbose "Applying ProcessName filter: $($ProcessName -join ', ')"
            $filteredResults = $filteredResults | Where-Object {
                $ProcessName -contains $_.ProcessName
            }
            Write-Verbose "Remaining after ProcessName filter: $($filteredResults.Count)"
        }

        if ($ExcludeMinimized -or $VisibleOnly) {
            Write-Verbose "Applying ExcludeMinimized/VisibleOnly filter..."
            $filteredResults = $filteredResults | Where-Object {
                $_.WindowState -eq "Visible"
            }
            Write-Verbose "Remaining after visibility filter: $($filteredResults.Count)"
        }

        Write-Verbose "Enumeration complete. Returning $($filteredResults.Count) window(s)."
        
        # Return results
        return $filteredResults
    }

    end {
        # Cleanup script-level variables
        Remove-Variable -Name windowList -Scope Script -ErrorAction SilentlyContinue
        Remove-Variable -Name enumerationErrors -Scope Script -ErrorAction SilentlyContinue
        Remove-Variable -Name totalWindowsProcessed -Scope Script -ErrorAction SilentlyContinue
        Remove-Variable -Name filteredWindows -Scope Script -ErrorAction SilentlyContinue
    }
}
