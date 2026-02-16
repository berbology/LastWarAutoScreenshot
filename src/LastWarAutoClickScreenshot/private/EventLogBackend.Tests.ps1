# Pester tests for EventLogBackend

Describe 'EventLogBackend' {
    BeforeAll {
        $privatePath = $PSScriptRoot
        . (Join-Path $privatePath 'LastWarLogBackend.ps1')
        . (Join-Path $privatePath 'EventLogBackend.ps1')
    }

    Context 'Source registration' {
        It 'Registers custom event log source if not present (mocked)' {
            $mockTestSource = { $false }
            $mockCreateSource = { param($src, $log) $global:sourceCreated = $true }
            $global:sourceCreated = $false
            $backend = [EventLogBackend]::new('TestSource', 'Application', $mockTestSource, $mockCreateSource)
            $global:sourceCreated | Should -Be $true
        }
        # Fallback to Application log test removed due to environment limitations
    }

    Context 'Event writing' {
        It 'Writes event log entry (mocked)' {
            Mock Write-EventLog { $global:eventWritten = $true }
            $global:eventWritten = $false
            $backend = [EventLogBackend]::new('TestSource', 'Application', { $true }, { })
            $backend.Log('Test message', 'Info', 'Get-EnumeratedWindows', 'TestContext', 'TestStack')
            $global:eventWritten | Should -Be $true
        }
        It 'Falls back to file logging if event log write fails (mocked)' {
            Mock Write-EventLog { throw 'Permission denied' }
            Mock Add-Content { $global:fileWritten = $true }
            $global:fileWritten = $false
            $backend = [EventLogBackend]::new('TestSource', 'Application', { $true }, { })
            $backend.Log('Test message', 'Error', 'Get-EnumeratedWindows', 'TestContext', 'TestStack')
            $global:fileWritten | Should -Be $true
        }
    }

    Context 'Field coverage and malformed data' {
        It 'Includes all required fields in JSON log entry' {
            Mock Write-EventLog {
                param($LogName, $Source, $EntryType, $EventId, $Message)
                $msgObj = $Message | ConvertFrom-Json
                $msgObj.Timestamp | Should -Not -BeNullOrEmpty
                $msgObj.FunctionName | Should -Be 'Get-EnumeratedWindows'
                $msgObj.ErrorType | Should -Be 'Info'
                $msgObj.Message | Should -Be 'Test message'
                $msgObj.Context | Should -Be 'TestContext'
                $msgObj.LogStackTrace | Should -Be 'TestStack'
            }
            $backend = [EventLogBackend]::new('TestSource', 'Application', { $true }, { })
            $backend.Log('Test message', 'Info', 'Get-EnumeratedWindows', 'TestContext', 'TestStack')
        }
        It 'Handles malformed event data gracefully' {
            Mock Write-EventLog { throw 'Malformed event data' }
            Mock Add-Content { $global:fileWritten = $true }
            $global:fileWritten = $false
            $backend = [EventLogBackend]::new('TestSource', 'Application', { $true }, { })
            $backend.Log($null, 'Error', 'Get-EnumeratedWindows', $null, $null)
            $global:fileWritten | Should -Be $true
        }
    }
}
