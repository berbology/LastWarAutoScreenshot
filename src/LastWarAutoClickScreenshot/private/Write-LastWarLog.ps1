function Write-LastWarLog {
    <#
    .SYNOPSIS
        Writes a structured log entry to the configured logging backend(s).
    .DESCRIPTION
        Logs error, warning, or info events in a standard format as defined in docs/Logging.md.
        Supports file and Windows Event Log backends via class-based abstraction.
    .PARAMETER Message
        The main error or event message.
    .PARAMETER Level
        Log level/type: Info, Error, or Warning.
    .PARAMETER FunctionName
        Name of the function generating the log.
    .PARAMETER Context
        Key context info (parameters, state, etc.).
    .PARAMETER LogStackTrace
        Stack trace if error (LogStackTrace avoids conflict with PowerShell's automatic variable).
    .PARAMETER ForceLog
        Forces log entry regardless of verbosity settings.
    #>
    [CmdletBinding()]

    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [Parameter()]
        [ValidateSet('Info','Error','Warning')]
        [string]$Level = 'Info',
        [Parameter()]
        [string]$FunctionName = $null,
        [Parameter()]
        [string]$Context = $null,
        [Parameter()]
        [string]$LogStackTrace = $null,
        [Parameter()]
        [switch]$ForceLog,
        [Parameter()]
        [string[]]$BackendNames = $null
    )

    # Determine if logging should occur
    $shouldLog = $ForceLog.IsPresent
    if (-not $shouldLog) {
        if ($null -ne $PSCmdlet) {
            $shouldLog = $PSCmdlet.MyInvocation.BoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue' -or $PSCmdlet.MyInvocation.BoundParameters['Debug'] -or $DebugPreference -eq 'Continue'
        } else {
            $shouldLog = $VerbosePreference -eq 'Continue' -or $DebugPreference -eq 'Continue'
        }
    }
    if (-not $shouldLog) { return }

    # Import backend classes and config loader
    $privatePath = $PSScriptRoot
    . (Join-Path $privatePath 'LastWarLogBackend.ps1')
    . (Join-Path $privatePath 'EventLogBackend.ps1')
    . (Join-Path $privatePath 'Get-LoggingBackendConfig.ps1')

    $backendNames = if ($null -ne $BackendNames) { $BackendNames } else { Get-LoggingBackendConfig }
    $backends = @()
    if ($backendNames -contains 'File') {
        $logFilePath = Join-Path $privatePath 'LastWarAutoClickScreenshot.log'
        $backends += [FileLogBackend]::new($logFilePath)
    }
    if ($backendNames -contains 'EventLog') {
        $backends += [EventLogBackend]::new('LastWarAutoScreenshot', 'Application', $null, $null)
    }
    if ($backends.Count -eq 0) {
        # Fallback to file backend if config is invalid
        $logFilePath = Join-Path $privatePath 'LastWarAutoClickScreenshot.log'
        $backends += [FileLogBackend]::new($logFilePath)
    }

    foreach ($backend in $backends) {
        try {
            $backend.Log($Message, $Level, $FunctionName, $Context, $LogStackTrace)
        } catch {
            Write-Warning "Failed to write log entry via backend $($backend.GetType().Name): $_"
        }
    }
}
