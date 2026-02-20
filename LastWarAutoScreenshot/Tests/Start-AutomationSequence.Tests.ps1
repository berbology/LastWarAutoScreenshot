# Start-AutomationSequence Step 1 Pester Tests

# This file implements Phase 2, Task 1.15 from the ProjectPlan.md.
# It covers only the step 1 sections for Start-AutomationSequence as described.

#region Mocks
BeforeAll {
    Mock ConvertTo-ScreenCoordinates { @{ X = 100; Y = 200 } }
    Mock Move-MouseToPoint { $true }
    Mock Invoke-MouseClick { $true }
    Mock Start-EmergencyStopMonitor { @{ Stop = { }; Cleanup = { } } }
    Mock Stop-EmergencyStopMonitor { }
}

BeforeEach {
    # Reset script variables for each test
    $script:EmergencyStopRequested = $false
}
#endregion

Describe 'Start-AutomationSequence (step 1)' {
    Context 'EmergencyStop.AutoStart = $true' {
        It 'calls Start-EmergencyStopMonitor' {
            $config = @{ EmergencyStop = @{ AutoStart = $true } }
            Mock Get-ModuleConfiguration { $config }
            . $PSScriptRoot/../Public/Start-AutomationSequence.ps1
            Start-AutomationSequence -WindowHandle 123 -RelativeX 0.5 -RelativeY 0.5 | Out-Null
            Assert-MockCalled Start-EmergencyStopMonitor -Exactly 1
        }
    }

    Context '$script:EmergencyStopRequested = $true before move' {
        It 'exits cleanly and does not call Move-MouseToPoint' {
            $script:EmergencyStopRequested = $true
            . $PSScriptRoot/../Public/Start-AutomationSequence.ps1
            $result = Start-AutomationSequence -WindowHandle 123 -RelativeX 0.5 -RelativeY 0.5
            Assert-MockNotCalled Move-MouseToPoint
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'emergency stop'
        }
    }

    Context '$script:EmergencyStopRequested = $true after move' {
        It 'skips Invoke-MouseClick and exits cleanly' {
            # Patch Move-MouseToPoint to set EmergencyStopRequested after move
            Mock Move-MouseToPoint {
                $script:EmergencyStopRequested = $true
                $true
            }
            . $PSScriptRoot/../Public/Start-AutomationSequence.ps1
            $result = Start-AutomationSequence -WindowHandle 123 -RelativeX 0.5 -RelativeY 0.5
            Assert-MockNotCalled Invoke-MouseClick
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'emergency stop'
        }
    }

    Context 'Stop-EmergencyStopMonitor is always called in finally' {
        It 'calls Stop-EmergencyStopMonitor on success' {
            . $PSScriptRoot/../Public/Start-AutomationSequence.ps1
            Start-AutomationSequence -WindowHandle 123 -RelativeX 0.5 -RelativeY 0.5 | Out-Null
            Assert-MockCalled Stop-EmergencyStopMonitor -Exactly 1
        }
        It 'calls Stop-EmergencyStopMonitor on error' {
            Mock Move-MouseToPoint { throw 'Simulated error' }
            . $PSScriptRoot/../Public/Start-AutomationSequence.ps1
            try {
                Start-AutomationSequence -WindowHandle 123 -RelativeX 0.5 -RelativeY 0.5 | Out-Null
            } catch {}
            Assert-MockCalled Stop-EmergencyStopMonitor -Exactly 1
        }
    }

    Context 'Return object correctness' {
        It 'returns [PSCustomObject] with Success=$true on success' {
            . $PSScriptRoot/../Public/Start-AutomationSequence.ps1
            $result = Start-AutomationSequence -WindowHandle 123 -RelativeX 0.5 -RelativeY 0.5
            $result | Should -BeOfType PSCustomObject
            $result.Success | Should -BeTrue
            $result.Message | Should -Match 'completed'
        }
        It 'returns [PSCustomObject] with Success=$false on failure' {
            Mock Move-MouseToPoint { $false }
            . $PSScriptRoot/../Public/Start-AutomationSequence.ps1
            $result = Start-AutomationSequence -WindowHandle 123 -RelativeX 0.5 -RelativeY 0.5
            $result | Should -BeOfType PSCustomObject
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'failed'
        }
    }
}
