function Show-MouseControlConfigScreen {
    <#
    .SYNOPSIS
        Displays and edits all MouseControl configuration settings via Spectre.Console prompts.

    .DESCRIPTION
        Guides the user through reviewing and optionally updating every MouseControl key that
        exists in the $script:ConfigValidationSchema.

        Workflow:
          1. Loads the current configuration via Get-ModuleConfiguration.
          2. Renders a Spectre.Console Table showing each MouseControl key with its current
             value, allowed values or range, and a human-readable description sourced
             from $script:ConfigValidationSchema.
          3. Iterates each MouseControl key in order.  The prompt type depends on the key type:

             Bool keys (EasingEnabled, OvershootEnabled, MicroPausesEnabled, JitterEnabled):
               Uses a TextPrompt (y/n).  Empty input keeps the current value unchanged.
               Invalid input shows an error and re-prompts.

             intArray keys (range pairs - all duration/delay range keys):
               Shows two separate TextPrompts labelled:
                 "<Key> minimum (ms) [<min>]:"
                 "<Key> maximum (ms) [<max>]:"
               After both values are entered (or kept), the pair is validated as a unit via
               Test-ConfigValue.  If invalid (e.g. min > max, out-of-range), the error
               message is written to $Console in red and BOTH prompts repeat.
               Entering '[Reset to default]' on either the min or max prompt resets the
               entire array key to its schema default and moves to the next key.

             All other keys (int, double):
               Uses a TextPrompt:
                 "<Description> [blue][<min>-<max>][/] [green](<value>)[/]:"
               Empty input → keep current; '[Reset to default]' → restore default;
               any other input is validated and re-prompted if invalid.

          4. After all keys, renders a SelectionPrompt "Save changes?" with choices:
               - 'Yes - save now'                           → calls Save-ModuleSettings; success panel.
               - 'Reset ALL MouseControl settings to defaults' → replaces entire MouseControl
                                                                  section with defaults; saves; success panel.
               - 'Discard changes'                          → returns without saving; info panel.

        MouseControl keys covered (in order):
          EasingEnabled, OvershootEnabled, OvershootFactor, MicroPausesEnabled,
          MicroPauseChance, MinMicroPauseDurationMs, MaxMicroPauseDurationMs, JitterEnabled,
          JitterRadiusPx, BezierControlPointOffsetFactor, MinMovementDurationMs,
          MaxMovementDurationMs, MinClickDownDurationMs, MaxClickDownDurationMs,
          MinClickPreDelayMs, MaxClickPreDelayMs, MinClickPostDelayMs, MaxClickPostDelayMs,
          PathPointCount

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for all rendering and input.
        Pass [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole() for production use,
        or a [Spectre.Console.Testing.TestConsole]::new() instance in Pester tests.

    .OUTPUTS
        None

    .EXAMPLE
        $console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        Show-MouseControlConfigScreen -Console $console

    .NOTES
        The $Console parameter is the testability injection point.  All rendering and input
        is routed through this interface so Pester tests can inject a TestConsole and assert
        on its Output property without requiring a live terminal.

        Bool keys use a TextPrompt with y/n parsing (same pattern as Show-ScreenshotConfigScreen).
        In tests, push 'y' or 'n' explicitly using $tc.Input.PushTextWithEnter('y') or
        PushTextWithEnter('n').  Empty input (PushKey(Enter)) keeps the current value.

        intArray '[Reset to default]' sentinel: entering '[Reset to default]' on either
        the min or max prompt resets the ENTIRE array key to its default - not just one
        element.  Use 'Reset ALL MouseControl settings to defaults' at the save prompt
        to restore every key in one operation.

        Type coercion: values entered as strings are converted to int or double before
        being stored on the config object, matching ConvertFrom-Json behaviour.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    # ── Load current configuration ────────────────────────────────────────────
    $config   = Get-ModuleConfiguration
    $defaults = Get-DefaultModuleSettings

    # ── Ordered list of MouseControl keys ─────────────────────────────────────
    # The Type field drives which prompt type is used in the interactive loop:
    #   'bool'     → ConfirmationPrompt
    #   'intArray' → two TextPrompts (min then max), validated as a unit
    #   anything else → TextPrompt (same as Show-LoggingConfigScreen)
    $mouseControlKeyDefs = @(
        @{
            Key    = 'MouseControl.EasingEnabled'
            Type   = 'bool'
            Get    = { param($c) $c.MouseControl.EasingEnabled }
            Set    = { param($c, $v) $c.MouseControl.EasingEnabled = [bool]$v }
            DefGet = { param($d) $d.MouseControl.EasingEnabled }
        },
        @{
            Key    = 'MouseControl.OvershootEnabled'
            Type   = 'bool'
            Get    = { param($c) $c.MouseControl.OvershootEnabled }
            Set    = { param($c, $v) $c.MouseControl.OvershootEnabled = [bool]$v }
            DefGet = { param($d) $d.MouseControl.OvershootEnabled }
        },
        @{
            Key    = 'MouseControl.OvershootFactor'
            Type   = 'double'
            Get    = { param($c) $c.MouseControl.OvershootFactor }
            Set    = { param($c, $v) $c.MouseControl.OvershootFactor = [double]$v }
            DefGet = { param($d) $d.MouseControl.OvershootFactor }
        },
        @{
            Key    = 'MouseControl.MicroPausesEnabled'
            Type   = 'bool'
            Get    = { param($c) $c.MouseControl.MicroPausesEnabled }
            Set    = { param($c, $v) $c.MouseControl.MicroPausesEnabled = [bool]$v }
            DefGet = { param($d) $d.MouseControl.MicroPausesEnabled }
        },
        @{
            Key    = 'MouseControl.MicroPauseChance'
            Type   = 'double'
            Get    = { param($c) $c.MouseControl.MicroPauseChance }
            Set    = { param($c, $v) $c.MouseControl.MicroPauseChance = [double]$v }
            DefGet = { param($d) $d.MouseControl.MicroPauseChance }
        },
        @{
            Key    = 'MouseControl.MinMicroPauseDurationMs'
            Type   = 'int'
            Get    = { param($c) $c.MouseControl.MinMicroPauseDurationMs }
            Set    = { param($c, $v) $c.MouseControl.MinMicroPauseDurationMs = [int]$v }
            DefGet = { param($d) $d.MouseControl.MinMicroPauseDurationMs }
        },
        @{
            Key    = 'MouseControl.MaxMicroPauseDurationMs'
            Type   = 'int'
            Get    = { param($c) $c.MouseControl.MaxMicroPauseDurationMs }
            Set    = { param($c, $v) $c.MouseControl.MaxMicroPauseDurationMs = [int]$v }
            DefGet = { param($d) $d.MouseControl.MaxMicroPauseDurationMs }
        },
        @{
            Key    = 'MouseControl.JitterEnabled'
            Type   = 'bool'
            Get    = { param($c) $c.MouseControl.JitterEnabled }
            Set    = { param($c, $v) $c.MouseControl.JitterEnabled = [bool]$v }
            DefGet = { param($d) $d.MouseControl.JitterEnabled }
        },
        @{
            Key    = 'MouseControl.JitterRadiusPx'
            Type   = 'int'
            Get    = { param($c) $c.MouseControl.JitterRadiusPx }
            Set    = { param($c, $v) $c.MouseControl.JitterRadiusPx = [int]$v }
            DefGet = { param($d) $d.MouseControl.JitterRadiusPx }
        },
        @{
            Key    = 'MouseControl.BezierControlPointOffsetFactor'
            Type   = 'double'
            Get    = { param($c) $c.MouseControl.BezierControlPointOffsetFactor }
            Set    = { param($c, $v) $c.MouseControl.BezierControlPointOffsetFactor = [double]$v }
            DefGet = { param($d) $d.MouseControl.BezierControlPointOffsetFactor }
        },
        @{
            Key    = 'MouseControl.MinMovementDurationMs'
            Type   = 'int'
            Get    = { param($c) $c.MouseControl.MinMovementDurationMs }
            Set    = { param($c, $v) $c.MouseControl.MinMovementDurationMs = [int]$v }
            DefGet = { param($d) $d.MouseControl.MinMovementDurationMs }
        },
        @{
            Key    = 'MouseControl.MaxMovementDurationMs'
            Type   = 'int'
            Get    = { param($c) $c.MouseControl.MaxMovementDurationMs }
            Set    = { param($c, $v) $c.MouseControl.MaxMovementDurationMs = [int]$v }
            DefGet = { param($d) $d.MouseControl.MaxMovementDurationMs }
        },
        @{
            Key    = 'MouseControl.MinClickDownDurationMs'
            Type   = 'int'
            Get    = { param($c) $c.MouseControl.MinClickDownDurationMs }
            Set    = { param($c, $v) $c.MouseControl.MinClickDownDurationMs = [int]$v }
            DefGet = { param($d) $d.MouseControl.MinClickDownDurationMs }
        },
        @{
            Key    = 'MouseControl.MaxClickDownDurationMs'
            Type   = 'int'
            Get    = { param($c) $c.MouseControl.MaxClickDownDurationMs }
            Set    = { param($c, $v) $c.MouseControl.MaxClickDownDurationMs = [int]$v }
            DefGet = { param($d) $d.MouseControl.MaxClickDownDurationMs }
        },
        @{
            Key    = 'MouseControl.MinClickPreDelayMs'
            Type   = 'int'
            Get    = { param($c) $c.MouseControl.MinClickPreDelayMs }
            Set    = { param($c, $v) $c.MouseControl.MinClickPreDelayMs = [int]$v }
            DefGet = { param($d) $d.MouseControl.MinClickPreDelayMs }
        },
        @{
            Key    = 'MouseControl.MaxClickPreDelayMs'
            Type   = 'int'
            Get    = { param($c) $c.MouseControl.MaxClickPreDelayMs }
            Set    = { param($c, $v) $c.MouseControl.MaxClickPreDelayMs = [int]$v }
            DefGet = { param($d) $d.MouseControl.MaxClickPreDelayMs }
        },
        @{
            Key    = 'MouseControl.MinClickPostDelayMs'
            Type   = 'int'
            Get    = { param($c) $c.MouseControl.MinClickPostDelayMs }
            Set    = { param($c, $v) $c.MouseControl.MinClickPostDelayMs = [int]$v }
            DefGet = { param($d) $d.MouseControl.MinClickPostDelayMs }
        },
        @{
            Key    = 'MouseControl.MaxClickPostDelayMs'
            Type   = 'int'
            Get    = { param($c) $c.MouseControl.MaxClickPostDelayMs }
            Set    = { param($c, $v) $c.MouseControl.MaxClickPostDelayMs = [int]$v }
            DefGet = { param($d) $d.MouseControl.MaxClickPostDelayMs }
        },
        @{
            Key    = 'MouseControl.PathPointCount'
            Type   = 'int'
            Get    = { param($c) $c.MouseControl.PathPointCount }
            Set    = { param($c, $v) $c.MouseControl.PathPointCount = [int]$v }
            DefGet = { param($d) $d.MouseControl.PathPointCount }
        }
    )

    # ── Helper: build a human-readable constraint string from a schema rule ───
    # Used for the summary table only; returns plain text (no markup).
    $buildConstraintString = {
        param($rule)
        if ($null -eq $rule) { return '' }
        switch ($rule.Type) {
            'stringEnum' { return "one of: $($rule.AllowedValues -join ' | ')" }
            'int' {
                if ($rule.ContainsKey('Min') -and $rule.ContainsKey('Max')) {
                    return "$($rule.Min)-$($rule.Max)"
                }
                return 'integer'
            }
            'double' {
                if ($rule.ContainsKey('Min') -and $rule.ContainsKey('Max')) {
                    return "$($rule.Min)-$($rule.Max)"
                }
                return 'decimal'
            }
            'bool'   { return 'yes or no' }
            default  { return '' }
        }
    }

    # ── Helper: build bool prompt text ───────────────────────────────────────────
    # Format: "Description [blue][[y/n]][/] [green](y)[/]: "
    $buildBoolPromptText = {
        param($description, $currentValue)
        $displayValue = if ($currentValue) { 'y' } else { 'n' }
        return "$description [blue][[y/n]][/] [green]($displayValue)[/]: "
    }

    # ── Helper: build numeric prompt text ────────────────────────────────────────
    # Format: "Description [blue][[min-max]][/] [green](value)[/]: "
    $buildNumericPromptText = {
        param($description, $rule, $currentValue)
        $rangeStr = ''
        if ($rule -and $rule.ContainsKey('Min') -and $rule.ContainsKey('Max')) {
            $rangeStr = "$($rule.Min)-$($rule.Max)"
        }

        if ($rangeStr) {
            return "$description [blue][[$rangeStr]][/] [green]($currentValue)[/]: "
        } else {
            return "$description [green]($currentValue)[/]: "
        }
    }

    # ── Helper: parse yes/no user input to boolean ───────────────────────────────
    $parseBoolInput = {
        param($userInput)
        $lower = $userInput.ToLowerInvariant().Trim()
        if ($lower -in @('y', 'yes', 'true', '1')) {
            return $true
        }
        elseif ($lower -in @('n', 'no', 'false', '0')) {
            return $false
        }
        else {
            return $null  # Invalid input
        }
    }

    # ── Step 1: Render summary table of current values ────────────────────────
    $table = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(
        @('Setting', 'Current Value', 'Allowed / Range', 'Description')
    )

    foreach ($def in $mouseControlKeyDefs) {
        $rule           = $script:ConfigValidationSchema[$def.Key]
        $currentValue   = & $def.Get $config
        $constraintStr  = & $buildConstraintString $rule
        $descriptionStr = if ($rule -and $rule.Description) { $rule.Description } else { '' }
        $displayValue   = if ($currentValue -is [array]) { $currentValue -join ', ' } else { "$currentValue" }

        [Spectre.Console.TableExtensions]::AddRow(
            $table,
            [string[]]@(
                ($def.Key -replace '^.*\.', ''),
                [Spectre.Console.Markup]::Escape($displayValue),
                [Spectre.Console.Markup]::Escape($constraintStr),
                [Spectre.Console.Markup]::Escape($descriptionStr)
            )
        ) | Out-Null
    }

    $Console.Write($table)

    # ── Step 2: Prompt for each MouseControl key in turn ─────────────────────
    foreach ($def in $mouseControlKeyDefs) {
        $rule        = $script:ConfigValidationSchema[$def.Key]
        $description = if ($rule -and $rule.Description) { $rule.Description } else { $def.Key }

        if ($def.Type -eq 'bool') {
            # ── Bool: TextPrompt with y/n parsing ────────────────────────────
            $currentValue = & $def.Get $config
            $promptText   = & $buildBoolPromptText $description $currentValue

            while ($true) {
                $textPrompt = [Spectre.Console.TextPrompt[string]]::new($promptText)
                $textPrompt.AllowEmpty = $true
                $answer = $textPrompt.Show($Console)

                # Empty input → keep current value
                if ([string]::IsNullOrEmpty($answer)) {
                    $newValue = $currentValue
                    break
                }

                # Parse y/n/yes/no input
                $parsed = & $parseBoolInput $answer
                if ($null -eq $parsed) {
                    $Console.Write(
                        [Spectre.Console.Markup]::new("[red]Please enter y/yes/true/1 or n/no/false/0.`n[/]")
                    )
                    continue
                }

                $newValue = $parsed
                break
            }

            & $def.Set $config $newValue
        }
        elseif ($def.Type -eq 'intArray') {
            # ── intArray: separate min/max TextPrompts, validated as a pair ───
            # Strip the 'MouseControl.' prefix for the prompt label.
            $shortKey = $def.Key -replace '^MouseControl\.', ''

            while ($true) {
                $currentArr = & $def.Get $config
                $currentMin = $currentArr[0]
                $currentMax = $currentArr[1]

                # - Min prompt ----------------------------------------------
                $minPromptText = "$shortKey minimum (ms) [green][[$currentMin]][/]:"
                $minPrompt     = [Spectre.Console.TextPrompt[string]]::new($minPromptText)
                $minPrompt.AllowEmpty = $true
                $minAnswer = $minPrompt.Show($Console)

                if ([string]::IsNullOrEmpty($minAnswer)) {
                    $minAnswer = "$currentMin"
                }
                elseif ($minAnswer -ieq '[Reset to default]') {
                    $defaultValue = & $def.DefGet $defaults
                    & $def.Set $config $defaultValue
                    break
                }

                # - Max prompt ----------------------------------------------
                $maxPromptText = "$shortKey maximum (ms) [green][[$currentMax]][/]:"
                $maxPrompt     = [Spectre.Console.TextPrompt[string]]::new($maxPromptText)
                $maxPrompt.AllowEmpty = $true
                $maxAnswer = $maxPrompt.Show($Console)

                if ([string]::IsNullOrEmpty($maxAnswer)) {
                    $maxAnswer = "$currentMax"
                }
                elseif ($maxAnswer -ieq '[Reset to default]') {
                    $defaultValue = & $def.DefGet $defaults
                    & $def.Set $config $defaultValue
                    break
                }

                # - Validate as a pair ------------------------------------
                $pairString = "$minAnswer, $maxAnswer"
                $validation = Test-ConfigValue -Key $def.Key -Value $pairString
                if ($validation.Valid) {
                    & $def.Set $config @([int]$minAnswer, [int]$maxAnswer)
                    break
                }

                # Invalid - show error in red and re-prompt both min and max
                $Console.Write(
                    [Spectre.Console.Markup]::new("[red]$([Spectre.Console.Markup]::Escape($validation.Message))[/]`n")
                )
            }
        }
        else {
            # ── int / double: TextPrompt with standard format and validation ──
            while ($true) {
                $currentValue = & $def.Get $config
                $promptText   = & $buildNumericPromptText $description $rule $currentValue

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
            'Reset ALL MouseControl settings to defaults',
            'Discard changes'
        )
    )
    $saveChoice = $savePrompt.Show($Console)

    switch ($saveChoice) {

        'Yes - save now' {
            Save-ModuleSettings -Config $config

            $successPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'Mouse control settings saved successfully.',
                '[green]Saved[/]'
            )
            $Console.Write($successPanel)

            Write-LastWarLog -Level Info `
                -Message 'MouseControl settings saved by user via configuration screen.' `
                -FunctionName 'Show-MouseControlConfigScreen'
        }

        'Reset ALL MouseControl settings to defaults' {
            $config.MouseControl = $defaults.MouseControl

            Save-ModuleSettings -Config $config

            $successPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'All MouseControl settings have been reset to their default values and saved.',
                '[green]Reset & Saved[/]'
            )
            $Console.Write($successPanel)

            Write-LastWarLog -Level Info `
                -Message 'All MouseControl settings reset to defaults by user via configuration screen.' `
                -FunctionName 'Show-MouseControlConfigScreen'
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

