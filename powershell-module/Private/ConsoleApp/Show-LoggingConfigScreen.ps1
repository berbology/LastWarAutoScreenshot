function Show-LoggingConfigScreen {
    <#
    .SYNOPSIS
        Displays and edits all Logging configuration settings via Spectre.Console prompts.

    .DESCRIPTION
        Guides the user through reviewing and optionally updating every Logging key that
        exists in the $script:ConfigValidationSchema.

        Workflow:
          1. Loads the current configuration via Get-ModuleConfiguration.
          2. Renders a Spectre.Console Table showing each Logging key with its current
             value, allowed values or range, and a human-readable description sourced
             from $script:ConfigValidationSchema.
          3. Iterates each Logging key in order.  For each key a TextPrompt is shown:
               "Description [range] (current value): "
             where the range bracket is rendered in blue and the current value in green.
             - Empty input (just Enter) → current value kept unchanged.
             - '[Reset to default]'     → value replaced with the default from
                                          Get-DefaultModuleSettings.
             - Any other input          → validated via Test-ConfigValue.  If invalid,
                                          the error message is written to $Console in red
                                          and the same prompt is repeated until the user
                                          enters a valid value or accepts the current value
                                          via Enter.
          4. After all keys, renders a SelectionPrompt "Save changes?" with choices:
               - 'Yes - save now'                 → calls Save-ModuleSettings; success panel.
               - 'Reset ALL Logging settings to defaults' → replaces entire Logging section
                                                              with defaults; saves; success panel.
               - 'Discard changes'                → returns without saving; info panel.

        Logging keys covered (in order):
          Logging.MinimumLogLevel, Logging.Backend,
          Logging.FileBackend.MaxSizeMB, Logging.FileBackend.MaxFileCount,
          Logging.FileBackend.MaxAgeDays, Logging.FileBackend.RetentionFileCount

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for all rendering and input.
        Pass [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole() for production use,
        or a [Spectre.Console.Testing.TestConsole]::new() instance in Pester tests.

    .OUTPUTS
        None

    .EXAMPLE
        $console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        Show-LoggingConfigScreen -Console $console

    .NOTES
        The $Console parameter is the testability injection point.  All rendering and input
        is routed through this interface so Pester tests can inject a TestConsole and assert
        on its Output property without requiring a live terminal.

        TextPrompt input is captured via $Console so TestConsole.Input.PushTextWithEnter()
        can pre-queue answers for automated tests.

        Type coercion: values entered as strings are converted to the correct .NET type
        (int for 'int' schema entries) before being stored on the config object.  This
        matches the behaviour of ConvertFrom-Json which also returns ints as [int].

        '[Reset to default]': this literal string (including the brackets) is the recognised
        sentinel to reset an individual key.  It is case-insensitive to tolerate slight
        capitalisation differences.

        'Reset ALL Logging settings to defaults' on the save prompt replaces the entire
        Logging sub-object with a fresh copy from Get-DefaultModuleSettings and saves
        immediately - any per-key changes made earlier in the same session are discarded.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    # ── Load current configuration ────────────────────────────────────────────
    $config   = Get-ModuleConfiguration
    $defaults = Get-DefaultModuleSettings

    # ── Ordered list of Logging keys with their config navigation helpers ─────
    # Each entry: [key, getter scriptblock, setter scriptblock]
    $loggingKeyDefs = @(
        @{
            Key    = 'Logging.MinimumLogLevel'
            Get    = { param($c) $c.Logging.MinimumLogLevel }
            Set    = { param($c, $v) $c.Logging.MinimumLogLevel = $v }
            DefGet = { param($d) $d.Logging.MinimumLogLevel }
        },
        @{
            Key    = 'Logging.Backend'
            Get    = { param($c) $c.Logging.Backend }
            Set    = { param($c, $v) $c.Logging.Backend = $v }
            DefGet = { param($d) $d.Logging.Backend }
        },
        @{
            Key    = 'Logging.FileBackend.MaxSizeMB'
            Get    = { param($c) $c.Logging.FileBackend.MaxSizeMB }
            Set    = { param($c, $v) $c.Logging.FileBackend.MaxSizeMB = [int]$v }
            DefGet = { param($d) $d.Logging.FileBackend.MaxSizeMB }
        },
        @{
            Key    = 'Logging.FileBackend.MaxFileCount'
            Get    = { param($c) $c.Logging.FileBackend.MaxFileCount }
            Set    = { param($c, $v) $c.Logging.FileBackend.MaxFileCount = [int]$v }
            DefGet = { param($d) $d.Logging.FileBackend.MaxFileCount }
        },
        @{
            Key    = 'Logging.FileBackend.MaxAgeDays'
            Get    = { param($c) $c.Logging.FileBackend.MaxAgeDays }
            Set    = { param($c, $v) $c.Logging.FileBackend.MaxAgeDays = [int]$v }
            DefGet = { param($d) $d.Logging.FileBackend.MaxAgeDays }
        },
        @{
            Key    = 'Logging.FileBackend.RetentionFileCount'
            Get    = { param($c) $c.Logging.FileBackend.RetentionFileCount }
            Set    = { param($c, $v) $c.Logging.FileBackend.RetentionFileCount = [int]$v }
            DefGet = { param($d) $d.Logging.FileBackend.RetentionFileCount }
        }
    )

    # ── Helper: build a human-readable constraint string from a schema rule ───
    $buildConstraintString = {
        param($rule)
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
            'bool'     { return 'true or false' }
            'intArray' {
                if ($rule.ContainsKey('Min') -and $rule.ContainsKey('Max')) {
                    return "min, max (each $($rule.Min)-$($rule.Max); min ≤ max)"
                }
                return 'min, max'
            }
            default { return '' }
        }
    }

    # ── Helper: build prompt text ─────────────────────────────────────────────
    # Format: "Description [blue][[range]][/] [green](Current)[/]: "
    # stringEnum: range = "Value1 | Value2 | ..." in full brackets [[...]]
    # int:        range = "min-max" in full brackets [[min-max]]
    $buildPromptText = {
        param($description, $rule, $currentValue)
        $escapedValue = [Spectre.Console.Markup]::Escape("$currentValue")

        if ($rule) {
            switch ($rule.Type) {
                'stringEnum' {
                    $rangeStr = $rule.AllowedValues -join ' | '
                    return "$description [blue][[$rangeStr]][/] [green]($escapedValue)[/]: "
                }
                'int' {
                    if ($rule.ContainsKey('Min') -and $rule.ContainsKey('Max')) {
                        return "$description [blue][[$($rule.Min)-$($rule.Max)]][/] [green]($escapedValue)[/]: "
                    }
                }
            }
        }

        return "$description [green]($escapedValue)[/]: "
    }

    # ── Step 1: Render summary table of current values ────────────────────────
    $table = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(
        @('Setting', 'Current Value', 'Allowed / Range', 'Description')
    )

    foreach ($def in $loggingKeyDefs) {
        $rule            = $script:ConfigValidationSchema[$def.Key]
        $currentValue    = & $def.Get $config
        $constraintStr   = & $buildConstraintString $rule
        $descriptionStr  = if ($rule -and $rule.Description) { $rule.Description } else { '' }

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

    # ── Step 2: Prompt for each Logging key in turn ───────────────────────────
    foreach ($def in $loggingKeyDefs) {
        $rule        = $script:ConfigValidationSchema[$def.Key]
        $description = if ($rule -and $rule.Description) { $rule.Description } else { $def.Key }

        while ($true) {
            $currentValue = & $def.Get $config
            $promptText   = & $buildPromptText $description $rule $currentValue

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

            # Invalid - show error and re-prompt
            $Console.Write(
                [Spectre.Console.Markup]::new("[red]$([Spectre.Console.Markup]::Escape($validation.Message))[/]`n")
            )
        }
    }

    # ── Step 3: Save / reset / discard ───────────────────────────────────────
    $savePrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
        'Save changes?',
        @(
            'Yes - save now',
            'Reset ALL Logging settings to defaults',
            'Discard changes'
        )
    )
    $saveChoice = $savePrompt.Show($Console)

    switch ($saveChoice) {

        'Yes - save now' {
            Save-ModuleSettings -Config $config

            $successPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'Logging settings saved successfully.',
                '[green]Saved[/]'
            )
            $Console.Write($successPanel)

            Write-LastWarLog -Level Info `
                -Message 'Logging settings saved by user via configuration screen.' `
                -FunctionName 'Show-LoggingConfigScreen'
        }

        'Reset ALL Logging settings to defaults' {
            $config.Logging = $defaults.Logging

            Save-ModuleSettings -Config $config

            $successPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'All Logging settings have been reset to their default values and saved.',
                '[green]Reset & Saved[/]'
            )
            $Console.Write($successPanel)

            Write-LastWarLog -Level Info `
                -Message 'All Logging settings reset to defaults by user via configuration screen.' `
                -FunctionName 'Show-LoggingConfigScreen'
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

