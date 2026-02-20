BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'Save-ModuleConfiguration' {
    BeforeAll {
        # Use AppData\LastWarAutoScreenshot for test configuration files
        $script:testConfigDir = Join-Path -Path $env:APPDATA -ChildPath 'LastWarAutoScreenshotTest'
        New-Item -Path $script:testConfigDir -ItemType Directory -Force | Out-Null
        $script:testConfigPath = Join-Path -Path $script:testConfigDir -ChildPath 'TestConfig.json'

        # Suppress Write-Host calls made from inside the module (e.g. the 'saved to:' success message).
        # Must be inside InModuleScope so Pester intercepts the command in the module's session state,
        # not just in the test script's session state.
        InModuleScope LastWarAutoScreenshot {
            Mock Write-Host {}
        }

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
            InModuleScope LastWarAutoScreenshot -Parameters @{ mockWindow = $script:mockWindow; testConfigPath = $script:testConfigPath } {
                $result = Save-ModuleConfiguration -WindowObject $mockWindow -ConfigurationPath $testConfigPath -Force
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.IO.FileInfo]
                Test-Path -Path $testConfigPath | Should -Be $true
            }
        }

        It 'Should save valid JSON content' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ mockWindow = $script:mockWindow; testConfigPath = $script:testConfigPath } {
                Save-ModuleConfiguration -WindowObject $mockWindow -ConfigurationPath $testConfigPath -Force
                $content = Get-Content -Path $testConfigPath -Raw
                { $content | ConvertFrom-Json } | Should -Not -Throw
            }
        }

        It 'Should include all required properties' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ mockWindow = $script:mockWindow; testConfigPath = $script:testConfigPath } {
                Save-ModuleConfiguration -WindowObject $mockWindow -ConfigurationPath $testConfigPath -Force
                $config = Get-Content -Path $testConfigPath -Raw | ConvertFrom-Json
                $config.ProcessName | Should -Be 'TestProcess'
                $config.WindowTitle | Should -Be 'Test Window Title'
                $config.WindowHandleString | Should -Be '123456'
                $config.WindowHandleInt64 | Should -Be 123456
                $config.ProcessID | Should -Be 9999
                $config.WindowState | Should -Be 'Visible'
            }
        }

        It 'Should include metadata properties' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ mockWindow = $script:mockWindow; testConfigPath = $script:testConfigPath } {
                Save-ModuleConfiguration -WindowObject $mockWindow -ConfigurationPath $testConfigPath -Force
                $config = Get-Content -Path $testConfigPath -Raw | ConvertFrom-Json
                $config.SavedDate | Should -Not -BeNullOrEmpty
                $config.SavedBy | Should -Not -BeNullOrEmpty
                $config.ComputerName | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should create parent directory if it does not exist' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigDir = $script:testConfigDir; mockWindow = $script:mockWindow } {
                $nestedPath = Join-Path -Path $testConfigDir -ChildPath 'SubDir\DeepDir\Config.json'
                Save-ModuleConfiguration -WindowObject $mockWindow -ConfigurationPath $nestedPath -Force
                Test-Path -Path $nestedPath | Should -Be $true
            }
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
            InModuleScope LastWarAutoScreenshot -Parameters @{ mockWindow = $script:mockWindow; testConfigPath = $script:testConfigPath } {
                Save-ModuleConfiguration -WindowObject $mockWindow -ConfigurationPath $testConfigPath -Force
                $config = Get-Content -Path $testConfigPath -Raw | ConvertFrom-Json
                $config.ProcessName | Should -Be 'TestProcess'
                $config.WindowTitle | Should -Be 'Test Window Title'
            }
        }

        It 'Should declare SupportsShouldProcess (exposes -WhatIf and -Confirm)' {
            # Verifies [CmdletBinding(SupportsShouldProcess = $true)] is declared on the function.
            # Using -WhatIf directly is avoided here: $PSCmdlet.ShouldProcess() writes its
            # 'What if:' message via $Host.UI.WriteLine(), which bypasses all PS stream
            # redirection and cannot be suppressed in a test.
            InModuleScope LastWarAutoScreenshot {
                $cmd = Get-Command -Name Save-ModuleConfiguration
                $cmd.Parameters.ContainsKey('WhatIf')   | Should -Be $true
                $cmd.Parameters.ContainsKey('Confirm')  | Should -Be $true
            }
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
            InModuleScope LastWarAutoScreenshot {
                { Save-ModuleConfiguration -WindowObject $null -ConfigurationPath $script:testConfigPath -Force -ErrorAction Stop } | Should -Throw
            }
        }

        It 'Should throw error if WindowObject is missing ProcessName' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $invalidWindow = [PSCustomObject]@{
                    WindowTitle  = 'Test Window'
                    WindowHandle = [IntPtr]123
                }
                { Save-ModuleConfiguration -WindowObject $invalidWindow -ConfigurationPath $testConfigPath -Force -ErrorAction Stop } | Should -Throw '*missing required properties*'
            }
        }

        It 'Should throw error if WindowObject is missing WindowTitle' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $invalidWindow = [PSCustomObject]@{
                    ProcessName  = 'TestProcess'
                    WindowHandle = [IntPtr]123
                }
                { Save-ModuleConfiguration -WindowObject $invalidWindow -ConfigurationPath $testConfigPath -Force -ErrorAction Stop } | Should -Throw '*missing required properties*'
            }
        }

        It 'Should throw error if WindowObject is missing WindowHandle' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $invalidWindow = [PSCustomObject]@{
                    ProcessName = 'TestProcess'
                    WindowTitle = 'Test Window'
                }
                { Save-ModuleConfiguration -WindowObject $invalidWindow -ConfigurationPath $testConfigPath -Force -ErrorAction Stop } | Should -Throw '*missing required properties*'
            }
        }
    }

    Context 'When using pipeline input' {
        BeforeEach {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }

        It 'Should accept window object from pipeline' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ mockWindow = $script:mockWindow; testConfigPath = $script:testConfigPath } {
                $result = $mockWindow | Save-ModuleConfiguration -ConfigurationPath $testConfigPath -Force
                $result | Should -Not -BeNullOrEmpty
                Test-Path -Path $testConfigPath | Should -Be $true
            }
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
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should return correct ProcessName' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.ProcessName | Should -Be 'TestProcess'
            }
        }

        It 'Should return correct WindowTitle' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.WindowTitle | Should -Be 'Test Window Title'
            }
        }

        It 'Should return correct WindowHandle representations' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.WindowHandleString | Should -Be '123456'
                $config.WindowHandleInt64 | Should -Be 123456
            }
        }

        It 'Should return all metadata properties' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.SavedDate | Should -Not -BeNullOrEmpty
                $config.SavedBy | Should -Be 'TestUser'
                $config.ComputerName | Should -Be 'TestComputer'
            }
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
            InModuleScope LastWarAutoScreenshot -Parameters @{ nonExistentPath = $script:nonExistentPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $nonExistentPath
                $config | Should -BeNullOrEmpty
            }
        }

        It 'Should write warning message' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ nonExistentPath = $script:nonExistentPath } {
                $warningMsg = Get-ModuleConfiguration -ConfigurationPath $nonExistentPath -WarningVariable warnings 3>$null
                $warnings | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'When configuration file is invalid' {
        BeforeEach {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }

        It 'Should return null when file is empty' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                '' | Set-Content -Path $testConfigPath -Force
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath -ErrorAction SilentlyContinue
                $config | Should -BeNullOrEmpty
            }
        }

        It 'Should throw error if JSON is malformed' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                '{ invalid json content' | Set-Content -Path $testConfigPath -Force
                { Get-ModuleConfiguration -ConfigurationPath $testConfigPath -ErrorAction Stop } | Should -Throw
            }
        }

        It 'Should throw error if required properties are missing' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $incompleteConfig = @{
                    ProcessName = 'TestProcess'
                } | ConvertTo-Json
                $incompleteConfig | Set-Content -Path $testConfigPath -Force
                { Get-ModuleConfiguration -ConfigurationPath $testConfigPath -ErrorAction Stop } | Should -Throw '*missing required properties*'
            }
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
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $result = Test-ModuleConfigurationExists -ConfigurationPath $testConfigPath
                $result | Should -Be $true
            }
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
            InModuleScope LastWarAutoScreenshot -Parameters @{ nonExistentPath = $script:nonExistentPath } {
                $result = Test-ModuleConfigurationExists -ConfigurationPath $nonExistentPath
                $result | Should -Be $false
            }
        }
    }

    Context 'When path is a directory, not a file' {
        It 'Should return $false' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigDir = $script:testConfigDir } {
                $result = Test-ModuleConfigurationExists -ConfigurationPath $testConfigDir
                $result | Should -Be $false
            }
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
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath; mockWindow = $script:mockWindow } {
                # Test existence before save
                Test-ModuleConfigurationExists -ConfigurationPath $testConfigPath | Should -Be $false
                # Save configuration
                Save-ModuleConfiguration -WindowObject $mockWindow -ConfigurationPath $testConfigPath -Force
                # Test existence after save
                Test-ModuleConfigurationExists -ConfigurationPath $testConfigPath | Should -Be $true
                # Load configuration
                $loadedConfig = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                # Verify loaded data matches original
                $loadedConfig.ProcessName | Should -Be $mockWindow.ProcessName
                $loadedConfig.WindowTitle | Should -Be $mockWindow.WindowTitle
                $loadedConfig.WindowHandleString | Should -Be $mockWindow.WindowHandle.ToString()
                $loadedConfig.WindowHandleInt64 | Should -Be ([int64]$mockWindow.WindowHandle)
            }
        }

        AfterEach {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }
    }
}
