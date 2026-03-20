
# Pester v5 tests for Test-WindowHandleValid, Prompt-RetryAbort, and Start-WindowAndProcessMonitor

BeforeAll {
    # Import the module using the manifest so all exports are available
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Test-WindowHandleValid' -Tag 'Unit' {
    Context 'With a valid window handle' {
        It 'Returns $true for a valid handle' {
            InModuleScope LastWarAutoScreenshot {
                $result = Test-WindowHandleValid -WindowHandle 123456 `
                    -IsWindowFn { $true } `
                    -IsWindowVisibleFn { $true } `
                    -IsIconicFn { $false }
                $result | Should -Be $true
            }
        }
    }
    Context 'With an invalid window handle' {
        It 'Returns $false for an invalid handle' {
            InModuleScope LastWarAutoScreenshot {
                $result = Test-WindowHandleValid -WindowHandle 999999 -IsWindowFn { $false }
                $result | Should -Be $false
            }
        }
    }
    Context 'With an unsupported handle type' {
        It 'Returns $false and logs error' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                $result = Test-WindowHandleValid -WindowHandle @(1,2,3)
                $result | Should -Be $false
                Should -Invoke Write-LastWarLog -Exactly 1 -ParameterFilter { $Message -match 'Unsupported WindowHandle type' -and $Level -eq 'Error' }
            }
        }
    }
}

Describe 'Prompt-RetryAbort' -Tag 'Unit' {
    It 'Returns <Expected> for key press <Label>' -TestCases @(
        @{ KeyPressed = 'R'; Expected = 'Retry'; Label = 'uppercase-R' }
        @{ KeyPressed = 'r'; Expected = 'Retry'; Label = 'lowercase-r' }
        @{ KeyPressed = 'A'; Expected = 'Abort'; Label = 'uppercase-A' }
        @{ KeyPressed = 'a'; Expected = 'Abort'; Label = 'lowercase-a' }
    ) {
        InModuleScope LastWarAutoScreenshot -Parameters @{ KeyPressed = $KeyPressed; Expected = $Expected } {
            Mock Read-Host { $KeyPressed }
            Prompt-RetryAbort 'Test prompt' | Should -Be $Expected
        }
    }
}

Describe 'Get-LogCheckHint' -Tag 'Unit' {
    Context 'When only File backend is active' {
        It 'Returns log file hint' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-LoggingBackendConfig { @('File') }
                Get-LogCheckHint | Should -Be 'Check the log file for details.'
            }
        }
    }
    Context 'When only EventLog backend is active' {
        It 'Returns event log hint' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-LoggingBackendConfig { @('EventLog') }
                Get-LogCheckHint | Should -Be 'Check the Windows Event Log for details.'
            }
        }
    }
    Context 'When both backends are active' {
        It 'Returns combined hint' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-LoggingBackendConfig { @('File', 'EventLog') }
                Get-LogCheckHint | Should -Be 'Check the Windows Event Log or log file for details.'
            }
        }
    }
}

