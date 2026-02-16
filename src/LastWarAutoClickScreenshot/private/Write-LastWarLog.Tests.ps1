BeforeAll {
    function Get-LoggingBackendConfig { @('File') }
    . $PSScriptRoot/Write-LastWarLog.ps1
    $script:logFilePath = Join-Path $PSScriptRoot 'LastWarAutoClickScreenshot.log'
}

describe 'Write-LastWarLog' {
    Context 'Log entry format' {
        It 'Should write a log entry with all required fields' {
            if (Test-Path $script:logFilePath) { Remove-Item $script:logFilePath -Force }
            Write-LastWarLog -Message 'Test error' -Level 'Error' -FunctionName 'TestFunc' -Context 'UnitTest' -LogStackTrace 'Stack info' -ForceLog -BackendNames File
            Test-Path $script:logFilePath | Should -Be $true
            $log = Get-Content $script:logFilePath -Raw | ConvertFrom-Json
            $log.Timestamp | Should -Not -BeNullOrEmpty
            $log.FunctionName | Should -Be 'TestFunc'
            $log.ErrorType | Should -Be 'Error'
            $log.Message | Should -Be 'Test error'
            $log.Context | Should -Be 'UnitTest'
            $log.LogStackTrace | Should -Be 'Stack info'
        }
    }
    Context 'Multiple log entries' {
        It 'Should append multiple log entries' {
            if (Test-Path $script:logFilePath) { Remove-Item $script:logFilePath -Force }
            Write-LastWarLog -Message 'Test error' -Level 'Error' -FunctionName 'TestFunc' -Context 'UnitTest' -LogStackTrace 'Stack info' -ForceLog -BackendNames File
            Write-LastWarLog -Message 'First' -Level 'Info' -FunctionName 'Func1' -ForceLog -BackendNames File
            Write-LastWarLog -Message 'Second' -Level 'Warning' -FunctionName 'Func2' -ForceLog -BackendNames File
            $logs = Get-Content $script:logFilePath | ForEach-Object { $_ | ConvertFrom-Json }
            $logs.Count | Should -BeGreaterThan 1
            $logs[0].Message | Should -Be 'Test error'
            $logs[1].Message | Should -Be 'First'
            $logs[2].Message | Should -Be 'Second'
        }
    }
    Context 'Log level validation' {
        It 'Should only accept valid log levels' {
            { Write-LastWarLog -Message 'Bad' -Level 'Invalid' -ForceLog -BackendNames File } | Should -Throw
        }
    }
    Context 'Log file location' {
        It 'Should write log to module directory' {
            $expectedPath = Join-Path $PSScriptRoot 'LastWarAutoClickScreenshot.log'
            Test-Path $expectedPath | Should -Be $true
        }
    }
    AfterAll {
        if (Test-Path $script:logFilePath) { Remove-Item $script:logFilePath -Force }
    }
}