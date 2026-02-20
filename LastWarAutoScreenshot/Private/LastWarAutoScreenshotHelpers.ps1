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
