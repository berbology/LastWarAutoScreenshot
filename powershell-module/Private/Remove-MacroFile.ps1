function Remove-MacroFile {
    <#
    .SYNOPSIS
        Deletes a macro JSON file from disk.

    .DESCRIPTION
        Validates that the specified file exists, then deletes it via Remove-Item.
        Logs the outcome at the appropriate level via Write-LastWarLog.

    .PARAMETER FilePath
        The full path to the macro JSON file to delete.

    .OUTPUTS
        [bool]
        $true if the file was deleted successfully; $false if the file was not found
        or if deletion failed.

    .EXAMPLE
        $deleted = Remove-MacroFile -FilePath 'C:\...\Private\Macros\20260101_120000_my-macro.json'
        if ($deleted) { Write-Host 'Macro deleted.' }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    if (-not (Test-Path -LiteralPath $FilePath)) {
        Write-LastWarLog -Level Warning -Message "Macro file not found: $FilePath" -FunctionName 'Remove-MacroFile'
        return $false
    }

    try {
        Remove-Item -LiteralPath $FilePath -Force
        Write-LastWarLog -Level Info -Message "Macro file deleted: $FilePath" -FunctionName 'Remove-MacroFile'
        return $true
    } catch {
        Write-LastWarLog -Level Error -Message "Failed to delete macro file '$FilePath': $_" -FunctionName 'Remove-MacroFile'
        return $false
    }
}
