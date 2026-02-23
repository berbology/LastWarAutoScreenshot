function Start-LastWarAutoScreenshot {
    <#
    .SYNOPSIS
        Launches the Last War Auto Screenshot interactive console application.

    .DESCRIPTION
        Entry point for the console application.  On startup it:
          1. Validates the saved module configuration (Invoke-StartupConfigValidation) and
             displays any errors or warnings as a Spectre.Console Panel before showing the
             main menu.  Validation issues do not abort startup - the user must acknowledge
             them by pressing Enter.
          2. Enters an infinite loop rendering the main menu via Show-MainMenu.
          3. Dispatches each selection to the relevant screen function:
               SelectWindow → Show-WindowSelectionScreen   (Phase 4)
               Configure    → Show-ConfigMenuScreen         (Phase 5)
               RecordMacro  → 'Not yet available' Panel stub
               RunMacro     → Phase 4 placeholder
               Exit         → breaks the loop and returns
          4. The loop restarts after each screen returns (except Exit).

    .PARAMETER Console
        Optional Spectre.Console IAnsiConsole instance used for all rendering and input.
        Defaults to [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole() which returns
        the real live terminal console.

        Inject a [Spectre.Console.Testing.TestConsole]::new() instance in Pester tests to
        assert on its Output property without requiring a live terminal.

    .EXAMPLE
        # Normal production usage - no parameters required.
        Start-LastWarAutoScreenshot

    .EXAMPLE
        # Inject a TestConsole for Pester tests.
        $testConsole = [Spectre.Console.Testing.TestConsole]::new()
        # ... queue input keys on $testConsole.Input ...
        Start-LastWarAutoScreenshot -Console $testConsole

    .NOTES
        $Console injection pattern:
          Every screen function in Private\ConsoleApp\ accepts -Console [IAnsiConsole].
          This single injection point allows all rendering to be tested without a live
          terminal.  Production callers pass nothing; the default value creates the real
          console.  Test callers pass a TestConsole instance.

        Phase notes:
          Show-WindowSelectionScreen is implemented in Phase 4 (task 4.1).
          Show-ConfigMenuScreen is implemented in Phase 5 (task 5.1).
          'Run macro' screen is implemented in Phase 4.
          Macro file naming convention: Private\Macros\yyyyMMdd_HHmmss_<name>.json
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [Spectre.Console.IAnsiConsole]$Console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
    )

    # Run startup config validation; any panels are written inside this function
    Invoke-StartupConfigValidation -Console $Console | Out-Null

    # Main application loop
    while ($true) {
        $choice = Show-MainMenu -Console $Console

        switch ($choice) {

            'SelectWindow' {
                # Phase 4 - Show-WindowSelectionScreen implemented in task 4.1
                Show-WindowSelectionScreen -Console $Console
            }

            'Configure' {
                # Phase 5 - Show-ConfigMenuScreen implemented in task 5.1
                Show-ConfigMenuScreen -Console $Console
            }

            'RecordMacro' {
                # Stub: macro recording is a Phase 4 feature
                $stubPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                    'Macro recording is not yet available. This feature will be implemented in a future release.',
                    'Record Macro'
                )
                $Console.Write($stubPanel)
            }

            'RunMacro' {
                # Phase 4 placeholder - macro running requires the recording feature first
            }

            'Exit' {
                return
            }
        }
    }
}

