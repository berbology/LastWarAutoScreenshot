# Invoke-MouseMovePath.ps1
# Implements phase 2 task 2.5 as specified in ProjectPlan.md

function Invoke-MouseMovePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject[]]$Points
    )

    # Load config values
    $config = Get-ModuleConfiguration
    $MovementDurationRangeMs = $config.MouseControl.MovementDurationRangeMs
    $MicroPauseChance = $config.MouseControl.MicroPauseChance
    $MicroPauseDurationRangeMs = $config.MouseControl.MicroPauseDurationRangeMs
    $OvershootEnabled = $config.MouseControl.OvershootEnabled
    $OvershootFactor = $config.MouseControl.OvershootFactor

    # Calculate total move duration
    $totalDurationMs = Get-Random -Minimum $MovementDurationRangeMs[0] -Maximum ($MovementDurationRangeMs[1] + 1)
    $numSteps = $Points.Count
    if ($numSteps -lt 2) {
        Write-Error "Invoke-MouseMovePath: At least 2 points required."
        return $false
    }

    # Ease-in/out: larger delays at start and end (slow), smaller in the middle (fast)
    # Uses |cos(πt)| + small base so delays are highest at t=0 and t=1 (start/end)
    $numActualSteps = $numSteps - 1
    $stepDelays = [double[]]::new($numSteps)
    for ($i = 1; $i -lt $numSteps; $i++) {
        $t = if ($numActualSteps -le 1) { 0.0 } else { ($i - 1.0) / ($numActualSteps - 1.0) }
        $stepDelays[$i] = [math]::Abs([math]::Cos($t * [math]::PI)) + 0.1
    }
    $sumEase = 0.0
    for ($j = 1; $j -lt $numSteps; $j++) { $sumEase += $stepDelays[$j] }
    for ($j = 1; $j -lt $numSteps; $j++) {
        $stepDelays[$j] = $stepDelays[$j] * $totalDurationMs / $sumEase
    }

    $success = $true
    for ($i = 1; $i -lt $numSteps; $i++) {
        $prev = $Points[$i-1]
        $curr = $Points[$i]
        $deltaX = $curr.X - $prev.X
        $deltaY = $curr.Y - $prev.Y
        $result = Invoke-SendMouseInput -DeltaX $deltaX -DeltaY $deltaY
        if (-not $result) {
            $success = $false
            Write-LastWarLog -Level Error -Message "Invoke-MouseMovePath: SendInput error at step $i" -FunctionName 'Invoke-MouseMovePath'
            Write-Host "`e[31mInvoke-MouseMovePath: SendInput error at step $i`e[0m"
        }
        Start-Sleep -Milliseconds ([int]$stepDelays[$i])
        if ((Get-Random -Minimum 0.0 -Maximum 1.0) -lt $MicroPauseChance) {
            $pauseMs = Get-Random -Minimum $MicroPauseDurationRangeMs[0] -Maximum ($MicroPauseDurationRangeMs[1] + 1)
            Start-Sleep -Milliseconds $pauseMs
        }
    }

    # Overshoot logic
    if ($OvershootEnabled) {
        $dx = $Points[-1].X - $Points[-2].X
        $dy = $Points[-1].Y - $Points[-2].Y
        $lastStepLen = [math]::Sqrt(([math]::Pow($dx,2)) + ([math]::Pow($dy,2)))
        # Overshoot vector is scaled by OvershootFactor * lastStepLen, in the direction of the last step
        if ($lastStepLen -ne 0) {
            $overshootVecX = [int](($dx / $lastStepLen) * ($OvershootFactor * $lastStepLen))
            $overshootVecY = [int](($dy / $lastStepLen) * ($OvershootFactor * $lastStepLen))
        } else {
            $overshootVecX = 0
            $overshootVecY = 0
        }
        $overshootX = [int]($Points[-1].X + $overshootVecX)
        $overshootY = [int]($Points[-1].Y + $overshootVecY)
        $correctionPoints = Get-BezierPoints -StartX $overshootX -StartY $overshootY -EndX $Points[-1].X -EndY $Points[-1].Y
        for ($i = 1; $i -lt $correctionPoints.Count; $i++) {
            $prev = $correctionPoints[$i-1]
            $curr = $correctionPoints[$i]
            $deltaX = $curr.X - $prev.X
            $deltaY = $curr.Y - $prev.Y
            $result = Invoke-SendMouseInput -DeltaX $deltaX -DeltaY $deltaY
            if (-not $result) {
                $success = $false
                Write-LastWarLog -Level Error -Message "Invoke-MouseMovePath: Correction SendInput error at step $i" -FunctionName 'Invoke-MouseMovePath'
                Write-Host "`e[31mInvoke-MouseMovePath: Correction SendInput error at step $i`e[0m"
            }
            Start-Sleep -Milliseconds 5
        }
    }

    return $success
}
