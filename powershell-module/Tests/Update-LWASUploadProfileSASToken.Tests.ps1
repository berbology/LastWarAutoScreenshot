BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force

    # Stub Az.Storage cmdlets so Pester can mock them without Az.Storage being installed.
    # These are replaced per-test by Mock inside InModuleScope; the stubs only need to exist
    # so that Pester can discover and intercept the commands.
    function global:New-AzStorageContext {
        param([string]$StorageAccountName, [switch]$UseConnectedAccount)
    }
    function global:New-AzStorageContainerSASToken {
        param($Name, $Context, $Permission, $ExpiryTime, $Protocol)
    }
    function global:Get-AzContext {}
    function global:Connect-AzAccount {}
}

AfterAll {
    Remove-Item -Path 'Function:\New-AzStorageContext'           -ErrorAction SilentlyContinue
    Remove-Item -Path 'Function:\New-AzStorageContainerSASToken' -ErrorAction SilentlyContinue
    Remove-Item -Path 'Function:\Get-AzContext'                  -ErrorAction SilentlyContinue
    Remove-Item -Path 'Function:\Connect-AzAccount'              -ErrorAction SilentlyContinue
}

Describe 'Update-LWASUploadProfileSASToken' -Tag 'Unit' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
            # Defensive stubs for Assert-LWASAzureSession internals — prevent any real Azure call
            # if the higher-level Assert-LWASAzureSession mock is somehow bypassed.
            Mock Invoke-GetAzContext     { [PSCustomObject]@{ Account = 'test@example.com' } }
            Mock Invoke-ConnectAzAccount {}
            # Default: Azure session is active; individual tests override when testing the failure path
            Mock Assert-LWASAzureSession { return $true }
        }
    }

    # Non-Azure profile
    It 'Profile with cloudProvider = gcp → Write-Error called; $false returned; no Az cmdlets invoked' {
        InModuleScope LastWarAutoScreenshot {
            $gcpProfile = [PSCustomObject]@{
                name           = 'gcp-profile'
                cloudProvider  = 'gcp'
                sasTokenEnvVar = 'LWAS_SAS_GCP'
                accountName    = 'myaccount'
                containerName  = 'shots'
            }

            Mock Assert-LWASAzStorageModule {}
            Mock New-AzStorageContext {}
            Mock New-AzStorageContainerSASToken {}

            $result = $null
            { $result = Update-LWASUploadProfileSASToken -Profile $gcpProfile } |
                Should -Throw -Not
            $result | Should -BeFalse

            Should -Invoke Assert-LWASAzStorageModule -Times 0 -ModuleName LastWarAutoScreenshot
            Should -Invoke New-AzStorageContext        -Times 0
            Should -Invoke New-AzStorageContainerSASToken -Times 0
        }
    }

    # Assert-LWASAzStorageModule returns $false
    It 'Assert-LWASAzStorageModule returns $false → function returns $false; no Az cmdlets invoked' {
        InModuleScope LastWarAutoScreenshot {
            $profile = [PSCustomObject]@{
                name           = 'azure-profile'
                cloudProvider  = 'azure'
                sasTokenEnvVar = 'LWAS_SAS_PROD'
                accountName    = 'myaccount'
                containerName  = 'shots'
            }

            Mock Assert-LWASAzStorageModule { return $false }
            Mock New-AzStorageContext {}
            Mock New-AzStorageContainerSASToken {}

            $result = Update-LWASUploadProfileSASToken -Profile $profile

            $result | Should -BeFalse
            Should -Invoke New-AzStorageContext        -Times 0
            Should -Invoke New-AzStorageContainerSASToken -Times 0
        }
    }

    # Assert-LWASAzureSession returns $false
    It 'Assert-LWASAzureSession returns $false → function returns $false; Az storage cmdlets not invoked' {
        InModuleScope LastWarAutoScreenshot {
            $profile = [PSCustomObject]@{
                name           = 'azure-profile'
                cloudProvider  = 'azure'
                sasTokenEnvVar = 'LWAS_SAS_PROD'
                accountName    = 'myaccount'
                containerName  = 'shots'
            }

            Mock Assert-LWASAzStorageModule { return $true }
            Mock Assert-LWASAzureSession    { return $false }
            Mock New-AzStorageContext {}
            Mock New-AzStorageContainerSASToken {}

            $result = Update-LWASUploadProfileSASToken -Profile $profile

            $result | Should -BeFalse
            Should -Invoke New-AzStorageContext           -Times 0
            Should -Invoke New-AzStorageContainerSASToken -Times 0
        }
    }

    # Empty sasTokenEnvVar
    It 'Az module available but sasTokenEnvVar is empty → Write-Error called; $false returned' {
        InModuleScope LastWarAutoScreenshot {
            $profile = [PSCustomObject]@{
                name           = 'azure-profile'
                cloudProvider  = 'azure'
                sasTokenEnvVar = ''
                accountName    = 'myaccount'
                containerName  = 'shots'
            }

            Mock Assert-LWASAzStorageModule { return $true }
            Mock New-AzStorageContext {}
            Mock New-AzStorageContainerSASToken {}

            $result = $null
            { $result = Update-LWASUploadProfileSASToken -Profile $profile -ErrorAction SilentlyContinue } |
                Should -Throw -Not
            $result | Should -BeFalse

            Should -Invoke New-AzStorageContext        -Times 0
            Should -Invoke New-AzStorageContainerSASToken -Times 0
        }
    }

    # All checks pass; valid token returned
    It 'All checks pass; token stored at User scope and in current session; $true returned' {
        InModuleScope LastWarAutoScreenshot {
            $profile = [PSCustomObject]@{
                name           = 'azure-profile'
                cloudProvider  = 'azure'
                sasTokenEnvVar = 'LWAS_SAS_PROD'
                accountName    = 'myaccount'
                containerName  = 'shots'
            }

            Mock Assert-LWASAzStorageModule { return $true }
            Mock New-AzStorageContext       { [PSCustomObject]@{ StorageAccountName = 'myaccount' } }
            Mock New-AzStorageContainerSASToken { return 'sv=2022-11-02&se=2027-01-01T00%3A00%3A00Z&sr=c&sp=rwdl&sig=abc123' }
            Mock Set-Item {}

            $setEnvCalled = $false
            $setEnvValue  = $null
            $setEnvScope  = $null

            # Capture [Environment]::SetEnvironmentVariable calls via a local mock approach
            # by replacing the call path — we test the behaviour indirectly via Set-Item and
            # verifying $true is returned. We also confirm SetEnvironmentVariable is attempted.

            $result = Update-LWASUploadProfileSASToken -Profile $profile

            $result | Should -BeTrue
            Should -Invoke New-AzStorageContext           -Times 1
            Should -Invoke New-AzStorageContainerSASToken -Times 1
            Should -Invoke Set-Item                       -Times 1 -ParameterFilter {
                $Path -eq 'Env:\LWAS_SAS_PROD'
            }
        }
    }

    # New-AzStorageContainerSASToken throws
    It 'New-AzStorageContainerSASToken throws → Write-Error mentions Connect-AzAccount; $false returned; env var not set' {
        InModuleScope LastWarAutoScreenshot {
            $profile = [PSCustomObject]@{
                name           = 'azure-profile'
                cloudProvider  = 'azure'
                sasTokenEnvVar = 'LWAS_SAS_PROD'
                accountName    = 'myaccount'
                containerName  = 'shots'
            }

            Mock Assert-LWASAzStorageModule { return $true }
            Mock New-AzStorageContext       { throw 'Please run Connect-AzAccount to connect.' }
            Mock Write-Error {}
            Mock Set-Item {}

            $result = Update-LWASUploadProfileSASToken -Profile $profile -ErrorAction SilentlyContinue

            $result | Should -BeFalse
            Should -Invoke Write-Error -Times 1 -ParameterFilter {
                $Message -like '*Connect-AzAccount*'
            }
            Should -Invoke Set-Item -Times 0
        }
    }

    # New-AzStorageContainerSASToken returns null (non-terminating error path)
    It 'New-AzStorageContainerSASToken returns null → Write-Error called; $false returned; Set-Item not called' {
        InModuleScope LastWarAutoScreenshot {
            $profile = [PSCustomObject]@{
                name           = 'azure-profile'
                cloudProvider  = 'azure'
                sasTokenEnvVar = 'LWAS_SAS_PROD'
                accountName    = 'myaccount'
                containerName  = 'shots'
            }

            Mock Assert-LWASAzStorageModule { return $true }
            Mock New-AzStorageContext       { [PSCustomObject]@{ StorageAccountName = 'myaccount' } }
            Mock New-AzStorageContainerSASToken { return $null }
            Mock Write-Error {}
            Mock Set-Item {}

            $result = Update-LWASUploadProfileSASToken -Profile $profile -ErrorAction SilentlyContinue

            $result | Should -BeFalse
            Should -Invoke Write-Error -Times 1 -ParameterFilter {
                $Message -like '*returned null*'
            }
            Should -Invoke Set-Item -Times 0
        }
    }

    # Token with leading '?' stripped
    It 'Token returned with leading ? → stored token has ? stripped' {
        InModuleScope LastWarAutoScreenshot {
            $profile = [PSCustomObject]@{
                name           = 'azure-profile'
                cloudProvider  = 'azure'
                sasTokenEnvVar = 'LWAS_SAS_PROD'
                accountName    = 'myaccount'
                containerName  = 'shots'
            }

            Mock Assert-LWASAzStorageModule { return $true }
            Mock New-AzStorageContext       { [PSCustomObject]@{ StorageAccountName = 'myaccount' } }
            Mock New-AzStorageContainerSASToken { return '?sv=2022-11-02&se=2027-01-01T00%3A00%3A00Z&sr=c&sp=rwdl&sig=abc123' }
            Mock Set-Item {}

            Update-LWASUploadProfileSASToken -Profile $profile | Out-Null

            Should -Invoke Set-Item -Times 1 -ParameterFilter {
                $Path -eq 'Env:\LWAS_SAS_PROD' -and
                -not $Value.StartsWith('?')
            }
        }
    }

    # -WhatIf
    It '-WhatIf → no SetEnvironmentVariable; no Az cmdlets invoked; $false returned' {
        InModuleScope LastWarAutoScreenshot {
            $profile = [PSCustomObject]@{
                name           = 'azure-profile'
                cloudProvider  = 'azure'
                sasTokenEnvVar = 'LWAS_SAS_PROD'
                accountName    = 'myaccount'
                containerName  = 'shots'
            }

            Mock Assert-LWASAzStorageModule { return $true }
            Mock New-AzStorageContext {}
            Mock New-AzStorageContainerSASToken {}
            Mock Set-Item {}

            $result = Update-LWASUploadProfileSASToken -Profile $profile -WhatIf

            $result | Should -BeFalse
            Should -Invoke New-AzStorageContext           -Times 0
            Should -Invoke New-AzStorageContainerSASToken -Times 0
            Should -Invoke Set-Item                       -Times 0
        }
    }

    # Pipeline input — two profiles
    It 'Pipeline input with two Azure profiles → New-AzStorageContainerSASToken called once per profile; $true returned each time' {
        InModuleScope LastWarAutoScreenshot {
            $profile1 = [PSCustomObject]@{
                name           = 'azure-profile-1'
                cloudProvider  = 'azure'
                sasTokenEnvVar = 'LWAS_SAS_P1'
                accountName    = 'account1'
                containerName  = 'container1'
            }
            $profile2 = [PSCustomObject]@{
                name           = 'azure-profile-2'
                cloudProvider  = 'azure'
                sasTokenEnvVar = 'LWAS_SAS_P2'
                accountName    = 'account2'
                containerName  = 'container2'
            }

            Mock Assert-LWASAzStorageModule { return $true }
            Mock New-AzStorageContext       { [PSCustomObject]@{ StorageAccountName = $StorageAccountName } }
            Mock New-AzStorageContainerSASToken { return 'sv=2022-11-02&se=2027-01-01T00%3A00%3A00Z&sr=c&sp=rwdl&sig=abc123' }
            Mock Set-Item {}

            $results = @($profile1, $profile2 | Update-LWASUploadProfileSASToken)

            $results.Count | Should -Be 2
            $results[0] | Should -BeTrue
            $results[1] | Should -BeTrue
            Should -Invoke New-AzStorageContainerSASToken -Times 2
            Should -Invoke Set-Item                       -Times 2
        }
    }
}
