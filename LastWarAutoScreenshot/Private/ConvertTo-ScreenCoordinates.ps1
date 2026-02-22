function ConvertTo-ScreenCoordinates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$WindowHandle,
        [Parameter(Mandatory)]
        [ValidateRange(0.0, 1.0)]
        [double]$RelativeX,
        [Parameter(Mandatory)]
        [ValidateRange(0.0, 1.0)]
        [double]$RelativeY
    )

    # Validate input range
    if ($RelativeX -lt 0.0 -or $RelativeX -gt 1.0 -or $RelativeY -lt 0.0 -or $RelativeY -gt 1.0) {
        Write-LastWarLog -Level 'Error' -FunctionName 'ConvertTo-ScreenCoordinates' -Message "RelativeX ($RelativeX) and RelativeY ($RelativeY) must be between 0.0 and 1.0." -Context @{ WindowHandle = $WindowHandle; RelativeX = $RelativeX; RelativeY = $RelativeY }
        return $null
    }

    $bounds = Get-WindowBounds -WindowHandle $WindowHandle
    if (-not $bounds) {
        Write-LastWarLog -Level 'Error' -FunctionName 'ConvertTo-ScreenCoordinates' -Message 'Failed to get window bounds.' -Context @{ WindowHandle = $WindowHandle }
        return $null
    }

    $AbsoluteX = [int]($bounds.Left + $RelativeX * $bounds.Width)
    $AbsoluteY = [int]($bounds.Top + $RelativeY * $bounds.Height)

    [PSCustomObject]@{
        X = $AbsoluteX
        Y = $AbsoluteY
    }
}
