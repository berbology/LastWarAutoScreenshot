function New-LWASUploadProfile {
    <#
    .SYNOPSIS
        Creates and saves a new upload profile for Azure Blob Storage.

    .DESCRIPTION
        Validates the supplied parameters, builds a profile object with all schema
        fields, and saves it to the upload profiles directory. The profile can then
        be referenced by UploadScreenshots macro actions and by Send-LWASScreenshots.

        The SAS token is stored only as the name of the environment variable that
        holds it, not as the token itself. After saving, the current token is
        validated via Test-LWASSASTokenIsValid. If the token is absent or expired,
        Update-LWASSASToken is called automatically to generate and
        persist a new one (requires Az.Storage and an active Azure session).

    .PARAMETER Name
        Name for the upload profile. Must match the macro naming rules: 1–50
        characters, letters, digits, hyphens, and underscores only.

    .PARAMETER ResourceGroupName
        Azure Resource Group that contains the storage account (e.g. 'my-resource-group').
        Required to retrieve the storage account key when generating SAS tokens.

    .PARAMETER AccountName
        Azure Storage account name (e.g. 'mystorageaccount').

    .PARAMETER ContainerName
        Name of the blob container (e.g. 'screenshots').

    .PARAMETER SasTokenEnvVar
        Name of the environment variable that holds the SAS token at runtime.
        Must consist of letters, digits, and underscores only. The 'LWAS_SAS_'
        prefix is required and will be added automatically if omitted; a warning
        is emitted in that case so you know the effective variable name.

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

        Creates a profile using the environment variable LWAS_SAS_MY_TOKEN (prefix
        already supplied).

    .EXAMPLE
        New-LWASUploadProfile -Name 'azure-2' -AccountName 'myaccount' `
            -ContainerName 'screenshots' -SasTokenEnvVar 'MY_TOKEN'

        The prefix is missing so it is added automatically. A warning is emitted:
        "SAS token environment variable name must start with 'LWAS_SAS_' – prefix
        added. Effective variable name: LWAS_SAS_MY_TOKEN"

    .EXAMPLE
        New-LWASUploadProfile -Name 'azure-3' -AccountName 'myaccount' `
            -ContainerName 'screens' -SasTokenEnvVar 'LWAS_SAS_MY_TOKEN_2' `
            -DeleteLocalAfterUpload -DeleteLocalAfterDays 7 -MaxRetryAttempts 5
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$ResourceGroupName,

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

    # Auto-prefix SasTokenEnvVar if the required prefix is absent
    if ($SasTokenEnvVar -notmatch '^LWAS_SAS_') {
        $SasTokenEnvVar = "LWAS_SAS_$SasTokenEnvVar"
        Write-Warning "SAS token environment variable name must start with 'LWAS_SAS_' - prefix added. Effective variable name: $SasTokenEnvVar"
    }

    # Validate SasTokenEnvVar characters
    if ($SasTokenEnvVar -match '[^A-Za-z0-9_]') {
        Write-Error "SasTokenEnvVar '$SasTokenEnvVar' contains invalid characters. Only letters, digits, and underscores are allowed."
        return
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
    $uploadProfile = [PSCustomObject]@{
        name                   = $Name
        provider               = 'AzureBlobStorage'
        cloudProvider          = $CloudProvider.ToLower()
        resourceGroupName      = $ResourceGroupName
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

    Save-UploadProfileFile -UploadProfile $uploadProfile

    $currentToken = [Environment]::GetEnvironmentVariable($SasTokenEnvVar)
    if (-not (Test-LWASSASTokenIsValid -SasToken $currentToken)) {
        $tokenUpdated = Update-LWASSASToken -Name $SasTokenEnvVar -UploadProfile $Name
        if (-not $tokenUpdated) {
            Write-Warning "Profile '$Name' saved, but SAS token could not be updated automatically. Run Update-LWASSASToken after connecting to Azure (Connect-AzAccount)."
        } else {
            Write-Verbose "SAS token for '$SasTokenEnvVar' updated successfully."
        }
    }

    Write-Verbose "Upload profile '$Name' saved."
}
