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
        Optional. The name of a specific upload profile to return.

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
        With -Name: returns a single PSCustomObject, or $null when not found.

    .EXAMPLE
        Get-LWASUploadProfile

    .EXAMPLE
        Get-LWASUploadProfile -Name 'azure-storage-1'

    .EXAMPLE
        Get-LWASUploadProfile -Property name, accountName
        Returns all profiles but with only the name and accountName properties.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$Name,

        [Parameter()]
        [string[]]$Property
    )

    if ($PSBoundParameters.ContainsKey('Name')) {
        $uploadProfile = Get-UploadProfile -Name $Name
        if ($null -eq $uploadProfile) {
            Write-Warning "Upload profile '$Name' not found."
            return $null
        }
        if ($Property) {
            return ($uploadProfile | Select-Object -Property $Property)
        }
        return $uploadProfile
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
