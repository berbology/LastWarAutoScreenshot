function Show-UploadProfilesScreen {
    <#
    .SYNOPSIS
        Displays the upload profiles management screen.

    .DESCRIPTION
        Renders a table of all configured upload profiles and a SelectionPrompt
        for managing them. Loops continuously until the user selects '[Back]'.

        When no profiles exist, an informational panel is shown in place of the table.

        Selection prompt choices:
          - Add profile                  → calls Show-EditUploadProfileScreen; reloads and
                                           redraws on return
          - Edit profile                 → shown only when at least one profile exists;
                                           presents a sub-prompt listing profile names plus
                                           'Cancel'; on selection calls
                                           Show-EditUploadProfileScreen with the chosen profile
          - Remove profile               → shown only when at least one profile exists; presents
                                           a sub-prompt listing profile names plus 'Cancel';
                                           on selection calls Remove-LWASUploadProfile
          - Update SAS tokens            → shown only when at least one profile exists; presents
                                           a sub-prompt listing profiles as
                                           "name (LWAS_SAS_VAR)" plus 'Cancel'; on selection
                                           calls Update-LWASUploadProfileSASToken for the
                                           chosen profile
          - Update all profile SAS tokens → shown only when at least one profile exists;
                                            calls Update-LWASUploadProfileSASToken for every
                                            profile in one pass and reports a summary
          - [Back]                       → exits the loop and returns $null

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for all rendering and input.
        Pass [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole() for production use,
        or a [Spectre.Console.Testing.TestConsole]::new() instance in Pester tests.

    .OUTPUTS
        $null

    .EXAMPLE
        $console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        Show-UploadProfilesScreen -Console $console

    .NOTES
        All profile data is reloaded from disk on every loop iteration so changes
        made by Show-EditUploadProfileScreen and Remove-LWASUploadProfile are
        immediately reflected.

        On each iteration, any profile whose sasTokenEnvVar does not yet exist as
        a User-scoped environment variable is given an empty placeholder via
        Set-LWASSasToken. This ensures the variable is present for all future
        sessions even before a real token has been stored.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    while ($true) {

        # Reload profiles from disk on every iteration
        $profiles = @(Get-UploadProfile)

        # Build a name→token lookup for quick validity display (no online check)
        $tokenMap = @{}
        foreach ($t in (Get-LWASSASToken)) {
            $tokenMap[$t.Name] = $t
        }

        # Ensure every profile has a User-scoped env var placeholder; create one if absent.
        foreach ($profile in $profiles) {
            if (-not $tokenMap.ContainsKey($profile.sasTokenEnvVar)) {
                Set-LWASSasToken -Name $profile.sasTokenEnvVar -Token ''
                $tokenMap[$profile.sasTokenEnvVar] = [PSCustomObject]@{
                    Name               = $profile.sasTokenEnvVar
                    Value              = ''
                    Valid              = $false
                    Validation         = $null
                    ValidationResponse = $null
                }
            }
        }

        # Build and render the profiles table
        $profileTable = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(
            @('Name', 'Account', 'Container', 'Env Var', 'Token Valid', 'Blob Pattern', 'Delete After (days)')
        )

        foreach ($userProfile in $profiles) {
            $tokenInfo  = $tokenMap[$userProfile.sasTokenEnvVar]
            $tokenValid = if ($null -ne $tokenInfo) { "$($tokenInfo.Valid)" } else { 'False' }

            [Spectre.Console.TableExtensions]::AddRow(
                $profileTable,
                [string[]]@(
                    [Spectre.Console.Markup]::Escape($userProfile.name),
                    [Spectre.Console.Markup]::Escape($userProfile.accountName),
                    [Spectre.Console.Markup]::Escape($userProfile.containerName),
                    [Spectre.Console.Markup]::Escape($userProfile.sasTokenEnvVar),
                    [Spectre.Console.Markup]::Escape($tokenValid),
                    [Spectre.Console.Markup]::Escape($userProfile.blobPathPattern),
                    "$($userProfile.deleteLocalAfterDays)"
                )
            ) | Out-Null
        }

        $Console.Write($profileTable)

        # Show info panel when no profiles are configured
        if ($profiles.Count -eq 0) {
            $infoPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                "No upload profiles configured. Select 'Add profile' to create one.",
                'Upload Profiles'
            )
            $Console.Write($infoPanel)
        }

        # Build selection prompt choices
        $menuChoices = [System.Collections.Generic.List[string]]::new()
        $menuChoices.Add('[[Back]]')
        $menuChoices.Add('Add profile')
        if ($profiles.Count -gt 0) {
            $menuChoices.Add('Edit profile')
            $menuChoices.Add('Remove profile')
            $menuChoices.Add('Update SAS tokens')
            $menuChoices.Add('Update all profile SAS tokens')
        }

        $prompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
            'Upload profiles:', $menuChoices.ToArray()
        )
        $selection = $prompt.Show($Console)

        switch ($selection) {

            'Add profile' {
                Show-EditUploadProfileScreen -Console $Console
            }

            'Edit profile' {
                $editChoices = [System.Collections.Generic.List[string]]::new()
                foreach ($p in $profiles) { $editChoices.Add($p.name) }
                $editChoices.Add('Cancel')

                $editPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                    'Select a profile to edit:', $editChoices.ToArray()
                )
                $editChoice = $editPrompt.Show($Console)

                $matchedProfile = $profiles | Where-Object { $_.name -eq $editChoice } | Select-Object -First 1
                if ($null -ne $matchedProfile) {
                    Show-EditUploadProfileScreen -Console $Console -ExistingProfile $matchedProfile
                }
            }

            'Remove profile' {
                $removeChoices = [System.Collections.Generic.List[string]]::new()
                foreach ($p in $profiles) { $removeChoices.Add($p.name) }
                $removeChoices.Add('Cancel')

                $removePrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                    'Select a profile to remove:', $removeChoices.ToArray()
                )
                $removeChoice = $removePrompt.Show($Console)

                $matchedProfile = $profiles | Where-Object { $_.name -eq $removeChoice } | Select-Object -First 1
                if ($null -ne $matchedProfile) {
                    Remove-LWASUploadProfile -Name $matchedProfile.name -Force
                }
            }

            'Update SAS tokens' {
                $updateChoices = [System.Collections.Generic.List[string]]::new()
                foreach ($p in $profiles) {
                    $updateChoices.Add("$($p.name) ($($p.sasTokenEnvVar))")
                }
                $updateChoices.Add('Cancel')

                $updatePrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                    'Select a profile to update its SAS token:', $updateChoices.ToArray()
                )
                $updateChoice = $updatePrompt.Show($Console)

                $matchedProfile = $null
                foreach ($p in $profiles) {
                    if ($updateChoice -eq "$($p.name) ($($p.sasTokenEnvVar))") {
                        $matchedProfile = $p
                        break
                    }
                }

                if ($null -ne $matchedProfile) {
                    $safeName     = [Spectre.Console.Markup]::Escape($matchedProfile.name)
                    $safeSasVar   = [Spectre.Console.Markup]::Escape($matchedProfile.sasTokenEnvVar)
                    $tokenUpdated = Update-LWASUploadProfileSASToken -Profile $matchedProfile

                    if ($tokenUpdated) {
                        $Console.Write([Spectre.Console.Markup]::new("[green]SAS token for '$safeName' updated and stored in '$safeSasVar'.[/]`n"))
                        Write-LastWarLog -Level Info `
                            -Message "SAS token for profile '$($matchedProfile.name)' updated via console." `
                            -FunctionName 'Show-UploadProfilesScreen'
                    } else {
                        $warnContent  = "SAS token for '$($matchedProfile.name)' could not be updated. Ensure you are connected to Azure (Connect-AzAccount)."
                        $warningPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                            $warnContent,
                            'SAS Token Warning'
                        )
                        $Console.Write($warningPanel)
                    }
                }
            }

            'Update all profile SAS tokens' {
                $successCount = 0
                $failCount    = 0

                foreach ($p in $profiles) {
                    $safeName     = [Spectre.Console.Markup]::Escape($p.name)
                    $safeSasVar   = [Spectre.Console.Markup]::Escape($p.sasTokenEnvVar)
                    $tokenUpdated = Update-LWASUploadProfileSASToken -Profile $p

                    if ($tokenUpdated) {
                        $successCount++
                        $Console.Write([Spectre.Console.Markup]::new("[green]SAS token for '$safeName' stored in '$safeSasVar'.[/]`n"))
                    } else {
                        $failCount++
                        $Console.Write([Spectre.Console.Markup]::new("[yellow]SAS token for '$safeName' could not be updated.[/]`n"))
                    }
                }

                Write-LastWarLog -Level Info `
                    -Message "Bulk SAS token update complete: $successCount succeeded, $failCount failed." `
                    -FunctionName 'Show-UploadProfilesScreen'

                $summaryPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                    "$successCount profile(s) updated successfully. $failCount profile(s) failed.",
                    'SAS Token Update Summary'
                )
                $Console.Write($summaryPanel)
            }

            default {
                # '[Back]' or any unrecognised value — exit the loop
                return $null
            }
        }
    }
}
