function Save-MacroFile {
    <#
    .SYNOPSIS
        Validates a macro data object and saves it to the macros directory.

    .DESCRIPTION
        Runs the macro through Test-MacroFile before writing. If validation fails,
        all error messages are logged at Error level and the function returns without
        writing any file.

        The filename is derived from metadata.createdUtc (formatted yyyyMMdd_HHmmss in
        UTC) and metadata.name (sanitised via Get-ValidMacroName):
            <yyyyMMdd_HHmmss>_<name>.json

        The macros directory ($env:APPDATA\LastWarAutoScreenshot\Macros) is created
        automatically if it does not exist.

    .PARAMETER MacroData
        The PSCustomObject representing the macro to save (typically built during
        recording and validated against the macro schema).

    .PARAMETER Force
        Overwrite an existing file with the same derived filename. Without this
        switch the function returns Success=$false if the file already exists.

    .OUTPUTS
        PSCustomObject
        Properties: Success [bool], FilePath [string], Message [string].
        FilePath is the full path of the written file on success, empty string on failure.
        Message is empty on success; human-readable on failure.

    .EXAMPLE
        $result = Save-MacroFile -MacroData $macro
        if ($result.Success) { Write-Host "Saved to $($result.FilePath)" }

    .EXAMPLE
        Save-MacroFile -MacroData $macro -Force
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$MacroData,

        [Parameter()]
        [switch]$Force
    )

    $validation = Test-MacroFile -MacroData $MacroData
    if (-not $validation.Valid) {
        foreach ($msg in $validation.Messages) {
            Write-LastWarLog -Level Error -Message $msg -FunctionName 'Save-MacroFile'
        }
        return [PSCustomObject]@{
            Success  = $false
            FilePath = ''
            Message  = 'Macro validation failed.'
        }
    }

    $macrosDir = $script:MacrosPath
    New-Item -Path $macrosDir -ItemType Directory -Force | Out-Null

    $createdUtc = [datetime]::Parse($MacroData.metadata.createdUtc)
    $dtPrefix   = $createdUtc.ToUniversalTime().ToString('yyyyMMdd_HHmmss')

    $nameResult = Get-ValidMacroName -Name $MacroData.metadata.name
    $safeName   = $nameResult.SanitisedName

    $filename = "${dtPrefix}_${safeName}.json"
    $filePath = Join-Path $macrosDir $filename

    if ((Test-Path $filePath) -and -not $Force) {
        Write-LastWarLog -Level Warning -Message 'Macro file already exists. Use -Force to overwrite.' -FunctionName 'Save-MacroFile'
        return [PSCustomObject]@{
            Success  = $false
            FilePath = ''
            Message  = 'Macro file already exists. Use -Force to overwrite.'
        }
    }

    try {
        $MacroData | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8
        Write-LastWarLog -Level Info -Message "Macro '$safeName' saved to $filePath" -FunctionName 'Save-MacroFile'
        return [PSCustomObject]@{
            Success  = $true
            FilePath = $filePath
            Message  = ''
        }
    } catch {
        Write-LastWarLog -Level Error -Message "Failed to write macro file '$filePath': $_" -FunctionName 'Save-MacroFile'
        return [PSCustomObject]@{
            Success  = $false
            FilePath = ''
            Message  = "Failed to write macro file: $_"
        }
    }
}
