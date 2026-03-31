BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force

    # Stub Az.Storage cmdlets so Pester can mock them without Az.Storage being installed.
    # These are replaced per-test by Mock inside InModuleScope; the stubs only need to exist
    # so that Pester can discover and intercept the commands.
    function global:New-AzStorageContext {
        param([string]$StorageAccountName, [string]$StorageAccountKey)
    }
    function global:New-AzStorageAccountSASToken {
        param($Context, $Service, $ResourceType, $Permission, $ExpiryTime, $Protocol)
    }
    function global:Get-AzStorageAccountKey {
        param([string]$ResourceGroupName, [string]$Name)
    }
    function global:Get-AzContext {}
    function global:Connect-AzAccount {}
}

AfterAll {
    Remove-Item -Path 'Function:\New-AzStorageContext'        -ErrorAction SilentlyContinue
    Remove-Item -Path 'Function:\New-AzStorageAccountSASToken' -ErrorAction SilentlyContinue
    Remove-Item -Path 'Function:\Get-AzStorageAccountKey'     -ErrorAction SilentlyContinue
    Remove-Item -Path 'Function:\Get-AzContext'               -ErrorAction SilentlyContinue
    Remove-Item -Path 'Function:\Connect-AzAccount'           -ErrorAction SilentlyContinue
}

Describe 'Update-LWASSASToken' -Tag 'Unit' {

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

    # --- Profile resolution: explicit -UploadProfile ---

    It '-UploadProfile names a missing profile → Write-Error and Write-LastWarLog called; $false returned; no Az cmdlets invoked' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-LWASUploadProfile      { return $null }
            Mock Assert-LWASAzStorageModule {}
            Mock New-AzStorageContext {}
            Mock New-AzStorageAccountSASToken {}

            $result = $null
            { $result = Update-LWASSASToken -Name 'LWAS_SAS_PROD' -UploadProfile 'missing-profile' -ErrorAction SilentlyContinue } |
                Should -Throw -Not
            $result | Should -BeFalse

            Should -Invoke Write-LastWarLog -Times 1 -ModuleName LastWarAutoScreenshot -ParameterFilter {
                $Level -eq 'Error' -and $Message -like "*missing-profile*"
            }
            Should -Invoke Assert-LWASAzStorageModule   -Times 0 -ModuleName LastWarAutoScreenshot
            Should -Invoke New-AzStorageContext         -Times 0
            Should -Invoke New-AzStorageAccountSASToken -Times 0
        }
    }

    # --- Profile resolution: implicit lookup by sasTokenEnvVar ---

    It 'No -UploadProfile and no profile matches the env var → Write-Error and Write-LastWarLog called; $false returned' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-LWASUploadProfile { return @() }
            Mock Assert-LWASAzStorageModule {}
            Mock New-AzStorageContext {}
            Mock New-AzStorageAccountSASToken {}

            $result = $null
            { $result = Update-LWASSASToken -Name 'LWAS_SAS_UNKNOWN' -ErrorAction SilentlyContinue } |
                Should -Throw -Not
            $result | Should -BeFalse

            Should -Invoke Write-LastWarLog -Times 1 -ModuleName LastWarAutoScreenshot -ParameterFilter {
                $Level -eq 'Error' -and $Message -like "*LWAS_SAS_UNKNOWN*"
            }
            Should -Invoke New-AzStorageContext         -Times 0
            Should -Invoke New-AzStorageAccountSASToken -Times 0
        }
    }

    # --- Cloud provider guard ---

    It 'Profile with cloudProvider = gcp → Write-Error called; $false returned; no Az cmdlets invoked' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-LWASUploadProfile {
                [PSCustomObject]@{
                    name              = 'gcp-profile'
                    cloudProvider     = 'gcp'
                    sasTokenEnvVar    = 'LWAS_SAS_GCP'
                    resourceGroupName = 'my-resource-group'
                    accountName       = 'myaccount'
                    containerName     = 'shots'
                }
            }
            Mock Assert-LWASAzStorageModule {}
            Mock New-AzStorageContext {}
            Mock New-AzStorageAccountSASToken {}

            $result = $null
            { $result = Update-LWASSASToken -Name 'LWAS_SAS_GCP' -UploadProfile 'gcp-profile' -ErrorAction SilentlyContinue } |
                Should -Throw -Not
            $result | Should -BeFalse

            Should -Invoke Assert-LWASAzStorageModule -Times 0 -ModuleName LastWarAutoScreenshot
            Should -Invoke New-AzStorageContext        -Times 0
            Should -Invoke New-AzStorageAccountSASToken -Times 0
        }
    }

    # --- Az.Storage module guard ---

    It 'Assert-LWASAzStorageModule returns $false → function returns $false; no Az cmdlets invoked' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-LWASUploadProfile {
                [PSCustomObject]@{
                    name              = 'azure-profile'
                    cloudProvider     = 'azure'
                    sasTokenEnvVar    = 'LWAS_SAS_PROD'
                    resourceGroupName = 'my-resource-group'
                    accountName       = 'myaccount'
                    containerName     = 'shots'
                }
            }
            Mock Assert-LWASAzStorageModule { return $false }
            Mock New-AzStorageContext {}
            Mock New-AzStorageAccountSASToken {}

            $result = Update-LWASSASToken -Name 'LWAS_SAS_PROD' -UploadProfile 'azure-profile'

            $result | Should -BeFalse
            Should -Invoke New-AzStorageContext         -Times 0
            Should -Invoke New-AzStorageAccountSASToken -Times 0
        }
    }

    # --- Azure session guard ---

    It 'Assert-LWASAzureSession returns $false → function returns $false; Az storage cmdlets not invoked' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-LWASUploadProfile {
                [PSCustomObject]@{
                    name              = 'azure-profile'
                    cloudProvider     = 'azure'
                    sasTokenEnvVar    = 'LWAS_SAS_PROD'
                    resourceGroupName = 'my-resource-group'
                    accountName       = 'myaccount'
                    containerName     = 'shots'
                }
            }
            Mock Assert-LWASAzStorageModule { return $true }
            Mock Assert-LWASAzureSession    { return $false }
            Mock New-AzStorageContext {}
            Mock New-AzStorageAccountSASToken {}

            $result = Update-LWASSASToken -Name 'LWAS_SAS_PROD' -UploadProfile 'azure-profile'

            $result | Should -BeFalse
            Should -Invoke New-AzStorageContext           -Times 0
            Should -Invoke New-AzStorageAccountSASToken   -Times 0
        }
    }

    # --- Happy path ---

    It 'All checks pass; token stored at User scope and in current session; $true returned' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-LWASUploadProfile {
                [PSCustomObject]@{
                    name              = 'azure-profile'
                    cloudProvider     = 'azure'
                    sasTokenEnvVar    = 'LWAS_SAS_PROD'
                    resourceGroupName = 'my-resource-group'
                    accountName       = 'myaccount'
                    containerName     = 'shots'
                }
            }
            Mock Assert-LWASAzStorageModule { return $true }
            Mock Get-AzStorageAccountKey    { @([PSCustomObject]@{ Value = 'fake-key-1' }, [PSCustomObject]@{ Value = 'fake-key-2' }) }
            Mock New-AzStorageContext       { [PSCustomObject]@{ StorageAccountName = 'myaccount' } }
            Mock New-AzStorageAccountSASToken { return 'sv=2022-11-02&se=2027-01-01T00%3A00%3A00Z&sr=c&sp=rwdl&sig=abc123' }
            Mock Set-LWASSasToken {}

            $result = Update-LWASSASToken -Name 'LWAS_SAS_PROD' -UploadProfile 'azure-profile'

            $result | Should -BeTrue
            Should -Invoke Get-AzStorageAccountKey      -Times 1 -ParameterFilter {
                $ResourceGroupName -eq 'my-resource-group' -and $Name -eq 'myaccount'
            }
            Should -Invoke New-AzStorageContext         -Times 1
            Should -Invoke New-AzStorageAccountSASToken -Times 1
            Should -Invoke Set-LWASSasToken             -Times 1 -ParameterFilter {
                $Name -eq 'LWAS_SAS_PROD'
            }
        }
    }

    # --- Az cmdlet failure paths ---

    It 'New-AzStorageContext throws → Write-Error mentions Connect-AzAccount; $false returned; env var not set' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-LWASUploadProfile {
                [PSCustomObject]@{
                    name              = 'azure-profile'
                    cloudProvider     = 'azure'
                    sasTokenEnvVar    = 'LWAS_SAS_PROD'
                    resourceGroupName = 'my-resource-group'
                    accountName       = 'myaccount'
                    containerName     = 'shots'
                }
            }
            Mock Assert-LWASAzStorageModule { return $true }
            Mock Get-AzStorageAccountKey    { @([PSCustomObject]@{ Value = 'fake-key-1' }) }
            Mock New-AzStorageContext       { throw 'Please run Connect-AzAccount to connect.' }
            Mock Write-Error {}
            Mock Set-Item {}

            $result = Update-LWASSASToken -Name 'LWAS_SAS_PROD' -UploadProfile 'azure-profile' -ErrorAction SilentlyContinue

            $result | Should -BeFalse
            Should -Invoke Write-Error -Times 1 -ParameterFilter {
                $Message -like '*Connect-AzAccount*'
            }
            Should -Invoke Set-Item -Times 0
        }
    }

    It 'New-AzStorageAccountSASToken returns null → Write-Error called; $false returned; Set-Item not called' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-LWASUploadProfile {
                [PSCustomObject]@{
                    name              = 'azure-profile'
                    cloudProvider     = 'azure'
                    sasTokenEnvVar    = 'LWAS_SAS_PROD'
                    resourceGroupName = 'my-resource-group'
                    accountName       = 'myaccount'
                    containerName     = 'shots'
                }
            }
            Mock Assert-LWASAzStorageModule   { return $true }
            Mock Get-AzStorageAccountKey      { @([PSCustomObject]@{ Value = 'fake-key-1' }) }
            Mock New-AzStorageContext          { [PSCustomObject]@{ StorageAccountName = 'myaccount' } }
            Mock New-AzStorageAccountSASToken  { return $null }
            Mock Write-Error {}
            Mock Set-Item {}

            $result = Update-LWASSASToken -Name 'LWAS_SAS_PROD' -UploadProfile 'azure-profile' -ErrorAction SilentlyContinue

            $result | Should -BeFalse
            Should -Invoke Write-Error -Times 1 -ParameterFilter {
                $Message -like '*returned null*'
            }
            Should -Invoke Set-Item -Times 0
        }
    }

    # --- Leading '?' stripped ---

    It 'Token returned with leading ? → stored token has ? stripped' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-LWASUploadProfile {
                [PSCustomObject]@{
                    name              = 'azure-profile'
                    cloudProvider     = 'azure'
                    sasTokenEnvVar    = 'LWAS_SAS_PROD'
                    resourceGroupName = 'my-resource-group'
                    accountName       = 'myaccount'
                    containerName     = 'shots'
                }
            }
            Mock Assert-LWASAzStorageModule   { return $true }
            Mock Get-AzStorageAccountKey      { @([PSCustomObject]@{ Value = 'fake-key-1' }) }
            Mock New-AzStorageContext          { [PSCustomObject]@{ StorageAccountName = 'myaccount' } }
            Mock New-AzStorageAccountSASToken  { return '?sv=2022-11-02&se=2027-01-01T00%3A00%3A00Z&sr=c&sp=rwdl&sig=abc123' }
            Mock Set-LWASSasToken {}

            Update-LWASSASToken -Name 'LWAS_SAS_PROD' -UploadProfile 'azure-profile' | Out-Null

            Should -Invoke Set-LWASSasToken -Times 1 -ParameterFilter {
                $Name -eq 'LWAS_SAS_PROD' -and
                -not $Token.StartsWith('?')
            }
        }
    }

    # --- -WhatIf ---

    It '-WhatIf → no SetEnvironmentVariable; no Az cmdlets invoked; $false returned' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-LWASUploadProfile {
                [PSCustomObject]@{
                    name              = 'azure-profile'
                    cloudProvider     = 'azure'
                    sasTokenEnvVar    = 'LWAS_SAS_PROD'
                    resourceGroupName = 'my-resource-group'
                    accountName       = 'myaccount'
                    containerName     = 'shots'
                }
            }
            Mock Assert-LWASAzStorageModule   { return $true }
            Mock Get-AzStorageAccountKey      {}
            Mock New-AzStorageContext {}
            Mock New-AzStorageAccountSASToken {}
            Mock Set-Item {}

            $result = Update-LWASSASToken -Name 'LWAS_SAS_PROD' -UploadProfile 'azure-profile' -WhatIf

            $result | Should -BeFalse
            Should -Invoke New-AzStorageContext         -Times 0
            Should -Invoke New-AzStorageAccountSASToken -Times 0
            Should -Invoke Set-Item                     -Times 0
        }
    }

    # --- Pipeline input (implicit profile lookup) ---

    It 'Pipeline input with two env var names → profile located by sasTokenEnvVar; token stored; $true returned each time' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-LWASUploadProfile {
                @(
                    [PSCustomObject]@{
                        name              = 'azure-profile-1'
                        cloudProvider     = 'azure'
                        sasTokenEnvVar    = 'LWAS_SAS_P1'
                        resourceGroupName = 'my-resource-group'
                        accountName       = 'account1'
                        containerName     = 'container1'
                    }
                    [PSCustomObject]@{
                        name              = 'azure-profile-2'
                        cloudProvider     = 'azure'
                        sasTokenEnvVar    = 'LWAS_SAS_P2'
                        resourceGroupName = 'my-resource-group'
                        accountName       = 'account2'
                        containerName     = 'container2'
                    }
                )
            }
            Mock Assert-LWASAzStorageModule   { return $true }
            Mock Get-AzStorageAccountKey      { @([PSCustomObject]@{ Value = 'fake-key-1' }) }
            Mock New-AzStorageContext          { [PSCustomObject]@{ StorageAccountName = $StorageAccountName } }
            Mock New-AzStorageAccountSASToken  { return 'sv=2022-11-02&se=2027-01-01T00%3A00%3A00Z&sr=c&sp=rwdl&sig=abc123' }
            Mock Set-LWASSasToken {}

            $results = @(
                [PSCustomObject]@{ Name = 'LWAS_SAS_P1' }
                [PSCustomObject]@{ Name = 'LWAS_SAS_P2' }
            ) | Update-LWASSASToken

            $results.Count | Should -Be 2
            $results[0] | Should -BeTrue
            $results[1] | Should -BeTrue
            Should -Invoke New-AzStorageAccountSASToken -Times 2
            Should -Invoke Set-LWASSasToken             -Times 2
        }
    }
}
