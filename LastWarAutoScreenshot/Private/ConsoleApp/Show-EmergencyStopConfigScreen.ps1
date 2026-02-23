function Show-EmergencyStopConfigScreen {
    <#
    .SYNOPSIS
        Stub for the Emergency Stop configuration screen. To be implemented in Phase 5, task 5.4.

    .DESCRIPTION
        Will display and allow editing of all EmergencyStop.* configuration keys using
        Spectre.Console TextPrompt and ConfirmationPrompt components.

        For HotkeyVKeyCodes (int array of variable length): values will be displayd as
        comma-separated hex strings (e.g. 0x11, 0x10, 0xDC) and accepted as
        comma-separated hex or decimal integers.  An informational note about the '#' key
        VKCode being layout-dependent will be shown on screen.

        Save/reset/discard options follow the same pattern as Show-LoggingConfigScreen.

        Not yet implemented — displays a "Not yet available" panel when called.

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for rendering and input.

    .OUTPUTS
        None

    .EXAMPLE
        $console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        Show-EmergencyStopConfigScreen -Console $console

    .NOTES
        Implementation scheduled for Phase 5, task 5.4.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    $stubPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
        'Emergency stop configuration is not yet available. This screen will be implemented in Phase 5, task 5.4.',
        'Emergency Stop Settings'
    )
    $Console.Write($stubPanel)
}
