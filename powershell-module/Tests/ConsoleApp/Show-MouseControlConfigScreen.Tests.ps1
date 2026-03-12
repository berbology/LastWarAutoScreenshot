BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force

    # Spectre.Console.Testing.dll ships in lib\test\ and is required for TestConsole
    $testingDll = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}

Describe 'Show-MouseControlConfigScreen' -Tag 'Unit' {

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
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MinMicroPauseDurationMs        = 20
                            MaxMicroPauseDurationMs        = 80
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MinMovementDurationMs          = 200
                            MaxMovementDurationMs          = 600
                            MinClickDownDurationMs    = 50
                            MaxClickDownDurationMs    = 150
                            MinClickPreDelayMs             = 50
                            MaxClickPreDelayMs             = 200
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
                # Bool keys: y × 4, non-bool keys: Enter × 15 (3 double+6 int+2×2 intArray)
                $tc.Input.PushTextWithEnter('y')       # EasingEnabled
                $tc.Input.PushTextWithEnter('y')       # OvershootEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # OvershootFactor
                $tc.Input.PushTextWithEnter('y')       # MicroPausesEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # MicroPauseChance
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMicroPauseDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMicroPauseDurationMs
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter) # Discard

                Show-MouseControlConfigScreen -Console $tc

                # Patterns use (?s) to match across newlines (table text wraps due to column width)
                $tc.Output | Should -Match '(?s)Easin.*gEnabled'
                $tc.Output | Should -Match '(?s)Overs.*hootEnab.*led'
                $tc.Output | Should -Match '(?s)Overs.*hootFactor'
                $tc.Output | Should -Match '(?s)Micro.*Pause.*Enabled'
                $tc.Output | Should -Match '(?s)Micro.*Pause.*Chance'
                $tc.Output | Should -Match '(?s)MinMi.*croPause.*DurationMs'
                $tc.Output | Should -Match '(?s)MaxMi.*croPause.*DurationMs'
                $tc.Output | Should -Match '(?s)Jitte.*rEnabled'
                $tc.Output | Should -Match '(?s)Jitte.*rRadiusPx'
                $tc.Output | Should -Match '(?s)Bezie.*rControl.*PointOffse.*tFactor'
                $tc.Output | Should -Match '(?s)MinMo.*vementDu.*rationMs'
                $tc.Output | Should -Match '(?s)MaxMo.*vementDu.*rationMs'
                $tc.Output | Should -Match '(?s)MouseControl.MinCl.*ickDownD.*urationMs'
                $tc.Output | Should -Match '(?s)MaxCl.*ickDown.*DurationMs'
                $tc.Output | Should -Match '(?s)MinCl.*ickPreD.*elayMs'
                $tc.Output | Should -Match '(?s)MaxCl.*ickPreD.*elayMs'
                $tc.Output | Should -Match '(?s)MinCl.*ickPostD.*elayMs'
                $tc.Output | Should -Match '(?s)MaxCl.*ickPostD.*elayMs'
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
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MinMicroPauseDurationMs        = 20
                            MaxMicroPauseDurationMs        = 80
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MinMovementDurationMs          = 200
                            MaxMovementDurationMs          = 600
                            MinClickDownDurationMs    = 50
                            MaxClickDownDurationMs    = 150
                            MinClickPreDelayMs             = 50
                            MaxClickPreDelayMs             = 200
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
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMicroPauseDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMicroPauseDurationMs
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter) # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter) # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter) # Discard

                Show-MouseControlConfigScreen -Console $tc

                # Numeric values and array values should appear in the rendered table
                $tc.Output | Should -Match '0.1'    # OvershootFactor
                $tc.Output | Should -Match '20'     # part of MinMicroPauseDurationMs
                $tc.Output | Should -Match '200'    # part of MinMovementDurationMs
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
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MinMicroPauseDurationMs        = 20
                            MaxMicroPauseDurationMs        = 80
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MinMovementDurationMs          = 200
                            MaxMovementDurationMs          = 600
                            MinClickDownDurationMs    = 50
                            MaxClickDownDurationMs    = 150
                            MinClickPreDelayMs             = 50
                            MaxClickPreDelayMs             = 200
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
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMicroPauseDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMicroPauseDurationMs
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickPreDelayMs
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
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MinMicroPauseDurationMs        = 20
                            MaxMicroPauseDurationMs        = 80
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MinMovementDurationMs          = 200
                            MaxMovementDurationMs          = 600
                            MinClickDownDurationMs    = 50
                            MaxClickDownDurationMs    = 150
                            MinClickPreDelayMs             = 50
                            MaxClickPreDelayMs             = 200
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
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMicroPauseDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMicroPauseDurationMs
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickPreDelayMs
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
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MinMicroPauseDurationMs        = 20
                            MaxMicroPauseDurationMs        = 80
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MinMovementDurationMs          = 200
                            MaxMovementDurationMs          = 600
                            MinClickDownDurationMs    = 50
                            MaxClickDownDurationMs    = 150
                            MinClickPreDelayMs             = 50
                            MaxClickPreDelayMs             = 200
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
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMicroPauseDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMicroPauseDurationMs
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickPreDelayMs
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
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MinMicroPauseDurationMs        = 20
                            MaxMicroPauseDurationMs        = 80
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MinMovementDurationMs          = 200
                            MaxMovementDurationMs          = 600
                            MinClickDownDurationMs    = 50
                            MaxClickDownDurationMs    = 150
                            MinClickPreDelayMs             = 50
                            MaxClickPreDelayMs             = 200
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
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMicroPauseDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMicroPauseDurationMs
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickPreDelayMs
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
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MinMicroPauseDurationMs        = 20
                            MaxMicroPauseDurationMs        = 80
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MinMovementDurationMs          = 200
                            MaxMovementDurationMs          = 600
                            MinClickDownDurationMs    = 50
                            MaxClickDownDurationMs    = 150
                            MinClickPreDelayMs             = 50
                            MaxClickPreDelayMs             = 200
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
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMicroPauseDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMicroPauseDurationMs
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickPreDelayMs
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
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MinMicroPauseDurationMs        = 20
                            MaxMicroPauseDurationMs        = 80
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MinMovementDurationMs          = 200
                            MaxMovementDurationMs          = 600
                            MinClickDownDurationMs    = 50
                            MaxClickDownDurationMs    = 150
                            MinClickPreDelayMs             = 50
                            MaxClickPreDelayMs             = 200
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
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMicroPauseDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMicroPauseDurationMs
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickPreDelayMs
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
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MinMicroPauseDurationMs        = 20
                            MaxMicroPauseDurationMs        = 80
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MinMovementDurationMs          = 200
                            MaxMovementDurationMs          = 600
                            MinClickDownDurationMs    = 50
                            MaxClickDownDurationMs    = 150
                            MinClickPreDelayMs             = 50
                            MaxClickPreDelayMs             = 200
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
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMicroPauseDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMicroPauseDurationMs
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickPreDelayMs
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
    # Context: Valid new int values for MinMovementDurationMs and MaxMovementDurationMs
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user enters valid new int values for MinMovementDurationMs and MaxMovementDurationMs' {

        It 'The saved config contains the new scalar values' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockConfig = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MinMicroPauseDurationMs        = 20
                            MaxMicroPauseDurationMs        = 80
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MinMovementDurationMs          = 200
                            MaxMovementDurationMs          = 600
                            MinClickDownDurationMs    = 50
                            MaxClickDownDurationMs    = 150
                            MinClickPreDelayMs             = 50
                            MaxClickPreDelayMs             = 200
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
                $tc.Input.PushKey([ConsoleKey]::Enter)    # MinMicroPauseDurationMs (keep 20)
                $tc.Input.PushKey([ConsoleKey]::Enter)    # MaxMicroPauseDurationMs (keep 80)
                $tc.Input.PushTextWithEnter('y')          # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)    # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter)    # BezierControlPointOffsetFactor
                $tc.Input.PushTextWithEnter('100')        # MinMovementDurationMs = 100
                $tc.Input.PushTextWithEnter('400')        # MaxMovementDurationMs = 400
                $tc.Input.PushKey([ConsoleKey]::Enter)    # MinClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter)    # MaxClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter)    # MinClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter)    # MaxClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter)    # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)    # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)    # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Yes - save now

                Show-MouseControlConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.MouseControl.MinMovementDurationMs -eq 100 -and
                    $Config.MouseControl.MaxMovementDurationMs -eq 400
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
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.9
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MinMicroPauseDurationMs        = 20
                            MaxMicroPauseDurationMs        = 80
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MinMovementDurationMs          = 200
                            MaxMovementDurationMs          = 600
                            MinClickDownDurationMs    = 50
                            MaxClickDownDurationMs    = 150
                            MinClickPreDelayMs             = 50
                            MaxClickPreDelayMs             = 200
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
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MinMicroPauseDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MaxMicroPauseDurationMs
                $tc.Input.PushTextWithEnter('y')                   # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)             # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter)             # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MinMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MaxMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MinClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MaxClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MinClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MaxClickPreDelayMs
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
    # Context: [Reset to default] sentinel for the MinMovementDurationMs int key
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user enters [Reset to default] for the MinMovementDurationMs int key' {

        It 'The saved config contains the schema default value for MinMovementDurationMs' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                # Use non-default MinMovementDurationMs value to make the reset detectable
                $mockConfigNonDefault = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MinMicroPauseDurationMs        = 20
                            MaxMicroPauseDurationMs        = 80
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MinMovementDurationMs          = 1000
                            MaxMovementDurationMs          = 2000
                            MinClickDownDurationMs    = 50
                            MaxClickDownDurationMs    = 150
                            MinClickPreDelayMs             = 50
                            MaxClickPreDelayMs             = 200
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
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MinMicroPauseDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MaxMicroPauseDurationMs
                $tc.Input.PushTextWithEnter('y')                   # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)             # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter)             # BezierControlPointOffsetFactor
                $tc.Input.PushTextWithEnter('[Reset to default]')  # MinMovementDurationMs → reset to default (200)
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MaxMovementDurationMs → keep current (2000)
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MinClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MaxClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MinClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MaxClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter)             # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)             # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)             # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::Enter)             # Yes - save now

                Show-MouseControlConfigScreen -Console $tc

                # Default MinMovementDurationMs is 200 (from Get-DefaultModuleSettings)
                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.MouseControl.MinMovementDurationMs -eq 200 -and
                    $Config.MouseControl.MaxMovementDurationMs -eq 2000
                }
            }
        }

        It 'Pressing [Reset to default] on MaxClickDownDurationMs resets that key to its default' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                # Use non-default MinClickDownDurationMs/MaxClickDownDurationMs values to make the reset detectable
                $mockConfigNonDefault = {
                    [PSCustomObject]@{
                        Logging = [PSCustomObject]@{
                            MinimumLogLevel = 'Info'
                            Backend         = 'File'
                            FileBackend     = [PSCustomObject]@{
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MinMicroPauseDurationMs        = 20
                            MaxMicroPauseDurationMs        = 80
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MinMovementDurationMs          = 200
                            MaxMovementDurationMs          = 600
                            MinClickDownDurationMs    = 500
                            MaxClickDownDurationMs    = 1000
                            MinClickPreDelayMs             = 50
                            MaxClickPreDelayMs             = 200
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
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MinMicroPauseDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MaxMicroPauseDurationMs
                $tc.Input.PushTextWithEnter('y')                   # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter)             # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter)             # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MinMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MaxMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MinClickDownDurationMs (keep 500)
                $tc.Input.PushTextWithEnter('[Reset to default]')  # MaxClickDownDurationMs → reset to default (150)
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MinClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter)             # MaxClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter)             # ClickPostDelayRangeMs min
                $tc.Input.PushKey([ConsoleKey]::Enter)             # ClickPostDelayRangeMs max
                $tc.Input.PushKey([ConsoleKey]::Enter)             # PathPointCount
                $tc.Input.PushKey([ConsoleKey]::Enter)             # Yes - save now

                Show-MouseControlConfigScreen -Console $tc

                # MinClickDownDurationMs (500) is kept; MaxClickDownDurationMs is reset to default (150)
                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.MouseControl.MinClickDownDurationMs -eq 500 -and
                    $Config.MouseControl.MaxClickDownDurationMs -eq 150
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
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MinMicroPauseDurationMs        = 20
                            MaxMicroPauseDurationMs        = 80
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MinMovementDurationMs          = 200
                            MaxMovementDurationMs          = 600
                            MinClickDownDurationMs    = 50
                            MaxClickDownDurationMs    = 150
                            MinClickPreDelayMs             = 50
                            MaxClickPreDelayMs             = 200
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
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMicroPauseDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMicroPauseDurationMs
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickPreDelayMs
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
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $false
                            OvershootEnabled               = $false
                            OvershootFactor                = 0.9
                            MicroPausesEnabled             = $false
                            MicroPauseChance               = 0.9
                            MinMicroPauseDurationMs        = 500
                            MaxMicroPauseDurationMs        = 1000
                            JitterEnabled                  = $false
                            JitterRadiusPx                 = 15
                            BezierControlPointOffsetFactor = 1.5
                            MinMovementDurationMs          = 1000
                            MaxMovementDurationMs          = 2000
                            MinClickDownDurationMs    = 300
                            MaxClickDownDurationMs    = 500
                            MinClickPreDelayMs             = 300
                            MaxClickPreDelayMs             = 600
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
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMicroPauseDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMicroPauseDurationMs
                $tc.Input.PushTextWithEnter('n')       # JitterEnabled (confirm current false)
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickPreDelayMs
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
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MinMicroPauseDurationMs        = 20
                            MaxMicroPauseDurationMs        = 80
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MinMovementDurationMs          = 200
                            MaxMovementDurationMs          = 600
                            MinClickDownDurationMs    = 50
                            MaxClickDownDurationMs    = 150
                            MinClickPreDelayMs             = 50
                            MaxClickPreDelayMs             = 200
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
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMicroPauseDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMicroPauseDurationMs
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickPreDelayMs
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
                                MaxSizeMB = 50
                                MaxAgeDays = 30; MaxLogFileCount = 500
                            }
                        }
                        MouseControl = [PSCustomObject]@{
                            EasingEnabled                  = $true
                            OvershootEnabled               = $true
                            OvershootFactor                = 0.1
                            MicroPausesEnabled             = $true
                            MicroPauseChance               = 0.2
                            MinMicroPauseDurationMs        = 20
                            MaxMicroPauseDurationMs        = 80
                            JitterEnabled                  = $true
                            JitterRadiusPx                 = 2
                            BezierControlPointOffsetFactor = 0.3
                            MinMovementDurationMs          = 200
                            MaxMovementDurationMs          = 600
                            MinClickDownDurationMs    = 50
                            MaxClickDownDurationMs    = 150
                            MinClickPreDelayMs             = 50
                            MaxClickPreDelayMs             = 200
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
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMicroPauseDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMicroPauseDurationMs
                $tc.Input.PushTextWithEnter('y')       # JitterEnabled
                $tc.Input.PushKey([ConsoleKey]::Enter) # JitterRadiusPx
                $tc.Input.PushKey([ConsoleKey]::Enter) # BezierControlPointOffsetFactor
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxMovementDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickDownDurationMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MinClickPreDelayMs
                $tc.Input.PushKey([ConsoleKey]::Enter) # MaxClickPreDelayMs
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

