BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force

    # Spectre.Console.Testing.dll ships in lib\test\ and is required for TestConsole
    $testingDll = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}

Describe 'Show-LoggingConfigScreen' -Tag 'Unit' {

    # ════════════════════════════════════════════════════════════════════════
    # Context: Table renders current values
    # ════════════════════════════════════════════════════════════════════════
    Context 'Initial table display' {

        It 'Console output contains all five Logging key names' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB          = 50
                                MaxAgeDays         = 30
                                MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::Enter) }
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-LoggingConfigScreen -Console $tc

                $tc.Output | Should -Match 'MinimumLog'
                $tc.Output | Should -Match 'Backend'
                $tc.Output | Should -Match 'MaxSizeMB'
                $tc.Output | Should -Match 'MaxAgeDays'
                $tc.Output | Should -Match 'MaxLogFileCou'
            }
        }

        It 'Console output contains the current values from the loaded config' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB          = 50
                                MaxAgeDays         = 30
                                MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::Enter) }
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-LoggingConfigScreen -Console $tc

                $tc.Output | Should -Match 'Info'
                $tc.Output | Should -Match 'File'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Empty input keeps current values; Yes - save now calls Save-ModuleSettings
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user presses Enter for all keys and chooses Yes - save now' {

        It 'Calls Save-ModuleSettings exactly once' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB          = 50
                                MaxAgeDays         = 30
                                MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::Enter) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-LoggingConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1
            }
        }

        It 'The config passed to Save-ModuleSettings retains the original MinimumLogLevel' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB          = 50
                                MaxAgeDays         = 30
                                MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::Enter) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-LoggingConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.Logging.MinimumLogLevel -eq 'Info'
                }
            }
        }

        It 'Writes a success panel containing "saved" to the console' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB          = 50
                                MaxAgeDays         = 30
                                MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::Enter) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-LoggingConfigScreen -Console $tc

                $tc.Output | Should -Match 'saved'
            }
        }

        It 'Calls Write-LastWarLog with Level Info on successful save' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB          = 50
                                MaxAgeDays         = 30
                                MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::Enter) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-LoggingConfigScreen -Console $tc

                Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Info' } -Exactly 1
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Discard changes does not call Save-ModuleSettings
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user chooses Discard changes' {

        It 'Does not call Save-ModuleSettings' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB          = 50
                                MaxAgeDays         = 30
                                MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::Enter) }
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-LoggingConfigScreen -Console $tc

                Should -Not -Invoke Save-ModuleSettings
            }
        }

        It 'Writes a "No changes saved" panel to the console' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB          = 50
                                MaxAgeDays         = 30
                                MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::Enter) }
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-LoggingConfigScreen -Console $tc

                $tc.Output | Should -Match 'No changes saved'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Valid selection for MinimumLogLevel via SelectionPrompt
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user selects a different MinimumLogLevel from the SelectionPrompt' {

        It 'The saved config contains the updated MinimumLogLevel value' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB          = 50
                                MaxAgeDays         = 30
                                MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::DownArrow)   # Move to 'Verbose (noisy...)'
                $tc.Input.PushKey([ConsoleKey]::DownArrow)   # Move to 'Warning (recoverable...)'
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Select 'Warning'
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Accept default for Backend
                for ($i = 0; $i -lt 3; $i++) { $tc.Input.PushKey([ConsoleKey]::Enter) }  # Accept defaults for next 3 keys
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Save: 'Yes - save now'

                Show-LoggingConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.Logging.MinimumLogLevel -eq 'Warning'
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Reset ALL at the save prompt
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user chooses Reset ALL Logging settings to defaults at the save prompt' {

        It 'Calls Save-ModuleSettings exactly once' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB          = 50
                                MaxAgeDays         = 30
                                MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::Enter) }
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-LoggingConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1
            }
        }

        It 'The config passed to Save-ModuleSettings has MinimumLogLevel and Backend equal to schema defaults' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfigNonDefault = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Error'
                            Backend         = 'EventLog'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB          = 99
                                MaxAgeDays         = 99
                                MaxLogFileCount = 999
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfigNonDefault
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::Enter) }
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-LoggingConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.Logging.MinimumLogLevel -eq 'Info' -and
                    $Config.Logging.Backend -eq 'File,EventLog'
                }
            }
        }

        It 'Writes a panel containing "reset" to the console' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB          = 50
                                MaxAgeDays         = 30
                                MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::Enter) }
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-LoggingConfigScreen -Console $tc

                $tc.Output | Should -Match 'reset'
            }
        }

        It 'Calls Write-LastWarLog with Level Info after reset-all save' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB          = 50
                                MaxAgeDays         = 30
                                MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::Enter) }
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-LoggingConfigScreen -Console $tc

                Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Info' } -Exactly 1
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Valid integer value entered for an int key
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user enters a valid integer for MaxSizeMB' {

        It 'The saved config contains the updated MaxSizeMB value' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB          = 50
                                MaxAgeDays         = 30
                                MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushTextWithEnter('100')
                for ($i = 0; $i -lt 2; $i++) { $tc.Input.PushKey([ConsoleKey]::Enter) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-LoggingConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.Logging.FileBackend.MaxSizeMB -eq 100
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Out-of-range integer entered for an int key
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user enters an out-of-range value for MaxSizeMB' {

        It 'Error message appears in console output and original value is kept when user then presses Enter' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB          = 50
                                MaxAgeDays         = 30
                                MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushTextWithEnter('0')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                for ($i = 0; $i -lt 2; $i++) { $tc.Input.PushKey([ConsoleKey]::Enter) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-LoggingConfigScreen -Console $tc

                $tc.Output | Should -Match 'at least'
                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.Logging.FileBackend.MaxSizeMB -eq 50
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Function contract
    # ════════════════════════════════════════════════════════════════════════
    Context 'Function contract' {

        It 'Calls Get-ModuleConfiguration exactly once to load current settings' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB          = 50
                                MaxAgeDays         = 30
                                MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::Enter) }
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-LoggingConfigScreen -Console $tc

                Should -Invoke Get-ModuleConfiguration -Exactly 1
            }
        }

        It 'Does not throw under normal conditions' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB          = 50
                                MaxAgeDays         = 30
                                MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::Enter) }
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                { Show-LoggingConfigScreen -Console $tc } | Should -Not -Throw
            }
        }
    }
}

