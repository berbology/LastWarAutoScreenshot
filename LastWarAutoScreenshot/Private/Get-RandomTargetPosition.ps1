<#
.SYNOPSIS
    Generate a random target position within a bounding box or circle (relative coordinates).
.DESCRIPTION
    Provides two parameter sets:
    -Box: Uniform random within a box defined by RelativeX, RelativeY, RelativeWidth, RelativeHeight (all 0.0–1.0).
    -Circle: Uniform random within a circle defined by RelativeCentreX, RelativeCentreY, RelativeRadius (all 0.0–1.0).
    Output is clamped to [0.0, 1.0] for both axes. Returns PSCustomObject @{RelativeX; RelativeY} or $null on invalid input.
    Pure PowerShell, no Add-Type.
.PARAMETER Box
    PSCustomObject with properties: RelativeX, RelativeY, RelativeWidth, RelativeHeight (all 0.0–1.0)
.PARAMETER Circle
    PSCustomObject with properties: RelativeCentreX, RelativeCentreY, RelativeRadius (all 0.0–1.0)
.EXAMPLE
    Get-RandomTargetPosition -Box $box
.EXAMPLE
    Get-RandomTargetPosition -Circle $circle
.NOTES
    Implements Phase 2 Task 3.1 (ProjectPlan.md)
#>

function Get-RandomTargetPosition {
    [CmdletBinding(DefaultParameterSetName='Box')]
    param (
        [Parameter(Mandatory=$true, ParameterSetName='Box')]
        [PSCustomObject]$Box,
        [Parameter(Mandatory=$true, ParameterSetName='Circle')]
        [PSCustomObject]$Circle
    )

    if ($PSCmdlet.ParameterSetName -eq 'Box') {
        $requiredBoxProps = @('RelativeX','RelativeY','RelativeWidth','RelativeHeight')
        foreach ($prop in $requiredBoxProps) {
            if ($null -eq $Box.PSObject.Properties[$prop]) {
                Write-LastWarLog -Level Error -Message "Box object is missing required property: $prop"
                return $null
            }
        }
        if ($Box.RelativeX -lt 0.0 -or $Box.RelativeY -lt 0.0 -or
            $Box.RelativeWidth -le 0.0 -or $Box.RelativeHeight -le 0.0 -or
            ($Box.RelativeX + $Box.RelativeWidth) -gt 1.0 -or
            ($Box.RelativeY + $Box.RelativeHeight) -gt 1.0) {
            Write-LastWarLog -Level Error -Message 'Box properties are out of valid range [0.0, 1.0].'
            return $null
        }
        $rx = $Box.RelativeX + (Get-Random -Minimum 0.0 -Maximum 1.0) * $Box.RelativeWidth
        $ry = $Box.RelativeY + (Get-Random -Minimum 0.0 -Maximum 1.0) * $Box.RelativeHeight
        $rx = [math]::Max(0.0, [math]::Min(1.0, $rx))
        $ry = [math]::Max(0.0, [math]::Min(1.0, $ry))
        return [PSCustomObject]@{ RelativeX = [double]$rx; RelativeY = [double]$ry }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'Circle') {
        $requiredCircleProps = @('RelativeCentreX','RelativeCentreY','RelativeRadius')
        foreach ($prop in $requiredCircleProps) {
            if ($null -eq $Circle.PSObject.Properties[$prop]) {
                Write-LastWarLog -Level Error -Message "Circle object is missing required property: $prop"
                return $null
            }
        }
        if ($Circle.RelativeCentreX -lt 0.0 -or $Circle.RelativeCentreY -lt 0.0 -or
            $Circle.RelativeRadius -le 0.0 -or
            ($Circle.RelativeCentreX + $Circle.RelativeRadius) -gt 1.0 -or
            ($Circle.RelativeCentreY + $Circle.RelativeRadius) -gt 1.0) {
            Write-LastWarLog -Level Error -Message 'Circle properties are out of valid range [0.0, 1.0].'
            return $null
        }
        $cx = $Circle.RelativeCentreX
        $cy = $Circle.RelativeCentreY
        $r = $Circle.RelativeRadius
        $angle = 2 * [math]::PI * (Get-Random -Minimum 0.0 -Maximum 1.0)
        $radius = [math]::Sqrt((Get-Random -Minimum 0.0 -Maximum 1.0)) * $r
        $rx = $cx + $radius * [math]::Cos($angle)
        $ry = $cy + $radius * [math]::Sin($angle)
        $rx = [math]::Max(0.0, [math]::Min(1.0, $rx))
        $ry = [math]::Max(0.0, [math]::Min(1.0, $ry))
        return [PSCustomObject]@{ RelativeX = [double]$rx; RelativeY = [double]$ry }
    }
    else {
        Write-LastWarLog -Level Error -Message 'Unknown parameter set for Get-RandomTargetPosition.'
        return $null
    }
}
