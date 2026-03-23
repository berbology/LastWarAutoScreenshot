function Save-UploadProfileFile {
    <#
    .SYNOPSIS
        Serialises an upload profile object and writes it to the profiles directory.

    .DESCRIPTION
        Creates the profiles directory if it does not exist, sets modifiedUtc to the
        current UTC time, serialises the profile as JSON (depth 3), and writes to
        {ProfilesDirectory}\{Profile.name}.json with UTF-8 encoding.

    .PARAMETER Profile
        The PSCustomObject representing the upload profile to save.

    .PARAMETER ProfilesDirectory
        Directory to write the profile JSON file into. Defaults to
        $env:APPDATA\LastWarAutoScreenshot\UploadProfiles.

    .NOTES
        All profile fields — including cloudProvider — are serialised automatically by
        ConvertTo-Json. No explicit handling of cloudProvider is required here.

    .OUTPUTS
        None

    .EXAMPLE
        Save-UploadProfileFile -Profile $profile
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Profile,

        [Parameter()]
        [string]$ProfilesDirectory = (Join-Path $env:APPDATA 'LastWarAutoScreenshot\UploadProfiles')
    )

    New-Item -Path $ProfilesDirectory -ItemType Directory -Force | Out-Null

    $Profile.modifiedUtc = [datetime]::UtcNow.ToString('o')

    $filePath = Join-Path $ProfilesDirectory "$($Profile.name).json"
    $Profile | ConvertTo-Json -Depth 3 | Set-Content -Path $filePath -Encoding UTF8

    Write-LastWarLog -Level Info `
        -Message "Upload profile '$($Profile.name)' saved to '$filePath'." `
        -FunctionName 'Save-UploadProfileFile'
}
