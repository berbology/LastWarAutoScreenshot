function Get-MacroFileList {
    <#
    .SYNOPSIS
        Returns a list of all saved macro files with their display metadata.

    .DESCRIPTION
        Scans the Private\Macros folder within the module root for *.json files
        whose filenames match the expected convention (yyyyMMdd_HHmmss_<name>.json).

        For each matching file the macro JSON is read via Get-MacroFile and key
        metadata is extracted. Files whose filename does not match the expected
        pattern, or whose JSON cannot be parsed, are logged as warnings and excluded
        from the results.

        The returned list is sorted by CreatedUtc descending so that the most
        recently created macro appears first.

    .OUTPUTS
        PSCustomObject[]
        Each object has properties:
          FileName    [string]   — bare filename, e.g. '20260224_121212_my-macro.json'
          FilePath    [string]   — absolute path to the file
          Name        [string]   — macro name from metadata.name
          CreatedUtc  [datetime] — creation timestamp (UTC) from metadata.createdUtc
          DisplayDate [string]   — CreatedUtc converted to local time, formatted 'dd/MM/yy HH:mm:ss'
          ActionCount [int]      — number of actions in the sequence
          Valid       [bool]     — whether the macro passed schema validation

        Returns an empty array when the folder does not exist or contains no
        matching JSON files.

    .EXAMPLE
        $macros = Get-MacroFileList
        foreach ($m in $macros) {
            Write-Host "$($m.Name) ($($m.DisplayDate)) — $($m.ActionCount) actions"
        }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    $macrosDir = Join-Path $script:ModuleRootPath 'Private\Macros'

    if (-not (Test-Path -LiteralPath $macrosDir)) {
        return @()
    }

    $jsonFiles = @(Get-ChildItem -LiteralPath $macrosDir -Filter '*.json' -File -ErrorAction SilentlyContinue)
    if ($jsonFiles.Count -eq 0) {
        return @()
    }

    $filenamePattern = '^(\d{8}_\d{6})_(.+)\.json$'
    $results         = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($file in $jsonFiles) {
        # Validate filename pattern
        if ($file.Name -notmatch $filenamePattern) {
            Write-LastWarLog -Level Warning `
                -Message "Macro file '$($file.Name)' does not match the expected filename pattern and will be skipped." `
                -FunctionName 'Get-MacroFileList'
            continue
        }

        # Read and validate the macro JSON
        $macroResult = Get-MacroFile -FilePath $file.FullName
        if ($null -eq $macroResult) {
            Write-LastWarLog -Level Warning `
                -Message "Macro file '$($file.Name)' could not be read or parsed and will be skipped." `
                -FunctionName 'Get-MacroFileList'
            continue
        }

        # Parse createdUtc from JSON metadata (handle both string and [datetime] types)
        $createdUtc = $null
        try {
            $rawCreated = $macroResult.Data.metadata.createdUtc
            if ($rawCreated -is [datetime]) {
                $createdUtc = $rawCreated
            } elseif ($rawCreated -is [string]) {
                $createdUtc = [datetime]::Parse($rawCreated, $null, [System.Globalization.DateTimeStyles]::RoundtripKind)
            } else {
                throw "createdUtc is not a string or datetime: $rawCreated"
            }
        } catch {
            Write-LastWarLog -Level Warning `
                -Message "Macro file '$($file.Name)' has an unparseable createdUtc '$($macroResult.Data.metadata.createdUtc)' and will be skipped." `
                -FunctionName 'Get-MacroFileList'
            continue
        }

        $displayDate = $createdUtc.ToLocalTime().ToString('dd/MM/yy HH:mm:ss')
        $actionCount = if ($null -ne $macroResult.Data.sequence) { @($macroResult.Data.sequence).Count } else { 0 }

        $results.Add([PSCustomObject]@{
            FileName    = $file.Name
            FilePath    = $file.FullName
            Name        = $macroResult.Data.metadata.name
            CreatedUtc  = $createdUtc
            DisplayDate = $displayDate
            ActionCount = $actionCount
            Valid       = $macroResult.Valid
        })
    }

    return @($results | Sort-Object -Property CreatedUtc -Descending)
}
