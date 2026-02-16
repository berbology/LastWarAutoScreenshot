function Write-LastWarLog {
    <#
    .SYNOPSIS
        Writes a structured log entry to the module log file in JSON format.
    .DESCRIPTION
        Logs error, warning, or info events in a standard format as defined in docs/Logging.md.
        Only logs if -ForceLog, -Verbose, or -Debug is set.
    .PARAMETER Message
        The main error or event message.
    .PARAMETER Level
        Log level/type: Info, Error, or Warning.
    .PARAMETER FunctionName
        Name of the function generating the log.
    .PARAMETER Context
        Key context info (parameters, state, etc.).
    .PARAMETER StackTrace
        Stack trace if error.
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
        [string]$StackTrace = $null,
        [Parameter()]
        [switch]$ForceLog
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

    # Build log entry as an ordered hashtable for JSON output
    $logEntry = [ordered]@{
        Timestamp    = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ') # ISO 8601 UTC
        FunctionName = $FunctionName
        ErrorType    = $Level
        Message      = $Message
        Context      = $Context
        StackTrace   = $StackTrace
    }

    try {
        # Write as JSON (preferred for file logs)
        $logMsg = $logEntry | ConvertTo-Json -Compress
        $logPath = Join-Path -Path $PSScriptRoot -ChildPath 'LastWarAutoClickScreenshot.log'
        Add-Content -Path $logPath -Value $logMsg
        # Log format fields are defined in docs/Logging.md
    } catch {
        # If logging fails, write to host as a fallback
        Write-Warning "Failed to write log entry: $_"
        Write-Warning "Log message: $($logMsg)"
    }
}
