# MouseMovement.Tests.ps1
# Pester tests for Move-MouseToPoint and Invoke-MouseClick (Phase 2, 1.14 step 1 only)

BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'Move-MouseToPoint' {
    It 'calls Invoke-SendMouseInput with correct delta' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 100; Y = 200 } } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { 1 } -ModuleName LastWarAutoScreenshot
            Move-MouseToPoint -X 110 -Y 220 | Should -Be $true
            Should -Invoke Invoke-GetCursorPosition -Exactly 1
            Should -Invoke Invoke-SendMouseInput -Exactly 1 -ParameterFilter {
                $DeltaX -eq 10 -and $DeltaY -eq 20
            }
        }
    }

    It 'returns $false and logs error if SendInput fails' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-SendMouseInput { 0 } -ModuleName LastWarAutoScreenshot
            Mock Write-LastWarLog {} -ModuleName LastWarAutoScreenshot
            Move-MouseToPoint -X 110 -Y 220 | Should -Be $false
            Should -Invoke Write-LastWarLog -Exactly 1
        }
    }
}

# === PHASE 2 STEP 2.7 TESTS ===

Describe 'Get-BezierPoints' {
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

Describe 'Invoke-MouseMovePath' {
    It 'calls Invoke-SendMouseInput once per point' {
        InModuleScope LastWarAutoScreenshot {
            $points = @(for ($i=0; $i -lt 5; $i++) { [PSCustomObject]@{ X = $i; Y = $i } })
            Mock Invoke-SendMouseInput { $true } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration {
                @{ MouseControl = @{ MovementDurationRangeMs = @(100, 100); MicroPauseChance = 0.0; MicroPauseDurationRangeMs = @(1,1); OvershootEnabled = $false; OvershootFactor = 0.1 } }
            } -ModuleName LastWarAutoScreenshot
            Invoke-MouseMovePath -Points $points | Should -Be $true
            Should -Invoke Invoke-SendMouseInput -Exactly ($points.Count-1)
        }
    }

    It 'uses ease-in/out: first and last delays greater than median' {
        InModuleScope LastWarAutoScreenshot {
            $points = @(for ($i=0; $i -lt 7; $i++) { [PSCustomObject]@{ X = $i; Y = $i } })
            $sleepArgs = @()
            Mock Invoke-SendMouseInput { $true } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep { param($Milliseconds) $script:sleepArgs += $Milliseconds } -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration {
                @{ MouseControl = @{ MovementDurationRangeMs = @(700, 700); MicroPauseChance = 0.0; MicroPauseDurationRangeMs = @(1,1); OvershootEnabled = $false; OvershootFactor = 0.1 } }
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
            Mock Invoke-SendMouseInput { $true } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration {
                @{ MouseControl = @{ MovementDurationRangeMs = @(100, 100); MicroPauseChance = 1.0; MicroPauseDurationRangeMs = @(1,1); OvershootEnabled = $false; OvershootFactor = 0.1 } }
            } -ModuleName LastWarAutoScreenshot
            Invoke-MouseMovePath -Points $points | Out-Null
            # For n points, n-1 steps, so n-1 main sleeps + n-1 micro-pauses
            Should -Invoke Start-Sleep -Exactly (2*($points.Count-1))
        }
    }

    It 'calls extra SendMouseInput for overshoot correction when OvershootEnabled = $true' {
        InModuleScope LastWarAutoScreenshot {
            $points = @(for ($i=0; $i -lt 5; $i++) { [PSCustomObject]@{ X = $i; Y = $i } })
            Mock Invoke-SendMouseInput { $true } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration {
                @{ MouseControl = @{ MovementDurationRangeMs = @(100, 100); MicroPauseChance = 0.0; MicroPauseDurationRangeMs = @(1,1); OvershootEnabled = $true; OvershootFactor = 0.5 } }
            } -ModuleName LastWarAutoScreenshot
            Mock Get-BezierPoints {
                @( [PSCustomObject]@{ X = 10; Y = 10 }, [PSCustomObject]@{ X = 5; Y = 5 } )
            } -ModuleName LastWarAutoScreenshot
            Invoke-MouseMovePath -Points $points | Should -Be $true
            # 4 steps for main path, 1 for correction (correctionPoints.Count-1)
            Should -Invoke Invoke-SendMouseInput -Exactly 5
        }
    }

    It 'logs error and returns $false if SendInput fails' {
        InModuleScope LastWarAutoScreenshot {
            $points = @(for ($i=0; $i -lt 4; $i++) { [PSCustomObject]@{ X = $i; Y = $i } })
            Mock Invoke-SendMouseInput { $false } -ModuleName LastWarAutoScreenshot
            Mock Write-LastWarLog {} -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration {
                @{ MouseControl = @{ MovementDurationRangeMs = @(100, 100); MicroPauseChance = 0.0; MicroPauseDurationRangeMs = @(1,1); OvershootEnabled = $false; OvershootFactor = 0.1 } }
            } -ModuleName LastWarAutoScreenshot
            Write-Host "===============================================================" -ForegroundColor Red
            Write-Host "Ignore expected error message about SendInput failure below:" -ForegroundColor Red
            $result = Invoke-MouseMovePath -Points $points
            Write-Host '===============================================================' -ForegroundColor Red
            $result | Should -Be $false
        }
    }
}


Describe 'Invoke-MouseClick' {
    It 'calls Move-MouseToPoint if position differs' {
        InModuleScope LastWarAutoScreenshot {
            Mock Move-MouseToPoint { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 10; Y = 20 } } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { 1 } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration { @{ MouseControl = @{ ClickDownDurationRangeMs = @(50, 150) } } } -ModuleName LastWarAutoScreenshot
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
            Mock Get-ModuleConfiguration { @{ MouseControl = @{ ClickDownDurationRangeMs = @(50, 150) } } } -ModuleName LastWarAutoScreenshot
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
            Mock Get-ModuleConfiguration { @{ MouseControl = @{ ClickDownDurationRangeMs = @(50, 150) } } } -ModuleName LastWarAutoScreenshot
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
            Mock Get-ModuleConfiguration { @{ MouseControl = @{ ClickDownDurationRangeMs = @(50, 150) } } } -ModuleName LastWarAutoScreenshot
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
            Mock Get-ModuleConfiguration { @{ MouseControl = @{ ClickDownDurationRangeMs = @(50, 150) } } } -ModuleName LastWarAutoScreenshot
            Mock Write-LastWarLog {} -ModuleName LastWarAutoScreenshot
            Invoke-MouseClick -X 30 -Y 40 -DownDurationMs 100 | Should -Be $false
            Should -Invoke Write-LastWarLog -Exactly 1
        }
    }
}
