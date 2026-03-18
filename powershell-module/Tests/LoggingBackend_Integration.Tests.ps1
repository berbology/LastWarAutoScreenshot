# Integration tests for FileLogBackend Logging Enhancements

BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
    $testLogDir = Join-Path $PSScriptRoot 'testlogs'
    if (-not (Test-Path $testLogDir)) { New-Item -Path $testLogDir -ItemType Directory | Out-Null }
    $testLogFile = Join-Path $testLogDir 'TestLog.log'
}

Describe 'FileLogBackend Logging Enhancements' -Tag 'Integration' {
    It 'logs entries and validates format' {
        InModuleScope LastWarAutoScreenshot -Parameters @{ testLogFile = $testLogFile } {
            $backend = [LastWarAutoScreenshot.FileLogBackend]::new($testLogFile)
            $backend.Log('Test message', 'Info', 'TestFunc', 'TestContext', 'TestStack')
            $logContent = Get-Content $testLogFile -Raw
            $json = $logContent | ConvertFrom-Json
            $json.Timestamp | Should -Not -BeNullOrEmpty
            $json.FunctionName | Should -Be 'TestFunc'
            $json.ErrorType | Should -Be 'Info'
            $json.Message | Should -Be 'Test message'
            $json.Context | Should -Be 'TestContext'
            $json.LogStackTrace | Should -Be 'TestStack'
        }
    }

    It 'triggers rollover by size' {
        InModuleScope LastWarAutoScreenshot -Parameters @{ testLogFile = $testLogFile; testLogDir = $testLogDir } {
            $backend = [LastWarAutoScreenshot.FileLogBackend]::new($testLogFile)
            for ($i=0; $i -lt 100; $i++) {
                $backend.Log("Msg $i", 'Info', 'TestFunc', 'TestContext', 'TestStack')
            }
            $rolled = Get-ChildItem -Path $testLogDir -Filter 'TestLog.log.*' | Where-Object { -not $_.PSIsContainer }
            $rolled.Count | Should -BeGreaterThan 0
        }
    }

    It 'cleans up old logs by retention policy' {
        InModuleScope LastWarAutoScreenshot -Parameters @{ testLogFile = $testLogFile; testLogDir = $testLogDir } {
            $backend = [LastWarAutoScreenshot.FileLogBackend]::new($testLogFile)
            for ($i=0; $i -lt 100; $i++) {
                $backend.Log("Msg $i", 'Info', 'TestFunc', 'TestContext', 'TestStack')
            }
            $allLogs = Get-ChildItem -Path $testLogDir | Where-Object { -not $_.PSIsContainer -and $_.Name -like 'TestLog.log*' }
            # MaxLogFileCount is 2, but main log file may be present, so expect 2 or 3 files
            $allLogs.Count | Should -BeLessOrEqual 3
        }
    }

    It 'handles permission errors gracefully' {
        InModuleScope LastWarAutoScreenshot {
            $badPath = Join-Path $env:TEMP ("TestLog_permission_" + [guid]::NewGuid().ToString() + ".log")
            $backend = [LastWarAutoScreenshot.FileLogBackend]::new($badPath)
            # Simulate permission error by locking file for writing
            $fs = [System.IO.File]::Open($badPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            try {
                { $backend.Log('Should fail', 'Error', 'TestFunc', 'TestContext', 'TestStack') } | Should -Throw
            } finally {
                $fs.Close()
                Remove-Item $badPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'handles file not found and partial deletion' {
        InModuleScope LastWarAutoScreenshot -Parameters @{ testLogFile = $testLogFile } {
            $backend = [LastWarAutoScreenshot.FileLogBackend]::new($testLogFile)
            Remove-Item $testLogFile -Force
            $backend.Log('After deletion', 'Info', 'TestFunc', 'TestContext', 'TestStack')
            $logContent = Get-Content $testLogFile -Raw
            $logContent | Should -Not -BeNullOrEmpty
        }
    }

    AfterAll {
        Remove-Item $testLogDir -Recurse -Force
    }
}
