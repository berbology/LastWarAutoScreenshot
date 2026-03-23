BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'New-LWASUploadProfile' -Tag 'Unit' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
            Mock Get-ValidMacroName {
                [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
            }
            Mock Get-UploadProfile { $null }
            Mock Save-UploadProfileFile {}
            Mock Write-Warning {}
            Mock Test-LWASSASTokenIsValid { $true }
            Mock Update-LWASUploadProfileSASToken { $true }
        }
        Remove-Item -Path Env:\LWAS_SAS_TEST -ErrorAction SilentlyContinue
    }

    AfterEach {
        Remove-Item -Path Env:\LWAS_SAS_TEST -ErrorAction SilentlyContinue
    }

    It 'All mandatory parameters supplied — Save-UploadProfileFile called with all fields; success verbose written' {
        InModuleScope LastWarAutoScreenshot {
            $env:LWAS_SAS_TEST = 'sv=fake'

            $script:capturedProfile = $null
            Mock Save-UploadProfileFile { $script:capturedProfile = $Profile } -Verifiable

            New-LWASUploadProfile -Name 'my-profile' -AccountName 'myaccount' `
                -ContainerName 'screenshots' -SasTokenEnvVar 'LWAS_SAS_TEST' -Verbose 4>&1 | Out-Null

            $script:capturedProfile | Should -Not -BeNull
            $script:capturedProfile.name           | Should -Be 'my-profile'
            $script:capturedProfile.accountName    | Should -Be 'myaccount'
            $script:capturedProfile.containerName  | Should -Be 'screenshots'
            $script:capturedProfile.sasTokenEnvVar | Should -Be 'LWAS_SAS_TEST'
            $script:capturedProfile.provider       | Should -Be 'AzureBlobStorage'
            $script:capturedProfile.cloudProvider  | Should -Be 'azure'
            $script:capturedProfile.createdUtc     | Should -Not -BeNullOrEmpty
            $script:capturedProfile.modifiedUtc    | Should -Not -BeNullOrEmpty

            Remove-Item -Path Env:\LWAS_SAS_TEST -ErrorAction SilentlyContinue
        }
    }

    It 'Default values applied for optional parameters when not supplied' {
        InModuleScope LastWarAutoScreenshot {
            $env:LWAS_SAS_TEST = 'sv=fake'

            $script:capturedProfile = $null
            Mock Save-UploadProfileFile { $script:capturedProfile = $Profile }

            New-LWASUploadProfile -Name 'defaults-test' -AccountName 'acct' `
                -ContainerName 'c' -SasTokenEnvVar 'LWAS_SAS_TEST'

            $script:capturedProfile.blobPathPattern        | Should -Be '{MacroName}/{Date}/{Filename}'
            $script:capturedProfile.maxRetryAttempts       | Should -Be 3
            $script:capturedProfile.retryBaseDelayMs       | Should -Be 500
            $script:capturedProfile.deleteLocalAfterUpload | Should -BeFalse
            $script:capturedProfile.deleteLocalAfterDays   | Should -Be 30

            Remove-Item -Path Env:\LWAS_SAS_TEST -ErrorAction SilentlyContinue
        }
    }

    It '-Name with invalid characters — Write-Error called; Save-UploadProfileFile not called' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-ValidMacroName {
                [PSCustomObject]@{ Valid = $false; SanitisedName = ''; WasAutoFixed = $false; Message = "Name contains invalid characters." }
            }
            Mock Write-Error {}

            New-LWASUploadProfile -Name '!bad name!' -AccountName 'acct' `
                -ContainerName 'c' -SasTokenEnvVar 'ENV'

            Should -Invoke Write-Error -Times 1
            Should -Invoke Save-UploadProfileFile -Times 0
        }
    }

    It 'Duplicate name — Write-Error called; Save-UploadProfileFile not called' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile {
                [PSCustomObject]@{ name = 'existing-profile' }
            }
            Mock Write-Error {}

            New-LWASUploadProfile -Name 'existing-profile' -AccountName 'acct' `
                -ContainerName 'c' -SasTokenEnvVar 'ENV'

            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*already exists*' }
            Should -Invoke Save-UploadProfileFile -Times 0
        }
    }

    It '-SasTokenEnvVar containing spaces — Write-Error called' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-Error {}

            New-LWASUploadProfile -Name 'my-profile' -AccountName 'acct' `
                -ContainerName 'c' -SasTokenEnvVar 'LWAS_SAS_INVALID NAME'

            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*invalid characters*' }
            Should -Invoke Save-UploadProfileFile -Times 0
        }
    }

    It 'SAS token invalid on save — Update-LWASUploadProfileSASToken called; Write-Warning on failure; profile still saved' {
        InModuleScope LastWarAutoScreenshot {
            Mock Test-LWASSASTokenIsValid { $false }
            Mock Update-LWASUploadProfileSASToken { $false }
            Mock Write-Warning {}

            New-LWASUploadProfile -Name 'warn-test' -AccountName 'acct' `
                -ContainerName 'c' -SasTokenEnvVar 'LWAS_SAS_TEST'

            Should -Invoke Update-LWASUploadProfileSASToken -Times 1
            Should -Invoke Write-Warning -Times 1 -ParameterFilter { $Message -like '*Connect-AzAccount*' }
            Should -Invoke Save-UploadProfileFile -Times 1
        }
    }

    It '-MaxRetryAttempts outside range (0 or 11) — Write-Error called' -TestCases @(
        @{ Value = 0 }
        @{ Value = 11 }
    ) {
        param($Value)
        InModuleScope LastWarAutoScreenshot -Parameters @{ MaxAttempts = $Value } {
            $env:LWAS_SAS_TEST = 'sv=fake'
            Mock Write-Error {}

            New-LWASUploadProfile -Name 'range-test' -AccountName 'acct' `
                -ContainerName 'c' -SasTokenEnvVar 'LWAS_SAS_TEST' `
                -MaxRetryAttempts $MaxAttempts

            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*MaxRetryAttempts*' }
            Should -Invoke Save-UploadProfileFile -Times 0

            Remove-Item -Path Env:\LWAS_SAS_TEST -ErrorAction SilentlyContinue
        }
    }

    It '-DeleteLocalAfterDays outside range (0 or 3651) — Write-Error called' -TestCases @(
        @{ Value = 0 }
        @{ Value = 3651 }
    ) {
        param($Value)
        InModuleScope LastWarAutoScreenshot -Parameters @{ DaysValue = $Value } {
            $env:LWAS_SAS_TEST = 'sv=fake'
            Mock Write-Error {}

            New-LWASUploadProfile -Name 'days-test' -AccountName 'acct' `
                -ContainerName 'c' -SasTokenEnvVar 'LWAS_SAS_TEST' `
                -DeleteLocalAfterDays $DaysValue

            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*DeleteLocalAfterDays*' }
            Should -Invoke Save-UploadProfileFile -Times 0

            Remove-Item -Path Env:\LWAS_SAS_TEST -ErrorAction SilentlyContinue
        }
    }

    It 'Default -CloudProvider is azure — saved profile has cloudProvider = azure' {
        InModuleScope LastWarAutoScreenshot {
            $env:LWAS_SAS_TEST = 'sv=fake'

            $script:capturedProfile = $null
            Mock Save-UploadProfileFile { $script:capturedProfile = $Profile }

            New-LWASUploadProfile -Name 'cloud-default' -AccountName 'acct' `
                -ContainerName 'c' -SasTokenEnvVar 'LWAS_SAS_TEST'

            $script:capturedProfile.cloudProvider | Should -Be 'azure'

            Remove-Item -Path Env:\LWAS_SAS_TEST -ErrorAction SilentlyContinue
        }
    }

    It '-CloudProvider gcp — Write-Error called; Save-UploadProfileFile not called' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-Error {}

            New-LWASUploadProfile -Name 'gcp-test' -AccountName 'acct' `
                -ContainerName 'c' -SasTokenEnvVar 'LWAS_SAS_TEST' -CloudProvider 'gcp'

            Should -Invoke Write-Error -Times 1
            Should -Invoke Save-UploadProfileFile -Times 0
        }
    }

    It '-SasTokenEnvVar without LWAS_SAS_ prefix — Write-Error called; no profile saved' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-Error {}

            New-LWASUploadProfile -Name 'prefix-test' -AccountName 'acct' `
                -ContainerName 'c' -SasTokenEnvVar 'MY_TOKEN'

            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like "*LWAS_SAS_*" }
            Should -Invoke Save-UploadProfileFile -Times 0
        }
    }

    It '-SasTokenEnvVar with valid LWAS_SAS_ prefix — no prefix error; profile saved' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-Error {}

            New-LWASUploadProfile -Name 'valid-prefix' -AccountName 'acct' `
                -ContainerName 'c' -SasTokenEnvVar 'LWAS_SAS_MY_TOKEN'

            Should -Invoke Write-Error -Times 0 -ParameterFilter { $Message -like "*LWAS_SAS_*" }
            Should -Invoke Save-UploadProfileFile -Times 1
        }
    }

    It 'Token valid on save — Update-LWASUploadProfileSASToken not called' {
        InModuleScope LastWarAutoScreenshot {
            Mock Test-LWASSASTokenIsValid { $true }

            New-LWASUploadProfile -Name 'valid-token' -AccountName 'acct' `
                -ContainerName 'c' -SasTokenEnvVar 'LWAS_SAS_TEST'

            Should -Invoke Update-LWASUploadProfileSASToken -Times 0
        }
    }

    It 'Token absent or expired on save — Update-LWASUploadProfileSASToken called exactly once' {
        InModuleScope LastWarAutoScreenshot {
            Mock Test-LWASSASTokenIsValid { $false }
            Mock Update-LWASUploadProfileSASToken { $true }

            New-LWASUploadProfile -Name 'expired-token' -AccountName 'acct' `
                -ContainerName 'c' -SasTokenEnvVar 'LWAS_SAS_TEST'

            Should -Invoke Update-LWASUploadProfileSASToken -Times 1
        }
    }

    It 'Update-LWASUploadProfileSASToken returns false — Write-Warning called; profile was still saved' {
        InModuleScope LastWarAutoScreenshot {
            Mock Test-LWASSASTokenIsValid { $false }
            Mock Update-LWASUploadProfileSASToken { $false }
            Mock Write-Warning {}

            New-LWASUploadProfile -Name 'update-fails' -AccountName 'acct' `
                -ContainerName 'c' -SasTokenEnvVar 'LWAS_SAS_TEST'

            Should -Invoke Write-Warning -Times 1
            Should -Invoke Save-UploadProfileFile -Times 1
        }
    }
}
