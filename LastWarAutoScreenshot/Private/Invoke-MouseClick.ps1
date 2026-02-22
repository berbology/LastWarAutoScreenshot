<#
    .SYNOPSIS
    Sends a mouse click (left button) at specified screen coordinates.
    .DESCRIPTION
    Moves the mouse to (X, Y) if not already there, then performs a left mouse button click.
    Down duration is configurable or can be specified directly.
    Logs errors and returns $true/$false.
    .PARAMETER X
    Absolute X coordinate (pixels).
    .PARAMETER Y
    Absolute Y coordinate (pixels).
    .PARAMETER DownDurationMs
    Optional. Duration (ms) to hold mouse button down. If omitted, uses config range.
    .EXAMPLE
    Invoke-MouseClick -X 100 -Y 200 -DownDurationMs 75
    .EXAMPLE
    Invoke-MouseClick -X 100 -Y 200
    .NOTES
    Implements ProjectPlan Phase 2 task 1.7. Uses event flags, not magic numbers.
#>
function Invoke-MouseClick {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$X,
        [Parameter(Mandatory)]
        [int]$Y,
        [int]$DownDurationMs
    )

    # Constants from MouseControlAPI
    $MOUSEEVENTF_LEFTDOWN = [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_LEFTDOWN
    $MOUSEEVENTF_LEFTUP   = [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_LEFTUP

    # Move mouse if not already at target
    $currentPos = Invoke-GetCursorPosition
    if ($null -eq $currentPos) {
        Write-LastWarLog -Level Error -Message "Failed to get current cursor position in Invoke-MouseClick." -Context @{ X = $X; Y = $Y }
        return $false
    }
    if ($currentPos.X -ne $X -or $currentPos.Y -ne $Y) {
        $moveResult = Move-MouseToPoint -X $X -Y $Y
        if (-not $moveResult) {
            Write-LastWarLog -Level Error -Message "Failed to move mouse to ($X, $Y) before click." -Context @{ X = $X; Y = $Y }
            Write-Host "\e[31mError: Failed to move mouse to ($X, $Y). See log for details.\e[0m"
            return $false
        }
    }

    # Determine click down duration
    if (-not $PSBoundParameters.ContainsKey('DownDurationMs')) {
        $config = Get-ModuleConfiguration
        $range = $config.MouseControl.ClickDownDurationRangeMs
        if ($null -eq $range -or $range.Count -ne 2) {
            $DownDurationMs = 100
        } else {
            $DownDurationMs = Get-Random -Minimum $range[0] -Maximum ($range[1] + 1)
        }
    }

    # Send left button down
    $downResult = Invoke-SendMouseInput -DeltaX 0 -DeltaY 0 -ButtonFlags $MOUSEEVENTF_LEFTDOWN
    if (-not $downResult) {
        Write-LastWarLog -Level Error -Message "Failed to send MOUSEEVENTF_LEFTDOWN at ($X, $Y)." -Context @{ X = $X; Y = $Y }
        Write-Host "\e[31mError: Failed to send mouse down event. See log for details.\e[0m"
        return $false
    }

    # Hold button down
    Start-Sleep -Milliseconds $DownDurationMs

    # Send left button up
    $upResult = Invoke-SendMouseInput -DeltaX 0 -DeltaY 0 -ButtonFlags $MOUSEEVENTF_LEFTUP
    if (-not $upResult) {
        Write-LastWarLog -Level Error -Message "Failed to send MOUSEEVENTF_LEFTUP at ($X, $Y)." -Context @{ X = $X; Y = $Y }
        Write-Host "\e[31mError: Failed to send mouse up event. See log for details.\e[0m"
        return $false
    }

    return $true
}
