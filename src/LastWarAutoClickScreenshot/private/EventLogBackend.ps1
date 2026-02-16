# Windows Event Log backend for LastWarAutoScreenshot

class EventLogBackend : LastWarLogBackend {
    [string] $Source
    [string] $LogName
    [ScriptBlock] $TestSourceExistsFn
    [ScriptBlock] $CreateSourceFn
    EventLogBackend(
        [string]$source = 'LastWarAutoScreenshot',
        [string]$logName = 'Application',
        [ScriptBlock]$testSourceExistsFn = $null,
        [ScriptBlock]$createSourceFn = $null
    ) {
        $this.Source = $source
        $this.LogName = $logName
        $this.TestSourceExistsFn = $testSourceExistsFn
        $this.CreateSourceFn = $createSourceFn
        if (-not $this.TestSourceExistsFn) {
            . (Join-Path $PSScriptRoot 'EventLogHelpers.ps1')
            $this.TestSourceExistsFn = { param($src) Test-EventLogSourceExists $src }
        }
        if (-not $this.CreateSourceFn) {
            . (Join-Path $PSScriptRoot 'EventLogHelpers.ps1')
            $this.CreateSourceFn = { param($src, $log) Create-EventLogSource $src $log }
        }
        # Register event source if needed
        if (-not (& $this.TestSourceExistsFn $this.Source)) {
            try {
                & $this.CreateSourceFn $this.Source $this.LogName
            } catch {
                Write-Warning "Failed to register custom event log source '$($this.Source)'."
                Write-Host "\nEvent log source registration requires administrator privileges."
                Write-Host "To resolve: Run PowerShell as Administrator and rerun the module, or manually create the event log source using:"
                Write-Host "New-EventLog -LogName $($this.LogName) -Source $($this.Source)"
                $choice = $null
                while ($choice -notin @('F','A')) {
                    Write-Host "\nChoose an option:"
                    Write-Host "[F] Fix permissions and retry registration"
                    Write-Host "[A] Fallback to Application log"
                    $choice = Read-Host "Enter F or A"
                    $choice = $choice.ToUpper()
                }
                if ($choice -eq 'F') {
                    throw "Event log source registration failed. Please restart PowerShell as Administrator and rerun."
                } else {
                    Write-Warning "Falling back to Application log. Logs will be written to the Application log with source 'Application'."
                    $this.Source = 'Application'
                }
            }
        }
    }
    [void] Log(
        [string]$Message,
        [string]$Level,
        [string]$FunctionName,
        [string]$Context,
        [string]$LogStackTrace
    ) {
        $entryType = switch ($Level) {
            'Error'   { 'Error' }
            'Warning' { 'Warning' }
            'Verbose' { 'Information' }
            default   { 'Information' }
        }
        # Map event IDs by scenario and level
        $eventId = switch ($FunctionName) {
            'Get-EnumeratedWindows' { switch ($Level) { 'Error' { 1101 } 'Warning' { 1102 } 'Info' { 1103 } 'Verbose' { 1104 } default { 1100 } } }
            'Select-TargetWindowFromMenu' { switch ($Level) { 'Error' { 1201 } 'Warning' { 1202 } 'Info' { 1203 } 'Verbose' { 1204 } default { 1200 } } }
            'Save-ModuleConfiguration' { switch ($Level) { 'Error' { 1301 } 'Warning' { 1302 } 'Info' { 1303 } 'Verbose' { 1304 } default { 1300 } } }
            'Write-LastWarLog' { switch ($Level) { 'Error' { 1401 } 'Warning' { 1402 } 'Info' { 1403 } 'Verbose' { 1404 } default { 1400 } } }
            default { switch ($Level) { 'Error' { 1001 } 'Warning' { 1002 } 'Info' { 1003 } 'Verbose' { 1004 } default { 1000 } } }
        }
        $logEntry = [ordered]@{
            Timestamp    = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
            FunctionName = $FunctionName
            ErrorType    = $Level
            Message      = $Message
            Context      = $Context
            LogStackTrace = $LogStackTrace
        }
        $eventMsg = $logEntry | ConvertTo-Json -Compress
        try {
            Write-EventLog -LogName $this.LogName -Source $this.Source -EntryType $entryType -EventId $eventId -Message $eventMsg
        } catch {
            Write-Warning "Failed to write to event log: $_"
            Write-Warning "Event message: $eventMsg"
            # Fallback to file logging if event log write fails
            try {
                $privatePath = $PSScriptRoot
                . (Join-Path $privatePath 'LastWarLogBackend.ps1')
                $logFilePath = Join-Path $privatePath 'LastWarAutoClickScreenshot.log'
                $fileBackend = [FileLogBackend]::new($logFilePath)
                $fallbackMsg = "[EventLogBackend fallback] Failed to write to event log. Reason: $_. Writing log entry to file backend instead."
                $fileBackend.Log($fallbackMsg, 'Warning', $FunctionName, $Context, $LogStackTrace)
            } catch {
                Write-Warning "Failed to fallback to file logging: $_"
            }
        }
    }
}
