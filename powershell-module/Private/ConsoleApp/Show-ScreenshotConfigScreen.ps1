function Show-ScreenshotConfigScreen {
    <#
    .SYNOPSIS
        Displays and edits all Screenshot configuration settings via Spectre.Console prompts.

    .DESCRIPTION
        Guides the user through reviewing and optionally updating every Screenshots key that
        exists in the $script:ConfigValidationSchema.

        Workflow:
          1. Loads the current configuration via Get-ModuleConfiguration.
          2. Renders a Spectre.Console Table showing each Screenshots key with its current
             value, allowed values or range, and a human-readable description sourced
             from $script:ConfigValidationSchema.
          3. Iterates each key in order.  The prompt type depends on the key type:

             Bool keys (SimilarityCheck.Enabled, SimilarityCheck.FullScan):
               Uses a ConfirmationPrompt (yes/no).  DefaultValue is set to the current value
               so pressing Enter keeps it unchanged.  Additional information notes are
               displayed after certain bool keys when the user answers yes.

             stringEnum keys (FileFormat, SimilarityCheck.Action):
               FileFormat: displays a grey info note and shows a SelectionPrompt with 'PNG'.
               SimilarityCheck.Action: shows a SelectionPrompt with display-friendly choices
               that are mapped back to raw config values via a switch statement.

             StoragePath (string with path validation):
               TextPrompt with AllowEmpty=$true.  Empty input clears the path (sets to '').
               Non-empty input is validated by checking that the parent directory exists via
               Test-Path.  If the parent does not exist, an error is displayed and the prompt
               repeats.  The directory is NOT created here — auto-creation occurs at capture time.

             FilenamePattern (string with example display):
               TextPrompt with AllowEmpty=$true.  After the user enters a non-empty value,
               Resolve-ScreenshotFilename is called to compute and display an example filename.
               If the pattern resolves to $null (e.g., exceeds 200 characters), an error is
               shown and the prompt repeats.  Empty input keeps the current value.

             All other keys (int, double):
               TextPrompt (identical pattern to Show-LoggingConfigScreen):
                 "<Description> [current: <value>] (<constraints>). Press Enter to keep:"
               Empty input → keep current; '[Reset to default]' → restore default;
               any other input is validated via Test-ConfigValue and re-prompted if invalid.

          4. After all keys, renders a SelectionPrompt "Save changes?" with choices:
               - 'Yes - save now'                         → calls Save-ModuleSettings; success panel.
               - 'Reset ALL Screenshot settings to defaults' → replaces entire Screenshots section
                                                               with defaults; saves; success panel.
               - 'Discard changes'                        → returns without saving; info panel.

        Screenshots keys covered (in order):
          StoragePath, MaxStorageGB, StorageWarningThresholdPercent, FileFormat,
          FilenamePattern, SimilarityCheck.Enabled, SimilarityCheck.Threshold,
          SimilarityCheck.SampleCount, SimilarityCheck.FullScan,
          SimilarityCheck.TolerancePerChannel, SimilarityCheck.Action,
          SimilarityCheck.ConsecutiveThreshold

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for all rendering and input.
        Pass [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole() for production use,
        or a [Spectre.Console.Testing.TestConsole]::new() instance in Pester tests.

    .OUTPUTS
        None

    .EXAMPLE
        $console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        Show-ScreenshotConfigScreen -Console $console

    .NOTES
        The $Console parameter is the testability injection point.  All rendering and input
        is routed through this interface so Pester tests can inject a TestConsole and assert
        on its Output property without requiring a live terminal.

        Do NOT call Invoke-InAlternateScreen inside this function.  The entire configuration
        area is already wrapped in Invoke-InAlternateScreen by Start-LastWarAutoScreenshot
        via Show-ConfigMenuScreen.

        Bool keys use ConfirmationPrompt.  In tests, push 'y' or 'n' explicitly using
        $tc.Input.PushTextWithEnter('y') or PushTextWithEnter('n') rather than relying on
        PushKey(Enter), as DefaultValue enforcement for empty input depends on the
        TestConsole/Spectre.Console version in use.

        SimilarityCheck.Action display vs raw values:
          Display: 'StopNestedMacro (exit current loop, parent sequence continues)'
          Raw:     'StopNestedMacro'
          Display: 'StopMacro (halt entire macro; reported as success)'
          Raw:     'StopMacro'
          Display: 'Warn (log warning and continue)'
          Raw:     'Warn'
        The switch statement maps display choices back to raw values after prompt.

        '[Reset to default]' sentinel: the user types '[Reset to default]' (single brackets)
        to reset an individual TextPrompt key to its default value.  In prompt title text,
        this is displayed as '[[Reset to default]]' so Spectre.Console renders it literally.

        Type coercion: values entered as strings are converted to the correct .NET type
        (int or double) before being stored on the config object, matching ConvertFrom-Json
        behaviour.

        StoragePath empty input behaviour: pressing Enter without typing clears the path
        (sets StoragePath = '').  This differs from other TextPrompt keys where empty input
        keeps the current value.  The prompt title text communicates this difference.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    # ── Load current configuration ────────────────────────────────────────────
    $config   = Get-ModuleConfiguration
    $defaults = Get-DefaultModuleSettings

    # ── Ordered list of Screenshots keys ──────────────────────────────────────
    # The Type field drives which prompt style is used in the interactive loop.
    # StoragePath and FilenamePattern are 'string' type with per-key special handling.
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
        },
        @{
            Key    = 'Screenshots.StorageWarningThresholdPercent'
            Type   = 'int'
            Get    = { param($c) $c.Screenshots.StorageWarningThresholdPercent }
            Set    = { param($c, $v) $c.Screenshots.StorageWarningThresholdPercent = [int]$v }
            DefGet = { param($d) $d.Screenshots.StorageWarningThresholdPercent }
        },
        @{
            Key    = 'Screenshots.FileFormat'
            Type   = 'stringEnum'
            Get    = { param($c) $c.Screenshots.FileFormat }
            Set    = { param($c, $v) $c.Screenshots.FileFormat = $v }
            DefGet = { param($d) $d.Screenshots.FileFormat }
        },
        @{
            Key    = 'Screenshots.FilenamePattern'
            Type   = 'string'
            Get    = { param($c) $c.Screenshots.FilenamePattern }
            Set    = { param($c, $v) $c.Screenshots.FilenamePattern = $v }
            DefGet = { param($d) $d.Screenshots.FilenamePattern }
        },
        @{
            Key    = 'Screenshots.SimilarityCheck.Enabled'
            Type   = 'bool'
            Get    = { param($c) $c.Screenshots.SimilarityCheck.Enabled }
            Set    = { param($c, $v) $c.Screenshots.SimilarityCheck.Enabled = [bool]$v }
            DefGet = { param($d) $d.Screenshots.SimilarityCheck.Enabled }
        },
        @{
            Key    = 'Screenshots.SimilarityCheck.Threshold'
            Type   = 'double'
            Get    = { param($c) $c.Screenshots.SimilarityCheck.Threshold }
            Set    = { param($c, $v) $c.Screenshots.SimilarityCheck.Threshold = [double]$v }
            DefGet = { param($d) $d.Screenshots.SimilarityCheck.Threshold }
        },
        @{
            Key    = 'Screenshots.SimilarityCheck.SampleCount'
            Type   = 'int'
            Get    = { param($c) $c.Screenshots.SimilarityCheck.SampleCount }
            Set    = { param($c, $v) $c.Screenshots.SimilarityCheck.SampleCount = [int]$v }
            DefGet = { param($d) $d.Screenshots.SimilarityCheck.SampleCount }
        },
        @{
            Key    = 'Screenshots.SimilarityCheck.FullScan'
            Type   = 'bool'
            Get    = { param($c) $c.Screenshots.SimilarityCheck.FullScan }
            Set    = { param($c, $v) $c.Screenshots.SimilarityCheck.FullScan = [bool]$v }
            DefGet = { param($d) $d.Screenshots.SimilarityCheck.FullScan }
        },
        @{
            Key    = 'Screenshots.SimilarityCheck.TolerancePerChannel'
            Type   = 'int'
            Get    = { param($c) $c.Screenshots.SimilarityCheck.TolerancePerChannel }
            Set    = { param($c, $v) $c.Screenshots.SimilarityCheck.TolerancePerChannel = [int]$v }
            DefGet = { param($d) $d.Screenshots.SimilarityCheck.TolerancePerChannel }
        },
        @{
            Key    = 'Screenshots.SimilarityCheck.Action'
            Type   = 'stringEnum'
            Get    = { param($c) $c.Screenshots.SimilarityCheck.Action }
            Set    = { param($c, $v) $c.Screenshots.SimilarityCheck.Action = $v }
            DefGet = { param($d) $d.Screenshots.SimilarityCheck.Action }
        },
        @{
            Key    = 'Screenshots.SimilarityCheck.ConsecutiveThreshold'
            Type   = 'int'
            Get    = { param($c) $c.Screenshots.SimilarityCheck.ConsecutiveThreshold }
            Set    = { param($c, $v) $c.Screenshots.SimilarityCheck.ConsecutiveThreshold = [int]$v }
            DefGet = { param($d) $d.Screenshots.SimilarityCheck.ConsecutiveThreshold }
        }
    )

    # ── Helper: build a human-readable constraint string from a schema rule ───
    $buildConstraintString = {
        param($rule)
        if ($null -eq $rule) { return '' }
        switch ($rule.Type) {
            'stringEnum' { return "one of: $($rule.AllowedValues -join ' | ')" }
            'int' {
                if ($rule.ContainsKey('Min') -and $rule.ContainsKey('Max')) {
                    return "integer $($rule.Min)-$($rule.Max)"
                }
                return 'integer'
            }
            'double' {
                if ($rule.ContainsKey('Min') -and $rule.ContainsKey('Max')) {
                    return "decimal $($rule.Min)-$($rule.Max)"
                }
                return 'decimal'
            }
            'bool'   { return 'yes or no' }
            'string' { return 'text' }
            default  { return '' }
        }
    }

    # ── Step 1: Render summary table of current values ────────────────────────
    $table = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(
        @('Setting', 'Current Value', 'Allowed / Range', 'Description')
    )

    foreach ($def in $screenshotsKeyDefs) {
        $rule           = $script:ConfigValidationSchema[$def.Key]
        $currentValue   = & $def.Get $config
        $constraintStr  = & $buildConstraintString $rule
        $descriptionStr = if ($rule -and $rule.Description) { $rule.Description } else { '' }

        [Spectre.Console.TableExtensions]::AddRow(
            $table,
            [string[]]@(
                $def.Key,
                [Spectre.Console.Markup]::Escape("$currentValue"),
                [Spectre.Console.Markup]::Escape($constraintStr),
                [Spectre.Console.Markup]::Escape($descriptionStr)
            )
        ) | Out-Null
    }

    $Console.Write($table)

    # ── Step 2: Prompt for each Screenshots key in turn ───────────────────────
    foreach ($def in $screenshotsKeyDefs) {
        $rule        = $script:ConfigValidationSchema[$def.Key]
        $description = if ($rule -and $rule.Description) { $rule.Description } else { $def.Key }

        if ($def.Type -eq 'bool') {
            # ── Bool: ConfirmationPrompt (yes/no) ─────────────────────────────
            $currentValue  = & $def.Get $config
            $promptText    = "$description [[current: $currentValue]]:"
            $confirmPrompt = [Spectre.Console.ConfirmationPrompt]::new($promptText)
            $confirmPrompt.DefaultValue = [bool]$currentValue
            $newValue = $confirmPrompt.Show($Console)
            & $def.Set $config $newValue

            # Per-key post-prompt information notes
            if ($def.Key -eq 'Screenshots.SimilarityCheck.Enabled' -and $newValue -eq $true) {
                $Console.Write(
                    [Spectre.Console.Markup]::new("[grey]Similarity detection compares each screenshot with the previous one during macro execution. Use PNG format for best accuracy. Recommended threshold: 0.98.`n[/]")
                )
            }
            if ($def.Key -eq 'Screenshots.SimilarityCheck.FullScan' -and $newValue -eq $true) {
                $Console.Write(
                    [Spectre.Console.Markup]::new("[yellow]Full scan mode compares every pixel. This may be slow for large screenshots.`n[/]")
                )
            }
        }
        elseif ($def.Type -eq 'stringEnum') {
            if ($def.Key -eq 'Screenshots.FileFormat') {
                # ── FileFormat: info note + SelectionPrompt (PNG only) ────────
                $Console.Write(
                    [Spectre.Console.Markup]::new("[grey]Only PNG is supported in this release. Additional formats will be available in a future update.`n[/]")
                )
                $formatPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                    'File format:', @('PNG')
                )
                $newValue = $formatPrompt.Show($Console)
                & $def.Set $config $newValue
            }
            elseif ($def.Key -eq 'Screenshots.SimilarityCheck.Action') {
                # ── Action: SelectionPrompt with display-mapped choices ────────
                $actionDisplayChoices = @(
                    'StopNestedMacro (exit current loop, parent sequence continues)',
                    'StopMacro (halt entire macro; reported as success)',
                    'Warn (log warning and continue)'
                )
                $actionPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
                    'Similarity stop action:', $actionDisplayChoices
                )
                $displayChoice = $actionPrompt.Show($Console)
                $rawValue = switch ($displayChoice) {
                    'StopNestedMacro (exit current loop, parent sequence continues)' { 'StopNestedMacro' }
                    'StopMacro (halt entire macro; reported as success)'             { 'StopMacro' }
                    default                                                          { 'Warn' }
                }
                & $def.Set $config $rawValue
            }
        }
        elseif ($def.Key -eq 'Screenshots.StoragePath') {
            # ── StoragePath: TextPrompt with path parent validation ────────────
            # Empty input clears the path (sets to ''); this differs from other TextPrompt
            # keys where empty input retains the current value.
            while ($true) {
                $currentValue = & $def.Get $config
                $promptText   = "$description [[current: $([Spectre.Console.Markup]::Escape("$currentValue"))]]. Enter path or press Enter to clear:"

                $textPrompt = [Spectre.Console.TextPrompt[string]]::new($promptText)
                $textPrompt.AllowEmpty = $true
                $answer = $textPrompt.Show($Console)

                # Empty → clear path
                if ([string]::IsNullOrEmpty($answer)) {
                    & $def.Set $config ''
                    break
                }

                # Validate that the parent directory exists
                $parentDir = Split-Path $answer -Parent
                if (-not [string]::IsNullOrEmpty($parentDir) -and -not (Test-Path $parentDir)) {
                    $Console.Write(
                        [Spectre.Console.Markup]::new("[red]Parent directory does not exist: $([Spectre.Console.Markup]::Escape($parentDir))`n[/]")
                    )
                    continue
                }

                & $def.Set $config $answer
                break
            }
        }
        elseif ($def.Key -eq 'Screenshots.FilenamePattern') {
            # ── FilenamePattern: TextPrompt with example display ───────────────
            $constraintStr = & $buildConstraintString $rule
            while ($true) {
                $currentValue = & $def.Get $config
                $promptText   = "$description [[current: $([Spectre.Console.Markup]::Escape("$currentValue"))]] ($constraintStr). Press Enter to keep:"

                $textPrompt = [Spectre.Console.TextPrompt[string]]::new($promptText)
                $textPrompt.AllowEmpty = $true
                $answer = $textPrompt.Show($Console)

                # Empty → keep current value
                if ([string]::IsNullOrEmpty($answer)) {
                    break
                }

                # Reset sentinel (case-insensitive)
                if ($answer -ieq '[Reset to default]') {
                    $defaultValue = & $def.DefGet $defaults
                    & $def.Set $config $defaultValue
                    break
                }

                # Compute and display example filename
                $example = Resolve-ScreenshotFilename `
                    -Pattern    $answer `
                    -MacroName  'my-macro' `
                    -ActionName 'screenshot' `
                    -ActionType 'Screenshot' `
                    -Index      1 `
                    -Format     'PNG'

                if ($null -eq $example) {
                    $Console.Write(
                        [Spectre.Console.Markup]::new("[red]Pattern is invalid or resolves to a filename exceeding 200 characters. Please try a shorter pattern.`n[/]")
                    )
                    continue
                }

                $Console.Write(
                    [Spectre.Console.Markup]::new("[grey]Example filename: $([Spectre.Console.Markup]::Escape($example))`n[/]")
                )
                & $def.Set $config $answer
                break
            }
        }
        else {
            # ── int / double: TextPrompt (same as Show-LoggingConfigScreen) ────
            # Per-key custom hint text overrides the generic constraint string for keys
            # where the raw constraint string is less informative than a plain-English hint.
            $hintText = switch ($def.Key) {
                'Screenshots.SimilarityCheck.Threshold' {
                    '(0.0 to 1.0, where 1.0 = 100% identical)'
                }
                'Screenshots.SimilarityCheck.TolerancePerChannel' {
                    '(0 = exact match, 255 = any pixel counts as matching)'
                }
                'Screenshots.SimilarityCheck.ConsecutiveThreshold' {
                    '(1 = trigger on first match; higher values require N consecutive similar screenshots)'
                }
                default {
                    "($(& $buildConstraintString $rule))"
                }
            }

            while ($true) {
                $currentValue = & $def.Get $config
                $promptText   = "$description [[current: $currentValue]] $hintText. Press Enter to keep:"

                $textPrompt = [Spectre.Console.TextPrompt[string]]::new($promptText)
                $textPrompt.AllowEmpty = $true
                $answer = $textPrompt.Show($Console)

                # Empty → keep current value
                if ([string]::IsNullOrEmpty($answer)) {
                    break
                }

                # Reset sentinel (case-insensitive)
                if ($answer -ieq '[Reset to default]') {
                    $defaultValue = & $def.DefGet $defaults
                    & $def.Set $config $defaultValue
                    break
                }

                # Validate entered value
                $validation = Test-ConfigValue -Key $def.Key -Value $answer
                if ($validation.Valid) {
                    & $def.Set $config $answer
                    break
                }

                # Invalid - show error in red and re-prompt
                $Console.Write(
                    [Spectre.Console.Markup]::new("[red]$([Spectre.Console.Markup]::Escape($validation.Message))[/]`n")
                )
            }
        }
    }

    # ── Step 3: Save / reset / discard ───────────────────────────────────────
    $savePrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
        'Save changes?',
        @(
            'Yes - save now',
            'Reset ALL Screenshot settings to defaults',
            'Discard changes'
        )
    )
    $saveChoice = $savePrompt.Show($Console)

    switch ($saveChoice) {

        'Yes - save now' {
            Save-ModuleSettings -Config $config

            $successPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'Screenshot settings saved successfully.',
                '[green]Saved[/]'
            )
            $Console.Write($successPanel)

            Write-LastWarLog -Level Info `
                -Message 'Screenshot settings saved by user via configuration screen.' `
                -FunctionName 'Show-ScreenshotConfigScreen'
        }

        'Reset ALL Screenshot settings to defaults' {
            $config.Screenshots = $defaults.Screenshots

            Save-ModuleSettings -Config $config

            $successPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'All Screenshot settings have been reset to their default values and saved.',
                '[green]Reset & Saved[/]'
            )
            $Console.Write($successPanel)

            Write-LastWarLog -Level Info `
                -Message 'All Screenshot settings reset to defaults by user via configuration screen.' `
                -FunctionName 'Show-ScreenshotConfigScreen'
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
