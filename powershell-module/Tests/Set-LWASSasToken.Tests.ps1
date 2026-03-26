BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

AfterAll {
    [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_SET', [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
    Remove-ItemProperty -Path 'HKCU:\Environment' -Name 'LWAS_SAS_PESTER_SET' -ErrorAction SilentlyContinue
}

Describe 'Set-LWASSasToken' -Tag 'Unit' {

    BeforeEach {
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_SET', [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
        Remove-ItemProperty -Path 'HKCU:\Environment' -Name 'LWAS_SAS_PESTER_SET' -ErrorAction SilentlyContinue
    }

    AfterEach {
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_SET', [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
        Remove-ItemProperty -Path 'HKCU:\Environment' -Name 'LWAS_SAS_PESTER_SET' -ErrorAction SilentlyContinue
    }

    It 'Writes an error and returns when the variable name contains invalid characters' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-Error {}

            Set-LWASSasToken -Name 'LWAS SAS INVALID!' -Token 'some-token'

            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*invalid characters*' }
        }
    }

    It 'Does not set any environment variable when the name contains invalid characters' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-Error {}
        }

        Set-LWASSasToken -Name 'BAD NAME!' -Token 'some-token' -ErrorAction SilentlyContinue

        [Environment]::GetEnvironmentVariable('BAD NAME!', [System.EnvironmentVariableTarget]::Process) | Should -BeNull
    }

    It 'Sets the variable in the current Process scope' {
        Set-LWASSasToken -Name 'LWAS_SAS_PESTER_SET' -Token 'my-test-token'

        [Environment]::GetEnvironmentVariable('LWAS_SAS_PESTER_SET', [System.EnvironmentVariableTarget]::Process) |
            Should -Be 'my-test-token'
    }

    It 'Sets the variable in User scope so it persists across sessions' {
        Set-LWASSasToken -Name 'LWAS_SAS_PESTER_SET' -Token 'my-test-token'

        # Read from registry directly: GetEnvironmentVariable(User) may return stale entries in the current session
        (Get-Item -Path 'HKCU:\Environment').GetValue('LWAS_SAS_PESTER_SET') |
            Should -Be 'my-test-token'
    }

    It 'Accepts an empty string as a valid token value' {
        { Set-LWASSasToken -Name 'LWAS_SAS_PESTER_SET' -Token '' } | Should -Not -Throw

        [Environment]::GetEnvironmentVariable('LWAS_SAS_PESTER_SET', [System.EnvironmentVariableTarget]::Process) |
            Should -Be ''
    }

    It 'Overwrites an existing token value with the new value' {
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_SET', 'old-value', [System.EnvironmentVariableTarget]::Process)

        Set-LWASSasToken -Name 'LWAS_SAS_PESTER_SET' -Token 'new-value'

        [Environment]::GetEnvironmentVariable('LWAS_SAS_PESTER_SET', [System.EnvironmentVariableTarget]::Process) |
            Should -Be 'new-value'
    }

    It 'Writes verbose output after successful storage' {
        $output = Set-LWASSasToken -Name 'LWAS_SAS_PESTER_SET' -Token 'tok' -Verbose 4>&1
        $verboseMessages = @($output | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] })

        $verboseMessages | Where-Object { $_.Message -like '*LWAS_SAS_PESTER_SET*' } | Should -Not -BeNullOrEmpty
    }
}
