BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force

    # Spectre.Console.Testing.dll is required for TestConsole
    $testingDll = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}

Describe 'Start-LWASConsole' -Tag 'Unit' {

    BeforeEach {
        # All tests need deterministic mocks for the window-clearing calls that now
        # run on every invocation of Start-LWASConsole.
        InModuleScope -ModuleName 'LastWarAutoScreenshot' {
            Mock Get-ModuleConfiguration -MockWith {
                [PSCustomObject]@{
                    ProcessName   = 'LastWar'
                    WindowTitle   = 'Last War: Survival'
                    Logging       = [PSCustomObject]@{}
                    MouseControl  = [PSCustomObject]@{}
                    EmergencyStop = [PSCustomObject]@{}
                    Screenshots   = [PSCustomObject]@{}
                    CodeEditor    = ''
                }
            }
            Mock Save-ModuleSettings -MockWith { $true }
        }
    }

    Context 'Loop lifecycle' {

        It 'Exits cleanly without exception when Show-MainMenu returns Exit immediately' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-InAlternateScreen -MockWith {
                    param([Spectre.Console.IAnsiConsole]$Console, [scriptblock]$Action)
                    & $Action $Console
                }
                Mock Invoke-StartupConfigValidation -MockWith {
                    [PSCustomObject]@{ HasErrors = $false; Messages = @() }
                }
                Mock Show-MainMenu -MockWith { 'Exit' }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                { Start-LWASConsole -Console $tc } | Should -Not -Throw
            }
        }

        It 'Calls Show-MainMenu exactly once when it returns Exit on the first call' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-InAlternateScreen -MockWith {
                    param([Spectre.Console.IAnsiConsole]$Console, [scriptblock]$Action)
                    & $Action $Console
                }
                Mock Invoke-StartupConfigValidation -MockWith {
                    [PSCustomObject]@{ HasErrors = $false; Messages = @() }
                }
                Mock Show-MainMenu -MockWith { 'Exit' }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                Start-LWASConsole -Console $tc

                Should -Invoke Show-MainMenu -Exactly 1
            }
        }

        It 'Calls Invoke-StartupConfigValidation exactly once before entering the loop' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-InAlternateScreen -MockWith {
                    param([Spectre.Console.IAnsiConsole]$Console, [scriptblock]$Action)
                    & $Action $Console
                }
                Mock Invoke-StartupConfigValidation -MockWith {
                    [PSCustomObject]@{ HasErrors = $false; Messages = @() }
                }
                Mock Show-MainMenu -MockWith { 'Exit' }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                Start-LWASConsole -Console $tc

                Should -Invoke Invoke-StartupConfigValidation -Exactly 1
            }
        }
    }

    Context 'Window config reset on startup' {

        It 'Calls Save-ModuleSettings exactly once to clear the window target before entering the loop' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-InAlternateScreen -MockWith {
                    param([Spectre.Console.IAnsiConsole]$Console, [scriptblock]$Action)
                    & $Action $Console
                }
                Mock Invoke-StartupConfigValidation -MockWith {
                    [PSCustomObject]@{ HasErrors = $false; Messages = @() }
                }
                Mock Show-MainMenu -MockWith { 'Exit' }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                Start-LWASConsole -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1
            }
        }

        It 'Saves a settings-only config (no ProcessName) to clear the window target' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-InAlternateScreen -MockWith {
                    param([Spectre.Console.IAnsiConsole]$Console, [scriptblock]$Action)
                    & $Action $Console
                }
                Mock Invoke-StartupConfigValidation -MockWith {
                    [PSCustomObject]@{ HasErrors = $false; Messages = @() }
                }
                Mock Show-MainMenu -MockWith { 'Exit' }
                $savedConfig = $null
                Mock Save-ModuleSettings -MockWith {
                    param([PSCustomObject]$Config)
                    $script:savedConfig = $Config
                    $true
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                Start-LWASConsole -Console $tc

                $script:savedConfig | Should -Not -BeNullOrEmpty
                $script:savedConfig.PSObject.Properties['ProcessName'] | Should -BeNullOrEmpty
                $script:savedConfig.PSObject.Properties['WindowTitle']  | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Startup validation output' {

        It 'Does not write error markup to output when validation reports no errors' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-InAlternateScreen -MockWith {
                    param([Spectre.Console.IAnsiConsole]$Console, [scriptblock]$Action)
                    & $Action $Console
                }
                Mock Invoke-StartupConfigValidation -MockWith {
                    [PSCustomObject]@{ HasErrors = $false; Messages = @() }
                }
                Mock Show-MainMenu -MockWith { 'Exit' }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                Start-LWASConsole -Console $tc

                $tc.Output | Should -Not -Match 'Configuration Error'
            }
        }

        It 'Error panel content appears in output when validation mock writes a panel to Console' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-InAlternateScreen -MockWith {
                    param([Spectre.Console.IAnsiConsole]$Console, [scriptblock]$Action)
                    & $Action $Console
                }
                Mock Show-MainMenu -MockWith { 'Exit' }
                # Simulate what the real Invoke-StartupConfigValidation does on failure:
                # it writes a panel directly to $Console before returning
                Mock Invoke-StartupConfigValidation -MockWith {
                    param([Spectre.Console.IAnsiConsole]$Console)
                    $panel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                        'Logging.MinimumLogLevel: invalid value',
                        '[red]Configuration Error[/]'
                    )
                    $Console.Write($panel)
                    [PSCustomObject]@{ HasErrors = $true; Messages = @('Logging.MinimumLogLevel: invalid value') }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                Start-LWASConsole -Console $tc

                $tc.Output | Should -Match 'Logging.MinimumLogLevel'
            }
        }
    }

    Context 'Screen dispatch' {

        It 'Does not call Show-WindowSelectionScreen from the main dispatch loop when Show-MainMenu returns Exit' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-InAlternateScreen -MockWith {
                    param([Spectre.Console.IAnsiConsole]$Console, [scriptblock]$Action)
                    & $Action $Console
                }
                Mock Invoke-StartupConfigValidation -MockWith {
                    [PSCustomObject]@{ HasErrors = $false; Messages = @() }
                }
                Mock Show-MainMenu -MockWith { 'Exit' }
                Mock Show-WindowSelectionScreen -MockWith { $null }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                Start-LWASConsole -Console $tc

                Should -Not -Invoke Show-WindowSelectionScreen
            }
        }

        It 'Calls Show-RecordMacroScreen exactly once when Show-MainMenu returns RecordMacro then Exit' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-InAlternateScreen -MockWith {
                    param([Spectre.Console.IAnsiConsole]$Console, [scriptblock]$Action)
                    & $Action $Console
                }
                Mock Invoke-StartupConfigValidation -MockWith {
                    [PSCustomObject]@{ HasErrors = $false; Messages = @() }
                }
                Mock Show-RecordMacroScreen -MockWith { $null }
                $script:_recordMenuCallCount = 0
                Mock Show-MainMenu -MockWith {
                    $script:_recordMenuCallCount++
                    if ($script:_recordMenuCallCount -eq 1) { 'RecordMacro' } else { 'Exit' }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                Start-LWASConsole -Console $tc

                Should -Invoke Show-RecordMacroScreen -Exactly 1
            }
        }

        It 'Calls Show-RunMacroScreen exactly once when Show-MainMenu returns RunMacro then Exit' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-InAlternateScreen -MockWith {
                    param([Spectre.Console.IAnsiConsole]$Console, [scriptblock]$Action)
                    & $Action $Console
                }
                Mock Invoke-StartupConfigValidation -MockWith {
                    [PSCustomObject]@{ HasErrors = $false; Messages = @() }
                }
                Mock Show-RunMacroScreen -MockWith { $null }
                $script:_runMenuCallCount = 0
                Mock Show-MainMenu -MockWith {
                    $script:_runMenuCallCount++
                    if ($script:_runMenuCallCount -eq 1) { 'RunMacro' } else { 'Exit' }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                Start-LWASConsole -Console $tc

                Should -Invoke Show-RunMacroScreen -Exactly 1
            }
        }

        It 'Calls Show-StorageInfoScreen exactly once when Show-MainMenu returns StorageInfo then Exit' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-InAlternateScreen -MockWith {
                    param([Spectre.Console.IAnsiConsole]$Console, [scriptblock]$Action)
                    & $Action $Console
                }
                Mock Invoke-StartupConfigValidation -MockWith {
                    [PSCustomObject]@{ HasErrors = $false; Messages = @() }
                }
                Mock Show-StorageInfoScreen -MockWith { $null }
                $script:_storageMenuCallCount = 0
                Mock Show-MainMenu -MockWith {
                    $script:_storageMenuCallCount++
                    if ($script:_storageMenuCallCount -eq 1) { 'StorageInfo' } else { 'Exit' }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                Start-LWASConsole -Console $tc

                Should -Invoke Show-StorageInfoScreen -Exactly 1
            }
        }

        It 'Calls Show-ScheduleScreen exactly once when Show-MainMenu returns ManageSchedules then Exit' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-InAlternateScreen -MockWith {
                    param([Spectre.Console.IAnsiConsole]$Console, [scriptblock]$Action)
                    & $Action $Console
                }
                Mock Invoke-StartupConfigValidation -MockWith {
                    [PSCustomObject]@{ HasErrors = $false; Messages = @() }
                }
                Mock Show-ScheduleScreen -MockWith { $null }
                $script:_scheduleMenuCallCount = 0
                Mock Show-MainMenu -MockWith {
                    $script:_scheduleMenuCallCount++
                    if ($script:_scheduleMenuCallCount -eq 1) { 'ManageSchedules' } else { 'Exit' }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                Start-LWASConsole -Console $tc

                Should -Invoke Show-ScheduleScreen -Exactly 1
            }
        }

        It 'Calls Show-ManageMacrosScreen exactly once when Show-MainMenu returns ManageMacros then Exit' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-InAlternateScreen -MockWith {
                    param([Spectre.Console.IAnsiConsole]$Console, [scriptblock]$Action)
                    & $Action $Console
                }
                Mock Invoke-StartupConfigValidation -MockWith {
                    [PSCustomObject]@{ HasErrors = $false; Messages = @() }
                }
                Mock Show-ManageMacrosScreen -MockWith { $null }
                $script:_manageMenuCallCount = 0
                Mock Show-MainMenu -MockWith {
                    $script:_manageMenuCallCount++
                    if ($script:_manageMenuCallCount -eq 1) { 'ManageMacros' } else { 'Exit' }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                Start-LWASConsole -Console $tc

                Should -Invoke Show-ManageMacrosScreen -Exactly 1
            }
        }
    }

    Context 'Console parameter' {

        It 'Console parameter exists and is not mandatory (supports default value)' {
            $fn = Get-Command -Name 'Start-LWASConsole'
            $consoleParam = $fn.Parameters['Console']
            $consoleParam | Should -Not -BeNullOrEmpty
            $consoleParam.Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                Select-Object -ExpandProperty Mandatory |
                Should -BeFalse
        }
    }

    Context 'Title figlet output' {

        It 'Writes the application title to the console before entering the menu loop' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-InAlternateScreen -MockWith {
                    param([Spectre.Console.IAnsiConsole]$Console, [scriptblock]$Action)
                    & $Action $Console
                }
                Mock Invoke-StartupConfigValidation -MockWith {
                    [PSCustomObject]@{ HasErrors = $false; Messages = @() }
                }
                Mock Show-MainMenu -MockWith { 'Exit' }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                Start-LWASConsole -Console $tc

                # Figlet renders ASCII art across multiple lines, so the literal string
                # "Last War Auto Screenshot" doesn't appear contiguously. Instead, verify
                # that the panel containing the figlet was rendered by checking for panel borders.
                $tc.Output | Should -Match '┌───'
            }
        }
    }

    Context 'Invoke-MainAppLoop removed' {

        It 'Invoke-MainAppLoop does not exist as a command in the module' {
            $cmd = Get-Command -Name 'Invoke-MainAppLoop' -ErrorAction SilentlyContinue
            $cmd | Should -BeNullOrEmpty
        }
    }
}

