BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Rename-LWASUploadProfile' -Tag 'Unit' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
            Mock Write-Error {}
            Mock Remove-Item {}
            Mock Save-UploadProfileFile {}
        }
    }

    It 'Returns immediately without any side-effects when Name equals NewName' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile {}

            Rename-LWASUploadProfile -Name 'my-profile' -NewName 'my-profile'

            Should -Invoke Get-UploadProfile      -Times 0
            Should -Invoke Remove-Item            -Times 0
            Should -Invoke Save-UploadProfileFile -Times 0
        }
    }

    It 'Writes an error and makes no changes when the source profile is not found' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile { $null }

            Rename-LWASUploadProfile -Name 'missing' -NewName 'new-name'

            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like "*missing*not found*" }
            Should -Invoke Remove-Item            -Times 0
            Should -Invoke Save-UploadProfileFile -Times 0
        }
    }

    It 'Writes an error and makes no changes when NewName is already in use' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile {
                param($Name)
                # Both names resolve to an existing profile
                [PSCustomObject]@{ name = $Name; sasTokenEnvVar = 'LWAS_SAS_TEST' }
            }

            Rename-LWASUploadProfile -Name 'old-profile' -NewName 'existing-profile'

            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like "*existing-profile*already exists*" }
            Should -Invoke Remove-Item            -Times 0
            Should -Invoke Save-UploadProfileFile -Times 0
        }
    }

    It 'Removes the old file and saves the profile under the new name' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile {
                param($Name)
                if ($Name -eq 'old-profile') {
                    [PSCustomObject]@{ name = 'old-profile'; sasTokenEnvVar = 'LWAS_SAS_TEST' }
                } else {
                    $null
                }
            }

            Rename-LWASUploadProfile -Name 'old-profile' -NewName 'new-profile' -ProfilesDirectory 'C:\Profiles'

            Should -Invoke Remove-Item -Times 1 -ParameterFilter {
                $LiteralPath -like '*old-profile.json*'
            }
            Should -Invoke Save-UploadProfileFile -Times 1
        }
    }

    It 'Updates the profile name field to NewName before saving' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile {
                param($Name)
                if ($Name -eq 'old-profile') {
                    [PSCustomObject]@{ name = 'old-profile'; sasTokenEnvVar = 'LWAS_SAS_TEST' }
                } else {
                    $null
                }
            }
            Mock Save-UploadProfileFile {
                param($Profile, $ProfilesDirectory)
                $script:savedProfile = $Profile
            }

            Rename-LWASUploadProfile -Name 'old-profile' -NewName 'new-profile'

            $script:savedProfile.name | Should -Be 'new-profile'
        }
    }

    It 'Logs at Info level after a successful rename' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile {
                param($Name)
                if ($Name -eq 'old-profile') {
                    [PSCustomObject]@{ name = 'old-profile'; sasTokenEnvVar = 'LWAS_SAS_TEST' }
                } else {
                    $null
                }
            }

            Rename-LWASUploadProfile -Name 'old-profile' -NewName 'new-profile'

            Should -Invoke Write-LastWarLog -Times 1 -ParameterFilter { $Level -eq 'Info' }
        }
    }

    It '-WhatIf suppresses file operations and logging' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile {
                param($Name)
                if ($Name -eq 'old-profile') {
                    [PSCustomObject]@{ name = 'old-profile'; sasTokenEnvVar = 'LWAS_SAS_TEST' }
                } else {
                    $null
                }
            }

            Rename-LWASUploadProfile -Name 'old-profile' -NewName 'new-profile' -WhatIf

            Should -Invoke Remove-Item            -Times 0
            Should -Invoke Save-UploadProfileFile -Times 0
            Should -Invoke Write-LastWarLog       -Times 0
        }
    }
}
