BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Get-DefaultModuleSettings' -Tag 'Unit' {
    Context 'When called without parameters' {
        It 'Should return a PSCustomObject' {
            InModuleScope LastWarAutoScreenshot {
                $defaults = Get-DefaultModuleSettings
                $defaults | Should -BeOfType [PSCustomObject]
            }
        }

        It 'Should return object with three property groups' {
            InModuleScope LastWarAutoScreenshot {
                $defaults = Get-DefaultModuleSettings
                $defaults.PSObject.Properties.Name | Should -Contain 'Logging'
                $defaults.PSObject.Properties.Name | Should -Contain 'MouseControl'
                $defaults.PSObject.Properties.Name | Should -Contain 'EmergencyStop'
            }
        }
    }

    Context 'Logging defaults' {
        It 'Should have correct Logging structure' {
            InModuleScope LastWarAutoScreenshot {
                $defaults = Get-DefaultModuleSettings
                $defaults.Logging | Should -Not -BeNullOrEmpty
                $defaults.Logging.Backend | Should -Be 'File,EventLog'
                $defaults.Logging.MinimumLogLevel | Should -Be 'Info'
            }
        }

        It 'Should have FileBackend with all required properties' {
            InModuleScope LastWarAutoScreenshot {
                $defaults = Get-DefaultModuleSettings
                $defaults.Logging.FileBackend | Should -Not -BeNullOrEmpty
                $defaults.Logging.FileBackend.MaxSizeMB | Should -Be 50
                $defaults.Logging.FileBackend.MaxAgeDays | Should -Be 30
                $defaults.Logging.FileBackend.MaxLogFileCount | Should -Be 500
            }
        }
    }

    Context 'MouseControl defaults' {
        It 'Should have correct MouseControl structure' {
            InModuleScope LastWarAutoScreenshot {
                $defaults = Get-DefaultModuleSettings
                $defaults.MouseControl | Should -Not -BeNullOrEmpty
                @($defaults.MouseControl.PSObject.Properties).Count | Should -Be 19
            }
        }

        It 'Should have all required MouseControl properties with correct defaults' {
            InModuleScope LastWarAutoScreenshot {
                $defaults = Get-DefaultModuleSettings
                $m = $defaults.MouseControl
                
                $m.EasingEnabled | Should -Be $true
                $m.OvershootEnabled | Should -Be $true
                $m.OvershootFactor | Should -Be 0.1
                $m.MicroPausesEnabled | Should -Be $true
                $m.MicroPauseChance | Should -Be 0.2
                $m.MinMicroPauseDurationMs | Should -Be 20
                $m.MaxMicroPauseDurationMs | Should -Be 80
                $m.JitterEnabled | Should -Be $true
                $m.JitterRadiusPx | Should -Be 2
                $m.BezierControlPointOffsetFactor | Should -Be 0.3
                $m.MinMovementDurationMs | Should -Be 200
                $m.MaxMovementDurationMs | Should -Be 600
                $m.MinClickDownDurationMs | Should -Be 50
                $m.MaxClickDownDurationMs | Should -Be 150
                $m.MinClickPreDelayMs | Should -Be 50
                $m.MaxClickPreDelayMs | Should -Be 200
                $m.MinClickPostDelayMs | Should -Be 100
                $m.MaxClickPostDelayMs | Should -Be 300
                $m.PathPointCount | Should -Be 20
            }
        }
    }

    Context 'EmergencyStop defaults' {
        It 'Should have correct EmergencyStop structure' {
            InModuleScope LastWarAutoScreenshot {
                $defaults = Get-DefaultModuleSettings
                $defaults.EmergencyStop | Should -Not -BeNullOrEmpty
                @($defaults.EmergencyStop.PSObject.Properties).Count | Should -Be 3
            }
        }

        It 'Should have all required EmergencyStop properties with correct defaults' {
            InModuleScope LastWarAutoScreenshot {
                $defaults = Get-DefaultModuleSettings
                $es = $defaults.EmergencyStop

                $es.AutoStart | Should -Be $true
                $es.HotkeyKeyNames | Should -Be 'Ctrl+Alt+Q'
                $es.PollIntervalMs | Should -Be 100
            }
        }

        It 'Should have correct HotkeyKeyNames value' {
            InModuleScope LastWarAutoScreenshot {
                $defaults = Get-DefaultModuleSettings
                # 'Ctrl+Alt+Q' -- '#' is a standalone key on UK keyboard layouts
                $defaults.EmergencyStop.HotkeyKeyNames | Should -Be 'Ctrl+Alt+Q'
            }
        }
    }

    Context 'Consistency across multiple calls' {
        It 'Should return identical values on successive calls' {
            InModuleScope LastWarAutoScreenshot {
                $defaults1 = Get-DefaultModuleSettings
                $defaults2 = Get-DefaultModuleSettings
                
                # Compare full JSON to ensure deep equality
                $json1 = $defaults1 | ConvertTo-Json -Depth 5
                $json2 = $defaults2 | ConvertTo-Json -Depth 5
                $json1 | Should -Be $json2
            }
        }

        It 'Should be a new object each call (not cached)' {
            InModuleScope LastWarAutoScreenshot {
                $defaults1 = Get-DefaultModuleSettings
                $defaults2 = Get-DefaultModuleSettings
                
                # Objects should be different instances
                [object]::ReferenceEquals($defaults1, $defaults2) | Should -Be $false
            }
        }
    }

    Context 'Output format' {
        It 'Should output valid JSON-serializable object' {
            InModuleScope LastWarAutoScreenshot {
                $defaults = Get-DefaultModuleSettings
                { $defaults | ConvertTo-Json -Depth 5 } | Should -Not -Throw
            }
        }
    }
}

