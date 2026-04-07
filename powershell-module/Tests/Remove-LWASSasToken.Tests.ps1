BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Remove-LWASSasToken' -Tag 'Unit' {

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
        $varName = "LWAS_RM_PESTER_$([System.Guid]::NewGuid().ToString('N').Substring(0, 8))"
        [Environment]::SetEnvironmentVariable($varName, 'test-token', [System.EnvironmentVariableTarget]::Process)

        try {
            Remove-LWASSasToken -Name $varName

            [Environment]::GetEnvironmentVariable($varName, [System.EnvironmentVariableTarget]::Process) |
                Should -BeNull
        } finally {
            [Environment]::SetEnvironmentVariable($varName, [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
        }
    }

    It 'Processes multiple names supplied as an array' {
        $suffix = [System.Guid]::NewGuid().ToString('N').Substring(0, 8)
        $var1 = "LWAS_RM_PESTER_1_$suffix"
        $var2 = "LWAS_RM_PESTER_2_$suffix"

        [Environment]::SetEnvironmentVariable($var1, 'val1', [System.EnvironmentVariableTarget]::Process)
        [Environment]::SetEnvironmentVariable($var2, 'val2', [System.EnvironmentVariableTarget]::Process)

        try {
            Remove-LWASSasToken -Name $var1, $var2

            [Environment]::GetEnvironmentVariable($var1, [System.EnvironmentVariableTarget]::Process) | Should -BeNull
            [Environment]::GetEnvironmentVariable($var2, [System.EnvironmentVariableTarget]::Process) | Should -BeNull
        } finally {
            [Environment]::SetEnvironmentVariable($var1, [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
            [Environment]::SetEnvironmentVariable($var2, [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
        }
    }

    It 'Pipeline: accepts objects with a Name property and removes each token' {
        $suffix = [System.Guid]::NewGuid().ToString('N').Substring(0, 8)
        $var1 = "LWAS_RM_PESTER_1_$suffix"
        $var2 = "LWAS_RM_PESTER_2_$suffix"

        [Environment]::SetEnvironmentVariable($var1, 'val1', [System.EnvironmentVariableTarget]::Process)
        [Environment]::SetEnvironmentVariable($var2, 'val2', [System.EnvironmentVariableTarget]::Process)

        try {
            @(
                [PSCustomObject]@{ Name = $var1 }
                [PSCustomObject]@{ Name = $var2 }
            ) | Remove-LWASSasToken

            [Environment]::GetEnvironmentVariable($var1, [System.EnvironmentVariableTarget]::Process) | Should -BeNull
            [Environment]::GetEnvironmentVariable($var2, [System.EnvironmentVariableTarget]::Process) | Should -BeNull
        } finally {
            [Environment]::SetEnvironmentVariable($var1, [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
            [Environment]::SetEnvironmentVariable($var2, [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
        }
    }

    It 'Writes verbose output after successful removal' {
        $varName = "LWAS_RM_PESTER_$([System.Guid]::NewGuid().ToString('N').Substring(0, 8))"
        [Environment]::SetEnvironmentVariable($varName, 'test-token', [System.EnvironmentVariableTarget]::Process)

        try {
            $output = Remove-LWASSasToken -Name $varName -Verbose 4>&1
            $verboseMessages = @($output | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] })

            $verboseMessages | Where-Object { $_.Message -like "*$varName*" } | Should -Not -BeNullOrEmpty
        } finally {
            [Environment]::SetEnvironmentVariable($varName, [NullString]::Value, [System.EnvironmentVariableTarget]::Process)
        }
    }
}
