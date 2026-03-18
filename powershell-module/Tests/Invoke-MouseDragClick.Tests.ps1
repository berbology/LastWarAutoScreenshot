# Invoke-MouseDragClick.Tests.ps1
# Pester tests for Invoke-MouseDragClick (Phase 4, task 4.2)

BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Invoke-MouseDragClick' -Tag 'Unit' {
    AfterEach {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            $script:EmergencyStopRequested = $false
        }
    }

    It 'returns Success=$true, calls MovePath once for start, calls DragPath once for drag, sends LEFTDOWN then LEFTUP, and calls Start-Sleep three times on success' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    MouseControl = [PSCustomObject]@{
                        MinClickPreDelayMs     = 10
                        MaxClickPreDelayMs     = 20
                        MinClickDownDurationMs = 50
                        MaxClickDownDurationMs = 100
                        MinClickPostDelayMs      = 10
                        MaxClickPostDelayMs      = 20
                    }
                }
            } -ModuleName LastWarAutoScreenshot
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 0; Y = 0 } } -ModuleName LastWarAutoScreenshot
            Mock Get-BezierPoints { @( [PSCustomObject]@{ X = 1; Y = 1 }, [PSCustomObject]@{ X = 2; Y = 2 } ) } -ModuleName LastWarAutoScreenshot
            Mock Invoke-MouseMovePath { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-MouseDragPath { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { $true } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot

            $result = Invoke-MouseDragClick -StartX 100 -StartY 100 -EndX 200 -EndY 200

            $result.Success | Should -Be $true
            Should -Invoke Invoke-MouseMovePath -Exactly 1 -ModuleName LastWarAutoScreenshot
            Should -Invoke Invoke-MouseDragPath -Exactly 1 -ModuleName LastWarAutoScreenshot
            Should -Invoke Invoke-SendMouseInput -Exactly 1 -ModuleName LastWarAutoScreenshot -ParameterFilter {
                $ButtonFlags -eq [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_LEFTDOWN
            }
            Should -Invoke Invoke-SendMouseInput -Exactly 1 -ModuleName LastWarAutoScreenshot -ParameterFilter {
                $ButtonFlags -eq [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_LEFTUP
            }
            Should -Invoke Start-Sleep -Exactly 3 -ModuleName LastWarAutoScreenshot
        }
    }

    It 'returns Success=$false and does not call LEFTDOWN when emergency stop is active before drag' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    MouseControl = [PSCustomObject]@{
                        MinClickPreDelayMs     = 10
                        MaxClickPreDelayMs     = 20
                        MinClickDownDurationMs = 50
                        MaxClickDownDurationMs = 100
                        MinClickPostDelayMs      = 10
                        MaxClickPostDelayMs      = 20
                    }
                }
            } -ModuleName LastWarAutoScreenshot
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 0; Y = 0 } } -ModuleName LastWarAutoScreenshot
            Mock Get-BezierPoints { @( [PSCustomObject]@{ X = 1; Y = 1 }, [PSCustomObject]@{ X = 2; Y = 2 } ) } -ModuleName LastWarAutoScreenshot
            Mock Invoke-MouseMovePath { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-MouseDragPath { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { $true } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot

            $script:EmergencyStopRequested = $true
            $result = Invoke-MouseDragClick -StartX 100 -StartY 100 -EndX 200 -EndY 200

            $result.Success | Should -Be $false
            Should -Invoke Invoke-SendMouseInput -Exactly 0 -ModuleName LastWarAutoScreenshot
        }
    }

    It 'sends LEFTUP in finally block when emergency stop is triggered after LEFTDOWN' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    MouseControl = [PSCustomObject]@{
                        MinClickPreDelayMs     = 10
                        MaxClickPreDelayMs     = 20
                        MinClickDownDurationMs = 50
                        MaxClickDownDurationMs = 100
                        MinClickPostDelayMs      = 10
                        MaxClickPostDelayMs      = 20
                    }
                }
            } -ModuleName LastWarAutoScreenshot
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 0; Y = 0 } } -ModuleName LastWarAutoScreenshot
            Mock Get-BezierPoints { @( [PSCustomObject]@{ X = 1; Y = 1 }, [PSCustomObject]@{ X = 2; Y = 2 } ) } -ModuleName LastWarAutoScreenshot
            Mock Invoke-MouseMovePath { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-MouseDragPath { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput {
                param($DeltaX, $DeltaY, $ButtonFlags)
                if ($ButtonFlags -eq [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_LEFTDOWN) {
                    $script:EmergencyStopRequested = $true
                }
                return $true
            } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot

            $result = Invoke-MouseDragClick -StartX 100 -StartY 100 -EndX 200 -EndY 200

            $result.Success | Should -Be $false
            Should -Invoke Invoke-SendMouseInput -Exactly 1 -ModuleName LastWarAutoScreenshot -ParameterFilter {
                $ButtonFlags -eq [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_LEFTUP
            }
        }
    }

    It 'returns Success=$false and logs an error when LEFTDOWN send fails' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    MouseControl = [PSCustomObject]@{
                        MinClickPreDelayMs     = 10
                        MaxClickPreDelayMs     = 20
                        MinClickDownDurationMs = 50
                        MaxClickDownDurationMs = 100
                        MinClickPostDelayMs      = 10
                        MaxClickPostDelayMs      = 20
                    }
                }
            } -ModuleName LastWarAutoScreenshot
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 0; Y = 0 } } -ModuleName LastWarAutoScreenshot
            Mock Get-BezierPoints { @( [PSCustomObject]@{ X = 1; Y = 1 }, [PSCustomObject]@{ X = 2; Y = 2 } ) } -ModuleName LastWarAutoScreenshot
            Mock Invoke-MouseMovePath { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-MouseDragPath { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { $false } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Write-LastWarLog {} -ModuleName LastWarAutoScreenshot

            $result = Invoke-MouseDragClick -StartX 100 -StartY 100 -EndX 200 -EndY 200

            $result.Success | Should -Be $false
            Should -Invoke Write-LastWarLog -Exactly 1 -ModuleName LastWarAutoScreenshot -ParameterFilter {
                $Level -eq 'Error'
            }
        }
    }

    It 'returns Success=$false and does not call LEFTDOWN when move to start position fails' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    MouseControl = [PSCustomObject]@{
                        MinClickPreDelayMs     = 10
                        MaxClickPreDelayMs     = 20
                        MinClickDownDurationMs = 50
                        MaxClickDownDurationMs = 100
                        MinClickPostDelayMs      = 10
                        MaxClickPostDelayMs      = 20
                    }
                }
            } -ModuleName LastWarAutoScreenshot
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 0; Y = 0 } } -ModuleName LastWarAutoScreenshot
            Mock Get-BezierPoints { @( [PSCustomObject]@{ X = 1; Y = 1 }, [PSCustomObject]@{ X = 2; Y = 2 } ) } -ModuleName LastWarAutoScreenshot
            Mock Invoke-MouseMovePath { $false } -ModuleName LastWarAutoScreenshot
            Mock Invoke-MouseDragPath { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { $true } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Write-LastWarLog {} -ModuleName LastWarAutoScreenshot

            $result = Invoke-MouseDragClick -StartX 100 -StartY 100 -EndX 200 -EndY 200

            $result.Success | Should -Be $false
            Should -Invoke Invoke-SendMouseInput -Exactly 0 -ModuleName LastWarAutoScreenshot
        }
    }
}
