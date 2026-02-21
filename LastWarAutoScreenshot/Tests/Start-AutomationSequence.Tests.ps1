# Start-AutomationSequence Step 1 Pester Tests

# This file implements Phase 2, Task 1.15 from the ProjectPlan.md.
# It covers only the step 1 sections for Start-AutomationSequence as described.


Describe 'Start-AutomationSequence (step 1)' {
    BeforeAll {
        $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
        Import-Module $moduleManifest -Force
        Mock ConvertTo-ScreenCoordinates { @{ X = 100; Y = 200 } } -ModuleName LastWarAutoScreenshot
        Mock Move-MouseToPoint { $true } -ModuleName LastWarAutoScreenshot
        Mock Invoke-MouseClick { $true } -ModuleName LastWarAutoScreenshot
        Mock Start-EmergencyStopMonitor { @{ Stop = { }; Cleanup = { } } } -ModuleName LastWarAutoScreenshot
        Mock Stop-EmergencyStopMonitor { } -ModuleName LastWarAutoScreenshot
        Mock Write-LastWarLog { } -ModuleName LastWarAutoScreenshot
        Mock Get-ModuleConfiguration { @{ EmergencyStop = @{ AutoStart = $false } } } -ModuleName LastWarAutoScreenshot
    }

    BeforeEach {
        # Reset module script variables for each test
        InModuleScope LastWarAutoScreenshot {
            $script:EmergencyStopRequested = $false
            $script:EmergencyStopTimer = $null
        }
    }

    AfterEach {
        # Ensure module script variables are reset after each test
        InModuleScope LastWarAutoScreenshot {
            $script:EmergencyStopRequested = $false
            $script:EmergencyStopTimer = $null
        }
    }

    Context 'EmergencyStop.AutoStart = $true' {
        It 'calls Start-EmergencyStopMonitor' {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                Mock Get-ModuleConfiguration { @{ EmergencyStop = @{ AutoStart = $true } } }
                Start-AutomationSequence -WindowHandle 123 -RelativeX 0.5 -RelativeY 0.5 | Out-Null
                Should -Invoke Start-EmergencyStopMonitor -Exactly 1
            }
        }
    }

    Context '$script:EmergencyStopRequested = $true before move' {
        It 'exits cleanly and does not call Move-MouseToPoint' {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                $script:EmergencyStopRequested = $true
                $result = Start-AutomationSequence -WindowHandle 123 -RelativeX 0.5 -RelativeY 0.5
                Should -Not -Invoke Move-MouseToPoint
                $result.Success | Should -BeFalse
                $result.Message | Should -Match 'emergency stop'
            }
        }
    }

    Context '$script:EmergencyStopRequested = $true after move' {
        It 'skips Invoke-MouseClick and exits cleanly' {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                Mock Move-MouseToPoint {
                    $script:EmergencyStopRequested = $true
                    $true
                }
                $result = Start-AutomationSequence -WindowHandle 123 -RelativeX 0.5 -RelativeY 0.5
                Should -Not -Invoke Invoke-MouseClick
                $result.Success | Should -BeFalse
                $result.Message | Should -Match 'emergency stop'
            }
        }
    }

    Context 'Stop-EmergencyStopMonitor is always called in finally' {
        It 'calls Stop-EmergencyStopMonitor on success' {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                Start-AutomationSequence -WindowHandle 123 -RelativeX 0.5 -RelativeY 0.5 | Out-Null
                Should -Invoke Stop-EmergencyStopMonitor -Exactly 1
            }
        }
        It 'calls Stop-EmergencyStopMonitor on error' {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                Mock Move-MouseToPoint { throw 'Simulated error' }
                try {
                    Start-AutomationSequence -WindowHandle 123 -RelativeX 0.5 -RelativeY 0.5 | Out-Null
                } catch {}
                Should -Invoke Stop-EmergencyStopMonitor -Exactly 1
            }
        }
    }

    Context 'Return object correctness' {
        It 'returns [PSCustomObject] with Success=$true on success' {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                $result = Start-AutomationSequence -WindowHandle 123 -RelativeX 0.5 -RelativeY 0.5
                $result | Should -BeOfType PSCustomObject
                $result.Success | Should -BeTrue
                $result.Message | Should -Match 'completed'
            }
        }
        It 'returns [PSCustomObject] with Success=$false on failure' {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                Mock Move-MouseToPoint { $false }
                $result = Start-AutomationSequence -WindowHandle 123 -RelativeX 0.5 -RelativeY 0.5
                $result | Should -BeOfType PSCustomObject
                $result.Success | Should -BeFalse
                $result.Message | Should -Match 'failed'
            }
        }
    }
}
