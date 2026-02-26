function Show-WindowSelectionScreen {
    <#
    .SYNOPSIS
        Displays the window selection screen using Spectre.Console UI components.

    .DESCRIPTION
        Guides the user through selecting a target application window in four steps:

        1.  Sort selection - the user chooses how the window list is ordered.
        2.  Window enumeration - all open windows are enumerated.
        3.  Window selection - the user picks a window from a SelectionPrompt or
            chooses '[Back to main menu]' to cancel.
        4.  Window validation - Test-WindowHandleValid confirms the window is still
            open. If closed, an error panel is shown and the loop restarts from step 2
            (does NOT return to the main menu; the user must select again).
        5.  On a valid selection, the window is saved via Save-ModuleConfiguration, a
            success panel is displayed, and the window object is returned.

        Returns $null when the user cancels via '[Back to main menu]' or when no
        windows are found after enumeration.

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for all rendering and input.
        Pass [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole() for production,
        or a [Spectre.Console.Testing.TestConsole]::new() instance in Pester tests.

    .OUTPUTS
        PSCustomObject
        The selected window object (same shape as Get-EnumeratedWindows output), or
        $null when the user cancels or no windows are found.

    .EXAMPLE
        $console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        $window  = Show-WindowSelectionScreen -Console $console
        if ($window) { Write-Host "Selected: $($window.WindowTitle)" }

    .NOTES
        The $Console parameter is the testability injection point. In Pester tests,
        pre-queue keystrokes via $testConsole.Input.PushKey() before calling this
        function. The sort SelectionPrompt consumes keys first, followed by the window
        SelectionPrompt on every loop iteration.

        Window titles and process names that contain Spectre.Console markup characters
        ('[', ']') are escaped with [Spectre.Console.Markup]::Escape() before being
        placed in the SelectionPrompt choices, preventing rendering errors.

        Sorting: the sort order is chosen once (before the loop) and re-applied on
        each iteration. Sort options: Process name A-Z, Process name Z-A,
        Window title A-Z, Window title Z-A, Minimised first, Minimised last.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    # ── Step 1: Sort selection (shown once, before the main loop) ─────────────
    $sortPrompt       = [Spectre.Console.SelectionPrompt[string]]::new()
    $sortPrompt.Title = 'Sort windows by:'
    $sortPrompt.AddChoice('Process name (A-Z)') | Out-Null
    $sortPrompt.AddChoice('Process name (Z-A)') | Out-Null
    $sortPrompt.AddChoice('Window title (A-Z)') | Out-Null
    $sortPrompt.AddChoice('Window title (Z-A)') | Out-Null
    $sortPrompt.AddChoice('Minimised first')    | Out-Null
    $sortPrompt.AddChoice('Minimised last')     | Out-Null

    $sortChoice = $sortPrompt.Show($Console)

    # ── Main selection loop ────────────────────────────────────────────────────
    while ($true) {

        # ── Step 2: Enumerate and display windows ──────────────────────────────
        $allWindows = @(Get-EnumeratedWindows)

        if ($allWindows.Count -eq 0) {
            $errorPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'No windows found. Ensure at least one application is open and try again.',
                '[red]Error[/]'
            )
            $Console.Write($errorPanel)
            Write-LastWarLog -Level Error `
                -Message 'No windows found during window selection screen enumeration.' `
                -FunctionName 'Show-WindowSelectionScreen'
            return $null
        }

        # Apply the sort chosen in step 1
        $sortedWindows = switch ($sortChoice) {
            'Process name (A-Z)' { @($allWindows | Sort-Object ProcessName) }
            'Process name (Z-A)' { @($allWindows | Sort-Object ProcessName -Descending) }
            'Window title (A-Z)' { @($allWindows | Sort-Object WindowTitle) }
            'Window title (Z-A)' { @($allWindows | Sort-Object WindowTitle -Descending) }
            'Minimised first'    { @($allWindows | Sort-Object WindowState) }
            'Minimised last'     { @($allWindows | Sort-Object WindowState -Descending) }
            default              { @($allWindows | Sort-Object WindowTitle) }
        }

        # ── Step 3: Window selection prompt ────────────────────────────────────
        $selectionPrompt       = [Spectre.Console.SelectionPrompt[string]]::new()
        $selectionPrompt.Title = 'Select a window:'

        $choiceLabels = @()
        for ($i = 0; $i -lt $sortedWindows.Count; $i++) {
            $win         = $sortedWindows[$i]
            $choiceLabel = "$($i + 1): $([Spectre.Console.Markup]::Escape($win.ProcessName)) - $([Spectre.Console.Markup]::Escape($win.WindowTitle)) ($($win.WindowState))"
            $choiceLabels += $choiceLabel
            $selectionPrompt.AddChoice($choiceLabel) | Out-Null
        }
        $backChoice = [Spectre.Console.Markup]::Escape('[Back to main menu]')
        $selectionPrompt.AddChoice($backChoice) | Out-Null

        $selectedChoice = $selectionPrompt.Show($Console)

        if ($selectedChoice -eq $backChoice) {
            return $null
        }

        # Correlate the selected choice label back to the sorted window list
        $selectedWindow = $null
        for ($i = 0; $i -lt $sortedWindows.Count; $i++) {
            if ($selectedChoice -eq $choiceLabels[$i]) {
                $selectedWindow = $sortedWindows[$i]
                break
            }
        }

        if ($null -eq $selectedWindow) {
            Write-LastWarLog -Level Error `
                -Message "Could not correlate selected window choice to enumerated window object. Choice: '$selectedChoice'" `
                -FunctionName 'Show-WindowSelectionScreen'
            return $null
        }

        # ── Step 4: Validate window still exists ──────────────────────────────
        if (-not (Test-WindowHandleValid -WindowHandle $selectedWindow.WindowHandle)) {
            $closedPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'The selected window has closed. Please select another.',
                '[red]Error[/]'
            )
            $Console.Write($closedPanel)
            Write-LastWarLog -Level Error `
                -Message "Selected window '$($selectedWindow.WindowTitle)' is no longer valid. Re-displaying window list." `
                -FunctionName 'Show-WindowSelectionScreen'
            continue  # Loop back to step 2; do NOT return $null
        }

        # ── Step 5: Save and return ────────────────────────────────────────────
        Save-ModuleConfiguration -WindowObject $selectedWindow -Force

        $escapedSuccessTitle = [Spectre.Console.Markup]::Escape($selectedWindow.WindowTitle)
        $successPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
            "Window '[bold]$escapedSuccessTitle[/]' selected and saved to configuration.",
            '[green]Success[/]'
        )
        $Console.Write($successPanel)

        return $selectedWindow
    }
}

