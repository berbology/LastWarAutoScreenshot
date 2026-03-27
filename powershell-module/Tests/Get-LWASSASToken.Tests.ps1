BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force

    function script:New-FakeSasToken {
        param([string]$ExpiryValue)
        return "sv=2021-06-08&ss=b&srt=o&sp=rwdl&se=$ExpiryValue&spr=https&sig=FAKESIG"
    }
}

AfterAll {
    $processVars = [System.Environment]::GetEnvironmentVariables([System.EnvironmentVariableTarget]::Process)
    foreach ($key in @($processVars.Keys)) {
        if ($key -like 'LWAS_SAS_PESTER_*') {
            [Environment]::SetEnvironmentVariable($key, [NullString]::Value, [System.EnvironmentVariableTarget]::Process)

        }
    }
    # Use registry directly: GetEnvironmentVariables(User) may return stale entries in the current session
    $regKey = Get-Item -Path 'HKCU:\Environment' -ErrorAction SilentlyContinue
    if ($null -ne $regKey) {
        foreach ($name in @($regKey.GetValueNames() | Where-Object { $_ -like 'LWAS_SAS_PESTER_*' })) {
            Remove-ItemProperty -Path 'HKCU:\Environment' -Name $name -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Get-LWASSASToken' -Tag 'Unit' {

    BeforeEach {
        # Ensure test variables start cleared before each test in both scopes to prevent
        # pollution from prior test runs that may have written to User or Process scope
        $processVars = [System.Environment]::GetEnvironmentVariables([System.EnvironmentVariableTarget]::Process)
        foreach ($key in @($processVars.Keys)) {
            if ($key -like 'LWAS_SAS_PESTER_*') {
                [Environment]::SetEnvironmentVariable($key, [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
            }
        }
        # Use registry directly: GetEnvironmentVariables(User) may return stale entries in the current session
        $regKey = Get-Item -Path 'HKCU:\Environment' -ErrorAction SilentlyContinue
        if ($null -ne $regKey) {
            foreach ($name in @($regKey.GetValueNames() | Where-Object { $_ -like 'LWAS_SAS_PESTER_*' })) {
                Remove-ItemProperty -Path 'HKCU:\Environment' -Name $name -ErrorAction SilentlyContinue
            }
        }
    }

    AfterEach {
        $processVars = [System.Environment]::GetEnvironmentVariables([System.EnvironmentVariableTarget]::Process)
        foreach ($key in @($processVars.Keys)) {
            if ($key -like 'LWAS_SAS_PESTER_*') {
                [Environment]::SetEnvironmentVariable($key, [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
            }
        }
        # Use registry directly: GetEnvironmentVariables(User) may return stale entries in the current session
        $regKey = Get-Item -Path 'HKCU:\Environment' -ErrorAction SilentlyContinue
        if ($null -ne $regKey) {
            foreach ($name in @($regKey.GetValueNames() | Where-Object { $_ -like 'LWAS_SAS_PESTER_*' })) {
                Remove-ItemProperty -Path 'HKCU:\Environment' -Name $name -ErrorAction SilentlyContinue
            }
        }
    }

    It 'Returns an empty array when no matching variable exists' {
        # GetEnvironmentVariables(User) may return stale entries in the current session after
        # removal. Read HKCU:\Environment directly as the authoritative source instead.
        $regKey = Get-Item -Path 'HKCU:\Environment' -ErrorAction SilentlyContinue
        $matchingVars = if ($null -ne $regKey) {
            @($regKey.GetValueNames() | Where-Object { $_ -like 'LWAS_SAS_PESTER_*' })
        } else {
            @()
        }
        $matchingVars.Count | Should -Be 0
    }

    It 'Returns one result with Valid=$true for a token with a future expiry' {
        $futureToken = New-FakeSasToken -ExpiryValue ([datetime]::UtcNow.AddYears(1).ToString('yyyy-MM-ddTHH:mm:ssZ'))
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_A', $futureToken, [System.EnvironmentVariableTarget]::Process)

        $result = @(Get-LWASSASToken -Name 'LWAS_SAS_PESTER_A')

        $result.Count | Should -Be 1
        $result[0].Name  | Should -Be 'LWAS_SAS_PESTER_A'
        $result[0].Valid | Should -BeTrue
    }

    It 'Returns Valid=$false for a token with a past expiry' {
        $expiredToken = New-FakeSasToken -ExpiryValue ([datetime]::UtcNow.AddDays(-1).ToString('yyyy-MM-ddTHH:mm:ssZ'))
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_A', $expiredToken, [System.EnvironmentVariableTarget]::Process)

        $result = @(Get-LWASSASToken -Name 'LWAS_SAS_PESTER_A')

        $result[0].Valid | Should -BeFalse
    }

    It 'Returns Valid=$false when the variable value is empty' {
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_A', '', [System.EnvironmentVariableTarget]::Process)

        $result = @(Get-LWASSASToken -Name 'LWAS_SAS_PESTER_A')

        $result[0].Valid | Should -BeFalse
    }

    It 'Each result always has Name, Value, Valid, Validation, and ValidationResponse properties' {
        $futureToken = New-FakeSasToken -ExpiryValue ([datetime]::UtcNow.AddYears(1).ToString('yyyy-MM-ddTHH:mm:ssZ'))
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_A', $futureToken, [System.EnvironmentVariableTarget]::Process)

        $result = @(Get-LWASSASToken -Name 'LWAS_SAS_PESTER_A')

        $result[0].PSObject.Properties.Name | Should -Contain 'Name'
        $result[0].PSObject.Properties.Name | Should -Contain 'Value'
        $result[0].PSObject.Properties.Name | Should -Contain 'Valid'
        $result[0].PSObject.Properties.Name | Should -Contain 'Validation'
        $result[0].PSObject.Properties.Name | Should -Contain 'ValidationResponse'
    }

    It 'Validation and ValidationResponse are $null when -VerifyOnline is not used' {
        $futureToken = New-FakeSasToken -ExpiryValue ([datetime]::UtcNow.AddYears(1).ToString('yyyy-MM-ddTHH:mm:ssZ'))
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_A', $futureToken, [System.EnvironmentVariableTarget]::Process)

        $result = @(Get-LWASSASToken -Name 'LWAS_SAS_PESTER_A')

        $result[0].Validation         | Should -BeNull
        $result[0].ValidationResponse | Should -BeNull
    }

    It '-Name wildcard filter returns only matching variables' {
        $futureToken = New-FakeSasToken -ExpiryValue ([datetime]::UtcNow.AddYears(1).ToString('yyyy-MM-ddTHH:mm:ssZ'))
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_A', $futureToken, [System.EnvironmentVariableTarget]::Process)
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_B', $futureToken, [System.EnvironmentVariableTarget]::Process)

        $result = @(Get-LWASSASToken -Name 'LWAS_SAS_PESTER_A')

        $result.Count       | Should -Be 1
        $result[0].Name     | Should -Be 'LWAS_SAS_PESTER_A'
    }

    It '-Name string array returns results matching any of the provided names' {
        $futureToken = New-FakeSasToken -ExpiryValue ([datetime]::UtcNow.AddYears(1).ToString('yyyy-MM-ddTHH:mm:ssZ'))
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_A', $futureToken, [System.EnvironmentVariableTarget]::Process)
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_B', $futureToken, [System.EnvironmentVariableTarget]::Process)
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_C', $futureToken, [System.EnvironmentVariableTarget]::Process)

        $result = @(Get-LWASSASToken -Name 'LWAS_SAS_PESTER_A', 'LWAS_SAS_PESTER_B')

        $result.Count | Should -Be 2
        ($result | Where-Object { $_.Name -eq 'LWAS_SAS_PESTER_A' }) | Should -Not -BeNull
        ($result | Where-Object { $_.Name -eq 'LWAS_SAS_PESTER_B' }) | Should -Not -BeNull
        ($result | Where-Object { $_.Name -eq 'LWAS_SAS_PESTER_C' }) | Should -BeNull
    }

    It '-Name string array with wildcard patterns returns results matching any pattern' {
        $futureToken = New-FakeSasToken -ExpiryValue ([datetime]::UtcNow.AddYears(1).ToString('yyyy-MM-ddTHH:mm:ssZ'))
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_A', $futureToken, [System.EnvironmentVariableTarget]::Process)
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_B', $futureToken, [System.EnvironmentVariableTarget]::Process)
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_C', $futureToken, [System.EnvironmentVariableTarget]::Process)

        $result = @(Get-LWASSASToken -Name 'LWAS_SAS_PESTER_A', 'LWAS_SAS_PESTER_C')

        $result.Count | Should -Be 2
        ($result | Where-Object { $_.Name -eq 'LWAS_SAS_PESTER_A' }) | Should -Not -BeNull
        ($result | Where-Object { $_.Name -eq 'LWAS_SAS_PESTER_C' }) | Should -Not -BeNull
        ($result | Where-Object { $_.Name -eq 'LWAS_SAS_PESTER_B' }) | Should -BeNull
    }

    It '-Name string array returns empty array when no names match' {
        $futureToken = New-FakeSasToken -ExpiryValue ([datetime]::UtcNow.AddYears(1).ToString('yyyy-MM-ddTHH:mm:ssZ'))
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_A', $futureToken, [System.EnvironmentVariableTarget]::Process)

        $result = @(Get-LWASSASToken -Name 'LWAS_SAS_PESTER_X', 'LWAS_SAS_PESTER_Y')

        $result.Count | Should -Be 0
    }

    It '-Property filter returns only the specified properties' {
        $futureToken = New-FakeSasToken -ExpiryValue ([datetime]::UtcNow.AddYears(1).ToString('yyyy-MM-ddTHH:mm:ssZ'))
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_A', $futureToken, [System.EnvironmentVariableTarget]::Process)

        $result = @(Get-LWASSASToken -Name 'LWAS_SAS_PESTER_A' -Property 'Name', 'Valid')

        $result[0].PSObject.Properties.Name | Should -Contain 'Name'
        $result[0].PSObject.Properties.Name | Should -Contain 'Valid'
        $result[0].PSObject.Properties.Name | Should -Not -Contain 'Value'
        $result[0].PSObject.Properties.Name | Should -Not -Contain 'Validation'
        $result[0].PSObject.Properties.Name | Should -Not -Contain 'ValidationResponse'
    }

    Context '-VerifyOnline' {

        It 'Sets Validation=Skip and ValidationResponse=N/A when token is locally invalid' {
            [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_A', '', [System.EnvironmentVariableTarget]::Process)

            $result = @(Get-LWASSASToken -Name 'LWAS_SAS_PESTER_A' -VerifyOnline)

            $result[0].Validation         | Should -Be 'Skip'
            $result[0].ValidationResponse | Should -Be 'N/A'
        }

        It 'Sets Validation=Skip when token is valid but no matching upload profile is found' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Get-UploadProfile { @() }
            }

            $futureToken = New-FakeSasToken -ExpiryValue ([datetime]::UtcNow.AddYears(1).ToString('yyyy-MM-ddTHH:mm:ssZ'))
            [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_A', $futureToken, [System.EnvironmentVariableTarget]::Process)

            $result = @(Get-LWASSASToken -Name 'LWAS_SAS_PESTER_A' -VerifyOnline)

            $result[0].Validation         | Should -Be 'Skip'
            $result[0].ValidationResponse | Should -Be 'N/A'
        }

        It 'Sets Validation=Pass when HTTP 200 is returned from the storage endpoint' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Get-UploadProfile {
                    [PSCustomObject]@{
                        sasTokenEnvVar = 'LWAS_SAS_PESTER_A'
                        accountName    = 'myaccount'
                        containerName  = 'mycontainer'
                    }
                }
                Mock Invoke-WebRequest {
                    [PSCustomObject]@{ StatusCode = 200 }
                }
            }

            $futureToken = New-FakeSasToken -ExpiryValue ([datetime]::UtcNow.AddYears(1).ToString('yyyy-MM-ddTHH:mm:ssZ'))
            [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_A', $futureToken, [System.EnvironmentVariableTarget]::Process)

            $result = @(Get-LWASSASToken -Name 'LWAS_SAS_PESTER_A' -VerifyOnline)

            $result[0].Validation         | Should -Be 'Pass'
            $result[0].ValidationResponse | Should -Be '200'
        }

        It 'Sets Validation=Fail and logs a Warning when all HTTP attempts fail' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Get-UploadProfile {
                    [PSCustomObject]@{
                        sasTokenEnvVar = 'LWAS_SAS_PESTER_A'
                        accountName    = 'myaccount'
                        containerName  = 'mycontainer'
                    }
                }
                Mock Invoke-WebRequest { throw [Microsoft.PowerShell.Commands.HttpResponseException]::new() }
            }

            $futureToken = New-FakeSasToken -ExpiryValue ([datetime]::UtcNow.AddYears(1).ToString('yyyy-MM-ddTHH:mm:ssZ'))
            [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_A', $futureToken, [System.EnvironmentVariableTarget]::Process)

            $result = @(Get-LWASSASToken -Name 'LWAS_SAS_PESTER_A' -VerifyOnline)

            $result[0].Validation | Should -Be 'Fail'

            InModuleScope LastWarAutoScreenshot {
                Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Warning' } -Times 1
            }
        }
    }
}
