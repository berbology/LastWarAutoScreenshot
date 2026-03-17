BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force

    # Spectre.Console.Testing.dll ships in lib\test\ and is required for TestConsole
    $testingDll = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll

}

Describe 'Show-EditMacroScreen' -Tag 'Unit' {

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
    # Shared helper: scriptblock that returns a fresh 3-action macro each
    # time it is invoked, preventing inter-test mutation.
    #
    # Sequence:
    #   [0] MoveToPoint  name='action-a'  position=(0.5, 0.3)
    #   [1] LeftClick    (unnamed)
    #   [2] Loop         name='my-loop'   iterations=3  actionNames=['action-a']
    # ════════════════════════════════════════════════════════════════════════

    # ════════════════════════════════════════════════════════════════════════
    # Context: Dynamic menu options — Back only visible when no changes
    # ════════════════════════════════════════════════════════════════════════
    Context 'When no changes have been made' {

        It 'Output contains [[Back]] and does not contain Save changes or Discard changes' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockMacroData = {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version      = '1.0'
                            metadata     = [PSCustomObject]@{ name = 'test-macro'; createdUtc = '2026-01-01T00:00:00Z'; modifiedUtc = '2026-01-01T00:00:00Z'; description = '' }
                            targetWindow = [PSCustomObject]@{ processName = 'LastWar'; windowTitle = 'Last War: Survival' }
                            sequence     = [object[]]@(
                                [PSCustomObject]@{ type = 'MoveToPoint'; name = 'action-a'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' },
                                [PSCustomObject]@{ type = 'Loop'; name = 'my-loop'; iterations = 3; actionNames = [object[]]@('action-a') }
                            )
                        }
                    }
                }
                Mock Get-MacroFile -MockWith $mockMacroData

                $tc = $script:tc
                # Edit menu (no changes): [0]Rename macro [1]Edit steps [2][[Back]]
                # Navigate to [Back] (index 2)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-EditMacroScreen -Console $tc -FilePath 'C:\fake\20260101_000000_test-macro.json'

                $tc.Output | Should -Match 'Back'
                $tc.Output | Should -Not -Match 'Save changes'
                $tc.Output | Should -Not -Match 'Discard changes'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Dynamic menu options — Save/Discard visible only after change
    # ════════════════════════════════════════════════════════════════════════
    Context 'When a change has been made' {

        It 'Output contains Save changes and Discard changes after a rename' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockMacroData = {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version      = '1.0'
                            metadata     = [PSCustomObject]@{ name = 'test-macro'; createdUtc = '2026-01-01T00:00:00Z'; modifiedUtc = '2026-01-01T00:00:00Z'; description = '' }
                            targetWindow = [PSCustomObject]@{ processName = 'LastWar'; windowTitle = 'Last War: Survival' }
                            sequence     = [object[]]@(
                                [PSCustomObject]@{ type = 'MoveToPoint'; name = 'action-a'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' },
                                [PSCustomObject]@{ type = 'Loop'; name = 'my-loop'; iterations = 3; actionNames = [object[]]@('action-a') }
                            )
                        }
                    }
                }
                Mock Get-MacroFile    -MockWith $mockMacroData
                Mock Get-LWASMacro { @() }
                Mock Rename-MacroFile { [PSCustomObject]@{ Success = $true; NewFilePath = 'C:\fake\20260101_000000_new-name.json'; Message = '' } }
                Mock Save-MacroFile   { [PSCustomObject]@{ Success = $true; FilePath = 'C:\fake\20260101_000000_new-name.json'; Message = '' } }

                $tc = $script:tc
                # Select 'Rename macro' (index 0)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Provide new name
                $tc.Input.PushTextWithEnter('new-name')
                # Edit menu now shows changes: [0]Rename [1]Edit steps [2]Save changes [3]Discard
                # Navigate to 'Save changes' (index 2)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-EditMacroScreen -Console $tc -FilePath 'C:\fake\20260101_000000_test-macro.json'

                $tc.Output | Should -Match 'Save changes'
                $tc.Output | Should -Match 'Discard changes'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Rename macro
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user renames the macro and saves' {

        It 'Calls Rename-MacroFile with the new name' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockMacroData = {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version      = '1.0'
                            metadata     = [PSCustomObject]@{ name = 'test-macro'; createdUtc = '2026-01-01T00:00:00Z'; modifiedUtc = '2026-01-01T00:00:00Z'; description = '' }
                            targetWindow = [PSCustomObject]@{ processName = 'LastWar'; windowTitle = 'Last War: Survival' }
                            sequence     = [object[]]@(
                                [PSCustomObject]@{ type = 'MoveToPoint'; name = 'action-a'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' },
                                [PSCustomObject]@{ type = 'Loop'; name = 'my-loop'; iterations = 3; actionNames = [object[]]@('action-a') }
                            )
                        }
                    }
                }
                Mock Get-MacroFile    -MockWith $mockMacroData
                Mock Get-LWASMacro { @() }
                Mock Rename-MacroFile { [PSCustomObject]@{ Success = $true; NewFilePath = 'C:\fake\20260101_000000_new-name.json'; Message = '' } }
                Mock Save-MacroFile   { [PSCustomObject]@{ Success = $true; FilePath = 'C:\fake\20260101_000000_new-name.json'; Message = '' } }

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Rename macro'
                $tc.Input.PushTextWithEnter('new-name')         # enter new name
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Save changes'

                Show-EditMacroScreen -Console $tc -FilePath 'C:\fake\20260101_000000_test-macro.json'

                Should -Invoke Rename-MacroFile -Exactly 1 -ParameterFilter { $NewName -eq 'new-name' }
            }
        }

        It 'Calls Save-MacroFile after a successful rename' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockMacroData = {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version      = '1.0'
                            metadata     = [PSCustomObject]@{ name = 'test-macro'; createdUtc = '2026-01-01T00:00:00Z'; modifiedUtc = '2026-01-01T00:00:00Z'; description = '' }
                            targetWindow = [PSCustomObject]@{ processName = 'LastWar'; windowTitle = 'Last War: Survival' }
                            sequence     = [object[]]@(
                                [PSCustomObject]@{ type = 'MoveToPoint'; name = 'action-a'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' },
                                [PSCustomObject]@{ type = 'Loop'; name = 'my-loop'; iterations = 3; actionNames = [object[]]@('action-a') }
                            )
                        }
                    }
                }
                Mock Get-MacroFile    -MockWith $mockMacroData
                Mock Get-LWASMacro { @() }
                Mock Rename-MacroFile { [PSCustomObject]@{ Success = $true; NewFilePath = 'C:\fake\20260101_000000_new-name.json'; Message = '' } }
                Mock Save-MacroFile   { [PSCustomObject]@{ Success = $true; FilePath = 'C:\fake\20260101_000000_new-name.json'; Message = '' } }

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushTextWithEnter('new-name')
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-EditMacroScreen -Console $tc -FilePath 'C:\fake\20260101_000000_test-macro.json'

                Should -Invoke Save-MacroFile -Exactly 1
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Rename macro — empty input keeps current name
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user presses Enter without typing a new name' {

        It 'Does not call Rename-MacroFile' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockMacroData = {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version      = '1.0'
                            metadata     = [PSCustomObject]@{ name = 'test-macro'; createdUtc = '2026-01-01T00:00:00Z'; modifiedUtc = '2026-01-01T00:00:00Z'; description = '' }
                            targetWindow = [PSCustomObject]@{ processName = 'LastWar'; windowTitle = 'Last War: Survival' }
                            sequence     = [object[]]@(
                                [PSCustomObject]@{ type = 'MoveToPoint'; name = 'action-a'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' },
                                [PSCustomObject]@{ type = 'Loop'; name = 'my-loop'; iterations = 3; actionNames = [object[]]@('action-a') }
                            )
                        }
                    }
                }
                Mock Get-MacroFile    -MockWith $mockMacroData
                Mock Rename-MacroFile {}
                Mock Save-MacroFile   {}

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Rename macro'
                $tc.Input.PushKey([ConsoleKey]::Enter)          # empty input — keep current
                # No changes: [0]Rename [1]Edit steps [2][[Back]]
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # '[Back]'

                Show-EditMacroScreen -Console $tc -FilePath 'C:\fake\20260101_000000_test-macro.json'

                Should -Not -Invoke Rename-MacroFile
            }
        }

        It 'Does not call Save-MacroFile' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockMacroData = {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version      = '1.0'
                            metadata     = [PSCustomObject]@{ name = 'test-macro'; createdUtc = '2026-01-01T00:00:00Z'; modifiedUtc = '2026-01-01T00:00:00Z'; description = '' }
                            targetWindow = [PSCustomObject]@{ processName = 'LastWar'; windowTitle = 'Last War: Survival' }
                            sequence     = [object[]]@(
                                [PSCustomObject]@{ type = 'MoveToPoint'; name = 'action-a'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' },
                                [PSCustomObject]@{ type = 'Loop'; name = 'my-loop'; iterations = 3; actionNames = [object[]]@('action-a') }
                            )
                        }
                    }
                }
                Mock Get-MacroFile  -MockWith $mockMacroData
                Mock Save-MacroFile {}

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Rename macro'
                $tc.Input.PushKey([ConsoleKey]::Enter)          # empty input
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # '[Back]'

                Show-EditMacroScreen -Console $tc -FilePath 'C:\fake\20260101_000000_test-macro.json'

                Should -Not -Invoke Save-MacroFile
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Rename step — loop actionNames updated automatically
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user renames a step that is referenced by a Loop action' {

        It 'Saves the macro with the updated actionNames in the Loop action' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockMacroData = {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version      = '1.0'
                            metadata     = [PSCustomObject]@{ name = 'test-macro'; createdUtc = '2026-01-01T00:00:00Z'; modifiedUtc = '2026-01-01T00:00:00Z'; description = '' }
                            targetWindow = [PSCustomObject]@{ processName = 'LastWar'; windowTitle = 'Last War: Survival' }
                            sequence     = [object[]]@(
                                [PSCustomObject]@{ type = 'MoveToPoint'; name = 'action-a'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' },
                                [PSCustomObject]@{ type = 'Loop'; name = 'my-loop'; iterations = 3; actionNames = [object[]]@('action-a') }
                            )
                        }
                    }
                }
                Mock Get-MacroFile  -MockWith $mockMacroData
                Mock Save-MacroFile { [PSCustomObject]@{ Success = $true; FilePath = 'C:\fake\20260101_000000_test-macro.json'; Message = '' } }

                $tc = $script:tc
                # Navigate to 'Edit steps' (index 1)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Step list: [0]#1: MoveToPoint [[action-a]]  [1]#2: LeftClick  [2]#3: Loop [[my-loop]]  [3][[Back to edit menu]]
                # Select step 1 (index 0)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Step options for first (named) step: [0]Rename step  [1]Move down  [2][[Back to step list]]
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Rename step'
                $tc.Input.PushTextWithEnter('action-b')         # new step name
                # Returned to step list (via continue); select '[[Back to edit menu]]' (index 3)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Edit menu with changes: [0]Rename [1]Edit steps [2]Save changes [3]Discard
                # Select 'Save changes' (index 2)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-EditMacroScreen -Console $tc -FilePath 'C:\fake\20260101_000000_test-macro.json'

                Should -Invoke Save-MacroFile -Exactly 1 -ParameterFilter {
                    $MacroData.sequence[2].actionNames -contains 'action-b'
                }
            }
        }

        It 'Does not include the old step name in the Loop actionNames after rename' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockMacroData = {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version      = '1.0'
                            metadata     = [PSCustomObject]@{ name = 'test-macro'; createdUtc = '2026-01-01T00:00:00Z'; modifiedUtc = '2026-01-01T00:00:00Z'; description = '' }
                            targetWindow = [PSCustomObject]@{ processName = 'LastWar'; windowTitle = 'Last War: Survival' }
                            sequence     = [object[]]@(
                                [PSCustomObject]@{ type = 'MoveToPoint'; name = 'action-a'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' },
                                [PSCustomObject]@{ type = 'Loop'; name = 'my-loop'; iterations = 3; actionNames = [object[]]@('action-a') }
                            )
                        }
                    }
                }
                Mock Get-MacroFile  -MockWith $mockMacroData
                Mock Save-MacroFile { [PSCustomObject]@{ Success = $true; FilePath = 'C:\fake\20260101_000000_test-macro.json'; Message = '' } }

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Edit steps'
                $tc.Input.PushKey([ConsoleKey]::Enter)          # select step 1 (#1: MoveToPoint)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Rename step'
                $tc.Input.PushTextWithEnter('action-b')
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # '[Back to edit menu]'
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Save changes'

                Show-EditMacroScreen -Console $tc -FilePath 'C:\fake\20260101_000000_test-macro.json'

                Should -Invoke Save-MacroFile -Exactly 1 -ParameterFilter {
                    $MacroData.sequence[2].actionNames -notcontains 'action-a'
                }
            }
        }

        It 'Writes a message about the updated loop reference to the console' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockMacroData = {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version      = '1.0'
                            metadata     = [PSCustomObject]@{ name = 'test-macro'; createdUtc = '2026-01-01T00:00:00Z'; modifiedUtc = '2026-01-01T00:00:00Z'; description = '' }
                            targetWindow = [PSCustomObject]@{ processName = 'LastWar'; windowTitle = 'Last War: Survival' }
                            sequence     = [object[]]@(
                                [PSCustomObject]@{ type = 'MoveToPoint'; name = 'action-a'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' },
                                [PSCustomObject]@{ type = 'Loop'; name = 'my-loop'; iterations = 3; actionNames = [object[]]@('action-a') }
                            )
                        }
                    }
                }
                Mock Get-MacroFile  -MockWith $mockMacroData
                Mock Save-MacroFile { [PSCustomObject]@{ Success = $true; FilePath = 'C:\fake\20260101_000000_test-macro.json'; Message = '' } }

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Edit steps'
                $tc.Input.PushKey([ConsoleKey]::Enter)          # step 1
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Rename step'
                $tc.Input.PushTextWithEnter('action-b')
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # '[Back to edit menu]'
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Save changes'

                Show-EditMacroScreen -Console $tc -FilePath 'C:\fake\20260101_000000_test-macro.json'

                $tc.Output | Should -Match 'my-loop'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Add name to unnamed step
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user adds a name to a previously unnamed step' {

        It 'Saves the macro with the name set on the LeftClick action' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockMacroData = {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version      = '1.0'
                            metadata     = [PSCustomObject]@{ name = 'test-macro'; createdUtc = '2026-01-01T00:00:00Z'; modifiedUtc = '2026-01-01T00:00:00Z'; description = '' }
                            targetWindow = [PSCustomObject]@{ processName = 'LastWar'; windowTitle = 'Last War: Survival' }
                            sequence     = [object[]]@(
                                [PSCustomObject]@{ type = 'MoveToPoint'; name = 'action-a'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' },
                                [PSCustomObject]@{ type = 'Loop'; name = 'my-loop'; iterations = 3; actionNames = [object[]]@('action-a') }
                            )
                        }
                    }
                }
                Mock Get-MacroFile  -MockWith $mockMacroData
                Mock Save-MacroFile { [PSCustomObject]@{ Success = $true; FilePath = 'C:\fake\20260101_000000_test-macro.json'; Message = '' } }

                $tc = $script:tc
                # Navigate to 'Edit steps' (index 1)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Step list: select '#2: LeftClick' (index 1)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Step options for unnamed middle step: [0]Add name to step [1]Move up [2]Move down [3][[Back to step list]]
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Add name to step'
                $tc.Input.PushTextWithEnter('my-click')         # enter name
                # Returned to step list; select '[[Back to edit menu]]' (index 3)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Edit menu with changes: select 'Save changes' (index 2)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-EditMacroScreen -Console $tc -FilePath 'C:\fake\20260101_000000_test-macro.json'

                Should -Invoke Save-MacroFile -Exactly 1 -ParameterFilter {
                    $MacroData.sequence[1].name -eq 'my-click'
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Move step up
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user moves the second step up' {

        It 'Saves the macro with the originally-second step now first in the sequence' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockMacroData = {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version      = '1.0'
                            metadata     = [PSCustomObject]@{ name = 'test-macro'; createdUtc = '2026-01-01T00:00:00Z'; modifiedUtc = '2026-01-01T00:00:00Z'; description = '' }
                            targetWindow = [PSCustomObject]@{ processName = 'LastWar'; windowTitle = 'Last War: Survival' }
                            sequence     = [object[]]@(
                                [PSCustomObject]@{ type = 'MoveToPoint'; name = 'action-a'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' },
                                [PSCustomObject]@{ type = 'Loop'; name = 'my-loop'; iterations = 3; actionNames = [object[]]@('action-a') }
                            )
                        }
                    }
                }
                Mock Get-MacroFile  -MockWith $mockMacroData
                Mock Save-MacroFile { [PSCustomObject]@{ Success = $true; FilePath = 'C:\fake\20260101_000000_test-macro.json'; Message = '' } }

                $tc = $script:tc
                # 'Edit steps'
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Select '#2: LeftClick' (index 1)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Step options for unnamed middle step: [0]Add name [1]Move up [2]Move down [3]Back
                # Select 'Move up' (index 1)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Returned to step list; '[Back to edit menu]' is now index 3
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 'Save changes' (index 2)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-EditMacroScreen -Console $tc -FilePath 'C:\fake\20260101_000000_test-macro.json'

                Should -Invoke Save-MacroFile -Exactly 1 -ParameterFilter {
                    $MacroData.sequence[0].type -eq 'LeftClick'
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Move step down
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user moves the first step down' {

        It 'Saves the macro with the originally-first step now second in the sequence' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockMacroData = {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version      = '1.0'
                            metadata     = [PSCustomObject]@{ name = 'test-macro'; createdUtc = '2026-01-01T00:00:00Z'; modifiedUtc = '2026-01-01T00:00:00Z'; description = '' }
                            targetWindow = [PSCustomObject]@{ processName = 'LastWar'; windowTitle = 'Last War: Survival' }
                            sequence     = [object[]]@(
                                [PSCustomObject]@{ type = 'MoveToPoint'; name = 'action-a'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' },
                                [PSCustomObject]@{ type = 'Loop'; name = 'my-loop'; iterations = 3; actionNames = [object[]]@('action-a') }
                            )
                        }
                    }
                }
                Mock Get-MacroFile  -MockWith $mockMacroData
                Mock Save-MacroFile { [PSCustomObject]@{ Success = $true; FilePath = 'C:\fake\20260101_000000_test-macro.json'; Message = '' } }

                $tc = $script:tc
                # 'Edit steps'
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Select '#1: MoveToPoint [[action-a]]' (index 0)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Step options for named first step: [0]Rename step [1]Move down [2][[Back to step list]]
                # Select 'Move down' (index 1)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Returned to step list; '[Back to edit menu]' is index 3
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 'Save changes' (index 2)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-EditMacroScreen -Console $tc -FilePath 'C:\fake\20260101_000000_test-macro.json'

                Should -Invoke Save-MacroFile -Exactly 1 -ParameterFilter {
                    $MacroData.sequence[1].type -eq 'MoveToPoint'
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Move up hidden for first step
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user opens step options for the first step' {

        It 'Does not show Move up in the step options' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockMacroData = {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version      = '1.0'
                            metadata     = [PSCustomObject]@{ name = 'test-macro'; createdUtc = '2026-01-01T00:00:00Z'; modifiedUtc = '2026-01-01T00:00:00Z'; description = '' }
                            targetWindow = [PSCustomObject]@{ processName = 'LastWar'; windowTitle = 'Last War: Survival' }
                            sequence     = [object[]]@(
                                [PSCustomObject]@{ type = 'MoveToPoint'; name = 'action-a'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' },
                                [PSCustomObject]@{ type = 'Loop'; name = 'my-loop'; iterations = 3; actionNames = [object[]]@('action-a') }
                            )
                        }
                    }
                }
                Mock Get-MacroFile -MockWith $mockMacroData

                $tc = $script:tc
                # 'Edit steps'
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Select first step (index 0)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Step options for first step: [0]Rename step [1]Move down [2][[Back to step list]]
                # Select '[Back to step list]' (index 2)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Step list: select '[Back to edit menu]' (index 3)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Edit menu (no changes): '[Back]' (index 2)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-EditMacroScreen -Console $tc -FilePath 'C:\fake\20260101_000000_test-macro.json'

                $tc.Output | Should -Not -Match 'Move up'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Move down hidden for last step
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user opens step options for the last step' {

        It 'Does not show Move down in the step options' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockMacroData = {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version      = '1.0'
                            metadata     = [PSCustomObject]@{ name = 'test-macro'; createdUtc = '2026-01-01T00:00:00Z'; modifiedUtc = '2026-01-01T00:00:00Z'; description = '' }
                            targetWindow = [PSCustomObject]@{ processName = 'LastWar'; windowTitle = 'Last War: Survival' }
                            sequence     = [object[]]@(
                                [PSCustomObject]@{ type = 'MoveToPoint'; name = 'action-a'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' },
                                [PSCustomObject]@{ type = 'Loop'; name = 'my-loop'; iterations = 3; actionNames = [object[]]@('action-a') }
                            )
                        }
                    }
                }
                Mock Get-MacroFile -MockWith $mockMacroData

                $tc = $script:tc
                # 'Edit steps'
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Select '#3: Loop [[my-loop]]' (index 2)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Step options for last step: [0]Rename step [1]Move up [2][[Back to step list]]
                # Select '[Back to step list]' (index 2)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Step list: '[Back to edit menu]' (index 3)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Edit menu (no changes): '[Back]' (index 2)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-EditMacroScreen -Console $tc -FilePath 'C:\fake\20260101_000000_test-macro.json'

                $tc.Output | Should -Not -Match 'Move down'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Save changes — success
    # ════════════════════════════════════════════════════════════════════════
    Context 'When Save changes succeeds' {

        It 'Writes a success message containing saved successfully to the console' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockMacroData = {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version      = '1.0'
                            metadata     = [PSCustomObject]@{ name = 'test-macro'; createdUtc = '2026-01-01T00:00:00Z'; modifiedUtc = '2026-01-01T00:00:00Z'; description = '' }
                            targetWindow = [PSCustomObject]@{ processName = 'LastWar'; windowTitle = 'Last War: Survival' }
                            sequence     = [object[]]@(
                                [PSCustomObject]@{ type = 'MoveToPoint'; name = 'action-a'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' },
                                [PSCustomObject]@{ type = 'Loop'; name = 'my-loop'; iterations = 3; actionNames = [object[]]@('action-a') }
                            )
                        }
                    }
                }
                Mock Get-MacroFile  -MockWith $mockMacroData
                Mock Save-MacroFile { [PSCustomObject]@{ Success = $true; FilePath = 'C:\fake\20260101_000000_test-macro.json'; Message = '' } }

                $tc = $script:tc
                # Make a step change (add name to LeftClick) then save
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Edit steps'
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # '#2: LeftClick'
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Add name to step'
                $tc.Input.PushTextWithEnter('click-step')
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # '[Back to edit menu]'
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Save changes'

                Show-EditMacroScreen -Console $tc -FilePath 'C:\fake\20260101_000000_test-macro.json'

                $tc.Output | Should -Match 'saved successfully'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Save changes — failure
    # ════════════════════════════════════════════════════════════════════════
    Context 'When Save changes fails' {

        It 'Displays an error and does not exit the edit menu' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockMacroData = {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version      = '1.0'
                            metadata     = [PSCustomObject]@{ name = 'test-macro'; createdUtc = '2026-01-01T00:00:00Z'; modifiedUtc = '2026-01-01T00:00:00Z'; description = '' }
                            targetWindow = [PSCustomObject]@{ processName = 'LastWar'; windowTitle = 'Last War: Survival' }
                            sequence     = [object[]]@(
                                [PSCustomObject]@{ type = 'MoveToPoint'; name = 'action-a'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' },
                                [PSCustomObject]@{ type = 'Loop'; name = 'my-loop'; iterations = 3; actionNames = [object[]]@('action-a') }
                            )
                        }
                    }
                }
                Mock Get-MacroFile  -MockWith $mockMacroData
                Mock Save-MacroFile { [PSCustomObject]@{ Success = $false; FilePath = ''; Message = 'Disk full.' } }

                $tc = $script:tc
                # Make a step change then attempt save (which fails)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Edit steps'
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # '#2: LeftClick'
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Add name to step'
                $tc.Input.PushTextWithEnter('click-step')
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # '[Back to edit menu]'
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Save changes' — fails
                # Still on edit menu with changes; discard to exit
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Discard changes'
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Yes, discard'

                Show-EditMacroScreen -Console $tc -FilePath 'C:\fake\20260101_000000_test-macro.json'

                $tc.Output | Should -Match 'Error'
            }
        }

        It 'Calls Save-MacroFile exactly once before the failure' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockMacroData = {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version      = '1.0'
                            metadata     = [PSCustomObject]@{ name = 'test-macro'; createdUtc = '2026-01-01T00:00:00Z'; modifiedUtc = '2026-01-01T00:00:00Z'; description = '' }
                            targetWindow = [PSCustomObject]@{ processName = 'LastWar'; windowTitle = 'Last War: Survival' }
                            sequence     = [object[]]@(
                                [PSCustomObject]@{ type = 'MoveToPoint'; name = 'action-a'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' },
                                [PSCustomObject]@{ type = 'Loop'; name = 'my-loop'; iterations = 3; actionNames = [object[]]@('action-a') }
                            )
                        }
                    }
                }
                Mock Get-MacroFile  -MockWith $mockMacroData
                Mock Save-MacroFile { [PSCustomObject]@{ Success = $false; FilePath = ''; Message = 'Disk full.' } }

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Edit steps'
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # '#2: LeftClick'
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Add name to step'
                $tc.Input.PushTextWithEnter('click-step')
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # '[Back to edit menu]'
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Save changes' — fails
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Discard changes'
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Yes, discard'

                Show-EditMacroScreen -Console $tc -FilePath 'C:\fake\20260101_000000_test-macro.json'

                Should -Invoke Save-MacroFile -Exactly 1
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Discard changes — confirmed
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user discards changes and confirms' {

        It 'Does not call Save-MacroFile' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockMacroData = {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version      = '1.0'
                            metadata     = [PSCustomObject]@{ name = 'test-macro'; createdUtc = '2026-01-01T00:00:00Z'; modifiedUtc = '2026-01-01T00:00:00Z'; description = '' }
                            targetWindow = [PSCustomObject]@{ processName = 'LastWar'; windowTitle = 'Last War: Survival' }
                            sequence     = [object[]]@(
                                [PSCustomObject]@{ type = 'MoveToPoint'; name = 'action-a'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' },
                                [PSCustomObject]@{ type = 'Loop'; name = 'my-loop'; iterations = 3; actionNames = [object[]]@('action-a') }
                            )
                        }
                    }
                }
                Mock Get-MacroFile    -MockWith $mockMacroData
                Mock Get-LWASMacro { @() }
                Mock Save-MacroFile   {}
                Mock Rename-MacroFile {}

                $tc = $script:tc
                # Make a change (rename macro)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Rename macro'
                $tc.Input.PushTextWithEnter('new-name')
                # Edit menu with changes: [0]Rename [1]Edit steps [2]Save changes [3]Discard changes
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Discard changes'
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Yes, discard'

                Show-EditMacroScreen -Console $tc -FilePath 'C:\fake\20260101_000000_test-macro.json'

                Should -Not -Invoke Save-MacroFile
            }
        }

        It 'Does not call Rename-MacroFile' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockMacroData = {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version      = '1.0'
                            metadata     = [PSCustomObject]@{ name = 'test-macro'; createdUtc = '2026-01-01T00:00:00Z'; modifiedUtc = '2026-01-01T00:00:00Z'; description = '' }
                            targetWindow = [PSCustomObject]@{ processName = 'LastWar'; windowTitle = 'Last War: Survival' }
                            sequence     = [object[]]@(
                                [PSCustomObject]@{ type = 'MoveToPoint'; name = 'action-a'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' },
                                [PSCustomObject]@{ type = 'Loop'; name = 'my-loop'; iterations = 3; actionNames = [object[]]@('action-a') }
                            )
                        }
                    }
                }
                Mock Get-MacroFile    -MockWith $mockMacroData
                Mock Get-LWASMacro { @() }
                Mock Rename-MacroFile {}

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushTextWithEnter('new-name')
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Discard changes'
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Yes, discard'

                Show-EditMacroScreen -Console $tc -FilePath 'C:\fake\20260101_000000_test-macro.json'

                Should -Not -Invoke Rename-MacroFile
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Discard changes — declined
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user selects Discard changes but then chooses No keep editing' {

        It 'Returns the user to the edit menu without saving' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $mockMacroData = {
                    [PSCustomObject]@{
                        Valid    = $true
                        Messages = @()
                        Data     = [PSCustomObject]@{
                            version      = '1.0'
                            metadata     = [PSCustomObject]@{ name = 'test-macro'; createdUtc = '2026-01-01T00:00:00Z'; modifiedUtc = '2026-01-01T00:00:00Z'; description = '' }
                            targetWindow = [PSCustomObject]@{ processName = 'LastWar'; windowTitle = 'Last War: Survival' }
                            sequence     = [object[]]@(
                                [PSCustomObject]@{ type = 'MoveToPoint'; name = 'action-a'; position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 } },
                                [PSCustomObject]@{ type = 'LeftClick' },
                                [PSCustomObject]@{ type = 'Loop'; name = 'my-loop'; iterations = 3; actionNames = [object[]]@('action-a') }
                            )
                        }
                    }
                }
                Mock Get-MacroFile    -MockWith $mockMacroData
                Mock Get-LWASMacro { @() }
                Mock Save-MacroFile   {}

                $tc = $script:tc
                # Make a change (rename macro)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushTextWithEnter('new-name')
                # 'Discard changes' (index 3)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 'No, keep editing' (index 1)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Still on edit menu with changes; now actually discard to exit
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Discard changes'
                $tc.Input.PushKey([ConsoleKey]::Enter)          # 'Yes, discard'

                Show-EditMacroScreen -Console $tc -FilePath 'C:\fake\20260101_000000_test-macro.json'

                $tc.Output | Should -Match 'No, keep editing'
                Should -Not -Invoke Save-MacroFile
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Get-MacroFile returns null — load failure guard
    # ════════════════════════════════════════════════════════════════════════
    Context 'When Get-MacroFile returns null' {

        It 'Displays an error panel and returns without rendering the edit menu' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-MacroFile { $null }

                $tc = $script:tc

                { Show-EditMacroScreen -Console $tc -FilePath 'C:\fake\missing.json' } | Should -Not -Throw

                $tc.Output | Should -Match 'Error'
                $tc.Output | Should -Not -Match 'Rename macro'
            }
        }
    }
}
