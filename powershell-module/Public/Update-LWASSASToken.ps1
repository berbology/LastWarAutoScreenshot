function Update-LWASSASToken {
    <#
    .SYNOPSIS
        Generates a new SAS token and stores it in the named environment variable.

    .DESCRIPTION
        Uses the Az.Storage module to generate a new Account SAS token with a
        7-day expiry and stores it in the specified environment variable — at both
        User scope (persistent) and Process scope (immediately available in the
        current session).

        An Account SAS (ss=bfqt, srt=o) is required so uploads can address
        individual blobs. Container SAS tokens are insufficient for this purpose.

        Prerequisites:
          - Az.Storage module must be installed (Install-Module Az.Storage -Scope CurrentUser).
          - An active Azure session is required (Connect-AzAccount). The function does
            not call Connect-AzAccount automatically.
          - The upload profile must have a resourceGroupName set so that the storage
            account key can be retrieved via Get-AzStorageAccountKey.

        Only Azure profiles (cloudProvider = 'azure') are supported.

        To resolve the Azure storage account details, one of the following must hold:
          - -UploadProfile is specified: the named profile is loaded and its details used.
          - -UploadProfile is omitted: the first upload profile whose sasTokenEnvVar matches
            -Name is located automatically. An error is thrown if none is found.

        Supports pipeline input so callers can pipe objects whose Name property holds
        the SAS token environment variable name:
            [PSCustomObject]@{ Name = 'LWAS_SAS_PROD' } | Update-LWASSASToken
            Update-LWASSASToken -Name 'LWAS_SAS_PROD'
            Update-LWASSASToken -Name 'LWAS_SAS_PROD', 'LWAS_SAS_STAGING'

    .PARAMETER Name
        The name of the environment variable that holds the SAS token (e.g. LWAS_SAS_PROD).
        Accepts a single string, an array of strings, or the Name property of a piped object.

    .PARAMETER UploadProfile
        Optional. The name of the upload profile to retrieve Azure storage account details
        from (accountName, containerName, cloudProvider). When omitted, the function
        searches all upload profiles for the first one whose sasTokenEnvVar matches -Name.

    .OUTPUTS
        System.Boolean
        $true when the token was generated and stored successfully; $false on any
        failure (wrong cloud provider, module unavailable, Az error, profile not found).

    .EXAMPLE
        Update-LWASSASToken -Name 'LWAS_SAS_PROD'

    .EXAMPLE
        Update-LWASSASToken -Name 'LWAS_SAS_PROD' -UploadProfile 'azure-storage-1'

    .EXAMPLE
        Update-LWASSASToken -Name 'LWAS_SAS_PROD', 'LWAS_SAS_STAGING'

    .EXAMPLE
        [PSCustomObject]@{ Name = 'LWAS_SAS_PROD' } | Update-LWASSASToken
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string[]]$Name,

        [Parameter()]
        [string]$UploadProfile
    )

    process {
        foreach ($tokenEnvVar in $Name) {
            # Resolve which upload profile provides the Azure storage details
            $resolvedProfile = $null
            if ($PSBoundParameters.ContainsKey('UploadProfile')) {
                $resolvedProfile = Get-LWASUploadProfile -Name $UploadProfile
                if ($null -eq $resolvedProfile) {
                    Write-LastWarLog -Level Error `
                        -Message "Upload profile '$UploadProfile' not found." `
                        -FunctionName 'Update-LWASSASToken'
                    Write-Error "Upload profile '$UploadProfile' not found."
                    return $false
                }
            } else {
                $allProfiles     = @(Get-LWASUploadProfile)
                $resolvedProfile = $allProfiles |
                    Where-Object { $_.sasTokenEnvVar -eq $tokenEnvVar } |
                    Select-Object -First 1
                if ($null -eq $resolvedProfile) {
                    Write-LastWarLog -Level Error `
                        -Message "No upload profile found with sasTokenEnvVar '$tokenEnvVar'." `
                        -FunctionName 'Update-LWASSASToken'
                    Write-Error "No upload profile found with sasTokenEnvVar '$tokenEnvVar'. Configure an upload profile that uses this environment variable, or specify -UploadProfile explicitly."
                    return $false
                }
            }

            # Guard: Azure profiles only
            if (-not (Test-LWASAzureProfile -UploadProfile $resolvedProfile)) {
                Write-Error "SAS token management is only supported for Azure profiles (cloudProvider = 'azure')."
                return $false
            }

            # Guard: Az.Storage must be installed and imported
            if (-not (Assert-LWASAzStorageModule)) {
                return $false
            }

            if ($PSCmdlet.ShouldProcess($tokenEnvVar, 'Request new SAS token')) {
                # Guard: must be authenticated to Azure before calling storage cmdlets
                if (-not (Assert-LWASAzureSession)) {
                    return $false
                }

                Write-Verbose "Requesting new SAS token for '$tokenEnvVar' (profile: '$($resolvedProfile.name)', account: '$($resolvedProfile.accountName)')."

                $token = $null
                try {
                    Write-Verbose "Retrieving storage account key..."
                    $storageKeys       = Get-AzStorageAccountKey -ResourceGroupName $resolvedProfile.resourceGroupName -Name $resolvedProfile.accountName
                    $storageAccountKey = $storageKeys[0].Value
                    $context           = New-AzStorageContext -StorageAccountName $resolvedProfile.accountName -StorageAccountKey $storageAccountKey
                    $token             = New-AzStorageAccountSASToken `
                                   -Context      $context `
                                   -Service      Blob,File,Queue,Table `
                                   -ResourceType Object `
                                   -Permission   'rwdlacupyx' `
                                   -ExpiryTime   ([datetime]::UtcNow.AddDays(7)) `
                                   -Protocol     HttpsOnly
                } catch {
                    Write-Error "Failed to generate SAS token for '$tokenEnvVar'. Ensure you are connected to Azure (Connect-AzAccount). Error: $($_.Exception.Message)"
                    return $false
                }

                # Guard: cmdlet may write a non-terminating error and return null instead of throwing.
                # Proceeding with a null token would call SetEnvironmentVariable(name, $null) which
                # silently deletes the variable — never do that.
                if ($null -eq $token) {
                    Write-Error "Failed to generate SAS token for '$tokenEnvVar': the Azure cmdlet returned null. Check the account/container names and ensure you are connected to Azure (Connect-AzAccount)."
                    return $false
                }

                # Strip leading '?' that Az module sometimes includes
                if ($token.StartsWith('?')) {
                    $token = $token.Substring(1)
                }

                Set-LWASSasToken -Name $tokenEnvVar -Token $token

                Write-LastWarLog -Level Info `
                    -Message "SAS token for '$tokenEnvVar' (profile '$($resolvedProfile.name)') stored (expires in ~7 days)." `
                    -FunctionName 'Update-LWASSASToken'

                return $true
            }

            # -WhatIf path
            return $false
        }
    }
}
