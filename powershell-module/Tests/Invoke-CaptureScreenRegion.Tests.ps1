BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
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
}
