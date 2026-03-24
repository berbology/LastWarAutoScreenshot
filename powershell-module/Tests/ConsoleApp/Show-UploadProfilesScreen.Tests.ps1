BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force

    # Spectre.Console.Testing.dll ships in lib\test\ and is required for TestConsole
    $testingDll = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}

Describe 'Show-UploadProfilesScreen' -Tag 'Unit' {

    BeforeEach {
        InModuleScope 'LastWarAutoScreenshot' {
            $script:tc = [Spectre.Console.Testing.TestConsole]::new()
            $script:tc.Profile.Width  = $script:TestConsoleWidth
            $script:tc.Profile.Height = $script:TestConsoleHeight
            $script:tc.Profile.Capabilities.Interactive = $true
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context 9.3.1: No profiles exist
    # ════════════════════════════════════════════════════════════════════════
    Context 'When no profiles are configured' {

        It 'Output contains "No upload profiles configured"' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-UploadProfile { @() }
                Mock Show-EditUploadProfileScreen {}
                Mock Remove-UploadProfileFile {}

                $tc = $script:tc
                # Choices: [0] [Back], [1] Add profile — select [Back] (Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-UploadProfilesScreen -Console $tc

                $tc.Output | Should -Match 'No upload profiles configured'
            }
        }

        It 'Output does not contain "Remove profile" when no profiles exist' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-UploadProfile { @() }
                Mock Show-EditUploadProfileScreen {}
                Mock Remove-UploadProfileFile {}

                $tc = $script:tc
                # Choices: [0] [Back], [1] Add profile — select [Back] (Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-UploadProfilesScreen -Console $tc

                $tc.Output | Should -Not -Match 'Remove profile'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context 9.3.2: Two profiles exist
    # ════════════════════════════════════════════════════════════════════════
    Context 'When two profiles are configured' {

        It 'Table output contains both profile names and "Remove profile" choice is present' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-UploadProfile {
                    @(
                        [PSCustomObject]@{
                            name                   = 'profile-alpha'
                            accountName            = 'accountA'
                            containerName          = 'containerA'
                            sasTokenEnvVar         = 'LWAS_SAS_A'
                            blobPathPattern        = '{MacroName}/{Date}/{Filename}'
                            deleteLocalAfterDays   = 30
                        },
                        [PSCustomObject]@{
                            name                   = 'profile-beta'
                            accountName            = 'accountB'
                            containerName          = 'containerB'
                            sasTokenEnvVar         = 'LWAS_SAS_B'
                            blobPathPattern        = '{MacroName}/{Date}/{Filename}'
                            deleteLocalAfterDays   = 14
                        }
                    )
                }
                Mock Show-EditUploadProfileScreen {}
                Mock Remove-UploadProfileFile {}

                $tc = $script:tc
                # Choices: [0] [Back], [1] Add profile, [2] Remove profile — select [Back] (Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-UploadProfilesScreen -Console $tc

                $tc.Output | Should -Match 'profile-alpha'
                $tc.Output | Should -Match 'profile-beta'
                $tc.Output | Should -Match 'Remove profile'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context 9.3.3: User selects Add profile
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user selects Add profile' {

        It 'Calls Show-EditUploadProfileScreen exactly once' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-UploadProfile { @() }
                Mock Show-EditUploadProfileScreen {}
                Mock Remove-UploadProfileFile {}

                $tc = $script:tc
                # First iteration: [1] Add profile — 1 down + Enter
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second iteration (loop returns to menu): [0] [Back] — Enter
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-UploadProfilesScreen -Console $tc

                Should -Invoke Show-EditUploadProfileScreen -Exactly 1
            }
        }

        It 'Passes the same Console instance to Show-EditUploadProfileScreen' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-UploadProfile { @() }
                Mock Show-EditUploadProfileScreen {}
                Mock Remove-UploadProfileFile {}

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-UploadProfilesScreen -Console $tc

                Should -Invoke Show-EditUploadProfileScreen -Exactly 1 -ParameterFilter { $Console -eq $tc }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context 9.3.4: User selects Remove profile then selects a profile name
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user selects Remove profile then selects a profile name' {

        It 'Calls Remove-UploadProfileFile with the selected profile name' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-UploadProfile {
                    @(
                        [PSCustomObject]@{
                            name                   = 'profile-one'
                            accountName            = 'acc1'
                            containerName          = 'ctr1'
                            sasTokenEnvVar         = 'LWAS_SAS_1'
                            blobPathPattern        = '{MacroName}/{Date}/{Filename}'
                            deleteLocalAfterDays   = 30
                        },
                        [PSCustomObject]@{
                            name                   = 'profile-two'
                            accountName            = 'acc2'
                            containerName          = 'ctr2'
                            sasTokenEnvVar         = 'LWAS_SAS_2'
                            blobPathPattern        = '{MacroName}/{Date}/{Filename}'
                            deleteLocalAfterDays   = 7
                        }
                    )
                }
                Mock Show-EditUploadProfileScreen {}
                Mock Remove-UploadProfileFile {}

                $tc = $script:tc
                # Choices: [0] [Back], [1] Add profile, [2] Remove profile
                # Select Remove profile (index 2): 2 downs + Enter
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Remove sub-prompt: [0] profile-one, [1] profile-two, [2] Cancel
                # Select profile-one (index 0): Enter
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Back to main prompt (loop re-runs): [0] [Back] — Enter
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-UploadProfilesScreen -Console $tc

                Should -Invoke Remove-UploadProfileFile -Exactly 1 -ParameterFilter {
                    $Name -eq 'profile-one'
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context 9.3.5: User selects [Back]
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user selects [Back]' {

        It 'Returns $null' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-UploadProfile { @() }
                Mock Show-EditUploadProfileScreen {}
                Mock Remove-UploadProfileFile {}

                $tc = $script:tc
                # Choices: [0] [Back], [1] Add profile — select [Back] (Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-UploadProfilesScreen -Console $tc

                $result | Should -BeNullOrEmpty
            }
        }
    }
}
