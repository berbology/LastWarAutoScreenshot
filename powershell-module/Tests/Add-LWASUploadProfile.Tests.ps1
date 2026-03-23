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
        }
        # Ensure the test SAS env var is not set so the warning-only path is testable
        Remove-Item -Path Env:\LWAS_TEST_ADD_SAS -ErrorAction SilentlyContinue
    }

    AfterEach {
        Remove-Item -Path Env:\LWAS_TEST_ADD_SAS -ErrorAction SilentlyContinue
    }

    It '8.6.1: All mandatory parameters supplied — Save-UploadProfileFile called with all fields; success verbose written' {
        InModuleScope LastWarAutoScreenshot {
            $env:LWAS_TEST_ADD_SAS = 'sv=fake'

            $script:capturedProfile = $null
            Mock Save-UploadProfileFile { $script:capturedProfile = $Profile } -Verifiable

            New-LWASUploadProfile -Name 'my-profile' -AccountName 'myaccount' `
                -ContainerName 'screenshots' -SasTokenEnvVar 'LWAS_TEST_ADD_SAS' -Verbose 4>&1 | Out-Null

            $script:capturedProfile | Should -Not -BeNull
            $script:capturedProfile.name           | Should -Be 'my-profile'
            $script:capturedProfile.accountName    | Should -Be 'myaccount'
            $script:capturedProfile.containerName  | Should -Be 'screenshots'
            $script:capturedProfile.sasTokenEnvVar | Should -Be 'LWAS_TEST_ADD_SAS'
            $script:capturedProfile.provider       | Should -Be 'AzureBlobStorage'
            $script:capturedProfile.createdUtc     | Should -Not -BeNullOrEmpty
            $script:capturedProfile.modifiedUtc    | Should -Not -BeNullOrEmpty

            Remove-Item -Path Env:\LWAS_TEST_ADD_SAS -ErrorAction SilentlyContinue
        }
    }

    It '8.6.2: Default values applied for optional parameters when not supplied' {
        InModuleScope LastWarAutoScreenshot {
            $env:LWAS_TEST_ADD_SAS = 'sv=fake'

            $script:capturedProfile = $null
            Mock Save-UploadProfileFile { $script:capturedProfile = $Profile }

            New-LWASUploadProfile -Name 'defaults-test' -AccountName 'acct' `
                -ContainerName 'c' -SasTokenEnvVar 'LWAS_TEST_ADD_SAS'

            $script:capturedProfile.blobPathPattern        | Should -Be '{MacroName}/{Date}/{Filename}'
            $script:capturedProfile.maxRetryAttempts       | Should -Be 3
            $script:capturedProfile.retryBaseDelayMs       | Should -Be 500
            $script:capturedProfile.deleteLocalAfterUpload | Should -BeFalse
            $script:capturedProfile.deleteLocalAfterDays   | Should -Be 30

            Remove-Item -Path Env:\LWAS_TEST_ADD_SAS -ErrorAction SilentlyContinue
        }
    }

    It '8.6.3: -Name with invalid characters — Write-Error called; Save-UploadProfileFile not called' {
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

    It '8.6.4: Duplicate name — Write-Error called; Save-UploadProfileFile not called' {
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

    It '8.6.5: -SasTokenEnvVar containing spaces — Write-Error called' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-Error {}

            New-LWASUploadProfile -Name 'my-profile' -AccountName 'acct' `
                -ContainerName 'c' -SasTokenEnvVar 'ENV WITH SPACES'

            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*invalid characters*' }
            Should -Invoke Save-UploadProfileFile -Times 0
        }
    }

    It '8.6.6: -SasTokenEnvVar env var not currently set — Write-Warning called but profile is still saved' {
        InModuleScope LastWarAutoScreenshot {
            # LWAS_TEST_ADD_SAS is not set (cleared in AfterEach / BeforeEach)
            Mock Write-Warning {}

            New-LWASUploadProfile -Name 'warn-test' -AccountName 'acct' `
                -ContainerName 'c' -SasTokenEnvVar 'LWAS_TEST_ADD_SAS'

            Should -Invoke Write-Warning -Times 1 -ParameterFilter { $Message -like '*LWAS_TEST_ADD_SAS*' }
            Should -Invoke Save-UploadProfileFile -Times 1
        }
    }

    It '8.6.7: -MaxRetryAttempts outside range (0 or 11) — Write-Error called' -TestCases @(
        @{ Value = 0 }
        @{ Value = 11 }
    ) {
        param($Value)
        InModuleScope LastWarAutoScreenshot -Parameters @{ MaxAttempts = $Value } {
            $env:LWAS_TEST_ADD_SAS = 'sv=fake'
            Mock Write-Error {}

            New-LWASUploadProfile -Name 'range-test' -AccountName 'acct' `
                -ContainerName 'c' -SasTokenEnvVar 'LWAS_TEST_ADD_SAS' `
                -MaxRetryAttempts $MaxAttempts

            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*MaxRetryAttempts*' }
            Should -Invoke Save-UploadProfileFile -Times 0

            Remove-Item -Path Env:\LWAS_TEST_ADD_SAS -ErrorAction SilentlyContinue
        }
    }

    It '8.6.8: -DeleteLocalAfterDays outside range (0 or 3651) — Write-Error called' -TestCases @(
        @{ Value = 0 }
        @{ Value = 3651 }
    ) {
        param($Value)
        InModuleScope LastWarAutoScreenshot -Parameters @{ DaysValue = $Value } {
            $env:LWAS_TEST_ADD_SAS = 'sv=fake'
            Mock Write-Error {}

            New-LWASUploadProfile -Name 'days-test' -AccountName 'acct' `
                -ContainerName 'c' -SasTokenEnvVar 'LWAS_TEST_ADD_SAS' `
                -DeleteLocalAfterDays $DaysValue

            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*DeleteLocalAfterDays*' }
            Should -Invoke Save-UploadProfileFile -Times 0

            Remove-Item -Path Env:\LWAS_TEST_ADD_SAS -ErrorAction SilentlyContinue
        }
    }
}
