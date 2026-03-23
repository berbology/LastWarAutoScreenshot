BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Assert-LWASAzStorageModule' -Tag 'Unit' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-Error {}
        }
    }

    # Module installed and already imported → $true; no prompt; no install; no Import-Module
    It 'Module installed and already imported → $true; Invoke-InstallAzStorageModule and Import-Module not called' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-Module {
                param($Name, [switch]$ListAvailable)
                # Both -ListAvailable and imported queries return a result
                [PSCustomObject]@{ Name = 'Az.Storage'; Version = '6.0.0' }
            }
            Mock Invoke-InstallAzStorageModule {}
            Mock Import-Module {}
            Mock Invoke-AzStorageInstallPrompt { 1 }  # No — should not be reached

            $result = Assert-LWASAzStorageModule

            $result | Should -BeTrue
            Should -Invoke Invoke-InstallAzStorageModule   -Times 0
            Should -Invoke Import-Module                   -Times 0
            Should -Invoke Invoke-AzStorageInstallPrompt   -Times 0
        }
    }

    # Module installed but not yet imported → $true; Import-Module called once; no prompt; no install
    It 'Module installed but not imported → $true; Import-Module called once' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-Module {
                param($Name, [switch]$ListAvailable)
                if ($ListAvailable) {
                    return [PSCustomObject]@{ Name = 'Az.Storage'; Version = '6.0.0' }
                }
                # Not yet imported — return nothing
                return $null
            }
            Mock Invoke-InstallAzStorageModule {}
            Mock Import-Module {}
            Mock Invoke-AzStorageInstallPrompt { 1 }

            $result = Assert-LWASAzStorageModule

            $result | Should -BeTrue
            Should -Invoke Import-Module                 -Times 1 -ParameterFilter { $Name -eq 'Az.Storage' }
            Should -Invoke Invoke-InstallAzStorageModule -Times 0
            Should -Invoke Invoke-AzStorageInstallPrompt -Times 0
        }
    }

    # Not installed, user chooses Yes, install and import succeed → $true
    It 'Not installed, user chooses Yes, install succeeds, import succeeds → $true' {
        InModuleScope LastWarAutoScreenshot {
            $script:installCalled = $false
            Mock Get-Module {
                param($Name, [switch]$ListAvailable)
                # After install, ListAvailable returns a result; session check returns nothing until Import-Module runs
                if ($ListAvailable -and $script:installCalled) {
                    return [PSCustomObject]@{ Name = 'Az.Storage'; Version = '6.0.0' }
                }
                return $null
            }
            Mock Invoke-InstallAzStorageModule { $script:installCalled = $true }
            Mock Import-Module {}
            Mock Invoke-AzStorageInstallPrompt { 0 }  # Yes

            $result = Assert-LWASAzStorageModule

            $result | Should -BeTrue
            Should -Invoke Invoke-AzStorageInstallPrompt   -Times 1
            Should -Invoke Invoke-InstallAzStorageModule   -Times 1
            Should -Invoke Import-Module                   -Times 1 -ParameterFilter { $Name -eq 'Az.Storage' }
        }
    }

    # Not installed, user chooses No → Write-Error called; $false; no install
    It 'Not installed, user chooses No → Write-Error with install instructions; $false returned; Invoke-InstallAzStorageModule not called' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-Module { $null }
            Mock Invoke-InstallAzStorageModule {}
            Mock Import-Module {}
            Mock Invoke-AzStorageInstallPrompt { 1 }  # No

            $result = Assert-LWASAzStorageModule

            $result | Should -BeFalse
            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*Install-Module Az.Storage*' }
            Should -Invoke Invoke-InstallAzStorageModule -Times 0
        }
    }

    # Not installed, user chooses Yes, Invoke-InstallAzStorageModule throws → Write-Error; $false
    It 'Not installed, user chooses Yes, install throws → Write-Error with exception message; $false' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-Module { $null }
            Mock Invoke-InstallAzStorageModule { throw 'Network error: could not reach PSGallery' }
            Mock Import-Module {}
            Mock Invoke-AzStorageInstallPrompt { 0 }  # Yes

            $result = Assert-LWASAzStorageModule

            $result | Should -BeFalse
            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*installation failed*' }
        }
    }

    # Installed, Import-Module throws → Write-Error; $false
    It 'Installed, Import-Module throws → Write-Error with exception message; $false' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-Module {
                param($Name, [switch]$ListAvailable)
                if ($ListAvailable) {
                    return [PSCustomObject]@{ Name = 'Az.Storage'; Version = '6.0.0' }
                }
                return $null
            }
            Mock Invoke-InstallAzStorageModule {}
            Mock Import-Module { throw 'Dependency conflict loading Az.Storage' }
            Mock Invoke-AzStorageInstallPrompt { 1 }

            $result = Assert-LWASAzStorageModule

            $result | Should -BeFalse
            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*could not be imported*' }
        }
    }

    # No Write-Error on success paths (3.4.1, 3.4.2, 3.4.3)
    It 'Installed and imported (success path) → Write-Error not called' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-Module { [PSCustomObject]@{ Name = 'Az.Storage' } }
            Mock Invoke-InstallAzStorageModule {}
            Mock Import-Module {}
            Mock Invoke-AzStorageInstallPrompt { 1 }

            Assert-LWASAzStorageModule | Out-Null

            Should -Invoke Write-Error -Times 0
        }
    }

    It 'Installed but not imported (success path) → Write-Error not called' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-Module {
                param($Name, [switch]$ListAvailable)
                if ($ListAvailable) { return [PSCustomObject]@{ Name = 'Az.Storage' } }
                return $null
            }
            Mock Import-Module {}
            Mock Invoke-InstallAzStorageModule {}
            Mock Invoke-AzStorageInstallPrompt { 1 }

            Assert-LWASAzStorageModule | Out-Null

            Should -Invoke Write-Error -Times 0
        }
    }

    It 'Not installed, user Yes, install+import succeed (success path) → Write-Error not called' {
        InModuleScope LastWarAutoScreenshot {
            $script:installed = $false
            Mock Get-Module {
                param($Name, [switch]$ListAvailable)
                if ($ListAvailable -and $script:installed) { return [PSCustomObject]@{ Name = 'Az.Storage' } }
                return $null
            }
            Mock Invoke-InstallAzStorageModule { $script:installed = $true }
            Mock Import-Module {}
            Mock Invoke-AzStorageInstallPrompt { 0 }

            Assert-LWASAzStorageModule | Out-Null

            Should -Invoke Write-Error -Times 0
        }
    }
}
