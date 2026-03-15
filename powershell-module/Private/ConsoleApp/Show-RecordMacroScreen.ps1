function Show-RecordMacroScreen {
    <#
    .SYNOPSIS
        Displays the macro recording screen, guiding the user through building a macro action by action.

    .DESCRIPTION
        Full recording workflow:

        Step 1 — Validates the target window: loads config, checks ProcessName is set, and that the
        window handle is still valid via Test-WindowHandleValid.

        Step 2 — Prompts for a macro name. Sanitises input via Get-ValidMacroName -AutoFix, confirms
        any auto-fix with the user, and re-prompts on invalid names.

        Step 3 — Action recording loop. Displays the current sequence as a table and presents a
        SelectionPrompt with action types. Supported actions:
          - MoveToPoint   : captures one mouse position via Invoke-CaptureMousePosition
          - MoveToRegion  : captures two positions (box or circle) and computes dimensions/radius
          - LeftClick     : no position capture; executes at current mouse position during playback
          - DragClick     : captures start and end positions
          - Screenshot    : captures two positions defining a rectangular region
          - Delay         : prompts for a delay in seconds (0.1–3600)
          - Loop          : selects named non-Loop actions and a repeat count
          - Save macro    : validates and saves the macro via Save-MacroFile
          - Discard       : optionally confirms before discarding the sequence

        The console must have keyboard focus while recording. The game window must be visible and
        in windowed mode so that window bounds can be retrieved accurately.

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for all rendering and input.
        Pass [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole() for production use,
        or a [Spectre.Console.Testing.TestConsole]::new() instance in Pester tests.

    .OUTPUTS
        $null

    .EXAMPLE
        $console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        Show-RecordMacroScreen -Console $console

    .NOTES
        Coordinate capture relies on Invoke-CaptureMousePosition which reads the live cursor
        position when the user presses Enter.  Ensure the game window is visible during
        recording so that relative coordinates are computed correctly.

        Phase 4 (Macro Recording) implementation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    # ── Step 1: Validate target window ────────────────────────────────────────

    $config = $null
    try {
        $config = Get-ModuleConfiguration
    } catch {
        $errorPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
            'No target window configured. Please select a target window from the main menu first.',
            '[red]Error[/]'
        )
        $Console.Write($errorPanel)
        return $null
    }

    if (-not $config.PSObject.Properties['ProcessName'] -or [string]::IsNullOrEmpty($config.ProcessName)) {
        $errorPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
            'No target window configured. Please select a target window from the main menu first.',
            '[red]Error[/]'
        )
        $Console.Write($errorPanel)
        return $null
    }

    $windowHandle = [IntPtr]::new($config.WindowHandleInt64)

    if (-not (Test-WindowHandleValid -WindowHandle $windowHandle)) {
        $errorPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
            'Target window is no longer open. Please select a new target window.',
            '[red]Error[/]'
        )
        $Console.Write($errorPanel)
        return $null
    }

    # ── Step 2: Prompt for macro name ────────────────────────────────────────

    $existingMacros = @(Get-MacroFileList | ForEach-Object { $_.Name })

    $infoPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
        'You will build a macro by adding actions one at a time. Position your mouse over the game window and press Enter to capture coordinates. The console must have keyboard focus while recording.',
        'Macro Recording'
    )
    $Console.Write($infoPanel)

    $macroName = $null
    while ($null -eq $macroName) {
        $namePrompt           = [Spectre.Console.TextPrompt[string]]::new('Enter a name for this macro:')
        $namePrompt.AllowEmpty = $false
        $rawName              = $namePrompt.Show($Console)

        if ([string]::IsNullOrEmpty($rawName)) {
            continue
        }

        $nameResult = Get-ValidMacroName -Name $rawName -AutoFix -ExistingNames $existingMacros

        if ($nameResult.WasAutoFixed) {
            $confirmPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                "Name was sanitised. Use `"$($nameResult.SanitisedName)`"?",
                @("Use `"$($nameResult.SanitisedName)`"", 'Enter a different name', 'Cancel')
            )
            $confirmChoice = $confirmPrompt.Show($Console)

            if ($confirmChoice -eq 'Cancel') {
                return $null
            } elseif ($confirmChoice -eq 'Enter a different name') {
                continue
            }
            # 'Use "<sanitised-name>"' falls through
        }

        if (-not $nameResult.Valid) {
            $Console.Write([Spectre.Console.Markup]::new("[red]$([Spectre.Console.Markup]::Escape($nameResult.Message))[/]`n"))
            continue
        }

        $macroName = $nameResult.SanitisedName
    }

    # ── Step 3: Action recording loop ────────────────────────────────────────

    $sequence      = [System.Collections.Generic.List[PSCustomObject]]::new()
    $existingNames = [System.Collections.Generic.List[string]]::new()

    while ($true) {

        # Display current sequence as a table
        $seqTable = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(@('#', 'Type', 'Name', 'Details'))
        $stepIndex = 0
        foreach ($action in $sequence) {
            $stepIndex++
            $actionName    = if ($action.PSObject.Properties['name'] -and -not [string]::IsNullOrEmpty($action.name)) { $action.name } else { '' }
            $actionDetails = switch ($action.type) {
                'MoveToPoint'  { "($($action.position.relativeX), $($action.position.relativeY))" }
                'MoveToRegion' {
                    if ($action.region.type -eq 'Box') {
                        "Box $($action.region.relativeWidth)x$($action.region.relativeHeight) at ($($action.region.relativeX), $($action.region.relativeY))"
                    } else {
                        "Circle centre ($($action.region.relativeCentreX), $($action.region.relativeCentreY)), r=$($action.region.relativeRadius)"
                    }
                }
                'LeftClick'    { 'at current position' }
                'DragClick'    { "($($action.start.relativeX), $($action.start.relativeY)) -> ($($action.end.relativeX), $($action.end.relativeY))" }
                'Screenshot'   {
                    $regionStr = "($($action.region.topLeft.relativeX), $($action.region.topLeft.relativeY)) to ($($action.region.bottomRight.relativeX), $($action.region.bottomRight.relativeY))"
                    if ($action.PSObject.Properties['maskRegions'] -and $action.maskRegions.Count -gt 0) {
                        "$regionStr | $($action.maskRegions.Count) mask(s)"
                    } else {
                        $regionStr
                    }
                }
                'Delay'        { "$($action.seconds)s" }
                'Loop'         { "$($action.actionNames -join ' -> ') x$($action.iterations)" }
                default        { '' }
            }

            [Spectre.Console.TableExtensions]::AddRow(
                $seqTable,
                [string[]]@(
                    "$stepIndex",
                    [Spectre.Console.Markup]::Escape($action.type),
                    [Spectre.Console.Markup]::Escape($actionName),
                    [Spectre.Console.Markup]::Escape($actionDetails)
                )
            ) | Out-Null
        }
        $Console.Write($seqTable)

        # Build dynamic action menu choices
        $menuChoices = [System.Collections.Generic.List[string]]::new()
        $menuChoices.Add('Move mouse to point')
        $menuChoices.Add('Move mouse to region (box)')
        $menuChoices.Add('Move mouse to region (circle)')
        $menuChoices.Add('Left-click')
        $menuChoices.Add('Drag-click')
        $menuChoices.Add('Screenshot region')
        $menuChoices.Add('Add delay')

        # 'Create loop' only if one or more NAMED non-Loop actions exist
        $namedNonLoopActions = @($sequence | Where-Object {
            $_.PSObject.Properties['name'] -and -not [string]::IsNullOrEmpty($_.name) -and $_.type -ne 'Loop'
        })
        if ($namedNonLoopActions.Count -gt 0) {
            $menuChoices.Add('Create loop')
        }

        # 'Save macro' only if at least one action exists
        if ($sequence.Count -gt 0) {
            $menuChoices.Add('Save macro')
        }

        $menuChoices.Add('Discard and exit')

        $actionPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
            'Add action to sequence:', $menuChoices.ToArray()
        )
        $menuChoice = $actionPrompt.Show($Console)

        switch ($menuChoice) {

            # ── Step 3a: Move mouse to point ──────────────────────────────────
            'Move mouse to point' {
                $captured = Invoke-CaptureMousePosition `
                    -WindowHandle $windowHandle `
                    -Console $Console `
                    -PromptMessage '[yellow]Move your mouse to the target position, then press [[Enter]]...[/]'

                if ($null -eq $captured) { break }

                $actionName = Invoke-RecordActionName -Console $Console -ExistingNames $existingNames
                if ($actionName -eq '__cancel__') { return $null }

                $action = [PSCustomObject]@{
                    type     = 'MoveToPoint'
                    position = [PSCustomObject]@{
                        relativeX = $captured.RelativeX
                        relativeY = $captured.RelativeY
                    }
                }
                if (-not [string]::IsNullOrEmpty($actionName)) {
                    $action | Add-Member -NotePropertyName 'name' -NotePropertyValue $actionName
                    $existingNames.Add($actionName) | Out-Null
                }

                $sequence.Add($action)
                $Console.Write([Spectre.Console.Markup]::new("[green]MoveToPoint action added to sequence (step $($sequence.Count)).[/]`n"))
            }

            # ── Step 3b: Move mouse to region (box) ──────────────────────────
            'Move mouse to region (box)' {
                $boxDone = $false
                while (-not $boxDone) {
                    $topLeft = Invoke-CaptureMousePosition `
                        -WindowHandle $windowHandle `
                        -Console $Console `
                        -PromptMessage '[yellow]Move your mouse to the TOP-LEFT corner of the target box, then press [[Enter]]...[/]'

                    if ($null -eq $topLeft) { $boxDone = $true; break }

                    $bottomRight = Invoke-CaptureMousePosition `
                        -WindowHandle $windowHandle `
                        -Console $Console `
                        -PromptMessage '[yellow]Move your mouse to the BOTTOM-RIGHT corner of the target box, then press [[Enter]]...[/]'

                    if ($null -eq $bottomRight) { $boxDone = $true; break }

                    $relativeWidth  = [math]::Round($bottomRight.RelativeX - $topLeft.RelativeX, 4)
                    $relativeHeight = [math]::Round($bottomRight.RelativeY - $topLeft.RelativeY, 4)

                    if ($relativeWidth -le 0 -or $relativeHeight -le 0) {
                        $Console.Write([Spectre.Console.Markup]::new("[red]Bottom-right must be below and to the right of top-left. Please try again.[/]`n"))
                        continue
                    }

                    $relativeX = $topLeft.RelativeX
                    $relativeY = $topLeft.RelativeY
                    $Console.Write([Spectre.Console.Markup]::new("Box region: position ($relativeX, $relativeY) size ($relativeWidth x $relativeHeight)`n"))

                    $actionName = Invoke-RecordActionName -Console $Console -ExistingNames $existingNames
                    if ($actionName -eq '__cancel__') { return $null }

                    $action = [PSCustomObject]@{
                        type   = 'MoveToRegion'
                        region = [PSCustomObject]@{
                            type           = 'Box'
                            relativeX      = $relativeX
                            relativeY      = $relativeY
                            relativeWidth  = $relativeWidth
                            relativeHeight = $relativeHeight
                        }
                    }
                    if (-not [string]::IsNullOrEmpty($actionName)) {
                        $action | Add-Member -NotePropertyName 'name' -NotePropertyValue $actionName
                        $existingNames.Add($actionName) | Out-Null
                    }

                    $sequence.Add($action)
                    $Console.Write([Spectre.Console.Markup]::new("[green]MoveToRegion (Box) action added to sequence (step $($sequence.Count)).[/]`n"))
                    $boxDone = $true
                }
            }

            # ── Step 3c: Move mouse to region (circle) ────────────────────────
            'Move mouse to region (circle)' {
                $circleDone = $false
                while (-not $circleDone) {
                    $centre = Invoke-CaptureMousePosition `
                        -WindowHandle $windowHandle `
                        -Console $Console `
                        -PromptMessage '[yellow]Move your mouse to the CENTRE of the target circle, then press [[Enter]]...[/]'

                    if ($null -eq $centre) { $circleDone = $true; break }

                    $edge = Invoke-CaptureMousePosition `
                        -WindowHandle $windowHandle `
                        -Console $Console `
                        -PromptMessage '[yellow]Move your mouse to the EDGE of the circle, then press [[Enter]]...[/]'

                    if ($null -eq $edge) { $circleDone = $true; break }

                    $radius = [math]::Round(
                        [math]::Sqrt(
                            [math]::Pow($edge.RelativeX - $centre.RelativeX, 2) +
                            [math]::Pow($edge.RelativeY - $centre.RelativeY, 2)
                        ), 4
                    )

                    if ($radius -le 0) {
                        $Console.Write([Spectre.Console.Markup]::new("[red]Edge point must be different from centre. Please try again.[/]`n"))
                        continue
                    }

                    $Console.Write([Spectre.Console.Markup]::new("Circle region: centre ($($centre.RelativeX), $($centre.RelativeY)), radius $radius`n"))

                    $actionName = Invoke-RecordActionName -Console $Console -ExistingNames $existingNames
                    if ($actionName -eq '__cancel__') { return $null }

                    $action = [PSCustomObject]@{
                        type   = 'MoveToRegion'
                        region = [PSCustomObject]@{
                            type             = 'Circle'
                            relativeCentreX  = $centre.RelativeX
                            relativeCentreY  = $centre.RelativeY
                            relativeRadius   = $radius
                        }
                    }
                    if (-not [string]::IsNullOrEmpty($actionName)) {
                        $action | Add-Member -NotePropertyName 'name' -NotePropertyValue $actionName
                        $existingNames.Add($actionName) | Out-Null
                    }

                    $sequence.Add($action)
                    $Console.Write([Spectre.Console.Markup]::new("[green]MoveToRegion (Circle) action added to sequence (step $($sequence.Count)).[/]`n"))
                    $circleDone = $true
                }
            }

            # ── Step 3d: Left-click ───────────────────────────────────────────
            'Left-click' {
                $Console.Write([Spectre.Console.Markup]::new("Left-click action will execute at the current mouse position during playback.`n"))

                $actionName = Invoke-RecordActionName -Console $Console -ExistingNames $existingNames
                if ($actionName -eq '__cancel__') { return $null }

                $action = [PSCustomObject]@{ type = 'LeftClick' }
                if (-not [string]::IsNullOrEmpty($actionName)) {
                    $action | Add-Member -NotePropertyName 'name' -NotePropertyValue $actionName
                    $existingNames.Add($actionName) | Out-Null
                }

                $sequence.Add($action)
                $Console.Write([Spectre.Console.Markup]::new("[green]LeftClick action added to sequence (step $($sequence.Count)).[/]`n"))
            }

            # ── Step 3e: Drag-click ───────────────────────────────────────────
            'Drag-click' {
                $startPos = Invoke-CaptureMousePosition `
                    -WindowHandle $windowHandle `
                    -Console $Console `
                    -PromptMessage '[yellow]Move your mouse to the DRAG START position, then press [[Enter]]...[/]'

                if ($null -eq $startPos) { break }

                $endPos = Invoke-CaptureMousePosition `
                    -WindowHandle $windowHandle `
                    -Console $Console `
                    -PromptMessage '[yellow]Move your mouse to the DRAG END position (where the button will be released), then press [[Enter]]...[/]'

                if ($null -eq $endPos) { break }

                $Console.Write([Spectre.Console.Markup]::new("Drag from ($($startPos.RelativeX), $($startPos.RelativeY)) to ($($endPos.RelativeX), $($endPos.RelativeY))`n"))

                $actionName = Invoke-RecordActionName -Console $Console -ExistingNames $existingNames
                if ($actionName -eq '__cancel__') { return $null }

                $action = [PSCustomObject]@{
                    type  = 'DragClick'
                    start = [PSCustomObject]@{
                        relativeX = $startPos.RelativeX
                        relativeY = $startPos.RelativeY
                    }
                    end   = [PSCustomObject]@{
                        relativeX = $endPos.RelativeX
                        relativeY = $endPos.RelativeY
                    }
                }
                if (-not [string]::IsNullOrEmpty($actionName)) {
                    $action | Add-Member -NotePropertyName 'name' -NotePropertyValue $actionName
                    $existingNames.Add($actionName) | Out-Null
                }

                $sequence.Add($action)
                $Console.Write([Spectre.Console.Markup]::new("[green]DragClick action added to sequence (step $($sequence.Count)).[/]`n"))
            }

            # ── Step 3f: Screenshot region ────────────────────────────────────
            'Screenshot region' {
                $sssDone = $false
                while (-not $sssDone) {
                    $ssTopLeft = Invoke-CaptureMousePosition `
                        -WindowHandle $windowHandle `
                        -Console $Console `
                        -PromptMessage '[yellow]Move your mouse to the TOP-LEFT of the screenshot region, then press [[Enter]]...[/]'

                    if ($null -eq $ssTopLeft) { $sssDone = $true; break }

                    $ssBottomRight = Invoke-CaptureMousePosition `
                        -WindowHandle $windowHandle `
                        -Console $Console `
                        -PromptMessage '[yellow]Move your mouse to the BOTTOM-RIGHT of the screenshot region, then press [[Enter]]...[/]'

                    if ($null -eq $ssBottomRight) { $sssDone = $true; break }

                    if ($ssBottomRight.RelativeX -le $ssTopLeft.RelativeX -or $ssBottomRight.RelativeY -le $ssTopLeft.RelativeY) {
                        $Console.Write([Spectre.Console.Markup]::new("[red]Bottom-right must be below and to the right of top-left. Please try again.[/]`n"))
                        continue
                    }

                    $Console.Write([Spectre.Console.Markup]::new("Screenshot region: ($($ssTopLeft.RelativeX), $($ssTopLeft.RelativeY)) to ($($ssBottomRight.RelativeX), $($ssBottomRight.RelativeY))`n"))
                    $Console.Write([Spectre.Console.Markup]::new("[grey]Naming screenshot actions is recommended so they can be referenced in loops.[/]`n"))

                    # ── Mask region recording loop ─────────────────────────────────────
                    $maskRegions = [System.Collections.Generic.List[object]]::new()
                    $addMask = Invoke-YesNoPrompt -Console $Console -Message 'Add a black-out region to this screenshot?'
                    while ($addMask) {
                        $maskTopLeft = Invoke-CaptureMousePosition `
                            -Console $Console `
                            -WindowHandle $windowHandle `
                            -PromptMessage '[grey]Move mouse to the top-left corner of the black-out region, then press [[Enter]].[/]'
                        if ($null -eq $maskTopLeft) { break }

                        $maskBottomRight = Invoke-CaptureMousePosition `
                            -Console $Console `
                            -WindowHandle $windowHandle `
                            -PromptMessage '[grey]Move mouse to the bottom-right corner of the black-out region, then press [[Enter]].[/]'
                        if ($null -eq $maskBottomRight) { break }

                        if ($maskBottomRight.RelativeX -le $maskTopLeft.RelativeX -or
                            $maskBottomRight.RelativeY -le $maskTopLeft.RelativeY) {
                            $Console.Write([Spectre.Console.Markup]::new("[red]Bottom-right corner must be below and to the right of the top-left corner. Black-out region not added.[/]`n"))
                        } else {
                            $overlapExists = ($maskTopLeft.RelativeX  -lt $ssBottomRight.RelativeX) -and
                                             ($maskBottomRight.RelativeX -gt $ssTopLeft.RelativeX)  -and
                                             ($maskTopLeft.RelativeY  -lt $ssBottomRight.RelativeY) -and
                                             ($maskBottomRight.RelativeY -gt $ssTopLeft.RelativeY)
                            if (-not $overlapExists) {
                                $Console.Write([Spectre.Console.Markup]::new('[yellow]Warning: this black-out region does not overlap the screenshot region and will have no visible effect.[/]'))
                            }
                            $maskRegions.Add([PSCustomObject]@{
                                topLeft     = [PSCustomObject]@{ relativeX = $maskTopLeft.RelativeX;     relativeY = $maskTopLeft.RelativeY }
                                bottomRight = [PSCustomObject]@{ relativeX = $maskBottomRight.RelativeX; relativeY = $maskBottomRight.RelativeY }
                            })
                        }

                        $addMask = Invoke-YesNoPrompt -Console $Console -Message 'Add another black-out region?'
                    }

                    $actionName = Invoke-RecordActionName -Console $Console -ExistingNames $existingNames
                    if ($actionName -eq '__cancel__') { return $null }

                    $action = [PSCustomObject]@{
                        type   = 'Screenshot'
                        region = [PSCustomObject]@{
                            topLeft     = [PSCustomObject]@{
                                relativeX = $ssTopLeft.RelativeX
                                relativeY = $ssTopLeft.RelativeY
                            }
                            bottomRight = [PSCustomObject]@{
                                relativeX = $ssBottomRight.RelativeX
                                relativeY = $ssBottomRight.RelativeY
                            }
                        }
                    }
                    if ($maskRegions.Count -gt 0) {
                        $action | Add-Member -NotePropertyName maskRegions -NotePropertyValue $maskRegions.ToArray()
                    }
                    if (-not [string]::IsNullOrEmpty($actionName)) {
                        $action | Add-Member -NotePropertyName 'name' -NotePropertyValue $actionName
                        $existingNames.Add($actionName) | Out-Null
                    }

                    $sequence.Add($action)
                    $Console.Write([Spectre.Console.Markup]::new("[green]Screenshot action added to sequence (step $($sequence.Count)).[/]`n"))
                    $sssDone = $true
                }
            }

            # ── Step 3g: Add delay ────────────────────────────────────────────
            'Add delay' {
                $delaySeconds = $null
                while ($null -eq $delaySeconds) {
                    $delayPrompt           = [Spectre.Console.TextPrompt[string]]::new('Enter delay in seconds (0.1 - 3600):')
                    $delayPrompt.AllowEmpty = $false
                    $delayInput            = $delayPrompt.Show($Console)

                    $parsedDelay = 0.0
                    if (-not [double]::TryParse($delayInput, [ref]$parsedDelay) -or $parsedDelay -lt 0.1 -or $parsedDelay -gt 3600) {
                        $Console.Write([Spectre.Console.Markup]::new("[red]Invalid delay. Enter a number between 0.1 and 3600.[/]`n"))
                        continue
                    }
                    $delaySeconds = $parsedDelay
                }

                $actionName = Invoke-RecordActionName -Console $Console -ExistingNames $existingNames
                if ($actionName -eq '__cancel__') { return $null }

                $action = [PSCustomObject]@{
                    type    = 'Delay'
                    seconds = $delaySeconds
                }
                if (-not [string]::IsNullOrEmpty($actionName)) {
                    $action | Add-Member -NotePropertyName 'name' -NotePropertyValue $actionName
                    $existingNames.Add($actionName) | Out-Null
                }

                $sequence.Add($action)
                $Console.Write([Spectre.Console.Markup]::new("[green]Delay action added to sequence (step $($sequence.Count)).[/]`n"))
            }

            # ── Step 3h: Create loop ──────────────────────────────────────────
            'Create loop' {
                # Table of named non-Loop actions available for selection
                $availableForLoop = @($sequence | Where-Object {
                    $_.PSObject.Properties['name'] -and -not [string]::IsNullOrEmpty($_.name) -and $_.type -ne 'Loop'
                })

                $loopTable = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(@('#', 'Name', 'Type', 'Details'))
                $loopIdx   = 0
                foreach ($loopAction in $availableForLoop) {
                    $loopIdx++
                    $loopDetails = switch ($loopAction.type) {
                        'MoveToPoint'  { "($($loopAction.position.relativeX), $($loopAction.position.relativeY))" }
                        'MoveToRegion' {
                            if ($loopAction.region.type -eq 'Box') {
                                "Box at ($($loopAction.region.relativeX), $($loopAction.region.relativeY))"
                            } else {
                                "Circle centre ($($loopAction.region.relativeCentreX), $($loopAction.region.relativeCentreY))"
                            }
                        }
                        'LeftClick'    { 'at current position' }
                        'DragClick'    { "($($loopAction.start.relativeX), $($loopAction.start.relativeY)) -> ($($loopAction.end.relativeX), $($loopAction.end.relativeY))" }
                        'Screenshot'   {
                            $regionStr = "($($loopAction.region.topLeft.relativeX), $($loopAction.region.topLeft.relativeY)) to ($($loopAction.region.bottomRight.relativeX), $($loopAction.region.bottomRight.relativeY))"
                            if ($loopAction.PSObject.Properties['maskRegions'] -and $loopAction.maskRegions.Count -gt 0) {
                                "$regionStr | $($loopAction.maskRegions.Count) mask(s)"
                            } else {
                                $regionStr
                            }
                        }
                        'Delay'        { "$($loopAction.seconds)s" }
                        default        { '' }
                    }
                    [Spectre.Console.TableExtensions]::AddRow(
                        $loopTable,
                        [string[]]@(
                            "$loopIdx",
                            [Spectre.Console.Markup]::Escape($loopAction.name),
                            [Spectre.Console.Markup]::Escape($loopAction.type),
                            [Spectre.Console.Markup]::Escape($loopDetails)
                        )
                    ) | Out-Null
                }
                $Console.Write($loopTable)

                $loopActionNames = [System.Collections.Generic.List[string]]::new()
                $loopSelecting   = $true

                while ($loopSelecting) {
                    $loopNameChoices = [System.Collections.Generic.List[string]]::new()
                    foreach ($la in $availableForLoop) { $loopNameChoices.Add($la.name) }
                    $loopNameChoices.Add('Done adding actions')
                    $loopNameChoices.Add('Cancel loop')

                    $loopSelectPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                        'Select an action to add to the loop:', $loopNameChoices.ToArray()
                    )
                    $loopSelected = $loopSelectPrompt.Show($Console)

                    if ($loopSelected -eq 'Cancel loop') {
                        $loopSelecting = $false
                        $loopActionNames.Clear()
                        break
                    }

                    if ($loopSelected -eq 'Done adding actions') {
                        $loopSelecting = $false
                        break
                    }

                    $loopActionNames.Add($loopSelected) | Out-Null
                    $Console.Write([Spectre.Console.Markup]::new("Loop so far: $($loopActionNames -join ' -> ')`n"))
                }

                if ($loopActionNames.Count -eq 0) { break }

                $loopCount = $null
                while ($null -eq $loopCount) {
                    $loopCountPrompt           = [Spectre.Console.TextPrompt[string]]::new('How many times should this loop repeat? (1 - 10000):')
                    $loopCountPrompt.AllowEmpty = $false
                    $loopCountInput            = $loopCountPrompt.Show($Console)

                    $parsedCount = 0
                    if (-not [int]::TryParse($loopCountInput, [ref]$parsedCount) -or $parsedCount -lt 1 -or $parsedCount -gt 10000) {
                        $Console.Write([Spectre.Console.Markup]::new("[red]Invalid count. Enter an integer between 1 and 10000.[/]`n"))
                        continue
                    }
                    $loopCount = $parsedCount
                }

                $loopName = Invoke-RecordActionName -Console $Console -ExistingNames $existingNames
                if ($loopName -eq '__cancel__') { return $null }

                $Console.Write([Spectre.Console.Markup]::new("Loop: $($loopActionNames -join ' -> ') x$loopCount iterations`n"))

                $action = [PSCustomObject]@{
                    type        = 'Loop'
                    iterations  = $loopCount
                    actionNames = $loopActionNames.ToArray()
                }
                if (-not [string]::IsNullOrEmpty($loopName)) {
                    $action | Add-Member -NotePropertyName 'name' -NotePropertyValue $loopName
                    $existingNames.Add($loopName) | Out-Null
                }

                $sequence.Add($action)
                $Console.Write([Spectre.Console.Markup]::new("[green]Loop action added to sequence (step $($sequence.Count)).[/]`n"))
            }

            # ── Step 3i: Save macro ───────────────────────────────────────────
            'Save macro' {
                $macroData = [PSCustomObject]@{
                    version      = $script:MacroSchemaVersion
                    metadata     = [PSCustomObject]@{
                        name        = $macroName
                        createdUtc  = (Get-Date).ToUniversalTime().ToString('o')
                        modifiedUtc = (Get-Date).ToUniversalTime().ToString('o')
                        description = ''
                    }
                    targetWindow = [PSCustomObject]@{
                        processName = $config.ProcessName
                        windowTitle = $config.WindowTitle
                    }
                    sequence     = $sequence.ToArray()
                }

                $validation = Test-MacroFile -MacroData $macroData
                if (-not $validation.Valid) {
                    $validationMessages = $validation.Messages -join "`n"
                    $errorPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                        $validationMessages,
                        '[red]Validation Failed[/]'
                    )
                    $Console.Write($errorPanel)
                    break
                }

                $saveResult = Save-MacroFile -MacroData $macroData
                if ($saveResult.Success) {
                    $successPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                        "Macro '$macroName' saved successfully.",
                        '[green]Saved[/]'
                    )
                    $Console.Write($successPanel)
                    Write-LastWarLog -Level Info `
                        -Message "Macro '$macroName' saved with $($sequence.Count) actions." `
                        -FunctionName 'Show-RecordMacroScreen'
                    return $null
                } else {
                    $errorPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                        $saveResult.Message,
                        '[red]Save Failed[/]'
                    )
                    $Console.Write($errorPanel)
                }
            }

            # ── Step 3j: Discard and exit ─────────────────────────────────────
            'Discard and exit' {
                if ($sequence.Count -eq 0) {
                    return $null
                }

                $discardPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                    "Are you sure you want to discard this macro? All $($sequence.Count) recorded actions will be lost.",
                    @('Yes, discard', 'No, continue recording')
                )
                $discardChoice = $discardPrompt.Show($Console)

                if ($discardChoice -eq 'Yes, discard') {
                    return $null
                }
                # 'No, continue recording': fall back to the action menu
            }
        }
    }
}

function Invoke-RecordActionName {
    <#
    .SYNOPSIS
        Prompts for an optional action name during macro recording, with validation and auto-fix.

    .DESCRIPTION
        Displays a TextPrompt allowing the user to enter a name for the action being recorded,
        or press Enter to skip naming.  If a name is supplied it is validated via
        Get-ValidMacroName -AutoFix.  When spaces are converted the sanitised name is shown
        and the user may confirm, re-enter, or cancel the entire recording session.

        Returns:
          - Empty string when the user skips naming (presses Enter with no input)
          - The validated, sanitised name string when accepted
          - '__cancel__' sentinel when the user selects 'Cancel' in a confirmation prompt,
            signalling the caller to return $null and exit recording

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for all rendering and input.

    .PARAMETER ExistingNames
        Names already used in the current recording session.  Used by Get-ValidMacroName
        for uniqueness checking.

    .OUTPUTS
        System.String

    .EXAMPLE
        $name = Invoke-RecordActionName -Console $Console -ExistingNames $existingNames
        if ($name -eq '__cancel__') { return $null }
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console,

        [Parameter()]
        [System.Collections.Generic.List[string]]$ExistingNames = [System.Collections.Generic.List[string]]::new()
    )

    while ($true) {
        $namePrompt           = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateEmptyTextPrompt('Enter a name for this action (or press [[Enter]] to skip):')
        $rawName              = $namePrompt.Show($Console)

        if ([string]::IsNullOrEmpty($rawName)) {
            return ''
        }

        $nameResult = Get-ValidMacroName -Name $rawName -AutoFix -ExistingNames $ExistingNames.ToArray()

        if ($nameResult.WasAutoFixed) {
            $confirmPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                "Name was sanitised. Use `"$($nameResult.SanitisedName)`"?",
                @("Use `"$($nameResult.SanitisedName)`"", 'Enter a different name', 'Cancel')
            )
            $confirmChoice = $confirmPrompt.Show($Console)

            if ($confirmChoice -eq 'Cancel') { return '__cancel__' }
            if ($confirmChoice -eq 'Enter a different name') { continue }
        }

        if (-not $nameResult.Valid) {
            $Console.Write([Spectre.Console.Markup]::new("[red]$([Spectre.Console.Markup]::Escape($nameResult.Message))[/]`n"))
            continue
        }

        return $nameResult.SanitisedName
    }
}
