function Get-LWASMacro {
    <#
    .SYNOPSIS
        Returns saved macros with their full metadata and sequence data.

    .DESCRIPTION
        Scans the Private\Macros folder within the module root for *.json files
        whose filenames match the expected convention (yyyyMMdd_HHmmss_<name>.json).

        For each matching file the macro JSON is read via Get-MacroFile and key
        metadata is extracted. Files whose filename does not match the expected
        pattern, or whose JSON cannot be parsed, are logged as warnings and excluded
        from the results.

        The returned list is sorted by CreatedUtc descending so that the most
        recently created macro appears first.

        If -Name is supplied, only macros whose Name matches one of the specified
        values are returned. Each element may be a comma-separated string, which is
        split and trimmed automatically. A non-terminating error is written for any
        name that matches no stored macro.

    .PARAMETER Name
        Optional. One or more macro names to return. Accepts pipeline input and
        comma-separated strings. If omitted, all macros are returned.

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
          Metadata    [object]   — full metadata object from the macro JSON
          Sequence    [object[]] — full sequence array from the macro JSON

        Returns an empty array when the folder does not exist or contains no
        matching JSON files.

    .EXAMPLE
        $macros = Get-LWASMacro
        foreach ($m in $macros) {
            Write-Host "$($m.Name) ($($m.DisplayDate)) — $($m.ActionCount) actions"
        }

    .EXAMPLE
        $macro = Get-LWASMacro -Name 'my-macro'
        Invoke-MacroSequence -MacroData $macro.Data -WindowHandle $hWnd

    .EXAMPLE
        'macro-1', 'macro-2' | Get-LWASMacro
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]$Name
    )

    begin {
        $nameList = [System.Collections.Generic.List[string]]::new()
    }

    process {
        if ($null -ne $Name) {
            foreach ($token in $Name) {
                foreach ($part in ($token -split ',')) {
                    $trimmed = $part.Trim()
                    if ($trimmed.Length -gt 0) {
                        $nameList.Add($trimmed)
                    }
                }
            }
        }
    }

    end {
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
                    -FunctionName 'Get-LWASMacro'
                continue
            }

            # Read and validate the macro JSON
            $macroResult = Get-MacroFile -FilePath $file.FullName
            if ($null -eq $macroResult) {
                Write-LastWarLog -Level Warning `
                    -Message "Macro file '$($file.Name)' could not be read or parsed and will be skipped." `
                    -FunctionName 'Get-LWASMacro'
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
                    -FunctionName 'Get-LWASMacro'
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
                Metadata    = $macroResult.Data.metadata
                Sequence    = if ($null -ne $macroResult.Data.sequence) { @($macroResult.Data.sequence) } else { @() }
            })
        }

        $sorted = @($results | Sort-Object -Property CreatedUtc -Descending)

        # Apply -Name filter if names were specified
        if ($nameList.Count -gt 0) {
            $filtered = @($sorted | Where-Object { $_.Name -in $nameList })

            # Report unmatched names
            foreach ($requestedName in $nameList) {
                $match = $filtered | Where-Object { $_.Name -ieq $requestedName }
                if ($null -eq $match -or @($match).Count -eq 0) {
                    Write-Error "No macro named '$requestedName' found."
                }
            }

            return $filtered
        }

        return $sorted
    }
}
