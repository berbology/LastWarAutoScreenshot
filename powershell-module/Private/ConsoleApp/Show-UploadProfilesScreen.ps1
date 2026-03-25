function Show-UploadProfilesScreen {
    <#
    .SYNOPSIS
        Displays the upload profiles management screen.

    .DESCRIPTION
        Renders a table of all configured upload profiles and a SelectionPrompt
        for managing them. Loops continuously until the user selects '[Back]'.

        When no profiles exist, an informational panel is shown in place of the table.

        Selection prompt choices:
          - Add profile    → calls Show-EditUploadProfileScreen; reloads and redraws on return
          - Remove profile → shown only when at least one profile exists; presents a second
                             prompt listing all profile names plus 'Cancel'; on selection calls
                             Remove-UploadProfileFile
          - [Back]         → exits the loop and returns $null

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
        made by Show-EditUploadProfileScreen and Remove-UploadProfileFile are
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

        foreach ($profile in $profiles) {
            $tokenInfo  = $tokenMap[$profile.sasTokenEnvVar]
            $tokenValid = if ($null -ne $tokenInfo) { "$($tokenInfo.Valid)" } else { 'False' }

            [Spectre.Console.TableExtensions]::AddRow(
                $profileTable,
                [string[]]@(
                    [Spectre.Console.Markup]::Escape($profile.name),
                    [Spectre.Console.Markup]::Escape($profile.accountName),
                    [Spectre.Console.Markup]::Escape($profile.containerName),
                    [Spectre.Console.Markup]::Escape($profile.sasTokenEnvVar),
                    [Spectre.Console.Markup]::Escape($tokenValid),
                    [Spectre.Console.Markup]::Escape($profile.blobPathPattern),
                    "$($profile.deleteLocalAfterDays)"
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
            $menuChoices.Add('Remove profile')
        }

        $prompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
            'Upload profiles:', $menuChoices.ToArray()
        )
        $selection = $prompt.Show($Console)

        switch ($selection) {

            'Add profile' {
                Show-EditUploadProfileScreen -Console $Console
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
                    Remove-UploadProfileFile -Name $matchedProfile.name
                }
            }

            default {
                # '[Back]' or any unrecognised value — exit the loop
                return $null
            }
        }
    }
}
