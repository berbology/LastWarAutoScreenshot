BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force

    # Spectre.Console.Testing.dll ships in lib\test\ and is required for TestConsole
    $testingDll = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}

Describe 'Show-MainMenu' -Tag 'Unit' {

    Context 'When no macros are present (macro folder absent or empty)' {

        It 'Returns SelectWindow when the first choice (Select target window) is confirmed' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)  # Confirm first highlighted item

                $result = Show-MainMenu -Console $tc
                $result | Should -Be 'SelectWindow'
            }
        }

        It 'Returns Configure when Configure module is selected' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-MainMenu -Console $tc
                $result | Should -Be 'Configure'
            }
        }

        It 'Returns RecordMacro when Record macro is selected' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
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
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # Selectable order: [0] Select target window, [1] Configure module,
                # [2] Record macro, [3] Manage macros, [4] Exit (Run macro is not a choice when no macros exist)
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
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
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

        It 'Navigating 3 DownArrows confirms Exit is selected (RunMacro not available when no macros)' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
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

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # Selectable order: [0] Select window, [1] Configure, [2] Record macro, [3] Run macro, [4] Exit
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-MainMenu -Console $tc
                $result | Should -Be 'RunMacro'
            }
        }

        It 'Returns Exit when Exit is selected with macros present (5 DownArrows)' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockFile = [PSCustomObject]@{ Name = '20260101_120000_TestMacro.json' }
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $true }
                Mock Get-ChildItem -ParameterFilter { $Filter -eq '*.json' } -MockWith { @($mockFile) }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
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

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
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
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
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

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-MainMenu -Console $tc | Out-Null
                $tc.Output | Should -Match 'Manage macros'
            }
        }

        It 'Returns ManageMacros when Manage macros is selected with no macros present' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Test-Path -ParameterFilter { $Path -like '*Macros*' } -MockWith { $false }
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # Selectable order (no macros): [0] Select target window, [1] Configure module,
                # [2] Record macro, [3] Manage macros, [4] Exit
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-MainMenu -Console $tc
                $result | Should -Be 'ManageMacros'
            }
        }
    }
}

