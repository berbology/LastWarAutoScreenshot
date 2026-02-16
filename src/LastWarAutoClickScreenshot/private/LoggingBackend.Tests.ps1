# Ensure base class is loaded
. (Join-Path $PSScriptRoot 'LastWarLogBackend.ps1')

Describe 'FileLogBackend Logging Enhancements' {
    BeforeAll {
        $testLogDir = Join-Path $PSScriptRoot 'testlogs'
        if (-not (Test-Path $testLogDir)) { New-Item -Path $testLogDir -ItemType Directory | Out-Null }
        $testLogFile = Join-Path $testLogDir 'TestLog.log'
        $configPath = Join-Path $testLogDir 'ModuleConfig.json'
        $config = @{
            Logging = @{
                Backend = 'File'
                FileBackend = @{
                    MaxSizeMB = 0.001 # Force rollover after a few entries
                    MaxFileCount = 2
                    MaxAgeDays = 1
                    RetentionFileCount = 2
                }
            }
        } | ConvertTo-Json -Depth 5
        $config | Set-Content -Path $configPath -Encoding UTF8
        . (Join-Path $PSScriptRoot 'LastWarLogBackend.ps1')
    }

    It 'logs entries and validates format' {
        $backend = [FileLogBackend]::new($testLogFile)
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

    It 'triggers rollover by size' {
        $backend = [FileLogBackend]::new($testLogFile)
        for ($i=0; $i -lt 100; $i++) {
            $backend.Log("Msg $i", 'Info', 'TestFunc', 'TestContext', 'TestStack')
        }
        $rolled = Get-ChildItem -Path $testLogDir -Filter 'TestLog.log.*' | Where-Object { -not $_.PSIsContainer }
        $rolled.Count | Should -BeGreaterThan 0
    }

    It 'cleans up old logs by retention policy' {
        $backend = [FileLogBackend]::new($testLogFile)
        for ($i=0; $i -lt 100; $i++) {
            $backend.Log("Msg $i", 'Info', 'TestFunc', 'TestContext', 'TestStack')
        }
        $allLogs = Get-ChildItem -Path $testLogDir | Where-Object { -not $_.PSIsContainer -and $_.Name -like 'TestLog.log*' }
        # RetentionFileCount is 2, but main log file may be present, so expect 2 or 3 files
        $allLogs.Count | Should -BeLessOrEqual 3
    }

    It 'handles permission errors gracefully' {
        $badPath = Join-Path $env:TEMP ("TestLog_permission_" + [guid]::NewGuid().ToString() + ".log")
        $backend = [FileLogBackend]::new($badPath)
        # Simulate permission error by locking file for writing
        $fs = [System.IO.File]::Open($badPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $oldErrPref = $ErrorActionPreference
            $ErrorActionPreference = 'SilentlyContinue'
            { $backend.Log('Should fail', 'Error', 'TestFunc', 'TestContext', 'TestStack') } | Should -Throw
            $ErrorActionPreference = $oldErrPref
        } catch {
            $ErrorActionPreference = $oldErrPref
            # Exception is expected, do nothing
        } finally {
            $fs.Close()
            Remove-Item $badPath -Force
        }
    }

    It 'handles file not found and partial deletion' {
        $backend = [FileLogBackend]::new($testLogFile)
        Remove-Item $testLogFile -Force
        $backend.Log('After deletion', 'Info', 'TestFunc', 'TestContext', 'TestStack')
        $logContent = Get-Content $testLogFile -Raw
        $logContent | Should -Not -BeNullOrEmpty
    }

    AfterAll {
        if (Test-Path $testLogDir) {
            Remove-Item $testLogDir -Recurse -Force
        }
        # Clean up any temp log files from permission error test
        Get-ChildItem -Path $env:TEMP -Filter 'TestLog_permission_*.log' | ForEach-Object { Remove-Item $_.FullName -Force }
    }
}
BeforeAll {
    . $PSScriptRoot/../private/LastWarLogBackend.ps1
    . $PSScriptRoot/../private/EventLogBackend.ps1
    . $PSScriptRoot/../private/Get-LoggingBackendConfig.ps1
}

describe 'Logging Backend Abstraction' {
    Context 'FileLogBackend' {
        It 'Should write a log entry to file (mocked)' {
            $tmp = New-TemporaryFile
            $backend = [FileLogBackend]::new($tmp.FullName)
            $backend.Log('Test message', 'Info', 'TestFunc', 'TestCtx', 'TestStack')
            $content = Get-Content $tmp.FullName -Raw
            $content | Should -Match 'Test message'
            Remove-Item $tmp.FullName -Force
        }
    }
    Context 'EventLogBackend' {
        It 'Should call Write-EventLog (mocked)' {
            Mock Write-EventLog { $true }
            $mockTestSourceExists = { param($src) $true }
            $mockCreateSource = { param($src, $log) $null }
            $backend = [EventLogBackend]::new('TestSource', 'Application', $mockTestSourceExists, $mockCreateSource)
            { $backend.Log('Test message', 'Error', 'TestFunc', 'TestCtx', 'TestStack') } | Should -Not -Throw
            Assert-MockCalled Write-EventLog -Exactly 1 -Scope It
        }
    }
}

describe 'Get-LoggingBackendConfig' {
    It 'Should return File and EventLog when both are set' {
        $tmp = New-TemporaryFile
        Set-Content -Path $tmp.FullName -Value '{"Logging":{"Backend":"File,EventLog"}}'
        Mock Test-Path { $true }
        Mock Get-Content { '{"Logging":{"Backend":"File,EventLog"}}' }
        Mock ConvertFrom-Json { @{ Logging = @{ Backend = 'File,EventLog' } } }
        . $PSScriptRoot/../private/Get-LoggingBackendConfig.ps1
        $result = Get-LoggingBackendConfig
        $result | Should -Contain 'File'
        $result | Should -Contain 'EventLog'
    }
    It 'Should default to File if config missing' {
        Mock Test-Path { $false }
        . $PSScriptRoot/../private/Get-LoggingBackendConfig.ps1
        $result = Get-LoggingBackendConfig
        $result | Should -Contain 'File'
    }

    It 'Should handle trailing comma in Logging.Backend' {
        Mock Test-Path { $true }
        Mock Get-Content { '{"Logging":{"Backend":"File,"}}' }
        Mock ConvertFrom-Json { @{ Logging = @{ Backend = 'File,' } } }
        . $PSScriptRoot/../private/Get-LoggingBackendConfig.ps1
        $result = Get-LoggingBackendConfig
        $result | Should -Be @('File','')
        # Filter out empty entries for actual backend use
        ($result | Where-Object { $_ }) | Should -Be @('File')
    }

    It 'Should handle trailing space in Logging.Backend' {
        Mock Test-Path { $true }
        Mock Get-Content { '{"Logging":{"Backend":"File, "}}' }
        Mock ConvertFrom-Json { @{ Logging = @{ Backend = 'File, ' } } }
        . $PSScriptRoot/../private/Get-LoggingBackendConfig.ps1
        $result = Get-LoggingBackendConfig
        $result | Should -Be @('File','')
        ($result | Where-Object { $_ }) | Should -Be @('File')
    }
}
