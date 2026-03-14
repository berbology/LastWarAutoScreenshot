function Invoke-MouseDragPath {
    <#
    .SYNOPSIS
        Moves the mouse cursor along a Bezier path whilst a mouse button is held down.

    .DESCRIPTION
        Moves through each point using SendInput with MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE,
        ensuring all movement events are injected through the same hardware input queue as the
        held button event. This is required for reliable drag recognition in Win32 applications
        such as games; SetCursorPos injects movement through a separate codepath and cannot be
        relied upon during a SendInput-based drag.

        Overshoot is intentionally omitted. Overshooting whilst a button is held draws an
        unintended correction path in the target application.

        Easing and micro-pause behaviour match Invoke-MouseMovePath.

    .PARAMETER Points
        Ordered array of PSCustomObject points (each with X and Y properties) representing the
        drag path. Must contain at least two points.

    .OUTPUTS
        [bool] $true if all steps succeeded, $false if any SendInput call failed.

    .EXAMPLE
        $path = Get-BezierPoints -StartX 100 -StartY 100 -EndX 500 -EndY 300
        Invoke-MouseDragPath -Points $path
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Points
    )

    $config                    = Get-ModuleConfiguration
    $MinMovementDurationMs     = $config.MouseControl.MinMovementDurationMs
    $MaxMovementDurationMs     = $config.MouseControl.MaxMovementDurationMs
    $MicroPauseChance          = $config.MouseControl.MicroPauseChance
    $MinMicroPauseDurationMs   = $config.MouseControl.MinMicroPauseDurationMs
    $MaxMicroPauseDurationMs   = $config.MouseControl.MaxMicroPauseDurationMs

    $numSteps = $Points.Count
    if ($numSteps -lt 2) {
        throw 'Invoke-MouseDragPath: At least 2 points required.'
    }

    $totalDurationMs = Get-Random -Minimum $MinMovementDurationMs -Maximum ($MaxMovementDurationMs + 1)

    # Ease-in/out: same |cos(πt)| curve as Invoke-MouseMovePath
    $numActualSteps = $numSteps - 1
    $stepDelays     = [double[]]::new($numSteps)
    for ($i = 1; $i -lt $numSteps; $i++) {
        $t              = if ($numActualSteps -le 1) { 0.0 } else { ($i - 1.0) / ($numActualSteps - 1.0) }
        $stepDelays[$i] = [math]::Abs([math]::Cos($t * [math]::PI)) + 0.1
    }
    $sumEase = 0.0
    for ($j = 1; $j -lt $numSteps; $j++) { $sumEase += $stepDelays[$j] }
    for ($j = 1; $j -lt $numSteps; $j++) {
        $stepDelays[$j] = $stepDelays[$j] * $totalDurationMs / $sumEase
    }

    $success = $true
    for ($i = 1; $i -lt $numSteps; $i++) {
        $curr   = $Points[$i]
        $result = Invoke-SendMouseMoveAbsolute -X $curr.X -Y $curr.Y
        if (-not $result) {
            $success = $false
            Write-LastWarLog -Level Error -Message "Invoke-MouseDragPath: SendInput move error at step $i" -FunctionName 'Invoke-MouseDragPath'
        }
        Start-Sleep -Milliseconds ([int]$stepDelays[$i])
        if ((Get-Random -Minimum 0.0 -Maximum 1.0) -lt $MicroPauseChance) {
            $pauseMs = Get-Random -Minimum $MinMicroPauseDurationMs -Maximum ($MaxMicroPauseDurationMs + 1)
            Start-Sleep -Milliseconds $pauseMs
        }
    }

    return $success
}
