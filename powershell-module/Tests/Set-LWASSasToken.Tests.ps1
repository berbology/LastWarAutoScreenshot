BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Set-LWASSasToken' -Tag 'Unit' {

    It 'Writes an error and returns when the variable name contains invalid characters' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-Error {}
            Mock Set-EnvironmentVariable {}

            Set-LWASSasToken -Name 'LWAS SAS INVALID!' -Token 'some-token'

            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*invalid characters*' }
        }
    }

    It 'Does not set any environment variable when the name contains invalid characters' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-Error {}
            Mock Set-EnvironmentVariable {}

            Set-LWASSasToken -Name 'BAD NAME!' -Token 'some-token' -ErrorAction SilentlyContinue

            Should -Invoke Set-EnvironmentVariable -Times 0
        }
    }

    It 'Sets the variable in both Process and User scopes' {
        InModuleScope LastWarAutoScreenshot {
            Mock Set-EnvironmentVariable {}

            Set-LWASSasToken -Name 'LWAS_TEST_VAR' -Token 'my-test-token'

            Should -Invoke Set-EnvironmentVariable -Times 2 -ParameterFilter {
                $Name -eq 'LWAS_TEST_VAR' -and $Value -eq 'my-test-token'
            }
        }
    }

    It 'Accepts an empty string as a valid token value' {
        InModuleScope LastWarAutoScreenshot {
            Mock Set-EnvironmentVariable {}

            { Set-LWASSasToken -Name 'LWAS_TEST_VAR' -Token '' } | Should -Not -Throw

            Should -Invoke Set-EnvironmentVariable -Times 2 -ParameterFilter {
                $Name -eq 'LWAS_TEST_VAR' -and $Value -eq ''
            }
        }
    }

    It 'Writes verbose output after successful storage' {
        InModuleScope LastWarAutoScreenshot {
            Mock Set-EnvironmentVariable {}

            $output = Set-LWASSasToken -Name 'LWAS_TEST_VAR' -Token 'tok' -Verbose 4>&1
            $verboseMessages = @($output | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] })

            $verboseMessages | Where-Object { $_.Message -like '*LWAS_TEST_VAR*' } | Should -Not -BeNullOrEmpty
        }
    }
}
