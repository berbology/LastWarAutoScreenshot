BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force

    # Spectre.Console.Testing.dll is required for TestConsole
    $testingDll = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}

Describe 'Start-LastWarAutoScreenshot' {

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
                { Start-LastWarAutoScreenshot -Console $tc } | Should -Not -Throw
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
                Start-LastWarAutoScreenshot -Console $tc

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
                Start-LastWarAutoScreenshot -Console $tc

                Should -Invoke Invoke-StartupConfigValidation -Exactly 1
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
                Start-LastWarAutoScreenshot -Console $tc

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
                Start-LastWarAutoScreenshot -Console $tc

                $tc.Output | Should -Match 'Logging.MinimumLogLevel'
            }
        }
    }

    Context 'Screen dispatch' {

        It 'Calls Show-WindowSelectionScreen exactly once when Show-MainMenu returns SelectWindow then Exit' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-InAlternateScreen -MockWith {
                    param([Spectre.Console.IAnsiConsole]$Console, [scriptblock]$Action)
                    & $Action $Console
                }
                Mock Invoke-StartupConfigValidation -MockWith {
                    [PSCustomObject]@{ HasErrors = $false; Messages = @() }
                }
                Mock Show-WindowSelectionScreen -MockWith { $null }
                $script:_menuCallCount = 0
                Mock Show-MainMenu -MockWith {
                    $script:_menuCallCount++
                    if ($script:_menuCallCount -eq 1) { 'SelectWindow' } else { 'Exit' }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                Start-LastWarAutoScreenshot -Console $tc

                Should -Invoke Show-WindowSelectionScreen -Exactly 1
            }
        }

        It 'Does not call Show-WindowSelectionScreen when Show-MainMenu returns Exit immediately' {
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
                Start-LastWarAutoScreenshot -Console $tc

                Should -Not -Invoke Show-WindowSelectionScreen
            }
        }

        It 'Writes the stub panel to Console when Show-MainMenu returns RecordMacro' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-InAlternateScreen -MockWith {
                    param([Spectre.Console.IAnsiConsole]$Console, [scriptblock]$Action)
                    & $Action $Console
                }
                Mock Invoke-StartupConfigValidation -MockWith {
                    [PSCustomObject]@{ HasErrors = $false; Messages = @() }
                }
                $script:_stubMenuCallCount = 0
                Mock Show-MainMenu -MockWith {
                    $script:_stubMenuCallCount++
                    if ($script:_stubMenuCallCount -eq 1) { 'RecordMacro' } else { 'Exit' }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                Start-LastWarAutoScreenshot -Console $tc

                $tc.Output | Should -Match 'not yet available'
            }
        }
    }

    Context 'Console parameter' {

        It 'Console parameter exists and is not mandatory (supports default value)' {
            $fn = Get-Command -Name 'Start-LastWarAutoScreenshot'
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
                Start-LastWarAutoScreenshot -Console $tc

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

