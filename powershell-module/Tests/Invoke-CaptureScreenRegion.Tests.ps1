BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
    # Create the screenshots directory in TestDrive for all tests
    New-Item -ItemType Directory -Path 'TestDrive:\Screenshots' -Force | Out-Null
}

Describe 'Invoke-CaptureScreenRegion' -Tag 'Unit' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    Screenshots = [PSCustomObject]@{
                        StoragePath                    = 'TestDrive:\Pester_Tests\Screenshots'
                        MaxStorageGB                   = 2.0
                        FileFormat                     = 'PNG'
                        FilenamePattern                = '{MacroName}_{ActionName}_{Timestamp}_{Index}'
                        StorageWarningThresholdPercent = 90
                        MaskColour                     = '0,0,0'
                    }
                }
            }
            Mock Get-StorageInfo {
                [PSCustomObject]@{
                    IsConfigured = $true
                    UsedPercent  = 50.0
                    UsedGB       = 1.0
                    MaxGB        = 2.0
                }
            }
            Mock Resolve-ScreenshotFilename { 'test_screenshot_20260101_120000_0001.png' }
            Mock Invoke-CaptureWindowRegion { $true }
            Mock Test-Path { $true }
            Mock New-Item {}
        }
    }

    It 'returns Success=$false, Skipped=$true, FilePath=$null when StoragePath is empty' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    Screenshots = [PSCustomObject]@{
                        StoragePath                    = ''
                        MaxStorageGB                   = 2.0
                        FileFormat                     = 'PNG'
                        FilenamePattern                = '{MacroName}_{ActionName}_{Timestamp}_{Index}'
                        StorageWarningThresholdPercent = 90
                    }
                }
            }

            $ctx    = @{ Index = 0; MacroName = 'Test'; ActionName = 'shot'; PreviousScreenshotPath = $null }
            $result = Invoke-CaptureScreenRegion `
                -WindowHandle               ([IntPtr]::new(1)) `
                -RegionTopLeftRelativeX     0.0 `
                -RegionTopLeftRelativeY     0.0 `
                -RegionBottomRightRelativeX 1.0 `
                -RegionBottomRightRelativeY 1.0 `
                -ScreenshotContext          $ctx

            $result.Success | Should -BeFalse
            $result.Skipped | Should -BeTrue
            $result.FilePath | Should -BeNullOrEmpty
            Should -Invoke Write-LastWarLog -Times 1 -ParameterFilter { $Level -eq 'Warning' }
        }
    }

    It 'returns Success=$false, Skipped=$false when storage limit is reached (100%)' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-StorageInfo {
                [PSCustomObject]@{
                    IsConfigured = $true
                    UsedPercent  = 100.0
                    UsedGB       = 2.0
                    MaxGB        = 2.0
                }
            }

            $ctx    = @{ Index = 0; MacroName = 'Test'; ActionName = 'shot'; PreviousScreenshotPath = $null }
            $result = Invoke-CaptureScreenRegion `
                -WindowHandle               ([IntPtr]::new(1)) `
                -RegionTopLeftRelativeX     0.0 `
                -RegionTopLeftRelativeY     0.0 `
                -RegionBottomRightRelativeX 1.0 `
                -RegionBottomRightRelativeY 1.0 `
                -ScreenshotContext          $ctx

            $result.Success | Should -BeFalse
            $result.Skipped | Should -BeFalse
            Should -Invoke Write-LastWarLog -Times 1 -ParameterFilter { $Level -eq 'Error' }
        }
    }

    It 'logs a warning but proceeds when storage is at 92% (above threshold)' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-StorageInfo {
                [PSCustomObject]@{
                    IsConfigured = $true
                    UsedPercent  = 92.0
                    UsedGB       = 1.84
                    MaxGB        = 2.0
                }
            }

            $ctx    = @{ Index = 0; MacroName = 'Test'; ActionName = 'shot'; PreviousScreenshotPath = $null }
            $result = Invoke-CaptureScreenRegion `
                -WindowHandle               ([IntPtr]::new(1)) `
                -RegionTopLeftRelativeX     0.0 `
                -RegionTopLeftRelativeY     0.0 `
                -RegionBottomRightRelativeX 1.0 `
                -RegionBottomRightRelativeY 1.0 `
                -ScreenshotContext          $ctx

            Should -Invoke Write-LastWarLog -Times 1 -ParameterFilter { $Level -eq 'Warning' }
            $result.Success | Should -BeTrue
        }
    }

    It 'calls New-Item with -ItemType Directory and logs Info when storage path does not exist' {
        InModuleScope LastWarAutoScreenshot {
            Mock Test-Path { $false }

            $ctx    = @{ Index = 0; MacroName = 'Test'; ActionName = 'shot'; PreviousScreenshotPath = $null }
            $result = Invoke-CaptureScreenRegion `
                -WindowHandle               ([IntPtr]::new(1)) `
                -RegionTopLeftRelativeX     0.0 `
                -RegionTopLeftRelativeY     0.0 `
                -RegionBottomRightRelativeX 1.0 `
                -RegionBottomRightRelativeY 1.0 `
                -ScreenshotContext          $ctx

            Should -Invoke New-Item -Times 1 -ParameterFilter { $ItemType -eq 'Directory' }
            Should -Invoke Write-LastWarLog -Times 1 -ParameterFilter { $Level -eq 'Info' -and $Message -like '*Created screenshot storage directory*' }
        }
    }

    It 'returns Success=$false, Skipped=$false when region dimensions are invalid (right <= left)' {
        InModuleScope LastWarAutoScreenshot {
            $ctx    = @{ Index = 0; MacroName = 'Test'; ActionName = 'shot'; PreviousScreenshotPath = $null }
            $result = Invoke-CaptureScreenRegion `
                -WindowHandle               ([IntPtr]::new(1)) `
                -RegionTopLeftRelativeX     0.8 `
                -RegionTopLeftRelativeY     0.0 `
                -RegionBottomRightRelativeX 0.2 `
                -RegionBottomRightRelativeY 1.0 `
                -ScreenshotContext          $ctx

            $result.Success | Should -BeFalse
            $result.Skipped | Should -BeFalse
            Should -Invoke Write-LastWarLog -Times 1 -ParameterFilter { $Level -eq 'Error' }
        }
    }

    It 'returns Success=$true, increments Index, and updates PreviousScreenshotPath on success' {
        InModuleScope LastWarAutoScreenshot {
            $ctx    = @{ Index = 0; MacroName = 'Test'; ActionName = 'shot'; PreviousScreenshotPath = $null }
            $result = Invoke-CaptureScreenRegion `
                -WindowHandle               ([IntPtr]::new(1)) `
                -RegionTopLeftRelativeX     0.0 `
                -RegionTopLeftRelativeY     0.0 `
                -RegionBottomRightRelativeX 1.0 `
                -RegionBottomRightRelativeY 1.0 `
                -ScreenshotContext          $ctx

            $result.Success | Should -BeTrue
            $result.FilePath | Should -Not -BeNullOrEmpty
            $result.FilePath | Should -BeLike '*.png'
            $ctx.Index | Should -Be 1
            $ctx.PreviousScreenshotPath | Should -BeExactly $result.FilePath
        }
    }

    It 'returns Success=$false, Skipped=$false when Invoke-CaptureWindowRegion returns $false' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-CaptureWindowRegion { $false }

            $ctx    = @{ Index = 0; MacroName = 'Test'; ActionName = 'shot'; PreviousScreenshotPath = $null }
            $result = Invoke-CaptureScreenRegion `
                -WindowHandle               ([IntPtr]::new(1)) `
                -RegionTopLeftRelativeX     0.0 `
                -RegionTopLeftRelativeY     0.0 `
                -RegionBottomRightRelativeX 1.0 `
                -RegionBottomRightRelativeY 1.0 `
                -ScreenshotContext          $ctx

            $result.Success | Should -BeFalse
            $result.Skipped | Should -BeFalse
            Should -Invoke Write-LastWarLog -Times 1 -ParameterFilter { $Level -eq 'Error' }
        }
    }

    It 'increments ScreenshotContext.Index to 2 after two consecutive calls' {
        InModuleScope LastWarAutoScreenshot {
            $ctx = @{ Index = 0; MacroName = 'Test'; ActionName = 'shot'; PreviousScreenshotPath = $null }

            Invoke-CaptureScreenRegion `
                -WindowHandle               ([IntPtr]::new(1)) `
                -RegionTopLeftRelativeX     0.0 `
                -RegionTopLeftRelativeY     0.0 `
                -RegionBottomRightRelativeX 1.0 `
                -RegionBottomRightRelativeY 1.0 `
                -ScreenshotContext          $ctx | Out-Null

            Invoke-CaptureScreenRegion `
                -WindowHandle               ([IntPtr]::new(1)) `
                -RegionTopLeftRelativeX     0.0 `
                -RegionTopLeftRelativeY     0.0 `
                -RegionBottomRightRelativeX 1.0 `
                -RegionBottomRightRelativeY 1.0 `
                -ScreenshotContext          $ctx | Out-Null

            $ctx.Index | Should -Be 2
        }
    }

    Context 'Mask rectangle computation' {
        # Window bounds: Width=1000, Height=2000
        # Screenshot region: (0.1, 0.1) → (0.9, 0.9)
        # bmpWidth  = int(0.8 * 1000) = 800
        # bmpHeight = int(0.8 * 2000) = 1600
        BeforeEach {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-WindowBounds {
                    [PSCustomObject]@{ Left = 0; Top = 0; Right = 1000; Bottom = 2000; Width = 1000; Height = 2000 }
                }
                Mock Resolve-MaskColour { [System.Drawing.Color]::Red }
            }
        }

        It 'passes one rectangle at correct pixel coords when mask fully inside screenshot region' {
            # mask (0.2, 0.2) → (0.5, 0.5)
            # overlapLeft=0.2, overlapTop=0.2, overlapRight=0.5, overlapBottom=0.5
            # pixelX = int((0.2-0.1)/0.8 * 800) = 100
            # pixelY = int((0.2-0.1)/0.8 * 1600) = 200
            # pixelW = int((0.5-0.2)/0.8 * 800) = 300
            # pixelH = int((0.5-0.2)/0.8 * 1600) = 600
            InModuleScope LastWarAutoScreenshot {
                $mask = [PSCustomObject]@{
                    topLeft     = [PSCustomObject]@{ relativeX = 0.2; relativeY = 0.2 }
                    bottomRight = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.5 }
                }
                $ctx = @{ Index = 0; MacroName = 'Test'; ActionName = 'shot'; PreviousScreenshotPath = $null }
                Invoke-CaptureScreenRegion `
                    -WindowHandle               ([IntPtr]::new(1)) `
                    -RegionTopLeftRelativeX     0.1 `
                    -RegionTopLeftRelativeY     0.1 `
                    -RegionBottomRightRelativeX 0.9 `
                    -RegionBottomRightRelativeY 0.9 `
                    -MaskRegions                @($mask) `
                    -ScreenshotContext          $ctx | Out-Null

                Should -Invoke Invoke-CaptureWindowRegion -Times 1 -ParameterFilter {
                    $MaskPixelRects.Length -eq 1 -and
                    $MaskPixelRects[0].X      -eq 100 -and
                    $MaskPixelRects[0].Y      -eq 200 -and
                    $MaskPixelRects[0].Width  -eq 300 -and
                    $MaskPixelRects[0].Height -eq 600
                }
            }
        }

        It 'passes rectangle covering full bitmap when mask region equals screenshot region' {
            # mask same as ss region → X=0, Y=0, W=800, H=1600
            InModuleScope LastWarAutoScreenshot {
                $mask = [PSCustomObject]@{
                    topLeft     = [PSCustomObject]@{ relativeX = 0.1; relativeY = 0.1 }
                    bottomRight = [PSCustomObject]@{ relativeX = 0.9; relativeY = 0.9 }
                }
                $ctx = @{ Index = 0; MacroName = 'Test'; ActionName = 'shot'; PreviousScreenshotPath = $null }
                Invoke-CaptureScreenRegion `
                    -WindowHandle               ([IntPtr]::new(1)) `
                    -RegionTopLeftRelativeX     0.1 `
                    -RegionTopLeftRelativeY     0.1 `
                    -RegionBottomRightRelativeX 0.9 `
                    -RegionBottomRightRelativeY 0.9 `
                    -MaskRegions                @($mask) `
                    -ScreenshotContext          $ctx | Out-Null

                Should -Invoke Invoke-CaptureWindowRegion -Times 1 -ParameterFilter {
                    $MaskPixelRects.Length -eq 1 -and
                    $MaskPixelRects[0].X      -eq 0 -and
                    $MaskPixelRects[0].Y      -eq 0 -and
                    $MaskPixelRects[0].Width  -eq 800 -and
                    $MaskPixelRects[0].Height -eq 1600
                }
            }
        }

        It 'clips mask region that extends outside screenshot boundary' {
            # mask (0.5, 0.5) → (1.5, 1.5) — extends beyond ss region (0.1→0.9)
            # overlapLeft=0.5, overlapTop=0.5, overlapRight=0.9, overlapBottom=0.9
            # pixelX = int((0.5-0.1)/0.8 * 800) = 400
            # pixelY = int((0.5-0.1)/0.8 * 1600) = 800
            # pixelW = int((0.9-0.5)/0.8 * 800) = 400
            # pixelH = int((0.9-0.5)/0.8 * 1600) = 800
            InModuleScope LastWarAutoScreenshot {
                $mask = [PSCustomObject]@{
                    topLeft     = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.5 }
                    bottomRight = [PSCustomObject]@{ relativeX = 1.5; relativeY = 1.5 }
                }
                $ctx = @{ Index = 0; MacroName = 'Test'; ActionName = 'shot'; PreviousScreenshotPath = $null }
                Invoke-CaptureScreenRegion `
                    -WindowHandle               ([IntPtr]::new(1)) `
                    -RegionTopLeftRelativeX     0.1 `
                    -RegionTopLeftRelativeY     0.1 `
                    -RegionBottomRightRelativeX 0.9 `
                    -RegionBottomRightRelativeY 0.9 `
                    -MaskRegions                @($mask) `
                    -ScreenshotContext          $ctx | Out-Null

                Should -Invoke Invoke-CaptureWindowRegion -Times 1 -ParameterFilter {
                    $MaskPixelRects.Length -eq 1 -and
                    $MaskPixelRects[0].X      -eq 400 -and
                    $MaskPixelRects[0].Y      -eq 800 -and
                    $MaskPixelRects[0].Width  -eq 400 -and
                    $MaskPixelRects[0].Height -eq 800
                }
            }
        }

        It 'passes empty rectangle array when mask region is entirely outside screenshot region' {
            InModuleScope LastWarAutoScreenshot {
                $mask = [PSCustomObject]@{
                    topLeft     = [PSCustomObject]@{ relativeX = 0.95; relativeY = 0.95 }
                    bottomRight = [PSCustomObject]@{ relativeX = 1.0;  relativeY = 1.0 }
                }
                $ctx = @{ Index = 0; MacroName = 'Test'; ActionName = 'shot'; PreviousScreenshotPath = $null }
                Invoke-CaptureScreenRegion `
                    -WindowHandle               ([IntPtr]::new(1)) `
                    -RegionTopLeftRelativeX     0.1 `
                    -RegionTopLeftRelativeY     0.1 `
                    -RegionBottomRightRelativeX 0.9 `
                    -RegionBottomRightRelativeY 0.9 `
                    -MaskRegions                @($mask) `
                    -ScreenshotContext          $ctx | Out-Null

                Should -Invoke Invoke-CaptureWindowRegion -Times 1 -ParameterFilter {
                    $MaskPixelRects.Length -eq 0
                }
            }
        }

        It 'passes two rectangles when both mask regions are valid and overlapping' {
            InModuleScope LastWarAutoScreenshot {
                $mask1 = [PSCustomObject]@{
                    topLeft     = [PSCustomObject]@{ relativeX = 0.2; relativeY = 0.2 }
                    bottomRight = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.5 }
                }
                $mask2 = [PSCustomObject]@{
                    topLeft     = [PSCustomObject]@{ relativeX = 0.6; relativeY = 0.6 }
                    bottomRight = [PSCustomObject]@{ relativeX = 0.8; relativeY = 0.8 }
                }
                $ctx = @{ Index = 0; MacroName = 'Test'; ActionName = 'shot'; PreviousScreenshotPath = $null }
                Invoke-CaptureScreenRegion `
                    -WindowHandle               ([IntPtr]::new(1)) `
                    -RegionTopLeftRelativeX     0.1 `
                    -RegionTopLeftRelativeY     0.1 `
                    -RegionBottomRightRelativeX 0.9 `
                    -RegionBottomRightRelativeY 0.9 `
                    -MaskRegions                @($mask1, $mask2) `
                    -ScreenshotContext          $ctx | Out-Null

                Should -Invoke Invoke-CaptureWindowRegion -Times 1 -ParameterFilter {
                    $MaskPixelRects.Length -eq 2
                }
            }
        }

        It 'passes empty rectangle array when MaskRegions is <Description>' -TestCases @(
            @{ Description = 'absent (null)';    MaskRegions = $null }
            @{ Description = 'an empty array';   MaskRegions = @() }
        ) {
            param($MaskRegions)
            InModuleScope LastWarAutoScreenshot -Parameters @{ MaskRegions = $MaskRegions } {
                param($MaskRegions)
                $ctx = @{ Index = 0; MacroName = 'Test'; ActionName = 'shot'; PreviousScreenshotPath = $null }
                $splat = @{
                    WindowHandle               = [IntPtr]::new(1)
                    RegionTopLeftRelativeX     = 0.0
                    RegionTopLeftRelativeY     = 0.0
                    RegionBottomRightRelativeX = 1.0
                    RegionBottomRightRelativeY = 1.0
                    ScreenshotContext          = $ctx
                }
                if ($null -ne $MaskRegions) { $splat['MaskRegions'] = $MaskRegions }
                Invoke-CaptureScreenRegion @splat | Out-Null

                Should -Invoke Invoke-CaptureWindowRegion -Times 1 -ParameterFilter {
                    $MaskPixelRects.Length -eq 0
                }
            }
        }
    }

    Context 'Mask colour resolution' {
        BeforeEach {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-WindowBounds {
                    [PSCustomObject]@{ Left = 0; Top = 0; Right = 1000; Bottom = 2000; Width = 1000; Height = 2000 }
                }
            }
        }

        It 'passes the colour returned by Resolve-MaskColour to Invoke-CaptureWindowRegion' {
            InModuleScope LastWarAutoScreenshot {
                Mock Resolve-MaskColour { [System.Drawing.Color]::FromArgb(255, 0, 0) }
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath                    = 'TestDrive:\Pester_Tests\Screenshots'
                            MaxStorageGB                   = 2.0
                            FileFormat                     = 'PNG'
                            FilenamePattern                = '{MacroName}_{ActionName}_{Timestamp}_{Index}'
                            StorageWarningThresholdPercent = 90
                            MaskColour                     = '255,0,0'
                        }
                    }
                }

                $mask = [PSCustomObject]@{
                    topLeft     = [PSCustomObject]@{ relativeX = 0.2; relativeY = 0.2 }
                    bottomRight = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.5 }
                }
                $ctx = @{ Index = 0; MacroName = 'Test'; ActionName = 'shot'; PreviousScreenshotPath = $null }
                Invoke-CaptureScreenRegion `
                    -WindowHandle               ([IntPtr]::new(1)) `
                    -RegionTopLeftRelativeX     0.1 `
                    -RegionTopLeftRelativeY     0.1 `
                    -RegionBottomRightRelativeX 0.9 `
                    -RegionBottomRightRelativeY 0.9 `
                    -MaskRegions                @($mask) `
                    -ScreenshotContext          $ctx | Out-Null

                Should -Invoke Resolve-MaskColour -Times 1 -ParameterFilter { $ColourString -eq '255,0,0' }
                Should -Invoke Invoke-CaptureWindowRegion -Times 1 -ParameterFilter {
                    $MaskColour.R -eq 255 -and $MaskColour.G -eq 0 -and $MaskColour.B -eq 0
                }
            }
        }

        It 'falls back to black and emits a warning when Resolve-MaskColour returns null' {
            InModuleScope LastWarAutoScreenshot {
                Mock Resolve-MaskColour { $null }
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath                    = 'TestDrive:\Pester_Tests\Screenshots'
                            MaxStorageGB                   = 2.0
                            FileFormat                     = 'PNG'
                            FilenamePattern                = '{MacroName}_{ActionName}_{Timestamp}_{Index}'
                            StorageWarningThresholdPercent = 90
                            MaskColour                     = '0,0,0'
                        }
                    }
                }

                $mask = [PSCustomObject]@{
                    topLeft     = [PSCustomObject]@{ relativeX = 0.2; relativeY = 0.2 }
                    bottomRight = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.5 }
                }
                Mock Write-Warning {}

                $ctx = @{ Index = 0; MacroName = 'Test'; ActionName = 'shot'; PreviousScreenshotPath = $null }
                Invoke-CaptureScreenRegion `
                    -WindowHandle               ([IntPtr]::new(1)) `
                    -RegionTopLeftRelativeX     0.1 `
                    -RegionTopLeftRelativeY     0.1 `
                    -RegionBottomRightRelativeX 0.9 `
                    -RegionBottomRightRelativeY 0.9 `
                    -MaskRegions                @($mask) `
                    -ScreenshotContext          $ctx | Out-Null

                Should -Invoke Write-Warning -Times 1
                Should -Invoke Invoke-CaptureWindowRegion -Times 1 -ParameterFilter {
                    $MaskColour.R -eq 0 -and $MaskColour.G -eq 0 -and $MaskColour.B -eq 0
                }
            }
        }
    }
}
