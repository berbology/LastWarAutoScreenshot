function New-LWASUploadProfile {
    <#
    .SYNOPSIS
        Creates and saves a new upload profile for Azure Blob Storage.

    .DESCRIPTION
        Validates the supplied parameters, builds a profile object with all schema
        fields, and saves it to the upload profiles directory. The profile can then
        be referenced by UploadScreenshots macro actions and by Send-LWASScreenshots.

        The SAS token is stored only as the name of the environment variable that
        holds it, not as the token itself. Set the environment variable before
        running an upload. A warning is issued if the variable is not currently set,
        but the profile is still saved.

    .PARAMETER Name
        Name for the upload profile. Must match the macro naming rules: 1–50
        characters, letters, digits, hyphens, and underscores only.

    .PARAMETER AccountName
        Azure Storage account name (e.g. 'mystorageaccount').

    .PARAMETER ContainerName
        Name of the blob container (e.g. 'screenshots').

    .PARAMETER SasTokenEnvVar
        Name of the environment variable that holds the SAS token at runtime.
        Must consist of letters, digits, and underscores only.

    .PARAMETER BlobPathPattern
        Pattern for the blob path. Supports placeholders: {MacroName}, {Date},
        {Time}, {Filename}. Defaults to '{MacroName}/{Date}/{Filename}'.

    .PARAMETER MaxRetryAttempts
        Maximum upload retry attempts (1–10). Defaults to 3.

    .PARAMETER RetryBaseDelayMs
        Base delay in milliseconds between retry attempts (100–60000). Defaults
        to 500.

    .PARAMETER DeleteLocalAfterUpload
        When set, deletes each local file immediately after a successful upload.

    .PARAMETER CloudProvider
        The cloud provider for this profile. Only 'azure' is supported in Phase 9b.
        Defaults to 'azure'.

    .PARAMETER DeleteLocalAfterDays
        Removes local screenshot files older than this many days after each upload
        run (1–3650). Defaults to 30.

    .OUTPUTS
        None

    .EXAMPLE
        New-LWASUploadProfile -Name 'azure-1' -AccountName 'myaccount' `
            -ContainerName 'screenshots' -SasTokenEnvVar 'LWAS_SAS_MY_TOKEN'

    .EXAMPLE
        New-LWASUploadProfile -Name 'azure-2' -AccountName 'myaccount' `
            -ContainerName 'screens' -SasTokenEnvVar 'LWAS_SAS_MY_TOKEN_2' `
            -DeleteLocalAfterUpload -DeleteLocalAfterDays 7 -MaxRetryAttempts 5
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$AccountName,

        [Parameter(Mandatory)]
        [string]$ContainerName,

        [Parameter(Mandatory)]
        [string]$SasTokenEnvVar,

        [Parameter()]
        [string]$BlobPathPattern = '{MacroName}/{Date}/{Filename}',

        [Parameter()]
        [int]$MaxRetryAttempts = 3,

        [Parameter()]
        [int]$RetryBaseDelayMs = 500,

        [Parameter()]
        [switch]$DeleteLocalAfterUpload,

        [Parameter()]
        [int]$DeleteLocalAfterDays = 30,

        [Parameter()]
        [string]$CloudProvider = 'azure'
    )

    # Validate CloudProvider
    if ($CloudProvider -ine 'azure') {
        Write-Error "CloudProvider '$CloudProvider' is not supported. Only 'azure' is supported in Phase 9b."
        return
    }

    # Validate name format
    $nameValidation = Get-ValidMacroName -Name $Name
    if (-not $nameValidation.Valid) {
        Write-Error $nameValidation.Message
        return
    }

    # Check uniqueness
    $existingProfile = Get-UploadProfile -Name $Name
    if ($null -ne $existingProfile) {
        Write-Error "Upload profile '$Name' already exists."
        return
    }

    # Validate SasTokenEnvVar characters
    if ($SasTokenEnvVar -match '[^A-Za-z0-9_]') {
        Write-Error "SasTokenEnvVar '$SasTokenEnvVar' contains invalid characters. Only letters, digits, and underscores are allowed."
        return
    }

    # Warn if env var is not currently set (do not block save)
    $currentToken = [Environment]::GetEnvironmentVariable($SasTokenEnvVar)
    if ([string]::IsNullOrEmpty($currentToken)) {
        Write-Warning "Environment variable '$SasTokenEnvVar' is not currently set. Set it to the SAS token before running an upload."
    }

    # Validate numeric ranges
    if ($MaxRetryAttempts -lt 1 -or $MaxRetryAttempts -gt 10) {
        Write-Error "MaxRetryAttempts must be between 1 and 10. Got: $MaxRetryAttempts."
        return
    }

    if ($RetryBaseDelayMs -lt 100 -or $RetryBaseDelayMs -gt 60000) {
        Write-Error "RetryBaseDelayMs must be between 100 and 60000. Got: $RetryBaseDelayMs."
        return
    }

    if ($DeleteLocalAfterDays -lt 1 -or $DeleteLocalAfterDays -gt 3650) {
        Write-Error "DeleteLocalAfterDays must be between 1 and 3650. Got: $DeleteLocalAfterDays."
        return
    }

    $nowUtc = [datetime]::UtcNow.ToString('o')
    $profile = [PSCustomObject]@{
        name                   = $Name
        provider               = 'AzureBlobStorage'
        cloudProvider          = $CloudProvider.ToLower()
        accountName            = $AccountName
        containerName          = $ContainerName
        sasTokenEnvVar         = $SasTokenEnvVar
        blobPathPattern        = $BlobPathPattern
        maxRetryAttempts       = $MaxRetryAttempts
        retryBaseDelayMs       = $RetryBaseDelayMs
        deleteLocalAfterUpload = $DeleteLocalAfterUpload.IsPresent
        deleteLocalAfterDays   = $DeleteLocalAfterDays
        createdUtc             = $nowUtc
        modifiedUtc            = $nowUtc
    }

    Save-UploadProfileFile -Profile $profile
    Write-Verbose "Upload profile '$Name' saved."
}
