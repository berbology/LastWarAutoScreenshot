
<#
.SYNOPSIS
    Displays an interactive console menu for selecting a target window from enumerated windows.

.DESCRIPTION
    Presents an interactive menu allowing users to select a window from a list of enumerated windows.
    Supports multiple selection methods (direct number entry or arrow key navigation), sorting options,
    and view modes. Can accept window objects via the WindowList parameter (direct argument or pipeline),
    or enumerate windows internally with optional filters.

.PARAMETER WindowList
    Array of window objects from Get-EnumeratedWindows. Accepts pipeline input or direct parameter.

.PARAMETER ProcessName
    Optional process name filter when enumerating windows internally (not used with pipeline input).

.PARAMETER ExcludeMinimized
    Exclude minimized windows when enumerating internally (not used with pipeline input).

.PARAMETER VisibleOnly
    Only show visible windows when enumerating internally (not used with pipeline input).

.PARAMETER SortBy
    Initial sort column. Valid values: 'ProcessName', 'WindowTitle', 'WindowState'. Default: 'WindowTitle'.

.PARAMETER DetailedView
    Start in detailed view mode showing WindowHandle values.

.OUTPUTS
    PSCustomObject
    Returns the selected window object with properties: ProcessName, WindowTitle, WindowHandle, 
    WindowHandleString, WindowHandleInt64, ProcessID, WindowState. Returns $null if user exits without selection.


.EXAMPLE
    Get-EnumeratedWindows | Select-TargetWindowFromMenu
    
    Displays interactive menu with all enumerated windows, allowing user to select a target (pipeline input).

.EXAMPLE
    Select-TargetWindowFromMenu -WindowList (Get-EnumeratedWindows)
    
    Displays menu with all enumerated windows, allowing user to select a target (direct parameter).

.EXAMPLE
    Get-EnumeratedWindows -ProcessName 'LastWar' | Select-TargetWindowFromMenu -DetailedView
    
    Displays menu with LastWar windows in detailed view mode (pipeline input).

.EXAMPLE
    Select-TargetWindowFromMenu -ProcessName 'chrome' -VisibleOnly
    
    Enumerates Chrome windows internally and displays selection menu.

.NOTES
    Interactive Commands:
    - Type number + Enter: Select window by number
    - ↑/↓ Arrow keys: Activate scroll mode and navigate list
    - Enter (in scroll mode): Select currently highlighted window
    - P: Toggle sort by Process name (ascending/descending)
    - A: Toggle sort by Application name (ascending/descending)
    - M: Toggle sort by Minimised status (ascending/descending)
    - D: Toggle between Simple and Detailed view
    - R: Refresh window list (only works with internal enumeration)
    - H: Show/hide help
    - X: Exit without selection
    
    Display Features:
    - Active window marked with * in Active column
    - Scroll mode shows selected row in blue text
    - Sort indicators (↑/↓) shown in column headers
    - Underlined key letters in column headers
    - Help displayed below window list
#>


function Select-TargetWindowFromMenu {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [PSCustomObject[]]$WindowList,

        [Parameter()]
        [string]$ProcessName,

        [Parameter()]
        [switch]$ExcludeMinimized,

        [Parameter()]
        [switch]$VisibleOnly,

        [Parameter()]
        [ValidateSet('ProcessName', 'WindowTitle', 'WindowState')]
        [string]$SortBy = 'WindowTitle',

        [Parameter()]
        [switch]$DetailedView
    )


    begin {
        # Always clear script:windows to prevent cross-test accumulation
        $script:windows = @()
        Write-Verbose "Starting Select-TargetWindowFromMenu"
        
        # ANSI escape codes
        $script:AnsiBlue = "`e[34m"
        $script:AnsiReset = "`e[0m"
        $script:AnsiUnderline = "`e[4m"
        $script:AnsiNoUnderline = "`e[24m"
        
        # State variables (use local variable for windows)
        $windows = @()  # Always initialize as array for each invocation
        $script:useInternalEnumeration = $false
        $script:enumerationParams = @{}
        $script:receivedInput = $false
        $script:calledFromPipeline = $MyInvocation.ExpectingInput
        
        # Menu state
        $script:currentSort = $SortBy
        $script:sortAscending = $true
        $script:detailedMode = $DetailedView.IsPresent
        $script:scrollMode = $false
        $script:selectedIndex = 0
        $script:showHelp = $false
        
        # Load type definitions if not already loaded
        if (-not ([System.Management.Automation.PSTypeName]'WindowEnumerationAPI').Type) {
            . "$PSScriptRoot\WindowEnumeration_TypeDefinition.ps1"
        }
        
        # Check if we should use internal enumeration
        if (-not $PSBoundParameters.ContainsKey('WindowList')) {
            $script:useInternalEnumeration = $true
            
            # Build enumeration parameters
            if ($PSBoundParameters.ContainsKey('ProcessName')) {
                $script:enumerationParams['ProcessName'] = $ProcessName
            }
            if ($ExcludeMinimized.IsPresent) {
                $script:enumerationParams['ExcludeMinimized'] = $true
            }
            if ($VisibleOnly.IsPresent) {
                $script:enumerationParams['VisibleOnly'] = $true
            }
            
            Write-Verbose "Using internal enumeration with parameters: $($script:enumerationParams | ConvertTo-Json -Compress)"
        }
    }

    process {
        if ($WindowList) {
            # Always treat as array, overwrite for each pipeline call to avoid accumulation
            $windows = @($WindowList)
            $script:receivedInput = $true
            Write-Verbose "Received $($windows.Count) window(s) from pipeline or parameter (overwriting previous)"
        }
    }

    end {
        # If called from pipeline and no input was received, return $null immediately (fix for empty pipeline)
        if ($script:calledFromPipeline -and -not $script:receivedInput) {
            Write-Verbose "No pipeline input received (pipeline context), returning null."
            return $null
        }
        # If using internal enumeration, get windows now
        if ($script:useInternalEnumeration) {
            Write-Verbose "Enumerating windows internally"
            $windows = Get-EnumeratedWindows @script:enumerationParams
        }
        
        # Robustly check for empty or null windows (handle all cases)
        $windowsCount = 0
        if ($null -eq $windows) {
            $windowsCount = 0
        } elseif ($windows -is [System.Collections.IEnumerable] -and -not ($windows -is [string])) {
            $windowsCount = @($windows).Count
        } else {
            $windowsCount = 1
        }
        if ($windowsCount -eq 0) {
            Write-Host "`n═══════════════════════════════════════════════════════════════════════════════"
            Write-Host "  No windows found matching the specified criteria."
            Write-Host "═══════════════════════════════════════════════════════════════════════════════`n"
            Write-Verbose "No windows to display, exiting"
            return $null
        }
        
        Write-Verbose "Displaying menu with $($windows.Count) window(s)"
        Write-Host "DEBUG: Windows passed to Show-MenuLoop: $($windows.Count) - $($windows | ForEach-Object { $_.ProcessName + ':' + $_.WindowTitle + ':' + $_.WindowState })"
        # Main menu loop, pass windows as parameter
        $selectedWindow = Show-MenuLoop -Windows $windows
        if ($selectedWindow) {
            Write-Verbose "User selected window: ProcessName=$($selectedWindow.ProcessName), WindowTitle=$($selectedWindow.WindowTitle)"
        }
        else {
            Write-Verbose "User cancelled selection"
        }
        return $selectedWindow
    }
}

function Show-MenuLoop {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Windows
    )
    # Guard: If no windows, exit immediately (extra safety for test environments)
    $windowsCount = 0
    if ($null -eq $Windows) {
        $windowsCount = 0
    } elseif ($Windows -is [System.Collections.IEnumerable] -and -not ($Windows -is [string])) {
        $windowsCount = @($Windows).Count
    } else {
        $windowsCount = 1
    }
    if ($windowsCount -eq 0) {
        Write-Verbose "Show-MenuLoop: No windows to display, exiting."
        return $null
    }
    while ($true) {
        # Get active window handle
        $activeWindowHandle = [WindowEnumerationAPI]::GetForegroundWindow()
        # Sort windows
        $sortedWindows = Get-SortedWindows -Windows $Windows
        # Display menu
        Show-Menu -Windows $sortedWindows -ActiveWindowHandle $activeWindowHandle
        # Get user input
        $selection = Get-UserSelection
        Write-Verbose "User input: Command=$($selection.Command), Value=$($selection.Value)"
        # Process command
        switch ($selection.Command) {
            'Select' {
                $index = $selection.Value - 1
                if ($index -ge 0 -and $index -lt $sortedWindows.Count) {
                    $selectedWindow = $sortedWindows[$index]
                    # Ensure WindowHandleInt64 property is set for display
                    if (-not $selectedWindow.PSObject.Properties['WindowHandleInt64']) {
                        $selectedWindow | Add-Member -MemberType NoteProperty -Name WindowHandleInt64 -Value ([int64]$selectedWindow.WindowHandle) -Force
                    }
                    # Validate window still exists
                    if (Test-WindowExists -WindowHandle $selectedWindow.WindowHandle) {
                        return $selectedWindow
                    }
                    else {
                        Write-Host "`n$($script:AnsiReset)Error: Selected window has closed. Please select another window.`n" -ForegroundColor Red
                        Start-Sleep -Seconds 2
                    }
                }
                else {
                    Write-Host "`n$($script:AnsiReset)Error: Invalid selection '$($selection.Value)'. Please enter a number between 1 and $($sortedWindows.Count).`n" -ForegroundColor Red
                    Start-Sleep -Seconds 2
                }
            }
            'Exit' {
                Write-Host "`n═══════════════════════════════════════════════════════════════════════════════"
                Write-Host "  Exiting..."
                Write-Host "═══════════════════════════════════════════════════════════════════════════════`n"
                return $null
            }
            'ToggleDetail' {
                $script:detailedMode = -not $script:detailedMode
                Write-Verbose "Toggled detailed view: $($script:detailedMode)"
            }
            'ToggleHelp' {
                $script:showHelp = -not $script:showHelp
                Write-Verbose "Toggled help display: $($script:showHelp)"
            }
            'Refresh' {
                if ($script:useInternalEnumeration) {
                    Write-Verbose "Refreshing window list"
                    $refreshed = Get-EnumeratedWindows @script:enumerationParams
                    $script:scrollMode = $false
                    $script:selectedIndex = 0
                    if (-not $refreshed -or $refreshed.Count -eq 0) {
                        Write-Host "`n═══════════════════════════════════════════════════════════════════════════════"
                        Write-Host "  No windows found after refresh."
                        Write-Host "═══════════════════════════════════════════════════════════════════════════════`n"
                        return $null
                    }
                    $Windows = $refreshed
                    continue
                }
                else {
                    Write-Host "`n$($script:AnsiReset)Cannot refresh piped input. Re-run Get-EnumeratedWindows | Select-TargetWindowFromMenu`n" -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                }
            }
            'SortProcess' {
                if ($script:currentSort -eq 'ProcessName') {
                    $script:sortAscending = -not $script:sortAscending
                    Write-Verbose "Toggled ProcessName sort direction: Ascending=$($script:sortAscending)"
                }
                else {
                    $script:currentSort = 'ProcessName'
                    $script:sortAscending = $true
                    Write-Verbose "Changed sort to ProcessName ascending"
                }
            }
            'SortApplication' {
                if ($script:currentSort -eq 'WindowTitle') {
                    $script:sortAscending = -not $script:sortAscending
                    Write-Verbose "Toggled WindowTitle sort direction: Ascending=$($script:sortAscending)"
                }
                else {
                    $script:currentSort = 'WindowTitle'
                    $script:sortAscending = $true
                    Write-Verbose "Changed sort to WindowTitle ascending"
                }
            }
            'SortMinimised' {
                if ($script:currentSort -eq 'WindowState') {
                    $script:sortAscending = -not $script:sortAscending
                    Write-Verbose "Toggled WindowState sort direction: Ascending=$($script:sortAscending)"
                }
                else {
                    $script:currentSort = 'WindowState'
                    $script:sortAscending = $true
                    Write-Verbose "Changed sort to WindowState ascending"
                }
            }
            'ScrollUp' {
                if (-not $script:scrollMode) {
                    $script:scrollMode = $true
                    $script:selectedIndex = 0
                    Write-Verbose "Activated scroll mode at index 0"
                }
                elseif ($script:selectedIndex -gt 0) {
                    $script:selectedIndex--
                    Write-Verbose "Scrolled up to index $($script:selectedIndex)"
                }
            }
            'ScrollDown' {
                if (-not $script:scrollMode) {
                    $script:scrollMode = $true
                    $script:selectedIndex = 0
                    Write-Verbose "Activated scroll mode at index 0"
                }
                elseif ($script:selectedIndex -lt ($sortedWindows.Count - 1)) {
                    $script:selectedIndex++
                    Write-Verbose "Scrolled down to index $($script:selectedIndex)"
                }
            }
            'Empty' {
                # User pressed Enter with empty input - ignore
                Write-Verbose "Empty input ignored"
            }
            default {
                Write-Verbose "Unknown command: $($selection.Command)"
            }
        }
    }
}

function Get-SortedWindows {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Windows
    )
    $sorted = $Windows
    switch ($script:currentSort) {
        'ProcessName' {
            if ($script:sortAscending) {
                $sorted = $sorted | Sort-Object ProcessName
            }
            else {
                $sorted = $sorted | Sort-Object ProcessName -Descending
            }
        }
        'WindowTitle' {
            if ($script:sortAscending) {
                $sorted = $sorted | Sort-Object WindowTitle
            }
            else {
                $sorted = $sorted | Sort-Object WindowTitle -Descending
            }
        }
        'WindowState' {
            if ($script:sortAscending) {
                $sorted = $sorted | Sort-Object WindowState
            }
            else {
                $sorted = $sorted | Sort-Object WindowState -Descending
            }
        }
    }
    return $sorted
}

function Show-Menu {
    <#
    .SYNOPSIS
        Displays the menu with current windows and state.
    #>
    param(
        [PSCustomObject[]]$Windows,
        [IntPtr]$ActiveWindowHandle
    )
    
    # Clear screen
    Clear-Host
    
    # Display header
    $headerText = "  SELECT TARGET APPLICATION"
    if ($script:detailedMode) {
        $headerText += " - DETAILED VIEW"
    }
    
    Write-Host "═══════════════════════════════════════════════════════════════════════════════"
    Write-Host $headerText
    Write-Host "═══════════════════════════════════════════════════════════════════════════════"
    
    # Display column headers with sort indicators and underlines
    $processHeader = "${script:AnsiUnderline}P${script:AnsiNoUnderline}rocess"
    $appHeader = "${script:AnsiUnderline}A${script:AnsiNoUnderline}pplication"
    $minHeader = "${script:AnsiUnderline}M${script:AnsiNoUnderline}inimised"
    
    # Add sort indicator to appropriate column
    $sortIndicator = if ($script:sortAscending) { "↑" } else { "↓" }
    
    switch ($script:currentSort) {
        'ProcessName' { $processHeader += " $sortIndicator" }
        'WindowTitle' { $appHeader += " $sortIndicator" }
        'WindowState' { $minHeader += " $sortIndicator" }
    }
    
    if ($script:detailedMode) {
        Write-Host (" {0,-3} | {1,-6} | {2,-15} | {3,-30} | {4,-9} | {5}" -f '#', 'Active', $processHeader, $appHeader, $minHeader, 'WindowHandle')
        Write-Host "────────────────────────────────────────────────────────────────────────────────────────"
    }
    else {
        Write-Host (" {0,-3} | {1,-6} | {2,-15} | {3,-30} | {4,-9}" -f '#', 'Active', $processHeader, $appHeader, $minHeader)
        Write-Host "───────────────────────────────────────────────────────────────────────────────"
    }
    
    # Display windows
    for ($i = 0; $i -lt $Windows.Count; $i++) {
        $win = $Windows[$i]
        $num = $i + 1
        
        # Determine if this is the active window
        $isActive = if ($win.WindowHandle -eq $ActiveWindowHandle) { '*' } else { '' }
        
        # Determine minimised display
        $minimised = if ($win.WindowState -eq 'Minimized') { 'Yes' } else { 'No' }
        
        # Truncate long names for display
        $procName = if ($win.ProcessName.Length -gt 15) { $win.ProcessName.Substring(0, 12) + '...' } else { $win.ProcessName }
        $appName = if ($win.WindowTitle.Length -gt 30) { $win.WindowTitle.Substring(0, 27) + '...' } else { $win.WindowTitle }
        
        # Apply blue text if in scroll mode and this is selected index
        $linePrefix = ""
        $lineSuffix = ""
        if ($script:scrollMode -and $i -eq $script:selectedIndex) {
            $linePrefix = $script:AnsiBlue
            $lineSuffix = $script:AnsiReset
        }
        
        if ($script:detailedMode) {
            $line = " {0,-3} | {1,-6} | {2,-15} | {3,-30} | {4,-9} | {5}" -f $num, $isActive, $procName, $appName, $minimised, $win.WindowHandleInt64
            Write-Host "$linePrefix$line$lineSuffix"
        }
        else {
            $line = " {0,-3} | {1,-6} | {2,-15} | {3,-30} | {4,-9}" -f $num, $isActive, $procName, $appName, $minimised
            Write-Host "$linePrefix$line$lineSuffix"
        }
    }
    
    Write-Host "═══════════════════════════════════════════════════════════════════════════════"
    # Use ANSI underline for shortcut character in each command
    $esc = [char]27
    $footer = "Commands: Type or ↑↓ + Enter to select | E${esc}[4mx${esc}[24mit | ${esc}[4mD${esc}[24metail | ${esc}[4mR${esc}[24mefresh | ${esc}[4mH${esc}[24melp"
    Write-Host $footer
    Write-Host ""
    
    # Show help if enabled
    if ($script:showHelp) {
        Write-Host ""
        Write-Host "───────────────────────────────────────────────────────────────────────────────"
        Write-Host "HELP"
        Write-Host "───────────────────────────────────────────────────────────────────────────────"
        Write-Host "NAVIGATION:"
        Write-Host "  • Type a number and press Enter to select that window"
        Write-Host "  • Press ↑/↓ arrow keys to scroll"
        Write-Host "  • In scroll mode, press Enter to confirm selection"
        Write-Host ""
        Write-Host "SORTING:"
        Write-Host "  • Press P to sort by Process (toggles ↑/↓)"
        Write-Host "  • Press A to sort by Application (toggles ↑/↓)"
        Write-Host "  • Press M to sort by Minimised status (toggles ↑/↓)"
        Write-Host ""
        Write-Host "VIEW: Press D to toggle Simple/Detailed view | REFRESH: Press R"
        Write-Host "EXIT: Press X | HELP: Press H to show/hide this help"
        Write-Host ""
        Write-Host "COLUMNS: Active (*=foreground window) | Process | Application | Minimised"
        Write-Host "───────────────────────────────────────────────────────────────────────────────"
    }
}

function Get-UserSelection {
    <#
    .SYNOPSIS
        Gets user input and returns a command object.
    #>
    
    # If in scroll mode, show current selection number in prompt
    if ($script:scrollMode) {
        $promptNum = $script:selectedIndex + 1
        Write-Host "Enter selection: $promptNum" -NoNewline
    }
    else {
        Write-Host "Enter selection: " -NoNewline
    }
    
    # Read key
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    # Handle special keys
    if ($key.VirtualKeyCode -eq 38) { # Up arrow
        return @{ Command = 'ScrollUp'; Value = $null }
    }
    
    if ($key.VirtualKeyCode -eq 40) { # Down arrow
        return @{ Command = 'ScrollDown'; Value = $null }
    }
    
    if ($key.VirtualKeyCode -eq 13) { # Enter
        if ($script:scrollMode) {
            return @{ Command = 'Select'; Value = $script:selectedIndex + 1 }
        }
        else {
            return @{ Command = 'Empty'; Value = $null }
        }
    }
    
    # Handle character input
    $char = $key.Character.ToString().ToLower()
    
    # If it's a digit, collect full number
    if ($char -match '^\d$') {
        Write-Host $char -NoNewline
        $numberInput = $char
        
        # Keep reading until Enter
        while ($true) {
            $nextKey = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            
            if ($nextKey.VirtualKeyCode -eq 13) { # Enter
                Write-Host "" # New line
                $number = [int]$numberInput
                return @{ Command = 'Select'; Value = $number }
            }
            
            $nextChar = $nextKey.Character.ToString()
            if ($nextChar -match '^\d$') {
                Write-Host $nextChar -NoNewline
                $numberInput += $nextChar
            }
        }
    }
    
    # Handle command characters (case insensitive)
    Write-Host $char
    
    switch ($char) {
        'x' { return @{ Command = 'Exit'; Value = $null } }
        'q' { return @{ Command = 'Exit'; Value = $null } }
        'd' { return @{ Command = 'ToggleDetail'; Value = $null } }
        'r' { return @{ Command = 'Refresh'; Value = $null } }
        'h' { return @{ Command = 'ToggleHelp'; Value = $null } }
        'p' { return @{ Command = 'SortProcess'; Value = $null } }
        'a' { return @{ Command = 'SortApplication'; Value = $null } }
        'm' { return @{ Command = 'SortMinimised'; Value = $null } }
        default { return @{ Command = 'Empty'; Value = $null } }
    }
}

function Get-WindowTextLength {
    <#
    .SYNOPSIS
        Wrapper for [WindowEnumerationAPI]::GetWindowTextLength for testability.
    #>
    param(
        [IntPtr]$WindowHandle
    )
    return [WindowEnumerationAPI]::GetWindowTextLength($WindowHandle)
}

function Test-WindowExists {
    <#
    .SYNOPSIS
        Validates that a window handle still exists and is valid.
    #>
    param(
        [IntPtr]$WindowHandle
    )
    try {
        # Try to get window text length as a validation check
        $length = Get-WindowTextLength -WindowHandle $WindowHandle
        if ($length -eq 0) {
            Write-Verbose "Window handle $WindowHandle is invalid or closed (length=0)"
            return $false
        }
        return $true
    }
    catch {
        Write-Verbose "Window handle $WindowHandle no longer valid: $_"
        return $false
    }
}
