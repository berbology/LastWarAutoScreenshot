function Remove-UploadProfileFile {
    <#
    .SYNOPSIS
        Deletes an upload profile JSON file from the profiles directory.

    .DESCRIPTION
        Resolves the file path from the profile name, writes a non-terminating error if
        the file is not found, otherwise calls Remove-Item and logs success at Info level.

    .PARAMETER Name
        The name of the upload profile to remove (without the .json extension).

    .PARAMETER ProfilesDirectory
        Directory containing the profile JSON files. Defaults to
        $env:APPDATA\LastWarAutoScreenshot\UploadProfiles.

    .OUTPUTS
        None

    .EXAMPLE
        Remove-UploadProfileFile -Name 'azure-storage-1'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [string]$ProfilesDirectory = (Join-Path $env:APPDATA 'LastWarAutoScreenshot\UploadProfiles')
    )

    $filePath = Join-Path $ProfilesDirectory "$Name.json"

    if (-not (Test-Path -LiteralPath $filePath)) {
        Write-Error "Upload profile file not found: $filePath"
        return
    }

    Remove-Item -LiteralPath $filePath -Force
    Write-LastWarLog -Level Info `
        -Message "Upload profile '$Name' removed ('$filePath')." `
        -FunctionName 'Remove-UploadProfileFile'
}
