<#
    .SYNOPSIS
    Performs a drag-click: moves to a start position, holds the left mouse button, drags to
    an end position via a Bezier path, then releases the button.
    .DESCRIPTION
    Orchestrates existing mouse control helpers to execute a human-like drag gesture:
    1. Moves to the start position using a Bezier path.
    2. Checks for emergency stop before pressing the button.
    3. Sends MOUSEEVENTF_LEFTDOWN to begin the drag.
    4. Moves to the end position using a Bezier path while the button is held.
    5. Sends MOUSEEVENTF_LEFTUP in a finally block to guarantee the button is always released.
    All delay durations are read from the MouseControl section of the module configuration.
    .PARAMETER StartX
    Absolute X coordinate (pixels) of the drag start position.
    .PARAMETER StartY
    Absolute Y coordinate (pixels) of the drag start position.
    .PARAMETER EndX
    Absolute X coordinate (pixels) of the drag end position.
    .PARAMETER EndY
    Absolute Y coordinate (pixels) of the drag end position.
    .OUTPUTS
    [PSCustomObject] with properties:
      Success [bool]   — Whether the drag completed without error or interruption.
      Message [string] — Human-readable description of failure cause (empty on success).
    .NOTES
    SAFETY: MOUSEEVENTF_LEFTUP is sent in a finally block. This guarantees the mouse button is
    released even if an exception is thrown or an emergency stop is triggered mid-drag. A stuck
    left button would render the system unusable, so this protection is non-negotiable.
    Implements ProjectPlan Phase 4 task 4.1.
    .EXAMPLE
    $result = Invoke-MouseDragClick -StartX 500 -StartY 800 -EndX 500 -EndY 200
    if (-not $result.Success) { Write-Warning $result.Message }
#>
function Invoke-MouseDragClick {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$StartX,
        [Parameter(Mandatory)]
        [int]$StartY,
        [Parameter(Mandatory)]
        [int]$EndX,
        [Parameter(Mandatory)]
        [int]$EndY
    )

    $MOUSEEVENTF_LEFTDOWN = [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_LEFTDOWN
    $MOUSEEVENTF_LEFTUP   = [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_LEFTUP

    $config      = Get-ModuleConfiguration
    $mouseConfig = $config.MouseControl

    $minPreDelay    = $mouseConfig.MinClickPreDelayMs
    $maxPreDelay    = $mouseConfig.MaxClickPreDelayMs
    $minHold        = $mouseConfig.MinClickDownDurationMs
    $maxHold        = $mouseConfig.MaxClickDownDurationMs
    $minPostDelay   = $mouseConfig.MinClickPostDelayMs
    $maxPostDelay   = $mouseConfig.MaxClickPostDelayMs

    # Step 1 — Move to start position
    $currentPos = Invoke-GetCursorPosition
    if ($null -eq $currentPos) {
        Write-LastWarLog -Level Error -Message 'Invoke-MouseDragClick: Failed to get current cursor position.' -FunctionName 'Invoke-MouseDragClick'
        return [PSCustomObject]@{ Success = $false; Message = 'Failed to get current cursor position.' }
    }

    $pathToStart = Get-BezierPoints -StartX $currentPos.X -StartY $currentPos.Y -EndX $StartX -EndY $StartY
    $moveResult  = Invoke-MouseMovePath -Points $pathToStart
    if (-not $moveResult) {
        Write-LastWarLog -Level Error -Message "Invoke-MouseDragClick: Failed to move to start position ($StartX, $StartY)." -FunctionName 'Invoke-MouseDragClick'
        return [PSCustomObject]@{ Success = $false; Message = "Failed to move to start position ($StartX, $StartY)." }
    }

    # Step 2 — Emergency stop check before pressing button
    if ($script:EmergencyStopRequested) {
        return [PSCustomObject]@{ Success = $false; Message = 'Emergency stop triggered before drag.' }
    }

    # Step 3 — Pre-click delay
    Start-Sleep -Milliseconds (Get-Random -Minimum $minPreDelay -Maximum ($maxPreDelay + 1))

    $buttonDownSent = $false
    $success        = $true
    $message        = ''

    try {
        # Step 4 — Mouse button down
        $downResult = Invoke-SendMouseInput -DeltaX 0 -DeltaY 0 -ButtonFlags $MOUSEEVENTF_LEFTDOWN
        if (-not $downResult) {
            Write-LastWarLog -Level Error -Message 'Invoke-MouseDragClick: Failed to send MOUSEEVENTF_LEFTDOWN.' -FunctionName 'Invoke-MouseDragClick'
            $success = $false
            $message = 'Failed to send mouse button down event.'
            return [PSCustomObject]@{ Success = $false; Message = $message }
        }
        $buttonDownSent = $true

        # Step 5 — Hold delay
        Start-Sleep -Milliseconds (Get-Random -Minimum $minHold -Maximum ($maxHold + 1))

        # Step 6 — Emergency stop check after button is down
        if ($script:EmergencyStopRequested) {
            $success = $false
            $message = 'Emergency stop triggered during drag.'
            return [PSCustomObject]@{ Success = $false; Message = $message }
        }

        # Step 7 — Drag to end position via SendInput (not SetCursorPos) to stay in the hardware input queue
        $dragPath   = Get-BezierPoints -StartX $StartX -StartY $StartY -EndX $EndX -EndY $EndY
        $dragResult = Invoke-MouseDragPath -Points $dragPath
        if (-not $dragResult) {
            Write-LastWarLog -Level Error -Message "Invoke-MouseDragClick: Failed to drag to end position ($EndX, $EndY)." -FunctionName 'Invoke-MouseDragClick'
            $success = $false
            $message = "Failed to drag to end position ($EndX, $EndY)."
        }
    }
    finally {
        # Step 8 — Mouse button up (always executed to prevent stuck button)
        if ($buttonDownSent) {
            $upResult = Invoke-SendMouseInput -DeltaX 0 -DeltaY 0 -ButtonFlags $MOUSEEVENTF_LEFTUP
            if (-not $upResult) {
                Write-LastWarLog -Level Error -Message 'Invoke-MouseDragClick: Failed to send MOUSEEVENTF_LEFTUP.' -FunctionName 'Invoke-MouseDragClick'
                $success = $false
                if (-not $message) { $message = 'Failed to send mouse button up event.' }
            }
        }
    }

    # Step 9 — Post-click delay
    if ($success) {
        Start-Sleep -Milliseconds (Get-Random -Minimum $minPostDelay -Maximum ($maxPostDelay + 1))
    }

    return [PSCustomObject]@{ Success = $success; Message = $message }
}
