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
            $env:APPDATA\LastWarAutoScreenshot\ModuleConfig.jsonc

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
        - When overwriting an existing configuration file, module settings (MouseControl,
          EmergencyStop, and Logging) are preserved from the existing file. This allows you
          to save a new window target without losing custom configuration you may have set.
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
        
        # Import helper functions
        . "$PSScriptRoot/Get-DefaultModuleSettings.ps1"
        . "$PSScriptRoot/Write-LastWarLog.ps1"
        
        # Set default configuration path if not specified
        if (-not $PSBoundParameters.ContainsKey('ConfigurationPath')) {
            $defaultConfigDir = Join-Path -Path $env:APPDATA -ChildPath 'LastWarAutoScreenshot'
            $ConfigurationPath = Join-Path -Path $defaultConfigDir -ChildPath 'ModuleConfig.jsonc'
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
                [System.IO.Directory]::CreateDirectory($parentDir) | Out-Null
            }

            # Load existing configuration to preserve module settings (MouseControl, EmergencyStop, Logging)
            Write-Verbose "Loading existing configuration to preserve module settings"
            $existingConfig = $null
            if ($configExists) {
                try {
                    $existingConfig = Get-ModuleConfiguration -ConfigurationPath $ConfigurationPath -ErrorAction SilentlyContinue
                }
                catch {
                    Write-Verbose "Could not load existing configuration, will use defaults for module settings"
                }
            }

            # Get defaults from single source of truth
            $defaults = Get-DefaultModuleSettings

            # Use existing Logging settings if available, otherwise use defaults
            $loggingConfig = if ($existingConfig -and $existingConfig.Logging) {
                $existingConfig.Logging
            } else {
                $defaults.Logging
            }

            # Use existing MouseControl settings if available, otherwise use defaults
            $mouseControlConfig = if ($existingConfig -and $existingConfig.MouseControl) {
                $existingConfig.MouseControl
            } else {
                $defaults.MouseControl
            }

            # Use existing EmergencyStop settings if available, otherwise use defaults
            $emergencyStopConfig = if ($existingConfig -and $existingConfig.EmergencyStop) {
                $existingConfig.EmergencyStop
            } else {
                $defaults.EmergencyStop
            }

            # Use existing Screenshots settings if available, otherwise use defaults (Phase 5 task 1.5)
            $screenshotsConfig = if ($existingConfig -and $existingConfig.Screenshots) {
                $existingConfig.Screenshots
            } else {
                $defaults.Screenshots
            }

            # Ensure all new Screenshots sub-keys are present (forward compatibility)
            foreach ($key in $defaults.Screenshots.PSObject.Properties.Name) {
                if (-not $screenshotsConfig.PSObject.Properties[$key]) {
                    $screenshotsConfig | Add-Member -MemberType NoteProperty -Name $key -Value $defaults.Screenshots.$key
                }
            }

            # Ensure all SimilarityCheck sub-keys are present (Phase 5 task 1.5)
            if (-not $screenshotsConfig.PSObject.Properties['SimilarityCheck']) {
                $screenshotsConfig | Add-Member -MemberType NoteProperty -Name SimilarityCheck -Value $defaults.Screenshots.SimilarityCheck
            } else {
                foreach ($key in $defaults.Screenshots.SimilarityCheck.PSObject.Properties.Name) {
                    if (-not $screenshotsConfig.SimilarityCheck.PSObject.Properties[$key]) {
                        $screenshotsConfig.SimilarityCheck | Add-Member -MemberType NoteProperty -Name $key -Value $defaults.Screenshots.SimilarityCheck.$key
                    }
                }
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
                Logging             = $loggingConfig
                MouseControl        = $mouseControlConfig
                EmergencyStop       = $emergencyStopConfig
                Screenshots         = $screenshotsConfig
            }

            Write-Verbose "Serializing configuration to JSONC format"

            # Serialise to JSONC (JSON with embedded comments for user guidance)
            $jsonContent = Get-ModuleConfigJsoncContent -Config $configData

            # Save to file
            Write-Verbose "Writing configuration to file: $ConfigurationPath"
            Set-Content -Path $ConfigurationPath -Value $jsonContent -Encoding UTF8 -ErrorAction Stop -Force
            
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

