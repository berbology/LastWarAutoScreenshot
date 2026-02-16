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
}
