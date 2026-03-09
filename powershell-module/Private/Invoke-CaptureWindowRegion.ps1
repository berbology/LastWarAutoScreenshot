function Invoke-CaptureWindowRegion {
    <#
    .SYNOPSIS
        Captures a region of a window and saves it as a PNG file.

    .DESCRIPTION
        Uses Win32 PrintWindow(PW_RENDERFULLCONTENT) to render the target window's
        DWM-composited content (including OpenGL surfaces) into a managed bitmap,
        then crops to the specified relative region and saves as PNG.

        Bitmap operations are performed using System.Drawing at runtime rather than
        in a compiled C# class, avoiding System.Private.Windows.Core compilation
        dependencies that are not resolvable in .NET 9 via Add-Type.

        The target window must be non-minimised. Exclusive-fullscreen DirectX/Vulkan
        windows are not supported.

    .PARAMETER WindowHandle
        Handle to the target window. Must not be [IntPtr]::Zero.

    .PARAMETER RelativeX
        Left edge of the capture region as a fraction of window width (0.0–1.0).

    .PARAMETER RelativeY
        Top edge of the capture region as a fraction of window height (0.0–1.0).

    .PARAMETER RelativeWidth
        Width of the capture region as a fraction of window width (0.0–1.0, exclusive).

    .PARAMETER RelativeHeight
        Height of the capture region as a fraction of window height (0.0–1.0, exclusive).

    .PARAMETER OutputPath
        Full path to the output PNG file. Parent directory will be created if absent.

    .OUTPUTS
        System.Boolean
        $true on success; $false on any argument or Win32 failure.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [IntPtr]$WindowHandle,

        [Parameter(Mandatory)]
        [double]$RelativeX,

        [Parameter(Mandatory)]
        [double]$RelativeY,

        [Parameter(Mandatory)]
        [double]$RelativeWidth,

        [Parameter(Mandatory)]
        [double]$RelativeHeight,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$OutputPath
    )

    # ── Argument validation ──────────────────────────────────────────────────────
    if ($WindowHandle -eq [IntPtr]::Zero) { return $false }
    if ($RelativeX -lt 0.0 -or $RelativeX -gt 1.0) { return $false }
    if ($RelativeY -lt 0.0 -or $RelativeY -gt 1.0) { return $false }
    if ($RelativeWidth -le 0.0 -or $RelativeWidth -gt 1.0) { return $false }
    if ($RelativeHeight -le 0.0 -or $RelativeHeight -gt 1.0) { return $false }
    if (($RelativeX + $RelativeWidth) -gt 1.0) { return $false }
    if (($RelativeY + $RelativeHeight) -gt 1.0) { return $false }
    if ([string]::IsNullOrEmpty($OutputPath)) { return $false }

    # ── Retrieve window dimensions ───────────────────────────────────────────────
    $rect = New-Object 'LastWarAutoScreenshot.MouseControlAPI+RECT'
    if (-not [LastWarAutoScreenshot.MouseControlAPI]::GetWindowRect($WindowHandle, [ref]$rect)) {
        return $false
    }

    [int]$winWidth  = $rect.Right  - $rect.Left
    [int]$winHeight = $rect.Bottom - $rect.Top
    if ($winWidth -le 0 -or $winHeight -le 0) { return $false }

    # ── Compute capture region in pixels ─────────────────────────────────────────
    [int]$captureX = [int]($RelativeX      * $winWidth)
    [int]$captureY = [int]($RelativeY      * $winHeight)
    [int]$captureW = [int]($RelativeWidth  * $winWidth)
    [int]$captureH = [int]($RelativeHeight * $winHeight)
    if ($captureW -le 0 -or $captureH -le 0) { return $false }

    # ── Render window into a managed Bitmap via PrintWindow ──────────────────────
    # Graphics.FromImage creates a GDI DC backed by the bitmap's pixel buffer.
    # PrintWindow renders the DWM-composited window content into that DC.
    $fullBmp = $null
    $region  = $null
    $g       = $null
    try {
        $fullBmp = [System.Drawing.Bitmap]::new($winWidth, $winHeight)
        $g       = [System.Drawing.Graphics]::FromImage($fullBmp)
        $hdc     = $g.GetHdc()
        $success = [LastWarAutoScreenshot.ScreenCaptureAPI]::PrintWindow(
            $WindowHandle, $hdc, [LastWarAutoScreenshot.ScreenCaptureAPI]::PW_RENDERFULLCONTENT)
        $g.ReleaseHdc($hdc)

        if (-not $success) { return $false }

        # ── Crop to the requested region and save ────────────────────────────────
        $cropRect = [System.Drawing.Rectangle]::new($captureX, $captureY, $captureW, $captureH)
        $region   = $fullBmp.Clone($cropRect, $fullBmp.PixelFormat)

        $dir = [System.IO.Path]::GetDirectoryName($OutputPath)
        if (-not [string]::IsNullOrEmpty($dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        $region.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        return $true
    } finally {
        if ($null -ne $g)       { $g.Dispose() }
        if ($null -ne $region)  { $region.Dispose() }
        if ($null -ne $fullBmp) { $fullBmp.Dispose() }
    }
}
