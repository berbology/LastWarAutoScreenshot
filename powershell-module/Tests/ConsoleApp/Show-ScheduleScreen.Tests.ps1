BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force

    # Spectre.Console.Testing.dll ships in lib\test\ and is required for TestConsole
    $testingDll = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}

# ── Helpers ──────────────────────────────────────────────────────────────────

function New-MockTask {
    param([string]$MacroName = 'macro-1')
    [PSCustomObject]@{
        TaskName       = "LWAS_$MacroName"
        MacroName      = $MacroName
        State          = 'Ready'
        NextRunTime    = [datetime]'2026-07-01 09:00'
        LastRunTime    = [datetime]'2026-06-01 09:00'
        LastTaskResult = 0
        LauncherPath   = "$env:APPDATA\LastWarAutoScreenshot\Schedulers\LWAS_$MacroName.ps1"
    }
}

function New-MockMacro {
    param([string]$Name = 'my-macro')
    [PSCustomObject]@{
        FileName    = "20260101_120000_$Name.json"
        FilePath    = "C:\fake\macros\20260101_120000_$Name.json"
        Name        = $Name
        CreatedUtc  = [datetime]'2026-01-01T12:00:00Z'
        DisplayDate = '01/01/26 12:00:00'
        ActionCount = 1
        Valid       = $true
        Metadata    = [PSCustomObject]@{ name = $Name }
        Sequence    = @()
    }
}

function New-ScheduleTestConsole {
    InModuleScope 'LastWarAutoScreenshot' {
        $tc = [Spectre.Console.Testing.TestConsole]::new()
        $tc.Profile.Width  = $script:TestConsoleWidth
        $tc.Profile.Height = $script:TestConsoleHeight
        $tc.Profile.Capabilities.Interactive = $true
        return $tc
    }
}

Describe 'Show-ScheduleScreen' -Tag 'Unit' {

    # ══════════════════════════════════════════════════════════════════════════
    # Context: No tasks configured
    # ══════════════════════════════════════════════════════════════════════════
    Context 'When no scheduled tasks exist' {

        It 'Displays info panel containing "No schedules configured"' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-LWASScheduledTask { @() }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Width  = $script:TestConsoleWidth
                $tc.Profile.Height = $script:TestConsoleHeight
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)  # Back to main menu

                Show-ScheduleScreen -Console $tc
                $tc.Output | Should -Match 'No schedules configured'
            }
        }

        It 'Does not render a task table when no tasks exist' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-LWASScheduledTask { @() }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Width  = $script:TestConsoleWidth
                $tc.Profile.Height = $script:TestConsoleHeight
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)  # Back to main menu

                Show-ScheduleScreen -Console $tc
                # Table column headers only appear when tasks exist
                $tc.Output | Should -Not -Match 'Task Name.*Macro.*Next Run'
            }
        }
    }

    # ══════════════════════════════════════════════════════════════════════════
    # Context: Tasks exist
    # ══════════════════════════════════════════════════════════════════════════
    Context 'When scheduled tasks exist' {

        It 'Renders a task table containing both task names' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-LWASScheduledTask {
                    @(
                        [PSCustomObject]@{
                            TaskName = 'LWAS_macro-1'; MacroName = 'macro-1'
                            State = 'Ready'; NextRunTime = $null; LastRunTime = $null; LastTaskResult = 0
                            LauncherPath = 'C:\fake\LWAS_macro-1.ps1'
                        },
                        [PSCustomObject]@{
                            TaskName = 'LWAS_macro-2'; MacroName = 'macro-2'
                            State = 'Ready'; NextRunTime = $null; LastRunTime = $null; LastTaskResult = 0
                            LauncherPath = 'C:\fake\LWAS_macro-2.ps1'
                        }
                    )
                }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Width  = $script:TestConsoleWidth
                $tc.Profile.Height = $script:TestConsoleHeight
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)  # Back to main menu

                Show-ScheduleScreen -Console $tc
                $tc.Output | Should -Match 'LWAS_macro-1'
                $tc.Output | Should -Match 'LWAS_macro-2'
            }
        }
    }

    # ══════════════════════════════════════════════════════════════════════════
    # Context: Back to main menu
    # ══════════════════════════════════════════════════════════════════════════
    Context 'When the user selects Back to main menu immediately' {

        It 'Returns $null without calling any scheduling cmdlet' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-LWASScheduledTask { @() }
                Mock Register-LWASScheduledTask {}
                Mock Unregister-LWASScheduledTask {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Width  = $script:TestConsoleWidth
                $tc.Profile.Height = $script:TestConsoleHeight
                $tc.Profile.Capabilities.Interactive = $true
                # Action prompt: [0] Create new schedule, [1] Remove a schedule,
                # [2] [[Back to main menu]]
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-ScheduleScreen -Console $tc
                $result | Should -BeNullOrEmpty
                Should -Not -Invoke Register-LWASScheduledTask
                Should -Not -Invoke Unregister-LWASScheduledTask
            }
        }
    }

    # ══════════════════════════════════════════════════════════════════════════
    # Context: Create schedule — no macros available
    # ══════════════════════════════════════════════════════════════════════════
    Context 'Create schedule when no macros are available' {

        It 'Displays error panel and does not call Register-LWASScheduledTask' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-LWASScheduledTask { @() }
                Mock Get-LWASMacro { @() }
                Mock Register-LWASScheduledTask {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Width  = $script:TestConsoleWidth
                $tc.Profile.Height = $script:TestConsoleHeight
                $tc.Profile.Capabilities.Interactive = $true
                # First iteration: Create new schedule (Enter) → shows error → loops back
                # Second iteration: Back to main menu (2×Down + Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)  # Create new schedule
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)  # Back to main menu

                Show-ScheduleScreen -Console $tc
                $tc.Output | Should -Match 'No macros recorded yet'
                Should -Not -Invoke Register-LWASScheduledTask
            }
        }
    }

    # ══════════════════════════════════════════════════════════════════════════
    # Context: Create schedule — select [[Back]] at macro selection
    # ══════════════════════════════════════════════════════════════════════════
    Context 'Create schedule when user selects Back at macro selection' {

        It 'Returns to action prompt without calling Register-LWASScheduledTask' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-LWASScheduledTask { @() }
                Mock Get-LWASMacro {
                    @([PSCustomObject]@{
                        Name = 'my-macro'; DisplayDate = '01/01/26 12:00:00'
                    })
                }
                Mock Register-LWASScheduledTask {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Width  = $script:TestConsoleWidth
                $tc.Profile.Height = $script:TestConsoleHeight
                $tc.Profile.Capabilities.Interactive = $true
                # Create new schedule → macro prompt shows [0] my-macro, [1] [[Back]]
                # Navigate to [[Back]] then select it
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Create new schedule
                $tc.Input.PushKey([ConsoleKey]::DownArrow)   # Navigate to [[Back]]
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Select [[Back]] → loops back to action
                # Now at action prompt again: Back to main menu
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Back to main menu

                Show-ScheduleScreen -Console $tc
                Should -Not -Invoke Register-LWASScheduledTask
            }
        }
    }

    # ══════════════════════════════════════════════════════════════════════════
    # Context: Create schedule — happy path
    # ══════════════════════════════════════════════════════════════════════════
    Context 'Create schedule happy path' {

        It 'Calls Register-LWASScheduledTask once with correct MacroName and ProcessName and shows success panel' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-LWASScheduledTask { @() }
                Mock Get-LWASMacro {
                    @([PSCustomObject]@{ Name = 'my-macro'; DisplayDate = '01/01/26 12:00:00' })
                }
                Mock Register-LWASScheduledTask {
                    [PSCustomObject]@{ Success = $true; TaskName = 'LWAS_my-macro'; MacroName = 'my-macro'; LauncherPath = 'C:\fake\launcher.ps1' }
                }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Width  = $script:TestConsoleWidth
                $tc.Profile.Height = $script:TestConsoleHeight
                $tc.Profile.Capabilities.Interactive = $true

                # Wizard: Create new schedule → my-macro → process → date → 15 min → indefinitely → delay 0 → confirm
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Create new schedule
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # my-macro (first)
                $tc.Input.PushTextWithEnter('lastwar.exe')                    # Process name
                $tc.Input.PushTextWithEnter('01/01/3000 09:00')               # Start date (far future)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)                    # Skip 'Never' (index 0)
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # 15 minutes (index 1)
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Indefinitely
                $tc.Input.PushTextWithEnter('0')                              # Random delay
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Yes - create schedule
                # Loop back to action prompt; exit
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Back to main menu

                Show-ScheduleScreen -Console $tc

                Should -Invoke Register-LWASScheduledTask -Times 1 `
                    -ParameterFilter { $MacroName -eq 'my-macro' -and $ProcessName -eq 'lastwar.exe' }
                $tc.Output | Should -Match 'Schedule Created'
            }
        }
    }

    # ══════════════════════════════════════════════════════════════════════════
    # Context: Create schedule — invalid start date re-prompts
    # ══════════════════════════════════════════════════════════════════════════
    Context 'Create schedule with invalid start date' {

        It 'Displays error markup and re-prompts when date is not parseable' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-LWASScheduledTask { @() }
                Mock Get-LWASMacro {
                    @([PSCustomObject]@{ Name = 'my-macro'; DisplayDate = '01/01/26 12:00:00' })
                }
                Mock Register-LWASScheduledTask {
                    [PSCustomObject]@{ Success = $true; TaskName = 'LWAS_my-macro'; MacroName = 'my-macro'; LauncherPath = 'C:\fake\launcher.ps1' }
                }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Width  = $script:TestConsoleWidth
                $tc.Profile.Height = $script:TestConsoleHeight
                $tc.Profile.Capabilities.Interactive = $true

                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Create new schedule
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # my-macro
                $tc.Input.PushTextWithEnter('lastwar.exe')                    # Process name
                $tc.Input.PushTextWithEnter('not-a-date')                     # Invalid date → error
                $tc.Input.PushTextWithEnter('01/01/3000 09:00')               # Valid date
                $tc.Input.PushKey([ConsoleKey]::DownArrow)                    # Skip 'Never' (index 0)
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # 15 minutes (index 1)
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Indefinitely
                $tc.Input.PushTextWithEnter('0')                              # Delay
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Confirm
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Back to main menu

                Show-ScheduleScreen -Console $tc
                $tc.Output | Should -Match 'Invalid date format'
            }
        }
    }

    # ══════════════════════════════════════════════════════════════════════════
    # Context: Create schedule — Custom interval prompts
    # ══════════════════════════════════════════════════════════════════════════
    Context 'Create schedule with Custom repeat interval' {

        It 'Shows hours and minutes prompts when Custom is selected' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-LWASScheduledTask { @() }
                Mock Get-LWASMacro {
                    @([PSCustomObject]@{ Name = 'my-macro'; DisplayDate = '01/01/26 12:00:00' })
                }
                Mock Register-LWASScheduledTask {
                    [PSCustomObject]@{ Success = $true; TaskName = 'LWAS_my-macro'; MacroName = 'my-macro'; LauncherPath = 'C:\fake\launcher.ps1' }
                }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Width  = $script:TestConsoleWidth
                $tc.Profile.Height = $script:TestConsoleHeight
                $tc.Profile.Capabilities.Interactive = $true

                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Create new schedule
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # my-macro
                $tc.Input.PushTextWithEnter('lastwar.exe')                    # Process name
                $tc.Input.PushTextWithEnter('01/01/3000 09:00')               # Start date
                # Navigate to 'Custom' (index 10 = 10 DownArrows, index 0 is 'Never')
                for ($i = 0; $i -lt 10; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Custom
                $tc.Input.PushTextWithEnter('1')                              # Hours = 1
                $tc.Input.PushTextWithEnter('30')                             # Minutes = 30
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Indefinitely
                $tc.Input.PushTextWithEnter('0')                              # Delay
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Confirm
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Back to main menu

                Show-ScheduleScreen -Console $tc
                $tc.Output | Should -Match 'Hours'
                $tc.Output | Should -Match 'Minutes'
            }
        }

        It 'Shows "Interval must be at least 1 minute" error when hours and minutes are both 0' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-LWASScheduledTask { @() }
                Mock Get-LWASMacro {
                    @([PSCustomObject]@{ Name = 'my-macro'; DisplayDate = '01/01/26 12:00:00' })
                }
                Mock Register-LWASScheduledTask {
                    [PSCustomObject]@{ Success = $true; TaskName = 'LWAS_my-macro'; MacroName = 'my-macro'; LauncherPath = 'C:\fake\launcher.ps1' }
                }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Width  = $script:TestConsoleWidth
                $tc.Profile.Height = $script:TestConsoleHeight
                $tc.Profile.Capabilities.Interactive = $true

                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Create new schedule
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # my-macro
                $tc.Input.PushTextWithEnter('lastwar.exe')                    # Process name
                $tc.Input.PushTextWithEnter('01/01/3000 09:00')               # Start date
                for ($i = 0; $i -lt 10; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Custom
                $tc.Input.PushTextWithEnter('0')                              # Hours = 0 (first attempt)
                $tc.Input.PushTextWithEnter('0')                              # Minutes = 0 → error, re-prompt
                $tc.Input.PushTextWithEnter('1')                              # Hours = 1 (second attempt)
                $tc.Input.PushTextWithEnter('0')                              # Minutes = 0 (second attempt, valid: 60 min total)
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Indefinitely
                $tc.Input.PushTextWithEnter('0')                              # Delay
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Confirm
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Back to main menu

                Show-ScheduleScreen -Console $tc
                $tc.Output | Should -Match 'Interval must be at least 1 minute'
            }
        }

        It 'Calls Register-LWASScheduledTask with RepeatEvery of 90 minutes for 1h 30m custom interval' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-LWASScheduledTask { @() }
                Mock Get-LWASMacro {
                    @([PSCustomObject]@{ Name = 'my-macro'; DisplayDate = '01/01/26 12:00:00' })
                }
                Mock Register-LWASScheduledTask {
                    [PSCustomObject]@{ Success = $true; TaskName = 'LWAS_my-macro'; MacroName = 'my-macro'; LauncherPath = 'C:\fake\launcher.ps1' }
                }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Width  = $script:TestConsoleWidth
                $tc.Profile.Height = $script:TestConsoleHeight
                $tc.Profile.Capabilities.Interactive = $true

                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Create new schedule
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # my-macro
                $tc.Input.PushTextWithEnter('lastwar.exe')                    # Process name
                $tc.Input.PushTextWithEnter('01/01/3000 09:00')               # Start date
                for ($i = 0; $i -lt 10; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Custom
                $tc.Input.PushTextWithEnter('1')                              # Hours = 1
                $tc.Input.PushTextWithEnter('30')                             # Minutes = 30 → 90 min total
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Indefinitely
                $tc.Input.PushTextWithEnter('0')                              # Delay
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Confirm
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Back to main menu

                Show-ScheduleScreen -Console $tc

                Should -Invoke Register-LWASScheduledTask -Times 1 `
                    -ParameterFilter { $RepeatEvery -eq [TimeSpan]::FromMinutes(90) }
            }
        }
    }

    # ══════════════════════════════════════════════════════════════════════════
    # Context: Create schedule — Never repeat
    # ══════════════════════════════════════════════════════════════════════════
    Context 'Create schedule with Never repeat interval' {

        It 'Calls Register-LWASScheduledTask without RepeatEvery and skips duration prompt when Never is selected' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-LWASScheduledTask { @() }
                Mock Get-LWASMacro {
                    @([PSCustomObject]@{ Name = 'my-macro'; DisplayDate = '01/01/26 12:00:00' })
                }
                $capturedBoundParams = $null
                Mock Register-LWASScheduledTask {
                    $script:capturedBoundParams = $PSBoundParameters
                    [PSCustomObject]@{ Success = $true; TaskName = 'LWAS_my-macro'; MacroName = 'my-macro'; LauncherPath = 'C:\fake\launcher.ps1' }
                }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Width  = $script:TestConsoleWidth
                $tc.Profile.Height = $script:TestConsoleHeight
                $tc.Profile.Capabilities.Interactive = $true

                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Create new schedule
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # my-macro (first)
                $tc.Input.PushTextWithEnter('lastwar.exe')                    # Process name
                $tc.Input.PushTextWithEnter('01/01/3000 09:00')               # Start date (far future)
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Never (index 0)
                # No duration prompt expected (skipped for Never)
                $tc.Input.PushTextWithEnter('0')                              # Random delay
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Yes - create schedule
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Back to main menu

                Show-ScheduleScreen -Console $tc

                Should -Invoke Register-LWASScheduledTask -Times 1
                $script:capturedBoundParams.ContainsKey('RepeatEvery') | Should -BeFalse
                $tc.Output | Should -Match 'Schedule Created'
            }
        }
    }

    # ══════════════════════════════════════════════════════════════════════════
    # Context: Create schedule — invalid random delay re-prompts
    # ══════════════════════════════════════════════════════════════════════════
    Context 'Create schedule with invalid random delay' {

        It 'Shows error and re-prompts when random delay is out of range (150)' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-LWASScheduledTask { @() }
                Mock Get-LWASMacro {
                    @([PSCustomObject]@{ Name = 'my-macro'; DisplayDate = '01/01/26 12:00:00' })
                }
                Mock Register-LWASScheduledTask {
                    [PSCustomObject]@{ Success = $true; TaskName = 'LWAS_my-macro'; MacroName = 'my-macro'; LauncherPath = 'C:\fake\launcher.ps1' }
                }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Width  = $script:TestConsoleWidth
                $tc.Profile.Height = $script:TestConsoleHeight
                $tc.Profile.Capabilities.Interactive = $true

                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Create new schedule
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # my-macro
                $tc.Input.PushTextWithEnter('lastwar.exe')                    # Process name
                $tc.Input.PushTextWithEnter('01/01/3000 09:00')               # Start date
                $tc.Input.PushKey([ConsoleKey]::DownArrow)                    # Skip 'Never' (index 0)
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # 15 minutes (index 1)
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Indefinitely
                $tc.Input.PushTextWithEnter('150')                            # Invalid delay → error
                $tc.Input.PushTextWithEnter('0')                              # Valid delay
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Confirm
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)                        # Back to main menu

                Show-ScheduleScreen -Console $tc
                $tc.Output | Should -Match 'Random delay must be'
            }
        }
    }

    # ══════════════════════════════════════════════════════════════════════════
    # Context: Remove schedule
    # ══════════════════════════════════════════════════════════════════════════
    Context 'Remove schedule' {

        It 'Calls Unregister-LWASScheduledTask with correct macro name when user confirms removal' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-LWASScheduledTask {
                    @([PSCustomObject]@{
                        TaskName = 'LWAS_my-macro'; MacroName = 'my-macro'
                        State = 'Ready'; NextRunTime = $null; LastRunTime = $null; LastTaskResult = 0
                        LauncherPath = 'C:\fake\LWAS_my-macro.ps1'
                    })
                }
                Mock Unregister-LWASScheduledTask {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Width  = $script:TestConsoleWidth
                $tc.Profile.Height = $script:TestConsoleHeight
                $tc.Profile.Capabilities.Interactive = $true

                # Action: Remove a schedule (Down + Enter)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Remove a schedule
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Select LWAS_my-macro (first)
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Yes - remove
                # Loop back; exit
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Back to main menu

                Show-ScheduleScreen -Console $tc

                Should -Invoke Unregister-LWASScheduledTask -Times 1 `
                    -ParameterFilter { $MacroName -eq 'my-macro' }
            }
        }

        It 'Does not call Unregister-LWASScheduledTask when user selects No - go back' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-LWASScheduledTask {
                    @([PSCustomObject]@{
                        TaskName = 'LWAS_my-macro'; MacroName = 'my-macro'
                        State = 'Ready'; NextRunTime = $null; LastRunTime = $null; LastTaskResult = 0
                        LauncherPath = 'C:\fake\LWAS_my-macro.ps1'
                    })
                }
                Mock Unregister-LWASScheduledTask {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Width  = $script:TestConsoleWidth
                $tc.Profile.Height = $script:TestConsoleHeight
                $tc.Profile.Capabilities.Interactive = $true

                # Action: Remove a schedule
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Remove a schedule
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Select LWAS_my-macro
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)    # No - go back
                # Back at action prompt
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Back to main menu

                Show-ScheduleScreen -Console $tc

                Should -Not -Invoke Unregister-LWASScheduledTask
            }
        }
    }
}
