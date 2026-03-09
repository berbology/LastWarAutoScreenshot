function Resolve-ScreenshotFilename {
    <#
    .SYNOPSIS
        Resolves a screenshot filename pattern into a validated, sanitised filename.

    .DESCRIPTION
        Substitutes all supported placeholders in the configured FilenamePattern with
        runtime values, applies defensive sanitisation to ensure the result is a legal
        Windows filename, appends the correct extension, and validates that the resolved
        name does not exceed 200 characters.

        Supported placeholders:
            {MacroName}  - Name of the running macro (sanitised to [a-zA-Z0-9_-])
            {ActionName} - Action name if non-empty, otherwise falls back to ActionType
            {Timestamp}  - UTC datetime formatted as yyyyMMdd_HHmmss
            {Date}       - UTC date formatted as yyyyMMdd
            {Time}       - UTC time formatted as HHmmss
            {Index}      - Zero-padded 4-digit integer (e.g. 0001); no padding above 9999

    .PARAMETER Pattern
        The filename pattern string containing zero or more of the supported placeholders.
        Must not be null or empty.

    .PARAMETER MacroName
        Name of the currently executing macro.

    .PARAMETER ActionName
        Name property of the current action. If null or empty, $ActionType is used instead.

    .PARAMETER ActionType
        Type string of the current action (e.g. 'Screenshot'). Used when ActionName is absent.

    .PARAMETER Index
        Screenshot sequence number for this execution run. 1-based; rendered as a
        zero-padded 4-digit string.

    .PARAMETER Format
        File format identifier. Only 'PNG' is supported in Phase 5.

    .EXAMPLE
        Resolve-ScreenshotFilename -Pattern '{MacroName}_{ActionName}_{Timestamp}_{Index}' `
            -MacroName 'get-vs-scores' -ActionName 'vs-screenshot' `
            -ActionType 'Screenshot' -Index 3 -Format 'PNG'
        # Returns: 'get-vs-scores_vs-screenshot_20260101_120000_0003.png'

    .OUTPUTS
        System.String
        The resolved filename including extension, or $null on any validation failure.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$MacroName,

        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ActionName,

        [Parameter(Mandatory)]
        [string]$ActionType,

        [Parameter(Mandatory)]
        [int]$Index,

        [Parameter(Mandatory)]
        [string]$Format
    )

    if ([string]::IsNullOrEmpty($Pattern)) {
        Write-LastWarLog -Level Error `
            -Message 'Resolve-ScreenshotFilename: FilenamePattern is null or empty — cannot resolve screenshot filename.' `
            -FunctionName 'Resolve-ScreenshotFilename'
        return $null
    }

    $now = (Get-Date).ToUniversalTime()

    # Sanitise MacroName defensively — replace any character not in [a-zA-Z0-9_-] with '_'
    $safeMacroName = $MacroName -replace '[^a-zA-Z0-9_\-]', '_'

    # ActionName falls back to ActionType when absent
    $effectiveActionName = if (-not [string]::IsNullOrEmpty($ActionName)) { $ActionName } else { $ActionType }

    $resolved = $Pattern
    $resolved = $resolved -replace '\{MacroName\}',  $safeMacroName
    $resolved = $resolved -replace '\{ActionName\}', $effectiveActionName
    $resolved = $resolved -replace '\{Timestamp\}',  $now.ToString('yyyyMMdd_HHmmss')
    $resolved = $resolved -replace '\{Date\}',       $now.ToString('yyyyMMdd')
    $resolved = $resolved -replace '\{Time\}',       $now.ToString('HHmmss')
    $resolved = $resolved -replace '\{Index\}',      $Index.ToString('D4')

    # Global sanitisation — replace any char not in [a-zA-Z0-9_-] with '_'
    $resolved = $resolved -replace '[^a-zA-Z0-9_\-]', '_'

    # Append extension
    if ($Format -ieq 'PNG') {
        $resolved = $resolved + '.png'
    } else {
        Write-LastWarLog -Level Error `
            -Message "Resolve-ScreenshotFilename: Unrecognised file format '$Format'. Only 'PNG' is supported." `
            -FunctionName 'Resolve-ScreenshotFilename'
        return $null
    }

    # Length validation — keep well within Windows MAX_PATH
    if ($resolved.Length -gt 200) {
        Write-LastWarLog -Level Error `
            -Message "Resolve-ScreenshotFilename: Resolved screenshot filename exceeds 200 characters ($($resolved.Length) chars). Shorten the FilenamePattern or macro/action names." `
            -FunctionName 'Resolve-ScreenshotFilename'
        return $null
    }

    return $resolved
}
