function Show-ScheduleScreen {
    <#
    .SYNOPSIS
        Displays the Manage Schedules screen, allowing the user to view, create, and remove
        Windows Scheduled Tasks that run LWAS macros.

    .DESCRIPTION
        Presents a table of all LWAS scheduled tasks (from Get-LWASScheduledTask) and
        offers two actions:

          Create new schedule — interactive wizard collecting:
            1. Macro name (from saved macros)
            2. Target process name
            3. Start date and time (dd/MM/yyyy HH:mm; must be in the future)
            4. Repeat interval (preset or custom hours + minutes; minimum 1 minute)
            5. Repeat duration (indefinitely or until a specific date)
            6. Random delay in minutes (0–120)
            A summary panel is shown before final confirmation.  On confirm,
            Register-LWASScheduledTask is called and a result panel is displayed.

          Remove a schedule — lists existing tasks; user selects one, confirms removal,
            and Unregister-LWASScheduledTask is called.

        Loops back to the action selection prompt until 'Back to main menu' is chosen.
        When no tasks exist, an info panel replaces the task table.

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for all rendering and input.
        Pass [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole() for production use,
        or a [Spectre.Console.Testing.TestConsole]::new() instance in Pester tests.

    .OUTPUTS
        None.  Always returns $null.

    .EXAMPLE
        $console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        Show-ScheduleScreen -Console $console

    .NOTES
        The $Console parameter is the testability injection point.  All rendering and input
        is routed through this interface so Pester tests can inject a TestConsole and assert
        on its Output property without requiring a live terminal.

        The task list is refreshed on every outer loop iteration so that creations and
        removals are reflected immediately on return to the action prompt.

        All error paths log via Write-LastWarLog at the appropriate level.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    while ($true) {

        # ── Display current task list ─────────────────────────────────────────
        $tasks = @(Get-LWASScheduledTask -ErrorAction SilentlyContinue)

        if ($tasks.Count -eq 0) {
            $infoPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                "No schedules configured. Select 'Create new schedule' to add one.",
                'Manage Schedules'
            )
            $Console.Write($infoPanel) | Out-Null
        } else {
            $taskTable = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(
                @('Task Name', 'Macro', 'Next Run', 'Last Run', 'Last Result')
            )
            foreach ($task in $tasks) {
                $nextRun    = if ($null -ne $task.NextRunTime)    { $task.NextRunTime.ToString('dd/MM/yyyy HH:mm')  } else { 'N/A'   }
                $lastRun    = if ($null -ne $task.LastRunTime)    { $task.LastRunTime.ToString('dd/MM/yyyy HH:mm')  } else { 'Never' }
                $lastResult = if ($null -ne $task.LastTaskResult) { [string]$task.LastTaskResult                    } else { 'N/A'   }
                [Spectre.Console.TableExtensions]::AddRow($taskTable, [string[]]@(
                    [Spectre.Console.Markup]::Escape($task.TaskName),
                    [Spectre.Console.Markup]::Escape($task.MacroName),
                    $nextRun,
                    $lastRun,
                    $lastResult
                )) | Out-Null
            }
            $Console.Write($taskTable) | Out-Null
        }

        # ── Action selection ──────────────────────────────────────────────────
        $actionPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
            'What would you like to do?',
            @('Create new schedule', 'Remove a schedule', '[[Back to main menu]]')
        )
        $action = $actionPrompt.Show($Console)

        if ($action -ieq '[[Back to main menu]]') {
            return $null
        }

        switch ($action) {

            # ================================================================
            'Create new schedule' {

                # ── Step 1: Select macro ───────────────────────────────────
                $macroList = @(Get-LWASMacro)
                if ($macroList.Count -eq 0) {
                    $noMacroPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                        'No macros recorded yet. Record a macro first before creating a schedule.',
                        '[yellow]No Macros Available[/]'
                    )
                    $Console.Write($noMacroPanel) | Out-Null
                    continue
                }

                $macroChoices = [System.Collections.Generic.List[string]]::new()
                foreach ($m in $macroList) {
                    $macroChoices.Add([Spectre.Console.Markup]::Escape($m.Name))
                }
                $macroChoices.Add('[[Back]]')

                $macroPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                    'Select macro:', $macroChoices.ToArray()
                )
                $selectedMacroName = $macroPrompt.Show($Console)
                if ($selectedMacroName -ieq '[[Back]]') {
                    continue
                }

                # ── Step 2: Target process name ────────────────────────────
                $processName = $null
                while ($null -eq $processName) {
                    $processPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateEmptyTextPrompt(
                        'Target process name (e.g. lastwar.exe):'
                    )
                    $processInput = $processPrompt.Show($Console)
                    if ([string]::IsNullOrWhiteSpace($processInput)) {
                        $Console.Write([Spectre.Console.Markup]::new(
                            "[red]Process name cannot be empty.[/]`n"
                        )) | Out-Null
                    } else {
                        $processName = $processInput.Trim()
                    }
                }

                # ── Step 3: Start date and time ────────────────────────────
                $startAt = $null
                while ($null -eq $startAt) {
                    $datePrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateEmptyTextPrompt(
                        'Start date and time (dd/MM/yyyy HH:mm):'
                    )
                    $dateInput  = $datePrompt.Show($Console)
                    $parsedDate = [datetime]::MinValue
                    $parseOk    = $false
                    try {
                        $parsedDate = [datetime]::ParseExact($dateInput, 'dd/MM/yyyy HH:mm', $null)
                        $parseOk    = $true
                    } catch {
                        $parseOk = $false
                    }
                    if (-not $parseOk) {
                        $Console.Write([Spectre.Console.Markup]::new(
                            "[red]Invalid date format. Use dd/MM/yyyy HH:mm (e.g. 25/12/2026 09:00).[/]`n"
                        )) | Out-Null
                    } elseif ($parsedDate -le [datetime]::Now) {
                        $Console.Write([Spectre.Console.Markup]::new(
                            "[red]Start date must be in the future.[/]`n"
                        )) | Out-Null
                    } else {
                        $startAt = $parsedDate
                    }
                }

                # ── Step 4: Repeat interval ────────────────────────────────
                $repeatPresetLabels = @(
                    'Never',
                    '15 minutes', '30 minutes', '45 minutes',
                    '1 hour', '2 hours', '4 hours', '6 hours', '12 hours', '24 hours',
                    'Custom'
                )
                $repeatIntervalPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                    'Repeat every:', $repeatPresetLabels
                )
                $repeatChoice = $repeatIntervalPrompt.Show($Console)

                $repeatEvery = $null
                if ($repeatChoice -eq 'Custom') {
                    while ($null -eq $repeatEvery) {
                        # Hours sub-prompt
                        $customHours = $null
                        while ($null -eq $customHours) {
                            $hoursPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateEmptyTextPrompt(
                                'Hours (0 or more):'
                            )
                            $hoursInput = $hoursPrompt.Show($Console)
                            $hoursInt   = 0
                            if ([int]::TryParse($hoursInput, [ref]$hoursInt) -and $hoursInt -ge 0) {
                                $customHours = $hoursInt
                            } else {
                                $Console.Write([Spectre.Console.Markup]::new(
                                    "[red]Hours must be a whole number 0 or greater.[/]`n"
                                )) | Out-Null
                            }
                        }

                        # Minutes sub-prompt
                        $customMinutes = $null
                        while ($null -eq $customMinutes) {
                            $minutesPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateEmptyTextPrompt(
                                'Minutes (0-59):'
                            )
                            $minutesInput = $minutesPrompt.Show($Console)
                            $minutesInt   = 0
                            if ([int]::TryParse($minutesInput, [ref]$minutesInt) -and $minutesInt -ge 0 -and $minutesInt -le 59) {
                                $customMinutes = $minutesInt
                            } else {
                                $Console.Write([Spectre.Console.Markup]::new(
                                    "[red]Minutes must be a whole number between 0 and 59.[/]`n"
                                )) | Out-Null
                            }
                        }

                        $totalMinutes = ($customHours * 60) + $customMinutes
                        if ($totalMinutes -lt 1) {
                            $Console.Write([Spectre.Console.Markup]::new(
                                "[red]Interval must be at least 1 minute.[/]`n"
                            )) | Out-Null
                            # $repeatEvery stays $null → outer while re-prompts both fields
                        } else {
                            $repeatEvery = [TimeSpan]::FromMinutes($totalMinutes)
                        }
                    }
                } else {
                    $repeatEvery = switch ($repeatChoice) {
                        'Never'      { $null                        }
                        '15 minutes' { [TimeSpan]::FromMinutes(15)  }
                        '30 minutes' { [TimeSpan]::FromMinutes(30)  }
                        '45 minutes' { [TimeSpan]::FromMinutes(45)  }
                        '1 hour'     { [TimeSpan]::FromHours(1)     }
                        '2 hours'    { [TimeSpan]::FromHours(2)     }
                        '4 hours'    { [TimeSpan]::FromHours(4)     }
                        '6 hours'    { [TimeSpan]::FromHours(6)     }
                        '12 hours'   { [TimeSpan]::FromHours(12)    }
                        '24 hours'   { [TimeSpan]::FromHours(24)    }
                        default      { [TimeSpan]::FromHours(6)     }
                    }
                }

                # ── Step 5: Repeat duration (skipped when not repeating) ───
                $repeatFor = [TimeSpan]::MaxValue
                $expiresAt = $null

                if ($repeatChoice -ne 'Never') {
                    $durationPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                        'Repeat duration:',
                        @('Indefinitely', 'Until a specific date')
                    )
                    $durationChoice = $durationPrompt.Show($Console)
                } else {
                    $durationChoice = 'Indefinitely'
                }

                if ($durationChoice -eq 'Until a specific date') {
                    $expiryDate = $null
                    while ($null -eq $expiryDate) {
                        $expiryPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateEmptyTextPrompt(
                            'Expiry date (dd/MM/yyyy):'
                        )
                        $expiryInput  = $expiryPrompt.Show($Console)
                        $parsedExpiry = [datetime]::MinValue
                        $expiryOk     = $false
                        try {
                            $parsedExpiry = [datetime]::ParseExact($expiryInput, 'dd/MM/yyyy', $null)
                            $expiryOk     = $true
                        } catch {
                            $expiryOk = $false
                        }
                        if (-not $expiryOk) {
                            $Console.Write([Spectre.Console.Markup]::new(
                                "[red]Invalid date format. Use dd/MM/yyyy (e.g. 25/12/2026).[/]`n"
                            )) | Out-Null
                        } elseif ($parsedExpiry -le $startAt) {
                            $Console.Write([Spectre.Console.Markup]::new(
                                "[red]Expiry date must be after the start date.[/]`n"
                            )) | Out-Null
                        } else {
                            $expiryDate = $parsedExpiry
                        }
                    }
                    $expiresAt = $expiryDate
                    $repeatFor = $expiresAt - $startAt
                }

                # ── Step 6: Random delay ───────────────────────────────────
                $randomDelay = $null
                while ($null -eq $randomDelay) {
                    $delayPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateEmptyTextPrompt(
                        'Random delay before start (0-120 minutes, 0 = no delay) [[0]]:'
                    )
                    $delayInput = $delayPrompt.Show($Console)
                    if ([string]::IsNullOrWhiteSpace($delayInput)) {
                        $delayInput = '0'
                    }
                    $delayInt = 0
                    if ([int]::TryParse($delayInput, [ref]$delayInt) -and $delayInt -ge 0 -and $delayInt -le 120) {
                        $randomDelay = $delayInt
                    } else {
                        $Console.Write([Spectre.Console.Markup]::new(
                            "[red]Random delay must be a whole number between 0 and 120.[/]`n"
                        )) | Out-Null
                    }
                }

                # ── Step 7: Summary and confirm ────────────────────────────
                $durationStr = if ($null -ne $expiresAt) { $expiresAt.ToString('dd/MM/yyyy') } else { 'Indefinitely' }
                $summaryContent = @"
Macro    : $selectedMacroName
Process  : $processName
Start    : $($startAt.ToString('dd/MM/yyyy HH:mm'))
Repeat   : $repeatChoice
Duration : $durationStr
Delay    : $randomDelay minutes
"@
                $summaryPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                    $summaryContent, 'Schedule Summary'
                )
                $Console.Write($summaryPanel) | Out-Null

                $confirmCreatePrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                    'Confirm?',
                    @('Yes - create schedule', 'No - go back')
                )
                $confirmCreate = $confirmCreatePrompt.Show($Console)

                if ($confirmCreate -ieq 'No - go back') {
                    continue
                }

                # ── Register the task ──────────────────────────────────────
                $regParams = @{
                    MacroName   = $selectedMacroName
                    ProcessName = $processName
                    StartAt     = $startAt
                }
                if ($null -ne $repeatEvery) {
                    $regParams['RepeatEvery'] = $repeatEvery
                }
                if ($null -ne $expiresAt) {
                    $regParams['ExpiresAt'] = $expiresAt
                }
                if ($randomDelay -gt 0) {
                    $regParams['RandomDelayMinutes'] = $randomDelay
                }

                try {
                    $regResult    = Register-LWASScheduledTask @regParams
                    $resultContent = "Schedule created successfully.`nTask: $($regResult.TaskName)`nLauncher: $($regResult.LauncherPath)"
                    $resultPanel   = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                        $resultContent, '[green]Schedule Created[/]'
                    )
                    $Console.Write($resultPanel) | Out-Null
                    Write-LastWarLog -Level Info -FunctionName 'Show-ScheduleScreen' `
                        -Message "Created schedule '$($regResult.TaskName)' for macro '$selectedMacroName' via UI."
                } catch {
                    $errMsg  = [Spectre.Console.Markup]::Escape($_.ToString())
                    $errPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                        $errMsg, '[red]Error Creating Schedule[/]'
                    )
                    $Console.Write($errPanel) | Out-Null
                    Write-LastWarLog -Level Error -FunctionName 'Show-ScheduleScreen' `
                        -Message "Failed to create schedule for macro '$selectedMacroName': $_"
                }
            }

            # ================================================================
            'Remove a schedule' {

                if ($tasks.Count -eq 0) {
                    continue
                }

                $removeChoices = [System.Collections.Generic.List[string]]::new()
                foreach ($task in $tasks) {
                    $removeChoices.Add($task.TaskName)
                }
                $removeChoices.Add('[[Back]]')

                $removePrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                    'Select a schedule to remove:',
                    $removeChoices.ToArray()
                )
                $selectedTask = $removePrompt.Show($Console)

                if ($selectedTask -ieq '[[Back]]') {
                    continue
                }

                $escapedTask = [Spectre.Console.Markup]::Escape($selectedTask)
                $confirmRemovePrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                    "Remove schedule '$escapedTask'?",
                    @('Yes - remove', 'No - go back')
                )
                $confirmRemove = $confirmRemovePrompt.Show($Console)

                if ($confirmRemove -ieq 'No - go back') {
                    continue
                }

                $macroNameToRemove = $selectedTask -replace '^LWAS_', ''
                try {
                    Unregister-LWASScheduledTask -MacroName $macroNameToRemove -Force
                    $removedPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                        "Schedule '$escapedTask' removed successfully.", 'Schedule Removed'
                    )
                    $Console.Write($removedPanel) | Out-Null
                    Write-LastWarLog -Level Info -FunctionName 'Show-ScheduleScreen' `
                        -Message "Removed schedule '$selectedTask' via UI."
                } catch {
                    $errMsg   = [Spectre.Console.Markup]::Escape($_.ToString())
                    $errPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                        $errMsg, '[red]Error Removing Schedule[/]'
                    )
                    $Console.Write($errPanel) | Out-Null
                    Write-LastWarLog -Level Error -FunctionName 'Show-ScheduleScreen' `
                        -Message "Failed to remove schedule '$selectedTask': $_"
                }
            }
        }
    }
}
