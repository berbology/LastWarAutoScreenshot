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
        Displays the Edit Macro screen, allowing the user to rename the macro, rename or
        reorder steps, and save or discard changes.

    .DESCRIPTION
        Loads the macro at the given file path via Get-MacroFile, then enters an interactive
        loop presenting a dynamic SelectionPrompt.

        The available options depend on whether unsaved changes exist:
          - Always shown:              'Rename macro', 'Edit steps'
          - Shown only with changes:   'Save changes', 'Discard changes'
          - Shown only without changes:'[[Back]]'

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
        $macroList = Get-MacroFileList
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
                $otherNames = @(Get-MacroFileList |
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
