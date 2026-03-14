BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force

    # Spectre.Console.Testing.dll ships in lib\test\ and is required for TestConsole
    $testingDll = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll

}

Describe 'Show-ManageMacrosScreen' -Tag 'Unit' {

    BeforeEach {
        # Create a fresh TestConsole for each test to prevent output accumulation.
        # Width/height are set from module-scope variables defined in LastWarAutoScreenshot.psm1.
        InModuleScope 'LastWarAutoScreenshot' {
            $script:tc = [Spectre.Console.Testing.TestConsole]::new()
            $script:tc.Profile.Width  = $script:TestConsoleWidth
            $script:tc.Profile.Height = $script:TestConsoleHeight
            $script:tc.Profile.Capabilities.Interactive = $true
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Shared mock helpers (defined inline per test to avoid $script: scope issues)
    # Macro list entry: Name='test-macro', DisplayDate='01/01/26 12:00:00'
    # Management prompt order: [0] View details, [1] Edit macro, [2] Delete macro, [3] [Back to macro list]
    # Macro list prompt order: [0] 'test-macro (01/01/26 12:00:00)', [1] [Back to main menu]
    # ════════════════════════════════════════════════════════════════════════

    # ════════════════════════════════════════════════════════════════════════
    # Context: No macros saved
    # ════════════════════════════════════════════════════════════════════════
    Context 'When no macros are saved' {

        It 'Displays a panel containing "No macros saved" in the console output' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList { @() }
                Mock Write-LastWarLog {}

                $tc = $script:tc

                Show-ManageMacrosScreen -Console $tc

                $tc.Output | Should -Match 'No macros saved'
            }
        }

        It 'Returns $null when no macros exist' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList { @() }
                Mock Write-LastWarLog {}

                $tc = $script:tc

                $result = Show-ManageMacrosScreen -Console $tc

                $result | Should -BeNullOrEmpty
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: User selects [Back to main menu] immediately
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user selects [Back to main menu] from the macro list' {

        It 'Returns $null' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList {
                    @([PSCustomObject]@{
                        FileName    = '20260101_120000_test-macro.json'
                        FilePath    = 'C:\fake\macros\20260101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = [datetime]'2026-01-01T12:00:00Z'
                        DisplayDate = '01/01/26 12:00:00'
                        ActionCount = 1
                        Valid       = $true
                    })
                }
                Mock Write-LastWarLog {}

                $tc = $script:tc
                # Macro list: [0] [Back to main menu], [1] test-macro — select back (index 0, default)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-ManageMacrosScreen -Console $tc

                $result | Should -BeNullOrEmpty
            }
        }

        It 'Does not throw when back is selected immediately' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList {
                    @([PSCustomObject]@{
                        FileName    = '20260101_120000_test-macro.json'
                        FilePath    = 'C:\fake\macros\20260101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = [datetime]'2026-01-01T12:00:00Z'
                        DisplayDate = '01/01/26 12:00:00'
                        ActionCount = 1
                        Valid       = $true
                    })
                }
                Mock Write-LastWarLog {}

                $tc = $script:tc
                # Select back button at index 0
                $tc.Input.PushKey([ConsoleKey]::Enter)

                { Show-ManageMacrosScreen -Console $tc } | Should -Not -Throw
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: View details
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user selects View details for a macro' {

        It 'Console output contains the macro name' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList {
                    @([PSCustomObject]@{
                        FileName    = '20260101_120000_test-macro.json'
                        FilePath    = 'C:\fake\macros\20260101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = [datetime]'2026-01-01T12:00:00Z'
                        DisplayDate = '01/01/26 12:00:00'
                        ActionCount = 2
                        Valid       = $true
                    })
                }
                Mock Get-MacroFile {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version  = '1.0'
                            metadata = [PSCustomObject]@{
                                name        = 'test-macro'
                                createdUtc  = '2026-01-01T12:00:00Z'
                                modifiedUtc = '2026-01-01T12:00:00Z'
                                description = ''
                            }
                            targetWindow = [PSCustomObject]@{
                                processName = 'LastWar'
                                windowTitle = 'Last War: Survival'
                            }
                            sequence = @(
                                [PSCustomObject]@{ type = 'MoveToPoint'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' }
                            )
                        }
                    }
                }
                Mock Write-LastWarLog {}

                $tc = $script:tc
                # 1. Select macro from list (index 0) — Enter
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 2. Select 'View details' (index 0) — Enter
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 3. Acknowledge (press Enter on TextPrompt)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 4. Select '[[Back to macro list]]' (index 3) — 3 DownArrows + Enter
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 5. Select '[[Back to main menu]]' (index 1) — DownArrow + Enter
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ManageMacrosScreen -Console $tc

                $tc.Output | Should -Match 'test-macro'
            }
        }

        It 'Console output contains action types from the sequence' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList {
                    @([PSCustomObject]@{
                        FileName    = '20260101_120000_test-macro.json'
                        FilePath    = 'C:\fake\macros\20260101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = [datetime]'2026-01-01T12:00:00Z'
                        DisplayDate = '01/01/26 12:00:00'
                        ActionCount = 2
                        Valid       = $true
                    })
                }
                Mock Get-MacroFile {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version  = '1.0'
                            metadata = [PSCustomObject]@{
                                name        = 'test-macro'
                                createdUtc  = '2026-01-01T12:00:00Z'
                                modifiedUtc = '2026-01-01T12:00:00Z'
                                description = ''
                            }
                            targetWindow = [PSCustomObject]@{
                                processName = 'LastWar'
                                windowTitle = 'Last War: Survival'
                            }
                            sequence = @(
                                [PSCustomObject]@{ type = 'MoveToPoint'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' }
                            )
                        }
                    }
                }
                Mock Write-LastWarLog {}

                $tc = $script:tc
                # Macro list: [0] [Back to main menu], [1] test-macro — select macro
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Management menu: [0] View details — select it (default)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Acknowledgement prompt
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Back to macro list (3 DownArrows to index 3 [[Back to macro list]])
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Back to main menu (Enter at index 0)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ManageMacrosScreen -Console $tc

                $tc.Output | Should -Match 'MoveToPoint'
                $tc.Output | Should -Match 'LeftClick'
            }
        }

        It 'Calls Get-MacroFile with the correct FilePath' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList {
                    @([PSCustomObject]@{
                        FileName    = '20260101_120000_test-macro.json'
                        FilePath    = 'C:\fake\macros\20260101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = [datetime]'2026-01-01T12:00:00Z'
                        DisplayDate = '01/01/26 12:00:00'
                        ActionCount = 1
                        Valid       = $true
                    })
                }
                Mock Get-MacroFile {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version  = '1.0'
                            metadata = [PSCustomObject]@{
                                name        = 'test-macro'
                                createdUtc  = '2026-01-01T12:00:00Z'
                                modifiedUtc = '2026-01-01T12:00:00Z'
                                description = ''
                            }
                            targetWindow = [PSCustomObject]@{
                                processName = 'LastWar'
                                windowTitle = 'Last War: Survival'
                            }
                            sequence = @(
                                [PSCustomObject]@{ type = 'LeftClick' }
                            )
                        }
                    }
                }
                Mock Write-LastWarLog {}

                $tc = $script:tc
                # Macro list: [0] [Back to main menu], [1] test-macro — select macro
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Management menu: [0] View details — select it (default)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Acknowledgement prompt
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Back to macro list (3 DownArrows to index 3 [[Back to macro list]])
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Back to main menu (Enter at index 0)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ManageMacrosScreen -Console $tc

                Should -Invoke Get-MacroFile -Exactly 1 -ParameterFilter {
                    $FilePath -eq 'C:\fake\macros\20260101_120000_test-macro.json'
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Delete macro — confirmed
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user confirms deletion of a macro' {

        It 'Calls Remove-MacroFile exactly once' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList {
                    @([PSCustomObject]@{
                        FileName    = '20260101_120000_test-macro.json'
                        FilePath    = 'C:\fake\macros\20260101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = [datetime]'2026-01-01T12:00:00Z'
                        DisplayDate = '01/01/26 12:00:00'
                        ActionCount = 1
                        Valid       = $true
                    })
                }
                Mock Remove-MacroFile { $true }
                Mock Write-LastWarLog {}

                $tc = $script:tc
                # Macro list: [0] [Back to main menu], [1] test-macro — select macro (1 DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Management menu: [0] View details, [1] Edit macro, [2] Delete macro — select Delete (2 DownArrows)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Confirmation: [0] Yes, delete — select it (default/Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Back to macro list: [0] [Back to main menu] — select it (default/Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ManageMacrosScreen -Console $tc

                Should -Invoke Remove-MacroFile -Exactly 1
            }
        }

        It 'Calls Remove-MacroFile with the correct FilePath' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList {
                    @([PSCustomObject]@{
                        FileName    = '20260101_120000_test-macro.json'
                        FilePath    = 'C:\fake\macros\20260101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = [datetime]'2026-01-01T12:00:00Z'
                        DisplayDate = '01/01/26 12:00:00'
                        ActionCount = 1
                        Valid       = $true
                    })
                }
                Mock Remove-MacroFile { $true }
                Mock Write-LastWarLog {}

                $tc = $script:tc
                # Select macro at index 1
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Select Delete macro option (2 DownArrows to index 2)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Confirm deletion
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Back to main menu
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ManageMacrosScreen -Console $tc

                Should -Invoke Remove-MacroFile -Exactly 1 -ParameterFilter {
                    $FilePath -eq 'C:\fake\macros\20260101_120000_test-macro.json'
                }
            }
        }

        It 'Console output contains "deleted" after confirmed deletion' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList {
                    @([PSCustomObject]@{
                        FileName    = '20260101_120000_test-macro.json'
                        FilePath    = 'C:\fake\macros\20260101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = [datetime]'2026-01-01T12:00:00Z'
                        DisplayDate = '01/01/26 12:00:00'
                        ActionCount = 1
                        Valid       = $true
                    })
                }
                Mock Remove-MacroFile { $true }
                Mock Write-LastWarLog {}

                $tc = $script:tc
                # Select macro (DownArrow to index 1)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Select Delete macro (2 DownArrows to index 2)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Confirm deletion
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Back to main menu
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ManageMacrosScreen -Console $tc

                $tc.Output | Should -Match 'deleted'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Delete macro — declined
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user declines deletion of a macro' {

        It 'Does not call Remove-MacroFile' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList {
                    @([PSCustomObject]@{
                        FileName    = '20260101_120000_test-macro.json'
                        FilePath    = 'C:\fake\macros\20260101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = [datetime]'2026-01-01T12:00:00Z'
                        DisplayDate = '01/01/26 12:00:00'
                        ActionCount = 1
                        Valid       = $true
                    })
                }
                Mock Remove-MacroFile { $true }
                Mock Write-LastWarLog {}

                $tc = $script:tc
                # 1. Select macro — Enter
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 2. Select 'Delete macro' (index 2) — 2 DownArrows + Enter
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 3. Select 'No, keep it' (index 1) — DownArrow + Enter
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 4. Select '[[Back to macro list]]' (index 3) — 3 DownArrows + Enter
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 5. Select '[[Back to main menu]]' (index 1) — DownArrow + Enter
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ManageMacrosScreen -Console $tc

                Should -Not -Invoke Remove-MacroFile
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Edit macro dispatches to Show-EditMacroScreen
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user selects Edit macro' {

        It 'Calls Show-EditMacroScreen exactly once' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList {
                    @([PSCustomObject]@{
                        FileName    = '20260101_120000_test-macro.json'
                        FilePath    = 'C:\fake\macros\20260101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = [datetime]'2026-01-01T12:00:00Z'
                        DisplayDate = '01/01/26 12:00:00'
                        ActionCount = 1
                        Valid       = $true
                    })
                }
                Mock Show-EditMacroScreen {}
                Mock Write-LastWarLog {}

                $tc = $script:tc
                # Macro list: [0] [Back to main menu], [1] test-macro — select macro
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Management menu: [0] View details, [1] Edit macro — select Edit macro
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # After edit screen returns, back at macro list — select back at index 0
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ManageMacrosScreen -Console $tc

                Should -Invoke Show-EditMacroScreen -Exactly 1
            }
        }

        It 'Calls Show-EditMacroScreen with the correct -FilePath' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList {
                    @([PSCustomObject]@{
                        FileName    = '20260101_120000_test-macro.json'
                        FilePath    = 'C:\fake\macros\20260101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = [datetime]'2026-01-01T12:00:00Z'
                        DisplayDate = '01/01/26 12:00:00'
                        ActionCount = 1
                        Valid       = $true
                    })
                }
                Mock Show-EditMacroScreen {}
                Mock Write-LastWarLog {}

                $tc = $script:tc
                # Select macro at index 1
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Select Edit macro option
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Back to menu
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ManageMacrosScreen -Console $tc

                Should -Invoke Show-EditMacroScreen -Exactly 1 -ParameterFilter {
                    $FilePath -eq 'C:\fake\macros\20260101_120000_test-macro.json'
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Console output contains macro list choices
    # ════════════════════════════════════════════════════════════════════════
    Context 'Console output when macros exist' {

        It 'Output contains the macro name and display date' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList {
                    @([PSCustomObject]@{
                        FileName    = '20260101_120000_test-macro.json'
                        FilePath    = 'C:\fake\macros\20260101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = [datetime]'2026-01-01T12:00:00Z'
                        DisplayDate = '01/01/26 12:00:00'
                        ActionCount = 1
                        Valid       = $true
                    })
                }
                Mock Write-LastWarLog {}

                $tc = $script:tc
                # Select '[[Back to main menu]]' (index 0)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ManageMacrosScreen -Console $tc

                $tc.Output | Should -Match 'test-macro'
                $tc.Output | Should -Match '01/01/26'
            }
        }

        It 'Output contains "Back to main menu" option' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFileList {
                    @([PSCustomObject]@{
                        FileName    = '20260101_120000_test-macro.json'
                        FilePath    = 'C:\fake\macros\20260101_120000_test-macro.json'
                        Name        = 'test-macro'
                        CreatedUtc  = [datetime]'2026-01-01T12:00:00Z'
                        DisplayDate = '01/01/26 12:00:00'
                        ActionCount = 1
                        Valid       = $true
                    })
                }
                Mock Write-LastWarLog {}

                $tc = $script:tc
                # Select '[[Back to main menu]]' (index 0)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ManageMacrosScreen -Console $tc

                $tc.Output | Should -Match 'Back to main menu'
            }
        }
    }
}
