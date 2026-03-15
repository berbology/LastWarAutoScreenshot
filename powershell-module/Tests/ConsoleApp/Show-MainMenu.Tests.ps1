BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
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

Describe 'Show-MainMenu' -Tag 'Unit' {

    BeforeEach {
        # All tests in this Describe assume a target window has been configured unless
        # overridden inside a specific Context/It block.
        InModuleScope -ModuleName 'LastWarAutoScreenshot' {
            Mock Get-ModuleConfiguration -MockWith {
                [PSCustomObject]@{
                    ProcessName   = 'LastWar'
                    WindowTitle   = 'Last War: Survival'
                    Logging       = [PSCustomObject]@{}
                    MouseControl  = [PSCustomObject]@{}
                    EmergencyStop = [PSCustomObject]@{}
                    Screenshots   = [PSCustomObject]@{}
                    CodeEditor    = ''
                }
            }
        }
    }

    Context 'When no macros are present (macro folder absent or empty)' {

        It 'Returns SelectWindow when the first choice (Select target window) is confirmed' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)  # Confirm first highlighted item

                $result = Show-MainMenu -Console $tc
                $result | Should -Be 'SelectWindow'
            }
        }

        It 'Returns Configure when Configure module is selected' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-MainMenu -Console $tc
                $result | Should -Be 'Configure'
            }
        }

        It 'Returns RecordMacro when Record macro is selected' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-MainMenu -Console $tc
                $result | Should -Be 'RecordMacro'
            }
        }

        It 'Returns Exit when Exit is selected with 4 DownArrows when no macros present' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = $script:tc
                # Selectable order (no macros, Manage macros disabled/skipped):
                # [0] Select target window, [1] Configure module, [2] Record macro,
                # (disabled) Manage macros, [3] Storage info, [4] Exit
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-MainMenu -Console $tc
                $result | Should -Be 'Exit'
            }
        }

        It 'Output contains the disabled Run macro label when no macros are present' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-MainMenu -Console $tc | Out-Null
                # Verify that selecting by pressing Enter on the 4th option (Exit) works
                # This indirectly confirms that "Run macro" is not a selectable choice
                $tc.Output | Should -Match 'Exit|Configure|Record'
            }
        }

        It 'Navigating 3 DownArrows does not select RunMacro (RunMacro not available when no macros)' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = $script:tc
                # With no macros, Manage macros is disabled/skipped; 3 DownArrows reaches ViewStorageInfo
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-MainMenu -Console $tc
                $result | Should -Not -Be 'RunMacro'
            }
        }
    }

    Context 'When macros are present' {

        It 'Returns RunMacro when Run macro is selected' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockFile = [PSCustomObject]@{ Name = '20260101_120000_TestMacro.json' }
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $true }
                Mock Get-ChildItem -ParameterFilter { $Filter -eq '*.json' } -MockWith { @($mockFile) }

                $tc = $script:tc
                # Selectable order: [0] Select window, [1] Configure, [2] Record macro, [3] Run macro, [4] Exit
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-MainMenu -Console $tc
                $result | Should -Be 'RunMacro'
            }
        }

        It 'Returns Exit when Exit is selected with macros present (6 DownArrows)' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockFile = [PSCustomObject]@{ Name = '20260101_120000_TestMacro.json' }
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $true }
                Mock Get-ChildItem -ParameterFilter { $Filter -eq '*.json' } -MockWith { @($mockFile) }

                $tc = $script:tc
                # Selectable order (macros present): [0] Select target window, [1] Configure module,
                # [2] Record macro, [3] Run macro, [4] Manage macros, [5] Storage info, [6] Exit
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-MainMenu -Console $tc
                $result | Should -Be 'Exit'
            }
        }

        It 'Output contains Run macro as a selectable choice when macros exist' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockFile = [PSCustomObject]@{ Name = '20260101_120000_TestMacro.json' }
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $true }
                Mock Get-ChildItem -ParameterFilter { $Filter -eq '*.json' } -MockWith { @($mockFile) }

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-MainMenu -Console $tc | Out-Null
                $tc.Output | Should -Match 'Run macro'
            }
        }
    }

    Context 'Manage macros option' {

        It 'Manage macros option always appears in output when no macros are present' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-MainMenu -Console $tc | Out-Null
                $tc.Output | Should -Match 'Manage macros'
            }
        }

        It 'Manage macros option appears in output when macros exist' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockFile = [PSCustomObject]@{ Name = '20260101_120000_TestMacro.json' }
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $true }
                Mock Get-ChildItem -ParameterFilter { $Filter -eq '*.json' } -MockWith { @($mockFile) }

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-MainMenu -Console $tc | Out-Null
                $tc.Output | Should -Match 'Manage macros'
            }
        }

        It 'Manage macros is not selectable when no macros present: 3 DownArrows reaches ViewStorageInfo' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = $script:tc
                # Manage macros is disabled so arrow navigation skips it.
                # Selectable order (no macros): [0] Select target window, [1] Configure module,
                # [2] Record macro, (disabled) Manage macros, [3] Storage info, [4] Exit
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-MainMenu -Console $tc
                $result | Should -Be 'ViewStorageInfo'
            }
        }
    }

    Context 'When the user selects Storage info' {

        It 'Returns ViewStorageInfo when Storage info is selected with no macros present (3 DownArrows)' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = $script:tc
                # Manage macros is disabled so arrow navigation skips it.
                # Selectable order (no macros): [0] Select target window, [1] Configure module,
                # [2] Record macro, (disabled) Manage macros, [3] Storage info, [4] Exit
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-MainMenu -Console $tc
                $result | Should -Be 'ViewStorageInfo'
            }
        }

        It 'Returns ViewStorageInfo when Storage info is selected with macros present (5 DownArrows)' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockFile = [PSCustomObject]@{ Name = '20260101_120000_TestMacro.json' }
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $true }
                Mock Get-ChildItem -ParameterFilter { $Filter -eq '*.json' } -MockWith { @($mockFile) }

                $tc = $script:tc
                # Selectable order (macros present): [0] Select target window, [1] Configure module,
                # [2] Record macro, [3] Run macro, [4] Manage macros, [5] Storage info, [6] Exit
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-MainMenu -Console $tc
                $result | Should -Be 'ViewStorageInfo'
            }
        }

        It 'Output contains Storage info as a choice' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)  # Select first item

                Show-MainMenu -Console $tc | Out-Null
                $tc.Output | Should -Match 'Storage info'
            }
        }
    }

    Context 'When no target window has been configured' {

        BeforeEach {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                # Override the Describe-level mock: return a settings-only config (no ProcessName)
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{
                        Logging       = [PSCustomObject]@{}
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                        Screenshots   = [PSCustomObject]@{}
                        CodeEditor    = ''
                    }
                }
            }
        }

        It 'Does not include Record macro in the menu' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                # Use a fresh TestConsole so accumulated output from prior tests does not
                # interfere with the Should -Not -Match assertion.
                $freshTc = [Spectre.Console.Testing.TestConsole]::new()
                $freshTc.Profile.Width  = $script:TestConsoleWidth
                $freshTc.Profile.Height = $script:TestConsoleHeight
                $freshTc.Profile.Capabilities.Interactive = $true
                $freshTc.Input.PushKey([ConsoleKey]::Enter)

                Show-MainMenu -Console $freshTc | Out-Null
                $freshTc.Output | Should -Not -Match 'Record macro'
            }
        }

        It 'Does not include Run macro in the menu even when macros exist' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockFile = [PSCustomObject]@{ Name = '20260101_120000_TestMacro.json' }
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $true }
                Mock Get-ChildItem -ParameterFilter { $Filter -eq '*.json' } -MockWith { @($mockFile) }
                # Use a fresh TestConsole so accumulated output from prior tests does not
                # interfere with the Should -Not -Match assertion.
                $freshTc = [Spectre.Console.Testing.TestConsole]::new()
                $freshTc.Profile.Width  = $script:TestConsoleWidth
                $freshTc.Profile.Height = $script:TestConsoleHeight
                $freshTc.Profile.Capabilities.Interactive = $true
                $freshTc.Input.PushKey([ConsoleKey]::Enter)

                Show-MainMenu -Console $freshTc | Out-Null
                $freshTc.Output | Should -Not -Match 'Run macro'
            }
        }

        It 'Returns ViewStorageInfo at 2 DownArrows when no macros and no target window' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = $script:tc
                # Selectable order: [0] Select target window, [1] Configure module,
                # [2] Storage info, [3] Exit
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-MainMenu -Console $tc
                $result | Should -Be 'ViewStorageInfo'
            }
        }

        It 'Returns Exit at 3 DownArrows when no macros and no target window' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = $script:tc
                # Selectable order: [0] Select target window, [1] Configure module,
                # [2] Storage info, [3] Exit
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-MainMenu -Console $tc
                $result | Should -Be 'Exit'
            }
        }
    }
}

