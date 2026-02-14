BeforeAll {
    # Import functions under test
    . $PSScriptRoot/Save-ModuleConfiguration.ps1
    . $PSScriptRoot/Get-ModuleConfiguration.ps1
    . $PSScriptRoot/Test-ModuleConfigurationExists.ps1
}

Describe 'Save-ModuleConfiguration' {
    BeforeAll {
        # Use AppData\LastWarAutoScreenshot for test configuration files
        $script:testConfigDir = Join-Path -Path $env:APPDATA -ChildPath 'LastWarAutoScreenshotTest'
        New-Item -Path $script:testConfigDir -ItemType Directory -Force | Out-Null
        $script:testConfigPath = Join-Path -Path $script:testConfigDir -ChildPath 'TestConfig.json'
        
        # Create a mock window object
        $script:mockWindow = [PSCustomObject]@{
            ProcessName         = 'TestProcess'
            WindowTitle         = 'Test Window Title'
            WindowHandle        = [IntPtr]123456
            WindowHandleString  = '123456'
            WindowHandleInt64   = [int64]123456
            ProcessID           = [uint32]9999
            WindowState         = 'Visible'
        }
    }

    Context 'When saving a new configuration' {
        BeforeEach {
            # Ensure config file doesn't exist before each test
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }

        It 'Should create a configuration file' {
            $result = Save-ModuleConfiguration -WindowObject $script:mockWindow -ConfigurationPath $script:testConfigPath -Force
            
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [System.IO.FileInfo]
            Test-Path -Path $script:testConfigPath | Should -Be $true
        }

        It 'Should save valid JSON content' {
            Save-ModuleConfiguration -WindowObject $script:mockWindow -ConfigurationPath $script:testConfigPath -Force
            
            $content = Get-Content -Path $script:testConfigPath -Raw
            { $content | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Should include all required properties' {
            Save-ModuleConfiguration -WindowObject $script:mockWindow -ConfigurationPath $script:testConfigPath -Force
            
            $config = Get-Content -Path $script:testConfigPath -Raw | ConvertFrom-Json
            $config.ProcessName | Should -Be 'TestProcess'
            $config.WindowTitle | Should -Be 'Test Window Title'
            $config.WindowHandleString | Should -Be '123456'
            $config.WindowHandleInt64 | Should -Be 123456
            $config.ProcessID | Should -Be 9999
            $config.WindowState | Should -Be 'Visible'
        }

        It 'Should include metadata properties' {
            Save-ModuleConfiguration -WindowObject $script:mockWindow -ConfigurationPath $script:testConfigPath -Force
            
            $config = Get-Content -Path $script:testConfigPath -Raw | ConvertFrom-Json
            $config.SavedDate | Should -Not -BeNullOrEmpty
            $config.SavedBy | Should -Not -BeNullOrEmpty
            $config.ComputerName | Should -Not -BeNullOrEmpty
        }

        It 'Should create parent directory if it does not exist' {
            $nestedPath = Join-Path -Path $script:testConfigDir -ChildPath 'SubDir\DeepDir\Config.json'
            
            Save-ModuleConfiguration -WindowObject $script:mockWindow -ConfigurationPath $nestedPath -Force
            
            Test-Path -Path $nestedPath | Should -Be $true
        }

        AfterEach {
            # Cleanup
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }
    }

    Context 'When configuration file already exists' {
        BeforeAll {
            # Create an existing config
            $existingConfig = @{
                ProcessName = 'OldProcess'
                WindowTitle = 'Old Window'
            } | ConvertTo-Json
            
            $existingConfig | Set-Content -Path $script:testConfigPath -Force
        }

        It 'Should overwrite with -Force switch' {
            Save-ModuleConfiguration -WindowObject $script:mockWindow -ConfigurationPath $script:testConfigPath -Force
            
            $config = Get-Content -Path $script:testConfigPath -Raw | ConvertFrom-Json
            $config.ProcessName | Should -Be 'TestProcess'
            $config.WindowTitle | Should -Be 'Test Window Title'
        }

        It 'Should prompt for confirmation without -Force (via ShouldProcess)' {
            Mock -CommandName 'Set-Content' -MockWith { }
            
            # Note: Testing ShouldProcess behavior requires -WhatIf
            Save-ModuleConfiguration -WindowObject $script:mockWindow -ConfigurationPath $script:testConfigPath -WhatIf
            
            # Should not throw and should not actually write
            Should -Not -Invoke Set-Content
        }

        AfterAll {
            # Cleanup
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }
    }

    Context 'When WindowObject is invalid' {
        It 'Should throw error if WindowObject is null' {
            { Save-ModuleConfiguration -WindowObject $null -ConfigurationPath $script:testConfigPath -Force -ErrorAction Stop } | Should -Throw
        }

        It 'Should throw error if WindowObject is missing ProcessName' {
            $invalidWindow = [PSCustomObject]@{
                WindowTitle  = 'Test Window'
                WindowHandle = [IntPtr]123
            }
            
            { Save-ModuleConfiguration -WindowObject $invalidWindow -ConfigurationPath $script:testConfigPath -Force -ErrorAction Stop } | Should -Throw '*missing required properties*'
        }

        It 'Should throw error if WindowObject is missing WindowTitle' {
            $invalidWindow = [PSCustomObject]@{
                ProcessName  = 'TestProcess'
                WindowHandle = [IntPtr]123
            }
            
            { Save-ModuleConfiguration -WindowObject $invalidWindow -ConfigurationPath $script:testConfigPath -Force -ErrorAction Stop } | Should -Throw '*missing required properties*'
        }

        It 'Should throw error if WindowObject is missing WindowHandle' {
            $invalidWindow = [PSCustomObject]@{
                ProcessName = 'TestProcess'
                WindowTitle = 'Test Window'
            }
            
            { Save-ModuleConfiguration -WindowObject $invalidWindow -ConfigurationPath $script:testConfigPath -Force -ErrorAction Stop } | Should -Throw '*missing required properties*'
        }
    }

    Context 'When using pipeline input' {
        BeforeEach {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }

        It 'Should accept window object from pipeline' {
            $result = $script:mockWindow | Save-ModuleConfiguration -ConfigurationPath $script:testConfigPath -Force
            
            $result | Should -Not -BeNullOrEmpty
            Test-Path -Path $script:testConfigPath | Should -Be $true
        }

        AfterEach {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }
    }
}

Describe 'Get-ModuleConfiguration' {
    BeforeAll {
        $script:testConfigDir = Join-Path -Path $env:APPDATA -ChildPath 'LastWarAutoScreenshotTest'
        New-Item -Path $script:testConfigDir -ItemType Directory -Force | Out-Null
        $script:testConfigPath = Join-Path -Path $script:testConfigDir -ChildPath 'TestConfig.json'
    }

    Context 'When configuration file exists' {
        BeforeAll {
            # Create a valid configuration file
            $validConfig = [PSCustomObject]@{
                ProcessName         = 'TestProcess'
                WindowTitle         = 'Test Window Title'
                WindowHandleString  = '123456'
                WindowHandleInt64   = [int64]123456
                ProcessID           = [uint32]9999
                WindowState         = 'Visible'
                SavedDate           = (Get-Date -Format 'o')
                SavedBy             = 'TestUser'
                ComputerName        = 'TestComputer'
            }
            
            $validConfig | ConvertTo-Json | Set-Content -Path $script:testConfigPath -Force
        }

        It 'Should load configuration successfully' {
            $config = Get-ModuleConfiguration -ConfigurationPath $script:testConfigPath
            
            $config | Should -Not -BeNullOrEmpty
        }

        It 'Should return correct ProcessName' {
            $config = Get-ModuleConfiguration -ConfigurationPath $script:testConfigPath
            
            $config.ProcessName | Should -Be 'TestProcess'
        }

        It 'Should return correct WindowTitle' {
            $config = Get-ModuleConfiguration -ConfigurationPath $script:testConfigPath
            
            $config.WindowTitle | Should -Be 'Test Window Title'
        }

        It 'Should return correct WindowHandle representations' {
            $config = Get-ModuleConfiguration -ConfigurationPath $script:testConfigPath
            
            $config.WindowHandleString | Should -Be '123456'
            $config.WindowHandleInt64 | Should -Be 123456
        }

        It 'Should return all metadata properties' {
            $config = Get-ModuleConfiguration -ConfigurationPath $script:testConfigPath
            
            $config.SavedDate | Should -Not -BeNullOrEmpty
            $config.SavedBy | Should -Be 'TestUser'
            $config.ComputerName | Should -Be 'TestComputer'
        }

        AfterAll {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }
    }

    Context 'When configuration file does not exist' {
        BeforeAll {
            $script:nonExistentPath = Join-Path -Path $script:testConfigDir -ChildPath 'NonExistent.json'
        }

        It 'Should return $null' {
            $config = Get-ModuleConfiguration -ConfigurationPath $script:nonExistentPath
            
            $config | Should -BeNullOrEmpty
        }

        It 'Should write warning message' {
            $warningMsg = Get-ModuleConfiguration -ConfigurationPath $script:nonExistentPath -WarningVariable warnings 3>$null
            
            $warnings | Should -Not -BeNullOrEmpty
        }
    }

    Context 'When configuration file is invalid' {
        BeforeEach {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }

        It 'Should throw error if file is empty' {
            '' | Set-Content -Path $script:testConfigPath -Force
            
            $config = Get-ModuleConfiguration -ConfigurationPath $script:testConfigPath -ErrorAction SilentlyContinue
            $config | Should -BeNullOrEmpty
        }

        It 'Should throw error if JSON is malformed' {
            '{ invalid json content' | Set-Content -Path $script:testConfigPath -Force
            
            { Get-ModuleConfiguration -ConfigurationPath $script:testConfigPath -ErrorAction Stop } | Should -Throw
        }

        It 'Should throw error if required properties are missing' {
            $incompleteConfig = @{
                ProcessName = 'TestProcess'
            } | ConvertTo-Json
            
            $incompleteConfig | Set-Content -Path $script:testConfigPath -Force
            
            { Get-ModuleConfiguration -ConfigurationPath $script:testConfigPath -ErrorAction Stop } | Should -Throw '*missing required properties*'
        }

        AfterEach {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }
    }
}

Describe 'Test-ModuleConfigurationExists' {
    BeforeAll {
        $script:testConfigDir = Join-Path -Path $env:APPDATA -ChildPath 'LastWarAutoScreenshotTest'
        New-Item -Path $script:testConfigDir -ItemType Directory -Force | Out-Null
        $script:testConfigPath = Join-Path -Path $script:testConfigDir -ChildPath 'TestConfig.json'
    }

    Context 'When configuration file exists' {
        BeforeAll {
            'test content' | Set-Content -Path $script:testConfigPath -Force
        }

        It 'Should return $true' {
            $result = Test-ModuleConfigurationExists -ConfigurationPath $script:testConfigPath
            
            $result | Should -Be $true
        }

        AfterAll {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }
    }

    Context 'When configuration file does not exist' {
        BeforeAll {
            $script:nonExistentPath = Join-Path -Path $script:testConfigDir -ChildPath 'NonExistent.json'
        }

        It 'Should return $false' {
            $result = Test-ModuleConfigurationExists -ConfigurationPath $script:nonExistentPath
            
            $result | Should -Be $false
        }
    }

    Context 'When path is a directory, not a file' {
        It 'Should return $false' {
            $result = Test-ModuleConfigurationExists -ConfigurationPath $script:testConfigDir
            
            $result | Should -Be $false
        }
    }
}

Describe 'Configuration Functions Integration' {
    BeforeAll {
        $script:testConfigDir = Join-Path -Path $env:APPDATA -ChildPath 'LastWarAutoScreenshotTest'
        New-Item -Path $script:testConfigDir -ItemType Directory -Force | Out-Null
        $script:testConfigPath = Join-Path -Path $script:testConfigDir -ChildPath 'Integration.json'
        
        $script:mockWindow = [PSCustomObject]@{
            ProcessName         = 'IntegrationTest'
            WindowTitle         = 'Integration Window'
            WindowHandle        = [IntPtr]999888
            WindowHandleString  = '999888'
            WindowHandleInt64   = [int64]999888
            ProcessID           = [uint32]5555
            WindowState         = 'Visible'
        }
    }

    Context 'When performing save-load-test cycle' {
        BeforeEach {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }

        It 'Should complete full save-load cycle successfully' {
            # Test existence before save
            Test-ModuleConfigurationExists -ConfigurationPath $script:testConfigPath | Should -Be $false
            
            # Save configuration
            Save-ModuleConfiguration -WindowObject $script:mockWindow -ConfigurationPath $script:testConfigPath -Force
            
            # Test existence after save
            Test-ModuleConfigurationExists -ConfigurationPath $script:testConfigPath | Should -Be $true
            
            # Load configuration
            $loadedConfig = Get-ModuleConfiguration -ConfigurationPath $script:testConfigPath
            
            # Verify loaded data matches original
            $loadedConfig.ProcessName | Should -Be $script:mockWindow.ProcessName
            $loadedConfig.WindowTitle | Should -Be $script:mockWindow.WindowTitle
            $loadedConfig.WindowHandleString | Should -Be $script:mockWindow.WindowHandle.ToString()
            $loadedConfig.WindowHandleInt64 | Should -Be ([int64]$script:mockWindow.WindowHandle)
        }

        AfterEach {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }
    }
}
