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
        # Clean up any leftover SAS tokens from previous test runs using the proper cleanup function
        @('LWAS_SAS_TOKEN', 'LWAS_SAS_EXISTING', 'LWAS_SAS_NEW') | ForEach-Object {
            try {
                Remove-LWASSasToken -Name $_ -ErrorAction SilentlyContinue
            } catch {
                # Variable might not exist; that's fine
            }
        }
        InModuleScope 'LastWarAutoScreenshot' {
            $script:tc = [Spectre.Console.Testing.TestConsole]::new()
            $script:tc.Profile.Width  = $script:TestConsoleWidth
            $script:tc.Profile.Height = $script:TestConsoleHeight
            $script:tc.Profile.Capabilities.Interactive = $true
            Mock Get-LWASSASToken { @() }
            Mock Test-LWASSASTokenIsValid { $true }
            Mock Update-LWASSASToken { $true }
        }
    }

    AfterEach {
        # Clean up any SAS tokens created during tests using the proper cleanup function
        @('LWAS_SAS_TOKEN', 'LWAS_SAS_EXISTING', 'LWAS_SAS_NEW') | ForEach-Object {
            try {
                Remove-LWASSasToken -Name $_ -ErrorAction SilentlyContinue
            } catch {
                # Variable might not exist; that's fine
            }
        }
    }

    # Helper: push all field inputs for a successful profile creation.
    # Inputs:  Name, Account, Container, SasEnvVar, BlobPattern (empty=default),
    #          MaxRetry (empty=3), RetryDelay (empty=500), DeleteLocal (N),
    #          DeleteAfterDays (empty=30).
    # Does NOT push the confirmation key — caller supplies that.

    # All fields entered successfully
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
                # Resource group
                $tc.Input.PushText('my-rg')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Container
                $tc.Input.PushText('mycontainer')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # SAS token suffix — becomes LWAS_SAS_TOKEN
                $tc.Input.PushText('TOKEN')
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
                    $UploadProfile.name           -eq 'my-profile'     -and
                    $UploadProfile.accountName    -eq 'myaccount'      -and
                    $UploadProfile.containerName  -eq 'mycontainer'    -and
                    $UploadProfile.sasTokenEnvVar -eq 'LWAS_SAS_TOKEN' -and
                    $UploadProfile.cloudProvider  -eq 'azure'
                }
            }
        }
    }

    # Duplicate name causes prompt to loop
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
                $tc.Input.PushText('my-rg')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('ctr')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('TOKEN')
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
                    $UploadProfile.name -eq 'new-profile'
                }
            }
        }
    }

    # Empty blob path pattern uses default
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
                $tc.Input.PushText('my-rg')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('ctr')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('TOKEN')
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
                    $UploadProfile.blobPathPattern -eq '{MacroName}/{Date}/{Filename}'
                }
            }
        }
    }

    # User selects Cancel at the confirmation prompt
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
                $tc.Input.PushText('my-rg')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('ctr')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('TOKEN')
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

    # When no existing LWAS_SAS_* environment variables exist
    Context 'When no existing LWAS_SAS_* environment variables exist' {

        It 'Shows the info panel and prompts for a suffix to create a new variable' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ValidMacroName {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Get-UploadProfile { $null }
                Mock Save-UploadProfileFile {}
                Mock Write-LastWarLog {}
                Mock Get-LWASSASToken { @() }
                Mock Test-LWASSASTokenIsValid { $true }

                $tc = $script:tc

                $tc.Input.PushText('info-panel-test')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('acct')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('my-rg')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('ctr')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Suffix — becomes LWAS_SAS_TOKEN
                $tc.Input.PushText('TOKEN')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)  # blob pattern
                $tc.Input.PushKey([ConsoleKey]::Enter)  # max retry
                $tc.Input.PushKey([ConsoleKey]::Enter)  # retry delay
                $tc.Input.PushText('N')
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete local
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete after days
                # Cancel
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-EditUploadProfileScreen -Console $tc

                $tc.Output | Should -Match 'No LWAS_SAS'
                $tc.Output | Should -Match 'LWAS_SAS_TOKEN'
            }
        }
    }

    # When existing LWAS_SAS_* environment variables exist
    Context 'When existing LWAS_SAS_* environment variables exist' {

        It '5.4.2: Shows existing var names and Create new in the selection prompt' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ValidMacroName {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Get-UploadProfile { $null }
                Mock Save-UploadProfileFile {}
                Mock Write-LastWarLog {}
                Mock Get-LWASSASToken { @(
                    [PSCustomObject]@{ Name = 'LWAS_SAS_PROD'; Value = ''; Valid = $false },
                    [PSCustomObject]@{ Name = 'LWAS_SAS_DEV';  Value = ''; Valid = $false }
                ) }
                Mock Test-LWASSASTokenIsValid { $true }
                Mock Update-LWASSASToken { $true }

                $tc = $script:tc

                $tc.Input.PushText('selection-test')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('acct')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('my-rg')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('ctr')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Select first item: LWAS_SAS_PROD
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)  # blob pattern
                $tc.Input.PushKey([ConsoleKey]::Enter)  # max retry
                $tc.Input.PushKey([ConsoleKey]::Enter)  # retry delay
                $tc.Input.PushText('N')
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete local
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete after days
                # Cancel
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-EditUploadProfileScreen -Console $tc

                $tc.Output | Should -Match 'LWAS_SAS_PROD'
                $tc.Output | Should -Match 'LWAS_SAS_DEV'
                $tc.Output | Should -Match 'Create new'
            }
        }

        It 'Uses the selected existing variable and skips the suffix prompt' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ValidMacroName {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Get-UploadProfile { $null }
                Mock Save-UploadProfileFile {}
                Mock Write-LastWarLog {}
                Mock Get-LWASSASToken { @([PSCustomObject]@{ Name = 'LWAS_SAS_PROD'; Value = ''; Valid = $false }) }
                Mock Test-LWASSASTokenIsValid { $true }
                Mock Update-LWASSASToken { $true }

                $tc = $script:tc

                $tc.Input.PushText('existing-var-test')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('acct')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('my-rg')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('ctr')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Select LWAS_SAS_PROD (first item)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # No suffix input — suffix prompt is skipped
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
                    $UploadProfile.sasTokenEnvVar -eq 'LWAS_SAS_PROD'
                }
                $tc.Output | Should -Not -Match 'unique suffix'
            }
        }

        It 'Shows the suffix prompt when Create new is selected' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ValidMacroName {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Get-UploadProfile { $null }
                Mock Save-UploadProfileFile {}
                Mock Write-LastWarLog {}
                Mock Get-LWASSASToken {
                    if ([string]::IsNullOrEmpty($Name)) {
                        @([PSCustomObject]@{ Name = 'LWAS_SAS_PROD'; Value = ''; Valid = $false })
                    } else {
                        @()
                    }
                }
                Mock Test-LWASSASTokenIsValid { $true }

                $tc = $script:tc

                $tc.Input.PushText('create-new-test')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('acct')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('my-rg')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('ctr')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Navigate to Create new (index 1) and select it
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Enter suffix
                $tc.Input.PushText('TOKEN')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)  # blob pattern
                $tc.Input.PushKey([ConsoleKey]::Enter)  # max retry
                $tc.Input.PushKey([ConsoleKey]::Enter)  # retry delay
                $tc.Input.PushText('N')
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete local
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete after days
                # Cancel
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-EditUploadProfileScreen -Console $tc

                $tc.Output | Should -Match 'unique suffix'
            }
        }
    }

    # Suffix validation
    Context 'When entering a new suffix' {

        AfterEach {
            Remove-Item -Path 'Env:\LWAS_SAS_EXISTING' -ErrorAction SilentlyContinue
            Remove-Item -Path 'Env:\LWAS_SAS_NEW' -ErrorAction SilentlyContinue
        }

        It '5.4.5: Shows a red error on invalid suffix characters and re-prompts' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ValidMacroName {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Get-UploadProfile { $null }
                Mock Save-UploadProfileFile {}
                Mock Write-LastWarLog {}
                Mock Get-LWASSASToken { @() }
                Mock Test-LWASSASTokenIsValid { $true }

                $tc = $script:tc

                $tc.Input.PushText('invalid-suffix-test')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('acct')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('my-rg')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('ctr')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('my-container')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Invalid suffix (contains space) — causes error and re-prompt
                $tc.Input.PushText('MY SUFFIX')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Valid suffix on second attempt
                $tc.Input.PushText('TOKEN')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)  # blob pattern
                $tc.Input.PushKey([ConsoleKey]::Enter)  # max retry
                $tc.Input.PushKey([ConsoleKey]::Enter)  # retry delay
                $tc.Input.PushText('N')
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete local
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete after days
                # Cancel
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-EditUploadProfileScreen -Console $tc

                $tc.Output | Should -Match 'letters, digits, and underscores'
            }
        }

        It 'Shows a red error when the suffix produces an already-existing variable name' {
            $env:LWAS_SAS_EXISTING = 'sv=fake'

            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ValidMacroName {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Get-UploadProfile { $null }
                Mock Save-UploadProfileFile {}
                Mock Write-LastWarLog {}
                Mock Get-LWASSASToken {
                    if ($Name -eq 'LWAS_SAS_EXISTING') {
                        @([PSCustomObject]@{ Name = 'LWAS_SAS_EXISTING'; Value = 'sv=fake'; Valid = $false })
                    } else {
                        @()
                    }
                }
                Mock Test-LWASSASTokenIsValid { $true }

                $tc = $script:tc

                $tc.Input.PushText('collision-test')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('acct')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('my-rg')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('ctr')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('my-container')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Suffix that collides with LWAS_SAS_EXISTING
                $tc.Input.PushText('EXISTING')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Non-colliding suffix on second attempt
                $tc.Input.PushText('NEW')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)  # blob pattern
                $tc.Input.PushKey([ConsoleKey]::Enter)  # max retry
                $tc.Input.PushKey([ConsoleKey]::Enter)  # retry delay
                $tc.Input.PushText('N')
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete local
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete after days
                # Cancel
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-EditUploadProfileScreen -Console $tc

                $tc.Output | Should -Match 'already exists'
            }
        }
    }

        It 'Strips LWAS_SAS_ prefix when user types the full variable name as suffix' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ValidMacroName {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Get-UploadProfile { $null }
                Mock Save-UploadProfileFile {}
                Mock Write-LastWarLog {}
                Mock Get-LWASSASToken { @() }
                Mock Test-LWASSASTokenIsValid { $true }
                Mock Update-LWASSASToken { $true }

                $tc = $script:tc

                $tc.Input.PushText('prefix-strip-test')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('acct')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('my-rg')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('ctr')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # User types the full variable name including the LWAS_SAS_ prefix
                $tc.Input.PushText('LWAS_SAS_TOKEN')
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

                # The saved profile must use LWAS_SAS_TOKEN, not LWAS_SAS_LWAS_SAS_TOKEN
                Should -Invoke Save-UploadProfileFile -Exactly 1 -ParameterFilter {
                    $UploadProfile.sasTokenEnvVar -eq 'LWAS_SAS_TOKEN'
                }
            }
        }
    }

    # Save path — auto-token logic
    Context 'When saving the profile' {

        It 'Does not call Update-LWASSASToken when the token is already valid' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ValidMacroName {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Get-UploadProfile { $null }
                Mock Save-UploadProfileFile {}
                Mock Write-LastWarLog {}
                Mock Get-LWASSASToken { @() }
                Mock Test-LWASSASTokenIsValid { $true }
                Mock Update-LWASSASToken { $true }

                $tc = $script:tc

                $tc.Input.PushText('valid-token-test')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('acct')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('my-rg')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('ctr')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('TOKEN')
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

                Should -Not -Invoke Update-LWASSASToken
            }
        }

        It 'Calls Update-LWASSASToken exactly once when the token is absent or expired' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ValidMacroName {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Get-UploadProfile { $null }
                Mock Save-UploadProfileFile {}
                Mock Write-LastWarLog {}
                Mock Get-LWASSASToken { @() }
                Mock Test-LWASSASTokenIsValid { $false }
                Mock Update-LWASSASToken { $true }

                $tc = $script:tc

                $tc.Input.PushText('expired-token-test')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('acct')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('my-rg')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('ctr')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('TOKEN')
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

                Should -Invoke Update-LWASSASToken -Exactly 1
            }
        }

        It 'Shows a warning panel containing Connect-AzAccount when Update returns false' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ValidMacroName {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Get-UploadProfile { $null }
                Mock Save-UploadProfileFile {}
                Mock Write-LastWarLog {}
                Mock Get-LWASSASToken { @() }
                Mock Test-LWASSASTokenIsValid { $false }
                Mock Update-LWASSASToken { $false }

                $tc = $script:tc

                $tc.Input.PushText('update-fail-test')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('acct')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('my-rg')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('ctr')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('TOKEN')
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

                $tc.Output | Should -Match 'Connect-AzAccount'
            }
        }

        It 'Shows a green success message containing the env var name when Update returns true' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ValidMacroName {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Get-UploadProfile { $null }
                Mock Save-UploadProfileFile {}
                Mock Write-LastWarLog {}
                Mock Get-LWASSASToken { @() }
                Mock Test-LWASSASTokenIsValid { $false }
                Mock Update-LWASSASToken { $true }

                $tc = $script:tc

                $tc.Input.PushText('update-ok-test')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('acct')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('my-rg')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('ctr')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('TOKEN')
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

                $tc.Output | Should -Match 'SAS token updated'
                $tc.Output | Should -Match 'LWAS_SAS_TOKEN'
            }
        }

        It 'Saves the profile with cloudProvider set to azure' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ValidMacroName {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Get-UploadProfile { $null }
                Mock Save-UploadProfileFile {}
                Mock Write-LastWarLog {}
                Mock Get-LWASSASToken { @() }
                Mock Test-LWASSASTokenIsValid { $true }
                Mock Update-LWASSASToken { $true }

                $tc = $script:tc

                $tc.Input.PushText('cloud-provider-test')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('acct')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('my-rg')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('ctr')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('TOKEN')
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
                    $UploadProfile.cloudProvider -eq 'azure'
                }
            }
        }
    }

    # Summary panel validity indicator
    Context 'When showing the summary panel' {

        It 'Shows (Will be requested on save) when the token is absent or expired' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ValidMacroName {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Get-UploadProfile { $null }
                Mock Save-UploadProfileFile {}
                Mock Write-LastWarLog {}
                Mock Get-LWASSASToken { @() }
                Mock Test-LWASSASTokenIsValid { $false }

                $tc = $script:tc

                $tc.Input.PushText('validity-false-test')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('acct')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('my-rg')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('ctr')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('TOKEN')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)  # blob pattern
                $tc.Input.PushKey([ConsoleKey]::Enter)  # max retry
                $tc.Input.PushKey([ConsoleKey]::Enter)  # retry delay
                $tc.Input.PushText('N')
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete local
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete after days
                # Cancel — only summary is shown, save path not executed
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-EditUploadProfileScreen -Console $tc

                $tc.Output | Should -Match 'Will be requested on save'
            }
        }

        It 'Shows (Valid) when the token passes Test-LWASSASTokenIsValid' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ValidMacroName {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Get-UploadProfile { $null }
                Mock Save-UploadProfileFile {}
                Mock Write-LastWarLog {}
                Mock Get-LWASSASToken { @() }
                Mock Test-LWASSASTokenIsValid { $true }

                $tc = $script:tc

                $tc.Input.PushText('validity-true-test')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('acct')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('my-rg')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('ctr')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('TOKEN')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)  # blob pattern
                $tc.Input.PushKey([ConsoleKey]::Enter)  # max retry
                $tc.Input.PushKey([ConsoleKey]::Enter)  # retry delay
                $tc.Input.PushText('N')
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete local
                $tc.Input.PushKey([ConsoleKey]::Enter)  # delete after days
                # Cancel — only summary is shown, save path not executed
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-EditUploadProfileScreen -Console $tc

                $tc.Output | Should -Match '\(Valid\)'
            }
        }
    }
