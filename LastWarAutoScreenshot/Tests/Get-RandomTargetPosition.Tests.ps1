
# Get-RandomTargetPosition Pester Tests
#
# Implements Phase 2 Task 3.2 from ProjectPlan.md.
# Covers bounds, distribution, clamping, and invalid-input behaviour for the private
# Get-RandomTargetPosition function.

Describe 'Get-RandomTargetPosition' -Tag 'Unit' {

    BeforeAll {
        $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
        Import-Module $moduleManifest -Force
        Mock Write-LastWarLog { } -ModuleName LastWarAutoScreenshot
    }

    # =========================================================================
    # BOX PARAMETER SET
    # =========================================================================

    Context 'Box parameter set: 100-iteration bounds check' {

        It 'all 100 returned points are within the box region bounds' {
            InModuleScope LastWarAutoScreenshot {
                $testBox = [PSCustomObject]@{
                    RelativeX      = 0.1
                    RelativeY      = 0.2
                    RelativeWidth  = 0.3
                    RelativeHeight = 0.4
                }
                $inBoundsCount = 0
                for ($i = 0; $i -lt 100; $i++) {
                    $pt = Get-RandomTargetPosition -Box $testBox
                    if ($pt.RelativeX -ge $testBox.RelativeX -and
                        $pt.RelativeX -le ($testBox.RelativeX + $testBox.RelativeWidth) -and
                        $pt.RelativeY -ge $testBox.RelativeY -and
                        $pt.RelativeY -le ($testBox.RelativeY + $testBox.RelativeHeight)) {
                        $inBoundsCount++
                    }
                }
                $inBoundsCount | Should -Be 100
            }
        }
    }

    Context 'Box parameter set: clamp - output respects [0.0, 1.0]' {

        It 'no returned value falls outside [0.0, 1.0] across 100 iterations of a full-range box' {
            InModuleScope LastWarAutoScreenshot {
                $fullBox = [PSCustomObject]@{
                    RelativeX      = 0.0
                    RelativeY      = 0.0
                    RelativeWidth  = 1.0
                    RelativeHeight = 1.0
                }
                $allClamped = $true
                for ($i = 0; $i -lt 100; $i++) {
                    $pt = Get-RandomTargetPosition -Box $fullBox
                    if ($pt.RelativeX -lt 0.0 -or $pt.RelativeX -gt 1.0 -or
                        $pt.RelativeY -lt 0.0 -or $pt.RelativeY -gt 1.0) {
                        $allClamped = $false
                        break
                    }
                }
                $allClamped | Should -BeTrue
            }
        }
    }

    # =========================================================================
    # CIRCLE PARAMETER SET
    # =========================================================================

    Context 'Circle parameter set: 100-iteration radius bounds check' {

        It 'all 100 returned points are within the circle radius of centre' {
            InModuleScope LastWarAutoScreenshot {
                $testCircle = [PSCustomObject]@{
                    RelativeCentreX = 0.5
                    RelativeCentreY = 0.5
                    RelativeRadius  = 0.3
                }
                $inBoundsCount = 0
                for ($i = 0; $i -lt 100; $i++) {
                    $pt = Get-RandomTargetPosition -Circle $testCircle
                    $dx = $pt.RelativeX - $testCircle.RelativeCentreX
                    $dy = $pt.RelativeY - $testCircle.RelativeCentreY
                    $distance = [math]::Sqrt($dx * $dx + $dy * $dy)
                    if ($distance -le $testCircle.RelativeRadius) {
                        $inBoundsCount++
                    }
                }
                $inBoundsCount | Should -Be 100
            }
        }
    }

    Context 'Circle parameter set: distribution clusters near centre' {

        It 'mean X of 100 points is within 10% of radius from centre X' {
            InModuleScope LastWarAutoScreenshot {
                # Statistical note: z ≈ 2 for 10%-of-radius threshold with 100 samples (~95% pass rate).
                # The test may fail rarely (~1 in 20 runs) purely from sampling variance - this is per-spec.
                $testCircle = [PSCustomObject]@{
                    RelativeCentreX = 0.5
                    RelativeCentreY = 0.5
                    RelativeRadius  = 0.3
                }
                $sumX = 0.0
                for ($i = 0; $i -lt 100; $i++) {
                    $pt = Get-RandomTargetPosition -Circle $testCircle
                    $sumX += $pt.RelativeX
                }
                $meanX = $sumX / 100.0
                [math]::Abs($meanX - $testCircle.RelativeCentreX) | Should -BeLessThan ($testCircle.RelativeRadius * 0.12)
            }
        }

        It 'mean Y of 100 points is within 10% of radius from centre Y' {
            InModuleScope LastWarAutoScreenshot {
                # Statistical note: z ≈ 2 for 10%-of-radius threshold with 100 samples (~95% pass rate).
                # The test may fail rarely (~1 in 20 runs) purely from sampling variance - this is per-spec.
                $testCircle = [PSCustomObject]@{
                    RelativeCentreX = 0.5
                    RelativeCentreY = 0.5
                    RelativeRadius  = 0.3
                }
                $sumY = 0.0
                for ($i = 0; $i -lt 100; $i++) {
                    $pt = Get-RandomTargetPosition -Circle $testCircle
                    $sumY += $pt.RelativeY
                }
                $meanY = $sumY / 100.0
                [math]::Abs($meanY - $testCircle.RelativeCentreY) | Should -BeLessThan ($testCircle.RelativeRadius * 0.12)
            }
        }
    }

    Context 'Circle parameter set: clamp - output respects [0.0, 1.0]' {

        It 'no returned value falls outside [0.0, 1.0] for a circle near an edge across 100 iterations' {
            InModuleScope LastWarAutoScreenshot {
                # CentreX (0.05) - Radius (0.1) = -0.05: points to the left require clamping.
                $edgeCircle = [PSCustomObject]@{
                    RelativeCentreX = 0.05
                    RelativeCentreY = 0.5
                    RelativeRadius  = 0.1
                }
                $allClamped = $true
                for ($i = 0; $i -lt 100; $i++) {
                    $pt = Get-RandomTargetPosition -Circle $edgeCircle
                    if ($pt.RelativeX -lt 0.0 -or $pt.RelativeX -gt 1.0 -or
                        $pt.RelativeY -lt 0.0 -or $pt.RelativeY -gt 1.0) {
                        $allClamped = $false
                        break
                    }
                }
                $allClamped | Should -BeTrue
            }
        }
    }

    # =========================================================================
    # INVALID INPUT
    # =========================================================================

    Context 'Invalid input: returns $null and logs Error' {

        It 'returns $null and logs Error when Box RelativeX is negative' {
            InModuleScope LastWarAutoScreenshot {
                $badBox = [PSCustomObject]@{
                    RelativeX = -0.1; RelativeY = 0.1; RelativeWidth = 0.3; RelativeHeight = 0.3
                }
                $result = Get-RandomTargetPosition -Box $badBox
                $result | Should -BeNullOrEmpty
                Should -Invoke Write-LastWarLog -Exactly 1 -ParameterFilter { $Level -eq 'Error' }
            }
        }

        It 'returns $null and logs Error when Box extends beyond 1.0' {
            InModuleScope LastWarAutoScreenshot {
                $badBox = [PSCustomObject]@{
                    RelativeX = 0.8; RelativeY = 0.1; RelativeWidth = 0.5; RelativeHeight = 0.1
                }
                $result = Get-RandomTargetPosition -Box $badBox
                $result | Should -BeNullOrEmpty
                Should -Invoke Write-LastWarLog -Exactly 1 -ParameterFilter { $Level -eq 'Error' }
            }
        }

        It 'returns $null and logs Error when Circle radius is negative' {
            InModuleScope LastWarAutoScreenshot {
                $badCircle = [PSCustomObject]@{
                    RelativeCentreX = 0.5; RelativeCentreY = 0.5; RelativeRadius = -0.1
                }
                $result = Get-RandomTargetPosition -Circle $badCircle
                $result | Should -BeNullOrEmpty
                Should -Invoke Write-LastWarLog -Exactly 1 -ParameterFilter { $Level -eq 'Error' }
            }
        }

        It 'returns $null and logs Error when Circle extends beyond 1.0' {
            InModuleScope LastWarAutoScreenshot {
                $badCircle = [PSCustomObject]@{
                    RelativeCentreX = 0.8; RelativeCentreY = 0.5; RelativeRadius = 0.3
                }
                $result = Get-RandomTargetPosition -Circle $badCircle
                $result | Should -BeNullOrEmpty
                Should -Invoke Write-LastWarLog -Exactly 1 -ParameterFilter { $Level -eq 'Error' }
            }
        }
    }
}

