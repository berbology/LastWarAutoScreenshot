function Test-ScreenshotSimilarity {
    <#
    .SYNOPSIS
        Compares two screenshot images to determine whether they are visually similar.

    .DESCRIPTION
        Reads similarity configuration from Get-ModuleConfiguration (Threshold, SampleCount,
        TolerancePerChannel, FullScan) and delegates pixel comparison to Invoke-CompareImages.
        Returns a result object indicating whether the images meet the similarity threshold.

    .PARAMETER ReferencePath
        Full path to the reference (previous) screenshot image file.

    .PARAMETER ComparePath
        Full path to the comparison (current) screenshot image file.

    .OUTPUTS
        PSCustomObject with properties:
            Similar      ([bool])   : $true when MatchPercent >= configured Threshold
            MatchPercent ([double]) : Raw CompareImages return value (0.0-1.0, or -1.0 on error)
            Skipped      ([bool])   : $true when path validation prevented the comparison
            Message      ([string]) : Human-readable description; empty on success

    .NOTES
        MatchPercent is a decimal ratio (0.0-1.0), compared directly against the configured
        Threshold (also 0.0-1.0).  A value of 0.98 means 98% of sampled pixels matched.

        Skipped=$true means the comparison did not run (path missing or null) — it does NOT
        indicate that images are dissimilar.

        Skipped=$false with Similar=$false and MatchPercent=-1.0 indicates an error inside
        the C# comparison method (e.g. corrupt bitmap).
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$ReferencePath,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$ComparePath
    )

    $simConfig          = (Get-ModuleConfiguration).Screenshots.SimilarityCheck
    $threshold          = [double]$simConfig.Threshold
    $sampleCount        = [int]$simConfig.SampleCount
    $fullScan           = [bool]$simConfig.FullScan
    $tolerancePerChannel = [int]$simConfig.TolerancePerChannel

    # ── Reference path validation ─────────────────────────────────────────────
    if ('' -eq $ReferencePath -or (-not (Test-Path $ReferencePath))) {
        Write-LastWarLog -Level Warning -FunctionName 'Test-ScreenshotSimilarity' `
            -Message 'Similarity check skipped: reference image path is null or does not exist'
        return [PSCustomObject]@{
            Similar      = $false
            MatchPercent = 0.0
            Skipped      = $true
            Message      = 'Reference path invalid or not found'
        }
    }

    # ── Compare path validation ───────────────────────────────────────────────
    if ('' -eq $ComparePath -or (-not (Test-Path $ComparePath))) {
        Write-LastWarLog -Level Warning -FunctionName 'Test-ScreenshotSimilarity' `
            -Message 'Similarity check skipped: compare image path is null or does not exist'
        return [PSCustomObject]@{
            Similar      = $false
            MatchPercent = 0.0
            Skipped      = $true
            Message      = 'Compare path invalid or not found'
        }
    }

    # ── Compare images ────────────────────────────────────────────────────────
    $matchRatio = Invoke-CompareImages `
        -Path1               $ReferencePath `
        -Path2               $ComparePath `
        -SampleCount         $sampleCount `
        -TolerancePerChannel $tolerancePerChannel `
        -FullScan            $fullScan

    if ($matchRatio -eq -1.0) {
        Write-LastWarLog -Level Error -FunctionName 'Test-ScreenshotSimilarity' `
            -Message 'Similarity comparison returned an error (-1.0)'
        return [PSCustomObject]@{
            Similar      = $false
            MatchPercent = -1.0
            Skipped      = $false
            Message      = 'CompareImages returned error'
        }
    }

    $similar = ($matchRatio -ge $threshold)

    return [PSCustomObject]@{
        Similar      = $similar
        MatchPercent = $matchRatio
        Skipped      = $false
        Message      = ''
    }
}
