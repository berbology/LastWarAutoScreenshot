function Save-ModuleConfiguration {
    <#
    .SYNOPSIS
        Saves the selected window target configuration to a file.

    .DESCRIPTION
        Persists the window target configuration to a JSON file for later use. Stores the
        ProcessName, WindowTitle, and WindowHandle information from a selected window object.
        
        If a configuration file already exists at the target path, the function will prompt
        for confirmation before overwriting (unless -Force is specified).

    .PARAMETER WindowObject
        The window object returned from Select-TargetWindowFromMenu containing ProcessName,
        WindowTitle, WindowHandle, and other window properties.

        .PARAMETER ConfigurationPath
            Optional path to save the configuration file. If not specified, defaults to:
            $env:APPDATA\LastWarAutoScreenshot\WindowConfig.json

    .PARAMETER Force
        Skip confirmation prompt when overwriting an existing configuration file.

    .OUTPUTS
        System.IO.FileInfo
        Returns FileInfo object for the saved configuration file.

    .EXAMPLE
        $window = Get-EnumeratedWindows | Select-TargetWindowFromMenu
        Save-ModuleConfiguration -WindowObject $window
        
        Saves the selected window configuration to the default location.

    .EXAMPLE
        $window = Get-EnumeratedWindows -ProcessName 'LastWar' | Select-TargetWindowFromMenu
        Save-ModuleConfiguration -WindowObject $window -ConfigurationPath "C:\Config\MyWindow.json" -Force
        
        Saves the configuration to a custom path, overwriting without prompting.

    .NOTES
        - Configuration is saved in JSON format for easy editing and portability
        - The WindowHandle is saved as both string and int64 representations
        - Requires write permissions to the target directory
        - Creates parent directories if they don't exist
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [PSCustomObject]$WindowObject,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigurationPath,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        Write-Verbose "Starting window configuration save process"
        
        # Set default configuration path if not specified
        if (-not $PSBoundParameters.ContainsKey('ConfigurationPath')) {
            $defaultConfigDir = Join-Path -Path $env:APPDATA -ChildPath 'LastWarAutoScreenshot'
            $ConfigurationPath = Join-Path -Path $defaultConfigDir -ChildPath 'WindowConfig.json'
            Write-Verbose "Using default configuration path: $ConfigurationPath"
        }
        else {
            Write-Verbose "Using custom configuration path: $ConfigurationPath"
        }
    }

    process {
        try {
            # Validate WindowObject has required properties
            $requiredProperties = @('ProcessName', 'WindowTitle', 'WindowHandle')
            $missingProperties = $requiredProperties | Where-Object { -not $WindowObject.PSObject.Properties[$_] }
            
            if ($missingProperties.Count -gt 0) {
                $errorMsg = "WindowObject is missing required properties: $($missingProperties -join ', ')"
                Write-Error "Error: $errorMsg"
                Write-LastWarLog -Message $errorMsg -Level Error -FunctionName 'Save-ModuleConfiguration' -Context "Path: $ConfigurationPath" -LogStackTrace $_
                throw $errorMsg
            }

            Write-Verbose "Validating window object properties: ProcessName=$($WindowObject.ProcessName), WindowTitle=$($WindowObject.WindowTitle)"

            # Check if configuration file already exists
            $configExists = Test-Path -Path $ConfigurationPath -PathType Leaf
            
            if ($configExists) {
                Write-Verbose "Configuration file already exists at: $ConfigurationPath"
                # Prompt for confirmation if not forced
                $shouldProcessMessage = "Overwrite existing configuration file at '$ConfigurationPath'"
                if (-not $Force -and -not $PSCmdlet.ShouldProcess($ConfigurationPath, $shouldProcessMessage)) {
                    Write-Warning "Warning: Configuration save cancelled by user."
                    Write-LastWarLog -Message "Configuration save cancelled by user" -Level Warning -FunctionName 'Save-ModuleConfiguration' -Context "Path: $ConfigurationPath" -LogStackTrace $_
                    return
                }
                Write-Verbose "Overwriting existing configuration file"
            }

            # Ensure parent directory exists
            $parentDir = Split-Path -Path $ConfigurationPath -Parent
            if (-not (Test-Path -Path $parentDir -PathType Container)) {
                Write-Verbose "Creating configuration directory: $parentDir"
                New-Item -Path $parentDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }


            # MouseControl config defaults
            $mouseDefaults = [PSCustomObject]@{
                EasingEnabled = $true
                OvershootEnabled = $true
                OvershootFactor = 0.1
                MicroPausesEnabled = $true
                MicroPauseChance = 0.2
                MicroPauseDurationRangeMs = @(20, 80)
                JitterEnabled = $true
                JitterRadiusPx = 2
                BezierControlPointOffsetFactor = 0.3
                MovementDurationRangeMs = @(200, 600)
                ClickDownDurationRangeMs = @(50, 150)
                ClickPreDelayRangeMs = @(50, 200)
                ClickPostDelayRangeMs = @(100, 300)
                PathPointCount = 20
            }

            # Prepare configuration object for serialization
            $configData = [PSCustomObject]@{
                ProcessName         = $WindowObject.ProcessName
                WindowTitle         = $WindowObject.WindowTitle
                WindowHandleString  = $WindowObject.WindowHandle.ToString()
                WindowHandleInt64   = [int64]$WindowObject.WindowHandle
                ProcessID           = $WindowObject.ProcessID
                WindowState         = $WindowObject.WindowState
                SavedDate           = Get-Date -Format 'o'  # ISO 8601 format
                SavedBy             = $env:USERNAME
                ComputerName        = $env:COMPUTERNAME
                MouseControl        = $mouseDefaults
            }

            Write-Verbose "Serializing configuration to JSON format"
            
            # Serialize to JSON with formatting
            $jsonContent = $configData | ConvertTo-Json -Depth 5
            
            # Save to file
            Write-Verbose "Writing configuration to file: $ConfigurationPath"
            $jsonContent | Set-Content -Path $ConfigurationPath -Encoding UTF8 -ErrorAction Stop -Force
            
            # Get FileInfo object for return
            $savedFile = Get-Item -Path $ConfigurationPath -ErrorAction Stop
            
            Write-Verbose "Configuration saved successfully: $($savedFile.FullName) ($($savedFile.Length) bytes)"
            Write-Host "Window configuration saved to: $($savedFile.FullName)" -ForegroundColor Green
            
            # Return FileInfo object
            return $savedFile
        }
        catch [System.IO.IOException] {
            $errorMsg = "Failed to write configuration file: $_"
            Write-Error "Error: $errorMsg"
            Write-LastWarLog -Message $errorMsg -Level Error -FunctionName 'Save-ModuleConfiguration' -Context "Path: $ConfigurationPath" -LogStackTrace $_
            throw
        }
        catch [System.UnauthorizedAccessException] {
            $errorMsg = "Access denied writing to configuration path '$ConfigurationPath'. Check permissions."
            Write-Error "Error: $errorMsg"
            Write-LastWarLog -Message $errorMsg -Level Error -FunctionName 'Save-ModuleConfiguration' -Context "Path: $ConfigurationPath" -LogStackTrace $_
            throw
        }
        catch {
            $errorMsg = "Unexpected error saving window configuration: $_"
            Write-Error "Error: $errorMsg"
            Write-LastWarLog -Message $errorMsg -Level Error -FunctionName 'Save-ModuleConfiguration' -Context "Path: $ConfigurationPath" -LogStackTrace $_
            throw
        }
    }

    end {
        Write-Verbose "Window configuration save process completed"
    }
}
