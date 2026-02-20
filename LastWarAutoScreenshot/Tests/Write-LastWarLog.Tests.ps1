BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'Write-LastWarLog ModuleRootPath initialisation' {
    # Runs before the sibling Describe redirects $script:ModuleRootPath, so we see the real value.
    It 'Should initialise ModuleRootPath to the module installation directory' {
        InModuleScope LastWarAutoScreenshot {
            $expectedPath = Split-Path -Parent (Get-Module LastWarAutoScreenshot).Path
            $script:ModuleRootPath | Should -Be $expectedPath
        }
    }
}

Describe 'Write-LastWarLog' {
    BeforeAll {
        # Redirect the module's log output to a unique temp directory so tests
        # never write into the module source tree.
        InModuleScope LastWarAutoScreenshot {
            $script:_savedModuleRootPath = $script:ModuleRootPath
            $script:ModuleRootPath = Join-Path $env:TEMP ("LastWarAutoScreenshot_Tests_" + [guid]::NewGuid().ToString())
            New-Item -Path $script:ModuleRootPath -ItemType Directory -Force | Out-Null
        }
    }

    Context 'Log entry format' {
        It 'Should write a log entry with all required fields' {
            InModuleScope LastWarAutoScreenshot {
                $logFilePath = Join-Path $script:ModuleRootPath 'LastWarAutoScreenshot.log'
                if (Test-Path $logFilePath) { Remove-Item $logFilePath -Force }
                Write-LastWarLog -Message 'Test error' -Level 'Error' -FunctionName 'TestFunc' -Context 'UnitTest' -LogStackTrace 'Stack info' -ForceLog -BackendNames File
                Test-Path $logFilePath | Should -Be $true
                $log = Get-Content $logFilePath -Raw | ConvertFrom-Json
                $log.Timestamp | Should -Not -BeNullOrEmpty
                $log.FunctionName | Should -Be 'TestFunc'
                $log.ErrorType | Should -Be 'Error'
                $log.Message | Should -Be 'Test error'
                $log.Context | Should -Be 'UnitTest'
                $log.LogStackTrace | Should -Be 'Stack info'
            }
        }
    }
    Context 'Multiple log entries' {
        It 'Should append multiple log entries' {
            InModuleScope LastWarAutoScreenshot {
                $logFilePath = Join-Path $script:ModuleRootPath 'LastWarAutoScreenshot.log'
                if (Test-Path $logFilePath) { Remove-Item $logFilePath -Force }
                Write-LastWarLog -Message 'Test error' -Level 'Error' -FunctionName 'TestFunc' -Context 'UnitTest' -LogStackTrace 'Stack info' -ForceLog -BackendNames File
                Write-LastWarLog -Message 'First' -Level 'Info' -FunctionName 'Func1' -ForceLog -BackendNames File
                Write-LastWarLog -Message 'Second' -Level 'Warning' -FunctionName 'Func2' -ForceLog -BackendNames File
                $logs = Get-Content $logFilePath | Where-Object { $_.Trim() -ne '' } | ForEach-Object { $_ | ConvertFrom-Json }
                $logs.Count | Should -BeGreaterThan 1
                $logs[0].Message | Should -Be 'Test error'
                $logs[1].Message | Should -Be 'First'
                $logs[2].Message | Should -Be 'Second'
            }
        }
    }
    Context 'Log level validation' {
        It 'Should only accept valid log levels' {
            InModuleScope LastWarAutoScreenshot {
                { Write-LastWarLog -Message 'Bad' -Level 'Invalid' -ForceLog -BackendNames File } | Should -Throw
            }
        }
    }

    Context 'Log-level suppression' {
        It 'Should suppress an Info entry when MinimumLogLevel is Warning' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-MinimumLogLevel { 'Warning' }
                $logFilePath = Join-Path $script:ModuleRootPath 'LastWarAutoScreenshot.log'
                if (Test-Path $logFilePath) { Remove-Item $logFilePath -Force }
                Write-LastWarLog -Message 'Suppressed info' -Level 'Info' -BackendNames File
                # No log file should exist because the entry was suppressed before any backend ran
                (Test-Path $logFilePath) | Should -Be $false
            }
        }

        It 'Should write an Info entry when -ForceLog bypasses MinimumLogLevel Warning' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-MinimumLogLevel { 'Warning' }
                $logFilePath = Join-Path $script:ModuleRootPath 'LastWarAutoScreenshot.log'
                if (Test-Path $logFilePath) { Remove-Item $logFilePath -Force }
                Write-LastWarLog -Message 'Forced info' -Level 'Info' -ForceLog -BackendNames File
                Test-Path $logFilePath | Should -Be $true
                $logs = Get-Content $logFilePath | Where-Object { $_.Trim() -ne '' } | ForEach-Object { $_ | ConvertFrom-Json }
                $logs | Where-Object { $_.Message -eq 'Forced info' } | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should write a Warning entry when MinimumLogLevel is Warning' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-MinimumLogLevel { 'Warning' }
                $logFilePath = Join-Path $script:ModuleRootPath 'LastWarAutoScreenshot.log'
                if (Test-Path $logFilePath) { Remove-Item $logFilePath -Force }
                Write-LastWarLog -Message 'Allowed warning' -Level 'Warning' -BackendNames File
                Test-Path $logFilePath | Should -Be $true
                $logs = Get-Content $logFilePath | Where-Object { $_.Trim() -ne '' } | ForEach-Object { $_ | ConvertFrom-Json }
                $logs | Where-Object { $_.Message -eq 'Allowed warning' } | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should suppress a Warning entry when MinimumLogLevel is Error' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-MinimumLogLevel { 'Error' }
                $logFilePath = Join-Path $script:ModuleRootPath 'LastWarAutoScreenshot.log'
                if (Test-Path $logFilePath) { Remove-Item $logFilePath -Force }
                Write-LastWarLog -Message 'Suppressed warning' -Level 'Warning' -BackendNames File
                (Test-Path $logFilePath) | Should -Be $false
            }
        }
    }

    Context 'Fallback routing' {
        It 'Should fall back to module root log file when EventLog write fails' {
            InModuleScope LastWarAutoScreenshot {
                # Ensure source-existence check passes so execution reaches Write-EventLog.
                Mock Test-EventLogSourceExists { $true }
                Mock Write-EventLog { throw 'Simulated EventLog failure' }
                $logFilePath = Join-Path $script:ModuleRootPath 'LastWarAutoScreenshot.log'
                if (Test-Path $logFilePath) { Remove-Item $logFilePath -Force }
                Write-LastWarLog -Message 'EventLog fallback test' -Level 'Info' -FunctionName 'TestFunc' -ForceLog -BackendNames 'EventLog'
                Test-Path $logFilePath | Should -Be $true
                $logs = Get-Content $logFilePath | Where-Object { $_.Trim() -ne '' } | ForEach-Object { $_ | ConvertFrom-Json }
                $logs | Where-Object { $_.Message -eq 'EventLog fallback test' } | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should fall back to module root log file when no configured backends succeed' {
            InModuleScope LastWarAutoScreenshot {
                # Passing an empty BackendNames means neither File nor EventLog branch runs,
                # leaving $wroteToAny = $false and triggering the final catch-all fallback.
                $logFilePath = Join-Path $script:ModuleRootPath 'LastWarAutoScreenshot.log'
                if (Test-Path $logFilePath) { Remove-Item $logFilePath -Force }
                Write-LastWarLog -Message 'Final fallback test' -Level 'Info' -FunctionName 'TestFunc' -ForceLog -BackendNames @()
                Test-Path $logFilePath | Should -Be $true
                $logs = Get-Content $logFilePath | Where-Object { $_.Trim() -ne '' } | ForEach-Object { $_ | ConvertFrom-Json }
                $logs | Where-Object { $_.Message -eq 'Final fallback test' } | Should -Not -BeNullOrEmpty
            }
        }
    }

    AfterAll {
        InModuleScope LastWarAutoScreenshot {
            if (Test-Path $script:ModuleRootPath) { Remove-Item $script:ModuleRootPath -Recurse -Force }
            $script:ModuleRootPath = $script:_savedModuleRootPath
        }
    }
}