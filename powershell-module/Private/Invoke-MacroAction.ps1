function Invoke-MacroAction {
    <#
    .SYNOPSIS
        Executes a single macro action object.

    .DESCRIPTION
        Dispatches one action from a macro sequence to the appropriate mouse-control,
        timing, or screenshot function.  Checks for an active emergency stop before
        executing.

        Supported action types: MoveToPoint, MoveToRegion, LeftClick, DragClick,
        Screenshot, Delay, Loop.

        Loop actions may call Invoke-MacroAction recursively up to one level deep.
        The $Depth parameter guards against unexpected nesting beyond that limit.
        Loop actions pass $ScreenshotContext unchanged to recursive calls so that
        screenshot index and previous-path tracking are continuous across iterations.

    .PARAMETER Action
        The PSCustomObject representing the action to execute (from a macro sequence).

    .PARAMETER WindowHandle
        The window handle used by ConvertTo-ScreenCoordinates to resolve relative
        coordinates to absolute screen positions.

    .PARAMETER ActionLookup
        A hashtable mapping action name (string) to action object (PSCustomObject),
        built from the full macro sequence.  Required for Loop action resolution.

    .PARAMETER Depth
        Internal recursion depth counter.  Defaults to 0.  Loop actions increment
        this to 1 when making recursive calls; if depth reaches 1 and another Loop
        is encountered, execution is aborted.

    .PARAMETER ScreenshotContext
        Optional hashtable with keys: Index (int), MacroName (string), ActionName
        (string), PreviousScreenshotPath (string or $null), ConsecutiveSimilarCount
        (int).  Mutated in-place by the Screenshot case.  Passed unchanged to
        recursive Loop calls so tracking is continuous across loop iterations.
        Defaults to $null; existing callers that omit it are unaffected.

    .OUTPUTS
        PSCustomObject
        Properties: Success [bool], Message [string], Skipped [bool],
        SimilarityStop [bool].
        Skipped is $true when the action was intentionally not executed (e.g.
        emergency stop, StoragePath not configured).
        SimilarityStop is $true when the Screenshot case detects that consecutive
        images are similar and the configured Action is StopLoop or StopMacro.

    .NOTES
        StopLoop contract: the Screenshot case returns SimilarityStop=$true;
        the Loop case intercepts it, logs a message, and returns SimilarityStop=$false
        so the parent sequence continues after the loop.

        StopMacro contract: the Screenshot case returns SimilarityStop=$true; the
        Loop case propagates SimilarityStop=$true upward; Invoke-MacroSequence halts
        the macro and reports success.

    .EXAMPLE
        $result = Invoke-MacroAction -Action $action -WindowHandle $handle -ActionLookup $lookup
        if (-not $result.Success) { Write-Warning $result.Message }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Action,

        [Parameter(Mandatory)]
        [object]$WindowHandle,

        [Parameter(Mandatory)]
        [hashtable]$ActionLookup,

        [int]$Depth = 0,

        [hashtable]$ScreenshotContext = $null
    )

    if ($script:EmergencyStopRequested) {
        return [PSCustomObject]@{ Success = $false; Message = 'Emergency stop active'; Skipped = $true; SimilarityStop = $false }
    }

    switch ($Action.type) {
        'MoveToPoint' {
            $screenCoords = ConvertTo-ScreenCoordinates -WindowHandle $WindowHandle -RelativeX $Action.position.relativeX -RelativeY $Action.position.relativeY
            if ($null -eq $screenCoords) {
                Write-LastWarLog -Level Error -FunctionName 'Invoke-MacroAction' -Message 'MoveToPoint: ConvertTo-ScreenCoordinates returned null.'
                return [PSCustomObject]@{ Success = $false; Message = 'Failed to convert MoveToPoint coordinates to screen position.'; Skipped = $false; SimilarityStop = $false }
            }
            $curPos = Invoke-GetCursorPosition
            if ($null -eq $curPos) {
                Write-LastWarLog -Level Error -FunctionName 'Invoke-MacroAction' -Message 'MoveToPoint: Invoke-GetCursorPosition returned null.'
                return [PSCustomObject]@{ Success = $false; Message = 'Failed to get current cursor position for MoveToPoint.'; Skipped = $false; SimilarityStop = $false }
            }
            $points = Get-BezierPoints -StartX $curPos.X -StartY $curPos.Y -EndX $screenCoords.X -EndY $screenCoords.Y
            $moveResult = Invoke-MouseMovePath -Points $points
            return [PSCustomObject]@{ Success = [bool]$moveResult; Message = if ($moveResult) { '' } else { 'MoveToPoint: mouse path failed.' }; Skipped = $false; SimilarityStop = $false }
        }

        'MoveToRegion' {
            if ($Action.region.type -eq 'Box') {
                $regionObj = [PSCustomObject]@{
                    RelativeX      = $Action.region.relativeX
                    RelativeY      = $Action.region.relativeY
                    RelativeWidth  = $Action.region.relativeWidth
                    RelativeHeight = $Action.region.relativeHeight
                }
                $randomPos = Get-RandomTargetPosition -Box $regionObj
            } else {
                $regionObj = [PSCustomObject]@{
                    RelativeCentreX = $Action.region.relativeCentreX
                    RelativeCentreY = $Action.region.relativeCentreY
                    RelativeRadius  = $Action.region.relativeRadius
                }
                $randomPos = Get-RandomTargetPosition -Circle $regionObj
            }
            if ($null -eq $randomPos) {
                Write-LastWarLog -Level Error -FunctionName 'Invoke-MacroAction' -Message 'MoveToRegion: Get-RandomTargetPosition returned null.'
                return [PSCustomObject]@{ Success = $false; Message = 'Failed to compute random position within MoveToRegion region.'; Skipped = $false; SimilarityStop = $false }
            }
            $screenCoords = ConvertTo-ScreenCoordinates -WindowHandle $WindowHandle -RelativeX $randomPos.RelativeX -RelativeY $randomPos.RelativeY
            if ($null -eq $screenCoords) {
                Write-LastWarLog -Level Error -FunctionName 'Invoke-MacroAction' -Message 'MoveToRegion: ConvertTo-ScreenCoordinates returned null.'
                return [PSCustomObject]@{ Success = $false; Message = 'Failed to convert MoveToRegion target coordinates to screen position.'; Skipped = $false; SimilarityStop = $false }
            }
            $curPos = Invoke-GetCursorPosition
            if ($null -eq $curPos) {
                Write-LastWarLog -Level Error -FunctionName 'Invoke-MacroAction' -Message 'MoveToRegion: Invoke-GetCursorPosition returned null.'
                return [PSCustomObject]@{ Success = $false; Message = 'Failed to get current cursor position for MoveToRegion.'; Skipped = $false; SimilarityStop = $false }
            }
            $points = Get-BezierPoints -StartX $curPos.X -StartY $curPos.Y -EndX $screenCoords.X -EndY $screenCoords.Y
            $moveResult = Invoke-MouseMovePath -Points $points
            return [PSCustomObject]@{ Success = [bool]$moveResult; Message = if ($moveResult) { '' } else { 'MoveToRegion: mouse path failed.' }; Skipped = $false; SimilarityStop = $false }
        }

        'LeftClick' {
            $curPos = Invoke-GetCursorPosition
            if ($null -eq $curPos) {
                Write-LastWarLog -Level Error -FunctionName 'Invoke-MacroAction' -Message 'LeftClick: Invoke-GetCursorPosition returned null.'
                return [PSCustomObject]@{ Success = $false; Message = 'Failed to get current cursor position for LeftClick.'; Skipped = $false; SimilarityStop = $false }
            }
            $clickResult = Invoke-MouseClick -X $curPos.X -Y $curPos.Y
            return [PSCustomObject]@{ Success = [bool]$clickResult; Message = if ($clickResult) { '' } else { 'LeftClick: Invoke-MouseClick failed.' }; Skipped = $false; SimilarityStop = $false }
        }

        'DragClick' {
            $startCoords = ConvertTo-ScreenCoordinates -WindowHandle $WindowHandle -RelativeX $Action.start.relativeX -RelativeY $Action.start.relativeY
            if ($null -eq $startCoords) {
                Write-LastWarLog -Level Error -FunctionName 'Invoke-MacroAction' -Message 'DragClick: ConvertTo-ScreenCoordinates returned null for start position.'
                return [PSCustomObject]@{ Success = $false; Message = 'Failed to convert DragClick start coordinates to screen position.'; Skipped = $false; SimilarityStop = $false }
            }
            $endCoords = ConvertTo-ScreenCoordinates -WindowHandle $WindowHandle -RelativeX $Action.end.relativeX -RelativeY $Action.end.relativeY
            if ($null -eq $endCoords) {
                Write-LastWarLog -Level Error -FunctionName 'Invoke-MacroAction' -Message 'DragClick: ConvertTo-ScreenCoordinates returned null for end position.'
                return [PSCustomObject]@{ Success = $false; Message = 'Failed to convert DragClick end coordinates to screen position.'; Skipped = $false; SimilarityStop = $false }
            }
            $dragResult = Invoke-MouseDragClick -StartX $startCoords.X -StartY $startCoords.Y -EndX $endCoords.X -EndY $endCoords.Y
            return [PSCustomObject]@{ Success = $dragResult.Success; Message = $dragResult.Message; Skipped = $false; SimilarityStop = $false }
        }

        'Screenshot' {
            # Guard: ScreenshotContext must be supplied by Invoke-MacroSequence
            if ($null -eq $ScreenshotContext) {
                Write-LastWarLog -Level Warning -FunctionName 'Invoke-MacroAction' `
                    -Message 'ScreenshotContext not supplied — skipping Screenshot action'
                return [PSCustomObject]@{ Success = $true; Skipped = $true; SimilarityStop = $false; Message = 'ScreenshotContext not supplied' }
            }

            # Capture previous path before this call (used for similarity comparison below)
            $prevPath = $ScreenshotContext.PreviousScreenshotPath

            # Set ActionName on context so filename resolver uses it
            $ScreenshotContext.ActionName = if ($Action.name) { $Action.name } else { 'Screenshot' }

            $captureResult = Invoke-CaptureScreenRegion `
                -WindowHandle               $WindowHandle `
                -RegionTopLeftRelativeX     $Action.region.topLeft.relativeX `
                -RegionTopLeftRelativeY     $Action.region.topLeft.relativeY `
                -RegionBottomRightRelativeX $Action.region.bottomRight.relativeX `
                -RegionBottomRightRelativeY $Action.region.bottomRight.relativeY `
                -ScreenshotContext          $ScreenshotContext

            # StoragePath not configured — intentional skip, not an error
            if ($captureResult.Skipped -eq $true) {
                return [PSCustomObject]@{ Success = $true; Skipped = $true; SimilarityStop = $false; Message = $captureResult.Message }
            }

            if ($captureResult.Success -eq $false) {
                return [PSCustomObject]@{ Success = $false; Skipped = $false; SimilarityStop = $false; Message = $captureResult.Message }
            }

            # Similarity check — only when a previous screenshot exists and the feature is enabled
            if ($null -ne $prevPath) {
                $simConfig = (Get-ModuleConfiguration).Screenshots.SimilarityCheck
                if ($simConfig.Enabled -eq $true) {
                    $similarityResult = Test-ScreenshotSimilarity `
                        -ReferencePath $prevPath `
                        -ComparePath   $captureResult.FilePath

                    if ($similarityResult.Skipped -eq $true) {
                        Write-LastWarLog -Level Warning -FunctionName 'Invoke-MacroAction' `
                            -Message "Similarity check skipped: $($similarityResult.Message)"
                        $ScreenshotContext.ConsecutiveSimilarCount = 0
                        return [PSCustomObject]@{ Success = $true; Skipped = $false; SimilarityStop = $false; Message = '' }
                    }

                    if ($similarityResult.Similar -eq $true) {
                        $ScreenshotContext.ConsecutiveSimilarCount++
                        if ($ScreenshotContext.ConsecutiveSimilarCount -ge $simConfig.ConsecutiveThreshold) {
                            if ($simConfig.Action -ieq 'StopLoop' -or $simConfig.Action -ieq 'StopMacro') {
                                Write-LastWarLog -Level Info -FunctionName 'Invoke-MacroAction' `
                                    -Message "Similarity threshold reached ($([int]($similarityResult.MatchPercent * 100))% match, $($ScreenshotContext.ConsecutiveSimilarCount) consecutive) — signalling similarity stop"
                                return [PSCustomObject]@{ Success = $true; Skipped = $false; SimilarityStop = $true; Message = 'Similarity threshold reached' }
                            }
                            if ($simConfig.Action -ieq 'Warn') {
                                Write-LastWarLog -Level Warning -FunctionName 'Invoke-MacroAction' `
                                    -Message "Screenshot similarity above threshold ($([int]($similarityResult.MatchPercent * 100))% match, $($ScreenshotContext.ConsecutiveSimilarCount) consecutive) — possible scroll end; continuing"
                                return [PSCustomObject]@{ Success = $true; Skipped = $false; SimilarityStop = $false; Message = '' }
                            }
                        }
                        # Threshold not yet reached — accumulating consecutive count
                        return [PSCustomObject]@{ Success = $true; Skipped = $false; SimilarityStop = $false; Message = '' }
                    } else {
                        $ScreenshotContext.ConsecutiveSimilarCount = 0
                        return [PSCustomObject]@{ Success = $true; Skipped = $false; SimilarityStop = $false; Message = '' }
                    }
                }
            }

            return [PSCustomObject]@{ Success = $true; Skipped = $false; SimilarityStop = $false; Message = '' }
        }

        'Delay' {
            Start-Sleep -Seconds $Action.seconds
            return [PSCustomObject]@{ Success = $true; Message = ''; Skipped = $false; SimilarityStop = $false }
        }

        'Loop' {
            if ($Depth -ge 1) {
                Write-LastWarLog -Level Error -FunctionName 'Invoke-MacroAction' -Message 'Loop nesting detected — aborting'
                return [PSCustomObject]@{ Success = $false; Message = 'Loop nesting detected — aborting'; Skipped = $false; SimilarityStop = $false }
            }
            for ($iteration = 1; $iteration -le $Action.iterations; $iteration++) {
                if ($script:EmergencyStopRequested) {
                    return [PSCustomObject]@{ Success = $false; Message = 'Emergency stop active'; Skipped = $true; SimilarityStop = $false }
                }
                foreach ($actionName in $Action.actionNames) {
                    if ($script:EmergencyStopRequested) {
                        return [PSCustomObject]@{ Success = $false; Message = 'Emergency stop active'; Skipped = $true; SimilarityStop = $false }
                    }
                    $refAction = $ActionLookup[$actionName]
                    $loopResult = Invoke-MacroAction -Action $refAction -WindowHandle $WindowHandle -ActionLookup $ActionLookup -Depth ($Depth + 1) -ScreenshotContext $ScreenshotContext
                    if ($loopResult.SimilarityStop -eq $true) {
                        $loopSimConfig = (Get-ModuleConfiguration).Screenshots.SimilarityCheck
                        if ($loopSimConfig.Action -ieq 'StopLoop') {
                            Write-LastWarLog -Level Info -FunctionName 'Invoke-MacroAction' `
                                -Message "Similarity threshold reached inside loop '$($Action.name)' — exiting loop and continuing parent sequence"
                            return [PSCustomObject]@{ Success = $true; Skipped = $false; SimilarityStop = $false; Message = 'Similarity stop consumed by loop (StopLoop)' }
                        } elseif ($loopSimConfig.Action -ieq 'StopMacro') {
                            return [PSCustomObject]@{ Success = $true; Skipped = $false; SimilarityStop = $true; Message = $loopResult.Message }
                        }
                    }
                    if (-not $loopResult.Success -and -not $loopResult.Skipped) {
                        return $loopResult
                    }
                }
            }
            return [PSCustomObject]@{ Success = $true; Message = ''; Skipped = $false; SimilarityStop = $false }
        }

        default {
            return [PSCustomObject]@{ Success = $false; Message = "Unknown action type '$($Action.type)'"; Skipped = $false; SimilarityStop = $false }
        }
    }
}
