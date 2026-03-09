BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'Test-ScreenshotSimilarity' -Tag 'Unit' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    Screenshots = [PSCustomObject]@{
                        SimilarityCheck = [PSCustomObject]@{
                            Threshold           = 0.98
                            SampleCount         = 1000
                            TolerancePerChannel = 10
                            FullScan            = $false
                        }
                    }
                }
            }
            Mock Invoke-CompareImages { [double]0.99 }
            Mock Test-Path { $true }
        }
    }

    It 'returns Similar=$true, MatchPercent=0.99, Skipped=$false when images match above threshold' {
        InModuleScope LastWarAutoScreenshot {
            $result = Test-ScreenshotSimilarity `
                -ReferencePath 'TestDrive:\ref.png' `
                -ComparePath   'TestDrive:\cmp.png'

            $result.Similar      | Should -BeTrue
            $result.MatchPercent | Should -Be 0.99
            $result.Skipped      | Should -BeFalse
        }
    }

    It 'returns Similar=$false, MatchPercent=0.40, Skipped=$false when images do not match' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-CompareImages { [double]0.40 }

            $result = Test-ScreenshotSimilarity `
                -ReferencePath 'TestDrive:\ref.png' `
                -ComparePath   'TestDrive:\cmp.png'

            $result.Similar      | Should -BeFalse
            $result.MatchPercent | Should -Be 0.40
            $result.Skipped      | Should -BeFalse
        }
    }

    It 'returns Similar=$true when MatchPercent equals threshold exactly (0.98 >= 0.98)' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-CompareImages { [double]0.98 }

            $result = Test-ScreenshotSimilarity `
                -ReferencePath 'TestDrive:\ref.png' `
                -ComparePath   'TestDrive:\cmp.png'

            $result.Similar | Should -BeTrue
        }
    }

    It 'returns Skipped=$true, Similar=$false and logs Warning when ReferencePath is empty; Invoke-CompareImages NOT called' {
        InModuleScope LastWarAutoScreenshot {
            $result = Test-ScreenshotSimilarity `
                -ReferencePath '' `
                -ComparePath   'TestDrive:\cmp.png'

            $result.Skipped | Should -BeTrue
            $result.Similar | Should -BeFalse
            Should -Invoke Write-LastWarLog -Times 1 -ParameterFilter { $Level -eq 'Warning' }
            Should -Invoke Invoke-CompareImages -Times 0
        }
    }

    It 'returns Skipped=$true, Similar=$false when ComparePath does not exist; Invoke-CompareImages NOT called' {
        InModuleScope LastWarAutoScreenshot {
            Mock Test-Path -ParameterFilter { $Path -like '*cmp*' } { $false }

            $result = Test-ScreenshotSimilarity `
                -ReferencePath 'TestDrive:\ref.png' `
                -ComparePath   'TestDrive:\cmp.png'

            $result.Skipped | Should -BeTrue
            $result.Similar | Should -BeFalse
            Should -Invoke Invoke-CompareImages -Times 0
        }
    }

    It 'returns Similar=$false, MatchPercent=-1.0, Skipped=$false and logs Error when Invoke-CompareImages returns -1.0' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-CompareImages { [double]-1.0 }

            $result = Test-ScreenshotSimilarity `
                -ReferencePath 'TestDrive:\ref.png' `
                -ComparePath   'TestDrive:\cmp.png'

            $result.Similar      | Should -BeFalse
            $result.MatchPercent | Should -Be (-1.0)
            $result.Skipped      | Should -BeFalse
            Should -Invoke Write-LastWarLog -Times 1 -ParameterFilter { $Level -eq 'Error' }
        }
    }

    It 'passes SampleCount=500, TolerancePerChannel=5, FullScan=$false from config to Invoke-CompareImages' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    Screenshots = [PSCustomObject]@{
                        SimilarityCheck = [PSCustomObject]@{
                            Threshold           = 0.98
                            SampleCount         = 500
                            TolerancePerChannel = 5
                            FullScan            = $false
                        }
                    }
                }
            }

            Test-ScreenshotSimilarity `
                -ReferencePath 'TestDrive:\ref.png' `
                -ComparePath   'TestDrive:\cmp.png' | Out-Null

            Should -Invoke Invoke-CompareImages -Times 1 -ParameterFilter {
                $SampleCount -eq 500 -and $TolerancePerChannel -eq 5 -and $FullScan -eq $false
            }
        }
    }
}
