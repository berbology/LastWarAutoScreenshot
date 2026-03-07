

BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'Get-LoggingBackendConfig' -Tag 'Unit' {
    It 'Returns File and EventLog when both are set' {
        $tmp = New-TemporaryFile
        Set-Content $tmp.FullName '{"Logging":{"Backend":"File,EventLog"}}' -Encoding UTF8
        InModuleScope LastWarAutoScreenshot -Parameters @{ ConfigPath = $tmp.FullName } {
            $result = Get-LoggingBackendConfig -ConfigPath $ConfigPath
            $result | Should -Contain 'File'
            $result | Should -Contain 'EventLog'
        }
        Remove-Item $tmp.FullName -Force
    }
    It 'Defaults to File if config missing' {
        $tmp = New-TemporaryFile
        Remove-Item $tmp.FullName -Force
        InModuleScope LastWarAutoScreenshot -Parameters @{ ConfigPath = $tmp.FullName } {
            $result = Get-LoggingBackendConfig -ConfigPath $ConfigPath
            $result | Should -Be @('File')
        }
    }
    It 'Handles trailing comma in Logging.Backend' {
        $tmp = New-TemporaryFile
        Set-Content $tmp.FullName '{"Logging":{"Backend":"File,"}}' -Encoding UTF8
        InModuleScope LastWarAutoScreenshot -Parameters @{ ConfigPath = $tmp.FullName } {
            $result = Get-LoggingBackendConfig -ConfigPath $ConfigPath
            $result | Should -Be @('File')
        }
        Remove-Item $tmp.FullName -Force
    }
    It 'Handles trailing space in Logging.Backend' {
        $tmp = New-TemporaryFile
        Set-Content $tmp.FullName '{"Logging":{"Backend":"File, "}}' -Encoding UTF8
        InModuleScope LastWarAutoScreenshot -Parameters @{ ConfigPath = $tmp.FullName } {
            $result = Get-LoggingBackendConfig -ConfigPath $ConfigPath
            $result | Should -Be @('File')
        }
        Remove-Item $tmp.FullName -Force
    }
    It 'Returns File default when Logging.Backend is null' {
        $tmp = New-TemporaryFile
        Set-Content $tmp.FullName '{"Logging":{"Backend":null}}' -Encoding UTF8
        InModuleScope LastWarAutoScreenshot -Parameters @{ ConfigPath = $tmp.FullName } {
            $result = Get-LoggingBackendConfig -ConfigPath $ConfigPath
            $result | Should -Be @('File')
        }
        Remove-Item $tmp.FullName -Force
    }
}

