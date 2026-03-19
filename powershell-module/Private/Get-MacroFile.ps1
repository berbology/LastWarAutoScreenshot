function Get-MacroFile {
    <#
    .SYNOPSIS
        Reads and parses a single macro JSON file from disk.

    .DESCRIPTION
        Reads the file at the given path, parses its JSON content, and validates
        the parsed object against the macro schema via Test-MacroFile.

        Returns $null when the file does not exist or contains invalid JSON.
        When the file contains valid JSON but fails schema validation, the parsed
        data is still returned alongside the validation errors so that callers
        (e.g. the manage screen) can display and potentially correct the macro.

    .PARAMETER FilePath
        Absolute path to the macro JSON file to read.

    .OUTPUTS
        PSCustomObject
        Properties: Valid [bool], Data [PSCustomObject], Messages [string[]].
        Returns $null if the file is missing or the JSON cannot be parsed.

    .EXAMPLE
        $result = Get-MacroFile -FilePath "$env:APPDATA\LastWarAutoScreenshot\Macros\20260224_121212_my-macro.json"
        if ($null -eq $result) { Write-Warning 'File missing or invalid JSON.' }
        elseif (-not $result.Valid) { $result.Messages | ForEach-Object { Write-Warning $_ } }
        else { $result.Data.metadata.name }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    if (-not (Test-Path -LiteralPath $FilePath)) {
        Write-LastWarLog -Level Error -Message "Macro file not found: $FilePath" -FunctionName 'Get-MacroFile'
        return $null
    }

    $data = $null
    try {
        $content = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8
        $data    = $content | ConvertFrom-Json
    } catch {
        Write-LastWarLog -Level Error -Message "Failed to parse macro JSON from '$FilePath': $_" -FunctionName 'Get-MacroFile'
        return $null
    }

    $validation = Test-MacroFile -MacroData $data

    return [PSCustomObject]@{
        Valid    = $validation.Valid
        Data     = $data
        Messages = $validation.Messages
    }
}
