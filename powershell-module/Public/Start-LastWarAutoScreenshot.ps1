function Start-LastWarAutoScreenshot {
    <#
    .SYNOPSIS
        Launches the Last War Auto Screenshot interactive console application.

    .DESCRIPTION
        Entry point for the console application.  On startup it:
          1. Validates the saved module configuration (Invoke-StartupConfigValidation) and
             displays any errors or warnings as a Spectre.Console Panel. If validation issues
             are found, the user is presented with a selection prompt offering two options:
             'Configure Module' (opens the configuration screen) or 'Exit' (exits the app).
             If 'Exit' is selected, the function returns immediately. If 'Configure Module' is
             selected, the config menu is shown.
          2. Once validation is complete (or config is updated and validated), enters an
             infinite loop rendering the main menu via Show-MainMenu.
          3. Dispatches each selection to the relevant screen function:
               SelectWindow     → Show-WindowSelectionScreen   (Phase 1)
               Configure        → Show-ConfigMenuScreen         (Phase 3)
               ViewStorageInfo  → Show-StorageInfoScreen        (Phase 3)
               RecordMacro      → Show-RecordMacroScreen        (Phase 4)
               RunMacro         → Show-RunMacroScreen           (Phase 4)
               ManageMacros     → Show-ManageMacrosScreen       (Phase 4)
               Exit             → breaks the loop and returns
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

        Alternate screen buffers:
          The entire main-menu loop (figlet + menu + dispatch) runs inside a single
          RunInAlternateScreen call.  Sub-screens that need a clean buffer
          (Configure, RunMacro, ManageMacros, ViewStorageInfo) open a
          nested alternate buffer via a further RunInAlternateScreen call.
          Show-WindowSelectionScreen and Show-RecordMacroScreen run inline in the
          main alternate buffer (no nested buffer) so that their 'Saved' banners
          persist above the main menu, matching the pattern used by
          Show-LoggingConfigScreen inside Show-ConfigMenuScreen.  RunInAlternateScreen gracefully degrades — if the
          terminal (or injected TestConsole) does not advertise AlternateBuffer
          capability, the action is invoked directly in the current buffer without
          any ANSI sequences.  No manual TestConsole type checks are needed.

        Phase notes:
          Show-WindowSelectionScreen is implemented in Phase 1 (window management).
          Show-ConfigMenuScreen is implemented in Phase 3 (console app).
          Show-RecordMacroScreen, Show-RunMacroScreen, and Show-ManageMacrosScreen are
          implemented in Phase 4 (macro recording).
          Macro file naming convention: Private\Macros\yyyyMMdd_HHmmss_<name>.json
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [Spectre.Console.IAnsiConsole]$Console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
    )

    # Run startup config validation; any panels are written inside this function
    $validationResult = Invoke-StartupConfigValidation -Console $Console

    # Handle user action from validation warnings/errors
    if ($validationResult.UserAction -eq "Exit") {
        return
    }
    elseif ($validationResult.UserAction -eq "ConfigureModule") {
        $null = Show-ConfigMenuScreen -Console $Console
    }

    # $mainBlock is defined WITHOUT GetNewClosure() so that it retains the module's parse-time
    # session state binding. GetNewClosure() strips the module session state, causing private
    # functions (Show-MainMenu, Show-WindowSelectionScreen, etc.) to be unresolvable inside
    # the closure. $Console is received as a parameter; Invoke-InAlternateScreen passes it.
    $mainBlock = {
        param([Spectre.Console.IAnsiConsole]$Console)
        # Display the application title figlet once at the start of the alternate buffer
        $figlet = [Spectre.Console.FigletText]::new('Last War Auto Screenshot')
        $figlet.Justification = [Spectre.Console.Justify]::Center
        $titlePanel = [Spectre.Console.Panel]::new($figlet)
        $titlePanel.Expand = $false
        $titlePanel.Padding = [Spectre.Console.Padding]::new(0, 0, 0, 1)
        $Console.Write($titlePanel) | Out-Null

        while ($true) {
            $choice = Show-MainMenu -Console $Console

            switch ($choice) {

                'SelectWindow' {
                    Show-WindowSelectionScreen -Console $Console
                }

                'Configure' {
                    $screenBlock = {
                        param([Spectre.Console.IAnsiConsole]$Console)
                        Show-ConfigMenuScreen -Console $Console
                    }
                    Invoke-InAlternateScreen -Console $Console -Action $screenBlock
                }

                'ViewStorageInfo' {
                    $screenBlock = {
                        param([Spectre.Console.IAnsiConsole]$Console)
                        Show-StorageInfoScreen -Console $Console
                    }
                    Invoke-InAlternateScreen -Console $Console -Action $screenBlock
                }

                'RecordMacro' {
                    Show-RecordMacroScreen -Console $Console
                }

                'RunMacro' {
                    $screenBlock = {
                        param([Spectre.Console.IAnsiConsole]$Console)
                        Show-RunMacroScreen -Console $Console
                    }
                    Invoke-InAlternateScreen -Console $Console -Action $screenBlock
                }

                'ManageMacros' {
                    $screenBlock = {
                        param([Spectre.Console.IAnsiConsole]$Console)
                        Show-ManageMacrosScreen -Console $Console
                    }
                    Invoke-InAlternateScreen -Console $Console -Action $screenBlock
                }

                'Exit' {
                    return
                }
            }
        }
    }

    Invoke-InAlternateScreen -Console $Console -Action $mainBlock
}

