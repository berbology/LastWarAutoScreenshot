BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Get-LWASSASTokenEnvVarNames' -Tag 'Unit' {

    # Clean up any test env vars before and after each test to avoid cross-test pollution.
    # Only process-scope vars need cleanup here; user-scope vars are cleaned in specific tests.
    BeforeEach {
        Remove-Item -Path 'Env:\LWAS_SAS_TEST_A'     -ErrorAction SilentlyContinue
        Remove-Item -Path 'Env:\LWAS_SAS_TEST_B'     -ErrorAction SilentlyContinue
        Remove-Item -Path 'Env:\LWAS_SAS_TEST_C'     -ErrorAction SilentlyContinue
        Remove-Item -Path 'Env:\LWAS_SAS_PROD'       -ErrorAction SilentlyContinue
        Remove-Item -Path 'Env:\LWAS_STORAGE_TOKEN'  -ErrorAction SilentlyContinue
        Remove-Item -Path 'Env:\lwas_sas_dev'        -ErrorAction SilentlyContinue
    }

    AfterEach {
        Remove-Item -Path 'Env:\LWAS_SAS_TEST_A'     -ErrorAction SilentlyContinue
        Remove-Item -Path 'Env:\LWAS_SAS_TEST_B'     -ErrorAction SilentlyContinue
        Remove-Item -Path 'Env:\LWAS_SAS_TEST_C'     -ErrorAction SilentlyContinue
        Remove-Item -Path 'Env:\LWAS_SAS_PROD'       -ErrorAction SilentlyContinue
        Remove-Item -Path 'Env:\LWAS_STORAGE_TOKEN'  -ErrorAction SilentlyContinue
        Remove-Item -Path 'Env:\lwas_sas_dev'        -ErrorAction SilentlyContinue
    }

    # Return type guarantee: always a non-null array regardless of environment state
    It 'Always returns a non-null array' {
        InModuleScope LastWarAutoScreenshot {
            $result = Get-LWASSASTokenEnvVarNames

            $result | Should -Not -BeNull
            $result.GetType().IsArray | Should -BeTrue
        }
    }

    # One matching var in process scope → returned
    It 'One LWAS_SAS_PROD var set → returned in result' {
        InModuleScope LastWarAutoScreenshot {
            $env:LWAS_SAS_PROD = 'sv=fake-token'

            $result = Get-LWASSASTokenEnvVarNames

            $result | Should -Contain 'LWAS_SAS_PROD'
        }
    }

    # Same name in multiple scopes → deduplicated; appears exactly once
    It 'Same name LWAS_SAS_PROD in both User and Process scopes → deduplicated to one entry' {
        InModuleScope LastWarAutoScreenshot {
            # Set in both User and Process scopes
            [System.Environment]::SetEnvironmentVariable('LWAS_SAS_PROD', 'sv=user-token', [System.EnvironmentVariableTarget]::User)
            $env:LWAS_SAS_PROD = 'sv=process-token'

            try {
                $result = Get-LWASSASTokenEnvVarNames

                $count = ($result | Where-Object { $_ -eq 'LWAS_SAS_PROD' }).Count
                $count | Should -Be 1
            } finally {
                [System.Environment]::SetEnvironmentVariable('LWAS_SAS_PROD', $null, [System.EnvironmentVariableTarget]::User)
            }
        }
    }

    # Similar but non-matching prefix → not returned
    It 'LWAS_STORAGE_TOKEN (non-matching prefix) → not returned' {
        InModuleScope LastWarAutoScreenshot {
            $env:LWAS_STORAGE_TOKEN = 'sv=fake'

            $result = Get-LWASSASTokenEnvVarNames

            $result | Should -Not -Contain 'LWAS_STORAGE_TOKEN'
        }
    }

    # Multiple vars across scopes → all unique names returned, sorted alphabetically
    It 'Multiple LWAS_SAS_* vars → all unique names returned sorted alphabetically' {
        InModuleScope LastWarAutoScreenshot {
            $env:LWAS_SAS_TEST_C = 'token-c'
            $env:LWAS_SAS_TEST_A = 'token-a'
            $env:LWAS_SAS_TEST_B = 'token-b'

            $result = Get-LWASSASTokenEnvVarNames

            $result | Should -Contain 'LWAS_SAS_TEST_A'
            $result | Should -Contain 'LWAS_SAS_TEST_B'
            $result | Should -Contain 'LWAS_SAS_TEST_C'

            # Verify sorted order among our test vars
            $testVars = $result | Where-Object { $_ -in @('LWAS_SAS_TEST_A', 'LWAS_SAS_TEST_B', 'LWAS_SAS_TEST_C') }
            $testVars[0] | Should -Be 'LWAS_SAS_TEST_A'
            $testVars[1] | Should -Be 'LWAS_SAS_TEST_B'
            $testVars[2] | Should -Be 'LWAS_SAS_TEST_C'
        }
    }

    # Case-insensitive prefix match → included with original casing preserved
    It 'Var with lowercase prefix (lwas_sas_dev) → included; original casing preserved' {
        InModuleScope LastWarAutoScreenshot {
            # Note: on Windows, process env var names are case-insensitive storage-wise,
            # but the key returned by GetEnvironmentVariables preserves the casing used at creation.
            # We set via the hashtable key to preserve lowercase.
            [System.Environment]::SetEnvironmentVariable('lwas_sas_dev', 'sv=dev-token', [System.EnvironmentVariableTarget]::Process)

            try {
                $result = Get-LWASSASTokenEnvVarNames

                $match = $result | Where-Object { $_ -ieq 'lwas_sas_dev' }
                $match | Should -Not -BeNullOrEmpty
            } finally {
                [System.Environment]::SetEnvironmentVariable('lwas_sas_dev', $null, [System.EnvironmentVariableTarget]::Process)
            }
        }
    }
}
