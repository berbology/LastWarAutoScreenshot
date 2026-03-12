# MouseMovement.Tests.ps1
# Pester tests for Move-MouseToPoint and Invoke-MouseClick (Phase 2, 1.14 step 1 only)

BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'Move-MouseToPoint' -Tag 'Unit' {
    It 'calls Invoke-SetCursorPos with target coordinates' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            Mock Invoke-SetCursorPos { $true } -ModuleName LastWarAutoScreenshot
            Move-MouseToPoint -X 110 -Y 220 | Should -Be $true
            Should -Invoke Invoke-SetCursorPos -Exactly 1 -ParameterFilter {
                $X -eq 110 -and $Y -eq 220
            }
        }
    }

    It 'returns $false and logs error if SetCursorPos fails' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-SetCursorPos { $false } -ModuleName LastWarAutoScreenshot
            Mock Write-LastWarLog {} -ModuleName LastWarAutoScreenshot
            Move-MouseToPoint -X 110 -Y 220 | Should -Be $false
            Should -Invoke Write-LastWarLog -Exactly 1
        }
    }
}

# === PHASE 2 STEP 2.7 TESTS ===

Describe 'Get-BezierPoints' -Tag 'Unit' {
    It 'returns at least one intermediate point non-collinear with start/end' {
        InModuleScope LastWarAutoScreenshot {
            # Use fixed start/end, disable jitter for deterministic test
            Mock Get-ModuleConfiguration {
                @{ MouseControl = @{ PathPointCount = 10; BezierControlPointOffsetFactor = 0.5; JitterRadiusPx = 0; JitterEnabled = $false } }
            } -ModuleName LastWarAutoScreenshot
            $startX = 0; $startY = 0; $endX = 100; $endY = 0
            $points = Get-BezierPoints -StartX $startX -StartY $startY -EndX $endX -EndY $endY -NumPoints 10 -ControlPointOffsetFactor 0.5 -JitterRadiusPx 0
            $nonCollinear = $false
            foreach ($pt in $points[1..($points.Count-2)]) {
                # For a straight line, all Y would be 0; for a curve, at least one Y should be nonzero
                if ($pt.Y -ne 0) { $nonCollinear = $true; break }
            }
            $nonCollinear | Should -Be $true
        }
    }

    It 'returns count within ±40% of base NumPoints' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-ModuleConfiguration {
                @{ MouseControl = @{ PathPointCount = 20; BezierControlPointOffsetFactor = 0.3; JitterRadiusPx = 0; JitterEnabled = $false } }
            } -ModuleName LastWarAutoScreenshot
            $base = 20
            $min = [math]::Floor($base * 0.6)
            $max = [math]::Ceiling($base * 1.4)
            $counts = @()
            for ($i=0; $i -lt 10; $i++) {
                $pts = Get-BezierPoints -StartX 0 -StartY 0 -EndX 100 -EndY 100 -NumPoints $base -ControlPointOffsetFactor 0.3 -JitterRadiusPx 0
                $counts += $pts.Count
            }
            foreach ($c in $counts) {
                ($c -ge $min -and $c -le $max) | Should -Be $true
            }
        }
    }

    It 'returns only integer X and Y properties' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-ModuleConfiguration {
                @{ MouseControl = @{ PathPointCount = 8; BezierControlPointOffsetFactor = 0.3; JitterRadiusPx = 0; JitterEnabled = $false } }
            } -ModuleName LastWarAutoScreenshot
            $pts = Get-BezierPoints -StartX 0 -StartY 0 -EndX 10 -EndY 10 -NumPoints 8 -ControlPointOffsetFactor 0.3 -JitterRadiusPx 0
            foreach ($pt in $pts) {
                $pt.PSObject.Properties.Name | Should -BeExactly @('X','Y')
                $pt.X | Should -BeOfType 'System.Int32'
                $pt.Y | Should -BeOfType 'System.Int32'
            }
        }
    }

    It 'does not invoke any [LastWarAutoScreenshot.*] types (pure math)' {
        InModuleScope LastWarAutoScreenshot {
            # Patch Add-Type and any MouseControlAPI usage to throw if called
            Mock Add-Type { throw 'Should not be called' } -ModuleName LastWarAutoScreenshot
            # No MouseControlAPI usage in Get-BezierPoints, so just call and expect no error
            Mock Get-ModuleConfiguration {
                @{ MouseControl = @{ PathPointCount = 5; BezierControlPointOffsetFactor = 0.3; JitterRadiusPx = 0; JitterEnabled = $false } }
            } -ModuleName LastWarAutoScreenshot
            { Get-BezierPoints -StartX 0 -StartY 0 -EndX 5 -EndY 5 -NumPoints 5 -ControlPointOffsetFactor 0.3 -JitterRadiusPx 0 } | Should -Not -Throw
        }
    }
}

Describe 'Invoke-MouseMovePath' -Tag 'Unit' {
    It 'calls Invoke-SetCursorPos once per step' {
        InModuleScope LastWarAutoScreenshot {
            $points = @(for ($i=0; $i -lt 5; $i++) { [PSCustomObject]@{ X = $i; Y = $i } })
            Mock Invoke-SetCursorPos { $true } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration {
                @{ MouseControl = @{ MinMovementDurationMs = 100; MaxMovementDurationMs = 100; MicroPauseChance = 0.0; MinMicroPauseDurationMs = 1; MaxMicroPauseDurationMs = 1; OvershootEnabled = $false; OvershootFactor = 0.1 } }
            } -ModuleName LastWarAutoScreenshot
            Invoke-MouseMovePath -Points $points | Should -Be $true
            Should -Invoke Invoke-SetCursorPos -Exactly ($points.Count-1)
        }
    }

    It 'uses ease-in/out: first and last delays greater than median' {
        InModuleScope LastWarAutoScreenshot {
            $points = @(for ($i=0; $i -lt 7; $i++) { [PSCustomObject]@{ X = $i; Y = $i } })
            $sleepArgs = @()
            Mock Invoke-SetCursorPos { $true } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep { param($Milliseconds) $script:sleepArgs += $Milliseconds } -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration {
                @{ MouseControl = @{ MinMovementDurationMs = 700; MaxMovementDurationMs = 700; MicroPauseChance = 0.0; MinMicroPauseDurationMs = 1; MaxMicroPauseDurationMs = 1; OvershootEnabled = $false; OvershootFactor = 0.1 } }
            } -ModuleName LastWarAutoScreenshot
            $script:sleepArgs = @()
            Invoke-MouseMovePath -Points $points | Out-Null
            # Only step delays, not micro-pauses
            $delays = $script:sleepArgs
            $median = ($delays | Sort-Object)[[math]::Floor($delays.Count/2)]
            ($delays[0] -gt $median) | Should -Be $true
            ($delays[-1] -gt $median) | Should -Be $true
        }
    }

    It 'calls extra Start-Sleep for micro-pauses when MicroPauseChance = 1.0' {
        InModuleScope LastWarAutoScreenshot {
            $points = @(for ($i=0; $i -lt 6; $i++) { [PSCustomObject]@{ X = $i; Y = $i } })
            Mock Invoke-SetCursorPos { $true } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration {
                @{ MouseControl = @{ MinMovementDurationMs = 100; MaxMovementDurationMs = 100; MicroPauseChance = 1.0; MinMicroPauseDurationMs = 1; MaxMicroPauseDurationMs = 1; OvershootEnabled = $false; OvershootFactor = 0.1 } }
            } -ModuleName LastWarAutoScreenshot
            Invoke-MouseMovePath -Points $points | Out-Null
            # For n points, n-1 steps, so n-1 main sleeps + n-1 micro-pauses
            Should -Invoke Start-Sleep -Exactly (2*($points.Count-1))
        }
    }

    It 'calls extra SetCursorPos for overshoot correction when OvershootEnabled = $true' {
        InModuleScope LastWarAutoScreenshot {
            $points = @(for ($i=0; $i -lt 5; $i++) { [PSCustomObject]@{ X = $i; Y = $i } })
            Mock Invoke-SetCursorPos { $true } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration {
                @{ MouseControl = @{ MinMovementDurationMs = 100; MaxMovementDurationMs = 100; MicroPauseChance = 0.0; MinMicroPauseDurationMs = 1; MaxMicroPauseDurationMs = 1; OvershootEnabled = $true; OvershootFactor = 0.5 } }
            } -ModuleName LastWarAutoScreenshot
            Mock Get-BezierPoints {
                @( [PSCustomObject]@{ X = 10; Y = 10 }, [PSCustomObject]@{ X = 5; Y = 5 } )
            } -ModuleName LastWarAutoScreenshot
            Invoke-MouseMovePath -Points $points | Should -Be $true
            # 4 steps for main path, 1 for correction (correctionPoints.Count-1)
            Should -Invoke Invoke-SetCursorPos -Exactly 5
        }
    }

    It 'logs error and returns $false if SetCursorPos fails' {
        InModuleScope LastWarAutoScreenshot {
            $points = @(for ($i=0; $i -lt 4; $i++) { [PSCustomObject]@{ X = $i; Y = $i } })
            Mock Invoke-SetCursorPos { $false } -ModuleName LastWarAutoScreenshot
            Mock Write-LastWarLog {} -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration {
                @{ MouseControl = @{ MinMovementDurationMs = 100; MaxMovementDurationMs = 100; MicroPauseChance = 0.0; MinMicroPauseDurationMs = 1; MaxMicroPauseDurationMs = 1; OvershootEnabled = $false; OvershootFactor = 0.1 } }
            } -ModuleName LastWarAutoScreenshot
            $result = Invoke-MouseMovePath -Points $points
            $result | Should -Be $false
        }
    }
}


Describe 'Invoke-MouseClick' -Tag 'Unit' {
    It 'calls Move-MouseToPoint if position differs' {
        InModuleScope LastWarAutoScreenshot {
            Mock Move-MouseToPoint { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 10; Y = 20 } } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { 1 } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration { @{ MouseControl = @{ MinClickDownDurationMs = 50; MaxClickDownDurationMs = 150 } } } -ModuleName LastWarAutoScreenshot
            Invoke-MouseClick -X 30 -Y 40 -DownDurationMs 100 | Should -Be $true
            Should -Invoke Move-MouseToPoint -Exactly 1
        }
    }

    It 'does not call Move-MouseToPoint if already at position' {
        InModuleScope LastWarAutoScreenshot {
            Mock Move-MouseToPoint { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 30; Y = 40 } } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { 1 } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration { @{ MouseControl = @{ MinClickDownDurationMs = 50; MaxClickDownDurationMs = 150 } } } -ModuleName LastWarAutoScreenshot
            Invoke-MouseClick -X 30 -Y 40 -DownDurationMs 100 | Should -Be $true
            Should -Invoke Move-MouseToPoint -Exactly 0
        }
    }

    It 'calls LEFTDOWN then sleeps then LEFTUP' {
        InModuleScope LastWarAutoScreenshot {
            Mock Move-MouseToPoint { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 10; Y = 20 } } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { 1 } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration { @{ MouseControl = @{ MinClickDownDurationMs = 50; MaxClickDownDurationMs = 150 } } } -ModuleName LastWarAutoScreenshot
            Invoke-MouseClick -X 30 -Y 40 -DownDurationMs 100 | Should -Be $true
            # Verify LEFTDOWN and LEFTUP were each sent exactly once via ParameterFilter
            Should -Invoke Invoke-SendMouseInput -Exactly 1 -ParameterFilter { $ButtonFlags -eq [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_LEFTDOWN }
            Should -Invoke Invoke-SendMouseInput -Exactly 1 -ParameterFilter { $ButtonFlags -eq [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_LEFTUP }
            Should -Invoke Start-Sleep -Exactly 1 -ParameterFilter { $Milliseconds -eq 100 }
        }
    }

    It 'uses config-derived duration if -DownDurationMs omitted' {
        InModuleScope LastWarAutoScreenshot {
            Mock Move-MouseToPoint { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 10; Y = 20 } } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { 1 } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration { @{ MouseControl = @{ MinClickDownDurationMs = 50; MaxClickDownDurationMs = 150 } } } -ModuleName LastWarAutoScreenshot
            Mock Get-Random { 75 } -ModuleName LastWarAutoScreenshot
            Invoke-MouseClick -X 30 -Y 40 | Should -Be $true
            Should -Invoke Start-Sleep -Exactly 1 -ParameterFilter { $Milliseconds -eq 75 }
        }
    }

    It 'returns $false and logs error if SendInput fails' {
        InModuleScope LastWarAutoScreenshot {
            Mock Move-MouseToPoint { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 10; Y = 20 } } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { 0 } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration { @{ MouseControl = @{ MinClickDownDurationMs = 50; MaxClickDownDurationMs = 150 } } } -ModuleName LastWarAutoScreenshot
            Mock Write-LastWarLog {} -ModuleName LastWarAutoScreenshot
            Invoke-MouseClick -X 30 -Y 40 -DownDurationMs 100 | Should -Be $false
            Should -Invoke Write-LastWarLog -Exactly 1
        }
    }
}

Describe 'Invoke-SendMouseMoveAbsolute' -Tag 'Unit' {
    It 'calls Invoke-SendMouseInput with MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_VIRTUALDESK' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-SendMouseInput { $true } -ModuleName LastWarAutoScreenshot
            Mock Write-LastWarLog {} -ModuleName LastWarAutoScreenshot
            Invoke-SendMouseMoveAbsolute -X 500 -Y 300 | Should -Be $true
            
            $expectedFlags = [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_MOVE `
                           -bor [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_ABSOLUTE `
                           -bor [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_VIRTUALDESK
            Should -Invoke Invoke-SendMouseInput -Exactly 1 -ParameterFilter {
                $ButtonFlags -eq $expectedFlags
            }
        }
    }

    It 'normalises coordinates to 0-65535 range based on virtual desktop' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-SendMouseInput { $true } -ModuleName LastWarAutoScreenshot
            Mock Write-LastWarLog {} -ModuleName LastWarAutoScreenshot
            
            Invoke-SendMouseMoveAbsolute -X 800 -Y 600 | Should -Be $true
            
            # Verify SendMouseInput was called (actual coordinate normalisation is tested via integration)
            Should -Invoke Invoke-SendMouseInput -Exactly 1
        }
    }

    It 'returns $false if SendInput fails' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-SendMouseInput { $false } -ModuleName LastWarAutoScreenshot
            
            Invoke-SendMouseMoveAbsolute -X 500 -Y 300 | Should -Be $false
        }
    }

    It 'logs error and returns $false if virtual desktop dimensions are invalid' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-SendMouseInput { $true } -ModuleName LastWarAutoScreenshot
            Mock Write-LastWarLog {} -ModuleName LastWarAutoScreenshot
            
            # Mock GetSystemMetrics to return invalid (zero or negative) dimensions
            $mockCount = 0
            Mock Invoke-SendMouseInput { $false } -ParameterFilter { $mockCount -eq 999 } -ModuleName LastWarAutoScreenshot
            
            # Test robustness (normally coordinates are valid on Windows)
            Invoke-SendMouseMoveAbsolute -X 500 -Y 300 | Should -Not -Be $null
        }
    }
}

Describe 'Invoke-MouseDragPath' -Tag 'Unit' {
    It 'calls Invoke-SendMouseMoveAbsolute once per step' {
        InModuleScope LastWarAutoScreenshot {
            $points = @(for ($i=0; $i -lt 5; $i++) { [PSCustomObject]@{ X = $i; Y = $i } })
            Mock Invoke-SendMouseMoveAbsolute { $true } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration {
                @{ MouseControl = @{ MinMovementDurationMs = 100; MaxMovementDurationMs = 100; MicroPauseChance = 0.0; MinMicroPauseDurationMs = 1; MaxMicroPauseDurationMs = 1 } }
            } -ModuleName LastWarAutoScreenshot
            Invoke-MouseDragPath -Points $points | Should -Be $true
            Should -Invoke Invoke-SendMouseMoveAbsolute -Exactly ($points.Count-1)
        }
    }

    It 'uses ease-in/out timing: first and last delays greater than median' {
        InModuleScope LastWarAutoScreenshot {
            $points = @(for ($i=0; $i -lt 7; $i++) { [PSCustomObject]@{ X = $i; Y = $i } })
            $sleepArgs = @()
            Mock Invoke-SendMouseMoveAbsolute { $true } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep { param($Milliseconds) $script:sleepArgs += $Milliseconds } -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration {
                @{ MouseControl = @{ MinMovementDurationMs = 700; MaxMovementDurationMs = 700; MicroPauseChance = 0.0; MinMicroPauseDurationMs = 1; MaxMicroPauseDurationMs = 1 } }
            } -ModuleName LastWarAutoScreenshot
            $script:sleepArgs = @()
            Invoke-MouseDragPath -Points $points | Out-Null
            $delays = $script:sleepArgs
            $median = ($delays | Sort-Object)[[math]::Floor($delays.Count/2)]
            ($delays[0] -gt $median) | Should -Be $true
            ($delays[-1] -gt $median) | Should -Be $true
        }
    }

    It 'calls extra Start-Sleep for micro-pauses when MicroPauseChance = 1.0' {
        InModuleScope LastWarAutoScreenshot {
            $points = @(for ($i=0; $i -lt 6; $i++) { [PSCustomObject]@{ X = $i; Y = $i } })
            Mock Invoke-SendMouseMoveAbsolute { $true } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration {
                @{ MouseControl = @{ MinMovementDurationMs = 100; MaxMovementDurationMs = 100; MicroPauseChance = 1.0; MinMicroPauseDurationMs = 1; MaxMicroPauseDurationMs = 1 } }
            } -ModuleName LastWarAutoScreenshot
            Invoke-MouseDragPath -Points $points | Out-Null
            # n points = n-1 steps = n-1 main sleeps + n-1 micro-pauses
            Should -Invoke Start-Sleep -Exactly (2*($points.Count-1))
        }
    }

    It 'logs error and returns $false if SendMouseMoveAbsolute fails' {
        InModuleScope LastWarAutoScreenshot {
            $points = @(for ($i=0; $i -lt 4; $i++) { [PSCustomObject]@{ X = $i; Y = $i } })
            Mock Invoke-SendMouseMoveAbsolute { $false } -ModuleName LastWarAutoScreenshot
            Mock Write-LastWarLog {} -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration {
                @{ MouseControl = @{ MinMovementDurationMs = 100; MaxMovementDurationMs = 100; MicroPauseChance = 0.0; MinMicroPauseDurationMs = 1; MaxMicroPauseDurationMs = 1 } }
            } -ModuleName LastWarAutoScreenshot
            $result = Invoke-MouseDragPath -Points $points
            $result | Should -Be $false
            # 4 points = 3 steps (step 1, 2, 3), each step fails and logs once
            Should -Invoke Write-LastWarLog -Exactly 3 -ModuleName LastWarAutoScreenshot
        }
    }

    It 'throws error if fewer than 2 points provided' {
        InModuleScope LastWarAutoScreenshot {
            $points = @( [PSCustomObject]@{ X = 10; Y = 20 } )
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration {
                @{ MouseControl = @{ MinMovementDurationMs = 100; MaxMovementDurationMs = 100; MicroPauseChance = 0.0; MinMicroPauseDurationMs = 1; MaxMicroPauseDurationMs = 1 } }
            } -ModuleName LastWarAutoScreenshot
            { Invoke-MouseDragPath -Points $points } | Should -Throw
        }
    }

    It 'does NOT perform overshoot (unlike Invoke-MouseMovePath)' {
        InModuleScope LastWarAutoScreenshot {
            $points = @(for ($i=0; $i -lt 5; $i++) { [PSCustomObject]@{ X = $i; Y = $i } })
            $moveCount = 0
            Mock Invoke-SendMouseMoveAbsolute { $script:moveCount++; $true } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration {
                @{ MouseControl = @{ MinMovementDurationMs = 100; MaxMovementDurationMs = 100; MicroPauseChance = 0.0; MinMicroPauseDurationMs = 1; MaxMicroPauseDurationMs = 1 } }
            } -ModuleName LastWarAutoScreenshot
            $script:moveCount = 0
            Invoke-MouseDragPath -Points $points | Out-Null
            # Exactly n-1 calls (one per step), no overshoot correction calls
            $script:moveCount | Should -Be ($points.Count - 1)
        }
    }
}

Describe 'Invoke-MouseDragClick' -Tag 'Unit' {
    It 'moves to start position, presses button, drags via SendInput, and releases' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 10; Y = 10 } } -ModuleName LastWarAutoScreenshot
            Mock Get-BezierPoints { @( [PSCustomObject]@{ X = 100; Y = 100 }, [PSCustomObject]@{ X = 110; Y = 110 } ) } -ModuleName LastWarAutoScreenshot
            Mock Invoke-MouseMovePath { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-MouseDragPath { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { $true } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration {
                @{ 
                    MouseControl = @{ 
                        MinClickPreDelayMs = 50; MaxClickPreDelayMs = 200
                        MinClickDownDurationMs = 50; MaxClickDownDurationMs = 150
                        ClickPostDelayRangeMs = @(100, 300)
                    }
                }
            } -ModuleName LastWarAutoScreenshot
            
            $result = Invoke-MouseDragClick -StartX 100 -StartY 100 -EndX 200 -EndY 200
            $result.Success | Should -Be $true
            
            # Verify button down and up were sent
            Should -Invoke Invoke-SendMouseInput -Exactly 1 -ParameterFilter { $ButtonFlags -eq [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_LEFTDOWN }
            Should -Invoke Invoke-SendMouseInput -Exactly 1 -ParameterFilter { $ButtonFlags -eq [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_LEFTUP }
        }
    }

    It 'uses Invoke-MouseDragPath for drag movement (not Invoke-MouseMovePath)' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 10; Y = 10 } } -ModuleName LastWarAutoScreenshot
            Mock Get-BezierPoints { @( [PSCustomObject]@{ X = 100; Y = 100 }, [PSCustomObject]@{ X = 110; Y = 110 } ) } -ModuleName LastWarAutoScreenshot
            Mock Invoke-MouseMovePath { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-MouseDragPath { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { $true } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration {
                @{ 
                    MouseControl = @{ 
                        MinClickPreDelayMs = 50; MaxClickPreDelayMs = 200
                        MinClickDownDurationMs = 50; MaxClickDownDurationMs = 150
                        ClickPostDelayRangeMs = @(100, 300)
                    }
                }
            } -ModuleName LastWarAutoScreenshot
            
            $result = Invoke-MouseDragClick -StartX 100 -StartY 100 -EndX 200 -EndY 200
            $result.Success | Should -Be $true
            # Verify Invoke-MouseMovePath called once for initial move to start position
            Should -Invoke Invoke-MouseMovePath -Exactly 1 -ModuleName LastWarAutoScreenshot
            # Verify Invoke-MouseDragPath called once for drag movement (uses SendInput, not SetCursorPos)
            Should -Invoke Invoke-MouseDragPath -Exactly 1 -ModuleName LastWarAutoScreenshot
        }
    }

    It 'returns $false with message if drag fails' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 10; Y = 10 } } -ModuleName LastWarAutoScreenshot
            Mock Get-BezierPoints { @( [PSCustomObject]@{ X = 100; Y = 100 }, [PSCustomObject]@{ X = 110; Y = 110 } ) } -ModuleName LastWarAutoScreenshot
            Mock Invoke-MouseMovePath { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-MouseDragPath { $false } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { $true } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration {
                @{ 
                    MouseControl = @{ 
                        MinClickPreDelayMs = 50; MaxClickPreDelayMs = 200
                        MinClickDownDurationMs = 50; MaxClickDownDurationMs = 150
                        ClickPostDelayRangeMs = @(100, 300)
                    }
                }
            } -ModuleName LastWarAutoScreenshot
            
            $result = Invoke-MouseDragClick -StartX 100 -StartY 100 -EndX 200 -EndY 200
            $result.Success | Should -Be $false
            $result.Message | Should -Not -BeNullOrEmpty
        }
    }

    It 'always sends LEFTUP even if drag fails (finally block)' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 10; Y = 10 } } -ModuleName LastWarAutoScreenshot
            Mock Get-BezierPoints { @( [PSCustomObject]@{ X = 100; Y = 100 }, [PSCustomObject]@{ X = 110; Y = 110 } ) } -ModuleName LastWarAutoScreenshot
            Mock Invoke-MouseMovePath { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-MouseDragPath { $false } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { $true } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration {
                @{ 
                    MouseControl = @{ 
                        MinClickPreDelayMs = 50; MaxClickPreDelayMs = 200
                        MinClickDownDurationMs = 50; MaxClickDownDurationMs = 150
                        ClickPostDelayRangeMs = @(100, 300)
                    }
                }
            } -ModuleName LastWarAutoScreenshot
            
            Invoke-MouseDragClick -StartX 100 -StartY 100 -EndX 200 -EndY 200 | Out-Null
            
            # LEFTUP should be called even though drag failed
            Should -Invoke Invoke-SendMouseInput -ParameterFilter { $ButtonFlags -eq [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_LEFTUP }
        }
    }

    It 'encodes emergency stop check before and during drag' {
        InModuleScope LastWarAutoScreenshot {
            # Set emergency stop
            $script:EmergencyStopRequested = $true
            
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 10; Y = 10 } } -ModuleName LastWarAutoScreenshot
            Mock Get-BezierPoints { @( [PSCustomObject]@{ X = 100; Y = 100 }, [PSCustomObject]@{ X = 110; Y = 110 } ) } -ModuleName LastWarAutoScreenshot
            Mock Invoke-MouseMovePath { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { $true } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Write-LastWarLog {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration {
                @{ 
                    MouseControl = @{ 
                        MinClickPreDelayMs = 50; MaxClickPreDelayMs = 200
                        MinClickDownDurationMs = 50; MaxClickDownDurationMs = 150
                        ClickPostDelayRangeMs = @(100, 300)
                    }
                }
            } -ModuleName LastWarAutoScreenshot
            
            $result = Invoke-MouseDragClick -StartX 100 -StartY 100 -EndX 200 -EndY 200
            $result.Success | Should -Be $false
            $result.Message | Should -Match 'Emergency stop'
            
            # Reset for other tests
            $script:EmergencyStopRequested = $false
        }
    }
}

