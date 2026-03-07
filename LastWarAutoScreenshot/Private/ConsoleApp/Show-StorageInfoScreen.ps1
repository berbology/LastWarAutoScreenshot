function Show-StorageInfoScreen {
    <#
    .SYNOPSIS
        Displays current screenshot storage and log file usage, and allows the user to
        configure screenshot storage settings.

    .DESCRIPTION
        Uses Get-StorageInfo to retrieve the current storage state.  The screen behaves
        differently depending on whether storage has already been configured:

        Not configured (IsConfigured = $false):
          - Displays an information panel prompting the user to set a storage path.
          - Immediately presents TextPrompts for Screenshots.StoragePath and
            Screenshots.MaxStorageGB so the user can configure storage inline.

        Configured (IsConfigured = $true):
          - If storage usage is at or above 90 % of the configured maximum, a yellow
            warning panel is shown first.
          - A BreakdownChart visualises used vs free storage proportionally.
          - A Table summarises Used GB, Max GB, % Used, and Log Files GB.
          - TextPrompts are then presented so the user can update StoragePath and
            MaxStorageGB.

        After prompts (in both modes) a SelectionPrompt offers:
          'Yes - save now'                             -> persists changes via Save-ModuleSettings;
                                                          success panel shown; Info log entry written.
          'Reset ALL Screenshots settings to defaults' -> restores both Screenshots keys to
                                                          defaults from Get-DefaultModuleSettings;
                                                          saves; success panel; Info log entry.
          'Discard changes'                            -> returns without saving; info panel shown.

        Validation uses Test-ConfigValue throughout.  Invalid input is rejected with a
        red error message below the prompt and the same prompt is repeated until valid
        input or an empty Enter (keep current) is accepted.

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for all rendering and input.
        Pass [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole() for production use,
        or a [Spectre.Console.Testing.TestConsole]::new() instance in Pester tests.

    .OUTPUTS
        None

    .EXAMPLE
        $console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        Show-StorageInfoScreen -Console $console

    .NOTES
        The $Console parameter is the testability injection point.  All rendering and input
        is routed through this interface so Pester tests can inject a TestConsole and assert
        on its Output property without requiring a live terminal.

        BreakdownChart is available in Spectre.Console 0.40 and later.  This module bundles
        Spectre.Console 0.54.0 (see lib/VERSIONS.txt), so BreakdownChart is always available.
        Items are added via [Spectre.Console.BreakdownChartExtensions]::AddItem, which is the
        same static extension-method calling pattern used for TableExtensions.AddRow throughout
        this module.

        TextPrompt.AllowEmpty = $true is set on all prompts so that pressing Enter without
        typing anything keeps the current value unchanged - identical to the Logging,
        MouseControl, and EmergencyStop config screens.

        '[Reset to default]' sentinel: entering this exact string (case-insensitive) on any
        prompt resets that individual key to its value from Get-DefaultModuleSettings.
        'Reset ALL Screenshots settings to defaults' at the save prompt replaces the entire
        Screenshots sub-object and discards any per-key edits made in the current session.

        StoragePath type is 'string' with Nullable = $true in the validation schema, so
        Test-ConfigValue accepts any non-null string.  An empty TextPrompt answer (just
        Enter) keeps the existing value.  '[Reset to default]' resets the path to '' (empty).
        The function does not validate whether the path exists on disk; Get-StorageInfo
        handles that concern at runtime.

        Type coercion: MaxStorageGB values entered as strings are converted to [double]
        before being stored, matching the behaviour of ConvertFrom-Json on numeric values.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    # ── Load current configuration and live storage info ──────────────────────
    $config      = Get-ModuleConfiguration
    $defaults    = Get-DefaultModuleSettings
    $storageInfo = Get-StorageInfo

    # ── Ordered Screenshots key definitions ───────────────────────────────────
    # Drives both the summary table and the interactive prompt loop below.
    $screenshotsKeyDefs = @(
        @{
            Key    = 'Screenshots.StoragePath'
            Type   = 'string'
            Get    = { param($c) $c.Screenshots.StoragePath }
            Set    = { param($c, $v) $c.Screenshots.StoragePath = $v }
            DefGet = { param($d) $d.Screenshots.StoragePath }
        },
        @{
            Key    = 'Screenshots.MaxStorageGB'
            Type   = 'double'
            Get    = { param($c) $c.Screenshots.MaxStorageGB }
            Set    = { param($c, $v) $c.Screenshots.MaxStorageGB = [double]$v }
            DefGet = { param($d) $d.Screenshots.MaxStorageGB }
        }
    )

    # ── Helper: human-readable constraint string from a schema rule ───────────
    $buildConstraintString = {
        param($rule)
        if ($null -eq $rule) { return '' }
        switch ($rule.Type) {
            'string' {
                # Any non-null string is valid; no numeric range or enum constraint to display.
                # The schema Description field already conveys the field's purpose.
                return ''
            }
            'double' {
                if ($rule.ContainsKey('Min') -and $rule.ContainsKey('Max')) {
                    return "decimal $($rule.Min)-$($rule.Max)"
                }
                return 'decimal number'
            }
            default { return '' }
        }
    }

    # ── Step 1: Storage status - chart/table or not-configured panel ──────────
    if (-not $storageInfo.IsConfigured) {
        $infoPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
            'Screenshot storage path is not yet configured. Set it in the Screenshots section below.',
            'Storage & Log File Info'
        )
        $Console.Write($infoPanel)
    }
    else {
        # If storage is almost full, show a prominent warning before anything else
        if ($storageInfo.UsedPercent -ge 90.0) {
            $warningPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'Screenshot storage is over 90% full. Consider increasing the limit or clearing old screenshots.',
                '[yellow]Warning: Storage Almost Full[/]'
            )
            $Console.Write($warningPanel)
        }

        # BreakdownChart: proportional visualisation of used vs free storage
        $usedGB = $storageInfo.UsedGB
        $freeGB = [math]::Max(0.0, $storageInfo.MaxGB - $usedGB)

        $chart = [Spectre.Console.BreakdownChart]::new()

        if ($usedGB -gt 0.0) {
            [Spectre.Console.BreakdownChartExtensions]::AddItem(
                $chart,
                "Used ($([math]::Round($usedGB, 2)) GB)",
                $usedGB,
                [Spectre.Console.Color]::Red
            ) | Out-Null
        }

        [Spectre.Console.BreakdownChartExtensions]::AddItem(
            $chart,
            "Free ($([math]::Round($freeGB, 2)) GB)",
            [math]::Max($freeGB, 0.001),
            [Spectre.Console.Color]::Green
        ) | Out-Null

        $Console.Write($chart)

        # Summary table of live usage metrics
        $usageTable = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(@('Metric', 'Value'))

        [Spectre.Console.TableExtensions]::AddRow(
            $usageTable,
            [string[]]@('Used GB',      [Spectre.Console.Markup]::Escape("$([math]::Round($usedGB, 3))"))
        ) | Out-Null
        [Spectre.Console.TableExtensions]::AddRow(
            $usageTable,
            [string[]]@('Max GB',       [Spectre.Console.Markup]::Escape("$($storageInfo.MaxGB)"))
        ) | Out-Null
        [Spectre.Console.TableExtensions]::AddRow(
            $usageTable,
            [string[]]@('% Used',       [Spectre.Console.Markup]::Escape("$([math]::Round($storageInfo.UsedPercent, 1)) %"))
        ) | Out-Null
        [Spectre.Console.TableExtensions]::AddRow(
            $usageTable,
            [string[]]@('Log Files GB', [Spectre.Console.Markup]::Escape("$([math]::Round($storageInfo.LogFileSizeGB, 3))"))
        ) | Out-Null

        $Console.Write($usageTable)
    }

    # ── Step 2: Summary table of current config values ────────────────────────
    $configTable = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(
        @('Setting', 'Current Value', 'Allowed / Range', 'Description')
    )

    foreach ($def in $screenshotsKeyDefs) {
        $rule           = $script:ConfigValidationSchema[$def.Key]
        $currentValue   = & $def.Get $config
        $constraintStr  = & $buildConstraintString $rule
        $descriptionStr = if ($rule -and $rule.Description) { $rule.Description } else { '' }
        $displayValue   = if ([string]::IsNullOrEmpty($currentValue)) { '(not set)' } else { "$currentValue" }

        [Spectre.Console.TableExtensions]::AddRow(
            $configTable,
            [string[]]@(
                $def.Key,
                [Spectre.Console.Markup]::Escape($displayValue),
                [Spectre.Console.Markup]::Escape($constraintStr),
                [Spectre.Console.Markup]::Escape($descriptionStr)
            )
        ) | Out-Null
    }

    $Console.Write($configTable)

    # ── Step 3: Interactive prompts for each Screenshots key ──────────────────
    foreach ($def in $screenshotsKeyDefs) {
        $rule          = $script:ConfigValidationSchema[$def.Key]
        $constraintStr = & $buildConstraintString $rule
        $description   = if ($rule -and $rule.Description) { $rule.Description } else { $def.Key }

        while ($true) {
            $currentValue    = & $def.Get $config
            $displayCurrent  = if ([string]::IsNullOrEmpty($currentValue)) { '(not set)' } else { "$currentValue" }
            # Omit constraint parentheses entirely when the constraint string is empty (e.g. for 'string' type)
            $constraintPart  = if ([string]::IsNullOrEmpty($constraintStr)) { '' } else { " ($constraintStr)" }
            $promptText      = "$description [[current: $displayCurrent]]$constraintPart. Press Enter to keep:"

            $textPrompt            = [Spectre.Console.TextPrompt[string]]::new($promptText)
            $textPrompt.AllowEmpty = $true
            $answer                = $textPrompt.Show($Console)

            # Empty input -> keep the current value unchanged
            if ([string]::IsNullOrEmpty($answer)) {
                break
            }

            # Reset sentinel (case-insensitive)
            if ($answer -ieq '[Reset to default]') {
                $defaultValue = & $def.DefGet $defaults
                & $def.Set $config $defaultValue
                break
            }

            # Validate the entered value against the schema
            $validation = Test-ConfigValue -Key $def.Key -Value $answer
            if ($validation.Valid) {
                & $def.Set $config $answer
                break
            }

            # Invalid input - show error in red and re-prompt
            $Console.Write(
                [Spectre.Console.Markup]::new("[red]$([Spectre.Console.Markup]::Escape($validation.Message))[/]`n")
            )
        }
    }

    # ── Step 4: Save / reset / discard ────────────────────────────────────────
    $savePrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
        'Save changes?',
        @(
            'Yes - save now',
            'Reset ALL Screenshots settings to defaults',
            'Discard changes'
        )
    )
    $saveChoice = $savePrompt.Show($Console)

    switch ($saveChoice) {

        'Yes - save now' {
            Save-ModuleSettings -Config $config

            $successPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'Screenshot storage settings saved successfully.',
                '[green]Saved[/]'
            )
            $Console.Write($successPanel)

            Write-LastWarLog -Level Info `
                -Message 'Screenshots settings saved by user via storage info screen.' `
                -FunctionName 'Show-StorageInfoScreen'
        }

        'Reset ALL Screenshots settings to defaults' {
            $config.Screenshots = $defaults.Screenshots

            Save-ModuleSettings -Config $config

            $successPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'All Screenshots settings have been reset to their default values and saved.',
                '[green]Reset & Saved[/]'
            )
            $Console.Write($successPanel)

            Write-LastWarLog -Level Info `
                -Message 'All Screenshots settings reset to defaults by user via storage info screen.' `
                -FunctionName 'Show-StorageInfoScreen'
        }

        default {
            # 'Discard changes'
            $infoPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'No changes saved.',
                'Discarded'
            )
            $Console.Write($infoPanel)
        }
    }
}

