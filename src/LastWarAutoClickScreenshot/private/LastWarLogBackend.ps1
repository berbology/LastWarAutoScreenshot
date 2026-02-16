# Logging backend base class and file backend for LastWarAutoScreenshot


class LastWarLogBackend {
    [void] Log(
        [string]$Message,
        [string]$Level,
        [string]$FunctionName,
        [string]$Context,
        [string]$LogStackTrace
    ) {
        throw "Not implemented"
    }
}

class FileLogBackend : LastWarLogBackend {
    [string] $LogFilePath
    [ScriptBlock] $WriteContentFn
    FileLogBackend([string]$logFilePath) {
        $this.LogFilePath = $logFilePath
        $this.WriteContentFn = $null
    }
    [void] Log(
        [string]$Message,
        [string]$Level,
        [string]$FunctionName,
        [string]$Context,
        [string]$LogStackTrace
    ) {
        $logEntry = [ordered]@{
            Timestamp    = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
            FunctionName = $FunctionName
            ErrorType    = $Level
            Message      = $Message
            Context      = $Context
            LogStackTrace   = $LogStackTrace
        }
        $logMsg = $null
        try {
            $logMsg = $logEntry | ConvertTo-Json -Compress
            if ($this.WriteContentFn) {
                & $this.WriteContentFn $this.LogFilePath $logMsg
            } else {
                Add-Content -Path $this.LogFilePath -Value $logMsg
            }
        } catch {
            Write-Warning "Failed to write log entry: $_"
            Write-Warning "Log message: $($logMsg)"
        }
    }
}
