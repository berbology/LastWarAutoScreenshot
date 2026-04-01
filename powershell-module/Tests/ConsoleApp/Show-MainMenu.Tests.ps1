BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force

    # Spectre.Console.Testing.dll ships in lib\test\ and is required for TestConsole
    $testingDll = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}

Describe 'Show-MainMenu' -Tag 'Unit' {

    BeforeEach {
        # Create a fresh TestConsole for each test to prevent output accumulation.
        InModuleScope 'LastWarAutoScreenshot' {
            $script:tc = [Spectre.Console.Testing.TestConsole]::new()
            $script:tc.Profile.Width  = $script:TestConsoleWidth
            $script:tc.Profile.Height = $script:TestConsoleHeight
            $script:tc.Profile.Capabilities.Interactive = $true
        }
    }

    Context 'When no macros are present (macro folder absent or empty)' {

        It 'Returns Configure when the first choice (Configure module) is confirmed' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)  # Confirm first highlighted item

                $result = Show-MainMenu -Console $tc
                $result | Should -Be 'Configure'
            }
        }

        It 'Returns RecordMacro when Record macro is selected (1 DownArrow)' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = $script:tc
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
                # Selectable order (no macros):
                # [0] Configure module, [1] Record macro, [2] Manage schedules,
                # [3] Storage info, [4] Exit
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-MainMenu -Console $tc
                $result | Should -Be 'Exit'
            }
        }

        It 'Output does not contain Run macro label when no macros are present' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-MainMenu -Console $tc | Out-Null
                $tc.Output | Should -Not -Match 'Run macro'
            }
        }

        It 'Output does not contain Select target window' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-MainMenu -Console $tc | Out-Null
                $tc.Output | Should -Not -Match 'Select target window'
            }
        }

        It 'Output always contains Record macro' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-MainMenu -Console $tc | Out-Null
                $tc.Output | Should -Match 'Record macro'
            }
        }

    }

    Context 'When macros are present' {

        It 'Returns RunMacro when Run macro is selected (2 DownArrows)' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockFile = [PSCustomObject]@{ Name = '20260101_120000_TestMacro.json' }
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $true }
                Mock Get-ChildItem -ParameterFilter { $Filter -eq '*.json' } -MockWith { @($mockFile) }

                $tc = $script:tc
                # Selectable order: [0] Configure module, [1] Record macro, [2] Run macro, ...
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
                # Selectable order (macros present): [0] Configure module, [1] Record macro,
                # [2] Run macro, [3] Manage macros, [4] Manage schedules, [5] Storage info, [6] Exit
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
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-MainMenu -Console $tc | Out-Null
                $tc.Output | Should -Match 'Run macro'
            }
        }

        It 'Run macro is shown even without a target window configured in the session' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockFile = [PSCustomObject]@{ Name = '20260101_120000_TestMacro.json' }
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $true }
                Mock Get-ChildItem -ParameterFilter { $Filter -eq '*.json' } -MockWith { @($mockFile) }

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-MainMenu -Console $tc | Out-Null
                $tc.Output | Should -Match 'Run macro'
            }
        }
    }

    Context 'Manage macros option' {

        It 'Manage macros option does not appear in output when no macros are present' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-MainMenu -Console $tc | Out-Null
                $tc.Output | Should -Not -Match 'Manage macros'
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
    }

    Context 'When the user selects Storage info' {

        It 'Returns StorageInfo when Storage info is selected with no macros present (3 DownArrows)' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = $script:tc
                # Selectable order (no macros): [0] Configure module, [1] Record macro,
                # [2] Manage schedules, [3] Storage info, [4] Exit
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-MainMenu -Console $tc
                $result | Should -Be 'StorageInfo'
            }
        }

        It 'Returns StorageInfo when Storage info is selected with macros present (5 DownArrows)' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockFile = [PSCustomObject]@{ Name = '20260101_120000_TestMacro.json' }
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $true }
                Mock Get-ChildItem -ParameterFilter { $Filter -eq '*.json' } -MockWith { @($mockFile) }

                $tc = $script:tc
                # Selectable order (macros present): [0] Configure module, [1] Record macro,
                # [2] Run macro, [3] Manage macros, [4] Manage schedules, [5] Storage info, [6] Exit
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-MainMenu -Console $tc
                $result | Should -Be 'StorageInfo'
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

    Context 'Manage schedules option' {

        It 'Output contains Manage schedules as a choice' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-MainMenu -Console $tc | Out-Null
                $tc.Output | Should -Match 'Manage schedules'
            }
        }

        It 'Navigating to Manage schedules renders the item and returns ManageSchedules (2 DownArrows, no macros)' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = $script:tc
                # Selectable order (no macros): [0] Configure module, [1] Record macro,
                # [2] Manage schedules, ...
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-MainMenu -Console $tc
                $result | Should -Be 'ManageSchedules'
                $tc.Output | Should -Match 'Manage schedules'
            }
        }
    }
}
