function Get-LWASUploadProfile {
    <#
    .SYNOPSIS
        Returns saved upload profiles.

    .DESCRIPTION
        Without -Name: returns all saved upload profiles as an array. Writes a verbose
        message when no profiles exist; never returns $null.

        With -Name: returns the single profile matching that name, or $null if not
        found. Writes a warning when the profile does not exist.

    .PARAMETER Name
        Optional. The name(s) of specific upload profile(s) to return. Accepts a single string or
        an array of strings. Writes a warning for each name that is not found.

    .PARAMETER Property
        Optional. A list of property names to include in the returned objects.
        When specified, only the named properties are returned. Valid property names are:
        name, provider, accountName, containerName, sasTokenEnvVar, blobPathPattern,
        maxRetryAttempts, retryBaseDelayMs, deleteLocalAfterUpload, deleteLocalAfterDays,
        createdUtc, modifiedUtc.
        Example: -Property name, accountName returns only those two properties.

    .OUTPUTS
        PSCustomObject or PSCustomObject[]
        Without -Name: always returns an array (possibly empty).
        With -Name: returns a PSCustomObject for each found profile. Writes a warning for each
        name not found. When a single name is given and the profile exists, returns a single
        PSCustomObject; returns $null when not found.

    .EXAMPLE
        Get-LWASUploadProfile

    .EXAMPLE
        Get-LWASUploadProfile -Name 'azure-storage-1'

    .EXAMPLE
        Get-LWASUploadProfile -Name 'azure-storage-1', 'azure-storage-2'

    .EXAMPLE
        Get-LWASUploadProfile -Property name, accountName
        Returns all profiles but with only the name and accountName properties.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string[]]$Name,

        [Parameter()]
        [string[]]$Property
    )

    if ($PSBoundParameters.ContainsKey('Name')) {
        $found = foreach ($profileName in $Name) {
            $uploadProfile = Get-UploadProfile -Name $profileName
            if ($null -eq $uploadProfile) {
                Write-Warning "Upload profile '$profileName' not found."
                continue
            }
            $uploadProfile
        }

        $results = @($found)

        # Preserve the single-item scalar return for callers using a single name
        if ($Name.Count -eq 1) {
            if ($results.Count -eq 0) {
                return $null
            }
            if ($Property) {
                return ($results[0] | Select-Object -Property $Property)
            }
            return $results[0]
        }

        if ($Property) {
            return [PSCustomObject[]]@($results | Select-Object -Property $Property)
        }
        return [PSCustomObject[]]@($results)
    }

    $allProfiles = @(Get-UploadProfile)
    if ($allProfiles.Count -eq 0) {
        Write-Verbose "No upload profiles configured."
    }
    if ($Property) {
        return [PSCustomObject[]]@($allProfiles | Select-Object -Property $Property)
    }
    return $allProfiles
}
