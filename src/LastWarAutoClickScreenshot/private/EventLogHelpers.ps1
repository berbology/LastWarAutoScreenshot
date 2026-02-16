function Test-EventLogSourceExists {
    param([string]$Source)
    return [System.Diagnostics.EventLog]::SourceExists($Source)
}

<#
.SYNOPSIS
Creates a new Windows Event Log source.

.DESCRIPTION
Adds a new event log source to the specified log. This is required for custom logging in Windows Event Log. Requires administrator privileges.

.PARAMETER Source
The name of the event log source to create.

.PARAMETER LogName
The name of the event log to associate with the source (e.g., 'Application').

.EXAMPLE
Add-EventLogSource -Source 'MyApp' -LogName 'Application'
Creates a new event log source 'MyApp' in the Application log.

.OUTPUTS
None

.NOTES
Requires administrator privileges to create a new event log source.
#>
function Add-EventLogSource {
    param([string]$Source, [string]$LogName)
    [System.Diagnostics.EventLog]::CreateEventSource($Source, $LogName)
}