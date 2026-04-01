function Show-RunMacroScreen {
    <#
    .SYNOPSIS
        Displays the Run Macro screen, allowing the user to select and execute a saved macro.

    .DESCRIPTION
        Guides the user through five steps to run a saved macro:

        1.  List and select macro - shows all saved macros; user picks one or goes back.
        2.  Load and validate macro - reads the macro file and checks schema validity.
        3.  Display macro summary - shows metadata panel and full action sequence table.
        4.  Validate target window - locates the window using the processName and windowTitle
            stored in the macro file via Get-LWASTargetWindow.  If no matching window is
            found an error panel is shown and the screen loops back to step 1.  Also runs a
            pre-flight check: if the macro contains Screenshot actions and no storage
            path is configured, a warning panel is shown and the user may continue
            (screenshots will be skipped) or cancel (returns to the macro list).
        5.  Confirm and execute - user confirms, macro runs via Invoke-MacroSequence,
            and results are displayed.

        On any recoverable error (load failure, validation failure, window not found), the
        screen loops back to step 1 so the user can choose a different macro or navigate
        away. Returns $null in all exit paths (back navigation or after execution).

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for all rendering and input.
        Pass [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole() for production use,
        or a [Spectre.Console.Testing.TestConsole]::new() instance in Pester tests.

    .OUTPUTS
        None

    .EXAMPLE
        $console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        Show-RunMacroScreen -Console $console

    .NOTES
        The $Console parameter is the testability injection point.  All rendering and input
        is routed through this interface so Pester tests can inject a TestConsole and assert
        on its Output property without requiring a live terminal.

        Target window lookup: Get-LWASTargetWindow is called with the processName and
        windowTitle from the macro file and -First to select the first match.  A
        try/catch with -ErrorAction Stop converts Write-Error calls to terminating errors;
        any failure results in the window-not-found error panel.

        Emergency stop detection: after Invoke-MacroSequence returns,
        $script:EmergencyStopRequested is checked to distinguish an emergency-stop halt
        from a regular execution failure.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    while ($true) {

        # ── Step 1: List and select macro ─────────────────────────────────────────
        $macroList = @(Get-LWASMacro)

        if ($macroList.Count -eq 0) {
            $emptyPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'No macros saved yet. Record a macro from the main menu to get started.',
                'Run Macro'
            )
            $Console.Write($emptyPanel)
            return $null
        }

        $displayStrings = @()
        foreach ($m in $macroList) {
            $displayStrings += "$([Spectre.Console.Markup]::Escape($m.Name)) ($([Spectre.Console.Markup]::Escape($m.DisplayDate)))"
        }
        $selectPrompt    = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
            'Select a macro to run:',
            [string[]]($displayStrings + @('[[Back to main menu]]'))
        )
        $selectedDisplay = $selectPrompt.Show($Console)

        if ($selectedDisplay -ieq '[[Back to main menu]]') {
            return $null
        }

        # Correlate selected display string back to the macro list entry
        $selectedMacro = $null
        for ($i = 0; $i -lt $macroList.Count; $i++) {
            if ($selectedDisplay -eq $displayStrings[$i]) {
                $selectedMacro = $macroList[$i]
                break
            }
        }

        if ($null -eq $selectedMacro) {
            Write-LastWarLog -Level Error `
                -Message "Could not correlate selected display string to a macro list entry. Choice: '$selectedDisplay'" `
                -FunctionName 'Show-RunMacroScreen'
            continue
        }

        # ── Step 2: Load and validate macro ──────────────────────────────────────
        $macro = Get-MacroFile -FilePath $selectedMacro.FilePath

        if ($null -eq $macro) {
            $loadErrorPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'Failed to load macro file.',
                '[red]Error[/]'
            )
            $Console.Write($loadErrorPanel)
            continue
        }

        if (-not $macro.Valid) {
            $validationMessages = $macro.Messages -join "`n"
            $validationPanel    = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                $validationMessages,
                '[red]Macro Validation Failed[/]'
            )
            $Console.Write($validationPanel)
            continue
        }

        # ── Step 3: Display macro summary ─────────────────────────────────────────
        $actionCount = if ($macro.Data.sequence) { $macro.Data.sequence.Count } else { 0 }
        $metaContent = "Name:    $($macro.Data.metadata.name)`nCreated: $($macro.Data.metadata.createdUtc)`nActions: $actionCount`nProcess: $($macro.Data.targetWindow.processName)`nWindow:  $($macro.Data.targetWindow.windowTitle)"
        $metaPanel   = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
            $metaContent,
            'Macro Details'
        )
        $Console.Write($metaPanel)

        $seqTable  = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(@('#', 'Type', 'Name', 'Details'))
        $stepIndex = 0
        foreach ($action in $macro.Data.sequence) {
            $stepIndex++
            $actionName    = if ($action.PSObject.Properties['name'] -and -not [string]::IsNullOrEmpty($action.name)) { $action.name } else { '' }
            $actionDetails = switch ($action.type) {
                'MoveToPoint'  { "($($action.position.relativeX), $($action.position.relativeY))" }
                'MoveToRegion' {
                    if ($action.region.type -eq 'Box') {
                        "Box at ($($action.region.relativeX), $($action.region.relativeY)) size ($($action.region.relativeWidth) x $($action.region.relativeHeight))"
                    } else {
                        "Circle at ($($action.region.relativeCentreX), $($action.region.relativeCentreY)) r=$($action.region.relativeRadius)"
                    }
                }
                'LeftClick'    { 'Click at current position' }
                'DragClick'    { "($($action.start.relativeX), $($action.start.relativeY)) -> ($($action.end.relativeX), $($action.end.relativeY))" }
                'Screenshot'   { "($($action.region.topLeft.relativeX), $($action.region.topLeft.relativeY)) -> ($($action.region.bottomRight.relativeX), $($action.region.bottomRight.relativeY)) [deferred]" }
                'Delay'        { "$($action.seconds) seconds" }
                'Loop'         { "$($action.actionNames -join ' -> ') x $($action.iterations)" }
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

        # ── Step 4: Validate target window ────────────────────────────────────────
        $windowHandle = $null

        try {
            $targetWindow = Get-LWASTargetWindow `
                -ProcessName $macro.Data.targetWindow.processName `
                -WindowTitle $macro.Data.targetWindow.windowTitle `
                -First `
                -ErrorAction Stop
            $windowHandle = $targetWindow.WindowHandle
        } catch {
            Write-LastWarLog -Level Warning `
                -Message "Get-LWASTargetWindow threw an exception in Show-RunMacroScreen: $_" `
                -FunctionName 'Show-RunMacroScreen'
        }

        if ($null -eq $windowHandle) {
            $windowErrorPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                "Target window is not open. The window for process '$($macro.Data.targetWindow.processName)' could not be found.",
                '[red]Error[/]'
            )
            $Console.Write($windowErrorPanel)
            continue
        }

        # ── Pre-flight: Screenshot storage check ──────────────────────────────────
        $hasScreenshots = @($macro.Data.sequence | Where-Object { $_.type -eq 'Screenshot' }).Count -gt 0
        $storageConfig = $null
        try { $storageConfig = Get-ModuleConfiguration } catch {}
        $storagePathConfigured = (
            $null -ne $storageConfig -and
            $null -ne $storageConfig.Screenshots -and
            -not [string]::IsNullOrEmpty($storageConfig.Screenshots.StoragePath)
        )

        if ($hasScreenshots -and -not $storagePathConfigured) {
            $screenshotWarningPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'This macro contains screenshot actions but no screenshot storage path is configured. Screenshots will be skipped during execution, and no files will be saved. Configure a storage path via Configure Module → Screenshot settings to enable screenshot capture.',
                '[yellow]Warning: Screenshot Storage Not Configured[/]'
            )
            $Console.Write($screenshotWarningPanel)

            $screenshotPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                'How would you like to proceed?',
                @('Continue (screenshots will be skipped)', 'Cancel')
            )
            $screenshotChoice = $screenshotPrompt.Show($Console)
            if ($screenshotChoice -ieq 'Cancel') {
                continue
            }
        }

        # ── Pre-flight: SAS token check for UploadScreenshots actions ────────────
        $uploadActions = @($macro.Data.sequence | Where-Object { $_.type -eq 'UploadScreenshots' })
        if ($uploadActions.Count -gt 0) {
            $sasTokensReady      = $true
            $uniqueProfileNames  = @($uploadActions | ForEach-Object { $_.uploadProfileName } | Sort-Object -Unique)
            foreach ($profileName in $uniqueProfileNames) {
                if (-not $sasTokensReady) { break }
                $uploadProfile = Get-UploadProfile -Name $profileName
                if ($null -eq $uploadProfile) { continue }
                if ([string]::IsNullOrEmpty($uploadProfile.sasTokenEnvVar)) { continue }

                $currentToken = [Environment]::GetEnvironmentVariable($uploadProfile.sasTokenEnvVar)
                if (Test-LWASSASTokenIsValid -SasToken $currentToken) { continue }

                $sasWarningPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                    "Upload profile '$profileName' requires a valid SAS token in '$($uploadProfile.sasTokenEnvVar)', but none is set or it has expired. Attempting to connect to Azure and generate a new token.",
                    '[yellow]SAS Token Required[/]'
                )
                $Console.Write($sasWarningPanel)

                $tokenUpdated = Update-LWASSASToken -Name $uploadProfile.sasTokenEnvVar -UploadProfile $uploadProfile.name
                if (-not $tokenUpdated) {
                    $sasFailPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                        "Could not generate a SAS token for upload profile '$profileName'. Connect to Azure (Connect-AzAccount) and run Update-LWASSASToken, or continue without uploading.",
                        '[yellow]Warning: SAS Token Unavailable[/]'
                    )
                    $Console.Write($sasFailPanel)

                    $sasPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                        'How would you like to proceed?',
                        @('Continue (uploads may fail)', 'Cancel')
                    )
                    $sasChoice = $sasPrompt.Show($Console)
                    if ($sasChoice -ieq 'Cancel') {
                        $sasTokensReady = $false
                    }
                }
            }

            if (-not $sasTokensReady) {
                continue
            }
        }

        # ── Step 5: Confirm and execute ───────────────────────────────────────────
        $runPrompt  = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
            'Run this macro?',
            @('Yes, run now', 'Cancel')
        )
        $runChoice  = $runPrompt.Show($Console)
        if ($runChoice -ieq 'Cancel') {
            continue
        }

        # Restore if minimised, then bring to foreground
        if (Invoke-IsIconic -WindowHandle $windowHandle) {
            Set-WindowState -WindowHandle $windowHandle -State 'Restore' | Out-Null
            Write-LastWarLog -Level Info `
                -Message "Restored minimised window '$($macro.Data.targetWindow.windowTitle)' before macro execution." `
                -FunctionName 'Show-RunMacroScreen'
            Start-Sleep -Milliseconds $storageConfig.MacroExecution.WindowRestoreDelayMs
        }
        Set-WindowActive -WindowHandle $windowHandle | Out-Null

        $result = Invoke-MacroSequence -MacroData $macro.Data -WindowHandle $windowHandle -Console $Console

        if ($result.Success) {
            $Console.Write([Spectre.Console.Markup]::new(
                "[green]Macro completed successfully. $($result.CompletedActions) of $($result.TotalActions) actions executed.[/]`n"
            ))
        } elseif ($script:EmergencyStopRequested) {
            $Console.Write([Spectre.Console.Markup]::new(
                "[yellow]Macro halted by emergency stop. $($result.CompletedActions) of $($result.TotalActions) actions completed.[/]`n"
            ))
        } else {
            $Console.Write([Spectre.Console.Markup]::new(
                "[red]Macro execution failed at step $($result.CompletedActions + 1) of $($result.TotalActions). $($result.CompletedActions) actions completed before failure.[/]`n"
            ))
            if (-not [string]::IsNullOrEmpty($result.Message)) {
                $Console.Write([Spectre.Console.Markup]::new(
                    "[red]$([Spectre.Console.Markup]::Escape($result.Message))[/]`n"
                ))
            }
        }

        # Pause before returning to previous menu
        $pausePrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateEmptyTextPrompt('Press [[Enter]] to continue...')
        $pausePrompt.Show($Console) | Out-Null

        return $null
    }
}
