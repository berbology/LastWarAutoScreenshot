BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Remove-LWASUploadProfile' -Tag 'Unit' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
            Mock Get-UploadProfile {
                [PSCustomObject]@{ name = 'my-profile'; sasTokenEnvVar = 'LWAS_SAS_TEST' }
            }
            Mock Remove-Item {}
            Mock Remove-LWASSasToken {}
            Mock Read-Host { 'Y' }
            Mock Write-Error {}
        }
    }

    It '8.7.1: Profile not found — Write-Error called; Remove-Item not called' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile { $null }

            Remove-LWASUploadProfile -Name 'missing' -Force

            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like "*missing*not found*" }
            Should -Invoke Remove-Item -Times 0
        }
    }

    It '8.7.2: Without -Force, user answers Y — profile and token removed' {
        InModuleScope LastWarAutoScreenshot {
            Mock Read-Host { 'Y' }
            Mock Get-UploadProfile {
                @(
                    [PSCustomObject]@{ name = 'my-profile'; sasTokenEnvVar = 'LWAS_SAS_TEST' }
                )
            }

            Remove-LWASUploadProfile -Name 'my-profile'

            Should -Invoke Read-Host -Times 1
            Should -Invoke Remove-Item -Times 1
            Should -Invoke Remove-LWASSasToken -Times 1 -ParameterFilter { $Name -eq 'LWAS_SAS_TEST' }
        }
    }

    It '8.7.3: Without -Force, user answers N — nothing removed' {
        InModuleScope LastWarAutoScreenshot {
            Mock Read-Host { 'N' }

            Remove-LWASUploadProfile -Name 'my-profile'

            Should -Invoke Read-Host -Times 1
            Should -Invoke Remove-Item -Times 0
            Should -Invoke Remove-LWASSasToken -Times 0
        }
    }

    It '8.7.4: -Force specified — profile and token removed without prompt' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile {
                @(
                    [PSCustomObject]@{ name = 'my-profile'; sasTokenEnvVar = 'LWAS_SAS_TEST' }
                )
            }

            Remove-LWASUploadProfile -Name 'my-profile' -Force

            Should -Invoke Read-Host -Times 0
            Should -Invoke Remove-Item -Times 1
            Should -Invoke Remove-LWASSasToken -Times 1 -ParameterFilter { $Name -eq 'LWAS_SAS_TEST' }
        }
    }

    It '8.7.5: -WhatIf specified — nothing removed' {
        InModuleScope LastWarAutoScreenshot {
            Remove-LWASUploadProfile -Name 'my-profile' -Force -WhatIf

            Should -Invoke Remove-Item -Times 0
            Should -Invoke Remove-LWASSasToken -Times 0
        }
    }

    It 'When other profiles use the same SAS token, token is not removed' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile {
                param($Name)
                if ($PSBoundParameters.ContainsKey('Name')) {
                    [PSCustomObject]@{ name = 'my-profile'; sasTokenEnvVar = 'LWAS_SAS_TEST' }
                } else {
                    @(
                        [PSCustomObject]@{ name = 'my-profile'; sasTokenEnvVar = 'LWAS_SAS_TEST' }
                        [PSCustomObject]@{ name = 'other-profile'; sasTokenEnvVar = 'LWAS_SAS_TEST' }
                    )
                }
            }

            Remove-LWASUploadProfile -Name 'my-profile' -Force

            Should -Invoke Remove-Item -Times 1
            Should -Invoke Remove-LWASSasToken -Times 0
        }
    }

    It 'When profile has no SAS token, no token removal is attempted' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile {
                param($Name)
                if ($PSBoundParameters.ContainsKey('Name')) {
                    [PSCustomObject]@{ name = 'my-profile'; sasTokenEnvVar = $null }
                } else {
                    @( [PSCustomObject]@{ name = 'my-profile'; sasTokenEnvVar = $null } )
                }
            }

            Remove-LWASUploadProfile -Name 'my-profile' -Force

            Should -Invoke Remove-Item -Times 1
            Should -Invoke Remove-LWASSasToken -Times 0
        }
    }

    It 'String array -Name — removes all specified profiles' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile {
                param($Name)
                if ($PSBoundParameters.ContainsKey('Name')) {
                    [PSCustomObject]@{ name = $Name; sasTokenEnvVar = $null }
                } else {
                    @()
                }
            }

            Remove-LWASUploadProfile -Name 'profile-a', 'profile-b' -Force

            Should -Invoke Remove-Item -Times 2
        }
    }

    It 'String array -Name — skips missing profiles with Write-Error; continues to remove found ones' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile {
                param($Name)
                if ($PSBoundParameters.ContainsKey('Name')) {
                    if ($Name -eq 'profile-a') {
                        [PSCustomObject]@{ name = 'profile-a'; sasTokenEnvVar = $null }
                    } else {
                        $null
                    }
                } else {
                    @()
                }
            }

            Remove-LWASUploadProfile -Name 'profile-a', 'missing' -Force

            Should -Invoke Remove-Item -Times 1
            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*missing*not found*' }
        }
    }

    It 'Pipeline: accepts objects with a name property and removes each profile' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile {
                param($Name)
                if ($PSBoundParameters.ContainsKey('Name')) {
                    [PSCustomObject]@{ name = $Name; sasTokenEnvVar = $null }
                } else {
                    @()
                }
            }

            @(
                [PSCustomObject]@{ name = 'profile-a' }
                [PSCustomObject]@{ name = 'profile-b' }
            ) | Remove-LWASUploadProfile -Force

            Should -Invoke Remove-Item -Times 2
        }
    }

    It 'String array -Name — each profile prompted separately without -Force' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile {
                param($Name)
                if ($PSBoundParameters.ContainsKey('Name')) {
                    [PSCustomObject]@{ name = $Name; sasTokenEnvVar = $null }
                } else {
                    @()
                }
            }
            Mock Read-Host { 'Y' }

            Remove-LWASUploadProfile -Name 'profile-a', 'profile-b'

            Should -Invoke Read-Host -Times 2
            Should -Invoke Remove-Item -Times 2
        }
    }
}
