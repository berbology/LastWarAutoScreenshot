# Move-MouseToPoint.ps1

<##
.SYNOPSIS
    Moves the mouse cursor to the specified absolute screen coordinates (X, Y).
.DESCRIPTION
    Placeholder implementation for mouse movement. Computes delta from current cursor position to target, then sends a mouse move event using SendInput. Logs errors and returns $true/$false. Replaced by Invoke-MouseMovePath in Phase 2 step 2.5.
.PARAMETER X
    Target X coordinate (integer, absolute screen position).
.PARAMETER Y
    Target Y coordinate (integer, absolute screen position).
.EXAMPLE
    Move-MouseToPoint -X 100 -Y 200
.NOTES
    This is a placeholder for step 1.6. It will be replaced by Invoke-MouseMovePath in step 2.5.
##>

function Move-MouseToPoint {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [int]$X,
        [Parameter(Mandatory=$true)]
        [int]$Y
    )

    try {
        $current = Invoke-GetCursorPosition
        if ($null -eq $current) {
            Write-LastWarLog -Level Error -Message "Failed to get current cursor position." -FunctionName 'Move-MouseToPoint'
            Write-Host "\e[31mError: Unable to get current cursor position.\e[0m" -NoNewline
            return $false
        }
        $deltaX = $X - $current.X
        $deltaY = $Y - $current.Y
            $moveFlag = [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_MOVE
            $result = Invoke-SendMouseInput -DeltaX $deltaX -DeltaY $deltaY -ButtonFlags $moveFlag
        if (-not $result) {
            Write-LastWarLog -Level Error -Message "SendInput failed to move mouse." -FunctionName 'Move-MouseToPoint'
            Write-Host "\e[31mError: Mouse move failed. See log for details.\e[0m" -NoNewline
            return $false
        }
        return $true
    } catch {
        Write-LastWarLog -Level Error -Message $_.Exception.Message -FunctionName 'Move-MouseToPoint'
        Write-Host "\e[31mError: Exception occurred. See log for details.\e[0m" -NoNewline
        return $false
    }
}
