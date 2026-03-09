function Show-MainMenu {
    <#
    .SYNOPSIS
        Displays the application main menu and returns the user's selection as an identifier string.

    .DESCRIPTION
        Renders a Spectre.Console SelectionPrompt with the following choices:
          - Select target window
          - Configure module
          - Record macro
          - Run macro (disabled and shown as a non-selectable group header when no *.json files
            exist in the module's Private\Macros\ folder; a normal selectable choice otherwise)
          - Manage macros (always visible regardless of whether macros exist)
          - View module storage info
          - Exit

        The function checks the Private\Macros\ folder for saved macro files before building
        the prompt.  A macro is any file matching *.json in that folder (naming convention:
        yyyyMMdd_HHmmss_<name>.json).

        Returns a string identifier corresponding to the user's selection:
          'SelectWindow' | 'Configure' | 'RecordMacro' | 'RunMacro' | 'ManageMacros' |
          'ViewStorageInfo' | 'Exit'

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance to use for rendering and input.
        Pass [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole() for production use,
        or a [Spectre.Console.Testing.TestConsole]::new() instance in Pester tests.

    .OUTPUTS
        String
        One of: 'SelectWindow', 'Configure', 'RecordMacro', 'RunMacro', 'ManageMacros', 'ViewStorageInfo', 'Exit'

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

        Macro detection: the Private\Macros\ folder is not created automatically by this
        function.  If the folder does not exist, Get-ChildItem returns nothing and the 'Run
        macro' option is rendered as disabled.  The folder is created when the first macro is
        recorded (Phase 4).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    # Detect saved macros
    $macroFolder = Join-Path $script:ModuleRootPath 'Private\Macros'
    $macroFiles  = @()
    if (Test-Path $macroFolder -PathType Container) {
        $macroFiles = @(Get-ChildItem -Path $macroFolder -Filter '*.json' -ErrorAction SilentlyContinue)
    }
    $hasMacros = $macroFiles.Count -gt 0

    # Build the SelectionPrompt
    $choices = [System.Collections.Generic.List[string]]::new()
    $choices.Add('Select target window')
    $choices.Add('Configure module')
    $choices.Add('Record macro')

    if ($hasMacros) {
        $choices.Add('Run macro')
    }

    $choices.Add('Manage macros')
    $choices.Add('View module storage info')
    $choices.Add('Exit')

    $prompt     = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt('What would you like to do?', $choices.ToArray())
    $selection  = $prompt.Show($Console)

    switch ($selection) {
        'Select target window' { return 'SelectWindow'  }
        'Configure module'     { return 'Configure'     }
        'Record macro'         { return 'RecordMacro'   }
        'Run macro'            { return 'RunMacro'      }
        'Manage macros'            { return 'ManageMacros'     }
        'View module storage info' { return 'ViewStorageInfo'  }
        default                    { return 'Exit'             }
    }
}

