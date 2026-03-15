# Helper functions for LastWarAutoScreenshot module
# Place all shared utility functions here

<#
.SYNOPSIS
    Returns a user-facing hint directing the user to whichever logging backend(s) are active.
.DESCRIPTION
    Reads the configured logging backends via Get-LoggingBackendConfig and returns a message
    appropriate for inline use in Write-Host error footers. Ensures the user is only directed
    to backends that are actually receiving log entries.
.OUTPUTS
    [string]
#>
function Invoke-SelectCodeEditorDialog {
    <#
    .SYNOPSIS
        Opens a file open dialog for selecting an executable as the default code editor.

    .DESCRIPTION
        Displays a Windows OpenFileDialog filtered to .exe files, allowing the user to
        select an executable to use as the default code editor. The dialog opens in the
        directory of the current editor path if one is provided and valid.

    .PARAMETER InitialDirectory
        Optional path to the directory the dialog should open in. If not provided, or if the
        path does not exist, the dialog opens in the default location.

    .OUTPUTS
        [string]
        Returns the full path of the selected executable, or $null if the user cancelled.

    .EXAMPLE
        $path = Invoke-SelectCodeEditorDialog -InitialDirectory 'C:\Program Files\Microsoft VS Code'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]$InitialDirectory = ''
    )

    Add-Type -AssemblyName System.Windows.Forms
    $dialog = [System.Windows.Forms.OpenFileDialog]::new()
    $dialog.Title = 'Select default code editor'
    $dialog.Filter = 'Executable files (*.exe)|*.exe'
    $dialog.FilterIndex = 1

    if ($InitialDirectory -and (Test-Path -Path $InitialDirectory -PathType Container)) {
        $dialog.InitialDirectory = $InitialDirectory
    }

    $dialogResult = $dialog.ShowDialog()
    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.FileName
    }
    return $null
}

function Get-LogCheckHint {
    $backends = Get-LoggingBackendConfig
    $hasFile     = $backends -contains 'File'
    $hasEventLog = $backends -contains 'EventLog'
    if ($hasFile -and $hasEventLog) {
        return 'Check the Windows Event Log or log file for details.'
    } elseif ($hasEventLog) {
        return 'Check the Windows Event Log for details.'
    } else {
        return 'Check the log file for details.'
    }
}

