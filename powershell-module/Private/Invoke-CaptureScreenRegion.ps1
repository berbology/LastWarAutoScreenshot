function Invoke-CaptureScreenRegion {
    <#
    .SYNOPSIS
        Orchestrates a single screenshot capture action within a macro execution run.

    .DESCRIPTION
        Checks storage configuration and limits, resolves the output filename from the
        configured pattern, converts the window handle, and delegates the actual Win32
        capture to Invoke-CaptureWindowRegion.

        The caller supplies a $ScreenshotContext hashtable that is mutated in-place:
        Index is incremented before each capture, and PreviousScreenshotPath is updated
        after a successful capture.  Because hashtables are reference types in PowerShell,
        these mutations propagate to the caller without [ref] parameters.

    .PARAMETER WindowHandle
        Window handle to capture.  Accepts [IntPtr], [int64], [int], or [string].

    .PARAMETER RegionTopLeftRelativeX
        Left edge of the capture region as a fraction of window width (0.0-1.0).

    .PARAMETER RegionTopLeftRelativeY
        Top edge of the capture region as a fraction of window height (0.0-1.0).

    .PARAMETER RegionBottomRightRelativeX
        Right edge of the capture region as a fraction of window width (0.0-1.0).
        Must be greater than RegionTopLeftRelativeX.

    .PARAMETER RegionBottomRightRelativeY
        Bottom edge of the capture region as a fraction of window height (0.0-1.0).
        Must be greater than RegionTopLeftRelativeY.

    .PARAMETER MaskRegions
        Optional array of window-relative mask region objects. Each element must have
        topLeft.relativeX, topLeft.relativeY, bottomRight.relativeX, bottomRight.relativeY
        (all 0.0–1.0). Regions are clipped to the screenshot region before being converted
        to pixel-space rectangles passed to Invoke-CaptureWindowRegion. Defaults to empty
        (no masking).

    .PARAMETER ScreenshotContext
        Hashtable with keys: Index (int), MacroName (string), ActionName (string),
        PreviousScreenshotPath (string or $null).  Mutated in-place on success:
        Index is incremented and PreviousScreenshotPath is set to the saved file path.

    .OUTPUTS
        PSCustomObject with properties:
            Success  ([bool])         : $true when the screenshot was saved successfully
            Skipped  ([bool])         : $true when capture was intentionally skipped
                                        (StoragePath not configured); $false on error
            FilePath ([string])       : Full path to the saved file; $null on failure/skip
            Message  ([string])       : Human-readable status or error description

    .NOTES
        Storage directory is created automatically at first capture when StoragePath is
        configured but the directory does not yet exist.

        Skipped=$true (StoragePath not configured) is not an error — the macro continues.
        Skipped=$false with Success=$false indicates an actual failure; the caller should
        halt execution.

        WindowHandle conversion follows the same pattern as Set-WindowState: accepts
        [IntPtr], [int64], [int], or a non-empty [string] numeric representation.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$WindowHandle,

        [Parameter(Mandatory)]
        [double]$RegionTopLeftRelativeX,

        [Parameter(Mandatory)]
        [double]$RegionTopLeftRelativeY,

        [Parameter(Mandatory)]
        [double]$RegionBottomRightRelativeX,

        [Parameter(Mandatory)]
        [double]$RegionBottomRightRelativeY,

        [AllowNull()]
        [object[]]$MaskRegions = @(),

        [Parameter(Mandatory)]
        [hashtable]$ScreenshotContext
    )

    # ── 1. Load config ────────────────────────────────────────────────────────
    $config           = Get-ModuleConfiguration
    $storePath        = $config.Screenshots.StoragePath
    $maxStorageGB     = [double]$config.Screenshots.MaxStorageGB
    $format           = $config.Screenshots.FileFormat
    $filenamePattern  = $config.Screenshots.FilenamePattern
    $warningThreshold = [int]$config.Screenshots.StorageWarningThresholdPercent

    # ── 2. StoragePath guard ──────────────────────────────────────────────────
    if ([string]::IsNullOrWhiteSpace($storePath)) {
        Write-LastWarLog -Level Warning -FunctionName 'Invoke-CaptureScreenRegion' `
            -Message 'Screenshot StoragePath is not configured — skipping screenshot action'
        return [PSCustomObject]@{
            Success  = $false
            Skipped  = $true
            FilePath = $null
            Message  = 'StoragePath not configured'
        }
    }

    # ── 3. Disk free space check ──────────────────────────────────────────────
    try {
        $driveLetter = ([System.IO.Path]::GetPathRoot($storePath) -replace ':\\$', '')
        $psDrive = Get-PSDrive -Name $driveLetter -PSProvider FileSystem
        if ($psDrive.Free -le 0) {
            Write-LastWarLog -Level Error -FunctionName 'Invoke-CaptureScreenRegion' `
                -Message 'Disk is full — cannot save screenshot'
            return [PSCustomObject]@{
                Success  = $false
                Skipped  = $false
                FilePath = $null
                Message  = 'Disk full'
            }
        }
    } catch {
        Write-LastWarLog -Level Warning -FunctionName 'Invoke-CaptureScreenRegion' `
            -Message "Could not determine available disk space for '$storePath': $_"
    }

    # ── 4. Storage limit check ────────────────────────────────────────────────
    $storageInfo = Get-StorageInfo
    if ($storageInfo.UsedPercent -ge 100.0) {
        Write-LastWarLog -Level Error -FunctionName 'Invoke-CaptureScreenRegion' `
            -Message "Screenshot storage limit reached ($($storageInfo.UsedGB) GB used of $maxStorageGB GB limit)"
        return [PSCustomObject]@{
            Success  = $false
            Skipped  = $false
            FilePath = $null
            Message  = 'Storage limit reached'
        }
    }
    if ($storageInfo.UsedPercent -ge $warningThreshold) {
        Write-LastWarLog -Level Warning -FunctionName 'Invoke-CaptureScreenRegion' `
            -Message "Screenshot storage at $([int]$storageInfo.UsedPercent)% of configured limit ($storePath)"
    }

    # ── 5. Validate region dimensions ─────────────────────────────────────────
    $relativeWidth  = $RegionBottomRightRelativeX - $RegionTopLeftRelativeX
    $relativeHeight = $RegionBottomRightRelativeY - $RegionTopLeftRelativeY
    if ($relativeWidth -le 0 -or $relativeHeight -le 0) {
        Write-LastWarLog -Level Error -FunctionName 'Invoke-CaptureScreenRegion' `
            -Message 'Invalid screenshot region: bottom-right must be to the right of and below top-left'
        return [PSCustomObject]@{
            Success  = $false
            Skipped  = $false
            FilePath = $null
            Message  = 'Invalid region dimensions'
        }
    }

    # ── 6. Increment index and resolve filename ───────────────────────────────
    $ScreenshotContext.Index++
    $resolvedFilename = Resolve-ScreenshotFilename `
        -Pattern        $filenamePattern `
        -MacroName      $ScreenshotContext.MacroName `
        -ActionName     $ScreenshotContext.ActionName `
        -ActionType     'Screenshot' `
        -Index          $ScreenshotContext.Index `
        -Format         $format

    if ($null -eq $resolvedFilename) {
        return [PSCustomObject]@{
            Success  = $false
            Skipped  = $false
            FilePath = $null
            Message  = 'Filename resolution failed'
        }
    }

    # ── 7. Resolve full path and auto-create directory ────────────────────────
    $fullPath = Join-Path $storePath $resolvedFilename
    if (-not (Test-Path $storePath)) {
        New-Item -ItemType Directory -Path $storePath -Force | Out-Null
        Write-LastWarLog -Level Info -FunctionName 'Invoke-CaptureScreenRegion' `
            -Message "Created screenshot storage directory: $storePath"
    }

    # ── 8. Convert window handle and capture ──────────────────────────────────
    # Follows the same handle-conversion pattern as Set-WindowState.
    if ($null -eq $WindowHandle) {
        Write-LastWarLog -Level Error -FunctionName 'Invoke-CaptureScreenRegion' `
            -Message 'WindowHandle is null'
        return [PSCustomObject]@{
            Success  = $false
            Skipped  = $false
            FilePath = $null
            Message  = 'WindowHandle is null'
        }
    }

    $hWnd = if ($WindowHandle -is [IntPtr]) {
        $WindowHandle
    } elseif ($WindowHandle -is [string] -or $WindowHandle -is [int64] -or $WindowHandle -is [int]) {
        if ($WindowHandle -is [string] -and [string]::IsNullOrWhiteSpace($WindowHandle)) {
            Write-LastWarLog -Level Error -FunctionName 'Invoke-CaptureScreenRegion' `
                -Message 'WindowHandle is an empty string'
            return [PSCustomObject]@{
                Success  = $false
                Skipped  = $false
                FilePath = $null
                Message  = 'WindowHandle is an empty string'
            }
        }
        [IntPtr]::new([int64]$WindowHandle)
    } else {
        Write-LastWarLog -Level Error -FunctionName 'Invoke-CaptureScreenRegion' `
            -Message "Unsupported WindowHandle type: $($WindowHandle.GetType().FullName)"
        return [PSCustomObject]@{
            Success  = $false
            Skipped  = $false
            FilePath = $null
            Message  = "Unsupported WindowHandle type: $($WindowHandle.GetType().FullName)"
        }
    }

    # ── 9. Compute pixel-space mask rectangles from window-relative mask regions ─
    $maskPixelRects = [System.Drawing.Rectangle[]]@()
    $maskColour     = [System.Drawing.Color]::Black

    if ($null -ne $MaskRegions -and $MaskRegions.Count -gt 0) {
        $resolvedColour = Resolve-MaskColour -ColourString $config.Screenshots.MaskColour
        if ($null -eq $resolvedColour) {
            Write-Warning "MaskColour '$($config.Screenshots.MaskColour)' could not be parsed — using black."
            $resolvedColour = [System.Drawing.Color]::Black
        }
        $maskColour = $resolvedColour

        $windowBounds = Get-WindowBounds -WindowHandle $hWnd
        $ssLeft   = $RegionTopLeftRelativeX
        $ssTop    = $RegionTopLeftRelativeY
        $ssRight  = $RegionBottomRightRelativeX
        $ssBottom = $RegionBottomRightRelativeY
        $bmpWidth  = [int]($relativeWidth  * $windowBounds.Width)
        $bmpHeight = [int]($relativeHeight * $windowBounds.Height)

        $rectList = [System.Collections.Generic.List[System.Drawing.Rectangle]]::new()
        foreach ($maskRegion in $MaskRegions) {
            $mLeft   = $maskRegion.topLeft.relativeX
            $mTop    = $maskRegion.topLeft.relativeY
            $mRight  = $maskRegion.bottomRight.relativeX
            $mBottom = $maskRegion.bottomRight.relativeY

            $overlapLeft   = [Math]::Max($ssLeft,   $mLeft)
            $overlapTop    = [Math]::Max($ssTop,    $mTop)
            $overlapRight  = [Math]::Min($ssRight,  $mRight)
            $overlapBottom = [Math]::Min($ssBottom, $mBottom)

            if ($overlapLeft -ge $overlapRight -or $overlapTop -ge $overlapBottom) {
                Write-Verbose "Mask region has no overlap with screenshot region — skipping."
                continue
            }

            $pixelX = [int](($overlapLeft   - $ssLeft) / $relativeWidth  * $bmpWidth)
            $pixelY = [int](($overlapTop    - $ssTop)  / $relativeHeight * $bmpHeight)
            $pixelW = [int](($overlapRight  - $overlapLeft) / $relativeWidth  * $bmpWidth)
            $pixelH = [int](($overlapBottom - $overlapTop)  / $relativeHeight * $bmpHeight)

            if ($pixelW -gt 0 -and $pixelH -gt 0) {
                $rectList.Add([System.Drawing.Rectangle]::new($pixelX, $pixelY, $pixelW, $pixelH))
            }
        }
        $maskPixelRects = $rectList.ToArray()
    }

    # ── 10. Capture ───────────────────────────────────────────────────────────
    $captured = Invoke-CaptureWindowRegion `
        -WindowHandle   $hWnd `
        -RelativeX      $RegionTopLeftRelativeX `
        -RelativeY      $RegionTopLeftRelativeY `
        -RelativeWidth  $relativeWidth `
        -RelativeHeight $relativeHeight `
        -OutputPath     $fullPath `
        -MaskPixelRects $maskPixelRects `
        -MaskColour     $maskColour

    if (-not $captured) {
        Write-LastWarLog -Level Error -FunctionName 'Invoke-CaptureScreenRegion' `
            -Message "CaptureWindowRegion failed for path: $fullPath"
        return [PSCustomObject]@{
            Success  = $false
            Skipped  = $false
            FilePath = $null
            Message  = 'CaptureWindowRegion failed'
        }
    }

    # ── 11. Update context ────────────────────────────────────────────────────
    $ScreenshotContext.PreviousScreenshotPath = $fullPath

    # ── 12. Log success and return ────────────────────────────────────────────
    Write-LastWarLog -Level Info -FunctionName 'Invoke-CaptureScreenRegion' `
        -Message "Screenshot saved: $fullPath"

    return [PSCustomObject]@{
        Success  = $true
        Skipped  = $false
        FilePath = $fullPath
        Message  = ''
    }
}
