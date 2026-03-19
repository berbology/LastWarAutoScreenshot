function Rename-MacroFile {
    <#
    .SYNOPSIS
        Renames a saved macro file and updates the name in its JSON metadata.

    .DESCRIPTION
        Validates the new name, reads the existing macro, updates metadata.name and
        metadata.modifiedUtc, writes the updated JSON to the new filename (preserving
        the original datetime prefix), then deletes the old file.

        If the write of the new file succeeds but deletion of the old file fails,
        the function logs an Error and still returns Success=$true because the
        renamed file exists at the new path. Manual cleanup of the old file may
        be required.

    .PARAMETER FilePath
        Absolute path to the existing macro JSON file to rename.

    .PARAMETER NewName
        The desired new name for the macro. Must match [a-zA-Z0-9_-], 1-50 characters,
        and must be unique among all currently saved macros.

    .OUTPUTS
        PSCustomObject
        Properties: Success [bool], NewFilePath [string], Message [string].
        NewFilePath is the full path of the renamed file on success, empty string on failure.
        Message is empty on success; human-readable on failure.

    .EXAMPLE
        $result = Rename-MacroFile -FilePath "$env:APPDATA\LastWarAutoScreenshot\Macros\20260101_120000_old-name.json" -NewName 'new-name'
        if ($result.Success) { Write-Host "Renamed to $($result.NewFilePath)" }

    .NOTES
        The datetime prefix (yyyyMMdd_HHmmss) in the filename is always preserved on
        rename; only the name portion of the filename changes.

        If the write of the new file succeeds but Remove-Item of the old file throws,
        an Error is logged but Success=$true is returned because the renamed file
        already exists at NewFilePath.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string]$NewName
    )

    if (-not (Test-Path -LiteralPath $FilePath)) {
        return [PSCustomObject]@{
            Success     = $false
            NewFilePath = ''
            Message     = 'File not found.'
        }
    }

    # Collect existing macro names, excluding the current file, for uniqueness validation
    $allMacros  = Get-LWASMacro
    $otherNames = @($allMacros | Where-Object { $_.FilePath -ne $FilePath } | Select-Object -ExpandProperty Name)

    $nameResult = Get-ValidMacroName -Name $NewName -ExistingNames $otherNames
    if (-not $nameResult.Valid) {
        return [PSCustomObject]@{
            Success     = $false
            NewFilePath = ''
            Message     = $nameResult.Message
        }
    }

    $macroResult = Get-MacroFile -FilePath $FilePath
    if ($null -eq $macroResult) {
        return [PSCustomObject]@{
            Success     = $false
            NewFilePath = ''
            Message     = 'Failed to read macro file.'
        }
    }

    $oldName = $macroResult.Data.metadata.name

    # Update name and modified timestamp in the data object
    $macroResult.Data.metadata.name        = $nameResult.SanitisedName
    $macroResult.Data.metadata.modifiedUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

    # Extract the original datetime prefix from the filename
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    if ($baseName -notmatch '^(\d{8}_\d{6})_') {
        return [PSCustomObject]@{
            Success     = $false
            NewFilePath = ''
            Message     = "Cannot extract datetime prefix from filename '$baseName'."
        }
    }
    $dtPrefix = $Matches[1]

    $newFilename = "${dtPrefix}_$($nameResult.SanitisedName).json"
    $newFilePath = Join-Path (Split-Path -Parent $FilePath) $newFilename

    try {
        $macroResult.Data | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $newFilePath -Encoding UTF8
    } catch {
        Write-LastWarLog -Level Error `
            -Message "Failed to write renamed macro file '$newFilePath': $_" `
            -FunctionName 'Rename-MacroFile'
        return [PSCustomObject]@{
            Success     = $false
            NewFilePath = ''
            Message     = "Failed to write renamed macro file: $_"
        }
    }

    # Remove old file; non-fatal if it fails — the renamed file already exists
    try {
        Remove-Item -LiteralPath $FilePath -Force
    } catch {
        Write-LastWarLog -Level Error `
            -Message "Renamed macro written to '$newFilePath' but failed to delete old file '$FilePath': $_" `
            -FunctionName 'Rename-MacroFile'
    }

    Write-LastWarLog -Level Info `
        -Message "Macro renamed from '$oldName' to '$($nameResult.SanitisedName)'" `
        -FunctionName 'Rename-MacroFile'

    return [PSCustomObject]@{
        Success     = $true
        NewFilePath = $newFilePath
        Message     = ''
    }
}
