function Test-EventLogSourceExists {
    param([string]$Source)
    return [System.Diagnostics.EventLog]::SourceExists($Source)
}

function Create-EventLogSource {
    param([string]$Source, [string]$LogName)
    [System.Diagnostics.EventLog]::CreateEventSource($Source, $LogName)
}
