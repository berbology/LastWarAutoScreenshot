function Resolve-BlobPath {
    <#
    .SYNOPSIS
        Resolves a blob path pattern by substituting supported placeholders.

    .DESCRIPTION
        Substitutes {MacroName}, {Date}, {Time}, and {Filename} placeholders in the
        supplied pattern. Unrecognised placeholders are left unchanged and logged at
        Warning level.

        Supported placeholders:
            {MacroName}  - Name of the macro
            {Date}       - Upload date formatted as yyyy-MM-dd
            {Time}       - Upload time formatted as HH-mm-ss
            {Filename}   - Original filename including extension

    .PARAMETER BlobPathPattern
        The blob path pattern string containing zero or more supported placeholders.

    .PARAMETER MacroName
        Name of the macro associated with the upload.

    .PARAMETER Filename
        The original filename (with extension) to embed in the blob path.

    .PARAMETER UploadTime
        The timestamp to use for {Date} and {Time} substitutions. Defaults to
        [datetime]::UtcNow when not supplied.

    .OUTPUTS
        System.String
        The resolved blob path string.

    .EXAMPLE
        Resolve-BlobPath -BlobPathPattern '{MacroName}/{Date}/{Filename}' `
            -MacroName 'my-macro' -Filename 'screenshot_001.png'
        # Returns: 'my-macro/2026-03-21/screenshot_001.png'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$BlobPathPattern,

        [Parameter(Mandatory)]
        [string]$MacroName,

        [Parameter(Mandatory)]
        [string]$Filename,

        [Parameter()]
        [datetime]$UploadTime = [datetime]::UtcNow
    )

    $knownPlaceholders = @('{MacroName}', '{Date}', '{Time}', '{Filename}')

    $resolved = $BlobPathPattern
    $resolved = $resolved -replace '\{MacroName\}', $MacroName
    $resolved = $resolved -replace '\{Date\}',      $UploadTime.ToString('yyyy-MM-dd')
    $resolved = $resolved -replace '\{Time\}',      $UploadTime.ToString('HH-mm-ss')
    $resolved = $resolved -replace '\{Filename\}',  $Filename

    # Warn about any remaining unrecognised placeholders
    $remaining = [System.Text.RegularExpressions.Regex]::Matches($resolved, '\{[^}]+\}')
    foreach ($match in $remaining) {
        $placeholder = $match.Value
        if ($knownPlaceholders -notcontains $placeholder) {
            Write-LastWarLog -Level Warning `
                -Message "Resolve-BlobPath: Unrecognised placeholder '$placeholder' left unchanged in blob path." `
                -FunctionName 'Resolve-BlobPath'
        }
    }

    return $resolved
}
