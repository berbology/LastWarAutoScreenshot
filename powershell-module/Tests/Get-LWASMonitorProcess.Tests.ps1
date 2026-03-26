BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Get-LWASMonitorProcess' -Tag 'Unit' {

    It 'Returns a Process object for the current process ID' {
        $result = Get-LWASMonitorProcess -ProcessId $PID

        $result | Should -Not -BeNull
        $result | Should -BeOfType [System.Diagnostics.Process]
    }

    It 'Returns $null when the process ID does not exist' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}

            $result = Get-LWASMonitorProcess -ProcessId $([int]::MaxValue)

            $result | Should -BeNull
        }
    }

    It 'Logs a Warning when the process ID does not exist' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}

            Get-LWASMonitorProcess -ProcessId $([int]::MaxValue)

            Should -Invoke Write-LastWarLog -Times 1 -ParameterFilter { $Level -eq 'Warning' }
        }
    }

    It 'Does not throw when the process ID does not exist' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}

            { Get-LWASMonitorProcess -ProcessId $([int]::MaxValue) } | Should -Not -Throw
        }
    }
}
