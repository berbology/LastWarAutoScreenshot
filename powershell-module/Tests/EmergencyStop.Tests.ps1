# EmergencyStop.Tests.ps1
# Pester v5 tests for Invoke-EmergencyStopPoll, Start-LWASEmergencyStopMonitor,
# and Stop-LWASEmergencyStopMonitor.
# Covers Phase 2 Step 4 sub-tasks 4.3, 4.4, and 4.5.

BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

# ══════════════════════════════════════════════════════════════════════════════
# Invoke-EmergencyStopPoll
# ══════════════════════════════════════════════════════════════════════════════
Describe 'Invoke-EmergencyStopPoll' -Tag 'Unit' {

    BeforeEach {
        # Reset module-scope flag and timer before every test.
        # Must run inside InModuleScope to target the module's $script: scope.
        InModuleScope LastWarAutoScreenshot {
            $script:EmergencyStopRequested = $false
            $script:EmergencyStopTimer     = $null
        }
    }

    AfterEach {
        InModuleScope LastWarAutoScreenshot {
            $script:EmergencyStopRequested = $false
            $script:EmergencyStopTimer     = $null
        }
    }

    Context 'When State.Stopped is already $true' {
        It 'returns immediately without calling GetKeyStateFn' {
            InModuleScope LastWarAutoScreenshot {
                # If GetKeyStateFn were called it would throw, failing the test.
                $state = @{
                    Stopped         = $true
                    Timer           = $null
                    HotkeyVKeyCodes = @(17, 16, 220)
                    GetKeyStateFn   = { param($k) throw 'GetKeyStateFn must not be called when Stopped = $true' }
                }
                { Invoke-EmergencyStopPoll -State $state } | Should -Not -Throw
            }
        }

        It 'does not set $script:EmergencyStopRequested' {
            InModuleScope LastWarAutoScreenshot {
                $state = @{
                    Stopped         = $true
                    Timer           = $null
                    HotkeyVKeyCodes = @(17, 16, 220)
                    GetKeyStateFn   = { 0 }
                }
                Invoke-EmergencyStopPoll -State $state
                $script:EmergencyStopRequested | Should -Be $false
            }
        }
    }

    Context 'When HotkeyVKeyCodes is empty or null' {
        It 'returns immediately when HotkeyVKeyCodes is an empty array' {
            InModuleScope LastWarAutoScreenshot {
                # If GetKeyStateFn were called it would throw, failing the test.
                $state = @{
                    Stopped         = $false
                    Timer           = $null
                    HotkeyVKeyCodes = @()
                    GetKeyStateFn   = { param($k) throw 'GetKeyStateFn must not be called for empty HotkeyVKeyCodes' }
                }
                { Invoke-EmergencyStopPoll -State $state } | Should -Not -Throw
                $script:EmergencyStopRequested | Should -Be $false
            }
        }

        It 'returns immediately when HotkeyVKeyCodes is $null' {
            InModuleScope LastWarAutoScreenshot {
                # If GetKeyStateFn were called it would throw, failing the test.
                $state = @{
                    Stopped         = $false
                    Timer           = $null
                    HotkeyVKeyCodes = $null
                    GetKeyStateFn   = { param($k) throw 'GetKeyStateFn must not be called for null HotkeyVKeyCodes' }
                }
                { Invoke-EmergencyStopPoll -State $state } | Should -Not -Throw
                $script:EmergencyStopRequested | Should -Be $false
            }
        }
    }

    Context 'When no keys are held' {
        It 'does not set EmergencyStopRequested or State.Stopped' {
            InModuleScope LastWarAutoScreenshot {
                $state = @{
                    Stopped         = $false
                    Timer           = $null
                    HotkeyVKeyCodes = @(17, 16, 220)
                    GetKeyStateFn   = { param($k) 0 }   # 0 = no key held
                }
                Invoke-EmergencyStopPoll -State $state
                $script:EmergencyStopRequested | Should -Be $false
                $state.Stopped | Should -Be $false
            }
        }
    }

    Context 'When only some keys are held (partial combo)' {
        It 'does not set EmergencyStopRequested when only first key is held' {
            InModuleScope LastWarAutoScreenshot {
                $state = @{
                    Stopped         = $false
                    Timer           = $null
                    HotkeyVKeyCodes = @(17, 16, 220)
                    # Key 17 held (MSB set), all others not
                    GetKeyStateFn   = { param($k) if ($k -eq 17) { -32768 } else { 0 } }
                }
                Invoke-EmergencyStopPoll -State $state
                $script:EmergencyStopRequested | Should -Be $false
                $state.Stopped | Should -Be $false
            }
        }

        It 'does not set EmergencyStopRequested when two of three keys are held' {
            InModuleScope LastWarAutoScreenshot {
                $state = @{
                    Stopped         = $false
                    Timer           = $null
                    HotkeyVKeyCodes = @(17, 16, 220)
                    GetKeyStateFn   = { param($k) if ($k -eq 17 -or $k -eq 16) { -32768 } else { 0 } }
                }
                Invoke-EmergencyStopPoll -State $state
                $script:EmergencyStopRequested | Should -Be $false
                $state.Stopped | Should -Be $false
            }
        }
    }

    Context 'When all keys are held' {
        It 'sets $script:EmergencyStopRequested to $true' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                Mock Get-LogCheckHint { 'Check logs.' }
                $state = @{
                    Stopped         = $false
                    Timer           = $null
                    HotkeyVKeyCodes = @(17, 16, 220)
                    GetKeyStateFn   = { param($k) -32768 }   # All keys held
                }
                Invoke-EmergencyStopPoll -State $state
                $script:EmergencyStopRequested | Should -Be $true
            }
        }

        It 'sets State.Stopped to $true' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                Mock Get-LogCheckHint { 'Check logs.' }
                $state = @{
                    Stopped         = $false
                    Timer           = $null
                    HotkeyVKeyCodes = @(17, 16, 220)
                    GetKeyStateFn   = { param($k) -32768 }
                }
                Invoke-EmergencyStopPoll -State $state
                $state.Stopped | Should -Be $true
            }
        }

        It 'calls Timer.Stop() when a timer is supplied' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                Mock Get-LogCheckHint { 'Check logs.' }
                $mockTimer = [System.Timers.Timer]::new(60000)
                $mockTimer.AutoReset = $false
                $mockTimer.Start()   # Enabled = $true
                try {
                    $state = @{
                        Stopped         = $false
                        Timer           = $mockTimer
                        HotkeyVKeyCodes = @(17, 16, 220)
                        GetKeyStateFn   = { param($k) -32768 }
                    }
                    Invoke-EmergencyStopPoll -State $state
                    $mockTimer.Enabled | Should -Be $false
                } finally {
                    try { $mockTimer.Stop() }    catch {}
                    try { $mockTimer.Dispose() } catch {}
                }
            }
        }

        It 'logs an Error via Write-LastWarLog' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                Mock Get-LogCheckHint { 'Check logs.' }
                $state = @{
                    Stopped         = $false
                    Timer           = $null
                    HotkeyVKeyCodes = @(17, 16, 220)
                    GetKeyStateFn   = { param($k) -32768 }
                }
                Invoke-EmergencyStopPoll -State $state
                Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Error' } -Times 1
            }
        }

        It 'writes a red ANSI console message via Write-Host' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                Mock Get-LogCheckHint { 'Check logs.' }
                $state = @{
                    Stopped         = $false
                    Timer           = $null
                    HotkeyVKeyCodes = @(17, 16, 220)
                    GetKeyStateFn   = { param($k) -32768 }
                }
                Invoke-EmergencyStopPoll -State $state
                Should -Invoke Write-Host -ParameterFilter {
                    $Object -like '*EMERGENCY STOP*'
                } -Times 1
            }
        }
    }

    Context 'When GetKeyStateFn throws' {
        It 'does not throw an unhandled exception' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                $state = @{
                    Stopped         = $false
                    Timer           = $null
                    HotkeyVKeyCodes = @(17)
                    GetKeyStateFn   = { param($k) throw 'Simulated key-check failure' }
                }
                { Invoke-EmergencyStopPoll -State $state } | Should -Not -Throw
            }
        }

        It 'logs an Error when GetKeyStateFn throws' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                $state = @{
                    Stopped         = $false
                    Timer           = $null
                    HotkeyVKeyCodes = @(17)
                    GetKeyStateFn   = { param($k) throw 'Simulated key-check failure' }
                }
                Invoke-EmergencyStopPoll -State $state
                Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Error' } -Times 1
            }
        }

        It 'does not set $script:EmergencyStopRequested when GetKeyStateFn throws' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                $state = @{
                    Stopped         = $false
                    Timer           = $null
                    HotkeyVKeyCodes = @(17)
                    GetKeyStateFn   = { param($k) throw 'Simulated key-check failure' }
                }
                Invoke-EmergencyStopPoll -State $state
                $script:EmergencyStopRequested | Should -Be $false
            }
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# Start-LWASEmergencyStopMonitor
# ══════════════════════════════════════════════════════════════════════════════
Describe 'Start-LWASEmergencyStopMonitor' -Tag 'Unit' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            # Clean up any running timer from a previous test.
            if ($null -ne $script:EmergencyStopTimer) {
                try { $script:EmergencyStopTimer.Stop() }    catch {}
                try { $script:EmergencyStopTimer.Dispose() } catch {}
                $script:EmergencyStopTimer = $null
            }
            $script:EmergencyStopRequested = $false
        }
    }

    AfterEach {
        InModuleScope LastWarAutoScreenshot {
            if ($null -ne $script:EmergencyStopTimer) {
                try { $script:EmergencyStopTimer.Stop() }    catch {}
                try { $script:EmergencyStopTimer.Dispose() } catch {}
                $script:EmergencyStopTimer = $null
            }
            $script:EmergencyStopRequested = $false
        }
    }

    Context 'When called for the first time' {
        It 'returns a PSCustomObject with Stop and Cleanup scriptblocks' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        EmergencyStop = [PSCustomObject]@{
                            PollIntervalMs  = 100
                            HotkeyKeyNames  = 'Ctrl+Shift+F12'
                        }
                    }
                }
                $monitor = Start-LWASEmergencyStopMonitor -PollIntervalMs 100 -HotkeyKeyNames 'Ctrl+Shift+F12'
                try {
                    $monitor | Should -Not -BeNullOrEmpty
                    $monitor.Stop    | Should -BeOfType [ScriptBlock]
                    $monitor.Cleanup | Should -BeOfType [ScriptBlock]
                } finally {
                    try { & $monitor.Stop }    catch {}
                    try { & $monitor.Cleanup } catch {}
                }
            }
        }

        It 'resets $script:EmergencyStopRequested to $false' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{ EmergencyStop = [PSCustomObject]@{ PollIntervalMs = 100; HotkeyKeyNames = 'Ctrl' } }
                }
                # Pre-set the flag to $true to confirm it is reset.
                $script:EmergencyStopRequested = $true
                $monitor = Start-LWASEmergencyStopMonitor -PollIntervalMs 100 -HotkeyKeyNames 'Ctrl'
                try {
                    $script:EmergencyStopRequested | Should -Be $false
                } finally {
                    try { & $monitor.Stop }    catch {}
                    try { & $monitor.Cleanup } catch {}
                }
            }
        }

        It 'stores the timer in $script:EmergencyStopTimer' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{ EmergencyStop = [PSCustomObject]@{ PollIntervalMs = 100; HotkeyKeyNames = 'Ctrl' } }
                }
                $monitor = Start-LWASEmergencyStopMonitor -PollIntervalMs 100 -HotkeyKeyNames 'Ctrl'
                try {
                    $script:EmergencyStopTimer | Should -Not -BeNullOrEmpty
                    $script:EmergencyStopTimer | Should -BeOfType [System.Timers.Timer]
                    $script:EmergencyStopTimer.Enabled | Should -Be $true
                } finally {
                    try { & $monitor.Stop }    catch {}
                    try { & $monitor.Cleanup } catch {}
                }
            }
        }

        It 'honours the PollIntervalMs parameter as the timer interval' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{ EmergencyStop = [PSCustomObject]@{ PollIntervalMs = 100; HotkeyKeyNames = 'Ctrl' } }
                }
                $monitor = Start-LWASEmergencyStopMonitor -PollIntervalMs 250 -HotkeyKeyNames 'Ctrl'
                try {
                    $script:EmergencyStopTimer.Interval | Should -Be 250
                } finally {
                    try { & $monitor.Stop }    catch {}
                    try { & $monitor.Cleanup } catch {}
                }
            }
        }
    }

    Context 'When called while already running (idempotency)' {
        It 'returns $null on the second call' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{ EmergencyStop = [PSCustomObject]@{ PollIntervalMs = 100; HotkeyKeyNames = 'Ctrl+Shift+F12' } }
                }
                $monitor1 = Start-LWASEmergencyStopMonitor -PollIntervalMs 100 -HotkeyKeyNames 'Ctrl+Shift+F12'
                $monitor2 = Start-LWASEmergencyStopMonitor -PollIntervalMs 100 -HotkeyKeyNames 'Ctrl+Shift+F12'
                try {
                    $monitor2 | Should -BeNullOrEmpty
                } finally {
                    try { & $monitor1.Stop }    catch {}
                    try { & $monitor1.Cleanup } catch {}
                }
            }
        }

        It 'logs an Info message about already running on the second call' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{ EmergencyStop = [PSCustomObject]@{ PollIntervalMs = 100; HotkeyKeyNames = 'Ctrl+Shift+F12' } }
                }
                $monitor1 = Start-LWASEmergencyStopMonitor -PollIntervalMs 100 -HotkeyKeyNames 'Ctrl+Shift+F12'
                Start-LWASEmergencyStopMonitor -PollIntervalMs 100 -HotkeyKeyNames 'Ctrl+Shift+F12' | Out-Null
                try {
                    Should -Invoke Write-LastWarLog -ParameterFilter {
                        $Level -eq 'Info' -and $Message -like '*already running*'
                    } -Times 1
                } finally {
                    try { & $monitor1.Stop }    catch {}
                    try { & $monitor1.Cleanup } catch {}
                }
            }
        }
    }

    Context 'When config defaults drive parameter values' {
        It 'reads PollIntervalMs from config when parameter is not supplied' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        EmergencyStop = [PSCustomObject]@{
                            PollIntervalMs  = 350
                            HotkeyKeyNames  = ''
                        }
                    }
                }
                $monitor = Start-LWASEmergencyStopMonitor -HotkeyKeyNames 'Ctrl+Shift+F12'
                try {
                    $script:EmergencyStopTimer.Interval | Should -Be 350
                } finally {
                    try { & $monitor.Stop }    catch {}
                    try { & $monitor.Cleanup } catch {}
                }
            }
        }
    }

    Context 'When Get-ModuleConfiguration throws' {
        It 'propagates the exception from Start-LWASEmergencyStopMonitor' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-ModuleConfiguration { throw 'Simulated config load failure' }
                { Start-LWASEmergencyStopMonitor } | Should -Throw '*Simulated config load failure*'
            }
        }
    }

    Context 'Returned Stop scriptblock' {
        It 'sets State.Stopped = $true and stops the timer when invoked' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{ EmergencyStop = [PSCustomObject]@{ PollIntervalMs = 100; HotkeyKeyNames = 'Ctrl' } }
                }
                $monitor = Start-LWASEmergencyStopMonitor -PollIntervalMs 100 -HotkeyKeyNames 'Ctrl'
                & $monitor.Stop
                try {
                    $script:EmergencyStopTimer.Enabled | Should -Be $false
                } finally {
                    try { & $monitor.Cleanup } catch {}
                }
            }
        }
    }

}

# ══════════════════════════════════════════════════════════════════════════════
# Stop-LWASEmergencyStopMonitor
# ══════════════════════════════════════════════════════════════════════════════
Describe 'Stop-LWASEmergencyStopMonitor' -Tag 'Unit' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            if ($null -ne $script:EmergencyStopTimer) {
                try { $script:EmergencyStopTimer.Stop() }    catch {}
                try { $script:EmergencyStopTimer.Dispose() } catch {}
                $script:EmergencyStopTimer = $null
            }
            $script:EmergencyStopRequested = $false
        }
    }

    AfterEach {
        InModuleScope LastWarAutoScreenshot {
            if ($null -ne $script:EmergencyStopTimer) {
                try { $script:EmergencyStopTimer.Stop() }    catch {}
                try { $script:EmergencyStopTimer.Dispose() } catch {}
                $script:EmergencyStopTimer = $null
            }
            $script:EmergencyStopRequested = $false
        }
    }

    Context 'When the monitor is running' {
        BeforeEach {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{ EmergencyStop = [PSCustomObject]@{ PollIntervalMs = 100; HotkeyKeyNames = 'Ctrl' } }
                }
            }
        }

        It 'stops the timer and nulls $script:EmergencyStopTimer' {
            InModuleScope LastWarAutoScreenshot {
                Start-LWASEmergencyStopMonitor -PollIntervalMs 100 -HotkeyKeyNames 'Ctrl' | Out-Null
                $script:EmergencyStopTimer | Should -Not -BeNullOrEmpty

                Stop-LWASEmergencyStopMonitor

                $script:EmergencyStopTimer | Should -BeNullOrEmpty
            }
        }

        It 'logs Info via Write-LastWarLog' {
            InModuleScope LastWarAutoScreenshot {
                Start-LWASEmergencyStopMonitor -PollIntervalMs 100 -HotkeyKeyNames 'Ctrl' | Out-Null
                Stop-LWASEmergencyStopMonitor
                Should -Invoke Write-LastWarLog -ParameterFilter {
                    $Level -eq 'Info' -and $Message -like '*Emergency stop monitor stopped*'
                } -Times 1
            }
        }

        It 'does NOT modify $script:EmergencyStopRequested' {
            InModuleScope LastWarAutoScreenshot {
                Start-LWASEmergencyStopMonitor -PollIntervalMs 100 -HotkeyKeyNames 'Ctrl' | Out-Null
                # Simulate a triggered emergency stop
                $script:EmergencyStopRequested = $true

                Stop-LWASEmergencyStopMonitor

                # Flag must remain $true - Stop-LWASEmergencyStopMonitor must not reset it
                $script:EmergencyStopRequested | Should -Be $true
            }
        }
    }

    Context 'When the monitor is not running' {
        It 'does not throw when called and no monitor is active' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                $script:EmergencyStopTimer = $null
                { Stop-LWASEmergencyStopMonitor } | Should -Not -Throw
            }
        }

        It 'does not log when no monitor is active' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                $script:EmergencyStopTimer = $null
                Stop-LWASEmergencyStopMonitor
                Should -Not -Invoke Write-LastWarLog
            }
        }

        It 'does not modify $script:EmergencyStopRequested when called with no active monitor' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                $script:EmergencyStopTimer     = $null
                $script:EmergencyStopRequested = $true
                Stop-LWASEmergencyStopMonitor
                $script:EmergencyStopRequested | Should -Be $true
            }
        }
    }
}

