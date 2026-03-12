BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'Save-ModuleConfiguration' -Tag 'Unit' {
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
                    MinMicroPauseDurationMs = 100
                    MaxMicroPauseDurationMs = 200
                    JitterEnabled = $false
                    JitterRadiusPx = 5
                    BezierControlPointOffsetFactor = 0.5
                    MinMovementDurationMs = 1000
                    MaxMovementDurationMs = 2000
                    MinClickDownDurationMs = 100
                    MaxClickDownDurationMs = 200
                    MinClickPreDelayMs = 100
                    MaxClickPreDelayMs = 300
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
                        MaxAgeDays = 60
                        MaxLogFileCount = 1000
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
                $config.MouseControl.MinMicroPauseDurationMs | Should -Be 100
                $config.MouseControl.MaxMicroPauseDurationMs | Should -Be 200
                $config.MouseControl.JitterEnabled | Should -Be $false
                $config.MouseControl.JitterRadiusPx | Should -Be 5
                $config.MouseControl.BezierControlPointOffsetFactor | Should -Be 0.5
                $config.MouseControl.MinMovementDurationMs | Should -Be 1000
                $config.MouseControl.MaxMovementDurationMs | Should -Be 2000
                $config.MouseControl.MinClickDownDurationMs | Should -Be 100
                $config.MouseControl.MaxClickDownDurationMs | Should -Be 200
                $config.MouseControl.MinClickPreDelayMs | Should -Be 100
                $config.MouseControl.MaxClickPreDelayMs | Should -Be 300
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
                $config.Logging.FileBackend.MaxAgeDays | Should -Be 60
                $config.Logging.FileBackend.MaxLogFileCount | Should -Be 1000
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

Describe 'Get-ModuleConfiguration' -Tag 'Unit' {
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

        It 'Should return a config with Screenshots defaults' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ nonExistentPath = $script:nonExistentPath } {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                $config = Get-ModuleConfiguration -ConfigurationPath $nonExistentPath
                $config.Screenshots | Should -Not -BeNullOrEmpty
                $config.Screenshots.StoragePath | Should -Be 'C:\LastWarAutoScreenshot\Screenshots'
                $config.Screenshots.MaxStorageGB | Should -Be 2.0
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

        It 'Should return Screenshots defaults when file is empty' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                Mock Write-LastWarLog {}
                Mock Write-Host {}
                '' | Set-Content -Path $testConfigPath -Force

                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath

                $config.Screenshots | Should -Not -BeNullOrEmpty
                $config.Screenshots.StoragePath | Should -Be 'C:\LastWarAutoScreenshot\Screenshots'
                $config.Screenshots.MaxStorageGB | Should -Be 2.0
            }
        }

        AfterEach {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }
    }

    Context 'When loading a Phase 5 config with all new Screenshots keys present (round-trip)' {
        BeforeAll {
            # Write a config with all new Phase 5 Screenshots keys set to non-default values
            # so we can verify they are preserved on load (round-trip).
            $phase5Config = [PSCustomObject]@{
                ProcessName        = 'RoundTripProcess'
                WindowTitle        = 'Round Trip Window'
                WindowHandleString = '999'
                WindowHandleInt64  = [int64]999
                ProcessID          = [uint32]1
                WindowState        = 'Visible'
                SavedDate          = (Get-Date -Format 'o')
                SavedBy            = 'TestUser'
                ComputerName       = 'TestComputer'
                Screenshots        = [PSCustomObject]@{
                    StoragePath                    = 'C:\Screenshots'
                    MaxStorageGB                   = 5.0
                    StorageWarningThresholdPercent = 75
                    FileFormat                     = 'PNG'
                    FilenamePattern                = '{MacroName}_{Timestamp}'
                    SimilarityCheck                = [PSCustomObject]@{
                        Enabled              = $true
                        Threshold            = 0.95
                        SampleCount          = 500
                        FullScan             = $true
                        TolerancePerChannel  = 5
                        Action               = 'StopMacro'
                        ConsecutiveThreshold = 3
                    }
                }
            }
            $phase5Config | ConvertTo-Json -Depth 5 | Set-Content -Path $script:testConfigPath -Force
        }

        It 'Should preserve StorageWarningThresholdPercent' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.StorageWarningThresholdPercent | Should -Be 75
            }
        }

        It 'Should preserve FileFormat' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.FileFormat | Should -Be 'PNG'
            }
        }

        It 'Should preserve FilenamePattern' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.FilenamePattern | Should -Be '{MacroName}_{Timestamp}'
            }
        }

        It 'Should preserve SimilarityCheck.Enabled' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.SimilarityCheck.Enabled | Should -Be $true
            }
        }

        It 'Should preserve SimilarityCheck.Threshold' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.SimilarityCheck.Threshold | Should -Be 0.95
            }
        }

        It 'Should preserve SimilarityCheck.SampleCount' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.SimilarityCheck.SampleCount | Should -Be 500
            }
        }

        It 'Should preserve SimilarityCheck.FullScan' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.SimilarityCheck.FullScan | Should -Be $true
            }
        }

        It 'Should preserve SimilarityCheck.TolerancePerChannel' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.SimilarityCheck.TolerancePerChannel | Should -Be 5
            }
        }

        It 'Should preserve SimilarityCheck.Action' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.SimilarityCheck.Action | Should -Be 'StopMacro'
            }
        }

        It 'Should preserve SimilarityCheck.ConsecutiveThreshold' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.SimilarityCheck.ConsecutiveThreshold | Should -Be 3
            }
        }

        AfterAll {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }
    }

    Context 'When loading a Phase 3 config with only StoragePath and MaxStorageGB in Screenshots (default injection)' {
        BeforeEach {
            # Simulate a Phase 3 config file: Screenshots section has only the two original keys
            $phase3Config = [PSCustomObject]@{
                ProcessName        = 'Phase3Process'
                WindowTitle        = 'Phase 3 Window'
                WindowHandleString = '111'
                WindowHandleInt64  = [int64]111
                ProcessID          = [uint32]2
                WindowState        = 'Visible'
                SavedDate          = (Get-Date -Format 'o')
                SavedBy            = 'TestUser'
                ComputerName       = 'TestComputer'
                Screenshots        = [PSCustomObject]@{
                    StoragePath  = 'C:\OldScreenshots'
                    MaxStorageGB = 1.0
                }
            }
            $phase3Config | ConvertTo-Json -Depth 5 | Set-Content -Path $script:testConfigPath -Force
        }

        It 'Should inject StorageWarningThresholdPercent with default 90' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.StorageWarningThresholdPercent | Should -Be 90
            }
        }

        It 'Should inject FileFormat with default PNG' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.FileFormat | Should -Be 'PNG'
            }
        }

        It 'Should inject FilenamePattern with default value' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.FilenamePattern | Should -Be '{MacroName}_{ActionName}_{Timestamp}_{Index}'
            }
        }

        It 'Should create SimilarityCheck sub-object' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.SimilarityCheck | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should inject SimilarityCheck.Enabled with default false' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.SimilarityCheck.Enabled | Should -Be $false
            }
        }

        It 'Should inject SimilarityCheck.Threshold with default 0.98' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.SimilarityCheck.Threshold | Should -Be 0.98
            }
        }

        It 'Should inject SimilarityCheck.SampleCount with default 1000' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.SimilarityCheck.SampleCount | Should -Be 1000
            }
        }

        It 'Should inject SimilarityCheck.FullScan with default false' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.SimilarityCheck.FullScan | Should -Be $false
            }
        }

        It 'Should inject SimilarityCheck.TolerancePerChannel with default 10' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.SimilarityCheck.TolerancePerChannel | Should -Be 10
            }
        }

        It 'Should inject SimilarityCheck.Action with default StopLoop' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.SimilarityCheck.Action | Should -Be 'StopLoop'
            }
        }

        It 'Should inject SimilarityCheck.ConsecutiveThreshold with default 1' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.SimilarityCheck.ConsecutiveThreshold | Should -Be 1
            }
        }

        It 'Should preserve existing StoragePath and MaxStorageGB unchanged' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.StoragePath | Should -Be 'C:\OldScreenshots'
                $config.Screenshots.MaxStorageGB | Should -Be 1.0
            }
        }

        AfterEach {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }
    }

    Context 'When SimilarityCheck sub-object exists but Action key is missing (default injection)' {
        BeforeEach {
            # SimilarityCheck exists but is missing the Action key
            $partialConfig = [PSCustomObject]@{
                ProcessName        = 'PartialProcess'
                WindowTitle        = 'Partial Window'
                WindowHandleString = '222'
                WindowHandleInt64  = [int64]222
                ProcessID          = [uint32]3
                WindowState        = 'Visible'
                SavedDate          = (Get-Date -Format 'o')
                SavedBy            = 'TestUser'
                ComputerName       = 'TestComputer'
                Screenshots        = [PSCustomObject]@{
                    StoragePath                    = ''
                    MaxStorageGB                   = 2.0
                    StorageWarningThresholdPercent = 90
                    FileFormat                     = 'PNG'
                    FilenamePattern                = '{MacroName}_{ActionName}_{Timestamp}_{Index}'
                    SimilarityCheck                = [PSCustomObject]@{
                        Enabled              = $false
                        Threshold            = 0.98
                        SampleCount          = 1000
                        FullScan             = $false
                        TolerancePerChannel  = 10
                        ConsecutiveThreshold = 1
                        # Action is intentionally omitted
                    }
                }
            }
            $partialConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $script:testConfigPath -Force
        }

        It 'Should inject Action as StopLoop' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.SimilarityCheck.Action | Should -Be 'StopLoop'
            }
        }

        AfterEach {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }
    }

    Context 'When SimilarityCheck sub-object exists but ConsecutiveThreshold key is missing (default injection)' {
        BeforeEach {
            # SimilarityCheck exists but is missing the ConsecutiveThreshold key
            $partialConfig = [PSCustomObject]@{
                ProcessName        = 'PartialProcess2'
                WindowTitle        = 'Partial Window 2'
                WindowHandleString = '333'
                WindowHandleInt64  = [int64]333
                ProcessID          = [uint32]4
                WindowState        = 'Visible'
                SavedDate          = (Get-Date -Format 'o')
                SavedBy            = 'TestUser'
                ComputerName       = 'TestComputer'
                Screenshots        = [PSCustomObject]@{
                    StoragePath                    = ''
                    MaxStorageGB                   = 2.0
                    StorageWarningThresholdPercent = 90
                    FileFormat                     = 'PNG'
                    FilenamePattern                = '{MacroName}_{ActionName}_{Timestamp}_{Index}'
                    SimilarityCheck                = [PSCustomObject]@{
                        Enabled             = $false
                        Threshold           = 0.98
                        SampleCount         = 1000
                        FullScan            = $false
                        TolerancePerChannel = 10
                        Action              = 'StopLoop'
                        # ConsecutiveThreshold is intentionally omitted
                    }
                }
            }
            $partialConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $script:testConfigPath -Force
        }

        It 'Should inject ConsecutiveThreshold as 1' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath } {
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.SimilarityCheck.ConsecutiveThreshold | Should -Be 1
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

Describe 'Test-ModuleConfigurationExists' -Tag 'Unit' {
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


