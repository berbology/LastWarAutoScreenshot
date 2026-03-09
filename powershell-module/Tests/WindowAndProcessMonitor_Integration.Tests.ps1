# Integration tests for Start-WindowAndProcessMonitor

BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'Start-WindowAndProcessMonitor' -Tag 'Integration' {
    Context 'Return value' {
        It 'Returns an object with Stop and Cleanup scriptblock properties' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Get-MonitorProcess { [PSCustomObject]@{ HasExited = $false; Dispose = {} } }
                Mock Test-WindowHandleValid { $true }
                $monitor = Start-WindowAndProcessMonitor -WindowHandle 123456 -ProcessId 12345 -OnClosedOrExited {}
                try {
                    $monitor | Should -Not -BeNullOrEmpty
                    $monitor.Stop    | Should -BeOfType [ScriptBlock]
                    $monitor.Cleanup | Should -BeOfType [ScriptBlock]
                } finally {
                    if ($monitor) { try { & $monitor.Stop } catch {}; try { & $monitor.Cleanup } catch {} }
                }
            }
        }
    }

    Context 'When window is valid and process is running' {
        It 'Does not prompt or log during normal polling' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Test-WindowHandleValid { $true }
                Mock Prompt-RetryAbort {}
                # Call Invoke-MonitorPoll directly with a healthy state - no timer or sleep required.
                # Using Start-WindowAndProcessMonitor + Start-Sleep was timing-dependent and flaky.
                $state = @{
                    Stopped = $false; Timer = $null; WindowHandle = 123456; ProcessId = 12345
                    PollIntervalMs = 10; OnClosedOrExited = {}; CallbackState = $null
                    ProcessObject = [PSCustomObject]@{ HasExited = $false }
                    IsWindowFn = $null; IsWindowVisibleFn = $null; IsIconicFn = $null
                }
                Invoke-MonitorPoll -State $state
                Should -Not -Invoke Prompt-RetryAbort
                Should -Not -Invoke Write-LastWarLog
            }
        }
    }

    Context 'When Test-WindowHandleValid throws an exception' {
        It 'Logs exception detection, shows red text, and logs abort when user chooses abort' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                Mock Get-LogCheckHint { 'Check the log file for details.' }
                Mock Test-WindowHandleValid { throw 'Simulated Win32 failure' }
                Mock Prompt-RetryAbort { 'Abort' }
                $callbackInvoked = $false
                $state = @{
                    Stopped = $false; Timer = $null; WindowHandle = 123456; ProcessId = 12345
                    PollIntervalMs = 10; OnClosedOrExited = { $callbackInvoked = $true }; CallbackState = $null
                    ProcessObject = [PSCustomObject]@{ HasExited = $false }
                    IsWindowFn = $null; IsWindowVisibleFn = $null; IsIconicFn = $null
                }
                Invoke-MonitorPoll -State $state
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*Exception during window validity polling*' } -Times 1
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*abort after polling error*' } -Times 1
                Should -Invoke Write-Host -ParameterFilter { $Object -like '*Window monitoring exception detected*' } -Times 1
                $state.Stopped | Should -Be $true
            }
        }
        It 'Logs exception detection, shows red text, and logs retry when user chooses retry' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                Mock Get-LogCheckHint { 'Check the log file for details.' }
                Mock Test-WindowHandleValid { throw 'Simulated Win32 failure' }
                Mock Prompt-RetryAbort { 'Retry' }
                Mock Start-WindowAndProcessMonitor {}
                $state = @{
                    Stopped = $false; Timer = $null; WindowHandle = 123456; ProcessId = 12345
                    PollIntervalMs = 10; OnClosedOrExited = {}; CallbackState = $null
                    ProcessObject = [PSCustomObject]@{ HasExited = $false }
                    IsWindowFn = $null; IsWindowVisibleFn = $null; IsIconicFn = $null
                }
                Invoke-MonitorPoll -State $state
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*Exception during window validity polling*' } -Times 1
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*retry after polling error*' } -Times 1
                Should -Invoke Write-Host -ParameterFilter { $Object -like '*Window monitoring exception detected*' } -Times 1
                Should -Invoke Start-WindowAndProcessMonitor -Times 1
            }
        }
    }

    Context 'When window closes' {
        It 'Logs window closed detection and abort when user chooses abort' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                Mock Get-LogCheckHint { 'Check the log file for details.' }
                Mock Test-WindowHandleValid { $false }
                Mock Prompt-RetryAbort { 'Abort' }
                $state = @{
                    Stopped = $false; Timer = $null; WindowHandle = 123456; ProcessId = 12345
                    PollIntervalMs = 10; OnClosedOrExited = {}; CallbackState = $null
                    ProcessObject = [PSCustomObject]@{ HasExited = $false }
                    IsWindowFn = $null; IsWindowVisibleFn = $null; IsIconicFn = $null
                }
                Invoke-MonitorPoll -State $state
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*window closed*' } -Times 1
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*abort*' } -Times 1
                Should -Invoke Write-Host -ParameterFilter { $Object -like '*Window closed detected*' } -Times 1
            }
        }
        It 'Logs retry when user chooses retry after window closed' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                Mock Get-LogCheckHint { 'Check the log file for details.' }
                Mock Test-WindowHandleValid { $false }
                Mock Prompt-RetryAbort { 'Retry' }
                Mock Start-WindowAndProcessMonitor {}
                $state = @{
                    Stopped = $false; Timer = $null; WindowHandle = 123456; ProcessId = 12345
                    PollIntervalMs = 10; OnClosedOrExited = {}; CallbackState = $null
                    ProcessObject = [PSCustomObject]@{ HasExited = $false }
                    IsWindowFn = $null; IsWindowVisibleFn = $null; IsIconicFn = $null
                }
                Invoke-MonitorPoll -State $state
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*retry*' } -Times 1
                Should -Invoke Write-Host -ParameterFilter { $Object -like '*Window closed detected*' } -Times 1
            }
        }
    }

    Context 'When process exits' {
        It 'Logs process exit detection and abort when user chooses abort' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                Mock Get-LogCheckHint { 'Check the log file for details.' }
                Mock Test-WindowHandleValid { $true }
                Mock Prompt-RetryAbort { 'Abort' }
                $state = @{
                    Stopped = $false; Timer = $null; WindowHandle = 123456; ProcessId = 12345
                    PollIntervalMs = 10; OnClosedOrExited = {}; CallbackState = $null
                    ProcessObject = [PSCustomObject]@{ HasExited = $true }
                    IsWindowFn = $null; IsWindowVisibleFn = $null; IsIconicFn = $null
                }
                Invoke-MonitorPoll -State $state
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*process exited*' } -Times 1
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*abort*' } -Times 1
                Should -Invoke Write-Host -ParameterFilter { $Object -like '*Process exited detected*' } -Times 1
            }
        }
        It 'Logs retry when user chooses retry after process exit' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                Mock Get-LogCheckHint { 'Check the log file for details.' }
                Mock Test-WindowHandleValid { $true }
                Mock Prompt-RetryAbort { 'Retry' }
                Mock Start-WindowAndProcessMonitor {}
                $state = @{
                    Stopped = $false; Timer = $null; WindowHandle = 123456; ProcessId = 12345
                    PollIntervalMs = 10; OnClosedOrExited = {}; CallbackState = $null
                    ProcessObject = [PSCustomObject]@{ HasExited = $true }
                    IsWindowFn = $null; IsWindowVisibleFn = $null; IsIconicFn = $null
                }
                Invoke-MonitorPoll -State $state
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*retry*' } -Times 1
                Should -Invoke Write-Host -ParameterFilter { $Object -like '*Process exited detected*' } -Times 1
            }
        }
    }
}
