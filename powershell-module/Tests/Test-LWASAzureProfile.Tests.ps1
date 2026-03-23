BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Test-LWASAzureProfile' -Tag 'Unit' {

    # cloudProvider = 'azure' → $true
    It 'Profile with cloudProvider = ''azure'' → $true' {
        InModuleScope LastWarAutoScreenshot {
            $profile = [PSCustomObject]@{ cloudProvider = 'azure' }
            Test-LWASAzureProfile -Profile $profile | Should -BeTrue
        }
    }

    # cloudProvider = 'Azure' (mixed case) → $true (case-insensitive)
    It 'Profile with cloudProvider = ''Azure'' (mixed case) → $true (case-insensitive)' {
        InModuleScope LastWarAutoScreenshot {
            $profile = [PSCustomObject]@{ cloudProvider = 'Azure' }
            Test-LWASAzureProfile -Profile $profile | Should -BeTrue
        }
    }

    # cloudProvider = 'gcp' → $false
    It 'Profile with cloudProvider = ''gcp'' → $false' {
        InModuleScope LastWarAutoScreenshot {
            $profile = [PSCustomObject]@{ cloudProvider = 'gcp' }
            Test-LWASAzureProfile -Profile $profile | Should -BeFalse
        }
    }

    # cloudProvider = 'aws' → $false
    It 'Profile with cloudProvider = ''aws'' → $false' {
        InModuleScope LastWarAutoScreenshot {
            $profile = [PSCustomObject]@{ cloudProvider = 'aws' }
            Test-LWASAzureProfile -Profile $profile | Should -BeFalse
        }
    }

    # cloudProvider = '' (empty string) → $false
    It 'Profile with cloudProvider = '''' (empty string) → $false' {
        InModuleScope LastWarAutoScreenshot {
            $profile = [PSCustomObject]@{ cloudProvider = '' }
            Test-LWASAzureProfile -Profile $profile | Should -BeFalse
        }
    }

    # Profile object with no cloudProvider property → $false
    It 'Profile with no cloudProvider property → $false' {
        InModuleScope LastWarAutoScreenshot {
            $profile = [PSCustomObject]@{ name = 'legacy-profile'; provider = 'AzureBlobStorage' }
            Test-LWASAzureProfile -Profile $profile | Should -BeFalse
        }
    }

    # No Write-Error or Write-Warning in any case
    It 'No Write-Error or Write-Warning called for any input' -TestCases @(
        @{ CloudProvider = 'azure' }
        @{ CloudProvider = 'gcp' }
        @{ CloudProvider = '' }
    ) {
        param($CloudProvider)
        InModuleScope LastWarAutoScreenshot -Parameters @{ Cp = $CloudProvider } {
            Mock Write-Error {}
            Mock Write-Warning {}

            $profile = [PSCustomObject]@{ cloudProvider = $Cp }
            Test-LWASAzureProfile -Profile $profile | Out-Null

            Should -Invoke Write-Error   -Times 0
            Should -Invoke Write-Warning -Times 0
        }
    }

    It 'No Write-Error or Write-Warning when cloudProvider property is absent' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-Error {}
            Mock Write-Warning {}

            $profile = [PSCustomObject]@{ name = 'no-cloud-provider' }
            Test-LWASAzureProfile -Profile $profile | Out-Null

            Should -Invoke Write-Error   -Times 0
            Should -Invoke Write-Warning -Times 0
        }
    }
}
