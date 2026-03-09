BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force

    $testingDll = Join-Path $PSScriptRoot '..\lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}

# ============================================================
# Invoke-MacroAction
# ============================================================

Describe 'Invoke-MacroAction' -Tag 'Unit' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            $script:EmergencyStopRequested = $false
            Mock ConvertTo-ScreenCoordinates { [PSCustomObject]@{ X = 100; Y = 200 } }
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 50; Y = 60 } }
            Mock Get-BezierPoints {
                @(
                    [PSCustomObject]@{ X = 50; Y = 60 },
                    [PSCustomObject]@{ X = 100; Y = 200 }
                )
            }
            Mock Invoke-MouseMovePath { $true }
            Mock Invoke-MouseClick { $true }
            Mock Invoke-MouseDragClick { [PSCustomObject]@{ Success = $true; Message = '' } }
            Mock Get-RandomTargetPosition { [PSCustomObject]@{ RelativeX = 0.5; RelativeY = 0.5 } }
            Mock Start-Sleep {}
            Mock Write-LastWarLog {}
            Mock Invoke-CaptureScreenRegion {
                [PSCustomObject]@{ Success = $true; Skipped = $false; FilePath = 'TestDrive:\Screenshots\test.png'; Message = '' }
            }
            Mock Test-ScreenshotSimilarity {
                [PSCustomObject]@{ Similar = $false; MatchPercent = 0.5; Skipped = $false; Message = '' }
            }
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    Screenshots = [PSCustomObject]@{
                        SimilarityCheck = [PSCustomObject]@{
                            Enabled              = $false
                            Threshold            = 0.98
                            SampleCount          = 1000
                            TolerancePerChannel  = 10
                            FullScan             = $false
                            Action               = 'StopNestedMacro'
                            ConsecutiveThreshold = 1
                        }
                    }
                }
            }
        }
    }

    AfterEach {
        InModuleScope LastWarAutoScreenshot {
            $script:EmergencyStopRequested = $false
        }
    }

    It 'MoveToPoint: calls ConvertTo-ScreenCoordinates with action coordinates; Invoke-MouseMovePath called; returns Success=$true' {
        InModuleScope LastWarAutoScreenshot {
            $action = [PSCustomObject]@{
                type     = 'MoveToPoint'
                position = [PSCustomObject]@{ relativeX = 0.3; relativeY = 0.7 }
            }

            $result = Invoke-MacroAction -Action $action -WindowHandle ([IntPtr]::new(1)) -ActionLookup @{}

            Should -Invoke ConvertTo-ScreenCoordinates -Times 1 -ParameterFilter {
                $RelativeX -eq 0.3 -and $RelativeY -eq 0.7
            }
            Should -Invoke Invoke-MouseMovePath -Times 1
            $result.Success | Should -BeTrue
            $result.Skipped | Should -BeFalse
        }
    }

    It 'MoveToRegion Box: calls Get-RandomTargetPosition with Box parameter set; coordinates converted and path followed' {
        InModuleScope LastWarAutoScreenshot {
            $action = [PSCustomObject]@{
                type   = 'MoveToRegion'
                region = [PSCustomObject]@{
                    type           = 'Box'
                    relativeX      = 0.1
                    relativeY      = 0.2
                    relativeWidth  = 0.3
                    relativeHeight = 0.4
                }
            }

            $result = Invoke-MacroAction -Action $action -WindowHandle ([IntPtr]::new(1)) -ActionLookup @{}

            Should -Invoke Get-RandomTargetPosition -Times 1 -ParameterFilter { $null -ne $Box }
            Should -Invoke ConvertTo-ScreenCoordinates -Times 1
            Should -Invoke Invoke-MouseMovePath -Times 1
            $result.Success | Should -BeTrue
        }
    }

    It 'MoveToRegion Circle: calls Get-RandomTargetPosition with Circle parameter set' {
        InModuleScope LastWarAutoScreenshot {
            $action = [PSCustomObject]@{
                type   = 'MoveToRegion'
                region = [PSCustomObject]@{
                    type            = 'Circle'
                    relativeCentreX = 0.5
                    relativeCentreY = 0.5
                    relativeRadius  = 0.1
                }
            }

            Invoke-MacroAction -Action $action -WindowHandle ([IntPtr]::new(1)) -ActionLookup @{} | Out-Null

            Should -Invoke Get-RandomTargetPosition -Times 1 -ParameterFilter { $null -ne $Circle }
        }
    }

    It 'LeftClick: calls Invoke-GetCursorPosition then Invoke-MouseClick at cursor coordinates; returns Success=$true' {
        InModuleScope LastWarAutoScreenshot {
            $action = [PSCustomObject]@{ type = 'LeftClick' }

            $result = Invoke-MacroAction -Action $action -WindowHandle ([IntPtr]::new(1)) -ActionLookup @{}

            Should -Invoke Invoke-GetCursorPosition -Times 1
            Should -Invoke Invoke-MouseClick -Times 1 -ParameterFilter { $X -eq 50 -and $Y -eq 60 }
            $result.Success | Should -BeTrue
            $result.Skipped | Should -BeFalse
        }
    }

    It 'DragClick: calls ConvertTo-ScreenCoordinates twice and Invoke-MouseDragClick with screen coords' {
        InModuleScope LastWarAutoScreenshot {
            $action = [PSCustomObject]@{
                type  = 'DragClick'
                start = [PSCustomObject]@{ relativeX = 0.1; relativeY = 0.2 }
                end   = [PSCustomObject]@{ relativeX = 0.8; relativeY = 0.9 }
            }

            $result = Invoke-MacroAction -Action $action -WindowHandle ([IntPtr]::new(1)) -ActionLookup @{}

            Should -Invoke ConvertTo-ScreenCoordinates -Times 2
            Should -Invoke Invoke-MouseDragClick -Times 1 -ParameterFilter {
                $StartX -eq 100 -and $StartY -eq 200 -and $EndX -eq 100 -and $EndY -eq 200
            }
            $result.Success | Should -BeTrue
        }
    }

    It 'Screenshot: ScreenshotContext supplied, capture succeeds; returns Success=$true, Skipped=$false, SimilarityStop=$false' {
        InModuleScope LastWarAutoScreenshot {
            $action = [PSCustomObject]@{
                type   = 'Screenshot'
                region = [PSCustomObject]@{
                    relativeTopLeftX     = 0.0
                    relativeTopLeftY     = 0.0
                    relativeBottomRightX = 1.0
                    relativeBottomRightY = 1.0
                }
            }
            $ctx = @{ Index = 0; MacroName = 'test'; ActionName = ''; PreviousScreenshotPath = $null; ConsecutiveSimilarCount = 0 }

            $result = Invoke-MacroAction -Action $action -WindowHandle ([IntPtr]::new(1)) -ActionLookup @{} -ScreenshotContext $ctx

            Should -Invoke Invoke-CaptureScreenRegion -Times 1
            $result.Success       | Should -BeTrue
            $result.Skipped       | Should -BeFalse
            $result.SimilarityStop | Should -BeFalse
        }
    }

    It 'Screenshot: ScreenshotContext=$null logs Warning, returns Success=$true Skipped=$true; Invoke-CaptureScreenRegion NOT called' {
        InModuleScope LastWarAutoScreenshot {
            $action = [PSCustomObject]@{
                type   = 'Screenshot'
                region = [PSCustomObject]@{
                    relativeTopLeftX     = 0.0
                    relativeTopLeftY     = 0.0
                    relativeBottomRightX = 1.0
                    relativeBottomRightY = 1.0
                }
            }

            $result = Invoke-MacroAction -Action $action -WindowHandle ([IntPtr]::new(1)) -ActionLookup @{}

            Should -Invoke Write-LastWarLog -Times 1 -ParameterFilter { $Level -eq 'Warning' }
            Should -Invoke Invoke-CaptureScreenRegion -Times 0
            $result.Success | Should -BeTrue
            $result.Skipped | Should -BeTrue
        }
    }

    It 'Screenshot: StoragePath not configured (capture returns Skipped=$true); returns Success=$true Skipped=$true SimilarityStop=$false' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-CaptureScreenRegion {
                [PSCustomObject]@{ Success = $false; Skipped = $true; FilePath = $null; Message = 'StoragePath not configured' }
            }
            $action = [PSCustomObject]@{
                type   = 'Screenshot'
                region = [PSCustomObject]@{
                    relativeTopLeftX     = 0.0
                    relativeTopLeftY     = 0.0
                    relativeBottomRightX = 1.0
                    relativeBottomRightY = 1.0
                }
            }
            $ctx = @{ Index = 0; MacroName = 'test'; ActionName = ''; PreviousScreenshotPath = $null; ConsecutiveSimilarCount = 0 }

            $result = Invoke-MacroAction -Action $action -WindowHandle ([IntPtr]::new(1)) -ActionLookup @{} -ScreenshotContext $ctx

            $result.Success       | Should -BeTrue
            $result.Skipped       | Should -BeTrue
            $result.SimilarityStop | Should -BeFalse
        }
    }

    It 'Screenshot: capture fails; returns Success=$false Skipped=$false' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-CaptureScreenRegion {
                [PSCustomObject]@{ Success = $false; Skipped = $false; FilePath = $null; Message = 'CaptureWindowRegion failed' }
            }
            $action = [PSCustomObject]@{
                type   = 'Screenshot'
                region = [PSCustomObject]@{
                    relativeTopLeftX     = 0.0
                    relativeTopLeftY     = 0.0
                    relativeBottomRightX = 1.0
                    relativeBottomRightY = 1.0
                }
            }
            $ctx = @{ Index = 0; MacroName = 'test'; ActionName = ''; PreviousScreenshotPath = $null; ConsecutiveSimilarCount = 0 }

            $result = Invoke-MacroAction -Action $action -WindowHandle ([IntPtr]::new(1)) -ActionLookup @{} -ScreenshotContext $ctx

            $result.Success | Should -BeFalse
            $result.Skipped | Should -BeFalse
        }
    }

    It 'Screenshot: StopNestedMacro, ConsecutiveThreshold=1, similar; returns SimilarityStop=$true; ConsecutiveSimilarCount=1' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    Screenshots = [PSCustomObject]@{
                        SimilarityCheck = [PSCustomObject]@{
                            Enabled              = $true
                            Threshold            = 0.98
                            SampleCount          = 1000
                            TolerancePerChannel  = 10
                            FullScan             = $false
                            Action               = 'StopNestedMacro'
                            ConsecutiveThreshold = 1
                        }
                    }
                }
            }
            Mock Test-ScreenshotSimilarity {
                [PSCustomObject]@{ Similar = $true; MatchPercent = 0.99; Skipped = $false; Message = '' }
            }
            $action = [PSCustomObject]@{
                type   = 'Screenshot'
                region = [PSCustomObject]@{
                    relativeTopLeftX     = 0.0
                    relativeTopLeftY     = 0.0
                    relativeBottomRightX = 1.0
                    relativeBottomRightY = 1.0
                }
            }
            $ctx = @{ Index = 0; MacroName = 'test'; ActionName = ''; PreviousScreenshotPath = 'TestDrive:\prev.png'; ConsecutiveSimilarCount = 0 }

            $result = Invoke-MacroAction -Action $action -WindowHandle ([IntPtr]::new(1)) -ActionLookup @{} -ScreenshotContext $ctx

            $result.Success       | Should -BeTrue
            $result.SimilarityStop | Should -BeTrue
            Should -Invoke Write-LastWarLog -Times 1 -ParameterFilter { $Level -eq 'Info' }
            $ctx.ConsecutiveSimilarCount | Should -Be 1
        }
    }

    It 'Screenshot: ConsecutiveThreshold=3, 2nd consecutive match — SimilarityStop=$false; ConsecutiveSimilarCount=2' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    Screenshots = [PSCustomObject]@{
                        SimilarityCheck = [PSCustomObject]@{
                            Enabled              = $true
                            Threshold            = 0.98
                            SampleCount          = 1000
                            TolerancePerChannel  = 10
                            FullScan             = $false
                            Action               = 'StopNestedMacro'
                            ConsecutiveThreshold = 3
                        }
                    }
                }
            }
            Mock Test-ScreenshotSimilarity {
                [PSCustomObject]@{ Similar = $true; MatchPercent = 0.99; Skipped = $false; Message = '' }
            }
            $action = [PSCustomObject]@{
                type   = 'Screenshot'
                region = [PSCustomObject]@{
                    relativeTopLeftX     = 0.0
                    relativeTopLeftY     = 0.0
                    relativeBottomRightX = 1.0
                    relativeBottomRightY = 1.0
                }
            }
            $ctx = @{ Index = 0; MacroName = 'test'; ActionName = ''; PreviousScreenshotPath = 'TestDrive:\prev.png'; ConsecutiveSimilarCount = 1 }

            $result = Invoke-MacroAction -Action $action -WindowHandle ([IntPtr]::new(1)) -ActionLookup @{} -ScreenshotContext $ctx

            $result.Success       | Should -BeTrue
            $result.SimilarityStop | Should -BeFalse
            $ctx.ConsecutiveSimilarCount | Should -Be 2
        }
    }

    It 'Screenshot: ConsecutiveThreshold=3, 3rd consecutive match — SimilarityStop=$true' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    Screenshots = [PSCustomObject]@{
                        SimilarityCheck = [PSCustomObject]@{
                            Enabled              = $true
                            Threshold            = 0.98
                            SampleCount          = 1000
                            TolerancePerChannel  = 10
                            FullScan             = $false
                            Action               = 'StopNestedMacro'
                            ConsecutiveThreshold = 3
                        }
                    }
                }
            }
            Mock Test-ScreenshotSimilarity {
                [PSCustomObject]@{ Similar = $true; MatchPercent = 0.99; Skipped = $false; Message = '' }
            }
            $action = [PSCustomObject]@{
                type   = 'Screenshot'
                region = [PSCustomObject]@{
                    relativeTopLeftX     = 0.0
                    relativeTopLeftY     = 0.0
                    relativeBottomRightX = 1.0
                    relativeBottomRightY = 1.0
                }
            }
            $ctx = @{ Index = 0; MacroName = 'test'; ActionName = ''; PreviousScreenshotPath = 'TestDrive:\prev.png'; ConsecutiveSimilarCount = 2 }

            $result = Invoke-MacroAction -Action $action -WindowHandle ([IntPtr]::new(1)) -ActionLookup @{} -ScreenshotContext $ctx

            $result.Success       | Should -BeTrue
            $result.SimilarityStop | Should -BeTrue
        }
    }

    It 'Screenshot: consecutive count reset to 0 when images are not similar' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    Screenshots = [PSCustomObject]@{
                        SimilarityCheck = [PSCustomObject]@{
                            Enabled              = $true
                            Threshold            = 0.98
                            SampleCount          = 1000
                            TolerancePerChannel  = 10
                            FullScan             = $false
                            Action               = 'StopNestedMacro'
                            ConsecutiveThreshold = 1
                        }
                    }
                }
            }
            Mock Test-ScreenshotSimilarity {
                [PSCustomObject]@{ Similar = $false; MatchPercent = 0.40; Skipped = $false; Message = '' }
            }
            $action = [PSCustomObject]@{
                type   = 'Screenshot'
                region = [PSCustomObject]@{
                    relativeTopLeftX     = 0.0
                    relativeTopLeftY     = 0.0
                    relativeBottomRightX = 1.0
                    relativeBottomRightY = 1.0
                }
            }
            $ctx = @{ Index = 0; MacroName = 'test'; ActionName = ''; PreviousScreenshotPath = 'TestDrive:\prev.png'; ConsecutiveSimilarCount = 2 }

            $result = Invoke-MacroAction -Action $action -WindowHandle ([IntPtr]::new(1)) -ActionLookup @{} -ScreenshotContext $ctx

            $result.Success       | Should -BeTrue
            $result.SimilarityStop | Should -BeFalse
            $ctx.ConsecutiveSimilarCount | Should -Be 0
        }
    }

    It 'Screenshot: Warn action on similar images; returns Success=$true SimilarityStop=$false; logs Warning' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    Screenshots = [PSCustomObject]@{
                        SimilarityCheck = [PSCustomObject]@{
                            Enabled              = $true
                            Threshold            = 0.98
                            SampleCount          = 1000
                            TolerancePerChannel  = 10
                            FullScan             = $false
                            Action               = 'Warn'
                            ConsecutiveThreshold = 1
                        }
                    }
                }
            }
            Mock Test-ScreenshotSimilarity {
                [PSCustomObject]@{ Similar = $true; MatchPercent = 0.99; Skipped = $false; Message = '' }
            }
            $action = [PSCustomObject]@{
                type   = 'Screenshot'
                region = [PSCustomObject]@{
                    relativeTopLeftX     = 0.0
                    relativeTopLeftY     = 0.0
                    relativeBottomRightX = 1.0
                    relativeBottomRightY = 1.0
                }
            }
            $ctx = @{ Index = 0; MacroName = 'test'; ActionName = ''; PreviousScreenshotPath = 'TestDrive:\prev.png'; ConsecutiveSimilarCount = 0 }

            $result = Invoke-MacroAction -Action $action -WindowHandle ([IntPtr]::new(1)) -ActionLookup @{} -ScreenshotContext $ctx

            $result.Success       | Should -BeTrue
            $result.SimilarityStop | Should -BeFalse
            Should -Invoke Write-LastWarLog -Times 1 -ParameterFilter { $Level -eq 'Warning' }
        }
    }

    It 'Screenshot: similarity not run when PreviousScreenshotPath=$null (first screenshot)' {
        InModuleScope LastWarAutoScreenshot {
            $action = [PSCustomObject]@{
                type   = 'Screenshot'
                region = [PSCustomObject]@{
                    relativeTopLeftX     = 0.0
                    relativeTopLeftY     = 0.0
                    relativeBottomRightX = 1.0
                    relativeBottomRightY = 1.0
                }
            }
            $ctx = @{ Index = 0; MacroName = 'test'; ActionName = ''; PreviousScreenshotPath = $null; ConsecutiveSimilarCount = 0 }

            Invoke-MacroAction -Action $action -WindowHandle ([IntPtr]::new(1)) -ActionLookup @{} -ScreenshotContext $ctx | Out-Null

            Should -Invoke Test-ScreenshotSimilarity -Times 0
        }
    }

    It 'Screenshot: similarity not run when SimilarityCheck.Enabled=$false' {
        InModuleScope LastWarAutoScreenshot {
            $action = [PSCustomObject]@{
                type   = 'Screenshot'
                region = [PSCustomObject]@{
                    relativeTopLeftX     = 0.0
                    relativeTopLeftY     = 0.0
                    relativeBottomRightX = 1.0
                    relativeBottomRightY = 1.0
                }
            }
            $ctx = @{ Index = 0; MacroName = 'test'; ActionName = ''; PreviousScreenshotPath = 'TestDrive:\prev.png'; ConsecutiveSimilarCount = 0 }

            Invoke-MacroAction -Action $action -WindowHandle ([IntPtr]::new(1)) -ActionLookup @{} -ScreenshotContext $ctx | Out-Null

            Should -Invoke Test-ScreenshotSimilarity -Times 0
        }
    }

    It 'Delay with seconds=5: calls Start-Sleep -Seconds 5; returns Success=$true' {
        InModuleScope LastWarAutoScreenshot {
            $action = [PSCustomObject]@{ type = 'Delay'; seconds = 5 }

            $result = Invoke-MacroAction -Action $action -WindowHandle ([IntPtr]::new(1)) -ActionLookup @{}

            Should -Invoke Start-Sleep -Times 1 -ParameterFilter { $Seconds -eq 5 }
            $result.Success | Should -BeTrue
        }
    }

    It 'Loop with 3 iterations and 2 action names: referenced actions executed 6 times' {
        InModuleScope LastWarAutoScreenshot {
            $click1 = [PSCustomObject]@{ type = 'LeftClick'; name = 'click1' }
            $click2 = [PSCustomObject]@{ type = 'LeftClick'; name = 'click2' }
            $lookup = @{ 'click1' = $click1; 'click2' = $click2 }
            $action = [PSCustomObject]@{
                type        = 'Loop'
                iterations  = 3
                actionNames = @('click1', 'click2')
            }

            $result = Invoke-MacroAction -Action $action -WindowHandle ([IntPtr]::new(1)) -ActionLookup $lookup

            Should -Invoke Invoke-MouseClick -Times 6
            $result.Success | Should -BeTrue
        }
    }

    It 'Loop: StopNestedMacro consumed — returns Success=$true SimilarityStop=$false; logs Info containing exiting loop' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    Screenshots = [PSCustomObject]@{
                        SimilarityCheck = [PSCustomObject]@{
                            Enabled              = $true
                            Threshold            = 0.98
                            SampleCount          = 1000
                            TolerancePerChannel  = 10
                            FullScan             = $false
                            Action               = 'StopNestedMacro'
                            ConsecutiveThreshold = 1
                        }
                    }
                }
            }
            # First sub-action call succeeds normally; second returns SimilarityStop=$true
            $callCount = 0
            Mock Invoke-CaptureScreenRegion {
                [PSCustomObject]@{ Success = $true; Skipped = $false; FilePath = 'TestDrive:\Screenshots\test.png'; Message = '' }
            }
            Mock Test-ScreenshotSimilarity {
                $script:_loopSimCallCount++
                if ($script:_loopSimCallCount -ge 2) {
                    [PSCustomObject]@{ Similar = $true; MatchPercent = 0.99; Skipped = $false; Message = '' }
                } else {
                    [PSCustomObject]@{ Similar = $false; MatchPercent = 0.5; Skipped = $false; Message = '' }
                }
            }
            $script:_loopSimCallCount = 0

            $shot = [PSCustomObject]@{
                type   = 'Screenshot'
                name   = 'shot1'
                region = [PSCustomObject]@{
                    relativeTopLeftX     = 0.0
                    relativeTopLeftY     = 0.0
                    relativeBottomRightX = 1.0
                    relativeBottomRightY = 1.0
                }
            }
            $lookup = @{ 'shot1' = $shot }
            $loopAction = [PSCustomObject]@{
                type        = 'Loop'
                name        = 'scroll-loop'
                iterations  = 3
                actionNames = @('shot1')
            }
            $ctx = @{ Index = 0; MacroName = 'test'; ActionName = ''; PreviousScreenshotPath = 'TestDrive:\prev.png'; ConsecutiveSimilarCount = 0 }

            $result = Invoke-MacroAction -Action $loopAction -WindowHandle ([IntPtr]::new(1)) -ActionLookup $lookup -ScreenshotContext $ctx

            $result.Success       | Should -BeTrue
            $result.SimilarityStop | Should -BeFalse
            Should -Invoke Write-LastWarLog -Times 1 -ParameterFilter { $Level -eq 'Info' -and $Message -like '*exiting loop*' }
        }
    }

    It 'Loop: StopMacro propagated — returns Success=$true SimilarityStop=$true' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    Screenshots = [PSCustomObject]@{
                        SimilarityCheck = [PSCustomObject]@{
                            Enabled              = $true
                            Threshold            = 0.98
                            SampleCount          = 1000
                            TolerancePerChannel  = 10
                            FullScan             = $false
                            Action               = 'StopMacro'
                            ConsecutiveThreshold = 1
                        }
                    }
                }
            }
            Mock Test-ScreenshotSimilarity {
                [PSCustomObject]@{ Similar = $true; MatchPercent = 0.99; Skipped = $false; Message = '' }
            }

            $shot = [PSCustomObject]@{
                type   = 'Screenshot'
                name   = 'shot1'
                region = [PSCustomObject]@{
                    relativeTopLeftX     = 0.0
                    relativeTopLeftY     = 0.0
                    relativeBottomRightX = 1.0
                    relativeBottomRightY = 1.0
                }
            }
            $lookup = @{ 'shot1' = $shot }
            $loopAction = [PSCustomObject]@{
                type        = 'Loop'
                name        = 'scroll-loop'
                iterations  = 3
                actionNames = @('shot1')
            }
            $ctx = @{ Index = 0; MacroName = 'test'; ActionName = ''; PreviousScreenshotPath = 'TestDrive:\prev.png'; ConsecutiveSimilarCount = 0 }

            $result = Invoke-MacroAction -Action $loopAction -WindowHandle ([IntPtr]::new(1)) -ActionLookup $lookup -ScreenshotContext $ctx

            $result.Success       | Should -BeTrue
            $result.SimilarityStop | Should -BeTrue
        }
    }

    It 'returns Success=$false immediately when EmergencyStopRequested is set; no mouse function called' {
        InModuleScope LastWarAutoScreenshot {
            $script:EmergencyStopRequested = $true
            $action = [PSCustomObject]@{ type = 'LeftClick' }

            $result = Invoke-MacroAction -Action $action -WindowHandle ([IntPtr]::new(1)) -ActionLookup @{}

            $result.Success | Should -BeFalse
            Should -Invoke Invoke-MouseClick -Times 0
            Should -Invoke Invoke-GetCursorPosition -Times 0
        }
    }

    It 'returns Success=$false with descriptive message for an unknown action type' {
        InModuleScope LastWarAutoScreenshot {
            $action = [PSCustomObject]@{ type = 'FlyToMoon' }

            $result = Invoke-MacroAction -Action $action -WindowHandle ([IntPtr]::new(1)) -ActionLookup @{}

            $result.Success | Should -BeFalse
            $result.Message | Should -BeLike '*FlyToMoon*'
        }
    }
}

# ============================================================
# Invoke-MacroSequence
# ============================================================

Describe 'Invoke-MacroSequence' -Tag 'Unit' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            $script:EmergencyStopRequested = $false
            Mock Test-MacroFile { [PSCustomObject]@{ Valid = $true; Messages = @() } }
            Mock Invoke-MacroAction { [PSCustomObject]@{ Success = $true; Message = ''; Skipped = $false; SimilarityStop = $false } }
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    EmergencyStop = [PSCustomObject]@{ AutoStart = $false }
                }
            }
            Mock Start-EmergencyStopMonitor {}
            Mock Stop-EmergencyStopMonitor {}
            Mock Write-LastWarLog {}
        }
    }

    AfterEach {
        InModuleScope LastWarAutoScreenshot {
            $script:EmergencyStopRequested = $false
        }
    }

    It 'valid 3-action macro: all 3 actions executed; returns CompletedActions=3, TotalActions=3, Success=$true' {
        InModuleScope LastWarAutoScreenshot {
            $testConsole = [Spectre.Console.Testing.TestConsole]::new()
            $macro = [PSCustomObject]@{
                metadata = [PSCustomObject]@{ name = 'test-macro' }
                sequence = @(
                    [PSCustomObject]@{ type = 'LeftClick' },
                    [PSCustomObject]@{ type = 'LeftClick' },
                    [PSCustomObject]@{ type = 'LeftClick' }
                )
            }

            $result = Invoke-MacroSequence -MacroData $macro -WindowHandle ([IntPtr]::new(1)) -Console $testConsole

            Should -Invoke Invoke-MacroAction -Times 3
            $result.Success          | Should -BeTrue
            $result.CompletedActions | Should -Be 3
            $result.TotalActions     | Should -Be 3
        }
    }

    It 'EmergencyStop.AutoStart=$true: Start-EmergencyStopMonitor called before execution; Stop-EmergencyStopMonitor called in finally' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    EmergencyStop = [PSCustomObject]@{ AutoStart = $true }
                }
            }
            $testConsole = [Spectre.Console.Testing.TestConsole]::new()
            $macro = [PSCustomObject]@{
                metadata = [PSCustomObject]@{ name = 'test-macro' }
                sequence = @([PSCustomObject]@{ type = 'LeftClick' })
            }

            Invoke-MacroSequence -MacroData $macro -WindowHandle ([IntPtr]::new(1)) -Console $testConsole | Out-Null

            Should -Invoke Start-EmergencyStopMonitor -Times 1
            Should -Invoke Stop-EmergencyStopMonitor -Times 1
        }
    }

    It 'emergency stop triggered mid-sequence: execution halts; CompletedActions reflects pre-stop count; Success=$false' {
        InModuleScope LastWarAutoScreenshot {
            # The Delay action triggers emergency stop; LeftClick actions succeed normally.
            # Sequence: LeftClick (completes, count=1), Delay (sets flag, break before count), LeftClick (never reached).
            Mock Invoke-MacroAction -ParameterFilter { $Action.type -eq 'Delay' } {
                $script:EmergencyStopRequested = $true
                [PSCustomObject]@{ Success = $true; Message = ''; Skipped = $false; SimilarityStop = $false }
            }
            $testConsole = [Spectre.Console.Testing.TestConsole]::new()
            $macro = [PSCustomObject]@{
                metadata = [PSCustomObject]@{ name = 'test-macro' }
                sequence = @(
                    [PSCustomObject]@{ type = 'LeftClick' },
                    [PSCustomObject]@{ type = 'Delay'; seconds = 1 },
                    [PSCustomObject]@{ type = 'LeftClick' }
                )
            }

            $result = Invoke-MacroSequence -MacroData $macro -WindowHandle ([IntPtr]::new(1)) -Console $testConsole

            $result.Success          | Should -BeFalse
            $result.CompletedActions | Should -Be 1
        }
    }

    It 'action failure mid-sequence: halts at failing action; CompletedActions reflects completed count' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-MacroAction -ParameterFilter { $Action.type -eq 'Delay' } {
                [PSCustomObject]@{ Success = $false; Message = 'action failed'; Skipped = $false; SimilarityStop = $false }
            }
            $testConsole = [Spectre.Console.Testing.TestConsole]::new()
            $macro = [PSCustomObject]@{
                metadata = [PSCustomObject]@{ name = 'test-macro' }
                sequence = @(
                    [PSCustomObject]@{ type = 'LeftClick' },
                    [PSCustomObject]@{ type = 'Delay'; seconds = 1 },
                    [PSCustomObject]@{ type = 'LeftClick' }
                )
            }

            $result = Invoke-MacroSequence -MacroData $macro -WindowHandle ([IntPtr]::new(1)) -Console $testConsole

            $result.Success          | Should -BeFalse
            $result.CompletedActions | Should -Be 1
        }
    }

    It 'Screenshot action skipped: sequence continues; CompletedActions does not count skipped action' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-MacroAction -ParameterFilter { $Action.type -eq 'Screenshot' } {
                [PSCustomObject]@{ Success = $true; Message = 'StoragePath not configured'; Skipped = $true; SimilarityStop = $false }
            }
            $testConsole = [Spectre.Console.Testing.TestConsole]::new()
            $macro = [PSCustomObject]@{
                metadata = [PSCustomObject]@{ name = 'test-macro' }
                sequence = @(
                    [PSCustomObject]@{ type = 'LeftClick' },
                    [PSCustomObject]@{ type = 'Screenshot' },
                    [PSCustomObject]@{ type = 'LeftClick' }
                )
            }

            $result = Invoke-MacroSequence -MacroData $macro -WindowHandle ([IntPtr]::new(1)) -Console $testConsole

            $result.Success          | Should -BeTrue
            $result.CompletedActions | Should -Be 2
            $result.TotalActions     | Should -Be 3
        }
    }

    It 'invalid macro: returns Success=$false and CompletedActions=0; validation failure displayed' {
        InModuleScope LastWarAutoScreenshot {
            Mock Test-MacroFile { [PSCustomObject]@{ Valid = $false; Messages = @('version missing') } }
            $testConsole = [Spectre.Console.Testing.TestConsole]::new()
            $macro = [PSCustomObject]@{
                metadata = [PSCustomObject]@{ name = 'bad-macro' }
                sequence = @()
            }

            $result = Invoke-MacroSequence -MacroData $macro -WindowHandle ([IntPtr]::new(1)) -Console $testConsole

            $result.Success          | Should -BeFalse
            $result.CompletedActions | Should -Be 0
            $testConsole.Output      | Should -BeLike '*validation failed*'
        }
    }

    It 'ScreenshotContext initialised with MacroName, Index=0, PreviousScreenshotPath=$null and passed to Invoke-MacroAction' {
        InModuleScope LastWarAutoScreenshot {
            $script:capturedContext = $null
            Mock Invoke-MacroAction {
                $script:capturedContext = $ScreenshotContext
                [PSCustomObject]@{ Success = $true; Message = ''; Skipped = $false; SimilarityStop = $false }
            }
            $testConsole = [Spectre.Console.Testing.TestConsole]::new()
            $macro = [PSCustomObject]@{
                metadata = [PSCustomObject]@{ name = 'my-macro' }
                sequence = @([PSCustomObject]@{ type = 'LeftClick' })
            }

            Invoke-MacroSequence -MacroData $macro -WindowHandle ([IntPtr]::new(1)) -Console $testConsole | Out-Null

            $script:capturedContext                    | Should -Not -BeNullOrEmpty
            $script:capturedContext.MacroName          | Should -BeExactly 'my-macro'
            $script:capturedContext.Index              | Should -Be 0
            $script:capturedContext.PreviousScreenshotPath | Should -BeNullOrEmpty
        }
    }

    It 'SimilarityStop=$true on step 2 of 5: exits after step 2; CompletedActions=2; Success=$true; SimilarityStop=$true; output contains Scroll end detected' {
        InModuleScope LastWarAutoScreenshot {
            $script:callNumber = 0
            Mock Invoke-MacroAction {
                $script:callNumber++
                if ($script:callNumber -eq 2) {
                    [PSCustomObject]@{ Success = $true; Message = 'Similarity threshold reached'; Skipped = $false; SimilarityStop = $true }
                } else {
                    [PSCustomObject]@{ Success = $true; Message = ''; Skipped = $false; SimilarityStop = $false }
                }
            }
            $testConsole = [Spectre.Console.Testing.TestConsole]::new()
            $macro = [PSCustomObject]@{
                metadata = [PSCustomObject]@{ name = 'test-macro' }
                sequence = @(
                    [PSCustomObject]@{ type = 'LeftClick' },
                    [PSCustomObject]@{ type = 'LeftClick' },
                    [PSCustomObject]@{ type = 'LeftClick' },
                    [PSCustomObject]@{ type = 'LeftClick' },
                    [PSCustomObject]@{ type = 'LeftClick' }
                )
            }

            $result = Invoke-MacroSequence -MacroData $macro -WindowHandle ([IntPtr]::new(1)) -Console $testConsole

            $result.Success          | Should -BeTrue
            $result.SimilarityStop   | Should -BeTrue
            $result.CompletedActions | Should -Be 2
            $testConsole.Output      | Should -Match 'Scroll end detected'
            $testConsole.Output      | Should -Match 'threshold\s+reached'
        }
    }

    It 'Normal completion: all actions return SimilarityStop=$false; result SimilarityStop=$false and Success=$true' {
        InModuleScope LastWarAutoScreenshot {
            $testConsole = [Spectre.Console.Testing.TestConsole]::new()
            $macro = [PSCustomObject]@{
                metadata = [PSCustomObject]@{ name = 'test-macro' }
                sequence = @(
                    [PSCustomObject]@{ type = 'LeftClick' },
                    [PSCustomObject]@{ type = 'LeftClick' }
                )
            }

            $result = Invoke-MacroSequence -MacroData $macro -WindowHandle ([IntPtr]::new(1)) -Console $testConsole

            $result.SimilarityStop | Should -BeFalse
            $result.Success        | Should -BeTrue
        }
    }

    It 'Emergency stop mid-sequence: SimilarityStop=$false and Success=$false' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-MacroAction -ParameterFilter { $Action.type -eq 'Delay' } {
                $script:EmergencyStopRequested = $true
                [PSCustomObject]@{ Success = $true; Message = ''; Skipped = $false; SimilarityStop = $false }
            }
            $testConsole = [Spectre.Console.Testing.TestConsole]::new()
            $macro = [PSCustomObject]@{
                metadata = [PSCustomObject]@{ name = 'test-macro' }
                sequence = @(
                    [PSCustomObject]@{ type = 'LeftClick' },
                    [PSCustomObject]@{ type = 'Delay'; seconds = 1 }
                )
            }

            $result = Invoke-MacroSequence -MacroData $macro -WindowHandle ([IntPtr]::new(1)) -Console $testConsole

            $result.SimilarityStop | Should -BeFalse
            $result.Success        | Should -BeFalse
        }
    }

    It 'progress output contains Executing step markup text for each step' {
        InModuleScope LastWarAutoScreenshot {
            $testConsole = [Spectre.Console.Testing.TestConsole]::new()
            $macro = [PSCustomObject]@{
                metadata = [PSCustomObject]@{ name = 'test-macro' }
                sequence = @(
                    [PSCustomObject]@{ type = 'LeftClick' },
                    [PSCustomObject]@{ type = 'Delay'; seconds = 1 }
                )
            }

            Invoke-MacroSequence -MacroData $macro -WindowHandle ([IntPtr]::new(1)) -Console $testConsole | Out-Null

            $testConsole.Output | Should -BeLike '*Executing step 1*'
            $testConsole.Output | Should -BeLike '*Executing step 2*'
        }
    }
}
