function Show-EmergencyStopConfigScreen {
    <#
    .SYNOPSIS
        Displays and edits all EmergencyStop configuration settings via Spectre.Console prompts.

    .DESCRIPTION
        Guides the user through reviewing and optionally updating every EmergencyStop key that
        exists in the $script:ConfigValidationSchema, plus the HotkeyKeyNames key which
        requires custom parsing and validation.

        Workflow:
          1. Loads the current configuration via Get-ModuleConfiguration.
          2. Renders a Spectre.Console Table showing each EmergencyStop key with its current
             value, allowed values or range, and a human-readable description sourced
             from $script:ConfigValidationSchema.  The HotkeyKeyNames row is always shown
             as the stored key combination string (e.g. 'Ctrl+Alt+Q').
          3. Iterates each schema-backed EmergencyStop key in order.  The prompt type depends
             on the key type:

             Bool keys (AutoStart):
               Uses a ConfirmationPrompt (yes/no).  DefaultValue is set to the current value
               so pressing Enter keeps it unchanged in interactive terminals.  In tests, push
               'y' or 'n' explicitly via $tc.Input.PushTextWithEnter('y').

             Int keys (PollIntervalMs):
               Uses a TextPrompt (identical pattern to Show-LoggingConfigScreen):
                 "<Description> [<value>] (<constraints>):"
               Empty input -> keep current; '[Reset to default]' -> restore default;
               any other input is validated via Test-ConfigValue and re-prompted if invalid.

          4. After schema-backed keys, handles HotkeyKeyNames with custom logic:
               - Displays an informational note about the key name input format.
               - Shows a TextPrompt displaying the current key combination string.
               - Accepts empty input (keep current), '[Reset to default]', or a new key
                 combination (e.g. 'Ctrl+Shift+P', 'Ctrl+Alt+F1', 'Alt+F10').
               - Input is validated via Test-HotkeyString: modifiers must come first, the
                 last key must not be a modifier, no duplicates, all names must be recognised.
               - On validation failure, writes a red error line and re-prompts.
               - On success, stores the normalised canonical form.

          5. After all keys, renders a SelectionPrompt "Save changes?" with choices:
               - 'Yes -- save now'                              -> calls Save-ModuleSettings; success panel.
               - 'Reset ALL EmergencyStop settings to defaults' -> replaces the entire EmergencyStop
                                                                    section with defaults; saves; success panel.
               - 'Discard changes'                             -> returns without saving; info panel.

        EmergencyStop keys covered (in order):
          AutoStart, PollIntervalMs, HotkeyKeyNames

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

        HotkeyKeyNames is not stored in $script:ConfigValidationSchema because it requires
        specialised structural validation (modifier order, key name lookup) beyond the
        fixed type/range pattern used by schema-backed keys.  Validation is performed
        inline via Test-HotkeyString.

        Default hotkey: 'Ctrl+Alt+Q', which on UK keyboard layouts corresponds to VKey
        codes @(17, 16, 220).  On other layouts where '#' requires a modifier to produce,
        the key cannot be used as a standalone key name; users should reconfigure
        HotkeyKeyNames using a combination available on their keyboard (e.g. 'Ctrl+Shift+P').

        Type coercion for int keys: values entered as strings are converted to [int] before
        being stored on the config object, matching ConvertFrom-Json behaviour.

        '[Reset to default]': this literal string (including the brackets) is the recognised
        sentinel to reset an individual key.  It is case-insensitive.

        'Reset ALL EmergencyStop settings to defaults' on the save prompt replaces the entire
        EmergencyStop sub-object (including HotkeyKeyNames) with a fresh copy from
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
            Key    = 'EmergencyStop.PollIntervalMs'
            Type   = 'int'
            Get    = { param($c) $c.EmergencyStop.PollIntervalMs }
            Set    = { param($c, $v) $c.EmergencyStop.PollIntervalMs = [int]$v }
            DefGet = { param($d) $d.EmergencyStop.PollIntervalMs }
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
                    return "$($rule.Min)-$($rule.Max)"
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
                ($def.Key -replace '^.*\.', ''),
                [Spectre.Console.Markup]::Escape("$currentValue"),
                [Spectre.Console.Markup]::Escape($constraintStr),
                [Spectre.Console.Markup]::Escape($descriptionStr)
            )
        ) | Out-Null
    }

    # HotkeyKeyNames row -- not in schema; displayed as-is (stored as a key combination string)
    $currentHotkeyNames = $config.EmergencyStop.HotkeyKeyNames

    [Spectre.Console.TableExtensions]::AddRow(
        $table,
        [string[]]@(
            'HotkeyKeyNames',
            [Spectre.Console.Markup]::Escape($currentHotkeyNames),
            'e.g. Ctrl+Shift+P, Ctrl+Alt+F1',
            'Key combination that must be held simultaneously to trigger emergency stop'
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
            $promptText    = "${description}:"
            $confirmPrompt = [Spectre.Console.ConfirmationPrompt]::new($promptText)
            $confirmPrompt.DefaultValue = [bool]$currentValue
            $newValue = $confirmPrompt.Show($Console)
            & $def.Set $config $newValue
        }
        else {
            # -- int: TextPrompt (same pattern as Show-LoggingConfigScreen) ---
            while ($true) {
                $currentValue = & $def.Get $config
                $promptText   = "$description [blue]($constraintStr)[/] [green][[$currentValue]][/]:"

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

    # -- Step 2b: HotkeyKeyNames -- key combination name validation -----------
    # Informational note: key name format and UK layout caveat.
    $Console.Write(
        [Spectre.Console.Markup]::new(
            "[grey]Note: Enter a key combination using key names separated by '+' (e.g. Ctrl+Shift+P). " +
            "Modifiers (Ctrl, Shift, Alt, Win) must precede the trigger key. " +
            "The default 'Ctrl+Alt+Q' requires a UK keyboard layout.[/]`n"
        )
    )

    while ($true) {
        $currentKeyNames  = $config.EmergencyStop.HotkeyKeyNames
        $hotkeyPromptText = "Emergency stop key combination (e.g. Ctrl+Shift+P, Ctrl+Alt+F1, Alt+F10) [green][[$currentKeyNames]][/]:"

        $hotkeyPrompt            = [Spectre.Console.TextPrompt[string]]::new($hotkeyPromptText)
        $hotkeyPrompt.AllowEmpty = $true
        $hotkeyAnswer            = $hotkeyPrompt.Show($Console)

        # Empty -> keep current value
        if ([string]::IsNullOrEmpty($hotkeyAnswer)) {
            break
        }

        # Reset sentinel (case-insensitive)
        if ($hotkeyAnswer -ieq '[Reset to default]') {
            $config.EmergencyStop.HotkeyKeyNames = $defaults.EmergencyStop.HotkeyKeyNames
            break
        }

        # Validate the entered key combination
        $hotkeyValidation = Test-HotkeyString -HotkeyString $hotkeyAnswer
        if ($hotkeyValidation.Valid) {
            $config.EmergencyStop.HotkeyKeyNames = $hotkeyValidation.Normalized
            break
        }

        # Invalid -- show error in red and re-prompt
        $Console.Write(
            [Spectre.Console.Markup]::new("[red]$([Spectre.Console.Markup]::Escape($hotkeyValidation.Message))[/]`n")
        )
    }

    # -- Step 3: Save / reset / discard ---------------------------------------
    $savePrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
        'Save changes?',
        @(
            'Yes - save now',
            'Reset ALL EmergencyStop settings to defaults',
            'Discard changes'
        )
    )
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

