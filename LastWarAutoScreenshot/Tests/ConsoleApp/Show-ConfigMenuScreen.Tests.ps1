BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force

    # Spectre.Console.Testing.dll ships in lib\test\ and is required for TestConsole
    $testingDll = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}

Describe 'Show-ConfigMenuScreen' -Tag 'Unit' {

    # ════════════════════════════════════════════════════════════════════════
    # Context: User immediately selects [Back to main menu]
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user immediately selects [Back to main menu]' {

        It 'Returns (exits cleanly) without calling any sub-screen' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-StorageInfoScreen          {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # Choices: [0] [Back to main menu], [1] Logging, [2] Mouse control, [3] Emergency stop, [4] Storage
                $tc.Input.PushKey([ConsoleKey]::Enter)  # Select [Back to main menu] (index 0, default)

                { Show-ConfigMenuScreen -Console $tc } | Should -Not -Throw
            }
        }

        It 'Does not call Show-LoggingConfigScreen when [Back to main menu] is selected immediately' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-StorageInfoScreen          {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)  # [Back to main menu] is index 0

                Show-ConfigMenuScreen -Console $tc

                Should -Not -Invoke Show-LoggingConfigScreen
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Logging settings chosen then back
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user selects Logging settings then [Back to main menu]' {

        It 'Calls Show-LoggingConfigScreen exactly once' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-StorageInfoScreen          {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # First iteration: choose 'Logging settings' (index 1, 1 down from [Back to main menu])
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second iteration: choose '[Back to main menu]' (index 0, Enter immediately)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ConfigMenuScreen -Console $tc

                Should -Invoke Show-LoggingConfigScreen -Exactly 1
            }
        }

        It 'Does not call any other sub-screen when only Logging settings is chosen' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-StorageInfoScreen          {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # First iteration: choose 'Logging settings' (index 1)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second iteration: choose '[Back to main menu]' (index 0)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ConfigMenuScreen -Console $tc

                Should -Not -Invoke Show-MouseControlConfigScreen
                Should -Not -Invoke Show-EmergencyStopConfigScreen
                Should -Not -Invoke Show-StorageInfoScreen
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Mouse control settings chosen then back
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user selects Mouse control settings then [Back to main menu]' {

        It 'Calls Show-MouseControlConfigScreen exactly once' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-StorageInfoScreen          {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # First iteration: Mouse control settings (index 2, 2 downs from [Back to main menu])
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second iteration: [Back to main menu] (index 0, Enter immediately)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ConfigMenuScreen -Console $tc

                Should -Invoke Show-MouseControlConfigScreen -Exactly 1
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Emergency stop settings chosen then back
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user selects Emergency stop settings then [Back to main menu]' {

        It 'Calls Show-EmergencyStopConfigScreen exactly once' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-StorageInfoScreen          {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # First iteration: Emergency stop settings (index 3, 3 downs from [Back to main menu])
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second iteration: [Back to main menu] (index 0, Enter immediately)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ConfigMenuScreen -Console $tc

                Should -Invoke Show-EmergencyStopConfigScreen -Exactly 1
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Storage & log file info chosen then back
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user selects Storage and log file info then [Back to main menu]' {

        It 'Calls Show-StorageInfoScreen exactly once' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-StorageInfoScreen          {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # First iteration: Storage & log file info (index 4, 4 downs from [Back to main menu])
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second iteration: [Back to main menu] (index 0, Enter immediately)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ConfigMenuScreen -Console $tc

                Should -Invoke Show-StorageInfoScreen -Exactly 1
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Console output contains all expected choices
    # ════════════════════════════════════════════════════════════════════════
    Context 'Console output' {

        It 'Output contains all five menu options' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-StorageInfoScreen          {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # [Back to main menu] is index 0; just Enter exits and causes output to render
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ConfigMenuScreen -Console $tc

                $tc.Output | Should -Match 'Logging settings'
                $tc.Output | Should -Match 'Mouse control settings'
                $tc.Output | Should -Match 'Emergency stop settings'
                $tc.Output | Should -Match 'Storage'
                $tc.Output | Should -Match 'Back to main menu'
            }
        }

        It 'Output contains the prompt title Configuration area' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-StorageInfoScreen          {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)  # [Back to main menu] is index 0

                Show-ConfigMenuScreen -Console $tc

                $tc.Output | Should -Match 'Configuration area'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Loop re-enters the menu after a sub-screen returns
    # ════════════════════════════════════════════════════════════════════════
    Context 'When a sub-screen is visited twice before going back' {

        It 'Calls Show-LoggingConfigScreen twice when chosen on two consecutive loop iterations' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-StorageInfoScreen          {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # First iteration: Logging settings (index 1, 1 down from [Back to main menu])
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second iteration: Logging settings again (index 1, 1 down from [Back to main menu])
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Third iteration: [Back to main menu] (index 0, Enter immediately)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ConfigMenuScreen -Console $tc

                Should -Invoke Show-LoggingConfigScreen -Exactly 2
            }
        }
    }
}

