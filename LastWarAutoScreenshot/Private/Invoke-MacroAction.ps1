function Invoke-MacroAction {
    <#
    .SYNOPSIS
        Executes a single macro action object.

    .DESCRIPTION
        Dispatches one action from a macro sequence to the appropriate mouse-control
        or timing function.  Checks for an active emergency stop before executing.

        Supported action types: MoveToPoint, MoveToRegion, LeftClick, DragClick,
        Screenshot, Delay, Loop.

        Loop actions may call Invoke-MacroAction recursively up to one level deep.
        The $Depth parameter guards against unexpected nesting beyond that limit.

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

    .OUTPUTS
        PSCustomObject
        Properties: Success [bool], Message [string], Skipped [bool].
        Skipped is $true when the action was intentionally not executed (e.g. Screenshot,
        emergency stop).

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

        [int]$Depth = 0
    )

    if ($script:EmergencyStopRequested) {
        return [PSCustomObject]@{ Success = $false; Message = 'Emergency stop active'; Skipped = $true }
    }

    switch ($Action.type) {
        'MoveToPoint' {
            $screenCoords = ConvertTo-ScreenCoordinates -WindowHandle $WindowHandle -RelativeX $Action.position.relativeX -RelativeY $Action.position.relativeY
            if ($null -eq $screenCoords) {
                Write-LastWarLog -Level Error -FunctionName 'Invoke-MacroAction' -Message 'MoveToPoint: ConvertTo-ScreenCoordinates returned null.'
                return [PSCustomObject]@{ Success = $false; Message = 'Failed to convert MoveToPoint coordinates to screen position.'; Skipped = $false }
            }
            $curPos = Invoke-GetCursorPosition
            if ($null -eq $curPos) {
                Write-LastWarLog -Level Error -FunctionName 'Invoke-MacroAction' -Message 'MoveToPoint: Invoke-GetCursorPosition returned null.'
                return [PSCustomObject]@{ Success = $false; Message = 'Failed to get current cursor position for MoveToPoint.'; Skipped = $false }
            }
            $points = Get-BezierPoints -StartX $curPos.X -StartY $curPos.Y -EndX $screenCoords.X -EndY $screenCoords.Y
            $moveResult = Invoke-MouseMovePath -Points $points
            return [PSCustomObject]@{ Success = [bool]$moveResult; Message = if ($moveResult) { '' } else { 'MoveToPoint: mouse path failed.' }; Skipped = $false }
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
                return [PSCustomObject]@{ Success = $false; Message = 'Failed to compute random position within MoveToRegion region.'; Skipped = $false }
            }
            $screenCoords = ConvertTo-ScreenCoordinates -WindowHandle $WindowHandle -RelativeX $randomPos.RelativeX -RelativeY $randomPos.RelativeY
            if ($null -eq $screenCoords) {
                Write-LastWarLog -Level Error -FunctionName 'Invoke-MacroAction' -Message 'MoveToRegion: ConvertTo-ScreenCoordinates returned null.'
                return [PSCustomObject]@{ Success = $false; Message = 'Failed to convert MoveToRegion target coordinates to screen position.'; Skipped = $false }
            }
            $curPos = Invoke-GetCursorPosition
            if ($null -eq $curPos) {
                Write-LastWarLog -Level Error -FunctionName 'Invoke-MacroAction' -Message 'MoveToRegion: Invoke-GetCursorPosition returned null.'
                return [PSCustomObject]@{ Success = $false; Message = 'Failed to get current cursor position for MoveToRegion.'; Skipped = $false }
            }
            $points = Get-BezierPoints -StartX $curPos.X -StartY $curPos.Y -EndX $screenCoords.X -EndY $screenCoords.Y
            $moveResult = Invoke-MouseMovePath -Points $points
            return [PSCustomObject]@{ Success = [bool]$moveResult; Message = if ($moveResult) { '' } else { 'MoveToRegion: mouse path failed.' }; Skipped = $false }
        }

        'LeftClick' {
            $curPos = Invoke-GetCursorPosition
            if ($null -eq $curPos) {
                Write-LastWarLog -Level Error -FunctionName 'Invoke-MacroAction' -Message 'LeftClick: Invoke-GetCursorPosition returned null.'
                return [PSCustomObject]@{ Success = $false; Message = 'Failed to get current cursor position for LeftClick.'; Skipped = $false }
            }
            $clickResult = Invoke-MouseClick -X $curPos.X -Y $curPos.Y
            return [PSCustomObject]@{ Success = [bool]$clickResult; Message = if ($clickResult) { '' } else { 'LeftClick: Invoke-MouseClick failed.' }; Skipped = $false }
        }

        'DragClick' {
            $startCoords = ConvertTo-ScreenCoordinates -WindowHandle $WindowHandle -RelativeX $Action.start.relativeX -RelativeY $Action.start.relativeY
            if ($null -eq $startCoords) {
                Write-LastWarLog -Level Error -FunctionName 'Invoke-MacroAction' -Message 'DragClick: ConvertTo-ScreenCoordinates returned null for start position.'
                return [PSCustomObject]@{ Success = $false; Message = 'Failed to convert DragClick start coordinates to screen position.'; Skipped = $false }
            }
            $endCoords = ConvertTo-ScreenCoordinates -WindowHandle $WindowHandle -RelativeX $Action.end.relativeX -RelativeY $Action.end.relativeY
            if ($null -eq $endCoords) {
                Write-LastWarLog -Level Error -FunctionName 'Invoke-MacroAction' -Message 'DragClick: ConvertTo-ScreenCoordinates returned null for end position.'
                return [PSCustomObject]@{ Success = $false; Message = 'Failed to convert DragClick end coordinates to screen position.'; Skipped = $false }
            }
            $dragResult = Invoke-MouseDragClick -StartX $startCoords.X -StartY $startCoords.Y -EndX $endCoords.X -EndY $endCoords.Y
            return [PSCustomObject]@{ Success = $dragResult.Success; Message = $dragResult.Message; Skipped = $false }
        }

        'Screenshot' {
            Write-LastWarLog -Level Warning -FunctionName 'Invoke-MacroAction' -Message 'Screenshot capture not yet implemented — skipping action'
            return [PSCustomObject]@{ Success = $true; Message = 'Screenshot capture not yet implemented — skipping action'; Skipped = $true }
        }

        'Delay' {
            Start-Sleep -Seconds $Action.seconds
            return [PSCustomObject]@{ Success = $true; Message = ''; Skipped = $false }
        }

        'Loop' {
            if ($Depth -ge 1) {
                Write-LastWarLog -Level Error -FunctionName 'Invoke-MacroAction' -Message 'Loop nesting detected — aborting'
                return [PSCustomObject]@{ Success = $false; Message = 'Loop nesting detected — aborting'; Skipped = $false }
            }
            for ($iteration = 1; $iteration -le $Action.iterations; $iteration++) {
                if ($script:EmergencyStopRequested) {
                    return [PSCustomObject]@{ Success = $false; Message = 'Emergency stop active'; Skipped = $true }
                }
                foreach ($actionName in $Action.actionNames) {
                    if ($script:EmergencyStopRequested) {
                        return [PSCustomObject]@{ Success = $false; Message = 'Emergency stop active'; Skipped = $true }
                    }
                    $refAction = $ActionLookup[$actionName]
                    $loopResult = Invoke-MacroAction -Action $refAction -WindowHandle $WindowHandle -ActionLookup $ActionLookup -Depth ($Depth + 1)
                    if (-not $loopResult.Success -and -not $loopResult.Skipped) {
                        return $loopResult
                    }
                }
            }
            return [PSCustomObject]@{ Success = $true; Message = ''; Skipped = $false }
        }

        default {
            return [PSCustomObject]@{ Success = $false; Message = "Unknown action type '$($Action.type)'"; Skipped = $false }
        }
    }
}
