function Show-EditUploadProfileScreen {
    <#
    .SYNOPSIS
        Displays a wizard for creating a new upload profile.

    .DESCRIPTION
        Prompts the user for each upload profile field in sequence with inline
        validation. After all fields are collected, shows a summary panel and
        asks for confirmation before saving.

        Fields collected (with defaults where applicable):
          - Name                   : validated via Get-ValidMacroName and uniqueness check
          - Azure account name     : non-empty string
          - Container name         : non-empty string
          - SAS token env var      : selected from existing LWAS_SAS_* variables or created
                                     with a validated suffix (becomes LWAS_SAS_{SUFFIX})
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

    .OUTPUTS
        PSCustomObject or $null
        Returns the saved profile object on success, or $null if the user cancels.

    .EXAMPLE
        $console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        $profile = Show-EditUploadProfileScreen -Console $console
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    # Name

    $profileName = $null
    while ($null -eq $profileName) {
        $namePrompt            = [Spectre.Console.TextPrompt[string]]::new('Upload profile name:')
        $namePrompt.AllowEmpty = $false
        $rawName               = $namePrompt.Show($Console)

        if ([string]::IsNullOrEmpty($rawName)) {
            continue
        }

        $nameResult = Get-ValidMacroName -Name $rawName
        if (-not $nameResult.Valid) {
            $Console.Write([Spectre.Console.Markup]::new("[red]$([Spectre.Console.Markup]::Escape($nameResult.Message))[/]`n"))
            continue
        }

        $existing = Get-UploadProfile -Name $nameResult.SanitisedName
        if ($null -ne $existing) {
            $safeName = [Spectre.Console.Markup]::Escape($nameResult.SanitisedName)
            $Console.Write([Spectre.Console.Markup]::new("[red]An upload profile named '$safeName' already exists. Choose a different name.[/]`n"))
            continue
        }

        $profileName = $nameResult.SanitisedName
    }

    # Azure account name

    $accountName = $null
    while ($null -eq $accountName) {
        $accountPrompt            = [Spectre.Console.TextPrompt[string]]::new('Azure storage account name:')
        $accountPrompt.AllowEmpty = $false
        $rawAccount               = $accountPrompt.Show($Console)

        if ([string]::IsNullOrEmpty($rawAccount)) {
            $Console.Write([Spectre.Console.Markup]::new("[red]Account name cannot be empty.[/]`n"))
            continue
        }

        $accountName = $rawAccount.Trim()
    }

    # Container name

    $containerName = $null
    while ($null -eq $containerName) {
        $containerPrompt            = [Spectre.Console.TextPrompt[string]]::new('Blob container name:')
        $containerPrompt.AllowEmpty = $false
        $rawContainer               = $containerPrompt.Show($Console)

        if ([string]::IsNullOrEmpty($rawContainer)) {
            $Console.Write([Spectre.Console.Markup]::new("[red]Container name cannot be empty.[/]`n"))
            continue
        }

        $containerName = $rawContainer.Trim()
    }

    # SAS token environment variable

    $sasTokenEnvVar   = $null
    $existingVarNames = @(Get-LWASSASTokenEnvVarNames)

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

        if ($null -ne [Environment]::GetEnvironmentVariable($candidateName)) {
            $Console.Write([Spectre.Console.Markup]::new("[red]Environment variable '$safeName' already exists. Choose a different suffix.[/]`n"))
            continue
        }

        $sasTokenEnvVar = $candidateName
    }

    # Blob path pattern

    $defaultBlobPattern  = '{MacroName}/{Date}/{Filename}'
    $blobPrompt          = [Spectre.Console.TextPrompt[string]]::new("Blob path pattern [[$defaultBlobPattern]]:")
    $blobPrompt.AllowEmpty = $true
    $rawBlobPattern      = $blobPrompt.Show($Console)
    $blobPathPattern     = if ([string]::IsNullOrEmpty($rawBlobPattern)) { $defaultBlobPattern } else { $rawBlobPattern }

    # Max retry attempts

    $maxRetryAttempts = $null
    while ($null -eq $maxRetryAttempts) {
        $retryPrompt            = [Spectre.Console.TextPrompt[string]]::new('Max retry attempts (1-10) [[3]]:')
        $retryPrompt.AllowEmpty = $true
        $rawRetry               = $retryPrompt.Show($Console)

        if ([string]::IsNullOrEmpty($rawRetry)) {
            $maxRetryAttempts = 3
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
        $delayPrompt            = [Spectre.Console.TextPrompt[string]]::new('Retry base delay in milliseconds (100-60000) [[500]]:')
        $delayPrompt.AllowEmpty = $true
        $rawDelay               = $delayPrompt.Show($Console)

        if ([string]::IsNullOrEmpty($rawDelay)) {
            $retryBaseDelayMs = 500
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

    $deleteLocalPrompt            = [Spectre.Console.TextPrompt[string]]::new('Delete local file after successful upload? (Y/N) [[N]]:')
    $deleteLocalPrompt.AllowEmpty = $true
    $deleteLocalInput             = $deleteLocalPrompt.Show($Console)
    $deleteLocalAfterUpload       = ($deleteLocalInput -match '^[Yy]')

    # Delete local after days

    $deleteLocalAfterDays = $null
    while ($null -eq $deleteLocalAfterDays) {
        $daysPrompt            = [Spectre.Console.TextPrompt[string]]::new('Delete local files older than N days (0-3650) [[30]]:')
        $daysPrompt.AllowEmpty = $true
        $rawDays               = $daysPrompt.Show($Console)

        if ([string]::IsNullOrEmpty($rawDays)) {
            $deleteLocalAfterDays = 30
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

    $currentToken      = [Environment]::GetEnvironmentVariable($sasTokenEnvVar)
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
    $summaryPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
        ($summaryLines -join "`n"),
        'Profile Summary'
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
    $profile = [PSCustomObject]@{
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
        createdUtc             = $nowUtc
        modifiedUtc            = $nowUtc
    }

    Save-UploadProfileFile -Profile $profile

    $safeProfileName = [Spectre.Console.Markup]::Escape($profileName)
    $safeSasVar      = [Spectre.Console.Markup]::Escape($sasTokenEnvVar)
    $savedToken      = [Environment]::GetEnvironmentVariable($sasTokenEnvVar)
    if (-not (Test-LWASSASTokenIsValid -SasToken $savedToken)) {
        $tokenUpdated = Update-LWASUploadProfileSASToken -Profile $profile
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
    $Console.Write([Spectre.Console.Markup]::new("[green]Upload profile '$safeProfileName' saved successfully.[/]`n"))

    return $profile
}
