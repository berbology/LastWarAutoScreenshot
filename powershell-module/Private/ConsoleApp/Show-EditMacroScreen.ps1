function Get-MacroActionDetailString {
    <#
    .SYNOPSIS
        Returns a short human-readable summary string for a single macro action's parameters.

    .DESCRIPTION
        Formats the key parameters of a macro action into a compact string for display
        in the sequence table shown on the Edit Macro and Manage Macros screens.

    .PARAMETER Action
        The PSCustomObject representing the action (as parsed from the macro JSON).

    .OUTPUTS
        String
        A compact summary of the action's parameters, or an empty string for unknown types.

    .EXAMPLE
        Get-MacroActionDetailString -Action ([PSCustomObject]@{ type = 'Delay'; seconds = 2.5 })
        # Returns: '2.5s'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Action
    )

    switch ($Action.type) {
        'MoveToPoint' {
            return "($($Action.position.relativeX), $($Action.position.relativeY))"
        }
        'MoveToRegion' {
            if ($Action.region.type -eq 'Circle') {
                return "Circle ($($Action.region.relativeCentreX), $($Action.region.relativeCentreY)) r=$($Action.region.relativeRadius)"
            } else {
                return "Box ($($Action.region.relativeX), $($Action.region.relativeY)) $($Action.region.relativeWidth)x$($Action.region.relativeHeight)"
            }
        }
        'LeftClick'   { return '(current position)' }
        'DragClick'   {
            return "($($Action.start.relativeX), $($Action.start.relativeY)) -> ($($Action.end.relativeX), $($Action.end.relativeY))"
        }
        'Screenshot'  {
            return "($($Action.region.topLeft.relativeX), $($Action.region.topLeft.relativeY)) to ($($Action.region.bottomRight.relativeX), $($Action.region.bottomRight.relativeY))"
        }
        'Delay'       { return "$($Action.seconds)s" }
        'Loop'        { return "$($Action.iterations)x: $($Action.actionNames -join ', ')" }
        default       { return '' }
    }
}

function Show-EditMacroScreen {
    <#
    .SYNOPSIS
        Displays the Edit Macro screen, allowing the user to add steps, rename the macro,
        rename or reorder steps, and save or discard changes.

    .DESCRIPTION
        Loads the macro at the given file path via Get-MacroFile, then enters an interactive
        loop presenting a dynamic SelectionPrompt.

        The available options depend on whether unsaved changes exist:
          - Always shown:              'Add steps', 'Rename macro', 'Edit steps'
          - Shown only with changes:   'Save changes', 'Discard changes'
          - Shown only without changes:'[[Back]]'

        Add steps:
          Enters an action recording loop (identical to Record Macro) that appends new
          actions to the end of the existing sequence.  Supported action types are the
          same as in Show-RecordMacroScreen (MoveToPoint, MoveToRegion, LeftClick,
          DragClick, Screenshot, Delay, Upload screenshots, Loop).  When the user
          selects 'Done adding steps', the new actions are appended to the sequence,
          changes are marked, and a prompt offers to save immediately or return to the
          edit menu.  'Discard added steps' abandons the new actions after confirmation.

        Rename macro:
          Prompts for a new name (or Enter to keep current).  Validated via
          Get-ValidMacroName -AutoFix, checking uniqueness against all other saved macros.
          If the name contained spaces and was auto-fixed, the user confirms before applying.

        Edit steps:
          Shows a numbered list of all steps.  For the selected step, offers Rename step /
          Add name to step, Move up (hidden if first), Move down (hidden if last), and
          [[Back to step list]].  Renaming a step that is referenced by a Loop action
          automatically updates the Loop's actionNames array.

        Save changes:
          Updates modifiedUtc, calls Rename-MacroFile if the name changed, then calls
          Save-MacroFile -Force to persist all in-memory changes.

        Discard changes:
          Asks for confirmation, then returns without saving.

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for all rendering and input.
        Pass [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole() for production use,
        or a [Spectre.Console.Testing.TestConsole]::new() instance in Pester tests.

    .PARAMETER FilePath
        Absolute path to the macro JSON file to edit.

    .OUTPUTS
        None

    .EXAMPLE
        $console  = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        $macroList = Get-LWASMacro
        Show-EditMacroScreen -Console $console -FilePath $macroList[0].FilePath

    .NOTES
        The $Console parameter is the testability injection point.  All rendering and input
        is routed through this interface so Pester tests can inject a TestConsole and assert
        on its Output property without requiring a live terminal.

        $FilePath is a local variable and may be reassigned if the macro is renamed
        (Rename-MacroFile returns a NewFilePath).  The in-memory $macroData is always
        saved via Save-MacroFile -Force after any rename to ensure step-level changes are
        also persisted.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console,

        [Parameter(Mandatory)]
        [string]$FilePath
    )

    # ── Load macro ────────────────────────────────────────────────────────────
    $macroResult = Get-MacroFile -FilePath $FilePath
    if ($null -eq $macroResult) {
        $Console.Write(
            [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'Failed to load macro file. The file may be missing or contain invalid JSON.',
                'Error'
            )
        )
        return
    }

    $macroData    = $macroResult.Data
    $hasChanges   = $false
    $originalName = $macroData.metadata.name

    # ── Edit menu loop ────────────────────────────────────────────────────────
    while ($true) {

        # Display sequence table
        $seqTable = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(@('#', 'Type', 'Name', 'Details'))
        $rowNum   = 0
        foreach ($action in $macroData.sequence) {
            $rowNum++
            $actionName    = if ($action.PSObject.Properties['name'] -and -not [string]::IsNullOrEmpty($action.name)) { $action.name } else { '' }
            $actionDetails = Get-MacroActionDetailString -Action $action
            [Spectre.Console.TableExtensions]::AddRow(
                $seqTable,
                [string[]]@([string]$rowNum, $action.type, $actionName, $actionDetails)
            ) | Out-Null
        }
        $Console.Write($seqTable)

        # Build dynamic edit menu
        $editChoices = [System.Collections.Generic.List[string]]::new()
        $editChoices.Add('Add steps')
        $editChoices.Add('Rename macro')
        $editChoices.Add('Edit steps')
        if ($hasChanges) {
            $editChoices.Add('Save changes')
            $editChoices.Add('Discard changes')
        } else {
            $editChoices.Add('[[Back]]')
        }

        $editPrompt    = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
            "Editing macro: $([Spectre.Console.Markup]::Escape($macroData.metadata.name))",
            $editChoices.ToArray()
        )
        $editSelection = $editPrompt.Show($Console)

        switch ($editSelection) {

            'Add steps' {
                # ── Add steps loop ────────────────────────────────────────────
                $windowHandle = $null
                try {
                    $targetWindowObj = Get-LWASTargetWindow `
                        -ProcessName $macroData.targetWindow.processName `
                        -First `
                        -ErrorAction Stop
                    $windowHandle = $targetWindowObj.WindowHandle
                } catch {
                    Write-LastWarLog -Level Warning `
                        -Message "Get-LWASTargetWindow threw an exception in Show-EditMacroScreen (Add steps): $_" `
                        -FunctionName 'Show-EditMacroScreen'
                }

                if ($null -eq $windowHandle) {
                    $windowErrorPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                        "Target window is not open. The window for process '$($macroData.targetWindow.processName)' could not be found.",
                        '[red]Error[/]'
                    )
                    $Console.Write($windowErrorPanel)
                    continue
                }

                # Seed existing names from the current sequence so new names are unique
                $addExistingNames = [System.Collections.Generic.List[string]]::new()
                foreach ($existingAction in $macroData.sequence) {
                    if ($existingAction.PSObject.Properties['name'] -and -not [string]::IsNullOrEmpty($existingAction.name)) {
                        $addExistingNames.Add($existingAction.name) | Out-Null
                    }
                }

                $newSteps     = [System.Collections.Generic.List[PSCustomObject]]::new()
                $addStepsDone = $false

                while (-not $addStepsDone) {
                    # Display current sequence (existing + new steps so far) as a table
                    $addSeqTable = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(@('#', 'Type', 'Name', 'Details'))
                    $addRowNum   = 0
                    foreach ($addAction in $macroData.sequence) {
                        $addRowNum++
                        $addActionName    = if ($addAction.PSObject.Properties['name'] -and -not [string]::IsNullOrEmpty($addAction.name)) { $addAction.name } else { '' }
                        $addActionDetails = Get-MacroActionDetailString -Action $addAction
                        [Spectre.Console.TableExtensions]::AddRow(
                            $addSeqTable,
                            [string[]]@([string]$addRowNum, $addAction.type, $addActionName, $addActionDetails)
                        ) | Out-Null
                    }
                    foreach ($newAction in $newSteps) {
                        $addRowNum++
                        $newActionName    = if ($newAction.PSObject.Properties['name'] -and -not [string]::IsNullOrEmpty($newAction.name)) { $newAction.name } else { '' }
                        $newActionDetails = Get-MacroActionDetailString -Action $newAction
                        [Spectre.Console.TableExtensions]::AddRow(
                            $addSeqTable,
                            [string[]]@([string]$addRowNum, $newAction.type, $newActionName, $newActionDetails)
                        ) | Out-Null
                    }
                    $Console.Write($addSeqTable)

                    # Build action menu choices (same as Show-RecordMacroScreen)
                    $addMenuChoices = [System.Collections.Generic.List[string]]::new()
                    $addMenuChoices.Add('Move mouse to point')
                    $addMenuChoices.Add('Move mouse to region (box)')
                    $addMenuChoices.Add('Move mouse to region (circle)')
                    $addMenuChoices.Add('Left-click')
                    $addMenuChoices.Add('Drag-click')
                    $addMenuChoices.Add('Screenshot region')
                    $addMenuChoices.Add('Add delay')
                    $addMenuChoices.Add('Upload screenshots')

                    # 'Create loop' only when named non-Loop actions exist in combined sequence
                    $combinedSequence = [System.Collections.Generic.List[PSCustomObject]]::new()
                    foreach ($cs in $macroData.sequence) { $combinedSequence.Add($cs) | Out-Null }
                    foreach ($cs in $newSteps)           { $combinedSequence.Add($cs) | Out-Null }
                    $namedNonLoopActions = @($combinedSequence | Where-Object {
                        $_.PSObject.Properties['name'] -and -not [string]::IsNullOrEmpty($_.name) -and $_.type -ne 'Loop'
                    })
                    if ($namedNonLoopActions.Count -gt 0) {
                        $addMenuChoices.Add('Create loop')
                    }

                    if ($newSteps.Count -gt 0) {
                        $addMenuChoices.Add('Done adding steps')
                    }
                    $addMenuChoices.Add('Discard added steps')

                    $addActionPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                        'Add action to sequence:', $addMenuChoices.ToArray()
                    )
                    $addMenuChoice = $addActionPrompt.Show($Console)

                    switch ($addMenuChoice) {

                        'Move mouse to point' {
                            $captured = Invoke-CaptureMousePosition `
                                -WindowHandle $windowHandle `
                                -Console $Console `
                                -PromptMessage '[yellow]Move your mouse to the target position, then press [[Enter]]...[/]'

                            if ($null -eq $captured) { break }

                            $actionName = Invoke-RecordActionName -Console $Console -ExistingNames $addExistingNames
                            if ($actionName -eq '__cancel__') { break }

                            $newAction = [PSCustomObject]@{
                                type     = 'MoveToPoint'
                                position = [PSCustomObject]@{
                                    relativeX = $captured.RelativeX
                                    relativeY = $captured.RelativeY
                                }
                            }
                            if (-not [string]::IsNullOrEmpty($actionName)) {
                                $newAction | Add-Member -NotePropertyName 'name' -NotePropertyValue $actionName
                                $addExistingNames.Add($actionName) | Out-Null
                            }
                            $newSteps.Add($newAction)
                            $Console.Write([Spectre.Console.Markup]::new("[green]MoveToPoint action added (step $($macroData.sequence.Count + $newSteps.Count)).[/]`n"))
                        }

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

                                $actionName = Invoke-RecordActionName -Console $Console -ExistingNames $addExistingNames
                                if ($actionName -eq '__cancel__') { $boxDone = $true; break }

                                $newAction = [PSCustomObject]@{
                                    type   = 'MoveToRegion'
                                    region = [PSCustomObject]@{
                                        type           = 'Box'
                                        relativeX      = $topLeft.RelativeX
                                        relativeY      = $topLeft.RelativeY
                                        relativeWidth  = $relativeWidth
                                        relativeHeight = $relativeHeight
                                    }
                                }
                                if (-not [string]::IsNullOrEmpty($actionName)) {
                                    $newAction | Add-Member -NotePropertyName 'name' -NotePropertyValue $actionName
                                    $addExistingNames.Add($actionName) | Out-Null
                                }
                                $newSteps.Add($newAction)
                                $Console.Write([Spectre.Console.Markup]::new("[green]MoveToRegion (Box) action added (step $($macroData.sequence.Count + $newSteps.Count)).[/]`n"))
                                $boxDone = $true
                            }
                        }

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

                                $actionName = Invoke-RecordActionName -Console $Console -ExistingNames $addExistingNames
                                if ($actionName -eq '__cancel__') { $circleDone = $true; break }

                                $newAction = [PSCustomObject]@{
                                    type   = 'MoveToRegion'
                                    region = [PSCustomObject]@{
                                        type            = 'Circle'
                                        relativeCentreX = $centre.RelativeX
                                        relativeCentreY = $centre.RelativeY
                                        relativeRadius  = $radius
                                    }
                                }
                                if (-not [string]::IsNullOrEmpty($actionName)) {
                                    $newAction | Add-Member -NotePropertyName 'name' -NotePropertyValue $actionName
                                    $addExistingNames.Add($actionName) | Out-Null
                                }
                                $newSteps.Add($newAction)
                                $Console.Write([Spectre.Console.Markup]::new("[green]MoveToRegion (Circle) action added (step $($macroData.sequence.Count + $newSteps.Count)).[/]`n"))
                                $circleDone = $true
                            }
                        }

                        'Left-click' {
                            $Console.Write([Spectre.Console.Markup]::new("Left-click action will execute at the current mouse position during playback.`n"))

                            $actionName = Invoke-RecordActionName -Console $Console -ExistingNames $addExistingNames
                            if ($actionName -eq '__cancel__') { break }

                            $newAction = [PSCustomObject]@{ type = 'LeftClick' }
                            if (-not [string]::IsNullOrEmpty($actionName)) {
                                $newAction | Add-Member -NotePropertyName 'name' -NotePropertyValue $actionName
                                $addExistingNames.Add($actionName) | Out-Null
                            }
                            $newSteps.Add($newAction)
                            $Console.Write([Spectre.Console.Markup]::new("[green]LeftClick action added (step $($macroData.sequence.Count + $newSteps.Count)).[/]`n"))
                        }

                        'Drag-click' {
                            $startPos = Invoke-CaptureMousePosition `
                                -WindowHandle $windowHandle `
                                -Console $Console `
                                -PromptMessage '[yellow]Move your mouse to the DRAG START position, then press [[Enter]]...[/]'

                            if ($null -eq $startPos) { break }

                            $endPos = Invoke-CaptureMousePosition `
                                -WindowHandle $windowHandle `
                                -Console $Console `
                                -PromptMessage '[yellow]Move your mouse to the DRAG END position, then press [[Enter]]...[/]'

                            if ($null -eq $endPos) { break }

                            $actionName = Invoke-RecordActionName -Console $Console -ExistingNames $addExistingNames
                            if ($actionName -eq '__cancel__') { break }

                            $newAction = [PSCustomObject]@{
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
                                $newAction | Add-Member -NotePropertyName 'name' -NotePropertyValue $actionName
                                $addExistingNames.Add($actionName) | Out-Null
                            }
                            $newSteps.Add($newAction)
                            $Console.Write([Spectre.Console.Markup]::new("[green]DragClick action added (step $($macroData.sequence.Count + $newSteps.Count)).[/]`n"))
                        }

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

                                $actionName = Invoke-RecordActionName -Console $Console -ExistingNames $addExistingNames
                                if ($actionName -eq '__cancel__') { $sssDone = $true; break }

                                $newAction = [PSCustomObject]@{
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
                                if (-not [string]::IsNullOrEmpty($actionName)) {
                                    $newAction | Add-Member -NotePropertyName 'name' -NotePropertyValue $actionName
                                    $addExistingNames.Add($actionName) | Out-Null
                                }
                                $newSteps.Add($newAction)
                                $Console.Write([Spectre.Console.Markup]::new("[green]Screenshot action added (step $($macroData.sequence.Count + $newSteps.Count)).[/]`n"))
                                $sssDone = $true
                            }
                        }

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

                            $actionName = Invoke-RecordActionName -Console $Console -ExistingNames $addExistingNames
                            if ($actionName -eq '__cancel__') { break }

                            $newAction = [PSCustomObject]@{
                                type    = 'Delay'
                                seconds = $delaySeconds
                            }
                            if (-not [string]::IsNullOrEmpty($actionName)) {
                                $newAction | Add-Member -NotePropertyName 'name' -NotePropertyValue $actionName
                                $addExistingNames.Add($actionName) | Out-Null
                            }
                            $newSteps.Add($newAction)
                            $Console.Write([Spectre.Console.Markup]::new("[green]Delay action added (step $($macroData.sequence.Count + $newSteps.Count)).[/]`n"))
                        }

                        'Upload screenshots' {
                            $availableProfiles = @(Get-UploadProfile)
                            if ($availableProfiles.Count -eq 0) {
                                $Console.Write(
                                    [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                                        'No upload profiles configured. Add one via Config → Upload profiles.',
                                        '[yellow]Warning[/]'
                                    )
                                )
                                break
                            }

                            $profileChoices = [System.Collections.Generic.List[string]]::new()
                            foreach ($p in $availableProfiles) { $profileChoices.Add($p.name) }
                            $profileChoices.Add('[[Cancel]]')

                            $profilePrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                                'Select an upload profile:', $profileChoices.ToArray()
                            )
                            $selectedProfile = $profilePrompt.Show($Console)
                            if ($selectedProfile -eq 'Cancel') { break }

                            $scopePrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                                'Upload scope:',
                                @('All screenshots in this macro sequence', 'Screenshots from named sequence step')
                            )
                            $scopeChoice = $scopePrompt.Show($Console)

                            $uploadScope          = 'MacroSequence'
                            $uploadScreenshotName = $null

                            if ($scopeChoice -eq 'Screenshots from named sequence step') {
                                $namedScreenshots = @($combinedSequence | Where-Object {
                                    $_.type -eq 'Screenshot' -and
                                    $_.PSObject.Properties['name'] -and
                                    -not [string]::IsNullOrEmpty($_.name)
                                })
                                if ($namedScreenshots.Count -eq 0) {
                                    $Console.Write(
                                        [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                                            'No Screenshot actions in this sequence yet. Add a Screenshot step first.',
                                            '[yellow]Warning[/]'
                                        )
                                    )
                                    break
                                }

                                $ssStepChoices = [System.Collections.Generic.List[string]]::new()
                                foreach ($ss in $namedScreenshots) { $ssStepChoices.Add($ss.name) }
                                $ssStepChoices.Add('[[Cancel]]')

                                $ssStepPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                                    'Select screenshot action:', $ssStepChoices.ToArray()
                                )
                                $selectedSsStep = $ssStepPrompt.Show($Console)
                                if ($selectedSsStep -eq 'Cancel') { break }

                                $uploadScope          = 'NamedStep'
                                $uploadScreenshotName = $selectedSsStep
                            }

                            $newAction = [PSCustomObject]@{
                                type              = 'UploadScreenshots'
                                uploadProfileName = $selectedProfile
                                scope             = $uploadScope
                            }
                            if ($null -ne $uploadScreenshotName) {
                                $newAction | Add-Member -NotePropertyName 'screenshotActionName' -NotePropertyValue $uploadScreenshotName
                            }
                            $newSteps.Add($newAction)
                            $Console.Write([Spectre.Console.Markup]::new("[green]UploadScreenshots action added (step $($macroData.sequence.Count + $newSteps.Count)).[/]`n"))
                        }

                        'Create loop' {
                            $loopActionNames = [System.Collections.Generic.List[string]]::new()
                            $loopSelecting   = $true

                            while ($loopSelecting) {
                                $loopNameChoices = [System.Collections.Generic.List[string]]::new()
                                foreach ($la in $namedNonLoopActions) { $loopNameChoices.Add($la.name) }
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

                            $loopName = Invoke-RecordActionName -Console $Console -ExistingNames $addExistingNames
                            if ($loopName -eq '__cancel__') { break }

                            $newAction = [PSCustomObject]@{
                                type        = 'Loop'
                                iterations  = $loopCount
                                actionNames = $loopActionNames.ToArray()
                            }
                            if (-not [string]::IsNullOrEmpty($loopName)) {
                                $newAction | Add-Member -NotePropertyName 'name' -NotePropertyValue $loopName
                                $addExistingNames.Add($loopName) | Out-Null
                            }
                            $newSteps.Add($newAction)
                            $Console.Write([Spectre.Console.Markup]::new("[green]Loop action added (step $($macroData.sequence.Count + $newSteps.Count)).[/]`n"))
                        }

                        'Done adding steps' {
                            # Append new steps to the existing sequence
                            $combinedList = [System.Collections.Generic.List[PSCustomObject]]::new()
                            foreach ($existingStep in $macroData.sequence) { $combinedList.Add($existingStep) | Out-Null }
                            foreach ($newStep in $newSteps) { $combinedList.Add($newStep) | Out-Null }
                            $macroData.sequence = $combinedList.ToArray()
                            $hasChanges   = $true
                            $addStepsDone = $true

                            # Prompt to save now or return to the edit menu
                            $donePrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                                "$($newSteps.Count) new step(s) added. Save macro now?",
                                @('Save now', 'Return to edit menu')
                            )
                            $doneChoice = $donePrompt.Show($Console)

                            if ($doneChoice -ieq 'Save now') {
                                $macroData.metadata.modifiedUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

                                if ($macroData.metadata.name -ne $originalName) {
                                    $renameResult = Rename-MacroFile -FilePath $FilePath -NewName $macroData.metadata.name
                                    if (-not $renameResult.Success) {
                                        $Console.Write(
                                            [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                                                "[red]Failed to rename macro file: $([Spectre.Console.Markup]::Escape($renameResult.Message))[/]",
                                                'Error'
                                            )
                                        )
                                    } else {
                                        $FilePath = $renameResult.NewFilePath
                                    }
                                }

                                $saveResult = Save-MacroFile -MacroData $macroData -Force
                                if ($saveResult.Success) {
                                    $Console.Write(
                                        [Spectre.Console.Markup]::new("[green]Changes saved successfully.[/]`n")
                                    )
                                    return
                                } else {
                                    $Console.Write(
                                        [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                                            "[red]Failed to save macro: $([Spectre.Console.Markup]::Escape($saveResult.Message))[/]",
                                            'Error'
                                        )
                                    )
                                }
                            }
                            # 'Return to edit menu' — $addStepsDone is already $true; loop will exit
                        }

                        'Discard added steps' {
                            if ($newSteps.Count -eq 0) {
                                $addStepsDone = $true
                            } else {
                                $discardAddedPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                                    "Discard all $($newSteps.Count) new step(s)?",
                                    @('Yes, discard', 'No, continue adding')
                                )
                                $discardAddedChoice = $discardAddedPrompt.Show($Console)
                                if ($discardAddedChoice -ieq 'Yes, discard') {
                                    $addStepsDone = $true
                                }
                                # 'No, continue adding' — $addStepsDone remains $false; loop continues
                            }
                        }
                    }
                }
            }

            'Rename macro' {
                $currentName  = $macroData.metadata.name
                $renamePrompt = [Spectre.Console.TextPrompt[string]]::new(
                    "Current name: $([Spectre.Console.Markup]::Escape($currentName)). Enter new name (or press [[Enter]] to keep current):"
                )
                $renamePrompt.AllowEmpty = $true
                $renameInput = $renamePrompt.Show($Console)

                if ([string]::IsNullOrWhiteSpace($renameInput)) {
                    continue
                }

                # Collect other macro names (excluding current) for uniqueness check
                $otherNames = @(Get-LWASMacro |
                    Where-Object { $_.FilePath -ne $FilePath } |
                    Select-Object -ExpandProperty Name)

                $nameResult = Get-ValidMacroName -Name $renameInput -AutoFix -ExistingNames $otherNames

                if ($nameResult.WasAutoFixed) {
                    $confirmPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                        "Name will be saved as '$([Spectre.Console.Markup]::Escape($nameResult.SanitisedName))'. Use this name?",
                        @(
                            "Use '$([Spectre.Console.Markup]::Escape($nameResult.SanitisedName))'",
                            'Enter a different name'
                        )
                    )
                    $confirmChoice = $confirmPrompt.Show($Console)
                    if ($confirmChoice -ieq 'Enter a different name') {
                        continue
                    }
                }

                if (-not $nameResult.Valid) {
                    $Console.Write(
                        [Spectre.Console.Markup]::new("[red]$([Spectre.Console.Markup]::Escape($nameResult.Message))[/]`n")
                    )
                    continue
                }

                $macroData.metadata.name = $nameResult.SanitisedName
                $hasChanges = $true
            }

            'Edit steps' {
                # ── Step list loop ────────────────────────────────────────────
                while ($true) {
                    $stepChoices = [System.Collections.Generic.List[string]]::new()
                    $stepNum     = 0
                    foreach ($step in $macroData.sequence) {
                        $stepNum++
                        $hasName = $step.PSObject.Properties['name'] -and -not [string]::IsNullOrEmpty($step.name)
                        if ($hasName) {
                            $stepChoices.Add("#${stepNum}: $($step.type) [[$($step.name)]]")
                        } else {
                            $stepChoices.Add("#${stepNum}: $($step.type)")
                        }
                    }
                    $stepChoices.Add('[[Back to edit menu]]')

                    $stepPrompt    = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                        'Select a step to edit:',
                        $stepChoices.ToArray()
                    )
                    $stepSelection = $stepPrompt.Show($Console)

                    if ($stepSelection -ieq '[[Back to edit menu]]') {
                        break
                    }

                    # Parse selected step index from '#N: ' prefix
                    if ($stepSelection -notmatch '^#(\d+): ') {
                        continue
                    }
                    $selectedStepIndex = [int]$Matches[1] - 1
                    $selectedStep      = $macroData.sequence[$selectedStepIndex]
                    $stepCount         = $macroData.sequence.Count

                    # Display step detail
                    $stepHasName = $selectedStep.PSObject.Properties['name'] -and -not [string]::IsNullOrEmpty($selectedStep.name)
                    $stepNameDisplay = if ($stepHasName) { $selectedStep.name } else { '(unnamed)' }
                    $detailText = "Type: $($selectedStep.type)  Name: $([Spectre.Console.Markup]::Escape($stepNameDisplay))  Details: $([Spectre.Console.Markup]::Escape((Get-MacroActionDetailString -Action $selectedStep)))"
                    $Console.Write(
                        [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel($detailText, "Step $([int]$selectedStepIndex + 1)")
                    )

                    # Build step options
                    $stepOptChoices = [System.Collections.Generic.List[string]]::new()
                    if ($stepHasName) {
                        $stepOptChoices.Add('Rename step')
                    } else {
                        $stepOptChoices.Add('Add name to step')
                    }
                    if ($selectedStepIndex -gt 0) {
                        $stepOptChoices.Add('Move up')
                    }
                    if ($selectedStepIndex -lt ($stepCount - 1)) {
                        $stepOptChoices.Add('Move down')
                    }
                    $stepOptChoices.Add('[[Back to step list]]')

                    $stepOptPrompt    = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                        'What would you like to do with this step?',
                        $stepOptChoices.ToArray()
                    )
                    $stepOptSelection = $stepOptPrompt.Show($Console)

                    if ($stepOptSelection -ieq '[[Back to step list]]') {
                        continue
                    }

                    switch ($stepOptSelection) {

                        { $_ -ieq 'Rename step' -or $_ -ieq 'Add name to step' } {
                            if ($stepHasName) {
                                $stepNamePrompt = [Spectre.Console.TextPrompt[string]]::new(
                                    "Current name: $([Spectre.Console.Markup]::Escape($selectedStep.name)). Enter new name (or press [[Enter]] to keep current):"
                                )
                            } else {
                                $stepNamePrompt = [Spectre.Console.TextPrompt[string]]::new(
                                    'Enter a name for this step (or press [[Enter]] to skip):'
                                )
                            }
                            $stepNamePrompt.AllowEmpty = $true
                            $stepNameInput = $stepNamePrompt.Show($Console)

                            if ([string]::IsNullOrWhiteSpace($stepNameInput)) {
                                continue
                            }

                            # Collect other named action names (excluding current step)
                            $currentStepName = if ($stepHasName) { $selectedStep.name } else { $null }
                            $otherStepNames  = @($macroData.sequence | Where-Object {
                                $_.PSObject.Properties['name'] -and
                                -not [string]::IsNullOrEmpty($_.name) -and
                                $_.name -ne $currentStepName
                            } | Select-Object -ExpandProperty name)

                            $stepNameResult = Get-ValidMacroName -Name $stepNameInput -AutoFix -ExistingNames $otherStepNames

                            if (-not $stepNameResult.Valid) {
                                $Console.Write(
                                    [Spectre.Console.Markup]::new("[red]$([Spectre.Console.Markup]::Escape($stepNameResult.Message))[/]`n")
                                )
                                continue
                            }

                            $oldStepName = $currentStepName
                            if ($stepHasName) {
                                $selectedStep.name = $stepNameResult.SanitisedName
                            } else {
                                $selectedStep | Add-Member -MemberType NoteProperty -Name 'name' -Value $stepNameResult.SanitisedName -Force
                            }

                            # Update any Loop actions that referenced the old name
                            if (-not [string]::IsNullOrEmpty($oldStepName)) {
                                foreach ($loopAction in ($macroData.sequence | Where-Object { $_.type -eq 'Loop' })) {
                                    if ($loopAction.actionNames -contains $oldStepName) {
                                        $loopAction.actionNames = @($loopAction.actionNames | ForEach-Object {
                                            if ($_ -eq $oldStepName) { $stepNameResult.SanitisedName } else { $_ }
                                        })
                                        $loopDisplayName = if ($loopAction.PSObject.Properties['name'] -and -not [string]::IsNullOrEmpty($loopAction.name)) {
                                            $loopAction.name
                                        } else { 'unnamed loop' }
                                        $Console.Write(
                                            [Spectre.Console.Markup]::new("[grey]Updated loop '$([Spectre.Console.Markup]::Escape($loopDisplayName))' to reference new step name.[/]`n")
                                        )
                                    }
                                }
                            }

                            $hasChanges = $true
                            # Continue step list loop (re-display with updated name)
                            continue
                        }

                        'Move up' {
                            $seq  = $macroData.sequence
                            $temp = $seq[$selectedStepIndex]
                            $seq[$selectedStepIndex]     = $seq[$selectedStepIndex - 1]
                            $seq[$selectedStepIndex - 1] = $temp
                            $hasChanges = $true
                            continue
                        }

                        'Move down' {
                            $seq  = $macroData.sequence
                            $temp = $seq[$selectedStepIndex]
                            $seq[$selectedStepIndex]     = $seq[$selectedStepIndex + 1]
                            $seq[$selectedStepIndex + 1] = $temp
                            $hasChanges = $true
                            continue
                        }
                    }
                }
            }

            'Save changes' {
                $macroData.metadata.modifiedUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

                if ($macroData.metadata.name -ne $originalName) {
                    $renameResult = Rename-MacroFile -FilePath $FilePath -NewName $macroData.metadata.name
                    if (-not $renameResult.Success) {
                        $Console.Write(
                            [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                                "[red]Failed to rename macro file: $([Spectre.Console.Markup]::Escape($renameResult.Message))[/]",
                                'Error'
                            )
                        )
                        continue
                    }
                    $FilePath = $renameResult.NewFilePath
                }

                $saveResult = Save-MacroFile -MacroData $macroData -Force
                if ($saveResult.Success) {
                    $Console.Write(
                        [Spectre.Console.Markup]::new("[green]Changes saved successfully.[/]`n")
                    )
                    return
                } else {
                    $Console.Write(
                        [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                            "[red]Failed to save macro: $([Spectre.Console.Markup]::Escape($saveResult.Message))[/]",
                            'Error'
                        )
                    )
                    continue
                }
            }

            'Discard changes' {
                $discardPrompt  = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                    'Discard all unsaved changes?',
                    @('Yes, discard', 'No, keep editing')
                )
                $discardChoice  = $discardPrompt.Show($Console)
                if ($discardChoice -ieq 'Yes, discard') {
                    return
                }
                # 'No, keep editing' — fall through to continue loop
            }

            default {
                # '[Back]' (only shown when no changes)
                return
            }
        }
    }
}
