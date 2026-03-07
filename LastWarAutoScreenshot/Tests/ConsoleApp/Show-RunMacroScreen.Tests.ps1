BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force

    # Spectre.Console.Testing.dll ships in lib\test\ and is required for TestConsole
    $testingDll = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}

Describe 'Show-RunMacroScreen' -Tag 'Unit' {

    # ════════════════════════════════════════════════════════════════════════
    # Context: No macros saved
    # ════════════════════════════════════════════════════════════════════════
    Context 'When no macros are saved' {

        It 'Returns $null and output contains "No macros saved"' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList -MockWith { @() }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true

                $result = Show-RunMacroScreen -Console $tc
                $result | Should -BeNullOrEmpty
                $tc.Output | Should -Match 'No macros saved'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Back to main menu
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user selects Back to main menu from the macro list' {

        It 'Does not call Invoke-MacroSequence and returns $null' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList -MockWith {
                    @([PSCustomObject]@{
                        FileName    = '20240101_120000_test-macro.json'
                        FilePath    = 'C:\test\Macros\20240101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = '2024-01-01T12:00:00Z'
                        DisplayDate = '01/01/24 12:00:00'
                        ActionCount = 1
                        Valid       = $true
                    })
                }
                Mock Get-MacroFile -MockWith {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version  = '1.0'
                            metadata = [PSCustomObject]@{
                                name        = 'test-macro'
                                createdUtc  = '2024-01-01T12:00:00Z'
                                modifiedUtc = '2024-01-01T12:00:00Z'
                            }
                            targetWindow = [PSCustomObject]@{ processName = 'game.exe'; windowTitle = 'Game' }
                            sequence     = @([PSCustomObject]@{ type = 'LeftClick' })
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Invoke-MacroSequence {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # Choices: [0] test-macro (01/01/24 12:00:00), [1] [Back to main menu]
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-RunMacroScreen -Console $tc
                $result | Should -BeNullOrEmpty
                Should -Invoke Invoke-MacroSequence -Times 0 -Exactly
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Load failure
    # ════════════════════════════════════════════════════════════════════════
    Context 'When Get-MacroFile returns $null (load failure)' {

        It 'Displays an error panel and does not call Invoke-MacroSequence' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList -MockWith {
                    @([PSCustomObject]@{
                        FileName    = '20240101_120000_test-macro.json'
                        FilePath    = 'C:\test\Macros\20240101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = '2024-01-01T12:00:00Z'
                        DisplayDate = '01/01/24 12:00:00'
                        ActionCount = 1
                        Valid       = $true
                    })
                }
                Mock Get-MacroFile -MockWith { $null }
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Invoke-MacroSequence {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # First pass: select the macro → error shown → loop back to step 1
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second pass: select Back to main menu
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RunMacroScreen -Console $tc
                $tc.Output | Should -Match 'Failed to load'
                Should -Invoke Invoke-MacroSequence -Times 0 -Exactly
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Validation failure
    # ════════════════════════════════════════════════════════════════════════
    Context 'When Get-MacroFile returns Valid=$false' {

        It 'Displays all validation messages and does not call Invoke-MacroSequence' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList -MockWith {
                    @([PSCustomObject]@{
                        FileName    = '20240101_120000_test-macro.json'
                        FilePath    = 'C:\test\Macros\20240101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = '2024-01-01T12:00:00Z'
                        DisplayDate = '01/01/24 12:00:00'
                        ActionCount = 1
                        Valid       = $false
                    })
                }
                Mock Get-MacroFile -MockWith {
                    [PSCustomObject]@{
                        Valid    = $false
                        Messages = @('Version mismatch', 'Missing target window')
                        Data     = [PSCustomObject]@{}
                    }
                }
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Invoke-MacroSequence {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # First pass: select the macro → validation errors shown → loop back
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second pass: Back to main menu
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RunMacroScreen -Console $tc
                $tc.Output | Should -Match 'Version mismatch'
                $tc.Output | Should -Match 'Missing target window'
                Should -Invoke Invoke-MacroSequence -Times 0 -Exactly
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Macro summary table
    # ════════════════════════════════════════════════════════════════════════
    Context 'When a valid macro with multiple action types is selected' {

        It 'Displays the action types and parameter summaries in the output' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList -MockWith {
                    @([PSCustomObject]@{
                        FileName    = '20240101_120000_test-macro.json'
                        FilePath    = 'C:\test\Macros\20240101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = '2024-01-01T12:00:00Z'
                        DisplayDate = '01/01/24 12:00:00'
                        ActionCount = 2
                        Valid       = $true
                    })
                }
                Mock Get-MacroFile -MockWith {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version  = '1.0'
                            metadata = [PSCustomObject]@{
                                name        = 'test-macro'
                                createdUtc  = '2024-01-01T12:00:00Z'
                                modifiedUtc = '2024-01-01T12:00:00Z'
                            }
                            targetWindow = [PSCustomObject]@{
                                processName = 'game.exe'
                                windowTitle = 'Game Window'
                            }
                            sequence = @(
                                [PSCustomObject]@{
                                    type     = 'MoveToPoint'
                                    position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.25 }
                                },
                                [PSCustomObject]@{ type = 'LeftClick' }
                            )
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game Window'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Invoke-MacroSequence -MockWith {
                    [PSCustomObject]@{ Success = $true; CompletedActions = 2; TotalActions = 2; Message = '' }
                }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # Select macro → confirm run → complete → dismiss pause prompt
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RunMacroScreen -Console $tc
                $tc.Output | Should -Match 'MoveToPoint'
                $tc.Output | Should -Match 'LeftClick'
                $tc.Output | Should -Match '0\.5'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Target window not open
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the target window handle is not valid' {

        It 'Displays the "not open" error panel and does not call Invoke-MacroSequence' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList -MockWith {
                    @([PSCustomObject]@{
                        FileName    = '20240101_120000_test-macro.json'
                        FilePath    = 'C:\test\Macros\20240101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = '2024-01-01T12:00:00Z'
                        DisplayDate = '01/01/24 12:00:00'
                        ActionCount = 1
                        Valid       = $true
                    })
                }
                Mock Get-MacroFile -MockWith {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version  = '1.0'
                            metadata = [PSCustomObject]@{
                                name        = 'test-macro'
                                createdUtc  = '2024-01-01T12:00:00Z'
                                modifiedUtc = '2024-01-01T12:00:00Z'
                            }
                            targetWindow = [PSCustomObject]@{ processName = 'game.exe'; windowTitle = 'Game' }
                            sequence     = @([PSCustomObject]@{ type = 'LeftClick' })
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $false }
                Mock Invoke-MacroSequence {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # First pass: select macro → window error → loop back
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second pass: Back to main menu
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RunMacroScreen -Console $tc
                $tc.Output | Should -Match 'not open'
                Should -Invoke Invoke-MacroSequence -Times 0 -Exactly
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Process name mismatch
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the macro process name differs from the current target window' {

        It 'Displays the warning and calls Invoke-MacroSequence when the user selects Continue anyway' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList -MockWith {
                    @([PSCustomObject]@{
                        FileName    = '20240101_120000_test-macro.json'
                        FilePath    = 'C:\test\Macros\20240101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = '2024-01-01T12:00:00Z'
                        DisplayDate = '01/01/24 12:00:00'
                        ActionCount = 1
                        Valid       = $true
                    })
                }
                Mock Get-MacroFile -MockWith {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version  = '1.0'
                            metadata = [PSCustomObject]@{
                                name        = 'test-macro'
                                createdUtc  = '2024-01-01T12:00:00Z'
                                modifiedUtc = '2024-01-01T12:00:00Z'
                            }
                            targetWindow = [PSCustomObject]@{ processName = 'original.exe'; windowTitle = 'Original' }
                            sequence     = @([PSCustomObject]@{ type = 'LeftClick' })
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'other.exe'; WindowTitle = 'Other'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Invoke-MacroSequence -MockWith {
                    [PSCustomObject]@{ Success = $true; CompletedActions = 1; TotalActions = 1; Message = '' }
                }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # Select macro → Continue anyway at mismatch → Yes, run now → dismiss pause prompt
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RunMacroScreen -Console $tc
                $tc.Output | Should -Match 'may not work correctly'
                Should -Invoke Invoke-MacroSequence -Times 1 -Exactly
            }
        }

        It 'Does not call Invoke-MacroSequence when the user selects Cancel at the mismatch prompt' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList -MockWith {
                    @([PSCustomObject]@{
                        FileName    = '20240101_120000_test-macro.json'
                        FilePath    = 'C:\test\Macros\20240101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = '2024-01-01T12:00:00Z'
                        DisplayDate = '01/01/24 12:00:00'
                        ActionCount = 1
                        Valid       = $true
                    })
                }
                Mock Get-MacroFile -MockWith {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version  = '1.0'
                            metadata = [PSCustomObject]@{
                                name        = 'test-macro'
                                createdUtc  = '2024-01-01T12:00:00Z'
                                modifiedUtc = '2024-01-01T12:00:00Z'
                            }
                            targetWindow = [PSCustomObject]@{ processName = 'original.exe'; windowTitle = 'Original' }
                            sequence     = @([PSCustomObject]@{ type = 'LeftClick' })
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'other.exe'; WindowTitle = 'Other'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Invoke-MacroSequence {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # First pass: select macro → Cancel at mismatch → loop back
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Mismatch prompt: select Cancel (index 1, down from default Continue)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second pass: Back to main menu
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RunMacroScreen -Console $tc
                Should -Invoke Invoke-MacroSequence -Times 0 -Exactly
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Execution results
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the macro executes successfully' {

        It 'Displays the "completed successfully" message with action counts' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList -MockWith {
                    @([PSCustomObject]@{
                        FileName    = '20240101_120000_test-macro.json'
                        FilePath    = 'C:\test\Macros\20240101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = '2024-01-01T12:00:00Z'
                        DisplayDate = '01/01/24 12:00:00'
                        ActionCount = 5
                        Valid       = $true
                    })
                }
                Mock Get-MacroFile -MockWith {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version  = '1.0'
                            metadata = [PSCustomObject]@{
                                name        = 'test-macro'
                                createdUtc  = '2024-01-01T12:00:00Z'
                                modifiedUtc = '2024-01-01T12:00:00Z'
                            }
                            targetWindow = [PSCustomObject]@{ processName = 'game.exe'; windowTitle = 'Game' }
                            sequence     = @([PSCustomObject]@{ type = 'LeftClick' })
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Invoke-MacroSequence -MockWith {
                    [PSCustomObject]@{ Success = $true; CompletedActions = 5; TotalActions = 5; Message = '' }
                }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # Select macro → Yes, run now → dismiss pause prompt
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RunMacroScreen -Console $tc
                $tc.Output | Should -Match 'completed successfully'
                $tc.Output | Should -Match '5 of 5'
            }
        }
    }

    Context 'When macro execution fails' {

        It 'Displays the "failed" message with completed action count' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList -MockWith {
                    @([PSCustomObject]@{
                        FileName    = '20240101_120000_test-macro.json'
                        FilePath    = 'C:\test\Macros\20240101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = '2024-01-01T12:00:00Z'
                        DisplayDate = '01/01/24 12:00:00'
                        ActionCount = 5
                        Valid       = $true
                    })
                }
                Mock Get-MacroFile -MockWith {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version  = '1.0'
                            metadata = [PSCustomObject]@{
                                name        = 'test-macro'
                                createdUtc  = '2024-01-01T12:00:00Z'
                                modifiedUtc = '2024-01-01T12:00:00Z'
                            }
                            targetWindow = [PSCustomObject]@{ processName = 'game.exe'; windowTitle = 'Game' }
                            sequence     = @([PSCustomObject]@{ type = 'LeftClick' })
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Invoke-MacroSequence -MockWith {
                    [PSCustomObject]@{ Success = $false; CompletedActions = 2; TotalActions = 5; Message = 'Action failed' }
                }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # Select macro → Yes, run now → dismiss pause prompt
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RunMacroScreen -Console $tc
                $tc.Output | Should -Match 'failed'
                $tc.Output | Should -Match '2'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: User cancels at run confirmation
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user cancels at the run confirmation prompt' {

        It 'Does not call Invoke-MacroSequence' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList -MockWith {
                    @([PSCustomObject]@{
                        FileName    = '20240101_120000_test-macro.json'
                        FilePath    = 'C:\test\Macros\20240101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = '2024-01-01T12:00:00Z'
                        DisplayDate = '01/01/24 12:00:00'
                        ActionCount = 1
                        Valid       = $true
                    })
                }
                Mock Get-MacroFile -MockWith {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version  = '1.0'
                            metadata = [PSCustomObject]@{
                                name        = 'test-macro'
                                createdUtc  = '2024-01-01T12:00:00Z'
                                modifiedUtc = '2024-01-01T12:00:00Z'
                            }
                            targetWindow = [PSCustomObject]@{ processName = 'game.exe'; windowTitle = 'Game' }
                            sequence     = @([PSCustomObject]@{ type = 'LeftClick' })
                        }
                    }
                }
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Invoke-MacroSequence {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # First pass: select macro → Cancel at run prompt → loop back
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second pass: Back to main menu
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RunMacroScreen -Console $tc
                Should -Invoke Invoke-MacroSequence -Times 0 -Exactly
            }
        }
    }
}
