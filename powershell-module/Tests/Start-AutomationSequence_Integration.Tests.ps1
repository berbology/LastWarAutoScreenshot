# Integration tests for Start-AutomationSequence

BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'Start-AutomationSequence' -Tag 'Integration' {
    Context 'Phase 2 Step 2.8: Human-like movement integration' {
        It 'calls Invoke-MouseMovePath instead of Move-MouseToPoint' {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                # Arrange: ensure Move-MouseToPoint is not called, but Invoke-MouseMovePath is
                Mock ConvertTo-ScreenCoordinates { @{ X = 100; Y = 200 } }
                Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 0; Y = 0 } }
                Mock Get-BezierPoints { @([PSCustomObject]@{X=50;Y=50},[PSCustomObject]@{X=100;Y=200}) }
                Mock Move-MouseToPoint { $true }
                Mock Invoke-MouseMovePath { $true }
                Mock Invoke-MouseClick { $true }
                Mock Start-EmergencyStopMonitor { @{ Stop = { }; Cleanup = { } } }
                Mock Stop-EmergencyStopMonitor { }
                Mock Write-LastWarLog { }
                Mock Get-ModuleConfiguration {
                    @{ 
                        EmergencyStop = @{ AutoStart = $false }
                        MouseControl = @{ MinClickPreDelayMs = 50; MaxClickPreDelayMs = 200; MinClickPostDelayMs = 100; MaxClickPostDelayMs = 300 }
                    }
                }
                
                Start-AutomationSequence -WindowHandle 123 -RelativeX 0.5 -RelativeY 0.5 | Out-Null
                Should -Invoke Invoke-MouseMovePath -Exactly 1
                Should -Not -Invoke Move-MouseToPoint
            }
        }

        It 'calls Start-Sleep for ClickPreDelay and ClickPostDelay' {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                $sleepCalls = @()
                Mock ConvertTo-ScreenCoordinates { @{ X = 100; Y = 200 } }
                Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 0; Y = 0 } }
                Mock Get-BezierPoints { @([PSCustomObject]@{X=50;Y=50},[PSCustomObject]@{X=100;Y=200}) }
                Mock Move-MouseToPoint { $true }
                Mock Invoke-MouseMovePath { $true }
                Mock Invoke-MouseClick { $true }
                Mock Start-Sleep { param($Milliseconds) $script:sleepCalls += $Milliseconds }
                Mock Start-EmergencyStopMonitor { @{ Stop = { }; Cleanup = { } } }
                Mock Stop-EmergencyStopMonitor { }
                Mock Write-LastWarLog { }
                Mock Get-ModuleConfiguration {
                    @{ 
                        EmergencyStop = @{ AutoStart = $false }
                        MouseControl = @{ MinClickPreDelayMs = 50; MaxClickPreDelayMs = 50; MinClickPostDelayMs = 100; MaxClickPostDelayMs = 100 }
                    }
                }
                
                $script:sleepCalls = @()
                Start-AutomationSequence -WindowHandle 123 -RelativeX 0.5 -RelativeY 0.5 | Out-Null
                # Should have two sleeps: one for pre-delay (50ms), one for post-delay (100ms)
                $script:sleepCalls.Count | Should -BeGreaterOrEqual 2
                $script:sleepCalls | Should -Contain 50
                $script:sleepCalls | Should -Contain 100
            }
        }
    }
}
