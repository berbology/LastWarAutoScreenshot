function Show-ConfigMenuScreen {
    <#
    .SYNOPSIS
        Displays the configuration area menu and dispatches to configuration sub-screens.

    .DESCRIPTION
        Renders a Spectre.Console SelectionPrompt labelled "Configuration area:" with the
        following choices:
          - Logging settings        → Show-LoggingConfigScreen
          - Mouse control settings  → Show-MouseControlConfigScreen
          - Emergency stop settings → Show-EmergencyStopConfigScreen
          - Screenshot settings     → Show-ScreenshotConfigScreen
          - Storage & log file info → Show-StorageInfoScreen
          - [Back to main menu]     → exits the loop and returns

        The function loops continuously, returning to this menu after each sub-screen
        closes, until the user selects "[Back to main menu]".

        All sub-screens receive the same $Console instance so the testability injection
        point propagates through the entire configuration hierarchy.

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for all rendering and input.
        Pass [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole() for production use,
        or a [Spectre.Console.Testing.TestConsole]::new() instance in Pester tests.

    .OUTPUTS
        None

    .EXAMPLE
        $console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        Show-ConfigMenuScreen -Console $console

    .NOTES
        The $Console parameter is the testability injection point.  All rendering and input
        is routed through this interface so Pester tests can inject a TestConsole and assert
        on its Output property without requiring a live terminal.

        Sub-screen implementation status:
          Show-LoggingConfigScreen       - implemented
          Show-MouseControlConfigScreen  - implemented
          Show-EmergencyStopConfigScreen - implemented
          Show-ScreenshotConfigScreen    - implemented
          Show-StorageInfoScreen         - implemented
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    while ($true) {

        $prompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
            'Configuration area:',
            @(
                '[[Back to main menu]]',
                'Logging settings',
                'Mouse control settings',
                'Emergency stop settings',
                'Screenshot settings',
                'Storage & log file info'
            )
        )
        $selection = $prompt.Show($Console)

        switch ($selection) {

            'Logging settings' {
                Show-LoggingConfigScreen -Console $Console
            }

            'Mouse control settings' {
                Show-MouseControlConfigScreen -Console $Console
            }

            'Emergency stop settings' {
                Show-EmergencyStopConfigScreen -Console $Console
            }

            'Screenshot settings' {
                Show-ScreenshotConfigScreen -Console $Console
            }

            'Storage & log file info' {
                Show-StorageInfoScreen -Console $Console
            }

            default {
                # '[Back to main menu]' or any unrecognised value - exit the loop
                return
            }
        }
    }
}

