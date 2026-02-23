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
            # Create an existing config with custom settings
            $existingConfig = @{
                ProcessName = 'OldProcess'
                WindowTitle = 'Old Window'
                WindowHandleString = '123456'
                WindowHandleInt64 = 123456
                ProcessID = 9999
                WindowState = 'Visible'
                SavedDate = (Get-Date -Format 'o')
                SavedBy = 'OldUser'
                ComputerName = 'OldComputer'
                MouseControl = @{
                    EasingEnabled = $false
                    OvershootEnabled = $false
                    OvershootFactor = 0.5
                    MicroPausesEnabled = $false
                    MicroPauseChance = 0.5
                    MicroPauseDurationRangeMs = @(100, 200)
                    JitterEnabled = $false
                    JitterRadiusPx = 5
                    BezierControlPointOffsetFactor = 0.5
                    MovementDurationRangeMs = @(1000, 2000)
                    ClickDownDurationRangeMs = @(100, 200)
                    ClickPreDelayRangeMs = @(100, 300)
                    ClickPostDelayRangeMs = @(200, 400)
                    PathPointCount = 50
                }
                EmergencyStop = @{
                    AutoStart = $false
                    HotkeyVKeyCodes = @(18, 17, 13)
                    PollIntervalMs = 200
                }
                Logging = @{
                    Backend = 'EventLog'
                    MinimumLogLevel = 'Warning'
                    FileBackend = @{
                        MaxSizeMB = 100
                        MaxFileCount = 100
                        MaxAgeDays = 60
                        RetentionFileCount = 1000
                    }
                }
            } | ConvertTo-Json -Depth 5
            
            $existingConfig | Set-Content -Path $script:testConfigPath -Force
        }

        It 'Should overwrite with -Force switch' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ mockWindow = $script:mockWindow; testConfigPath = $script:testConfigPath } {
                Mock Write-Host {}
                Save-ModuleConfiguration -WindowObject $mockWindow -ConfigurationPath $testConfigPath -Force
                $config = Get-Content -Path $testConfigPath -Raw | ConvertFrom-Json
                $config.ProcessName | Should -Be 'TestProcess'
                $config.WindowTitle | Should -Be 'Test Window Title'
            }
        }

        It 'Should preserve existing MouseControl settings when saving new window target' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ mockWindow = $script:mockWindow; testConfigPath = $script:testConfigPath } {
                Mock Write-Host {}
                Save-ModuleConfiguration -WindowObject $mockWindow -ConfigurationPath $testConfigPath -Force
                $config = Get-Content -Path $testConfigPath -Raw | ConvertFrom-Json
                
                # Custom MouseControl settings should be preserved
                $config.MouseControl.EasingEnabled | Should -Be $false
                $config.MouseControl.OvershootEnabled | Should -Be $false
                $config.MouseControl.OvershootFactor | Should -Be 0.5
                $config.MouseControl.MicroPausesEnabled | Should -Be $false
                $config.MouseControl.MicroPauseChance | Should -Be 0.5
                $config.MouseControl.MicroPauseDurationRangeMs | Should -Be @(100, 200)
                $config.MouseControl.JitterEnabled | Should -Be $false
                $config.MouseControl.JitterRadiusPx | Should -Be 5
                $config.MouseControl.BezierControlPointOffsetFactor | Should -Be 0.5
                $config.MouseControl.MovementDurationRangeMs | Should -Be @(1000, 2000)
                $config.MouseControl.ClickDownDurationRangeMs | Should -Be @(100, 200)
                $config.MouseControl.ClickPreDelayRangeMs | Should -Be @(100, 300)
                $config.MouseControl.ClickPostDelayRangeMs | Should -Be @(200, 400)
                $config.MouseControl.PathPointCount | Should -Be 50
            }
        }

        It 'Should preserve existing EmergencyStop settings when saving new window target' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ mockWindow = $script:mockWindow; testConfigPath = $script:testConfigPath } {
                Mock Write-Host {}
                Save-ModuleConfiguration -WindowObject $mockWindow -ConfigurationPath $testConfigPath -Force
                $config = Get-Content -Path $testConfigPath -Raw | ConvertFrom-Json
                
                # Custom EmergencyStop settings should be preserved
                $config.EmergencyStop.AutoStart | Should -Be $false
                $config.EmergencyStop.HotkeyVKeyCodes | Should -Be @(18, 17, 13)
                $config.EmergencyStop.PollIntervalMs | Should -Be 200
            }
        }

        It 'Should preserve existing Logging settings when saving new window target' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ mockWindow = $script:mockWindow; testConfigPath = $script:testConfigPath } {
                Mock Write-Host {}
                Save-ModuleConfiguration -WindowObject $mockWindow -ConfigurationPath $testConfigPath -Force
                $config = Get-Content -Path $testConfigPath -Raw | ConvertFrom-Json
                
                # Custom Logging settings should be preserved
                $config.Logging.Backend | Should -Be 'EventLog'
                $config.Logging.MinimumLogLevel | Should -Be 'Warning'
                $config.Logging.FileBackend.MaxSizeMB | Should -Be 100
                $config.Logging.FileBackend.MaxFileCount | Should -Be 100
                $config.Logging.FileBackend.MaxAgeDays | Should -Be 60
                $config.Logging.FileBackend.RetentionFileCount | Should -Be 1000
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

        BeforeEach {
            # Guarantee the file is absent before every test so each test exercises the create-defaults path.
            if (Test-Path -Path $script:nonExistentPath) {
                Remove-Item -Path $script:nonExistentPath -Force
            }
        }

        AfterEach {
            # Clean up any file that Get-ModuleConfiguration created during the test.
            if (Test-Path -Path $script:nonExistentPath) {
                Remove-Item -Path $script:nonExistentPath -Force
            }
        }

        It 'Should return a non-null config with EmergencyStop defaults' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ nonExistentPath = $script:nonExistentPath } {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                $config = Get-ModuleConfiguration -ConfigurationPath $nonExistentPath
                $config | Should -Not -BeNullOrEmpty
                $config.EmergencyStop | Should -Not -BeNullOrEmpty
                $config.EmergencyStop.PollIntervalMs | Should -Be 100
            }
        }

        It 'Should return a config with MouseControl defaults' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ nonExistentPath = $script:nonExistentPath } {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                $config = Get-ModuleConfiguration -ConfigurationPath $nonExistentPath
                $config.MouseControl | Should -Not -BeNullOrEmpty
                $config.MouseControl.EasingEnabled | Should -Be $true
                $config.MouseControl.PathPointCount | Should -Be 20
            }
        }

        It 'Should create the config file on disk' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ nonExistentPath = $script:nonExistentPath } {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                Get-ModuleConfiguration -ConfigurationPath $nonExistentPath | Out-Null
                Test-Path -Path $nonExistentPath | Should -Be $true
            }
        }

        It 'Should log an Info entry when creating the default config' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ nonExistentPath = $script:nonExistentPath } {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                Get-ModuleConfiguration -ConfigurationPath $nonExistentPath | Out-Null
                Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Info' } -Times 1
            }
        }
    }

    Context 'When configuration file is empty' {
        BeforeEach {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }

        It 'Should return default config and recreate file' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                '' | Set-Content -Path $testConfigPath -Force
                
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                
                $config | Should -Not -BeNullOrEmpty
                $config.Logging | Should -Not -BeNullOrEmpty
                $config.MouseControl | Should -Not -BeNullOrEmpty
                $config.EmergencyStop | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should recreate empty config file with defaults' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                '' | Set-Content -Path $testConfigPath -Force
                
                Get-ModuleConfiguration -ConfigurationPath $testConfigPath | Out-Null
                
                # Verify file was recreated (has content)
                $fileContent = Get-Content -Path $testConfigPath -Raw
                $fileContent | Should -Not -BeNullOrEmpty
                # Verify it's valid JSON
                { $fileContent | ConvertFrom-Json } | Should -Not -Throw
            }
        }

        It 'Should log Info entry when recreating empty config file' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                '' | Set-Content -Path $testConfigPath -Force
                
                Get-ModuleConfiguration -ConfigurationPath $testConfigPath | Out-Null
                
                Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Info' } -Times 1
            }
        }

        It 'Should return EmergencyStop defaults when file is empty' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                '' | Set-Content -Path $testConfigPath -Force
                
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                
                $config.EmergencyStop.AutoStart | Should -Be $true
                $config.EmergencyStop.HotkeyVKeyCodes | Should -Be @(17, 16, 220)
                $config.EmergencyStop.PollIntervalMs | Should -Be 100
            }
        }

        It 'Should return MouseGestureEnabled default $true when file is empty' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                '' | Set-Content -Path $testConfigPath -Force

                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath

                $config.EmergencyStop.MouseGestureEnabled | Should -Be $true
            }
        }

        It 'Should return MouseGestureHoldDurationMs default 3000 when file is empty' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                '' | Set-Content -Path $testConfigPath -Force

                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath

                $config.EmergencyStop.MouseGestureHoldDurationMs | Should -Be 3000
            }
        }

        It 'Should return MouseControl defaults when file is empty' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                '' | Set-Content -Path $testConfigPath -Force
                
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                
                $config.MouseControl.EasingEnabled | Should -Be $true
                $config.MouseControl.PathPointCount | Should -Be 20
            }
        }

        It 'Should return Logging defaults when file is empty' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                '' | Set-Content -Path $testConfigPath -Force
                
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                
                $config.Logging | Should -Not -BeNullOrEmpty
                $config.Logging.Backend | Should -Be 'File,EventLog'
                $config.Logging.MinimumLogLevel | Should -Be 'Info'
            }
        }

        AfterEach {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }
    }

    Context 'When configuration file is invalid' {
        BeforeEach {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
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

    Context 'Default settings come from Get-DefaultModuleSettings' {
        BeforeEach {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }

        It 'Get-ModuleConfiguration uses Get-DefaultModuleSettings defaults for new config' {
            InModuleScope -ModuleName LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $expectedDefaults = Get-DefaultModuleSettings
                
                # Verify Logging matches defaults
                $config.Logging.Backend | Should -Be $expectedDefaults.Logging.Backend
                $config.Logging.MinimumLogLevel | Should -Be $expectedDefaults.Logging.MinimumLogLevel
                $config.Logging.FileBackend.MaxSizeMB | Should -Be $expectedDefaults.Logging.FileBackend.MaxSizeMB
                
                # Verify MouseControl matches defaults
                $config.MouseControl.EasingEnabled | Should -Be $expectedDefaults.MouseControl.EasingEnabled
                $config.MouseControl.PathPointCount | Should -Be $expectedDefaults.MouseControl.PathPointCount
                
                # Verify EmergencyStop matches defaults
                $config.EmergencyStop.AutoStart | Should -Be $expectedDefaults.EmergencyStop.AutoStart
                $config.EmergencyStop.HotkeyVKeyCodes | Should -Be $expectedDefaults.EmergencyStop.HotkeyVKeyCodes
                $config.EmergencyStop.MouseGestureEnabled | Should -Be $expectedDefaults.EmergencyStop.MouseGestureEnabled
                $config.EmergencyStop.MouseGestureHoldDurationMs | Should -Be $expectedDefaults.EmergencyStop.MouseGestureHoldDurationMs
            }
        }

        It 'Save-ModuleConfiguration uses Get-DefaultModuleSettings defaults for new config' {
            InModuleScope -ModuleName LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath; mockWindow = $script:mockWindow } {
                Mock Write-Host {}
                
                Save-ModuleConfiguration -WindowObject $mockWindow -ConfigurationPath $testConfigPath -Force
                $savedConfig = Get-Content -Path $testConfigPath -Raw | ConvertFrom-Json
                $expectedDefaults = Get-DefaultModuleSettings
                
                # Verify Logging matches defaults
                $savedConfig.Logging.Backend | Should -Be $expectedDefaults.Logging.Backend
                $savedConfig.Logging.MinimumLogLevel | Should -Be $expectedDefaults.Logging.MinimumLogLevel
                
                # Verify MouseControl matches defaults
                $savedConfig.MouseControl.EasingEnabled | Should -Be $expectedDefaults.MouseControl.EasingEnabled
                $savedConfig.MouseControl.PathPointCount | Should -Be $expectedDefaults.MouseControl.PathPointCount
                
                # Verify EmergencyStop matches defaults
                $savedConfig.EmergencyStop.AutoStart | Should -Be $expectedDefaults.EmergencyStop.AutoStart
                $savedConfig.EmergencyStop.HotkeyVKeyCodes | Should -Be $expectedDefaults.EmergencyStop.HotkeyVKeyCodes
            }
        }

        AfterEach {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }
    }

    Context 'When performing save-load-test cycle' {
        BeforeEach {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }

        It 'Should complete full save-load cycle successfully' {
            InModuleScope -ModuleName LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath; mockWindow = $script:mockWindow } {
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

        It 'Should include all MouseControl config keys with correct defaults when missing from file' {
            InModuleScope -ModuleName LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath; mockWindow = $script:mockWindow } {
                # Save config with only minimal MouseControl
                $minimalConfig = [PSCustomObject]@{
                    ProcessName         = $mockWindow.ProcessName
                    WindowTitle         = $mockWindow.WindowTitle
                    WindowHandle        = $mockWindow.WindowHandle
                    WindowHandleString  = $mockWindow.WindowHandle.ToString()
                    WindowHandleInt64   = [int64]$mockWindow.WindowHandle
                    ProcessID           = $mockWindow.ProcessID
                    WindowState         = $mockWindow.WindowState
                    SavedDate           = (Get-Date -Format 'o')
                    SavedBy             = $env:USERNAME
                    ComputerName        = $env:COMPUTERNAME
                    MouseControl        = [PSCustomObject]@{ ClickDownDurationRangeMs = @(50, 150) }
                }
                $minimalConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $testConfigPath -Force
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $mouse = $config.MouseControl
                $mouse.EasingEnabled | Should -Be $true
                $mouse.OvershootEnabled | Should -Be $true
                $mouse.OvershootFactor | Should -Be 0.1
                $mouse.MicroPausesEnabled | Should -Be $true
                $mouse.MicroPauseChance | Should -Be 0.2
                $mouse.MicroPauseDurationRangeMs | Should -Be @(20, 80)
                $mouse.JitterEnabled | Should -Be $true
                $mouse.JitterRadiusPx | Should -Be 2
                $mouse.BezierControlPointOffsetFactor | Should -Be 0.3
                $mouse.MovementDurationRangeMs | Should -Be @(200, 600)
                $mouse.ClickDownDurationRangeMs | Should -Be @(50, 150)
                $mouse.ClickPreDelayRangeMs | Should -Be @(50, 200)
                $mouse.ClickPostDelayRangeMs | Should -Be @(100, 300)
                $mouse.PathPointCount | Should -Be 20
            }
        }

        It 'Should save and load all MouseControl config keys round-trip' {
            InModuleScope -ModuleName LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath; mockWindow = $script:mockWindow } {
                # Save config using module function
                Save-ModuleConfiguration -WindowObject $mockWindow -ConfigurationPath $testConfigPath -Force
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $mouse = $config.MouseControl
                $mouse.EasingEnabled | Should -Be $true
                $mouse.OvershootEnabled | Should -Be $true
                $mouse.OvershootFactor | Should -Be 0.1
                $mouse.MicroPausesEnabled | Should -Be $true
                $mouse.MicroPauseChance | Should -Be 0.2
                $mouse.MicroPauseDurationRangeMs | Should -Be @(20, 80)
                $mouse.JitterEnabled | Should -Be $true
                $mouse.JitterRadiusPx | Should -Be 2
                $mouse.BezierControlPointOffsetFactor | Should -Be 0.3
                $mouse.MovementDurationRangeMs | Should -Be @(200, 600)
                $mouse.ClickDownDurationRangeMs | Should -Be @(50, 150)
                $mouse.ClickPreDelayRangeMs | Should -Be @(50, 200)
                $mouse.ClickPostDelayRangeMs | Should -Be @(100, 300)
                $mouse.PathPointCount | Should -Be 20
            }
        }

        It 'Should include all EmergencyStop config keys with correct defaults when missing from file' {
            InModuleScope -ModuleName LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath; mockWindow = $script:mockWindow } {
                # Write a config missing the EmergencyStop key entirely
                $minimalConfig = [PSCustomObject]@{
                    ProcessName         = $mockWindow.ProcessName
                    WindowTitle         = $mockWindow.WindowTitle
                    WindowHandle        = $mockWindow.WindowHandle
                    WindowHandleString  = $mockWindow.WindowHandle.ToString()
                    WindowHandleInt64   = [int64]$mockWindow.WindowHandle
                    ProcessID           = $mockWindow.ProcessID
                    WindowState         = $mockWindow.WindowState
                    SavedDate           = (Get-Date -Format 'o')
                    SavedBy             = $env:USERNAME
                    ComputerName        = $env:COMPUTERNAME
                }
                $minimalConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $testConfigPath -Force
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $es = $config.EmergencyStop
                $es | Should -Not -BeNullOrEmpty
                $es.AutoStart | Should -Be $true
                $es.HotkeyVKeyCodes | Should -Be @(17, 16, 220)
                $es.PollIntervalMs | Should -Be 100
            }
        }

        It 'Should inject individual EmergencyStop keys that are missing while preserving existing ones' {
            InModuleScope -ModuleName LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath; mockWindow = $script:mockWindow } {
                # Config has EmergencyStop but only AutoStart - missing HotkeyVKeyCodes and PollIntervalMs
                $partialConfig = [PSCustomObject]@{
                    ProcessName         = $mockWindow.ProcessName
                    WindowTitle         = $mockWindow.WindowTitle
                    WindowHandle        = $mockWindow.WindowHandle
                    WindowHandleString  = $mockWindow.WindowHandle.ToString()
                    WindowHandleInt64   = [int64]$mockWindow.WindowHandle
                    ProcessID           = $mockWindow.ProcessID
                    WindowState         = $mockWindow.WindowState
                    SavedDate           = (Get-Date -Format 'o')
                    SavedBy             = $env:USERNAME
                    ComputerName        = $env:COMPUTERNAME
                    EmergencyStop       = [PSCustomObject]@{ AutoStart = $false }
                }
                $partialConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $testConfigPath -Force
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $es = $config.EmergencyStop
                # AutoStart was explicitly set to $false - must be preserved
                $es.AutoStart | Should -Be $false
                # Missing keys should have been injected with defaults
                $es.HotkeyVKeyCodes | Should -Be @(17, 16, 220)
                $es.PollIntervalMs | Should -Be 100
            }
        }

        It 'Should save and load all EmergencyStop config keys round-trip' {
            InModuleScope -ModuleName LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath; mockWindow = $script:mockWindow } {
                Save-ModuleConfiguration -WindowObject $mockWindow -ConfigurationPath $testConfigPath -Force
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $es = $config.EmergencyStop
                $es.AutoStart | Should -Be $true
                $es.HotkeyVKeyCodes | Should -Be @(17, 16, 220)
                $es.PollIntervalMs | Should -Be 100
            }
        }

        AfterEach {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }
    }
}

