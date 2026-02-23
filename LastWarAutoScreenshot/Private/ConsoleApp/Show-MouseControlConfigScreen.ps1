function Show-MouseControlConfigScreen {
    <#
    .SYNOPSIS
        Stub for the Mouse Control configuration screen. To be implemented in Phase 5, task 5.3.

    .DESCRIPTION
        Will display and allow editing of all MouseControl.* configuration keys using
        Spectre.Console TextPrompt and ConfirmationPrompt components.

        For bool keys (EasingEnabled, OvershootEnabled, MicroPausesEnabled, JitterEnabled)
        a ConfirmationPrompt (yes/no) will be used instead of a TextPrompt.

        For intArray keys a pair of prompts will be shown for min and max separately,
        validated as a unit via Test-ConfigValue after both values are entered.

        Save/reset/discard options follow the same pattern as Show-LoggingConfigScreen.

        Not yet implemented — displays a "Not yet available" panel when called.

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for rendering and input.

    .OUTPUTS
        None

    .EXAMPLE
        $console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        Show-MouseControlConfigScreen -Console $console

    .NOTES
        Implementation scheduled for Phase 5, task 5.3.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    $stubPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
        'Mouse control configuration is not yet available. This screen will be implemented in Phase 5, task 5.3.',
        'Mouse Control Settings'
    )
    $Console.Write($stubPanel)
}
