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
                [PSCustomObject]@{ name = 'my-profile' }
            }
            Mock Remove-UploadProfileFile {}
            Mock Read-Host { 'Y' }
            Mock Write-Error {}
        }
    }

    It '8.7.1: Profile not found — Write-Error called; Remove-UploadProfileFile not called' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile { $null }

            Remove-LWASUploadProfile -Name 'missing' -Force

            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like "*missing*not found*" }
            Should -Invoke Remove-UploadProfileFile -Times 0
        }
    }

    It '8.7.2: Without -Force, user answers Y — Remove-UploadProfileFile called' {
        InModuleScope LastWarAutoScreenshot {
            Mock Read-Host { 'Y' }

            Remove-LWASUploadProfile -Name 'my-profile'

            Should -Invoke Read-Host -Times 1
            Should -Invoke Remove-UploadProfileFile -Times 1 -ParameterFilter { $Name -eq 'my-profile' }
        }
    }

    It '8.7.3: Without -Force, user answers N — Remove-UploadProfileFile not called' {
        InModuleScope LastWarAutoScreenshot {
            Mock Read-Host { 'N' }

            Remove-LWASUploadProfile -Name 'my-profile'

            Should -Invoke Read-Host -Times 1
            Should -Invoke Remove-UploadProfileFile -Times 0
        }
    }

    It '8.7.4: -Force specified — Remove-UploadProfileFile called without Read-Host prompt' {
        InModuleScope LastWarAutoScreenshot {
            Remove-LWASUploadProfile -Name 'my-profile' -Force

            Should -Invoke Read-Host -Times 0
            Should -Invoke Remove-UploadProfileFile -Times 1 -ParameterFilter { $Name -eq 'my-profile' }
        }
    }

    It '8.7.5: -WhatIf specified — Remove-UploadProfileFile not called' {
        InModuleScope LastWarAutoScreenshot {
            Remove-LWASUploadProfile -Name 'my-profile' -Force -WhatIf

            Should -Invoke Remove-UploadProfileFile -Times 0
        }
    }
}
