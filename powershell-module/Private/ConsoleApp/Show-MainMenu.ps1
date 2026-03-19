function Show-MainMenu {
    <#
    .SYNOPSIS
        Displays the application main menu and returns the user's selection as an identifier string.

    .DESCRIPTION
        Renders a Spectre.Console SelectionPrompt with the following choices:
          - Select target window
          - Configure module
          - Record macro        (only shown when a target window has been configured)
          - Run macro           (only shown when a target window is configured AND *.json
                                 files exist in $env:APPDATA\LastWarAutoScreenshot\Macros)
          - Manage macros       (only shown when *.json files exist in
                                 $env:APPDATA\LastWarAutoScreenshot\Macros)
          - Manage schedules
          - Storage info
          - Exit

        The function calls Get-ModuleConfiguration to determine whether a target window has
        been configured (ProcessName is non-empty).  It also checks the macros directory
        ($env:APPDATA\LastWarAutoScreenshot\Macros) for saved macro files before building
        the prompt.  A macro is any file matching *.json in that folder
        (naming convention: yyyyMMdd_HHmmss_<name>.json).

        Returns a string identifier corresponding to the user's selection:
          'SelectWindow' | 'Configure' | 'RecordMacro' | 'RunMacro' | 'ManageMacros' |
          'ManageSchedules' | 'StorageInfo' | 'Exit'

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance to use for rendering and input.
        Pass [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole() for production use,
        or a [Spectre.Console.Testing.TestConsole]::new() instance in Pester tests.

    .OUTPUTS
        String
        One of: 'SelectWindow', 'Configure', 'RecordMacro', 'RunMacro', 'ManageMacros', 'ManageSchedules', 'StorageInfo', 'Exit'

    .EXAMPLE
        $console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        $choice  = Show-MainMenu -Console $console
        switch ($choice) {
            'SelectWindow' { Show-WindowSelectionScreen -Console $console }
            'Exit'         { return }
        }

    .NOTES
        The $Console parameter is the testability injection point.  All rendering and input
        is routed through this interface so that Pester tests can inject a TestConsole and
        assert directly on its Output property without requiring a live terminal.

        Macro detection: the macros directory is not created automatically by this
        function.  If the directory does not exist, Get-ChildItem returns nothing and the
        'Run macro' option is rendered as disabled.  The directory is created when the
        first macro is recorded.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    # Detect whether a target window has been configured for this session
    $config = Get-ModuleConfiguration
    $hasTargetWindow = $config.PSObject.Properties['ProcessName'] -and
                       -not [string]::IsNullOrEmpty($config.ProcessName)

    # Detect saved macros
    $macroFolder = $script:MacrosPath
    $macroFiles  = @()
    if (Test-Path $macroFolder -PathType Container) {
        $macroFiles = @(Get-ChildItem -Path $macroFolder -Filter '*.json' -ErrorAction SilentlyContinue)
    }
    $hasMacros = $macroFiles.Count -gt 0

    # Build the SelectionPrompt
    $choices = [System.Collections.Generic.List[string]]::new()
    $choices.Add('Select target window')
    $choices.Add('Configure module')

    if ($hasTargetWindow) {
        $choices.Add('Record macro')
    }

    if ($hasTargetWindow -and $hasMacros) {
        $choices.Add('Run macro')
    }

    if ($hasMacros) {
        $choices.Add('Manage macros')
    }

    $choices.Add('Manage schedules')
    $choices.Add('Storage info')
    $choices.Add('Exit')

    $prompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt('What would you like to do?', $choices.ToArray())

    $selection  = $prompt.Show($Console)

    switch ($selection) {
        'Select target window' { return 'SelectWindow'  }
        'Configure module'     { return 'Configure'     }
        'Record macro'         { return 'RecordMacro'   }
        'Run macro'            { return 'RunMacro'      }
        'Manage macros'            { return 'ManageMacros'     }
        'Manage schedules'         { return 'ManageSchedules'  }
        'Storage info'             { return 'StorageInfo'      }
        default                    { return 'Exit'             }
    }
}

