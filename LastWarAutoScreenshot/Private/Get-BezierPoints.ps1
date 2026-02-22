#region Get-BezierPoints
function Get-BezierPoints {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$StartX,
        [Parameter(Mandatory=$true)]
        [int]$StartY,
        [Parameter(Mandatory=$true)]
        [int]$EndX,
        [Parameter(Mandatory=$true)]
        [int]$EndY,
        [int]$NumPoints,
        [double]$ControlPointOffsetFactor,
        [int]$JitterRadiusPx
    )
    # Load config defaults if parameters are omitted
    $config = Get-ModuleConfiguration
    if (-not $PSBoundParameters.ContainsKey('NumPoints')) {
        $NumPoints = $config.MouseControl.PathPointCount
    }
    if (-not $PSBoundParameters.ContainsKey('ControlPointOffsetFactor')) {
        $ControlPointOffsetFactor = $config.MouseControl.BezierControlPointOffsetFactor
    }
    if (-not $PSBoundParameters.ContainsKey('JitterRadiusPx')) {
        $JitterRadiusPx = $config.MouseControl.JitterRadiusPx
    }
    # Randomise NumPoints ±20%
    $baseNum = $NumPoints
    $minNum = [math]::Floor($baseNum * 0.8)
    $maxNum = [math]::Ceiling($baseNum * 1.2)
    $NumPoints = Get-Random -Minimum $minNum -Maximum $maxNum
    # Calculate control point
    $midX = ($StartX + $EndX) / 2
    $midY = ($StartY + $EndY) / 2
    $dx = $EndX - $StartX
    $dy = $EndY - $StartY
    $length = [math]::Sqrt($dx*$dx + $dy*$dy)
    if ($length -eq 0) {
        $controlX = $midX
        $controlY = $midY
    } else {
        # Perpendicular offset
        $perpX = -$dy / $length
        $perpY = $dx / $length
        $offsetMag = $ControlPointOffsetFactor * $length
        $randSign = if ((Get-Random -Minimum 0 -Maximum 2) -eq 0) { -1 } else { 1 }
        $offset = $randSign * $offsetMag * (Get-Random -Minimum 0.5 -Maximum 1.0)
        $controlX = $midX + $perpX * $offset
        $controlY = $midY + $perpY * $offset
    }
    $points = @()
    for ($i = 0; $i -lt $NumPoints; $i++) {
        $t = $i / ($NumPoints - 1)
        $x = [math]::Round((1-$t)*(1-$t)*$StartX + 2*(1-$t)*$t*$controlX + $t*$t*$EndX)
        $y = [math]::Round((1-$t)*(1-$t)*$StartY + 2*(1-$t)*$t*$controlY + $t*$t*$EndY)
        if ($config.MouseControl.JitterEnabled) {
            $x += Get-Random -Minimum -$JitterRadiusPx -Maximum ($JitterRadiusPx+1)
            $y += Get-Random -Minimum -$JitterRadiusPx -Maximum ($JitterRadiusPx+1)
        }
        $points += [PSCustomObject]@{ X = [int]$x; Y = [int]$y }
    }
    return $points
}
#endregion
