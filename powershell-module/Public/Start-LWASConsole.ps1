function Start-LWASConsole {
    <#
    .SYNOPSIS
        Launches the Last War Auto Screenshot interactive console application.

    .DESCRIPTION
        Entry point for the console application. On startup it:
          0. Checks for event log source initialization failure. If the event log source
             'LastWarAutoScreenshot' could not be created during module load, displays a
             critical error panel with remediation instructions and waits for user acknowledgement
             before exiting. This prevents logs from being silently discarded.
          1. Validates the saved module configuration (Invoke-StartupConfigValidation) and
             displays any errors or warnings as a Spectre.Console Panel. If validation issues
             are found, the user is presented with a selection prompt offering two options:
             'Configure Module' (opens the configuration screen) or 'Exit' (exits the app).
             If 'Exit' is selected, the function returns immediately. If 'Configure Module' is
             selected, the config menu is shown.
          2. Clears window-target fields from the saved configuration so the user must
             select a fresh target window on each invocation.
          3. Once validation is complete (or config is updated and validated), enters an
             infinite loop rendering the main menu via Show-MainMenu.
          3. Dispatches each selection to the relevant screen function:
               SelectWindow     → Show-WindowSelectionScreen   (Phase 1)
               Configure        → Show-ConfigMenuScreen         (Phase 3)
               StorageInfo      → Show-StorageInfoScreen        (Phase 3, inline)
               RecordMacro      → Show-RecordMacroScreen        (Phase 4)
               RunMacro         → Show-RunMacroScreen           (Phase 4)
               ManageMacros     → Show-ManageMacrosScreen       (Phase 4)
               ManageSchedules  → Show-ScheduleScreen           (Phase 6)
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
        Start-LWASConsole

    .EXAMPLE
        # Inject a TestConsole for Pester tests.
        $testConsole = [Spectre.Console.Testing.TestConsole]::new()
        # ... queue input keys on $testConsole.Input ...
        Start-LWASConsole -Console $testConsole

    .NOTES
        Event log source initialization:
          If the event log source 'LastWarAutoScreenshot' fails to initialise during module
          load (e.g. because the module was not run as Administrator), the global flag
          $global:LastWarAutoScreenshot_LoggingInitFailed is set. This function checks
          that flag at startup and displays a critical error panel with remediation
          instructions before exiting. This prevents silent failures where logs are
          discarded without the user knowing.

        $Console injection pattern:
          Every screen function in Private\ConsoleApp\ accepts -Console [IAnsiConsole].
          This single injection point allows all rendering to be tested without a live
          terminal.  Production callers pass nothing; the default value creates the real
          console.  Test callers pass a TestConsole instance.

        Alternate screen buffers:
          The entire main-menu loop (figlet + menu + dispatch) runs inside a single
          RunInAlternateScreen call.  The buffer is cleared at the top of every loop
          iteration so returning from any sub-screen always presents a clean slate.
          Sub-screens that need their own isolated buffer (Configure, RunMacro,
          ManageMacros) open a nested alternate buffer via a further
          RunInAlternateScreen call.
          Show-WindowSelectionScreen, Show-RecordMacroScreen, and
          Show-StorageInfoScreen run inline in the main alternate buffer (no nested
          buffer).  Nesting AlternateScreen calls is not supported by terminals —
          the inner ESC[?1049l exits the alternate buffer entirely, returning to the
          primary buffer.  Screens that do not require a fully clean buffer must
          run inline to avoid this.  RunInAlternateScreen gracefully degrades — if the
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

    # Check for critical event log source initialization failure
    if ($global:LastWarAutoScreenshot_LoggingInitFailed) {
        $errorMsg = @"
[red][[CRITICAL ERROR]][/]

Event Log source 'LastWarAutoScreenshot' could not be created.

To enable event logging, rerun Start-LWASConsole in an admin window once, or manually run the following command in PowerShell as Administrator:

    New-EventLog -LogName Application -Source "LastWarAutoScreenshot"

Until this is resolved, logs will be written to file instead.
"@
        $errorPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel($errorMsg, '[red]Event Log Initialization Failed[/]')
        $Console.Write($errorPanel) | Out-Null
        $null = Read-Host 'Press Enter to exit'
        return
    }

    # Run startup config validation; any panels are written inside this function
    $validationResult = Invoke-StartupConfigValidation -Console $Console

    # Check again for event log initialization failure (may have occurred during validation)
    if ($global:LastWarAutoScreenshot_LoggingInitFailed) {
        $errorMsg = @"
[red][[CRITICAL ERROR]][/]

Event Log source 'LastWarAutoScreenshot' could not be created.

To enable event logging, rerun Start-LWASConsole in an admin window once, or manually run the following command in PowerShell as Administrator:

    New-EventLog -LogName Application -Source "LastWarAutoScreenshot"

Until this is resolved, logs will be written to file instead.
"@
        $errorPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel($errorMsg, '[red]Event Log Initialization Failed[/]')
        $Console.Write($errorPanel) | Out-Null
        $null = Read-Host 'Press Enter to exit'
        return
    }

    # Handle user action from validation warnings/errors
    if ($validationResult.UserAction -eq "Exit") {
        return
    }
    elseif ($validationResult.UserAction -eq "ConfigureModule") {
        $null = Show-ConfigMenuScreen -Console $Console
    }

    # Clear window-target fields from config on every invocation so the user must
    # select a fresh target window each time the application starts.
    $startupConfig = Get-ModuleConfiguration
    $settingsOnlyConfig = [PSCustomObject]@{
        Logging       = $startupConfig.Logging
        MouseControl  = $startupConfig.MouseControl
        EmergencyStop = $startupConfig.EmergencyStop
        Screenshots   = $startupConfig.Screenshots
        CodeEditor    = $startupConfig.CodeEditor
    }
    Save-ModuleSettings -Config $settingsOnlyConfig | Out-Null

    # $mainBlock is defined WITHOUT GetNewClosure() so that it retains the module's parse-time
    # session state binding. GetNewClosure() strips the module session state, causing private
    # functions (Show-MainMenu, Show-WindowSelectionScreen, etc.) to be unresolvable inside
    # the closure. $Console is received as a parameter; Invoke-InAlternateScreen passes it.
    $mainBlock = {
        param([Spectre.Console.IAnsiConsole]$Console)
        while ($true) {
            # Clear the buffer on every iteration so returning from a sub-screen always
            # starts with a clean slate rather than leftover output.
            $Console.Clear($true)

            # Re-render the application title above the menu on each iteration.
            $figlet = [Spectre.Console.FigletText]::new('Last War Auto Screenshot')
            $figlet.Justification = [Spectre.Console.Justify]::Center
            $titlePanel = [Spectre.Console.Panel]::new($figlet)
            $titlePanel.Expand = $false
            $titlePanel.Padding = [Spectre.Console.Padding]::new(0, 0, 0, 1)
            $Console.Write($titlePanel) | Out-Null

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

                'StorageInfo' {
                    Show-StorageInfoScreen -Console $Console
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
                    Show-ManageMacrosScreen -Console $Console
                }

                'ManageSchedules' {
                    $screenBlock = {
                        param([Spectre.Console.IAnsiConsole]$Console)
                        Show-ScheduleScreen -Console $Console
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

