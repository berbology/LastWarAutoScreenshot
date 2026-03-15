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
          - Set default code editor → opens a file dialog to select an editor executable
          - Edit module configuration → opens the config JSON in VSCode or Notepad
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
          Set default code editor        - implemented (WinForms SaveFileDialog)
          Edit module configuration      - implemented (opens JSON in VSCode or Notepad)
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
                'Set default code editor',
                'Edit module configuration'
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

            'Set default code editor' {
                $config = Get-ModuleConfiguration
                $initialDir = ''
                if ($config.CodeEditor) {
                    $initialDir = Split-Path -Path $config.CodeEditor -Parent
                }
                $selectedPath = Invoke-SelectCodeEditorDialog -InitialDirectory $initialDir
                if ($selectedPath) {
                    $config.CodeEditor = $selectedPath
                    Save-ModuleSettings -Config $config
                    $safeSelectedPath = $selectedPath -replace '\[', '[[' -replace '\]', ']]'
                    $Console.Write([Spectre.Console.Markup]::new("[green]Code editor updated to: $safeSelectedPath[/]`n")) | Out-Null
                }
            }

            'Edit module configuration' {
                $configPath = Join-Path -Path $env:APPDATA -ChildPath 'LastWarAutoScreenshot\WindowConfig.json'
                $editorConfig = Get-ModuleConfiguration
                $editorExe = $editorConfig.CodeEditor
                if ($editorExe -and (Test-Path -Path $editorExe -PathType Leaf)) {
                    # Launch via cmd.exe to suppress CLI log output (e.g. VS Code update/extension host messages)
                    $cmdArgs = "/c `"`"$editorExe`" `"$configPath`" 2>NUL 1>NUL`""
                    Start-Process -FilePath 'cmd.exe' -ArgumentList $cmdArgs -WindowStyle Hidden | Out-Null
                } else {
                    Start-Process -FilePath 'notepad.exe' -ArgumentList "`"$configPath`"" | Out-Null
                }
            }

            default {
                # '[Back to main menu]' or any unrecognised value - exit the loop
                return
            }
        }
    }
}

