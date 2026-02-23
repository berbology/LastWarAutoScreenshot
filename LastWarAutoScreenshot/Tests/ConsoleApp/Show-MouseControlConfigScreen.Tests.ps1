BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force

    # Spectre.Console.Testing.dll ships in lib\test\ and is required for TestConsole
    $testingDll = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}

Describe 'Show-MouseControlConfigScreen' {

    # ════════════════════════════════════════════════════════════════════════
    # Context: Table renders current values
    # ════════════════════════════════════════════════════════════════════════
    Context 'Initial table display' {

        It 'Console output contains representative MouseControl key names' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50; MaxFileCount = 50
                                MaxAgeDays = 30; RetentionFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MicroPauseDurationRangeMs      = @(20, 80)
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MovementDurationRangeMs        = @(200, 600)
                            ClickDownDurationRangeMs       = @(50, 150)
                            ClickPreDelayRangeMs           = @(50, 200)
                            ClickPostDelayRangeMs          = @(100, 300)
                            PathPointCount                 = 20
                        }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # Bool keys: y × 4, non-bool keys: Enter × 15 (3 double+2 int+5×2 intArray)
                $tc.Input.PushTextWithEnter('y')       # EasingEnabled
                $tc.Input.PushTextWithEnter('y')       # OvershootEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # OvershootFactor
                $tc.Input.PushTextWithEnter('y')       # MicroPausesEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseChance
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs max
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter) # Discard

                Show-MouseControlConfigScreen -Console $tc

                # Patterns use (?s) to match across newlines (table text wraps due to column width)
                $tc.Output | Should -Match '(?s)Easin.*gEnabled'
                $tc.Output | Should -Match '(?s)Overs.*hootFactor'
                $tc.Output | Should -Match '(?s)Micro.*PauseDurationRange.*Ms'
                $tc.Output | Should -Match '(?s)Movem.*entDurationRangeMs'
                $tc.Output | Should -Match '(?s)PathP.*ointCount'
            }
        }

        It 'Console output contains the current values from the loaded config' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50; MaxFileCount = 50
                                MaxAgeDays = 30; RetentionFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MicroPauseDurationRangeMs      = @(20, 80)
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MovementDurationRangeMs        = @(200, 600)
                            ClickDownDurationRangeMs       = @(50, 150)
                            ClickPreDelayRangeMs           = @(50, 200)
                            ClickPostDelayRangeMs          = @(100, 300)
                            PathPointCount                 = 20
                        }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('y')       # EasingEnabled
                $tc.Input.PushTextWithEnter('y')       # OvershootEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # OvershootFactor
                $tc.Input.PushTextWithEnter('y')       # MicroPausesEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseChance
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs max
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter) # Discard

                Show-MouseControlConfigScreen -Console $tc

                # Numeric values and array values should appear in the rendered table
                $tc.Output | Should -Match '0.1'    # OvershootFactor
                $tc.Output | Should -Match '20'     # part of MicroPauseDurationRangeMs
                $tc.Output | Should -Match '200'    # part of MovementDurationRangeMs
                $tc.Output | Should -Match '20'     # PathPointCount
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Accepting all current values calls Save-ModuleSettings
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user accepts all current values and chooses Yes - save now' {

        It 'Calls Save-ModuleSettings exactly once' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50; MaxFileCount = 50
                                MaxAgeDays = 30; RetentionFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MicroPauseDurationRangeMs      = @(20, 80)
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MovementDurationRangeMs        = @(200, 600)
                            ClickDownDurationRangeMs       = @(50, 150)
                            ClickPreDelayRangeMs           = @(50, 200)
                            ClickPostDelayRangeMs          = @(100, 300)
                            PathPointCount                 = 20
                        }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('y')       # EasingEnabled
                $tc.Input.PushTextWithEnter('y')       # OvershootEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # OvershootFactor
                $tc.Input.PushTextWithEnter('y')       # MicroPausesEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseChance
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs max
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::Enter) # Yes - save now

                Show-MouseControlConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1
            }
        }

        It 'The config passed to Save-ModuleSettings retains the original EasingEnabled value' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50; MaxFileCount = 50
                                MaxAgeDays = 30; RetentionFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MicroPauseDurationRangeMs      = @(20, 80)
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MovementDurationRangeMs        = @(200, 600)
                            ClickDownDurationRangeMs       = @(50, 150)
                            ClickPreDelayRangeMs           = @(50, 200)
                            ClickPostDelayRangeMs          = @(100, 300)
                            PathPointCount                 = 20
                        }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('y')       # EasingEnabled = keep true
                $tc.Input.PushTextWithEnter('y')       # OvershootEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # OvershootFactor
                $tc.Input.PushTextWithEnter('y')       # MicroPausesEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseChance
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs max
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::Enter) # Yes - save now

                Show-MouseControlConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.MouseControl.EasingEnabled -eq $true
                }
            }
        }

        It 'Writes a success panel containing "saved" to the console' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50; MaxFileCount = 50
                                MaxAgeDays = 30; RetentionFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MicroPauseDurationRangeMs      = @(20, 80)
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MovementDurationRangeMs        = @(200, 600)
                            ClickDownDurationRangeMs       = @(50, 150)
                            ClickPreDelayRangeMs           = @(50, 200)
                            ClickPostDelayRangeMs          = @(100, 300)
                            PathPointCount                 = 20
                        }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('y')       # EasingEnabled
                $tc.Input.PushTextWithEnter('y')       # OvershootEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # OvershootFactor
                $tc.Input.PushTextWithEnter('y')       # MicroPausesEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseChance
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs max
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::Enter) # Yes - save now

                Show-MouseControlConfigScreen -Console $tc

                $tc.Output | Should -Match 'saved'
            }
        }

        It 'Calls Write-LastWarLog with Level Info on successful save' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50; MaxFileCount = 50
                                MaxAgeDays = 30; RetentionFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MicroPauseDurationRangeMs      = @(20, 80)
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MovementDurationRangeMs        = @(200, 600)
                            ClickDownDurationRangeMs       = @(50, 150)
                            ClickPreDelayRangeMs           = @(50, 200)
                            ClickPostDelayRangeMs          = @(100, 300)
                            PathPointCount                 = 20
                        }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('y')       # EasingEnabled
                $tc.Input.PushTextWithEnter('y')       # OvershootEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # OvershootFactor
                $tc.Input.PushTextWithEnter('y')       # MicroPausesEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseChance
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs max
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::Enter) # Yes - save now

                Show-MouseControlConfigScreen -Console $tc

                Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Info' } -Exactly 1
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Discard changes does not call Save-ModuleSettings
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user chooses Discard changes' {

        It 'Does not call Save-ModuleSettings' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50; MaxFileCount = 50
                                MaxAgeDays = 30; RetentionFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MicroPauseDurationRangeMs      = @(20, 80)
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MovementDurationRangeMs        = @(200, 600)
                            ClickDownDurationRangeMs       = @(50, 150)
                            ClickPreDelayRangeMs           = @(50, 200)
                            ClickPostDelayRangeMs          = @(100, 300)
                            PathPointCount                 = 20
                        }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('y')       # EasingEnabled
                $tc.Input.PushTextWithEnter('y')       # OvershootEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # OvershootFactor
                $tc.Input.PushTextWithEnter('y')       # MicroPausesEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseChance
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs max
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter) # Discard changes

                Show-MouseControlConfigScreen -Console $tc

                Should -Not -Invoke Save-ModuleSettings
            }
        }

        It 'Writes a "No changes saved" panel to the console' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50; MaxFileCount = 50
                                MaxAgeDays = 30; RetentionFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MicroPauseDurationRangeMs      = @(20, 80)
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MovementDurationRangeMs        = @(200, 600)
                            ClickDownDurationRangeMs       = @(50, 150)
                            ClickPreDelayRangeMs           = @(50, 200)
                            ClickPostDelayRangeMs          = @(100, 300)
                            PathPointCount                 = 20
                        }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('y')       # EasingEnabled
                $tc.Input.PushTextWithEnter('y')       # OvershootEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # OvershootFactor
                $tc.Input.PushTextWithEnter('y')       # MicroPausesEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseChance
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs max
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter) # Discard changes

                Show-MouseControlConfigScreen -Console $tc

                $tc.Output | Should -Match 'No changes saved'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Bool key set to false via ConfirmationPrompt
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user sets a bool key to false via ConfirmationPrompt' {

        It 'EasingEnabled is saved as false when the user enters n' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50; MaxFileCount = 50
                                MaxAgeDays = 30; RetentionFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MicroPauseDurationRangeMs      = @(20, 80)
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MovementDurationRangeMs        = @(200, 600)
                            ClickDownDurationRangeMs       = @(50, 150)
                            ClickPreDelayRangeMs           = @(50, 200)
                            ClickPostDelayRangeMs          = @(100, 300)
                            PathPointCount                 = 20
                        }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('n')       # EasingEnabled → false
                $tc.Input.PushTextWithEnter('y')       # OvershootEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # OvershootFactor
                $tc.Input.PushTextWithEnter('y')       # MicroPausesEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseChance
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs max
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::Enter) # Yes - save now

                Show-MouseControlConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.MouseControl.EasingEnabled -eq $false
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: intArray validation error when min > max
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user enters invalid intArray values with min greater than max' {

        It 'Error message appears in console output' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50; MaxFileCount = 50
                                MaxAgeDays = 30; RetentionFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MicroPauseDurationRangeMs      = @(20, 80)
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MovementDurationRangeMs        = @(200, 600)
                            ClickDownDurationRangeMs       = @(50, 150)
                            ClickPreDelayRangeMs           = @(50, 200)
                            ClickPostDelayRangeMs          = @(100, 300)
                            PathPointCount                 = 20
                        }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('y')          # EasingEnabled
                $tc.Input.PushTextWithEnter('y')          # OvershootEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)    # OvershootFactor
                $tc.Input.PushTextWithEnter('y')          # MicroPausesEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)    # MicroPauseChance
                # MicroPauseDurationRangeMs: invalid pair (500 > 100)
                $tc.Input.PushTextWithEnter('500')        # min - invalid: 500 > 100
                $tc.Input.PushTextWithEnter('100')        # max
                # Re-prompt after error: keep current values (20, 80)
                $tc.Input.PushKey([ConsoleKey]::Enter)    # min (keep 20)
                $tc.Input.PushKey([ConsoleKey]::Enter)    # max (keep 80)
                $tc.Input.PushTextWithEnter('y')          # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)    # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter)    # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter)    # MovementDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)    # MovementDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)    # ClickDownDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)    # ClickDownDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)    # ClickPreDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)    # ClickPreDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)    # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)    # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)    # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Discard

                Show-MouseControlConfigScreen -Console $tc

                $tc.Output | Should -Match 'must not exceed'
            }
        }

        It 'After invalid pair the valid retry pair is saved correctly' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50; MaxFileCount = 50
                                MaxAgeDays = 30; RetentionFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MicroPauseDurationRangeMs      = @(20, 80)
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MovementDurationRangeMs        = @(200, 600)
                            ClickDownDurationRangeMs       = @(50, 150)
                            ClickPreDelayRangeMs           = @(50, 200)
                            ClickPostDelayRangeMs          = @(100, 300)
                            PathPointCount                 = 20
                        }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('y')          # EasingEnabled
                $tc.Input.PushTextWithEnter('y')          # OvershootEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)    # OvershootFactor
                $tc.Input.PushTextWithEnter('y')          # MicroPausesEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)    # MicroPauseChance
                # MicroPauseDurationRangeMs: first attempt invalid (500 > 100)
                $tc.Input.PushTextWithEnter('500')        # min (invalid)
                $tc.Input.PushTextWithEnter('100')        # max (pair fails: 500 > 100)
                # Second attempt: valid pair (30, 90)
                $tc.Input.PushTextWithEnter('30')         # min = 30
                $tc.Input.PushTextWithEnter('90')         # max = 90 → valid pair
                $tc.Input.PushTextWithEnter('y')          # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)    # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter)    # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter)    # MovementDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)    # MovementDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)    # ClickDownDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)    # ClickDownDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)    # ClickPreDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)    # ClickPreDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)    # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)    # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)    # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Yes - save now

                Show-MouseControlConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.MouseControl.MicroPauseDurationRangeMs[0] -eq 30 -and
                    $Config.MouseControl.MicroPauseDurationRangeMs[1] -eq 90
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Valid new intArray values for MovementDurationRangeMs
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user enters valid new intArray values for MovementDurationRangeMs' {

        It 'The saved config contains the new array values' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50; MaxFileCount = 50
                                MaxAgeDays = 30; RetentionFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MicroPauseDurationRangeMs      = @(20, 80)
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MovementDurationRangeMs        = @(200, 600)
                            ClickDownDurationRangeMs       = @(50, 150)
                            ClickPreDelayRangeMs           = @(50, 200)
                            ClickPostDelayRangeMs          = @(100, 300)
                            PathPointCount                 = 20
                        }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('y')          # EasingEnabled
                $tc.Input.PushTextWithEnter('y')          # OvershootEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)    # OvershootFactor
                $tc.Input.PushTextWithEnter('y')          # MicroPausesEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)    # MicroPauseChance
                $tc.Input.PushKey([ConsoleKey]::Enter)    # MicroPauseDurationRangeMs min (keep 20)
                $tc.Input.PushKey([ConsoleKey]::Enter)    # MicroPauseDurationRangeMs max (keep 80)
                $tc.Input.PushTextWithEnter('y')          # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)    # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter)    # BezierControlPointOffsetFactor
                $tc.Input.PushTextWithEnter('100')        # MovementDurationRangeMs min = 100
                $tc.Input.PushTextWithEnter('400')        # MovementDurationRangeMs max = 400
                $tc.Input.PushKey([ConsoleKey]::Enter)    # ClickDownDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)    # ClickDownDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)    # ClickPreDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)    # ClickPreDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)    # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)    # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)    # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Yes - save now

                Show-MouseControlConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.MouseControl.MovementDurationRangeMs[0] -eq 100 -and
                    $Config.MouseControl.MovementDurationRangeMs[1] -eq 400
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: [Reset to default] sentinel for a numeric key
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user enters [Reset to default] for the OvershootFactor key' {

        It 'The saved config contains the schema default value for OvershootFactor' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                # Use a non-default OvershootFactor value to make the reset detectable
                $mockConfigNonDefault = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50; MaxFileCount = 50
                                MaxAgeDays = 30; RetentionFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.9
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MicroPauseDurationRangeMs      = @(20, 80)
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MovementDurationRangeMs        = @(200, 600)
                            ClickDownDurationRangeMs       = @(50, 150)
                            ClickPreDelayRangeMs           = @(50, 200)
                            ClickPostDelayRangeMs          = @(100, 300)
                            PathPointCount                 = 20
                        }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfigNonDefault
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('y')                   # EasingEnabled
                $tc.Input.PushTextWithEnter('y')                   # OvershootEnabled
                $tc.Input.PushTextWithEnter('[Reset to default]')  # OvershootFactor → reset to 0.1
                $tc.Input.PushTextWithEnter('y')                   # MicroPausesEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MicroPauseChance
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MicroPauseDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MicroPauseDurationRangeMs max
                $tc.Input.PushTextWithEnter('y')                   # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)             # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter)             # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MovementDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MovementDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)             # ClickDownDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)             # ClickDownDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)             # ClickPreDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)             # ClickPreDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)             # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)             # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)             # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::Enter)             # Yes - save now

                Show-MouseControlConfigScreen -Console $tc

                # Default OvershootFactor is 0.1 (from Get-DefaultModuleSettings)
                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.MouseControl.OvershootFactor -eq 0.1
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: [Reset to default] sentinel for an intArray key
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user enters [Reset to default] for the MovementDurationRangeMs intArray key' {

        It 'The saved config contains the schema default value for MovementDurationRangeMs' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                # Use non-default MovementDurationRangeMs value to make the reset detectable
                $mockConfigNonDefault = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50; MaxFileCount = 50
                                MaxAgeDays = 30; RetentionFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MicroPauseDurationRangeMs      = @(20, 80)
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MovementDurationRangeMs        = @(1000, 2000)
                            ClickDownDurationRangeMs       = @(50, 150)
                            ClickPreDelayRangeMs           = @(50, 200)
                            ClickPostDelayRangeMs          = @(100, 300)
                            PathPointCount                 = 20
                        }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfigNonDefault
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('y')                   # EasingEnabled
                $tc.Input.PushTextWithEnter('y')                   # OvershootEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)             # OvershootFactor
                $tc.Input.PushTextWithEnter('y')                   # MicroPausesEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MicroPauseChance
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MicroPauseDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MicroPauseDurationRangeMs max
                $tc.Input.PushTextWithEnter('y')                   # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)             # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter)             # BezierControlPointOffsetFactor
                $tc.Input.PushTextWithEnter('[Reset to default]')  # MovementDurationRangeMs min → reset entire array
                $tc.Input.PushKey([ConsoleKey]::Enter)             # ClickDownDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)             # ClickDownDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)             # ClickPreDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)             # ClickPreDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)             # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)             # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)             # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::Enter)             # Yes - save now

                Show-MouseControlConfigScreen -Console $tc

                # Default MovementDurationRangeMs is @(200, 600) (from Get-DefaultModuleSettings)
                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.MouseControl.MovementDurationRangeMs[0] -eq 200 -and
                    $Config.MouseControl.MovementDurationRangeMs[1] -eq 600
                }
            }
        }

        It 'Pressing [Reset to default] on the max prompt resets the entire intArray' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                # Use non-default ClickDownDurationRangeMs value to make the reset detectable
                $mockConfigNonDefault = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50; MaxFileCount = 50
                                MaxAgeDays = 30; RetentionFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MicroPauseDurationRangeMs      = @(20, 80)
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MovementDurationRangeMs        = @(200, 600)
                            ClickDownDurationRangeMs       = @(500, 1000)
                            ClickPreDelayRangeMs           = @(50, 200)
                            ClickPostDelayRangeMs          = @(100, 300)
                            PathPointCount                 = 20
                        }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfigNonDefault
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('y')                   # EasingEnabled
                $tc.Input.PushTextWithEnter('y')                   # OvershootEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)             # OvershootFactor
                $tc.Input.PushTextWithEnter('y')                   # MicroPausesEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MicroPauseChance
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MicroPauseDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MicroPauseDurationRangeMs max
                $tc.Input.PushTextWithEnter('y')                   # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)             # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter)             # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MovementDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MovementDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)             # ClickDownDurationRangeMs min
                $tc.Input.PushTextWithEnter('[Reset to default]')  # ClickDownDurationRangeMs max → reset entire array
                $tc.Input.PushKey([ConsoleKey]::Enter)             # ClickPreDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)             # ClickPreDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)             # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)             # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)             # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::Enter)             # Yes - save now

                Show-MouseControlConfigScreen -Console $tc

                # Default ClickDownDurationRangeMs is @(50, 150) (from Get-DefaultModuleSettings)
                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.MouseControl.ClickDownDurationRangeMs[0] -eq 50 -and
                    $Config.MouseControl.ClickDownDurationRangeMs[1] -eq 150
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Reset ALL at the save prompt
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user chooses Reset ALL MouseControl settings to defaults at the save prompt' {

        It 'Calls Save-ModuleSettings exactly once' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50; MaxFileCount = 50
                                MaxAgeDays = 30; RetentionFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MicroPauseDurationRangeMs      = @(20, 80)
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MovementDurationRangeMs        = @(200, 600)
                            ClickDownDurationRangeMs       = @(50, 150)
                            ClickPreDelayRangeMs           = @(50, 200)
                            ClickPostDelayRangeMs          = @(100, 300)
                            PathPointCount                 = 20
                        }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('y')       # EasingEnabled
                $tc.Input.PushTextWithEnter('y')       # OvershootEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # OvershootFactor
                $tc.Input.PushTextWithEnter('y')       # MicroPausesEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseChance
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs max
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter) # Reset ALL MouseControl settings to defaults

                Show-MouseControlConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1
            }
        }

        It 'The config passed to Save-ModuleSettings has bool and numeric keys equal to defaults' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                # Use non-default values so the reset is observable
                $mockConfigNonDefault = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50; MaxFileCount = 50
                                MaxAgeDays = 30; RetentionFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $false
                            OvershootEnabled               = $false
                            OvershootFactor                = 0.9
                            MicroPausesEnabled             = $false
                            MicroPauseChance               = 0.9
                            MicroPauseDurationRangeMs      = @(500, 1000)
                            JitterEnabled                  = $false
                            JitterRadiusPx                 = 15
                            BezierControlPointOffsetFactor = 1.5
                            MovementDurationRangeMs        = @(1000, 2000)
                            ClickDownDurationRangeMs       = @(300, 500)
                            ClickPreDelayRangeMs           = @(300, 600)
                            ClickPostDelayRangeMs          = @(400, 700)
                            PathPointCount                 = 100
                        }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfigNonDefault
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('n')       # EasingEnabled (confirm current false)
                $tc.Input.PushTextWithEnter('n')       # OvershootEnabled (confirm current false)
                $tc.Input.PushKey([ConsoleKey]::Enter) # OvershootFactor
                $tc.Input.PushTextWithEnter('n')       # MicroPausesEnabled (confirm current false)
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseChance
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs max
                $tc.Input.PushTextWithEnter('n')       # JitterEnabled (confirm current false)
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter) # Reset ALL MouseControl settings to defaults

                Show-MouseControlConfigScreen -Console $tc

                # After Reset ALL, the entire MouseControl section is replaced with defaults.
                # Defaults: EasingEnabled = $true, OvershootFactor = 0.1, PathPointCount = 20
                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.MouseControl.EasingEnabled -eq $true -and
                    $Config.MouseControl.OvershootFactor -eq 0.1 -and
                    $Config.MouseControl.PathPointCount -eq 20
                }
            }
        }

        It 'Writes a panel containing "reset" to the console' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50; MaxFileCount = 50
                                MaxAgeDays = 30; RetentionFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MicroPauseDurationRangeMs      = @(20, 80)
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MovementDurationRangeMs        = @(200, 600)
                            ClickDownDurationRangeMs       = @(50, 150)
                            ClickPreDelayRangeMs           = @(50, 200)
                            ClickPostDelayRangeMs          = @(100, 300)
                            PathPointCount                 = 20
                        }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('y')       # EasingEnabled
                $tc.Input.PushTextWithEnter('y')       # OvershootEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # OvershootFactor
                $tc.Input.PushTextWithEnter('y')       # MicroPausesEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseChance
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs max
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter) # Reset ALL MouseControl settings to defaults

                Show-MouseControlConfigScreen -Console $tc

                $tc.Output | Should -Match 'reset'
            }
        }

        It 'Calls Write-LastWarLog with Level Info after reset-all save' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50; MaxFileCount = 50
                                MaxAgeDays = 30; RetentionFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MicroPauseDurationRangeMs      = @(20, 80)
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MovementDurationRangeMs        = @(200, 600)
                            ClickDownDurationRangeMs       = @(50, 150)
                            ClickPreDelayRangeMs           = @(50, 200)
                            ClickPostDelayRangeMs          = @(100, 300)
                            PathPointCount                 = 20
                        }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith $mockConfig
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('y')       # EasingEnabled
                $tc.Input.PushTextWithEnter('y')       # OvershootEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # OvershootFactor
                $tc.Input.PushTextWithEnter('y')       # MicroPausesEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseChance
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseDurationRangeMs max
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # MovementDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickDownDurationRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPreDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter) # Reset ALL MouseControl settings to defaults

                Show-MouseControlConfigScreen -Console $tc

                Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Info' } -Exactly 1
            }
        }
    }
}

