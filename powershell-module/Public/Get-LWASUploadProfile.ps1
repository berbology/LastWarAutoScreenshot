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

    .OUTPUTS
        PSCustomObject or PSCustomObject[]
        Without -Name: always returns an array (possibly empty).
        With -Name: returns a single PSCustomObject, or $null when not found.

    .EXAMPLE
        Get-LWASUploadProfile

    .EXAMPLE
        Get-LWASUploadProfile -Name 'azure-storage-1'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$Name
    )

    if ($PSBoundParameters.ContainsKey('Name')) {
        $uploadProfile = Get-UploadProfile -Name $Name
        if ($null -eq $uploadProfile) {
            Write-Warning "Upload profile '$Name' not found."
            return $null
        }
        return $uploadProfile
    }

    $allProfiles = @(Get-UploadProfile)
    if ($allProfiles.Count -eq 0) {
        Write-Verbose "No upload profiles configured."
    }
    return $allProfiles
}
