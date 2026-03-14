function Start-AutomationSequence {
<#
.SYNOPSIS
    Starts an automation sequence: moves mouse to a window-relative coordinate and clicks.

.DESCRIPTION
    Skeleton implementation for Phase 2, Task 1.10. Moves mouse to a window-relative coordinate and clicks, with emergency stop integration points. Human-like movement is added in Phase 2.6.

.PARAMETER WindowHandle
    The handle of the target window. Accepts IntPtr, int64, int, or string.

.PARAMETER RelativeX
    The X coordinate as a percentage (0.0-1.0) relative to the window's width. Mutually exclusive with -Region.

.PARAMETER RelativeY
    The Y coordinate as a percentage (0.0-1.0) relative to the window's height. Mutually exclusive with -Region.

.PARAMETER Region
    A PSCustomObject defining a Box or Circle area from which a random target position is selected via Get-RandomTargetPosition.
    Box format: @{ RelativeX; RelativeY; RelativeWidth; RelativeHeight } (all 0.0-1.0)
    Circle format: @{ RelativeCentreX; RelativeCentreY; RelativeRadius } (all 0.0-1.0)
    Mutually exclusive with -RelativeX/-RelativeY.

.EXAMPLE
    Start-AutomationSequence -WindowHandle $handle -RelativeX 0.5 -RelativeY 0.5

.EXAMPLE
    $box = [PSCustomObject]@{ RelativeX = 0.4; RelativeY = 0.4; RelativeWidth = 0.2; RelativeHeight = 0.2 }
    Start-AutomationSequence -WindowHandle $handle -Region $box

.NOTES
    Human-like movement (Bezier, jitter, etc.) is implemented in Phase 2.6.
    -Region parameter added in Phase 2 Task 3.3 (ProjectPlan.md).
#>
    [CmdletBinding(DefaultParameterSetName='Scalar')]
    param(
        [Parameter(Mandatory=$true)]
        $WindowHandle,
        [Parameter(Mandatory=$true, ParameterSetName='Scalar')]
        [double]$RelativeX,
        [Parameter(Mandatory=$true, ParameterSetName='Scalar')]
        [double]$RelativeY,
        [Parameter(Mandatory=$true, ParameterSetName='Region')]
        [PSCustomObject]$Region
    )

    $Config = Get-ModuleConfiguration
    if ($Config.EmergencyStop.AutoStart) {
        Start-EmergencyStopMonitor | Out-Null
    }

    try {
        if ($script:EmergencyStopRequested) {
            Write-LastWarLog -Level Warning -Message 'Emergency stop requested before mouse move. Aborting sequence.'
            return [PSCustomObject]@{
                Success = $false
                Message = 'Aborted: Emergency stop requested before mouse move.'
            }
        }

        # Determine RelativeX/RelativeY from Region (Box or Circle) or use scalar values directly
        if ($PSCmdlet.ParameterSetName -eq 'Region') {
            # Detect Circle vs Box by presence of RelativeRadius property
            if ($null -ne $Region.PSObject.Properties['RelativeRadius']) {
                $rand = Get-RandomTargetPosition -Circle $Region
            } else {
                $rand = Get-RandomTargetPosition -Box $Region
            }
            if (-not $rand) {
                Write-LastWarLog -Level Error -Message 'Failed to get random target position from region.'
                return [PSCustomObject]@{
                    Success = $false
                    Message = 'Failed to get random target position.'
                }
            }
            $RelativeX = $rand.RelativeX
            $RelativeY = $rand.RelativeY
        }
        # else: Scalar parameter set, use provided values

        $coords = ConvertTo-ScreenCoordinates -WindowHandle $WindowHandle -RelativeX $RelativeX -RelativeY $RelativeY
        if (-not $coords) {
            Write-LastWarLog -Level Error -Message 'Failed to convert to screen coordinates.'
            return [PSCustomObject]@{
                Success = $false
                Message = 'Failed to convert to screen coordinates.'
            }
        }

        $currentPos = Invoke-GetCursorPosition
        if (-not $currentPos) {
            Write-LastWarLog -Level Error -Message 'Failed to get current cursor position.'
            return [PSCustomObject]@{
                Success = $false
                Message = 'Failed to get current cursor position.'
            }
        }

        $bezierPoints = Get-BezierPoints -StartX $currentPos.X -StartY $currentPos.Y -EndX $coords.X -EndY $coords.Y
        $moveResult = Invoke-MouseMovePath -Points $bezierPoints
        if (-not $moveResult) {
            Write-LastWarLog -Level Error -Message 'Failed to move mouse to target point.'
            return [PSCustomObject]@{
                Success = $false
                Message = 'Failed to move mouse to target point.'
            }
        }

        # Click pre-delay
        $config = Get-ModuleConfiguration
        $minPreDelay = $config.MouseControl.MinClickPreDelayMs
        $maxPreDelay = $config.MouseControl.MaxClickPreDelayMs
        Start-Sleep -Milliseconds (Get-Random -Minimum $minPreDelay -Maximum ($maxPreDelay + 1))

        if ($script:EmergencyStopRequested) {
            Write-LastWarLog -Level Warning -Message 'Emergency stop requested after mouse move. Skipping click.'
            return [PSCustomObject]@{
                Success = $false
                Message = 'Aborted: Emergency stop requested after mouse move.'
            }
        }

        $clickResult = Invoke-MouseClick -X $coords.X -Y $coords.Y
        if (-not $clickResult) {
            Write-LastWarLog -Level Error -Message 'Mouse click failed.'
            return [PSCustomObject]@{
                Success = $false
                Message = 'Mouse click failed.'
            }
        }

        # Click post-delay
        $minPostDelay = $config.MouseControl.MinClickPostDelayMs
        $maxPostDelay = $config.MouseControl.MaxClickPostDelayMs
        $postDelayMs  = Get-Random -Minimum $minPostDelay -Maximum ($maxPostDelay + 1)
        Start-Sleep -Milliseconds $postDelayMs

        return [PSCustomObject]@{
            Success = $true
            Message = 'Automation sequence completed successfully.'
        }
    }
    finally {
        Stop-EmergencyStopMonitor | Out-Null
    }
}

