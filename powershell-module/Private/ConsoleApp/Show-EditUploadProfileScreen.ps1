function Show-EditUploadProfileScreen {
    <#
    .SYNOPSIS
        Displays a wizard for creating or editing an upload profile.

    .DESCRIPTION
        Prompts the user for each upload profile field in sequence with inline
        validation. After all fields are collected, shows a summary panel and
        asks for confirmation before saving.

        When ExistingProfile is supplied the wizard runs in edit mode: each field
        is pre-populated with the current value and pressing Enter keeps it.

        Fields collected (with defaults where applicable):
          - Name                   : validated via Get-ValidMacroName and uniqueness check
                                     (uniqueness check skipped when name is unchanged in edit mode)
          - Azure account name     : non-empty string
          - Container name         : non-empty string
          - SAS token env var      : in edit mode, prompts to keep current or change;
                                     in add mode, selected from existing LWAS_SAS_* variables
                                     or created with a validated suffix (becomes LWAS_SAS_{SUFFIX})
          - Blob path pattern      : defaults to {MacroName}/{Date}/{Filename} on empty entry
          - Max retry attempts     : integer 1–10, default 3
          - Retry base delay (ms)  : integer 100–60000, default 500
          - Delete local after upload : Y/N prompt, default N
          - Delete local after days   : integer 1–3650, default 30

        On confirmation 'Yes': saves the profile via Save-UploadProfileFile. If the SAS
        token is absent or expired, Update-LWASUploadProfileSASToken is called automatically.
        Shows a success message and returns the saved profile object.

        On 'Cancel': returns $null without saving.

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for all rendering and input.
        Pass [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole() for production use,
        or a [Spectre.Console.Testing.TestConsole]::new() instance in Pester tests.

    .PARAMETER ExistingProfile
        Optional. The existing upload profile PSCustomObject to edit. When supplied the
        wizard pre-populates all fields from this object and runs in edit mode.

    .OUTPUTS
        PSCustomObject or $null
        Returns the saved profile object on success, or $null if the user cancels.

    .EXAMPLE
        $console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        $uploadProfile = Show-EditUploadProfileScreen -Console $console

    .EXAMPLE
        $existing = Get-LWASUploadProfile -Name 'my-profile'
        $console  = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        $updated  = Show-EditUploadProfileScreen -Console $console -ExistingProfile $existing
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console,

        [Parameter()]
        [PSCustomObject]$ExistingProfile = $null
    )

    $isEditing = $null -ne $ExistingProfile

    # Name

    $profileName = $null
    while ($null -eq $profileName) {
        $namePromptText        = if ($isEditing) {
            "Upload profile name [[$($ExistingProfile.name)]]:"
        } else {
            'Upload profile name:'
        }
        $namePrompt            = [Spectre.Console.TextPrompt[string]]::new($namePromptText)
        $namePrompt.AllowEmpty = $isEditing
        $rawName               = $namePrompt.Show($Console)

        if ([string]::IsNullOrEmpty($rawName)) {
            if ($isEditing) {
                $profileName = $ExistingProfile.name
                break
            }
            continue
        }

        $nameResult = Get-ValidMacroName -Name $rawName
        if (-not $nameResult.Valid) {
            $Console.Write([Spectre.Console.Markup]::new("[red]$([Spectre.Console.Markup]::Escape($nameResult.Message))[/]`n"))
            continue
        }

        # Uniqueness check: skip when editing and the name has not changed
        if (-not ($isEditing -and ($nameResult.SanitisedName -eq $ExistingProfile.name))) {
            $existing = Get-UploadProfile -Name $nameResult.SanitisedName
            if ($null -ne $existing) {
                $safeName = [Spectre.Console.Markup]::Escape($nameResult.SanitisedName)
                $Console.Write([Spectre.Console.Markup]::new("[red]An upload profile named '$safeName' already exists. Choose a different name.[/]`n"))
                continue
            }
        }

        $profileName = $nameResult.SanitisedName
    }

    # Azure account name

    $accountName = $null
    while ($null -eq $accountName) {
        $accountPromptText        = if ($isEditing) {
            "Azure storage account name [[$($ExistingProfile.accountName)]]:"
        } else {
            'Azure storage account name:'
        }
        $accountPrompt            = [Spectre.Console.TextPrompt[string]]::new($accountPromptText)
        $accountPrompt.AllowEmpty = $isEditing
        $rawAccount               = $accountPrompt.Show($Console)

        if ([string]::IsNullOrEmpty($rawAccount)) {
            if ($isEditing) {
                $accountName = $ExistingProfile.accountName
                break
            }
            $Console.Write([Spectre.Console.Markup]::new("[red]Account name cannot be empty.[/]`n"))
            continue
        }

        $accountName = $rawAccount.Trim()
    }

    # Container name

    $containerName = $null
    while ($null -eq $containerName) {
        $containerPromptText        = if ($isEditing) {
            "Blob container name [[$($ExistingProfile.containerName)]]:"
        } else {
            'Blob container name:'
        }
        $containerPrompt            = [Spectre.Console.TextPrompt[string]]::new($containerPromptText)
        $containerPrompt.AllowEmpty = $isEditing
        $rawContainer               = $containerPrompt.Show($Console)

        if ([string]::IsNullOrEmpty($rawContainer)) {
            if ($isEditing) {
                $containerName = $ExistingProfile.containerName
                break
            }
            $Console.Write([Spectre.Console.Markup]::new("[red]Container name cannot be empty.[/]`n"))
            continue
        }

        $containerName = $rawContainer.Trim()
    }

    # SAS token environment variable

    $sasTokenEnvVar   = $null
    $existingVarNames = @(Get-LWASSASToken | Select-Object -ExpandProperty Name)

    if ($isEditing) {
        $keepCurrentLabel = "Keep current ($($ExistingProfile.sasTokenEnvVar))"
        $sasEditPrompt    = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
            'SAS token environment variable:',
            @($keepCurrentLabel, 'Change')
        )
        $sasEditChoice = $sasEditPrompt.Show($Console)
        if ($sasEditChoice -eq $keepCurrentLabel) {
            $sasTokenEnvVar = $ExistingProfile.sasTokenEnvVar
        }
        # else: fall through to the existing var selection / create-new logic below
    }

    if ($null -eq $sasTokenEnvVar) {
        if ($existingVarNames.Count -eq 0) {
            $infoPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'No LWAS_SAS_* environment variables found. A new one will be created.',
                'SAS Token'
            )
            $Console.Write($infoPanel)
        } else {
            $sasVarPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                'Select SAS token environment variable:',
                [string[]]($existingVarNames + @('Create new'))
            )
            $sasVarChoice = $sasVarPrompt.Show($Console)
            if ($sasVarChoice -ne 'Create new') {
                $sasTokenEnvVar = $sasVarChoice
            }
        }
    }

    while ($null -eq $sasTokenEnvVar) {
        $suffixPrompt            = [Spectre.Console.TextPrompt[string]]::new('Enter a unique suffix for the new SAS token variable (will become LWAS_SAS_{SUFFIX}):')
        $suffixPrompt.AllowEmpty = $false
        $rawSuffix               = $suffixPrompt.Show($Console)

        # If the user typed the full variable name (e.g. LWAS_SAS_TOKEN instead of TOKEN),
        # strip the prefix so it is not duplicated when we prepend it below.
        if ($rawSuffix -imatch '^LWAS_SAS_(.+)$') {
            $rawSuffix = $Matches[1]
        }

        if ($rawSuffix -notmatch '^[A-Za-z0-9_]{1,30}$') {
            $Console.Write([Spectre.Console.Markup]::new("[red]Suffix must be 1–30 characters and contain only letters, digits, and underscores.[/]`n"))
            continue
        }

        $candidateName = "LWAS_SAS_$($rawSuffix.ToUpper())"
        $safeName      = [Spectre.Console.Markup]::Escape($candidateName)

        $existingToken = Get-LWASSASToken -Name $candidateName | Select-Object -First 1
        if ($null -ne $existingToken) {
            $Console.Write([Spectre.Console.Markup]::new("[red]Environment variable '$safeName' already exists. Choose a different suffix.[/]`n"))
            continue
        }

        $sasTokenEnvVar = $candidateName
    }

    # Blob path pattern

    $defaultBlobPattern    = if ($isEditing) { $ExistingProfile.blobPathPattern } else { '{MacroName}/{Date}/{Filename}' }
    $blobPrompt            = [Spectre.Console.TextPrompt[string]]::new("Blob path pattern [[$defaultBlobPattern]]:")
    $blobPrompt.AllowEmpty = $true
    $rawBlobPattern        = $blobPrompt.Show($Console)
    $blobPathPattern       = if ([string]::IsNullOrEmpty($rawBlobPattern)) { $defaultBlobPattern } else { $rawBlobPattern }

    # Max retry attempts

    $maxRetryAttempts = $null
    while ($null -eq $maxRetryAttempts) {
        $defaultRetry           = if ($isEditing) { $ExistingProfile.maxRetryAttempts } else { 3 }
        $retryPrompt            = [Spectre.Console.TextPrompt[string]]::new("Max retry attempts (1-10) [[$defaultRetry]]:")
        $retryPrompt.AllowEmpty = $true
        $rawRetry               = $retryPrompt.Show($Console)

        if ([string]::IsNullOrEmpty($rawRetry)) {
            $maxRetryAttempts = $defaultRetry
        } else {
            $parsedRetry = 0
            if (-not [int]::TryParse($rawRetry, [ref]$parsedRetry) -or $parsedRetry -lt 1 -or $parsedRetry -gt 10) {
                $Console.Write([Spectre.Console.Markup]::new("[red]Max retry attempts must be an integer between 1 and 10.[/]`n"))
                continue
            }
            $maxRetryAttempts = $parsedRetry
        }
    }

    # Retry base delay (ms)

    $retryBaseDelayMs = $null
    while ($null -eq $retryBaseDelayMs) {
        $defaultDelay           = if ($isEditing) { $ExistingProfile.retryBaseDelayMs } else { 500 }
        $delayPrompt            = [Spectre.Console.TextPrompt[string]]::new("Retry base delay in milliseconds (100-60000) [[$defaultDelay]]:")
        $delayPrompt.AllowEmpty = $true
        $rawDelay               = $delayPrompt.Show($Console)

        if ([string]::IsNullOrEmpty($rawDelay)) {
            $retryBaseDelayMs = $defaultDelay
        } else {
            $parsedDelay = 0
            if (-not [int]::TryParse($rawDelay, [ref]$parsedDelay) -or $parsedDelay -lt 100 -or $parsedDelay -gt 60000) {
                $Console.Write([Spectre.Console.Markup]::new("[red]Retry base delay must be an integer between 100 and 60000.[/]`n"))
                continue
            }
            $retryBaseDelayMs = $parsedDelay
        }
    }

    # Delete local after upload

    $defaultDeleteLocal           = if ($isEditing -and $ExistingProfile.deleteLocalAfterUpload) { 'Y' } else { 'N' }
    $deleteLocalPrompt            = [Spectre.Console.TextPrompt[string]]::new("Delete local file after successful upload? (Y/N) [[$defaultDeleteLocal]]:")
    $deleteLocalPrompt.AllowEmpty = $true
    $deleteLocalInput             = $deleteLocalPrompt.Show($Console)
    $deleteLocalAfterUpload       = if ([string]::IsNullOrEmpty($deleteLocalInput)) {
        $isEditing -and $ExistingProfile.deleteLocalAfterUpload
    } else {
        $deleteLocalInput -match '^[Yy]'
    }

    # Delete local after days

    $deleteLocalAfterDays = $null
    while ($null -eq $deleteLocalAfterDays) {
        $defaultDays           = if ($isEditing) { $ExistingProfile.deleteLocalAfterDays } else { 30 }
        $daysPrompt            = [Spectre.Console.TextPrompt[string]]::new("Delete local files older than N days (0-3650) [[$defaultDays]]:")
        $daysPrompt.AllowEmpty = $true
        $rawDays               = $daysPrompt.Show($Console)

        if ([string]::IsNullOrEmpty($rawDays)) {
            $deleteLocalAfterDays = $defaultDays
        } else {
            $parsedDays = 0
            if (-not [int]::TryParse($rawDays, [ref]$parsedDays) -or $parsedDays -lt 0 -or $parsedDays -gt 3650) {
                $Console.Write([Spectre.Console.Markup]::new("[red]Days must be an integer between 0 and 3650.[/]`n"))
                continue
            }
            $deleteLocalAfterDays = $parsedDays
        }
    }

    # Summary panel

    $tokenInfo         = Get-LWASSASToken -Name $sasTokenEnvVar | Select-Object -First 1
    $currentToken      = if ($null -ne $tokenInfo) { $tokenInfo.Value } else { $null }
    $tokenIsValid      = Test-LWASSASTokenIsValid -SasToken $currentToken
    $validityIndicator = if ($tokenIsValid) { ' [green](Valid)[/]' } else { ' [yellow](Will be requested on save)[/]' }

    $deleteLocalStr = if ($deleteLocalAfterUpload) { 'Yes' } else { 'No' }
    $summaryLines   = @(
        "Name:                 $([Spectre.Console.Markup]::Escape($profileName))"
        "Account:              $([Spectre.Console.Markup]::Escape($accountName))"
        "Container:            $([Spectre.Console.Markup]::Escape($containerName))"
        "SAS Token Env Var:    $([Spectre.Console.Markup]::Escape($sasTokenEnvVar))$validityIndicator"
        "Blob Path Pattern:    $([Spectre.Console.Markup]::Escape($blobPathPattern))"
        "Max Retry Attempts:   $maxRetryAttempts"
        "Retry Base Delay ms:  $retryBaseDelayMs"
        "Delete After Upload:  $deleteLocalStr"
        "Delete After Days:    $deleteLocalAfterDays"
    )
    $panelTitle   = if ($isEditing) { 'Edit Profile Summary' } else { 'Profile Summary' }
    $summaryPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
        ($summaryLines -join "`n"),
        $panelTitle
    )
    $Console.Write($summaryPanel)

    # Confirmation

    $confirmPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
        'Save this profile?', @('Yes', 'Cancel')
    )
    $confirmChoice = $confirmPrompt.Show($Console)

    if ($confirmChoice -ne 'Yes') {
        return $null
    }

    $nowUtc  = [datetime]::UtcNow.ToString('o')
    $uploadProfile = [PSCustomObject]@{
        name                   = $profileName
        provider               = 'AzureBlobStorage'
        cloudProvider          = 'azure'
        accountName            = $accountName
        containerName          = $containerName
        sasTokenEnvVar         = $sasTokenEnvVar
        blobPathPattern        = $blobPathPattern
        maxRetryAttempts       = $maxRetryAttempts
        retryBaseDelayMs       = $retryBaseDelayMs
        deleteLocalAfterUpload = $deleteLocalAfterUpload
        deleteLocalAfterDays   = $deleteLocalAfterDays
        createdUtc             = if ($isEditing) { $ExistingProfile.createdUtc } else { $nowUtc }
        modifiedUtc            = $nowUtc
    }

    # When editing and the name has changed, rename the old profile file first
    if ($isEditing -and ($profileName -ne $ExistingProfile.name)) {
        Rename-LWASUploadProfile -Name $ExistingProfile.name -NewName $profileName
    }

    Save-UploadProfileFile -UploadProfile $uploadProfile

    $safeProfileName = [Spectre.Console.Markup]::Escape($profileName)
    $safeSasVar      = [Spectre.Console.Markup]::Escape($sasTokenEnvVar)
    $savedTokenInfo  = Get-LWASSASToken -Name $sasTokenEnvVar | Select-Object -First 1
    $savedToken      = if ($null -ne $savedTokenInfo) { $savedTokenInfo.Value } else { $null }
    if (-not (Test-LWASSASTokenIsValid -SasToken $savedToken)) {
        $tokenUpdated = Update-LWASUploadProfileSASToken -UploadProfile $uploadProfile
        if ($tokenUpdated) {
            $Console.Write([Spectre.Console.Markup]::new("[green]SAS token updated and stored in '$safeSasVar'.[/]`n"))
        } else {
            $warningPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'Profile saved, but SAS token could not be updated automatically. Run Update-LWASUploadProfileSASToken after connecting to Azure (Connect-AzAccount).',
                'SAS Token Warning'
            )
            $Console.Write($warningPanel)
        }
    }

    $actionWord = if ($isEditing) { 'updated' } else { 'saved' }
    $Console.Write([Spectre.Console.Markup]::new("[green]Upload profile '$safeProfileName' $actionWord successfully.[/]`n"))

    Write-LastWarLog -Level Info `
        -Message "Upload profile '$profileName' $actionWord." `
        -FunctionName 'Show-EditUploadProfileScreen'

    return $uploadProfile
}
