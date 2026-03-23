BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force

    # Spectre.Console.Testing.dll ships in lib\test\ and is required for TestConsole
    $testingDll = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}

Describe 'Show-EditUploadProfileScreen' -Tag 'Unit' {

    BeforeEach {
        InModuleScope 'LastWarAutoScreenshot' {
            $script:tc = [Spectre.Console.Testing.TestConsole]::new()
            $script:tc.Profile.Width  = $script:TestConsoleWidth
            $script:tc.Profile.Height = $script:TestConsoleHeight
            $script:tc.Profile.Capabilities.Interactive = $true
        }
    }

    # Helper: push all field inputs for a successful profile creation.
    # Inputs:  Name, Account, Container, SasEnvVar, BlobPattern (empty=default),
    #          MaxRetry (empty=3), RetryDelay (empty=500), DeleteLocal (N),
    #          DeleteAfterDays (empty=30).
    # Does NOT push the confirmation key — caller supplies that.

    # ════════════════════════════════════════════════════════════════════════
    # Context 9.4.1: All fields entered successfully
    # ════════════════════════════════════════════════════════════════════════
    Context 'When all fields are entered successfully' {

        It 'Calls Save-UploadProfileFile once with the entered values' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ValidMacroName {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Get-UploadProfile { $null }
                Mock Save-UploadProfileFile {}
                Mock Write-LastWarLog {}

                $tc = $script:tc

                # Name
                $tc.Input.PushText('my-profile')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Account
                $tc.Input.PushText('myaccount')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Container
                $tc.Input.PushText('mycontainer')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # SAS env var
                $tc.Input.PushText('LWAS_SAS_TOKEN')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Blob path (empty = default)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Max retry (empty = 3)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Retry delay (empty = 500)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Delete local after upload (N = false)
                $tc.Input.PushText('N')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Delete after days (empty = 30)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Confirm: [0] Yes — Enter
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-EditUploadProfileScreen -Console $tc

                Should -Invoke Save-UploadProfileFile -Exactly 1 -ParameterFilter {
                    $Profile.name          -eq 'my-profile'  -and
                    $Profile.accountName   -eq 'myaccount'   -and
                    $Profile.containerName -eq 'mycontainer' -and
                    $Profile.sasTokenEnvVar -eq 'LWAS_SAS_TOKEN'
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context 9.4.2: Duplicate name causes prompt to loop
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the first name entered is a duplicate' {

        It 'Re-prompts for name and calls Save-UploadProfileFile only after a unique name is entered' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ValidMacroName {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                $script:nameCheckCount = 0
                Mock Get-UploadProfile {
                    $script:nameCheckCount++
                    if ($script:nameCheckCount -eq 1) {
                        # Simulate duplicate on first uniqueness check
                        return [PSCustomObject]@{ name = $Name }
                    }
                    return $null
                }
                Mock Save-UploadProfileFile {}
                Mock Write-LastWarLog {}

                $tc = $script:tc

                # First name attempt — will fail uniqueness check
                $tc.Input.PushText('existing-profile')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second name attempt — will succeed
                $tc.Input.PushText('new-profile')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Remaining fields (all defaults)
                $tc.Input.PushText('acct')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('ctr')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('LWAS_SAS')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)  # blob pattern
                $tc.Input.PushKey([ConsoleKey]::Enter)  # max retry
                $tc.Input.PushKey([ConsoleKey]::Enter)  # retry delay
                $tc.Input.PushText('N')
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete local
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete after days
                # Confirm: Yes
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-EditUploadProfileScreen -Console $tc

                Should -Invoke Save-UploadProfileFile -Exactly 1 -ParameterFilter {
                    $Profile.name -eq 'new-profile'
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context 9.4.3: Empty blob path pattern uses default
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the blob path pattern field is left empty' {

        It 'Saves the profile with the default blob path pattern' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ValidMacroName {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Get-UploadProfile { $null }
                Mock Save-UploadProfileFile {}
                Mock Write-LastWarLog {}

                $tc = $script:tc

                $tc.Input.PushText('blob-pattern-test')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('acct')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('ctr')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('LWAS_SAS')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Empty blob path pattern — press Enter without typing
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)  # max retry
                $tc.Input.PushKey([ConsoleKey]::Enter)  # retry delay
                $tc.Input.PushText('N')
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete local
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete after days
                # Confirm: Yes
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-EditUploadProfileScreen -Console $tc

                Should -Invoke Save-UploadProfileFile -Exactly 1 -ParameterFilter {
                    $Profile.blobPathPattern -eq '{MacroName}/{Date}/{Filename}'
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context 9.4.4: User selects Cancel at the confirmation prompt
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user selects Cancel at the confirmation prompt' {

        It 'Does not call Save-UploadProfileFile and returns $null' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ValidMacroName {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Get-UploadProfile { $null }
                Mock Save-UploadProfileFile {}
                Mock Write-LastWarLog {}

                $tc = $script:tc

                $tc.Input.PushText('cancel-test')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('acct')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('ctr')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('LWAS_SAS')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)  # blob pattern
                $tc.Input.PushKey([ConsoleKey]::Enter)  # max retry
                $tc.Input.PushKey([ConsoleKey]::Enter)  # retry delay
                $tc.Input.PushText('N')
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete local
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete after days
                # Confirm: [1] Cancel — 1 down + Enter
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-EditUploadProfileScreen -Console $tc

                Should -Not -Invoke Save-UploadProfileFile
                $result | Should -BeNullOrEmpty
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context 9.4.5: Env var guidance panel appears in output
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the SAS token env var is entered' {

        It 'Writes the env var guidance panel to the console output' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ValidMacroName {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Get-UploadProfile { $null }
                Mock Save-UploadProfileFile {}
                Mock Write-LastWarLog {}

                $tc = $script:tc

                $tc.Input.PushText('guidance-test')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('acct')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('ctr')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('LWAS_SAS_TOKEN')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)  # blob pattern
                $tc.Input.PushKey([ConsoleKey]::Enter)  # max retry
                $tc.Input.PushKey([ConsoleKey]::Enter)  # retry delay
                $tc.Input.PushText('N')
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete local
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete after days
                # Cancel to keep test focused on output assertion
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-EditUploadProfileScreen -Console $tc

                $tc.Output | Should -Match 'Set the env var before running uploads'
                $tc.Output | Should -Match 'LWAS_SAS_TOKEN'
            }
        }
    }
}
