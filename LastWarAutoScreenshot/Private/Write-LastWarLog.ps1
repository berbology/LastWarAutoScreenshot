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
        Forces the log entry to be written regardless of the MinimumLogLevel setting
        configured in ModuleConfig.json. Without this switch, entries whose Level is
        below MinimumLogLevel are silently discarded.
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



    $backendNames = if ($null -ne $BackendNames) { $BackendNames } else { Get-LoggingBackendConfig }

    # Suppress entries that fall below the configured minimum level, unless -ForceLog is set
    if (-not $ForceLog) {
        $levelPriority = @{ 'Info' = 0; 'Warning' = 1; 'Error' = 2 }
        $minimumLevel  = Get-MinimumLogLevel
        if ($levelPriority[$Level] -lt $levelPriority[$minimumLevel]) {
            return
        }
    }

    $wroteToAny = $false

    $moduleRootLogFile = Join-Path $script:ModuleRootPath 'LastWarAutoScreenshot.log'
    $userConfiguredLogFile = $null
    if ($backendNames -contains 'File') {
        # Try user-configured file location if set in config, else use module root
        $userConfiguredLogFile = $moduleRootLogFile
        try {
            $fileBackend = [LastWarAutoScreenshot.FileLogBackend]::new($userConfiguredLogFile)
            $fileBackend.Log($Message, $Level, $FunctionName, $Context, $LogStackTrace)
            $wroteToAny = $true
        } catch {
            Write-Warning "Failed to write log entry via FileLogBackend: $_"
        }
    }

    if ($backendNames -contains 'EventLog') {
        $eventLogSuccess = $false
        try {
            # Ensure Event Log source exists before writing
            $sourceExists = $false
            try {
                $sourceExists = Test-EventLogSourceExists 'LastWarAutoScreenshot'
            } catch {}
            if (-not $sourceExists) {
                try {
                    Add-EventLogSource -Source 'LastWarAutoScreenshot' -LogName 'Application'
                    Write-Verbose "Created Event Log source 'LastWarAutoScreenshot'"
                } catch {
                    $adminMsg = "Run module as Administrator at least once to create the event log source 'LastWarAutoScreenshot'"
                    $eqLine = '=' * ($adminMsg.Length + 1)
                    Write-Host $eqLine -ForegroundColor Red
                    Write-Host $adminMsg -ForegroundColor Red
                    Write-Host $eqLine -ForegroundColor Red
                    Write-Host "`n`n"
                    $global:LastWarAutoScreenshot_LoggingInitFailed = $true
                    # Fallback to module root log file
                    try {
                        $fileBackend = [LastWarAutoScreenshot.FileLogBackend]::new($moduleRootLogFile)
                        $fileBackend.Log($Message, $Level, $FunctionName, $Context, $LogStackTrace)
                    } catch {}
                    return
                }
            }
            $entryType = switch ($Level) {
                'Error'   { 'Error' }
                'Warning' { 'Warning' }
                default   { 'Information' }
            }
            $eventId = switch ($FunctionName) {
                 'Get-EnumeratedWindows'         { 1100 }
                 'Select-TargetWindowFromMenu'   { 1200 }
                 'Show-MenuLoop'                 { 1210 }
                 'Save-ModuleConfiguration'      { 1300 }
                 'Write-LastWarLog'              { 1400 }
                 'Set-WindowActive'              { 2000 }
                 'Set-WindowState'               { 2010 }
                 'Start-WindowAndProcessMonitor' { 2100 }
                 'Test-WindowHandleValid'        { 2200 }
                 'Get-MonitorProcess'            { 2300 }
                 default                         { 1000 }
            }
            $logEntry = [ordered]@{
                Timestamp      = (Get-Date).ToUniversalTime().ToString('o')
                FunctionName   = $FunctionName
                ErrorType      = $Level
                Message        = $Message
                Context        = $Context
                LogStackTrace  = $LogStackTrace
            }
            $eventMessage = $logEntry | ConvertTo-Json -Compress
            Write-EventLog -LogName 'Application' -Source 'LastWarAutoScreenshot' -EntryType $entryType -EventId $eventId -Message $eventMessage
            $eventLogSuccess = $true
            $wroteToAny = $true
        } catch {
            Write-Warning "Failed to write log entry via EventLog backend: $_"
            # Fallback to module root log file
            try {
                $fileBackend = [LastWarAutoScreenshot.FileLogBackend]::new($moduleRootLogFile)
                $fileBackend.Log($Message, $Level, $FunctionName, $Context, $LogStackTrace)
            } catch {}
        }
    }

    if (-not $wroteToAny) {
        # Fallback to module root log file if all else fails
        try {
            $fileBackend = [LastWarAutoScreenshot.FileLogBackend]::new($moduleRootLogFile)
            $fileBackend.Log($Message, $Level, $FunctionName, $Context, $LogStackTrace)
        } catch {
            Write-Warning "Fallback file log also failed: $_"
        }
    }
}
