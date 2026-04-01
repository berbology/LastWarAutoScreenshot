function Get-ModuleConfiguration {
    <#
    .SYNOPSIS
        Loads a saved window target configuration from a file.

    .DESCRIPTION
        Reads and deserializes a window configuration from a JSON file that was previously
        saved using Save-ModuleConfiguration. Returns a configuration object containing
        ProcessName, WindowTitle, WindowHandle, and other window properties.

    .PARAMETER ConfigurationPath
        Optional path to the configuration file. If not specified, defaults to:
            $env:APPDATA\LastWarAutoScreenshot\ModuleConfig.jsonc

    .OUTPUTS
        PSCustomObject
        Returns configuration object with properties:
        - ProcessName (string): Name of the process (present only in a full window-target config)
        - WindowTitle (string): Window title text (present only in a full window-target config)
        - WindowHandleString (string): String representation of window handle (present only in a full window-target config)
        - WindowHandleInt64 (int64): Numeric representation of window handle (present only in a full window-target config)
        - ProcessID (uint32): Process identifier (present only in a full window-target config)
        - WindowState (string): Window state at time of save (present only in a full window-target config)
        - SavedDate (datetime): When configuration was saved (present only in a full window-target config)
        - SavedBy (string): Username who saved the configuration (present only in a full window-target config)
        - ComputerName (string): Computer name where configuration was saved (present only in a full window-target config)
        - MouseControl (PSCustomObject): Mouse control settings with all keys pre-populated from defaults
        - EmergencyStop (PSCustomObject): Emergency stop settings with all keys pre-populated from defaults
        - Logging (PSCustomObject): Logging backend settings (present when config exists)

    .EXAMPLE
        $config = Get-ModuleConfiguration
        Write-Host "Loaded configuration for: $($config.ProcessName) - $($config.WindowTitle)"
        
        Loads window configuration from the default location.

    .EXAMPLE
        $config = Get-ModuleConfiguration -ConfigurationPath "C:\Config\MyWindow.json"
        
        Loads window configuration from a custom path.

    .NOTES
        - Configuration file must be in JSON format as created by Save-ModuleConfiguration
        - This function NEVER returns $null. If the configuration file does not exist or is empty,
          it creates one at the specified path containing only the module-settings sections (Logging,
          MouseControl, EmergencyStop) with all defaults applied, logs an Info message, and
          returns the defaults object. Required window-property validation is skipped for a
          freshly-created defaults-only file.
        - WindowHandle values are stored as string and int64 for cross-session compatibility
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigurationPath
    )

    begin {
        Write-Verbose "Starting window configuration load process"
        
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
            # Check if configuration file exists; if not, create it with module-setting defaults.
            # This function is the single source of truth for defaults and never returns $null.
            $fileExists = Test-Path -Path $ConfigurationPath -PathType Leaf
            $jsonContent = $null
            $fileIsEmpty = $false

            if ($fileExists) {
                Write-Verbose "Reading configuration file: $ConfigurationPath"
                $jsonContent = Get-Content -Path $ConfigurationPath -Raw -ErrorAction Stop
                $fileIsEmpty = [string]::IsNullOrWhiteSpace($jsonContent)
            }

            # Treat empty config file the same as missing file: recreate with defaults
            if (-not $fileExists -or $fileIsEmpty) {
                if ($fileIsEmpty) {
                    Write-Verbose "Configuration file is empty at: $ConfigurationPath - recreating with module-setting defaults."
                }
                else {
                    Write-Verbose "Configuration file not found at: $ConfigurationPath - creating with module-setting defaults."
                }

                # Get defaults from single source of truth
                $defaults = Get-DefaultModuleSettings
                $defaultConfig = [PSCustomObject]@{
                    Logging        = $defaults.Logging
                    MouseControl   = $defaults.MouseControl
                    EmergencyStop  = $defaults.EmergencyStop
                    Screenshots    = $defaults.Screenshots
                    CodeEditor     = $defaults.CodeEditor
                    MacroExecution = $defaults.MacroExecution
                }

                # Ensure the target directory exists before writing.
                $defaultConfigParent = Split-Path -Path $ConfigurationPath -Parent
                if ($defaultConfigParent -and -not (Test-Path -Path $defaultConfigParent -PathType Container)) {
                    New-Item -Path $defaultConfigParent -ItemType Directory -Force -ErrorAction Stop | Out-Null
                }

                $defaultConfig | ConvertTo-Json -Depth 5 |
                    Set-Content -Path $ConfigurationPath -Encoding UTF8 -Force -ErrorAction Stop

                Write-LastWarLog -Level Info `
                    -Message "Default module configuration created at: $ConfigurationPath" `
                    -FunctionName 'Get-ModuleConfiguration' `
                    -Context "Path: $ConfigurationPath" `
                    -ForceLog `
                    -BackendNames @('File')
                Write-Verbose "Default module configuration created at: $ConfigurationPath"

                return $defaultConfig
            }

            Write-Verbose "Deserializing JSON content"
            
            # Deserialize JSON to object
            $configData = $jsonContent | ConvertFrom-Json -ErrorAction Stop

            # Get defaults from single source of truth
            $defaults = Get-DefaultModuleSettings

            # Inject missing MouseControl keys (Phase 2 task 2.2)
            if (-not $configData.PSObject.Properties['MouseControl']) {
                $configData | Add-Member -MemberType NoteProperty -Name MouseControl -Value $defaults.MouseControl
            } else {
                foreach ($key in $defaults.MouseControl.PSObject.Properties.Name) {
                    if (-not $configData.MouseControl.PSObject.Properties[$key]) {
                        $configData.MouseControl | Add-Member -MemberType NoteProperty -Name $key -Value $defaults.MouseControl.$key
                    }
                }
            }

            # Inject missing EmergencyStop keys (Phase 2 task 4.2)
            if (-not $configData.PSObject.Properties['EmergencyStop']) {
                $configData | Add-Member -MemberType NoteProperty -Name EmergencyStop -Value $defaults.EmergencyStop
            } else {
                foreach ($key in $defaults.EmergencyStop.PSObject.Properties.Name) {
                    if (-not $configData.EmergencyStop.PSObject.Properties[$key]) {
                        $configData.EmergencyStop | Add-Member -MemberType NoteProperty -Name $key -Value $defaults.EmergencyStop.$key
                    }
                }
            }

            # Migrate old HotkeyVKeyCodes (int[]) to HotkeyKeyNames (string) when upgrading
            # from a pre-Phase-7 configuration that stored virtual key codes directly.
            # The old property is removed so it is not re-serialised to the JSON file.
            if ($configData.EmergencyStop.PSObject.Properties['HotkeyVKeyCodes'] -and
                -not $configData.EmergencyStop.PSObject.Properties['HotkeyKeyNames']) {
                try {
                    $oldCodes         = [int[]]$configData.EmergencyStop.HotkeyVKeyCodes
                    $migratedKeyNames = ConvertTo-HotkeyDisplayString -VKeyCodes $oldCodes
                    $configData.EmergencyStop | Add-Member -MemberType NoteProperty -Name HotkeyKeyNames -Value $migratedKeyNames
                    Write-LastWarLog -Level Info `
                        -Message "Migrated HotkeyVKeyCodes @($($oldCodes -join ', ')) to HotkeyKeyNames '$migratedKeyNames'." `
                        -FunctionName 'Get-ModuleConfiguration' `
                        -ForceLog `
                        -BackendNames @('File')
                }
                catch {
                    Write-LastWarLog -Level Warning `
                        -Message "Could not migrate HotkeyVKeyCodes to HotkeyKeyNames: $_. Using default '$($defaults.EmergencyStop.HotkeyKeyNames)'." `
                        -FunctionName 'Get-ModuleConfiguration' `
                        -ForceLog `
                        -BackendNames @('File')
                    $configData.EmergencyStop | Add-Member -MemberType NoteProperty -Name HotkeyKeyNames -Value $defaults.EmergencyStop.HotkeyKeyNames
                }
            }

            # Remove the old HotkeyVKeyCodes property if still present (legacy configs carry it
            # even after migration; stripping it here keeps the JSON file clean).
            if ($configData.EmergencyStop.PSObject.Properties['HotkeyVKeyCodes']) {
                $configData.EmergencyStop.PSObject.Properties.Remove('HotkeyVKeyCodes')
            }

            # Inject missing Logging keys
            if (-not $configData.PSObject.Properties['Logging']) {
                $configData | Add-Member -MemberType NoteProperty -Name Logging -Value $defaults.Logging
            } else {
                foreach ($key in $defaults.Logging.PSObject.Properties.Name) {
                    if (-not $configData.Logging.PSObject.Properties[$key]) {
                        $configData.Logging | Add-Member -MemberType NoteProperty -Name $key -Value $defaults.Logging.$key
                    }
                }
            }

            # Inject missing FileBackend sub-object and its keys
            if (-not $configData.Logging.PSObject.Properties['FileBackend']) {
                $configData.Logging | Add-Member -MemberType NoteProperty -Name FileBackend -Value $defaults.Logging.FileBackend
            } else {
                foreach ($key in $defaults.Logging.FileBackend.PSObject.Properties.Name) {
                    if (-not $configData.Logging.FileBackend.PSObject.Properties[$key]) {
                        $configData.Logging.FileBackend | Add-Member -MemberType NoteProperty -Name $key -Value $defaults.Logging.FileBackend.$key
                    }
                }
            }

            # Inject missing Screenshots keys (Phase 3 task 6.1; Phase 5 task 1.4)
            if (-not $configData.PSObject.Properties['Screenshots']) {
                $configData | Add-Member -MemberType NoteProperty -Name Screenshots -Value $defaults.Screenshots
            } else {
                foreach ($key in $defaults.Screenshots.PSObject.Properties.Name) {
                    if (-not $configData.Screenshots.PSObject.Properties[$key]) {
                        $configData.Screenshots | Add-Member -MemberType NoteProperty -Name $key -Value $defaults.Screenshots.$key
                    }
                }
            }

            # Inject missing SimilarityCheck sub-object and its keys (Phase 5 task 1.4)
            if (-not $configData.Screenshots.PSObject.Properties['SimilarityCheck']) {
                $configData.Screenshots | Add-Member -MemberType NoteProperty -Name SimilarityCheck -Value $defaults.Screenshots.SimilarityCheck
            } else {
                foreach ($key in $defaults.Screenshots.SimilarityCheck.PSObject.Properties.Name) {
                    if (-not $configData.Screenshots.SimilarityCheck.PSObject.Properties[$key]) {
                        $configData.Screenshots.SimilarityCheck | Add-Member -MemberType NoteProperty -Name $key -Value $defaults.Screenshots.SimilarityCheck.$key
                    }
                }
            }

            # Inject missing CodeEditor key
            if (-not $configData.PSObject.Properties['CodeEditor']) {
                $configData | Add-Member -MemberType NoteProperty -Name CodeEditor -Value $defaults.CodeEditor
            }

            # Inject missing MacroExecution keys (Phase 6 task 6.1)
            if (-not $configData.PSObject.Properties['MacroExecution']) {
                $configData | Add-Member -MemberType NoteProperty -Name MacroExecution -Value $defaults.MacroExecution
            } else {
                foreach ($key in $defaults.MacroExecution.PSObject.Properties.Name) {
                    if (-not $configData.MacroExecution.PSObject.Properties[$key]) {
                        $configData.MacroExecution | Add-Member -MemberType NoteProperty -Name $key -Value $defaults.MacroExecution.$key
                    }
                }
            }

            # Check whether window-target properties are present.
            # A settings-only file (saved deliberately when the app starts, so the user
            # must pick a fresh window each session) is valid and contains no window
            # properties.  Only log/throw when SOME but not ALL window properties are
            # present, which indicates genuine file corruption.
            $windowProperties = @('ProcessName', 'WindowTitle', 'WindowHandleString', 'WindowHandleInt64')
            $presentCount = ($windowProperties | Where-Object { $configData.PSObject.Properties[$_] }).Count

            if ($presentCount -gt 0 -and $presentCount -lt $windowProperties.Count) {
                $missingProperties = $windowProperties | Where-Object { -not $configData.PSObject.Properties[$_] }
                $errorMsg = "Configuration file is missing required properties: $($missingProperties -join ', ')"
                Write-Error "Error: $errorMsg"
                Write-LastWarLog -Message $errorMsg -Level Error -FunctionName 'Get-ModuleConfiguration' -Context "Path: $ConfigurationPath" -LogStackTrace $_ -ForceLog -BackendNames @('File')
                throw $errorMsg
            }

            if ($presentCount -eq $windowProperties.Count) {
                Write-Verbose "Configuration loaded successfully: ProcessName=$($configData.ProcessName), WindowTitle=$($configData.WindowTitle)"
                Write-LastWarLog -Level Info -Message "Loaded window configuration: $($configData.ProcessName) - $($configData.WindowTitle)" -FunctionName 'Get-ModuleConfiguration' -ForceLog -BackendNames @('File')
            } else {
                Write-Verbose 'Configuration loaded (settings only — no window target configured)'
                Write-LastWarLog -Level Info -Message 'Loaded settings-only configuration (no window target)' -FunctionName 'Get-ModuleConfiguration' -ForceLog -BackendNames @('File')
            }

            # Return configuration object
            return $configData
        }
        catch [System.IO.IOException] {
            $errorMsg = "Failed to read configuration file: $_"
            Write-Error "Error: $errorMsg"
            Write-LastWarLog -Message $errorMsg -Level Error -FunctionName 'Get-ModuleConfiguration' -Context "Path: $ConfigurationPath" -LogStackTrace $_ -ForceLog -BackendNames @('File')
            throw
        }
        catch [System.ArgumentException] {
            $errorMsg = "Invalid JSON format in configuration file: $_"
            Write-Error "Error: $errorMsg"
            Write-LastWarLog -Message $errorMsg -Level Error -FunctionName 'Get-ModuleConfiguration' -Context "Path: $ConfigurationPath" -LogStackTrace $_ -ForceLog -BackendNames @('File')
            throw
        }
        catch {
            $errorMsg = "Unexpected error loading window configuration: $_"
            Write-Error "Error: $errorMsg"
            Write-LastWarLog -Message $errorMsg -Level Error -FunctionName 'Get-ModuleConfiguration' -Context "Path: $ConfigurationPath" -LogStackTrace $_ -ForceLog -BackendNames @('File')
            throw
        }
    }

    end {
        Write-Verbose "Window configuration load process completed"
    }
}

