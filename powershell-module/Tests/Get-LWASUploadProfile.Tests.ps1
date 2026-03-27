BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Get-LWASUploadProfile' -Tag 'Unit' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
        }
    }

    It '8.5.1: No profiles configured — returns empty array, no error' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile { @() }

            $result = @(Get-LWASUploadProfile)

            ($result -is [array]) | Should -BeTrue
            $result.Count | Should -Be 0
        }
    }

    It '8.5.2: Profiles exist — returns array with correct count and all expected properties' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile {
                @(
                    [PSCustomObject]@{
                        name                   = 'profile-a'
                        provider               = 'AzureBlobStorage'
                        accountName            = 'acct1'
                        containerName          = 'c1'
                        sasTokenEnvVar         = 'ENV_A'
                        blobPathPattern        = '{MacroName}/{Date}/{Filename}'
                        maxRetryAttempts       = 3
                        retryBaseDelayMs       = 500
                        deleteLocalAfterUpload = $false
                        deleteLocalAfterDays   = 30
                        createdUtc             = '2026-03-21T12:00:00Z'
                        modifiedUtc            = '2026-03-21T12:00:00Z'
                    },
                    [PSCustomObject]@{
                        name                   = 'profile-b'
                        provider               = 'AzureBlobStorage'
                        accountName            = 'acct2'
                        containerName          = 'c2'
                        sasTokenEnvVar         = 'ENV_B'
                        blobPathPattern        = '{MacroName}/{Date}/{Filename}'
                        maxRetryAttempts       = 3
                        retryBaseDelayMs       = 500
                        deleteLocalAfterUpload = $false
                        deleteLocalAfterDays   = 30
                        createdUtc             = '2026-03-21T12:00:00Z'
                        modifiedUtc            = '2026-03-21T12:00:00Z'
                    }
                )
            }

            $result = @(Get-LWASUploadProfile)

            $result.Count | Should -Be 2
            $result[0].name | Should -Be 'profile-a'
            $result[1].name | Should -Be 'profile-b'
            $result[0].PSObject.Properties.Name | Should -Contain 'accountName'
            $result[0].PSObject.Properties.Name | Should -Contain 'sasTokenEnvVar'
        }
    }

    It '8.5.3: -Name with existing profile — returns the single matching object' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile {
                [PSCustomObject]@{
                    name           = 'azure-1'
                    accountName    = 'myaccount'
                    containerName  = 'screenshots'
                    sasTokenEnvVar = 'LWAS_SAS'
                }
            }

            $result = Get-LWASUploadProfile -Name 'azure-1'

            $result | Should -Not -BeNull
            $result.name | Should -Be 'azure-1'
            Should -Invoke Get-UploadProfile -Times 1 -ParameterFilter { $Name -eq 'azure-1' }
        }
    }

    It '8.5.5: -Property without -Name — returns only the specified properties for all profiles' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile {
                @(
                    [PSCustomObject]@{
                        name           = 'profile-a'
                        accountName    = 'acct1'
                        containerName  = 'c1'
                        sasTokenEnvVar = 'ENV_A'
                    }
                )
            }

            $result = @(Get-LWASUploadProfile -Property name, accountName)

            $result.Count | Should -Be 1
            $result[0].PSObject.Properties.Name | Should -Contain 'name'
            $result[0].PSObject.Properties.Name | Should -Contain 'accountName'
            $result[0].PSObject.Properties.Name | Should -Not -Contain 'containerName'
            $result[0].PSObject.Properties.Name | Should -Not -Contain 'sasTokenEnvVar'
        }
    }

    It '8.5.6: -Property with -Name — returns only the specified properties for the matched profile' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile {
                [PSCustomObject]@{
                    name           = 'azure-1'
                    accountName    = 'myaccount'
                    containerName  = 'screenshots'
                    sasTokenEnvVar = 'LWAS_SAS'
                }
            }

            $result = Get-LWASUploadProfile -Name 'azure-1' -Property name, containerName

            $result | Should -Not -BeNull
            $result.PSObject.Properties.Name | Should -Contain 'name'
            $result.PSObject.Properties.Name | Should -Contain 'containerName'
            $result.PSObject.Properties.Name | Should -Not -Contain 'accountName'
            $result.PSObject.Properties.Name | Should -Not -Contain 'sasTokenEnvVar'
        }
    }

    It '8.5.4: -Name with non-existent profile — returns $null; Write-Warning called' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile { $null }
            Mock Write-Warning {}

            $result = Get-LWASUploadProfile -Name 'missing'

            $result | Should -BeNull
            Should -Invoke Write-Warning -Times 1 -ParameterFilter { $Message -like "*missing*" }
        }
    }
}
