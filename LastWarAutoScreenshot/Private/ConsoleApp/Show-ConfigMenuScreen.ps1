function Show-ConfigMenuScreen {
    <#
    .SYNOPSIS
        Displays the configuration area menu and dispatches to configuration sub-screens.

    .DESCRIPTION
        Renders a Spectre.Console SelectionPrompt labelled "Configuration area:" with the
        following choices:
          - Logging settings        → Show-LoggingConfigScreen
          - Mouse control settings  → Show-MouseControlConfigScreen  (Phase 5, task 5.3)
          - Emergency stop settings → Show-EmergencyStopConfigScreen (Phase 5, task 5.4)
          - Storage & log file info → Show-StorageInfoScreen          (Phase 6, task 6.3)
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
          Show-LoggingConfigScreen       - implemented in Phase 5, task 5.2
          Show-MouseControlConfigScreen  - stub in Phase 5, task 5.3
          Show-EmergencyStopConfigScreen - stub in Phase 5, task 5.4
          Show-StorageInfoScreen         - stub in Phase 6, task 6.3
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    while ($true) {

        $prompt       = [Spectre.Console.SelectionPrompt[string]]::new()
        $prompt.Title = 'Configuration area:'

        $prompt.AddChoice('[[Back to main menu]]')     | Out-Null
        $prompt.AddChoice('Logging settings')        | Out-Null
        $prompt.AddChoice('Mouse control settings')  | Out-Null
        $prompt.AddChoice('Emergency stop settings') | Out-Null
        $prompt.AddChoice('Storage & log file info') | Out-Null

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

