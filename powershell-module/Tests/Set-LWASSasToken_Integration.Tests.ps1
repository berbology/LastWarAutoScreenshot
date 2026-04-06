BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

AfterAll {
    [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_SET', [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
    Remove-ItemProperty -Path 'HKCU:\Environment' -Name 'LWAS_SAS_PESTER_SET' -ErrorAction SilentlyContinue
}

Describe 'Set-LWASSasToken' -Tag 'Integration' {

    BeforeEach {
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_SET', [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
        Remove-ItemProperty -Path 'HKCU:\Environment' -Name 'LWAS_SAS_PESTER_SET' -ErrorAction SilentlyContinue
    }

    AfterEach {
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_SET', [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
        Remove-ItemProperty -Path 'HKCU:\Environment' -Name 'LWAS_SAS_PESTER_SET' -ErrorAction SilentlyContinue
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

    It 'Overwrites an existing token value with the new value' {
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_SET', 'old-value', [System.EnvironmentVariableTarget]::Process)

        Set-LWASSasToken -Name 'LWAS_SAS_PESTER_SET' -Token 'new-value'

        [Environment]::GetEnvironmentVariable('LWAS_SAS_PESTER_SET', [System.EnvironmentVariableTarget]::Process) |
            Should -Be 'new-value'
    }
}
