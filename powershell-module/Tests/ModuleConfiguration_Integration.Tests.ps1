# Integration tests for Configuration Functions

BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Configuration Functions Integration' -Tag 'Integration' {
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

                # Verify Screenshots matches defaults
                $config.Screenshots.StoragePath | Should -Be $expectedDefaults.Screenshots.StoragePath
                $config.Screenshots.MaxStorageGB | Should -Be $expectedDefaults.Screenshots.MaxStorageGB
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

                # Verify Screenshots matches defaults
                $savedConfig.Screenshots.StoragePath | Should -Be $expectedDefaults.Screenshots.StoragePath
                $savedConfig.Screenshots.MaxStorageGB | Should -Be $expectedDefaults.Screenshots.MaxStorageGB
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
                    MouseControl        = [PSCustomObject]@{ MinClickDownDurationMs = 50; MaxClickDownDurationMs = 150 }
                }
                $minimalConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $testConfigPath -Force
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $mouse = $config.MouseControl
                $mouse.EasingEnabled | Should -Be $true
                $mouse.OvershootEnabled | Should -Be $true
                $mouse.OvershootFactor | Should -Be 0.1
                $mouse.MicroPausesEnabled | Should -Be $true
                $mouse.MicroPauseChance | Should -Be 0.2
                $mouse.MinMicroPauseDurationMs | Should -Be 20
                $mouse.MaxMicroPauseDurationMs | Should -Be 80
                $mouse.JitterEnabled | Should -Be $true
                $mouse.JitterRadiusPx | Should -Be 2
                $mouse.BezierControlPointOffsetFactor | Should -Be 0.3
                $mouse.MinMovementDurationMs | Should -Be 200
                $mouse.MaxMovementDurationMs | Should -Be 600
                $mouse.MinClickDownDurationMs | Should -Be 50
                $mouse.MaxClickDownDurationMs | Should -Be 150
                $mouse.MinClickPreDelayMs | Should -Be 50
                $mouse.MaxClickPreDelayMs | Should -Be 200
                $mouse.MinClickPostDelayMs | Should -Be 100
                $mouse.MaxClickPostDelayMs | Should -Be 300
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
                $mouse.MinMicroPauseDurationMs | Should -Be 20
                $mouse.MaxMicroPauseDurationMs | Should -Be 80
                $mouse.JitterEnabled | Should -Be $true
                $mouse.JitterRadiusPx | Should -Be 2
                $mouse.BezierControlPointOffsetFactor | Should -Be 0.3
                $mouse.MinMovementDurationMs | Should -Be 200
                $mouse.MaxMovementDurationMs | Should -Be 600
                $mouse.MinClickDownDurationMs | Should -Be 50
                $mouse.MaxClickDownDurationMs | Should -Be 150
                $mouse.MinClickPreDelayMs | Should -Be 50
                $mouse.MaxClickPreDelayMs | Should -Be 200
                $mouse.MinClickPostDelayMs | Should -Be 100
                $mouse.MaxClickPostDelayMs | Should -Be 300
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

        It 'Should include Screenshots defaults when Screenshots section is absent from file' {
            InModuleScope -ModuleName LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath; mockWindow = $script:mockWindow } {
                # Write a config that has no Screenshots section at all
                $noScreenshotsConfig = [PSCustomObject]@{
                    ProcessName        = $mockWindow.ProcessName
                    WindowTitle        = $mockWindow.WindowTitle
                    WindowHandle       = $mockWindow.WindowHandle
                    WindowHandleString = $mockWindow.WindowHandle.ToString()
                    WindowHandleInt64  = [int64]$mockWindow.WindowHandle
                    ProcessID          = $mockWindow.ProcessID
                    WindowState        = $mockWindow.WindowState
                    SavedDate          = (Get-Date -Format 'o')
                    SavedBy            = $env:USERNAME
                    ComputerName       = $env:COMPUTERNAME
                }
                $noScreenshotsConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $testConfigPath -Force

                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots | Should -Not -BeNullOrEmpty
                $config.Screenshots.StoragePath | Should -Be 'C:\LastWarAutoScreenshot\Screenshots'
                $config.Screenshots.MaxStorageGB | Should -Be 2.0
            }
        }

        It 'Should inject individual Screenshots keys that are missing while preserving existing ones' {
            InModuleScope -ModuleName LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath; mockWindow = $script:mockWindow } {
                # Config has Screenshots but only StoragePath - MaxStorageGB is absent
                $partialScreenshotsConfig = [PSCustomObject]@{
                    ProcessName        = $mockWindow.ProcessName
                    WindowTitle        = $mockWindow.WindowTitle
                    WindowHandle       = $mockWindow.WindowHandle
                    WindowHandleString = $mockWindow.WindowHandle.ToString()
                    WindowHandleInt64  = [int64]$mockWindow.WindowHandle
                    ProcessID          = $mockWindow.ProcessID
                    WindowState        = $mockWindow.WindowState
                    SavedDate          = (Get-Date -Format 'o')
                    SavedBy            = $env:USERNAME
                    ComputerName       = $env:COMPUTERNAME
                    Screenshots        = [PSCustomObject]@{ StoragePath = 'C:\MyScreenshots' }
                }
                $partialScreenshotsConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $testConfigPath -Force

                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                # Explicitly set StoragePath must be preserved
                $config.Screenshots.StoragePath | Should -Be 'C:\MyScreenshots'
                # Missing MaxStorageGB should be injected with the default
                $config.Screenshots.MaxStorageGB | Should -Be 2.0
            }
        }

        It 'Should save and load Screenshots.StoragePath round-trip' {
            InModuleScope -ModuleName LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath; mockWindow = $script:mockWindow } {
                # Save defaults (StoragePath = 'C:\LastWarAutoScreenshot\Screenshots')
                Save-ModuleConfiguration -WindowObject $mockWindow -ConfigurationPath $testConfigPath -Force
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.StoragePath | Should -Be 'C:\LastWarAutoScreenshot\Screenshots'
            }
        }

        It 'Should save and load Screenshots.MaxStorageGB round-trip' {
            InModuleScope -ModuleName LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath; mockWindow = $script:mockWindow } {
                # Save defaults (MaxStorageGB = 2.0)
                Save-ModuleConfiguration -WindowObject $mockWindow -ConfigurationPath $testConfigPath -Force
                $config = Get-ModuleConfiguration -ConfigurationPath $testConfigPath
                $config.Screenshots.MaxStorageGB | Should -Be 2.0
            }
        }

        It 'Should preserve existing Screenshots settings when saving a new window target' {
            InModuleScope -ModuleName LastWarAutoScreenshot -Parameters @{ testConfigPath = $script:testConfigPath; mockWindow = $script:mockWindow } {
                # Create a config file with custom Screenshots values
                $existingWithScreenshots = [PSCustomObject]@{
                    ProcessName        = 'OldProcess'
                    WindowTitle        = 'Old Window'
                    WindowHandleString = '111'
                    WindowHandleInt64  = [int64]111
                    ProcessID          = [uint32]1
                    WindowState        = 'Visible'
                    SavedDate          = (Get-Date -Format 'o')
                    SavedBy            = $env:USERNAME
                    ComputerName       = $env:COMPUTERNAME
                    Logging            = [PSCustomObject]@{
                        Backend         = 'File'
                        MinimumLogLevel = 'Info'
                        FileBackend     = [PSCustomObject]@{
                            MaxSizeMB = 50; MaxAgeDays = 30; MaxLogFileCount = 500
                        }
                    }
                    MouseControl       = [PSCustomObject]@{
                        EasingEnabled = $true; OvershootEnabled = $true; OvershootFactor = 0.1
                        MicroPausesEnabled = $true; MicroPauseChance = 0.2
                        MinMicroPauseDurationMs = 20; MaxMicroPauseDurationMs = 80; JitterEnabled = $true; JitterRadiusPx = 2
                        BezierControlPointOffsetFactor = 0.3; MinMovementDurationMs = 200; MaxMovementDurationMs = 600
                        MinClickDownDurationMs = 50; MaxClickDownDurationMs = 150
                        MinClickPreDelayMs = 50; MaxClickPreDelayMs = 200
                        MinClickPostDelayMs = 100; MaxClickPostDelayMs = 300; PathPointCount = 20
                    }
                    EmergencyStop      = [PSCustomObject]@{
                        AutoStart = $true; HotkeyVKeyCodes = @(17, 16, 220)
                        PollIntervalMs = 100; MouseGestureEnabled = $true; MouseGestureHoldDurationMs = 3000
                    }
                    Screenshots        = [PSCustomObject]@{
                        StoragePath  = 'D:\GameScreenshots'
                        MaxStorageGB = 5.0
                    }
                }
                $existingWithScreenshots | ConvertTo-Json -Depth 5 | Set-Content -Path $testConfigPath -Force

                Mock Write-Host {}
                Save-ModuleConfiguration -WindowObject $mockWindow -ConfigurationPath $testConfigPath -Force
                $config = Get-Content -Path $testConfigPath -Raw | ConvertFrom-Json

                # Custom Screenshots settings must survive a window-target save
                $config.Screenshots.StoragePath | Should -Be 'D:\GameScreenshots'
                $config.Screenshots.MaxStorageGB | Should -Be 5.0
            }
        }

        AfterEach {
            if (Test-Path -Path $script:testConfigPath) {
                Remove-Item -Path $script:testConfigPath -Force
            }
        }
    }
}


