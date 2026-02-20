# Pester tests for EventLog backend behaviour in Write-LastWarLog

BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'EventLog backend in Write-LastWarLog' {
    Context 'Event writing' {
        BeforeEach {
            InModuleScope LastWarAutoScreenshot {
                Mock Test-EventLogSourceExists { $true }
            }
        }
        It 'Calls Write-EventLog when EventLog backend is selected' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-EventLog { }
                Write-LastWarLog -Message 'Test message' -Level 'Info' -FunctionName 'Get-EnumeratedWindows' -Context 'TestContext' -LogStackTrace 'TestStack' -ForceLog -BackendNames 'EventLog'
                Should -Invoke Write-EventLog -Exactly 1 -Scope It
            }
        }

        It 'Passes the correct EntryType for Error level' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-EventLog { }
                Write-LastWarLog -Message 'Test error' -Level 'Error' -FunctionName 'TestFunc' -ForceLog -BackendNames 'EventLog'
                Should -Invoke Write-EventLog -Exactly 1 -Scope It -ParameterFilter { $EntryType -eq 'Error' }
            }
        }

        It 'Passes the correct EntryType for Warning level' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-EventLog { }
                Write-LastWarLog -Message 'Test warning' -Level 'Warning' -FunctionName 'TestFunc' -ForceLog -BackendNames 'EventLog'
                Should -Invoke Write-EventLog -Exactly 1 -Scope It -ParameterFilter { $EntryType -eq 'Warning' }
            }
        }

        It 'Passes the correct EntryType for Info level' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-EventLog { }
                Write-LastWarLog -Message 'Test info' -Level 'Info' -FunctionName 'TestFunc' -ForceLog -BackendNames 'EventLog'
                Should -Invoke Write-EventLog -Exactly 1 -Scope It -ParameterFilter { $EntryType -eq 'Information' }
            }
        }

        It 'Includes all required fields in JSON message' {
            InModuleScope LastWarAutoScreenshot {
                $script:capturedMessage = $null
                Mock Write-EventLog { $script:capturedMessage = $Message }
                Write-LastWarLog -Message 'Test message' -Level 'Info' -FunctionName 'Get-EnumeratedWindows' -Context 'TestContext' -LogStackTrace 'TestStack' -ForceLog -BackendNames 'EventLog'
                $parsed = $script:capturedMessage | ConvertFrom-Json
                $parsed.Timestamp     | Should -Not -BeNullOrEmpty
                $parsed.FunctionName  | Should -Be 'Get-EnumeratedWindows'
                $parsed.ErrorType     | Should -Be 'Info'
                $parsed.Message       | Should -Be 'Test message'
                $parsed.Context       | Should -Be 'TestContext'
                $parsed.LogStackTrace | Should -Be 'TestStack'
            }
        }

        It 'Assigns correct EventId for <FunctionName>' -TestCases @(
            @{ FunctionName = 'Get-EnumeratedWindows';         ExpectedEventId = 1100 }
            @{ FunctionName = 'Select-TargetWindowFromMenu';   ExpectedEventId = 1200 }
            @{ FunctionName = 'Show-MenuLoop';                 ExpectedEventId = 1210 }
            @{ FunctionName = 'Save-ModuleConfiguration';      ExpectedEventId = 1300 }
            @{ FunctionName = 'Write-LastWarLog';              ExpectedEventId = 1400 }
            @{ FunctionName = 'Set-WindowActive';              ExpectedEventId = 2000 }
            @{ FunctionName = 'Set-WindowState';               ExpectedEventId = 2010 }
            @{ FunctionName = 'Start-WindowAndProcessMonitor'; ExpectedEventId = 2100 }
            @{ FunctionName = 'Test-WindowHandleValid';        ExpectedEventId = 2200 }
            @{ FunctionName = 'Get-MonitorProcess';            ExpectedEventId = 2300 }
            @{ FunctionName = 'UnknownFunction';               ExpectedEventId = 1000 }
        ) {
            InModuleScope LastWarAutoScreenshot -Parameters @{ FunctionName = $FunctionName; ExpectedEventId = $ExpectedEventId } {
                Mock Write-EventLog { }
                Write-LastWarLog -Message 'msg' -Level 'Info' -FunctionName $FunctionName -ForceLog -BackendNames 'EventLog'
                Should -Invoke Write-EventLog -Exactly 1 -Scope It -ParameterFilter { $EventId -eq $ExpectedEventId }
            }
        }

        It 'Does not throw when Write-EventLog fails' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-EventLog { throw 'Permission denied' }
                { Write-LastWarLog -Message 'Test' -Level 'Error' -FunctionName 'TestFunc' -ForceLog -BackendNames 'EventLog' } | Should -Not -Throw
            }
        }

        It 'Emits a warning when Write-EventLog fails' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-EventLog { throw 'Permission denied' }
                $warnings = Write-LastWarLog -Message 'Test' -Level 'Error' -FunctionName 'TestFunc' -ForceLog -BackendNames 'EventLog' 3>&1 |
                    Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
                $warnings | Should -Not -BeNullOrEmpty
            }
        }
    }
}

