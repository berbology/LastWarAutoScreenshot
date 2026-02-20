param()

$source = 'LastWarAutoScreenshot'
$logName = 'Application'

Write-Warning "WARNING: Removing the event log source will delete all associated event log messages."
$confirmation = Read-Host "Do you want to continue? (Y/N) [N]"
if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
    Write-Host "Aborted. The event log source was not removed."
    return
}

try {
    if ([System.Diagnostics.EventLog]::SourceExists($source)) {
        [System.Diagnostics.EventLog]::DeleteEventSource($source)
        Write-Host "Event log source '$source' removed from log '$logName'."
    } else {
        Write-Host "Event log source '$source' does not exist."
    }
} catch {
    Write-Error "Failed to remove event log source: $_"
}
