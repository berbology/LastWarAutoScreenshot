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
                Mock Show-ScreenshotConfigScreen     {}

                $tc = $script:tc
                # Choices: [0] [Back to main menu], [1] Logging, [2] Mouse control, [3] Emergency stop, [4] Screenshot
                $tc.Input.PushKey([ConsoleKey]::Enter)  # Select [Back to main menu] (index 0, default)

                { Show-ConfigMenuScreen -Console $tc } | Should -Not -Throw
            }
        }

        It 'Does not call Show-LoggingConfigScreen when [Back to main menu] is selected immediately' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-ScreenshotConfigScreen     {}

                $tc = $script:tc
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
                Mock Show-ScreenshotConfigScreen     {}

                $tc = $script:tc
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
                Mock Show-ScreenshotConfigScreen     {}

                $tc = $script:tc
                # First iteration: choose 'Logging settings' (index 1)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second iteration: choose '[Back to main menu]' (index 0)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ConfigMenuScreen -Console $tc

                Should -Not -Invoke Show-MouseControlConfigScreen
                Should -Not -Invoke Show-EmergencyStopConfigScreen
                Should -Not -Invoke Show-ScreenshotConfigScreen
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
                Mock Show-ScreenshotConfigScreen     {}

                $tc = $script:tc
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
                Mock Show-ScreenshotConfigScreen     {}

                $tc = $script:tc
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
    # Context: Console output contains all expected choices
    # ════════════════════════════════════════════════════════════════════════
    Context 'Console output' {

        It 'Output contains all five menu options' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-ScreenshotConfigScreen     {}

                $tc = $script:tc
                # [Back to main menu] is index 0; just Enter exits and causes output to render
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ConfigMenuScreen -Console $tc

                $tc.Output | Should -Match 'Logging settings'
                $tc.Output | Should -Match 'Mouse control settings'
                $tc.Output | Should -Match 'Emergency stop settings'
                $tc.Output | Should -Match 'Screenshot settings'
                $tc.Output | Should -Match 'Back to main menu'
            }
        }

        It 'Output contains the prompt title Configuration area' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-ScreenshotConfigScreen     {}

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)  # [Back to main menu] is index 0

                Show-ConfigMenuScreen -Console $tc

                $tc.Output | Should -Match 'Configuration area'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Screenshot settings chosen then back
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user selects Screenshot settings then [Back to main menu]' {

        It 'Screenshot settings option appears in console output' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-ScreenshotConfigScreen     {}

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)  # [Back to main menu] is index 0

                Show-ConfigMenuScreen -Console $tc

                $tc.Output | Should -Match 'Screenshot settings'
            }
        }

        It 'Calls Show-ScreenshotConfigScreen exactly once when Screenshot settings is selected' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-ScreenshotConfigScreen     {}

                $tc = $script:tc
                # First iteration: Screenshot settings (index 4, 4 downs from [Back to main menu])
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second iteration: [Back to main menu] (index 0, Enter immediately)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ConfigMenuScreen -Console $tc

                Should -Invoke Show-ScreenshotConfigScreen -Exactly 1
            }
        }

        It 'Passes the same Console instance to Show-ScreenshotConfigScreen' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-ScreenshotConfigScreen     {}

                $tc = $script:tc
                # First iteration: Screenshot settings (index 4)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second iteration: [Back to main menu]
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ConfigMenuScreen -Console $tc

                Should -Invoke Show-ScreenshotConfigScreen -Exactly 1 -ParameterFilter { $Console -eq $tc }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Set default code editor
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user selects Set default code editor' {

        It 'Set default code editor option appears in console output' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-ScreenshotConfigScreen     {}
                Mock Invoke-SelectCodeEditorDialog   { $null }
                Mock Get-ModuleConfiguration         { [PSCustomObject]@{ CodeEditor = 'C:\Windows\System32\notepad.exe' } }
                Mock Save-ModuleSettings             {}

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)  # [Back to main menu] is index 0

                Show-ConfigMenuScreen -Console $tc

                $tc.Output | Should -Match 'Set default code editor'
            }
        }

        It 'Calls Invoke-SelectCodeEditorDialog when Set default code editor is selected' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-ScreenshotConfigScreen     {}
                Mock Invoke-SelectCodeEditorDialog   { $null }
                Mock Get-ModuleConfiguration         { [PSCustomObject]@{ CodeEditor = 'C:\Windows\System32\notepad.exe' } }
                Mock Save-ModuleSettings             {}

                $tc = $script:tc
                # First iteration: Set default code editor (index 5, 5 downs from [Back to main menu])
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second iteration: [Back to main menu] (index 0)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ConfigMenuScreen -Console $tc

                Should -Invoke Invoke-SelectCodeEditorDialog -Exactly 1
            }
        }

        It 'Calls Save-ModuleSettings with updated CodeEditor when dialog returns a path' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-ScreenshotConfigScreen     {}
                Mock Invoke-SelectCodeEditorDialog   { 'C:\Program Files\Microsoft VS Code\Code.exe' }
                Mock Get-ModuleConfiguration         { [PSCustomObject]@{ CodeEditor = 'C:\Windows\System32\notepad.exe' } }
                Mock Save-ModuleSettings             {}

                $tc = $script:tc
                # First iteration: Set default code editor (index 5)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second iteration: [Back to main menu]
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ConfigMenuScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.CodeEditor -eq 'C:\Program Files\Microsoft VS Code\Code.exe'
                }
            }
        }

        It 'Does not call Save-ModuleSettings when dialog is cancelled' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-ScreenshotConfigScreen     {}
                Mock Invoke-SelectCodeEditorDialog   { $null }
                Mock Get-ModuleConfiguration         { [PSCustomObject]@{ CodeEditor = 'C:\Windows\System32\notepad.exe' } }
                Mock Save-ModuleSettings             {}

                $tc = $script:tc
                # First iteration: Set default code editor (index 5)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second iteration: [Back to main menu]
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ConfigMenuScreen -Console $tc

                Should -Not -Invoke Save-ModuleSettings
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Edit module configuration
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user selects Edit module configuration' {

        It 'Edit module configuration option appears in console output' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-ScreenshotConfigScreen     {}
                Mock Start-Process                   {}

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)  # [Back to main menu] is index 0

                Show-ConfigMenuScreen -Console $tc

                $tc.Output | Should -Match 'Edit module configuration'
            }
        }

        It 'Calls Start-Process with configured CodeEditor when Edit module configuration is selected' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-ScreenshotConfigScreen     {}
                Mock Get-ModuleConfiguration         { [PSCustomObject]@{ CodeEditor = 'C:\editors\MyEditor.exe' } }
                Mock Test-Path                       { $true } -ParameterFilter { $Path -eq 'C:\editors\MyEditor.exe' }
                Mock Start-Process                   {}

                $tc = $script:tc
                # First iteration: Edit module configuration (index 6, 6 downs from [Back to main menu])
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second iteration: [Back to main menu]
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ConfigMenuScreen -Console $tc

                Should -Invoke Start-Process -Exactly 1 -ParameterFilter { $FilePath -eq 'cmd.exe' }
            }
        }

        It 'Opens notepad when CodeEditor in config is not set or does not exist' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Show-LoggingConfigScreen        {}
                Mock Show-MouseControlConfigScreen   {}
                Mock Show-EmergencyStopConfigScreen  {}
                Mock Show-ScreenshotConfigScreen     {}
                Mock Get-ModuleConfiguration         { [PSCustomObject]@{ CodeEditor = 'C:\editors\Missing.exe' } }
                Mock Test-Path                       { $false }
                Mock Start-Process                   {}

                $tc = $script:tc
                # First iteration: Edit module configuration (index 6)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second iteration: [Back to main menu]
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ConfigMenuScreen -Console $tc

                Should -Invoke Start-Process -Exactly 1 -ParameterFilter { $FilePath -eq 'notepad.exe' }
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
                Mock Show-ScreenshotConfigScreen     {}

                $tc = $script:tc
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
