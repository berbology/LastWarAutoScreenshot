function Invoke-CompareImages {
    <#
    .SYNOPSIS
        Compares two PNG images using deterministic grid-based pixel sampling.

    .DESCRIPTION
        Loads both images as System.Drawing.Bitmap objects and compares sampled pixels
        using a deterministic grid traversal algorithm, returning a match ratio between
        0.0 and 1.0.  Returns -1.0 on argument errors, 0.0 on dimension mismatch.

        The sampling algorithm is identical to the C# specification in the project plan:
        x = (int)((double)i / sampleCount * width) % width
        y = (int)((double)i / sampleCount * height)
        This produces reproducible results across test runs without any random seeding.

    .PARAMETER Path1
        Path to the first image file. Must exist.

    .PARAMETER Path2
        Path to the second image file. Must exist.

    .PARAMETER SampleCount
        Number of pixels to sample. Must be >= 1. Ignored when FullScan is $true.

    .PARAMETER TolerancePerChannel
        Maximum per-channel (R/G/B) difference that still counts as a matching pixel (0–255).

    .PARAMETER FullScan
        When $true, every pixel is compared regardless of SampleCount.

    .OUTPUTS
        System.Double
        Match ratio 0.0–1.0 on success; 0.0 when image dimensions differ; -1.0 on argument error.
    #>
    [CmdletBinding()]
    [OutputType([double])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path1,

        [Parameter(Mandatory, Position = 1)]
        [string]$Path2,

        [Parameter(Mandatory, Position = 2)]
        [int]$SampleCount,

        [Parameter(Mandatory, Position = 3)]
        [int]$TolerancePerChannel,

        [Parameter(Mandatory, Position = 4)]
        [bool]$FullScan
    )

    # ── Argument validation ──────────────────────────────────────────────────────
    if ([string]::IsNullOrEmpty($Path1) -or -not (Test-Path $Path1)) { return [double]-1.0 }
    if ([string]::IsNullOrEmpty($Path2) -or -not (Test-Path $Path2)) { return [double]-1.0 }
    if ($SampleCount -lt 1) { return [double]-1.0 }
    if ($TolerancePerChannel -lt 0 -or $TolerancePerChannel -gt 255) { return [double]-1.0 }

    $bmp1 = $null
    $bmp2 = $null
    try {
        $bmp1 = [System.Drawing.Bitmap]::new($Path1)
        $bmp2 = [System.Drawing.Bitmap]::new($Path2)

        if ($bmp1.Width -ne $bmp2.Width -or $bmp1.Height -ne $bmp2.Height) {
            return [double]0.0
        }

        if ($FullScan) {
            $SampleCount = $bmp1.Width * $bmp1.Height
        }

        $matchCount = 0
        for ($i = 0; $i -lt $SampleCount; $i++) {
            $x = [int]([double]$i / $SampleCount * $bmp1.Width)  % $bmp1.Width
            $y = [int]([double]$i / $SampleCount * $bmp1.Height)
            
            # Ensure coordinates stay within bitmap bounds (defensive against floating-point rounding)
            if ($y -ge $bmp1.Height) { $y = $bmp1.Height - 1 }
            if ($x -ge $bmp1.Width)  { $x = $bmp1.Width - 1 }

            $c1 = $bmp1.GetPixel($x, $y)
            $c2 = $bmp2.GetPixel($x, $y)

            if ([Math]::Abs($c1.R - $c2.R) -le $TolerancePerChannel -and
                [Math]::Abs($c1.G - $c2.G) -le $TolerancePerChannel -and
                [Math]::Abs($c1.B - $c2.B) -le $TolerancePerChannel) {
                $matchCount++
            }
        }

        return [double]$matchCount / $SampleCount
    } finally {
        if ($null -ne $bmp1) { $bmp1.Dispose() }
        if ($null -ne $bmp2) { $bmp2.Dispose() }
    }
}
