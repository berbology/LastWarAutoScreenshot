BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

AfterAll {
    [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_RM', [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
    [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_RM2', [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
}

Describe 'Remove-LWASSasToken' -Tag 'Unit' {

    BeforeEach {
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_RM', [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_RM2', [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
    }

    AfterEach {
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_RM', [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_RM2', [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
    }

    It 'Writes an error and continues when the variable name contains invalid characters' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-Error {}

            Remove-LWASSasToken -Name 'LWAS SAS INVALID!'

            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*invalid characters*' }
        }
    }

    It 'Does not throw when the variable name contains invalid characters' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-Error {}
            { Remove-LWASSasToken -Name 'BAD NAME!' } | Should -Not -Throw
        }
    }

    It 'Throws when the variable is not found in User or Process scope' {
        { Remove-LWASSasToken -Name 'LWAS_SAS_DEFINITELY_NOT_SET_PESTER_XYZ' } | Should -Throw "*not found*"
    }

    It 'Removes a variable that exists in Process scope' {
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_RM', 'test-token', [System.EnvironmentVariableTarget]::Process)

        Remove-LWASSasToken -Name 'LWAS_SAS_PESTER_RM'

        [Environment]::GetEnvironmentVariable('LWAS_SAS_PESTER_RM', [System.EnvironmentVariableTarget]::Process) |
            Should -BeNull
    }

    It 'Processes multiple names supplied as an array' {
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_RM',  'val1', [System.EnvironmentVariableTarget]::Process)
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_RM2', 'val2', [System.EnvironmentVariableTarget]::Process)

        try {
            Remove-LWASSasToken -Name 'LWAS_SAS_PESTER_RM', 'LWAS_SAS_PESTER_RM2'

            [Environment]::GetEnvironmentVariable('LWAS_SAS_PESTER_RM',  [System.EnvironmentVariableTarget]::Process) | Should -BeNull
            [Environment]::GetEnvironmentVariable('LWAS_SAS_PESTER_RM2', [System.EnvironmentVariableTarget]::Process) | Should -BeNull
        } finally {
            [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_RM2', [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
        }
    }

    It 'Pipeline: accepts objects with a Name property and removes each token' {
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_RM',  'val1', [System.EnvironmentVariableTarget]::Process)
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_RM2', 'val2', [System.EnvironmentVariableTarget]::Process)

        try {
            @(
                [PSCustomObject]@{ Name = 'LWAS_SAS_PESTER_RM'  }
                [PSCustomObject]@{ Name = 'LWAS_SAS_PESTER_RM2' }
            ) | Remove-LWASSasToken

            [Environment]::GetEnvironmentVariable('LWAS_SAS_PESTER_RM',  [System.EnvironmentVariableTarget]::Process) | Should -BeNull
            [Environment]::GetEnvironmentVariable('LWAS_SAS_PESTER_RM2', [System.EnvironmentVariableTarget]::Process) | Should -BeNull
        } finally {
            [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_RM2', [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
        }
    }

    It 'Writes verbose output after successful removal' {
        [Environment]::SetEnvironmentVariable('LWAS_SAS_PESTER_RM', 'test-token', [System.EnvironmentVariableTarget]::Process)

        $output = Remove-LWASSasToken -Name 'LWAS_SAS_PESTER_RM' -Verbose 4>&1
        $verboseMessages = @($output | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] })

        $verboseMessages | Where-Object { $_.Message -like '*LWAS_SAS_PESTER_RM*' } | Should -Not -BeNullOrEmpty
    }
}
