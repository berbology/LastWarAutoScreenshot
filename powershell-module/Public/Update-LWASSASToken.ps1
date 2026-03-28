function Update-LWASSASToken {
    <#
    .SYNOPSIS
        Generates a new SAS token for an Azure upload profile and stores it in the
        configured environment variable.

    .DESCRIPTION
        Uses the Az.Storage module to generate a new container SAS token with a
        1-year expiry and stores it in the environment variable named by the
        profile's sasTokenEnvVar field — at both User scope (persistent) and
        Process scope (immediately available in the current session).

        Prerequisites:
          - Az.Storage module must be installed (Install-Module Az.Storage -Scope CurrentUser).
          - An active Azure session is required (Connect-AzAccount). The function does
            not call Connect-AzAccount automatically.

        Only Azure profiles (cloudProvider = 'azure') are supported. Calling this
        function on a non-Azure profile is an error.

        Supports pipeline input so callers can pipe Get-LWASUploadProfile output:
            Get-LWASUploadProfile | Update-LWASSASToken

    .PARAMETER Profile
        The upload profile PSCustomObject. Must have cloudProvider = 'azure',
        a non-empty sasTokenEnvVar, accountName, and containerName.

    .OUTPUTS
        System.Boolean
        $true when the token was generated and stored successfully; $false on any
        failure (wrong cloud provider, module unavailable, Az error, missing fields).

    .EXAMPLE
        $uploadProfile = Get-LWASUploadProfile -Name 'azure-storage-1'
        Update-LWASSASToken -UploadProfile $uploadProfile

    .EXAMPLE
        Get-LWASUploadProfile | Update-LWASSASToken
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$UploadProfile
    )

    process {
        # Guard: Azure profiles only
        if (-not (Test-LWASAzureProfile -UploadProfile $UploadProfile)) {
            Write-Error "SAS token management is only supported for Azure profiles (cloudProvider = 'azure')."
            return $false
        }

        # Guard: Az.Storage must be installed and imported
        if (-not (Assert-LWASAzStorageModule)) {
            return $false
        }

        # Guard: sasTokenEnvVar must be configured
        if ([string]::IsNullOrEmpty($UploadProfile.sasTokenEnvVar)) {
            Write-Error "Profile '$($UploadProfile.name)' has no sasTokenEnvVar configured."
            return $false
        }

        if ($PSCmdlet.ShouldProcess($UploadProfile.sasTokenEnvVar, 'Request new SAS token')) {
            # Guard: must be authenticated to Azure before calling storage cmdlets
            if (-not (Assert-LWASAzureSession)) {
                return $false
            }

            $token = $null
            try {
                $context = New-AzStorageContext -StorageAccountName $UploadProfile.accountName -UseConnectedAccount
                $token   = New-AzStorageContainerSASToken `
                               -Name       $UploadProfile.containerName `
                               -Context    $context `
                               -Permission 'rwdl' `
                               -ExpiryTime ([datetime]::UtcNow.AddDays(6)) `
                               -Protocol   HttpsOnly
            } catch {
                Write-Error "Failed to generate SAS token for '$($UploadProfile.name)'. Ensure you are connected to Azure (Connect-AzAccount). Error: $($_.Exception.Message)"
                return $false
            }

            # Guard: cmdlet may write a non-terminating error and return null instead of throwing.
            # Proceeding with a null token would call SetEnvironmentVariable(name, $null) which
            # silently deletes the variable — never do that.
            if ($null -eq $token) {
                Write-Error "Failed to generate SAS token for '$($UploadProfile.name)': the Azure cmdlet returned null. Check the account/container names and ensure you are connected to Azure (Connect-AzAccount)."
                return $false
            }

            # Strip leading '?' that Az module sometimes includes
            if ($token.StartsWith('?')) {
                $token = $token.Substring(1)
            }

            Set-LWASSasToken -Name $UploadProfile.sasTokenEnvVar -Token $token

            Write-LastWarLog -Level Info `
                -Message "SAS token for profile '$($UploadProfile.name)' stored in '$($UploadProfile.sasTokenEnvVar)' (expires in ~6 days)." `
                -FunctionName 'Update-LWASSASToken'

            return $true
        }

        # -WhatIf path
        return $false
    }
}
