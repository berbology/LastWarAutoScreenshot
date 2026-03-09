function Show-ManageMacrosScreen {
    <#
    .SYNOPSIS
        Displays the Manage Macros screen, allowing the user to view, edit, and delete saved macros.

    .DESCRIPTION
        Presents a list of all saved macros (from Get-MacroFileList) and lets the user choose one
        to manage.  For the selected macro the user can:
          - View details: displays a metadata table and the full action sequence table, then waits
            for the user to press Enter before returning to the management options.
          - Edit macro:   dispatches to Show-EditMacroScreen and then refreshes the macro list.
          - Delete macro: prompts for confirmation, then calls Remove-MacroFile.
          - Back to macro list: returns to the macro selection list.

        When no macros are saved, an informational panel is displayed and the function returns $null.

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for all rendering and input.
        Pass [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole() for production use,
        or a [Spectre.Console.Testing.TestConsole]::new() instance in Pester tests.

    .OUTPUTS
        None.  Always returns $null.

    .EXAMPLE
        $console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        Show-ManageMacrosScreen -Console $console

    .NOTES
        The $Console parameter is the testability injection point.  All rendering and input is
        routed through this interface so Pester tests can inject a TestConsole and assert on its
        Output property without requiring a live terminal.

        The macro list is refreshed at the start of every outer loop iteration so that deletions
        and renames performed by Show-EditMacroScreen are reflected immediately.

        Action detail formatting is handled by an inline scriptblock ($getActionDetail) to keep
        the function self-contained without introducing an extra exported helper.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    # ── Inline helper: format one action's key parameters as a short string ───
    $getActionDetail = {
        param($action)
        switch ($action.type) {
            'MoveToPoint' {
                "($($action.position.relativeX), $($action.position.relativeY))"
            }
            'MoveToRegion' {
                if ($action.region.type -eq 'Circle') {
                    "Circle ($($action.region.relativeCentreX), $($action.region.relativeCentreY)) r=$($action.region.relativeRadius)"
                } else {
                    "Box ($($action.region.relativeX), $($action.region.relativeY)) $($action.region.relativeWidth)x$($action.region.relativeHeight)"
                }
            }
            'LeftClick'   { '(current position)' }
            'DragClick'   {
                "($($action.start.relativeX), $($action.start.relativeY)) to ($($action.end.relativeX), $($action.end.relativeY))"
            }
            'Screenshot'  {
                "($($action.region.topLeft.relativeX), $($action.region.topLeft.relativeY)) to ($($action.region.bottomRight.relativeX), $($action.region.bottomRight.relativeY))"
            }
            'Delay'       { "$($action.seconds)s" }
            'Loop'        { "$($action.iterations)x: $($action.actionNames -join ', ')" }
            default       { '' }
        }
    }

    # ── Outer loop: rebuild macro list on each iteration ─────────────────────
    while ($true) {
        $macroList = Get-MacroFileList

        if ($macroList.Count -eq 0) {
            $noMacrosPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'No macros saved yet. Record a macro from the main menu to get started.',
                'Manage Macros'
            )
            $Console.Write($noMacrosPanel)
            return $null
        }

        # Build macro selection prompt
        $macroChoices = [System.Collections.Generic.List[string]]::new()
        $macroChoices.Add('[[Back to main menu]]')
        foreach ($macro in $macroList) {
            $macroChoices.Add("$($macro.Name) ($($macro.DisplayDate))")
        }

        $macroPrompt    = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
            'Select a macro to manage:',
            $macroChoices.ToArray()
        )
        $macroSelection = $macroPrompt.Show($Console)

        if ($macroSelection -ieq '[[Back to main menu]]') {
            return $null
        }

        # Locate the selected macro object
        $selectedMacro = $macroList |
            Where-Object { "$($_.Name) ($($_.DisplayDate))" -eq $macroSelection } |
            Select-Object -First 1

        if ($null -eq $selectedMacro) {
            return $null
        }

        # ── Inner loop: management options for the selected macro ─────────────
        $stayOnMacro = $true
        while ($stayOnMacro) {
            $escapedName = [Spectre.Console.Markup]::Escape($selectedMacro.Name)

            $mgmtPrompt    = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                "Macro: $escapedName",
                @('View details', 'Edit macro', 'Delete macro', '[[Back to macro list]]')
            )
            $mgmtSelection = $mgmtPrompt.Show($Console)

            if ($mgmtSelection -ieq '[[Back to macro list]]') {
                $stayOnMacro = $false
                continue
            }

            switch ($mgmtSelection) {

                'View details' {
                    $macroResult = Get-MacroFile -FilePath $selectedMacro.FilePath
                    if ($null -eq $macroResult) {
                        $errPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                            'Failed to load the macro file. It may have been moved or corrupted.',
                            'Error'
                        )
                        $Console.Write($errPanel)
                    } else {
                        $data = $macroResult.Data

                        # Metadata table
                        $metaTable = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(@('Property', 'Value'))
                        [Spectre.Console.TableExtensions]::AddRow(
                            $metaTable,
                            [string[]]@('Name', [Spectre.Console.Markup]::Escape($data.metadata.name))
                        ) | Out-Null
                        $createdLocal  = [datetime]::Parse($data.metadata.createdUtc).ToLocalTime().ToString('dd/MM/yyyy HH:mm:ss')
                        $modifiedLocal = [datetime]::Parse($data.metadata.modifiedUtc).ToLocalTime().ToString('dd/MM/yyyy HH:mm:ss')
                        [Spectre.Console.TableExtensions]::AddRow(
                            $metaTable,
                            [string[]]@('Created', $createdLocal)
                        ) | Out-Null
                        [Spectre.Console.TableExtensions]::AddRow(
                            $metaTable,
                            [string[]]@('Modified', $modifiedLocal)
                        ) | Out-Null
                        [Spectre.Console.TableExtensions]::AddRow(
                            $metaTable,
                            [string[]]@('Action count', $data.sequence.Count.ToString())
                        ) | Out-Null
                        $targetStr = "$([Spectre.Console.Markup]::Escape($data.targetWindow.processName)) - $([Spectre.Console.Markup]::Escape($data.targetWindow.windowTitle))"
                        [Spectre.Console.TableExtensions]::AddRow(
                            $metaTable,
                            [string[]]@('Target window', $targetStr)
                        ) | Out-Null
                        $Console.Write($metaTable)

                        # Sequence table
                        $seqTable = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(@('#', 'Type', 'Name', 'Details'))
                        $rowNum   = 1
                        foreach ($action in $data.sequence) {
                            $actionName = if ($action.PSObject.Properties['name'] -and -not [string]::IsNullOrEmpty($action.name)) {
                                [Spectre.Console.Markup]::Escape($action.name)
                            } else {
                                ''
                            }
                            $details = & $getActionDetail $action
                            [Spectre.Console.TableExtensions]::AddRow(
                                $seqTable,
                                [string[]]@($rowNum.ToString(), $action.type, $actionName, $details)
                            ) | Out-Null
                            $rowNum++
                        }
                        $Console.Write($seqTable)

                        # Acknowledge prompt
                        $ackPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateEmptyTextPrompt('Press [[Enter]] to return...')
                        $ackPrompt.Show($Console) | Out-Null
                    }
                }

                'Edit macro' {
                    Show-EditMacroScreen -Console $Console -FilePath $selectedMacro.FilePath
                    $stayOnMacro = $false
                }

                'Delete macro' {
                    $deletePrompt  = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                        "Are you sure you want to delete macro '$escapedName'? This cannot be undone.",
                        @('Yes, delete', 'No, keep it')
                    )
                    $deleteConfirm = $deletePrompt.Show($Console)

                    if ($deleteConfirm -ieq 'Yes, delete') {
                        $deleted = Remove-MacroFile -FilePath $selectedMacro.FilePath
                        if ($deleted) {
                            $Console.Write([Spectre.Console.Markup]::new("[green]Macro '$escapedName' deleted.[/]`n"))
                        } else {
                            $errPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                                'Failed to delete the macro file. See the log for details.',
                                'Error'
                            )
                            $Console.Write($errPanel)
                        }
                        $stayOnMacro = $false
                    }
                    # 'No, keep it': $stayOnMacro stays $true — management options loop continues
                }
            }
        }
    }
}
