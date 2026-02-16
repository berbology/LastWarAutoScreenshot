
# Temporary test for retention policy issue

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
    [int] $MaxSizeMB = 50
    [int] $MaxFileCount = 50
    [int] $MaxAgeDays = 30
    [int] $RetentionFileCount = 500
    [string] $LogDir
    [string] $LogBaseName
    FileLogBackend([string]$logFilePath) {
        $this.LogFilePath = $logFilePath
        $this.WriteContentFn = $null
        $this.LogDir = Split-Path $logFilePath -Parent
        $this.LogBaseName = Split-Path $logFilePath -Leaf
        $configPath = Join-Path $this.LogDir 'ModuleConfig.json'
        $defaults = @{ MaxSizeMB = 50; MaxFileCount = 50; MaxAgeDays = 30; RetentionFileCount = 500 }
        $settings = $defaults
        if (Test-Path $configPath) {
            try {
                $json = Get-Content $configPath -Raw | ConvertFrom-Json
                if ($json.Logging -and $json.Logging.FileBackend) {
                    $fb = $json.Logging.FileBackend
                    $settings.MaxSizeMB = $fb.MaxSizeMB
                    $settings.MaxFileCount = $fb.MaxFileCount
                    $settings.MaxAgeDays = $fb.MaxAgeDays
                    $settings.RetentionFileCount = $fb.RetentionFileCount
                }
            } catch {
                Write-Warning "Failed to load file backend config: $_"
            }
        }
        $this.MaxSizeMB = $settings.MaxSizeMB
        $this.MaxFileCount = $settings.MaxFileCount
        $this.MaxAgeDays = $settings.MaxAgeDays
        $this.RetentionFileCount = $settings.RetentionFileCount
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
            $this.InvokeRolloverIfNeeded()
            if ($this.WriteContentFn) {
                & $this.WriteContentFn $this.LogFilePath $logMsg
            } else {
                # ...debug output removed...
                if ([string]::IsNullOrWhiteSpace($this.LogFilePath)) {
                    Write-Warning "LogFilePath is null or empty, skipping Add-Content."
                } elseif ([string]::IsNullOrWhiteSpace($logMsg)) {
                    Write-Warning "logMsg is null or empty, skipping Add-Content."
                } else {
                    Add-Content -Path $this.LogFilePath -Value $logMsg
                }
            }
            $this.CleanupOldLogs()
        } catch {
            Write-Warning "Failed to write log entry: $_"
            Write-Warning "Log message: $($logMsg)"
        }
    }
    [void] InvokeRolloverIfNeeded() {
        if (-not (Test-Path $this.LogFilePath)) { return }
        $file = Get-Item $this.LogFilePath
        $sizeMB = [math]::Round(($file.Length / 1MB), 2)
        $ageDays = [math]::Round(((Get-Date) - $file.CreationTime).TotalDays, 2)
        $rollover = $false
        if ($sizeMB -ge $this.MaxSizeMB) { $rollover = $true }
        if ($ageDays -ge $this.MaxAgeDays) { $rollover = $true }
        $logFiles = Get-ChildItem -Path $this.LogDir | Where-Object { -not $_.PSIsContainer -and $_.Name -like "$($this.LogBaseName)*" } | Sort-Object LastWriteTime
        if ($logFiles.Count -ge $this.MaxFileCount) { $rollover = $true }
        if ($rollover) {
            $idx = ($logFiles | Where-Object { $_.Name -match "$($this.LogBaseName)\.([0-9]+)$" } | Measure-Object).Count + 1
            $rollName = "$($this.LogBaseName).$idx"
            $rollPath = Join-Path $this.LogDir $rollName
            try {
                Move-Item -Path $this.LogFilePath -Destination $rollPath -Force
            } catch {
                Write-Warning "Log rollover failed: $_"
            }
        }
    }
    [void] CleanupOldLogs() {
        $logFiles = Get-ChildItem -Path $this.LogDir | Where-Object { -not $_.PSIsContainer -and $_.Name -like "$($this.LogBaseName)*" } | Sort-Object LastWriteTime
        if ($logFiles.Count -le $this.RetentionFileCount) { return }
        $toDelete = $logFiles | Select-Object -First ($logFiles.Count - $this.RetentionFileCount)
        foreach ($f in $toDelete) {
            try {
                Remove-Item $f.FullName -Force
            } catch {
                Write-Warning "Failed to delete old log file: $($f.FullName) $_"
            }
        }
    }
}
Describe 'FileLogBackend Retention Policy Isolated' {
    BeforeAll {
        $testLogDir = Join-Path $PSScriptRoot 'testlogs_temp'
        if (-not (Test-Path $testLogDir)) { New-Item -Path $testLogDir -ItemType Directory | Out-Null }
        $testLogFile = Join-Path $testLogDir 'TestLog.log'
        $configPath = Join-Path $testLogDir 'ModuleConfig.json'
        $config = @{
            Logging = @{
                Backend = 'File'
                FileBackend = @{
                    MaxSizeMB = 1
                    MaxFileCount = 2
                    MaxAgeDays = 1
                    RetentionFileCount = 2
                }
            }
        } | ConvertTo-Json -Depth 5
        $config | Set-Content -Path $configPath -Encoding UTF8
    }

    It 'cleans up old logs by retention policy (isolated)' {
        $backend = [FileLogBackend]::new($testLogFile)
        for ($i=0; $i -lt 100; $i++) {
            $backend.Log("Msg $i", 'Info', 'TestFunc', 'TestContext', 'TestStack')
        }
        $allFiles = Get-ChildItem -Path $testLogDir
        $allLogs = @()
        foreach ($file in $allFiles) {
            if (-not $file.PSIsContainer) {
                if ($file.Name -eq 'TestLog.log') {
                    $allLogs += $file
                } elseif ($file.Name -and ($file.Name -is [string]) -and ($file.Name -match '^TestLog\.log\.\d+$')) {
                    $allLogs += $file
                }
            }
        }
        if ($null -eq $allLogs) { $allLogs = @() }
        $allLogs = @($allLogs) # ensure array
        $logCount = $allLogs.Count
        $logCount | Should -BeLessOrEqual 2
    }

    AfterAll {
        Remove-Item $testLogDir -Recurse -Force
    }
}
