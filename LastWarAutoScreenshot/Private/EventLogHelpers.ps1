<#
.SYNOPSIS
    Adds a new Windows Event Log source.
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
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Source,
        [Parameter(Mandatory)]
        [string]$LogName
    )
    [System.Diagnostics.EventLog]::CreateEventSource($Source, $LogName)
}

<#
.SYNOPSIS
    Checks if a Windows Event Log source exists.
.DESCRIPTION
    Returns $true if the specified event log source exists, otherwise $false.
.PARAMETER Source
    The name of the event log source to check.
.EXAMPLE
    Test-EventLogSourceExists -Source 'MyApp'
    Returns $true if 'MyApp' event log source exists.
.OUTPUTS
    [bool]
#>
function Test-EventLogSourceExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Source
    )
    return [System.Diagnostics.EventLog]::SourceExists($Source)
}