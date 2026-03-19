BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force

    # Spectre.Console.Testing.dll ships in lib\test\ and is required for TestConsole
    $testingDll = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll

    # Create a single shared TestConsole for all tests in this file.
    # Width/height are set from module-scope variables defined in LastWarAutoScreenshot.psm1.
    InModuleScope 'LastWarAutoScreenshot' {
        $script:tc = [Spectre.Console.Testing.TestConsole]::new()
        $script:tc.Profile.Width  = $script:TestConsoleWidth
        $script:tc.Profile.Height = $script:TestConsoleHeight
        $script:tc.Profile.Capabilities.Interactive = $true
    }
}

Describe 'Show-EmergencyStopConfigScreen' -Tag 'Unit' {

    # Prompts in order:
    #   1. AutoStart              (bool  -> ConfirmationPrompt): push 'y' or 'n' explicitly
    #   2. MouseGestureEnabled    (bool  -> ConfirmationPrompt): push 'y' or 'n' explicitly
    #   3. PollIntervalMs         (int   -> TextPrompt):         push Enter to keep
    #   4. MouseGestureHoldDurationMs (int -> TextPrompt):      push Enter to keep
    #   5. HotkeyKeyNames         (custom TextPrompt):          push Enter to keep
    #   6. Save SelectionPrompt: Enter = 'Yes -- save now', Down+Enter = 'Reset ALL', Down+Down+Enter = 'Discard'

    # ════════════════════════════════════════════════════════════════════════
    # Context: Table renders current values
    # ════════════════════════════════════════════════════════════════════════
    Context 'Initial table display' {

        It 'Console output contains all EmergencyStop key names' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{
                            AutoStart                  = $true
                            HotkeyKeyNames             = 'Ctrl+Alt+Q'
                            PollIntervalMs             = 100
                            MouseGestureEnabled        = $true
                            MouseGestureHoldDurationMs = 3000
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = $script:tc
                $tc.Input.PushTextWithEnter('y')       # AutoStart
                $tc.Input.PushTextWithEnter('y')       # MouseGestureEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # PollIntervalMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MouseGestureHoldDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # HotkeyVKeyCodes
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter) # Discard changes

                Show-EmergencyStopConfigScreen -Console $tc

                # With a 2560px-wide console the table does not wrap; assert full key names.
                $tc.Output | Should -Match 'AutoStart'
                $tc.Output | Should -Match 'MouseGestureEnabled'
                $tc.Output | Should -Match 'PollIntervalMs'
                $tc.Output | Should -Match 'Ctrl'                 # HotkeyVKeyCodes resolved key name
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
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{
                            AutoStart                  = $true
                            HotkeyKeyNames             = 'Ctrl+Alt+Q'
                            PollIntervalMs             = 100
                            MouseGestureEnabled        = $true
                            MouseGestureHoldDurationMs = 3000
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = $script:tc
                $tc.Input.PushTextWithEnter('y')       # AutoStart
                $tc.Input.PushTextWithEnter('y')       # MouseGestureEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # PollIntervalMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MouseGestureHoldDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # HotkeyVKeyCodes
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter) # Discard changes

                Show-EmergencyStopConfigScreen -Console $tc

                $tc.Output | Should -Match '100'    # PollIntervalMs
                $tc.Output | Should -Match '3000'   # MouseGestureHoldDurationMs
                $tc.Output | Should -Match 'Ctrl'   # HotkeyVKeyCodes resolved key name
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Accepting all current values and saving
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user accepts all current values and chooses Yes -- save now' {

        It 'Calls Save-ModuleSettings exactly once' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{
                            AutoStart                  = $true
                            HotkeyKeyNames             = 'Ctrl+Alt+Q'
                            PollIntervalMs             = 100
                            MouseGestureEnabled        = $true
                            MouseGestureHoldDurationMs = 3000
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = $script:tc
                $tc.Input.PushTextWithEnter('y')       # AutoStart
                $tc.Input.PushTextWithEnter('y')       # MouseGestureEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # PollIntervalMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MouseGestureHoldDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # HotkeyVKeyCodes
                $tc.Input.PushKey([ConsoleKey]::Enter) # Yes -- save now

                Show-EmergencyStopConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1
            }
        }

        It 'The config passed to Save-ModuleSettings retains the original AutoStart value' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{
                            AutoStart                  = $true
                            HotkeyKeyNames             = 'Ctrl+Alt+Q'
                            PollIntervalMs             = 100
                            MouseGestureEnabled        = $true
                            MouseGestureHoldDurationMs = 3000
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = $script:tc
                $tc.Input.PushTextWithEnter('y')       # AutoStart = keep true
                $tc.Input.PushTextWithEnter('y')       # MouseGestureEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # PollIntervalMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MouseGestureHoldDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # HotkeyVKeyCodes
                $tc.Input.PushKey([ConsoleKey]::Enter) # Yes -- save now

                Show-EmergencyStopConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.EmergencyStop.AutoStart -eq $true
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
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{
                            AutoStart                  = $true
                            HotkeyKeyNames             = 'Ctrl+Alt+Q'
                            PollIntervalMs             = 100
                            MouseGestureEnabled        = $true
                            MouseGestureHoldDurationMs = 3000
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = $script:tc
                $tc.Input.PushTextWithEnter('y')       # AutoStart
                $tc.Input.PushTextWithEnter('y')       # MouseGestureEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # PollIntervalMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MouseGestureHoldDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # HotkeyVKeyCodes
                $tc.Input.PushKey([ConsoleKey]::Enter) # Yes -- save now

                Show-EmergencyStopConfigScreen -Console $tc

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
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{
                            AutoStart                  = $true
                            HotkeyKeyNames             = 'Ctrl+Alt+Q'
                            PollIntervalMs             = 100
                            MouseGestureEnabled        = $true
                            MouseGestureHoldDurationMs = 3000
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = $script:tc
                $tc.Input.PushTextWithEnter('y')       # AutoStart
                $tc.Input.PushTextWithEnter('y')       # MouseGestureEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # PollIntervalMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MouseGestureHoldDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # HotkeyVKeyCodes
                $tc.Input.PushKey([ConsoleKey]::Enter) # Yes -- save now

                Show-EmergencyStopConfigScreen -Console $tc

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
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{
                            AutoStart                  = $true
                            HotkeyKeyNames             = 'Ctrl+Alt+Q'
                            PollIntervalMs             = 100
                            MouseGestureEnabled        = $true
                            MouseGestureHoldDurationMs = 3000
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = $script:tc
                $tc.Input.PushTextWithEnter('y')       # AutoStart
                $tc.Input.PushTextWithEnter('y')       # MouseGestureEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # PollIntervalMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MouseGestureHoldDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # HotkeyVKeyCodes
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter) # Discard changes

                Show-EmergencyStopConfigScreen -Console $tc

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
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{
                            AutoStart                  = $true
                            HotkeyKeyNames             = 'Ctrl+Alt+Q'
                            PollIntervalMs             = 100
                            MouseGestureEnabled        = $true
                            MouseGestureHoldDurationMs = 3000
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = $script:tc
                $tc.Input.PushTextWithEnter('y')       # AutoStart
                $tc.Input.PushTextWithEnter('y')       # MouseGestureEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # PollIntervalMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MouseGestureHoldDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # HotkeyVKeyCodes
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter) # Discard changes

                Show-EmergencyStopConfigScreen -Console $tc

                $tc.Output | Should -Match 'No changes saved'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Reset ALL EmergencyStop settings to defaults
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user chooses Reset ALL EmergencyStop settings to defaults at the save prompt' {

        It 'Calls Save-ModuleSettings exactly once' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{
                            AutoStart                  = $true
                            HotkeyKeyNames             = 'Ctrl+Alt+Q'
                            PollIntervalMs             = 100
                            MouseGestureEnabled        = $true
                            MouseGestureHoldDurationMs = 3000
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = $script:tc
                $tc.Input.PushTextWithEnter('y')       # AutoStart
                $tc.Input.PushTextWithEnter('y')       # MouseGestureEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # PollIntervalMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MouseGestureHoldDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # HotkeyVKeyCodes
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter) # Reset ALL EmergencyStop settings to defaults

                Show-EmergencyStopConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1
            }
        }

        It 'The config passed to Save-ModuleSettings has all keys equal to defaults after reset' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                # Use non-default values so the reset is clearly observable
                $mockConfigNonDefault = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{
                            AutoStart                  = $false
                            HotkeyKeyNames             = 'Ctrl+A'
                            PollIntervalMs             = 500
                            MouseGestureEnabled        = $false
                            MouseGestureHoldDurationMs = 10000
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfigNonDefault
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = $script:tc
                $tc.Input.PushTextWithEnter('n')       # AutoStart (confirm current false)
                $tc.Input.PushTextWithEnter('n')       # MouseGestureEnabled (confirm current false)
                $tc.Input.PushKey([ConsoleKey]::Enter) # PollIntervalMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MouseGestureHoldDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # HotkeyVKeyCodes
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter) # Reset ALL EmergencyStop settings to defaults

                Show-EmergencyStopConfigScreen -Console $tc

                # After Reset ALL, entire EmergencyStop section is replaced with defaults.
                # Defaults: AutoStart = $true, PollIntervalMs = 100, HotkeyVKeyCodes = @(17, 16, 220)
                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.EmergencyStop.AutoStart -eq $true -and
                    $Config.EmergencyStop.PollIntervalMs -eq 100 -and
                    $Config.EmergencyStop.HotkeyKeyNames -eq 'Ctrl+Alt+Q'
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
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{
                            AutoStart                  = $true
                            HotkeyKeyNames             = 'Ctrl+Alt+Q'
                            PollIntervalMs             = 100
                            MouseGestureEnabled        = $true
                            MouseGestureHoldDurationMs = 3000
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = $script:tc
                $tc.Input.PushTextWithEnter('y')       # AutoStart
                $tc.Input.PushTextWithEnter('y')       # MouseGestureEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # PollIntervalMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MouseGestureHoldDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # HotkeyVKeyCodes
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter) # Reset ALL EmergencyStop settings to defaults

                Show-EmergencyStopConfigScreen -Console $tc

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
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{
                            AutoStart                  = $true
                            HotkeyKeyNames             = 'Ctrl+Alt+Q'
                            PollIntervalMs             = 100
                            MouseGestureEnabled        = $true
                            MouseGestureHoldDurationMs = 3000
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = $script:tc
                $tc.Input.PushTextWithEnter('y')       # AutoStart
                $tc.Input.PushTextWithEnter('y')       # MouseGestureEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # PollIntervalMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MouseGestureHoldDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # HotkeyVKeyCodes
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter) # Reset ALL EmergencyStop settings to defaults

                Show-EmergencyStopConfigScreen -Console $tc

                Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Info' } -Exactly 1
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: HotkeyKeyNames valid key name input
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user enters a valid key combination for HotkeyKeyNames' {

        It 'Valid input "Ctrl+Shift+P" is normalised and saved as "Ctrl+Shift+P"' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{
                            AutoStart                  = $true
                            HotkeyKeyNames             = 'Ctrl+Alt+Q'
                            PollIntervalMs             = 100
                            MouseGestureEnabled        = $true
                            MouseGestureHoldDurationMs = 3000
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = $script:tc
                $tc.Input.PushTextWithEnter('y')               # AutoStart
                $tc.Input.PushTextWithEnter('y')               # MouseGestureEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)         # PollIntervalMs
                $tc.Input.PushKey([ConsoleKey]::Enter)         # MouseGestureHoldDurationMs
                $tc.Input.PushTextWithEnter('Ctrl+Shift+P')    # HotkeyKeyNames valid key name
                $tc.Input.PushKey([ConsoleKey]::Enter)         # Yes -- save now

                Show-EmergencyStopConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.EmergencyStop.HotkeyKeyNames -eq 'Ctrl+Shift+P'
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: HotkeyKeyNames invalid key name input
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user enters an invalid key combination for HotkeyKeyNames' {

        It 'Invalid input "a+b+c" shows a validation error message in the console output' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{
                            AutoStart                  = $true
                            HotkeyKeyNames             = 'Ctrl+Alt+Q'
                            PollIntervalMs             = 100
                            MouseGestureEnabled        = $true
                            MouseGestureHoldDurationMs = 3000
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = $script:tc
                $tc.Input.PushTextWithEnter('y')         # AutoStart
                $tc.Input.PushTextWithEnter('y')         # MouseGestureEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)   # PollIntervalMs
                $tc.Input.PushKey([ConsoleKey]::Enter)   # MouseGestureHoldDurationMs
                $tc.Input.PushTextWithEnter('a+b+c')     # HotkeyKeyNames invalid ('a' not a modifier)
                $tc.Input.PushKey([ConsoleKey]::Enter)   # keep current on re-prompt
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)   # Discard changes

                Show-EmergencyStopConfigScreen -Console $tc

                $tc.Output | Should -Match 'not a valid modifier'
            }
        }

        It 'Current HotkeyKeyNames is preserved when Enter is pressed after invalid input' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{
                            AutoStart                  = $true
                            HotkeyKeyNames             = 'Ctrl+Alt+Q'
                            PollIntervalMs             = 100
                            MouseGestureEnabled        = $true
                            MouseGestureHoldDurationMs = 3000
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = $script:tc
                $tc.Input.PushTextWithEnter('y')         # AutoStart
                $tc.Input.PushTextWithEnter('y')         # MouseGestureEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)   # PollIntervalMs
                $tc.Input.PushKey([ConsoleKey]::Enter)   # MouseGestureHoldDurationMs
                $tc.Input.PushTextWithEnter('a+b+c')     # HotkeyKeyNames invalid
                $tc.Input.PushKey([ConsoleKey]::Enter)   # Keep current on re-prompt
                $tc.Input.PushKey([ConsoleKey]::Enter)   # Yes -- save now

                Show-EmergencyStopConfigScreen -Console $tc

                # Original HotkeyKeyNames 'Ctrl+Alt+Q' must be preserved
                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.EmergencyStop.HotkeyKeyNames -eq 'Ctrl+Alt+Q'
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Informational note about key name format and keyboard layout
    # ════════════════════════════════════════════════════════════════════════
    Context 'Informational note about key name format and keyboard layout' {

        It 'Console output contains the key name format note mentioning UK keyboard layout' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{
                            AutoStart                  = $true
                            HotkeyKeyNames             = 'Ctrl+Alt+Q'
                            PollIntervalMs             = 100
                            MouseGestureEnabled        = $true
                            MouseGestureHoldDurationMs = 3000
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = $script:tc
                $tc.Input.PushTextWithEnter('y')       # AutoStart
                $tc.Input.PushTextWithEnter('y')       # MouseGestureEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # PollIntervalMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MouseGestureHoldDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # HotkeyKeyNames (keep current)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter) # Discard changes

                Show-EmergencyStopConfigScreen -Console $tc

                $tc.Output | Should -Match 'UK keyboard'
            }
        }
    }
}

