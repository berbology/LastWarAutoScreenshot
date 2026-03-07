function Invoke-CaptureMousePosition {
    <#
    .SYNOPSIS
        Captures a mouse position relative to a target window, with Accept/Redo/Cancel flow.

    .DESCRIPTION
        Displays a positioning instruction, blocks until the user presses Enter, then
        captures the current cursor position.  Computes relative coordinates (0.0–1.0)
        within the supplied window bounds and prompts the user to Accept, Redo, or Cancel.

        If the captured position falls outside the window bounds the user is shown an
        error and the loop restarts from the positioning instruction without ever reaching
        the Accept/Redo/Cancel prompt.

        Returns a PSCustomObject with both relative and absolute coordinates on Accept,
        or $null when the user cancels.

    .PARAMETER WindowHandle
        The window handle used to retrieve bounds via Get-WindowBounds.  Accepts the
        same types as Get-WindowBounds (IntPtr, int, int64, or decimal/hex string).

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for all rendering and input.
        Pass [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole() for production,
        or a [Spectre.Console.Testing.TestConsole]::new() instance in Pester tests.

    .PARAMETER PromptMessage
        A Spectre.Console markup string displayed to instruct the user where to position
        the mouse before pressing Enter.

    .EXAMPLE
        $console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        $position = Invoke-CaptureMousePosition `
            -WindowHandle $window.WindowHandle `
            -Console $console `
            -PromptMessage 'Position the mouse over the [bold]Start[/] button and press Enter.'
        if ($position) {
            Write-Host "Captured: $($position.RelativeX), $($position.RelativeY)"
        }

    .OUTPUTS
        PSCustomObject
        An object with RelativeX [double], RelativeY [double], AbsoluteX [int], and
        AbsoluteY [int] properties on Accept, or $null when the user cancels.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        $WindowHandle,

        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console,

        [Parameter(Mandatory)]
        [string]$PromptMessage
    )

    while ($true) {

        # ── Step 1: Display positioning instruction ────────────────────────────
        $Console.Write([Spectre.Console.Markup]::new($PromptMessage))

        # ── Step 2: Block until the user presses Enter ────────────────────────
        [LastWarAutoScreenshot.ConsoleAppBridge]::CreateEmptyTextPrompt('').Show($Console) | Out-Null

        # ── Step 3: Capture absolute screen coordinates ────────────────────────
        $absolute = Invoke-GetCursorPosition

        # ── Step 4: Retrieve window bounds ────────────────────────────────────
        $bounds = Get-WindowBounds -WindowHandle $WindowHandle

        # ── Step 5: Compute relative coordinates ──────────────────────────────
        $relativeX = [math]::Round(($absolute.X - $bounds.Left) / $bounds.Width, 4)
        $relativeY = [math]::Round(($absolute.Y - $bounds.Top) / $bounds.Height, 4)

        # ── Step 6: Validate position is within the window ────────────────────
        if ($relativeX -lt 0.0 -or $relativeX -gt 1.0 -or $relativeY -lt 0.0 -or $relativeY -gt 1.0) {
            $Console.Write([Spectre.Console.Markup]::new("[red]Position is outside the target window. Please position the mouse within the window bounds.[/]`n"))
            continue
        }

        # ── Step 7: Display captured position ─────────────────────────────────
        $Console.Write([Spectre.Console.Markup]::new("[green]Position captured: ($relativeX, $relativeY) relative to window[/]`n"))

        # ── Step 8: Accept / Redo / Cancel prompt ─────────────────────────────
        $actionPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
            'What would you like to do?', @('Accept', 'Redo', 'Cancel')
        )
        $action = $actionPrompt.Show($Console)

        if ($action -eq 'Accept') {
            return [PSCustomObject]@{
                RelativeX = [double]$relativeX
                RelativeY = [double]$relativeY
                AbsoluteX = [int]$absolute.X
                AbsoluteY = [int]$absolute.Y
            }
        } elseif ($action -eq 'Cancel') {
            return $null
        }
        # 'Redo': fall through to restart the while loop from step 1
    }
}
