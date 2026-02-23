function Show-EmergencyStopConfigScreen {
    <#
    .SYNOPSIS
        Displays and edits all EmergencyStop configuration settings via Spectre.Console prompts.

    .DESCRIPTION
        Guides the user through reviewing and optionally updating every EmergencyStop key that
        exists in the $script:ConfigValidationSchema, plus the HotkeyVKeyCodes key which
        requires custom parsing and validation.

        Workflow:
          1. Loads the current configuration via Get-ModuleConfiguration.
          2. Renders a Spectre.Console Table showing each EmergencyStop key with its current
             value, allowed values or range, and a human-readable description sourced
             from $script:ConfigValidationSchema.  The HotkeyVKeyCodes row is always shown
             with the codes formatted as comma-separated hex strings (e.g. "0x11, 0x10, 0xDC").
          3. Iterates each schema-backed EmergencyStop key in order.  The prompt type depends
             on the key type:

             Bool keys (AutoStart, MouseGestureEnabled):
               Uses a ConfirmationPrompt (yes/no).  DefaultValue is set to the current value
               so pressing Enter keeps it unchanged in interactive terminals.  In tests, push
               'y' or 'n' explicitly via $tc.Input.PushTextWithEnter('y').

             Int keys (PollIntervalMs, MouseGestureHoldDurationMs):
               Uses a TextPrompt (identical pattern to Show-LoggingConfigScreen):
                 "<Description> [current: <value>] (<constraints>). Press Enter to keep:"
               Empty input -> keep current; '[Reset to default]' -> restore default;
               any other input is validated via Test-ConfigValue and re-prompted if invalid.

          4. After schema-backed keys, handles HotkeyVKeyCodes with custom logic:
               - Displays an informational note about the '#' key being layout-dependent.
               - Shows a TextPrompt with the current codes as comma-separated hex strings.
               - Accepts empty input (keep current), '[Reset to default]', or a new value as
                 comma-separated hex (e.g. "0x11, 0x10, 0xDC") or decimal integers.
               - Each parsed code is validated to be in the range 0x01-0xFE (1-254).
               - On validation failure, writes a red error line and re-prompts.

          5. After all keys, renders a SelectionPrompt "Save changes?" with choices:
               - 'Yes -- save now'                              -> calls Save-ModuleSettings; success panel.
               - 'Reset ALL EmergencyStop settings to defaults' -> replaces the entire EmergencyStop
                                                                    section with defaults; saves; success panel.
               - 'Discard changes'                             -> returns without saving; info panel.

        EmergencyStop keys covered (in order):
          AutoStart, MouseGestureEnabled, PollIntervalMs, MouseGestureHoldDurationMs,
          HotkeyVKeyCodes

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for all rendering and input.
        Pass [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole() for production use,
        or a [Spectre.Console.Testing.TestConsole]::new() instance in Pester tests.

    .OUTPUTS
        None

    .EXAMPLE
        $console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        Show-EmergencyStopConfigScreen -Console $console

    .NOTES
        The $Console parameter is the testability injection point.  All rendering and input
        is routed through this interface so Pester tests can inject a TestConsole and assert
        on its Output property without requiring a live terminal.

        HotkeyVKeyCodes is not stored in $script:ConfigValidationSchema because it is a
        variable-length integer array with VKey-specific range constraints (0x01-0xFE)
        rather than the fixed min/max pattern used by other intArray keys.  Validation is
        therefore performed inline in this function.

        VKey note: Virtual key code 0xDC is the '#' key on UK keyboard layouts.  On US
        layouts, '#' requires Shift+3 (VK code 0x33).  Users on non-UK layouts may need
        to reconfigure HotkeyVKeyCodes.  The README documents the default hotkey and the
        keyboard-layout caveat in detail.

        Type coercion for int keys: values entered as strings are converted to [int] before
        being stored on the config object, matching ConvertFrom-Json behaviour.

        '[Reset to default]': this literal string (including the brackets) is the recognised
        sentinel to reset an individual key.  It is case-insensitive.

        'Reset ALL EmergencyStop settings to defaults' on the save prompt replaces the entire
        EmergencyStop sub-object (including HotkeyVKeyCodes) with a fresh copy from
        Get-DefaultModuleSettings -- any per-key changes made earlier in the same session
        are discarded.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    # -- Load current configuration --------------------------------------------
    $config   = Get-ModuleConfiguration
    $defaults = Get-DefaultModuleSettings

    # -- Ordered list of schema-backed EmergencyStop keys ---------------------
    # Type drives which prompt style is used: 'bool' -> ConfirmationPrompt, else TextPrompt.
    $emergencyStopKeyDefs = @(
        @{
            Key    = 'EmergencyStop.AutoStart'
            Type   = 'bool'
            Get    = { param($c) $c.EmergencyStop.AutoStart }
            Set    = { param($c, $v) $c.EmergencyStop.AutoStart = [bool]$v }
            DefGet = { param($d) $d.EmergencyStop.AutoStart }
        },
        @{
            Key    = 'EmergencyStop.MouseGestureEnabled'
            Type   = 'bool'
            Get    = { param($c) $c.EmergencyStop.MouseGestureEnabled }
            Set    = { param($c, $v) $c.EmergencyStop.MouseGestureEnabled = [bool]$v }
            DefGet = { param($d) $d.EmergencyStop.MouseGestureEnabled }
        },
        @{
            Key    = 'EmergencyStop.PollIntervalMs'
            Type   = 'int'
            Get    = { param($c) $c.EmergencyStop.PollIntervalMs }
            Set    = { param($c, $v) $c.EmergencyStop.PollIntervalMs = [int]$v }
            DefGet = { param($d) $d.EmergencyStop.PollIntervalMs }
        },
        @{
            Key    = 'EmergencyStop.MouseGestureHoldDurationMs'
            Type   = 'int'
            Get    = { param($c) $c.EmergencyStop.MouseGestureHoldDurationMs }
            Set    = { param($c, $v) $c.EmergencyStop.MouseGestureHoldDurationMs = [int]$v }
            DefGet = { param($d) $d.EmergencyStop.MouseGestureHoldDurationMs }
        }
    )

    # -- Helper: build a human-readable constraint string from a schema rule --
    $buildConstraintString = {
        param($rule)
        if ($null -eq $rule) { return '' }
        switch ($rule.Type) {
            'bool' { return 'yes or no' }
            'int'  {
                if ($rule.ContainsKey('Min') -and $rule.ContainsKey('Max')) {
                    return "integer $($rule.Min)-$($rule.Max)"
                }
                return 'integer'
            }
            default { return '' }
        }
    }

    # -- Step 1: Render summary table of current values -----------------------
    $table = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(
        @('Setting', 'Current Value', 'Allowed / Range', 'Description')
    )

    foreach ($def in $emergencyStopKeyDefs) {
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

    # HotkeyVKeyCodes row -- not in schema; formatted as comma-separated hex strings
    $currentHotkeys = $config.EmergencyStop.HotkeyVKeyCodes
    $hotkeysDisplay = ($currentHotkeys | ForEach-Object { '0x{0:X2}' -f $_ }) -join ', '

    [Spectre.Console.TableExtensions]::AddRow(
        $table,
        [string[]]@(
            'EmergencyStop.HotkeyVKeyCodes',
            [Spectre.Console.Markup]::Escape($hotkeysDisplay),
            'comma-separated hex or decimal; each 0x01-0xFE',
            'Virtual key codes that must all be held simultaneously to trigger emergency stop'
        )
    ) | Out-Null

    $Console.Write($table)

    # -- Step 2: Prompt for each schema-backed key in turn --------------------
    foreach ($def in $emergencyStopKeyDefs) {
        $rule          = $script:ConfigValidationSchema[$def.Key]
        $description   = if ($rule -and $rule.Description) { $rule.Description } else { $def.Key }
        $constraintStr = & $buildConstraintString $rule

        if ($def.Type -eq 'bool') {
            # -- Bool: ConfirmationPrompt (yes/no) ----------------------------
            $currentValue  = & $def.Get $config
            $promptText    = "$description [[current: $currentValue]]:"
            $confirmPrompt = [Spectre.Console.ConfirmationPrompt]::new($promptText)
            $confirmPrompt.DefaultValue = [bool]$currentValue
            $newValue = $confirmPrompt.Show($Console)
            & $def.Set $config $newValue
        }
        else {
            # -- int: TextPrompt (same pattern as Show-LoggingConfigScreen) ---
            while ($true) {
                $currentValue = & $def.Get $config
                $promptText   = "$description [[current: $currentValue]] ($constraintStr). Press Enter to keep:"

                $textPrompt = [Spectre.Console.TextPrompt[string]]::new($promptText)
                $textPrompt.AllowEmpty = $true
                $answer = $textPrompt.Show($Console)

                # Empty -> keep current value
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

                # Invalid -- show error in red and re-prompt
                $Console.Write(
                    [Spectre.Console.Markup]::new("[red]$([Spectre.Console.Markup]::Escape($validation.Message))[/]`n")
                )
            }
        }
    }

    # -- Step 2b: HotkeyVKeyCodes -- custom VKey validation -------------------
    # Informational note: '#' is VK_OEM_5 (0xDC) on UK layouts; layout-dependent elsewhere.
    $Console.Write(
        [Spectre.Console.Markup]::new(
            "[grey]Note: '#' key is 0xDC on UK layouts and layout-dependent on others. See README for details.[/]`n"
        )
    )

    while ($true) {
        $currentHotkeyArr = $config.EmergencyStop.HotkeyVKeyCodes
        $hexDisplay       = ($currentHotkeyArr | ForEach-Object { '0x{0:X2}' -f $_ }) -join ', '
        $vkeyPromptText   = "Hotkey VKey codes (comma-separated hex or decimal; each 0x01-0xFE) [[current: $hexDisplay]]. Press Enter to keep:"

        $vkeyPrompt            = [Spectre.Console.TextPrompt[string]]::new($vkeyPromptText)
        $vkeyPrompt.AllowEmpty = $true
        $vkeyAnswer            = $vkeyPrompt.Show($Console)

        # Empty -> keep current value
        if ([string]::IsNullOrEmpty($vkeyAnswer)) {
            break
        }

        # Reset sentinel (case-insensitive)
        if ($vkeyAnswer -ieq '[Reset to default]') {
            $config.EmergencyStop.HotkeyVKeyCodes = $defaults.EmergencyStop.HotkeyVKeyCodes
            break
        }

        # Parse and validate comma-separated hex or decimal integers
        $parsedCodes = [System.Collections.Generic.List[int]]::new()
        $errMsg      = $null
        $parts       = $vkeyAnswer -split '\s*,\s*'

        foreach ($part in $parts) {
            $partTrimmed = $part.Trim()
            if ([string]::IsNullOrEmpty($partTrimmed)) { continue }

            $codeValue = 0

            if ($partTrimmed -match '^0[xX][0-9a-fA-F]+$') {
                # Hex input -- strip '0x' prefix before passing to [Convert]::ToInt32
                try   { $codeValue = [Convert]::ToInt32($partTrimmed.Substring(2), 16) }
                catch { $errMsg = "Could not parse '$partTrimmed' as a hexadecimal integer."; break }
            }
            elseif (-not [int]::TryParse($partTrimmed, [ref]$codeValue)) {
                $errMsg = "Could not parse '$partTrimmed' as an integer."
                break
            }

            if ($codeValue -lt 1 -or $codeValue -gt 254) {
                $errMsg = "VKey code $codeValue (0x$($codeValue.ToString('X2'))) is outside the valid range 0x01-0xFE (1-254)."
                break
            }

            $parsedCodes.Add($codeValue)
        }

        if (-not $errMsg -and $parsedCodes.Count -eq 0) {
            $errMsg = 'At least one VKey code must be provided.'
        }

        if ($errMsg) {
            $Console.Write(
                [Spectre.Console.Markup]::new("[red]$([Spectre.Console.Markup]::Escape($errMsg))[/]`n")
            )
            continue
        }

        $config.EmergencyStop.HotkeyVKeyCodes = $parsedCodes.ToArray()
        break
    }

    # -- Step 3: Save / reset / discard ---------------------------------------
    $savePrompt       = [Spectre.Console.SelectionPrompt[string]]::new()
    $savePrompt.Title = 'Save changes?'
    $savePrompt.AddChoice('Yes - save now')                                 | Out-Null
    $savePrompt.AddChoice('Reset ALL EmergencyStop settings to defaults')   | Out-Null
    $savePrompt.AddChoice('Discard changes')                                | Out-Null

    $saveChoice = $savePrompt.Show($Console)

    switch ($saveChoice) {

        'Yes - save now' {
            Save-ModuleSettings -Config $config

            $successPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'Emergency stop settings saved successfully.',
                '[green]Saved[/]'
            )
            $Console.Write($successPanel)

            Write-LastWarLog -Level Info `
                -Message 'EmergencyStop settings saved by user via configuration screen.' `
                -FunctionName 'Show-EmergencyStopConfigScreen'
        }

        'Reset ALL EmergencyStop settings to defaults' {
            $config.EmergencyStop = $defaults.EmergencyStop

            Save-ModuleSettings -Config $config

            $successPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'All EmergencyStop settings have been reset to their default values and saved.',
                '[green]Reset & Saved[/]'
            )
            $Console.Write($successPanel)

            Write-LastWarLog -Level Info `
                -Message 'All EmergencyStop settings reset to defaults by user via configuration screen.' `
                -FunctionName 'Show-EmergencyStopConfigScreen'
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

