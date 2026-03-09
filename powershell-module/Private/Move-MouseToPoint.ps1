# Move-MouseToPoint.ps1

<##
.SYNOPSIS
    Moves the mouse cursor to the specified absolute screen coordinates (X, Y).
.DESCRIPTION
    Sets the cursor to the given absolute pixel position using SetCursorPos, bypassing
    Windows pointer acceleration. Used by Invoke-MouseClick when the cursor is not already
    at the target position for a single-step jump.
.PARAMETER X
    Target X coordinate (integer, absolute screen position).
.PARAMETER Y
    Target Y coordinate (integer, absolute screen position).
.EXAMPLE
    Move-MouseToPoint -X 100 -Y 200
.NOTES
    Replaced the original placeholder delta/SendInput approach. SetCursorPos sets absolute
    pixel coordinates directly, so pointer speed/acceleration settings have no effect.
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
        $result = Invoke-SetCursorPos -X $X -Y $Y
        if (-not $result) {
            Write-LastWarLog -Level Error -Message "SetCursorPos failed to move mouse." -FunctionName 'Move-MouseToPoint'
            return $false
        }
        return $true
    } catch {
        Write-LastWarLog -Level Error -Message $_.Exception.Message -FunctionName 'Move-MouseToPoint'
        return $false
    }
}

