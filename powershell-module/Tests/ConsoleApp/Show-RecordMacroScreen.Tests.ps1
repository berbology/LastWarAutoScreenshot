BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force

    # Spectre.Console.Testing.dll ships in lib\test\ and is required for TestConsole
    $testingDll = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll

}

Describe 'Show-RecordMacroScreen' -Tag 'Unit' {

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
    # Context: Config validation failures
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the config has no ProcessName' {

        It 'Returns $null and output contains "No target window configured"' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Write-LastWarLog {}

                $tc = $script:tc

                $result = Show-RecordMacroScreen -Console $tc
                $result | Should -BeNullOrEmpty
                $tc.Output | Should -Match 'No target window configured'
            }
        }
    }

    Context 'When the target window handle is no longer valid' {

        It 'Returns $null and output contains "no longer open"' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $false }
                Mock Write-LastWarLog {}

                $tc = $script:tc

                $result = Show-RecordMacroScreen -Console $tc
                $result | Should -BeNullOrEmpty
                $tc.Output | Should -Match 'no longer open'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Immediate discard — empty sequence
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user enters a name then immediately discards with no actions recorded' {

        It 'Does not call Save-MacroFile and returns $null' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Save-MacroFile -MockWith { @{ Success = $true; FilePath = 'C:\dummy.json' } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }

                $tc = $script:tc
                # Macro name
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action menu (empty sequence, no Create loop, no Save macro):
                # 0=Move, 1=Box, 2=Circle, 3=Left, 4=Drag, 5=Screenshot, 6=Delay, 7=Discard
                # 7 DownArrows → 'Discard and exit'
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # No confirmation prompt since sequence is empty

                $result = Show-RecordMacroScreen -Console $tc
                $result | Should -BeNullOrEmpty
                Should -Invoke Save-MacroFile -Times 0 -Exactly
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Recording individual action types
    # ════════════════════════════════════════════════════════════════════════
    Context 'When recording a MoveToPoint action' {

        It 'Calls Save-MacroFile with sequence[0].type = MoveToPoint and the captured relative coordinates' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Invoke-CaptureMousePosition -MockWith {
                    [PSCustomObject]@{ RelativeX = 0.5; RelativeY = 0.3 }
                }
                $script:_savedMacroData = $null
                Mock Save-MacroFile -MockWith {
                    $script:_savedMacroData = $MacroData
                    @{ Success = $true; FilePath = 'C:\dummy.json' }
                }

                $tc = $script:tc
                # Macro name
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action menu: Enter → index 0 'Move mouse to point'
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action name: Enter (skip — unnamed)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action menu (1 unnamed action → no Create loop, Save macro at 7):
                # 0=Move, 1=Box, 2=Circle, 3=Left, 4=Drag, 5=Screenshot, 6=Delay, 7=Save, 8=Discard
                # 7 DownArrows → 'Save macro'
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                Should -Invoke Save-MacroFile -Times 1
                $script:_savedMacroData.sequence[0].type | Should -Be 'MoveToPoint'
                $script:_savedMacroData.sequence[0].position.relativeX | Should -Be 0.5
                $script:_savedMacroData.sequence[0].position.relativeY | Should -Be 0.3
            }
        }
    }

    Context 'When recording a MoveToRegion (box) action' {

        It 'Calls Save-MacroFile with region.type = Box and positive relativeWidth and relativeHeight' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                $script:_boxCaptureCount = 0
                Mock Invoke-CaptureMousePosition -MockWith {
                    $script:_boxCaptureCount++
                    if ($script:_boxCaptureCount -eq 1) {
                        [PSCustomObject]@{ RelativeX = 0.1; RelativeY = 0.2 }   # top-left
                    } else {
                        [PSCustomObject]@{ RelativeX = 0.4; RelativeY = 0.6 }   # bottom-right
                    }
                }
                $script:_savedMacroData = $null
                Mock Save-MacroFile -MockWith {
                    $script:_savedMacroData = $MacroData
                    @{ Success = $true; FilePath = 'C:\dummy.json' }
                }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action menu: 1 DownArrow → index 1 'Move mouse to region (box)'
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action name: Enter (skip)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 7 DownArrows → 'Save macro'
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                Should -Invoke Save-MacroFile -Times 1
                $script:_savedMacroData.sequence[0].type | Should -Be 'MoveToRegion'
                $script:_savedMacroData.sequence[0].region.type | Should -Be 'Box'
                $script:_savedMacroData.sequence[0].region.relativeWidth | Should -BeGreaterThan 0
                $script:_savedMacroData.sequence[0].region.relativeHeight | Should -BeGreaterThan 0
            }
        }
    }

    Context 'When recording a MoveToRegion (circle) action' {

        It 'Calls Save-MacroFile with relativeRadius = sqrt(dx^2+dy^2) rounded to 4 decimal places' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                $script:_circleCaptureCount = 0
                Mock Invoke-CaptureMousePosition -MockWith {
                    $script:_circleCaptureCount++
                    if ($script:_circleCaptureCount -eq 1) {
                        [PSCustomObject]@{ RelativeX = 0.2; RelativeY = 0.3 }   # centre
                    } else {
                        # edge: dx=0.3, dy=0.4 → radius = sqrt(0.09+0.16) = 0.5
                        [PSCustomObject]@{ RelativeX = 0.5; RelativeY = 0.7 }
                    }
                }
                $script:_savedMacroData = $null
                Mock Save-MacroFile -MockWith {
                    $script:_savedMacroData = $MacroData
                    @{ Success = $true; FilePath = 'C:\dummy.json' }
                }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action menu: 2 DownArrows → index 2 'Move mouse to region (circle)'
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action name: Enter (skip)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 7 DownArrows → 'Save macro'
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                $expectedRadius = [math]::Round([math]::Sqrt([math]::Pow(0.3, 2) + [math]::Pow(0.4, 2)), 4)
                $script:_savedMacroData.sequence[0].region.relativeRadius | Should -Be $expectedRadius
            }
        }
    }

    Context 'When recording a LeftClick action' {

        It 'Does not call Invoke-CaptureMousePosition and saves type = LeftClick' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Invoke-CaptureMousePosition -MockWith {
                    [PSCustomObject]@{ RelativeX = 0.0; RelativeY = 0.0 }
                }
                $script:_savedMacroData = $null
                Mock Save-MacroFile -MockWith {
                    $script:_savedMacroData = $MacroData
                    @{ Success = $true; FilePath = 'C:\dummy.json' }
                }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action menu: 3 DownArrows → index 3 'Left-click'
                for ($i = 0; $i -lt 3; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action name: Enter (skip)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 7 DownArrows → 'Save macro'
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                Should -Invoke Invoke-CaptureMousePosition -Times 0 -Exactly
                $script:_savedMacroData.sequence[0].type | Should -Be 'LeftClick'
            }
        }
    }

    Context 'When recording a DragClick action' {

        It 'Calls Save-MacroFile with type = DragClick and correct start and end positions' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                $script:_dragCaptureCount = 0
                Mock Invoke-CaptureMousePosition -MockWith {
                    $script:_dragCaptureCount++
                    if ($script:_dragCaptureCount -eq 1) {
                        [PSCustomObject]@{ RelativeX = 0.2; RelativeY = 0.3 }   # start
                    } else {
                        [PSCustomObject]@{ RelativeX = 0.8; RelativeY = 0.7 }   # end
                    }
                }
                $script:_savedMacroData = $null
                Mock Save-MacroFile -MockWith {
                    $script:_savedMacroData = $MacroData
                    @{ Success = $true; FilePath = 'C:\dummy.json' }
                }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action menu: 4 DownArrows → index 4 'Drag-click'
                for ($i = 0; $i -lt 4; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action name: Enter (skip)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 7 DownArrows → 'Save macro'
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                Should -Invoke Save-MacroFile -Times 1
                $script:_savedMacroData.sequence[0].type | Should -Be 'DragClick'
                $script:_savedMacroData.sequence[0].start.relativeX | Should -Be 0.2
                $script:_savedMacroData.sequence[0].end.relativeX | Should -Be 0.8
            }
        }
    }

    Context 'When recording a Screenshot region action' {

        It 'Saves type = Screenshot with correct region coordinates' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                $script:_ssCaptureCount = 0
                Mock Invoke-CaptureMousePosition -MockWith {
                    $script:_ssCaptureCount++
                    if ($script:_ssCaptureCount -eq 1) {
                        [PSCustomObject]@{ RelativeX = 0.1; RelativeY = 0.1 }   # top-left
                    } else {
                        [PSCustomObject]@{ RelativeX = 0.9; RelativeY = 0.9 }   # bottom-right
                    }
                }
                $script:_savedMacroData = $null
                Mock Save-MacroFile -MockWith {
                    $script:_savedMacroData = $MacroData
                    @{ Success = $true; FilePath = 'C:\dummy.json' }
                }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action menu: 5 DownArrows → index 5 'Screenshot region'
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Mask prompt: 'Add a black-out region?' → DownArrow + Enter → 'No'
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action name: Enter (skip)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 7 DownArrows → 'Save macro'
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                $script:_savedMacroData.sequence[0].type | Should -Be 'Screenshot'
                $script:_savedMacroData.sequence[0].region.topLeft.relativeX | Should -Be 0.1
                $script:_savedMacroData.sequence[0].region.topLeft.relativeY | Should -Be 0.1
                $script:_savedMacroData.sequence[0].region.bottomRight.relativeX | Should -Be 0.9
                $script:_savedMacroData.sequence[0].region.bottomRight.relativeY | Should -Be 0.9
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Screenshot mask region recording
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user responds No to Add a black-out region' {

        It 'The resulting Screenshot action has no maskRegions property' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                $script:_captureCount = 0
                Mock Invoke-CaptureMousePosition -MockWith {
                    $script:_captureCount++
                    if ($script:_captureCount -eq 1) { [PSCustomObject]@{ RelativeX = 0.1; RelativeY = 0.1 } }
                    else                              { [PSCustomObject]@{ RelativeX = 0.9; RelativeY = 0.9 } }
                }
                $script:_savedMacroData = $null
                Mock Save-MacroFile -MockWith {
                    $script:_savedMacroData = $MacroData
                    @{ Success = $true; FilePath = 'C:\dummy.json' }
                }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Screenshot region
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Mask prompt → No
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action name: skip
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Save macro
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                $script:_savedMacroData.sequence[0].PSObject.Properties['maskRegions'] | Should -BeNullOrEmpty
            }
        }
    }

    Context 'When the user adds one mask region and responds No to Add another' {

        It 'The Screenshot action has maskRegions with one element containing the correct coordinates' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                $script:_captureCount = 0
                Mock Invoke-CaptureMousePosition -MockWith {
                    $script:_captureCount++
                    switch ($script:_captureCount) {
                        1 { [PSCustomObject]@{ RelativeX = 0.1; RelativeY = 0.1 } }  # ss top-left
                        2 { [PSCustomObject]@{ RelativeX = 0.9; RelativeY = 0.9 } }  # ss bottom-right
                        3 { [PSCustomObject]@{ RelativeX = 0.2; RelativeY = 0.2 } }  # mask top-left
                        4 { [PSCustomObject]@{ RelativeX = 0.5; RelativeY = 0.5 } }  # mask bottom-right
                    }
                }
                $script:_savedMacroData = $null
                Mock Save-MacroFile -MockWith {
                    $script:_savedMacroData = $MacroData
                    @{ Success = $true; FilePath = 'C:\dummy.json' }
                }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Screenshot region
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # First mask prompt → Yes (Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second mask prompt ('Add another?') → No
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action name: skip
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Save macro
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                $maskRegions = $script:_savedMacroData.sequence[0].maskRegions
                $maskRegions | Should -Not -BeNullOrEmpty
                $maskRegions.Count | Should -Be 1
                $maskRegions[0].topLeft.relativeX     | Should -Be 0.2
                $maskRegions[0].topLeft.relativeY     | Should -Be 0.2
                $maskRegions[0].bottomRight.relativeX | Should -Be 0.5
                $maskRegions[0].bottomRight.relativeY | Should -Be 0.5
            }
        }
    }

    Context 'When the user adds two mask regions' {

        It 'The Screenshot action has maskRegions with two elements' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                $script:_captureCount = 0
                Mock Invoke-CaptureMousePosition -MockWith {
                    $script:_captureCount++
                    switch ($script:_captureCount) {
                        1 { [PSCustomObject]@{ RelativeX = 0.0; RelativeY = 0.0 } }  # ss top-left
                        2 { [PSCustomObject]@{ RelativeX = 1.0; RelativeY = 1.0 } }  # ss bottom-right
                        3 { [PSCustomObject]@{ RelativeX = 0.1; RelativeY = 0.1 } }  # mask 1 top-left
                        4 { [PSCustomObject]@{ RelativeX = 0.3; RelativeY = 0.3 } }  # mask 1 bottom-right
                        5 { [PSCustomObject]@{ RelativeX = 0.6; RelativeY = 0.6 } }  # mask 2 top-left
                        6 { [PSCustomObject]@{ RelativeX = 0.9; RelativeY = 0.9 } }  # mask 2 bottom-right
                    }
                }
                $script:_savedMacroData = $null
                Mock Save-MacroFile -MockWith {
                    $script:_savedMacroData = $MacroData
                    @{ Success = $true; FilePath = 'C:\dummy.json' }
                }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Screenshot region
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # First mask prompt → Yes
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 'Add another?' → Yes
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 'Add another?' → No
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action name: skip
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Save macro
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                $script:_savedMacroData.sequence[0].maskRegions.Count | Should -Be 2
            }
        }
    }

    Context 'When the user cancels during mask top-left capture' {

        It 'No mask region is added and the loop exits cleanly' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                $script:_captureCount = 0
                Mock Invoke-CaptureMousePosition -MockWith {
                    $script:_captureCount++
                    switch ($script:_captureCount) {
                        1 { [PSCustomObject]@{ RelativeX = 0.1; RelativeY = 0.1 } }  # ss top-left
                        2 { [PSCustomObject]@{ RelativeX = 0.9; RelativeY = 0.9 } }  # ss bottom-right
                        3 { $null }                                                    # mask top-left: cancel
                    }
                }
                $script:_savedMacroData = $null
                Mock Save-MacroFile -MockWith {
                    $script:_savedMacroData = $MacroData
                    @{ Success = $true; FilePath = 'C:\dummy.json' }
                }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Screenshot region
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # First mask prompt → Yes
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # (mock returns $null for mask top-left → loop exits)
                # Action name: skip
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Save macro
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                $script:_savedMacroData.sequence[0].PSObject.Properties['maskRegions'] | Should -BeNullOrEmpty
            }
        }
    }

    Context 'When captured mask region has bottomRight.relativeX <= topLeft.relativeX' {

        It 'A warning is written and no mask region is added' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                $script:_captureCount = 0
                Mock Invoke-CaptureMousePosition -MockWith {
                    $script:_captureCount++
                    switch ($script:_captureCount) {
                        1 { [PSCustomObject]@{ RelativeX = 0.1; RelativeY = 0.1 } }  # ss top-left
                        2 { [PSCustomObject]@{ RelativeX = 0.9; RelativeY = 0.9 } }  # ss bottom-right
                        3 { [PSCustomObject]@{ RelativeX = 0.5; RelativeY = 0.2 } }  # mask top-left
                        4 { [PSCustomObject]@{ RelativeX = 0.3; RelativeY = 0.8 } }  # mask bottom-right: X too small
                    }
                }
                $script:_savedMacroData = $null
                Mock Save-MacroFile -MockWith {
                    $script:_savedMacroData = $MacroData
                    @{ Success = $true; FilePath = 'C:\dummy.json' }
                }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Screenshot region
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # First mask prompt → Yes
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 'Add another?' after invalid mask → No
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action name: skip
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Save macro
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                $tc.Output | Should -Match 'must be below and to the right'
                $script:_savedMacroData.sequence[0].PSObject.Properties['maskRegions'] | Should -BeNullOrEmpty
            }
        }
    }

    Context 'When mask region has no overlap with the screenshot region' {

        It 'The no-overlap warning is written but the mask IS added to the action' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                $script:_captureCount = 0
                Mock Invoke-CaptureMousePosition -MockWith {
                    $script:_captureCount++
                    switch ($script:_captureCount) {
                        1 { [PSCustomObject]@{ RelativeX = 0.0; RelativeY = 0.0 } }  # ss top-left
                        2 { [PSCustomObject]@{ RelativeX = 0.5; RelativeY = 0.5 } }  # ss bottom-right
                        3 { [PSCustomObject]@{ RelativeX = 0.6; RelativeY = 0.6 } }  # mask top-left (outside ss)
                        4 { [PSCustomObject]@{ RelativeX = 0.9; RelativeY = 0.9 } }  # mask bottom-right (outside ss)
                    }
                }
                $script:_savedMacroData = $null
                Mock Save-MacroFile -MockWith {
                    $script:_savedMacroData = $MacroData
                    @{ Success = $true; FilePath = 'C:\dummy.json' }
                }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Screenshot region
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # First mask prompt → Yes
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 'Add another?' → No
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action name: skip
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Save macro
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                $tc.Output | Should -Match 'no visible effect'
                $script:_savedMacroData.sequence[0].maskRegions.Count | Should -Be 1
            }
        }
    }

    Context 'Step detail display for Screenshot actions' {

        It 'Step detail for a Screenshot action with two mask regions contains "2 mask(s)"' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                $script:_captureCount = 0
                Mock Invoke-CaptureMousePosition -MockWith {
                    $script:_captureCount++
                    switch ($script:_captureCount) {
                        1 { [PSCustomObject]@{ RelativeX = 0.0; RelativeY = 0.0 } }
                        2 { [PSCustomObject]@{ RelativeX = 1.0; RelativeY = 1.0 } }
                        3 { [PSCustomObject]@{ RelativeX = 0.1; RelativeY = 0.1 } }
                        4 { [PSCustomObject]@{ RelativeX = 0.3; RelativeY = 0.3 } }
                        5 { [PSCustomObject]@{ RelativeX = 0.6; RelativeY = 0.6 } }
                        6 { [PSCustomObject]@{ RelativeX = 0.9; RelativeY = 0.9 } }
                    }
                }
                Mock Save-MacroFile -MockWith { @{ Success = $true; FilePath = 'C:\dummy.json' } }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Screenshot region
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Mask prompt → Yes
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 'Add another?' → Yes
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 'Add another?' → No
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action name: skip
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Save macro
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                $tc.Output | Should -Match '2 mask\(s\)'
            }
        }

        It 'Step detail for a Screenshot action with no maskRegions does not contain "mask"' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                $script:_captureCount = 0
                Mock Invoke-CaptureMousePosition -MockWith {
                    $script:_captureCount++
                    if ($script:_captureCount -eq 1) { [PSCustomObject]@{ RelativeX = 0.1; RelativeY = 0.1 } }
                    else                              { [PSCustomObject]@{ RelativeX = 0.9; RelativeY = 0.9 } }
                }
                Mock Save-MacroFile -MockWith { @{ Success = $true; FilePath = 'C:\dummy.json' } }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Screenshot region
                for ($i = 0; $i -lt 5; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Mask prompt → No
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action name: skip
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Save macro
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                # Output from second loop iteration (step table showing the added screenshot action)
                # should not contain 'mask' anywhere
                $tc.Output | Should -Not -Match 'mask\(s\)'
            }
        }
    }

    Context 'When recording a Delay action' {

        It 'Calls Save-MacroFile with type = Delay and seconds = 5' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                $script:_savedMacroData = $null
                Mock Save-MacroFile -MockWith {
                    $script:_savedMacroData = $MacroData
                    @{ Success = $true; FilePath = 'C:\dummy.json' }
                }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action menu: 6 DownArrows → index 6 'Add delay'
                for ($i = 0; $i -lt 6; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Delay input: '5' + Enter
                $tc.Input.PushText('5')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action name: Enter (skip)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 7 DownArrows → 'Save macro'
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                $script:_savedMacroData.sequence[0].type | Should -Be 'Delay'
                $script:_savedMacroData.sequence[0].seconds | Should -Be 5
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Loop creation
    # ════════════════════════════════════════════════════════════════════════
    Context 'When creating a Loop action' {

        It 'Saves a Loop action with the selected actionNames and correct iteration count' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                $script:_savedMacroData = $null
                Mock Save-MacroFile -MockWith {
                    $script:_savedMacroData = $MacroData
                    @{ Success = $true; FilePath = 'C:\dummy.json' }
                }

                $tc = $script:tc
                # Macro name
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)

                # Add named LeftClick 'action-one': 3 DownArrows → index 3 'Left-click'
                for ($i = 0; $i -lt 3; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('action-one')
                $tc.Input.PushKey([ConsoleKey]::Enter)

                # Add named LeftClick 'action-two': 3 DownArrows → 'Left-click'
                for ($i = 0; $i -lt 3; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('action-two')
                $tc.Input.PushKey([ConsoleKey]::Enter)

                # Action menu (2 named LeftClicks → Create loop at index 7):
                # 0=Move, 1=Box, 2=Circle, 3=Left, 4=Drag, 5=Screenshot, 6=Delay, 7=Create loop, 8=Save, 9=Discard
                # 7 DownArrows → 'Create loop'
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                # Loop selection — choices: action-one(0), action-two(1), Done(2), Cancel(3)
                # Round 1: Enter → 'action-one'
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Round 2: DownArrow + Enter → 'action-two'
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Round 3: 2 DownArrows + Enter → 'Done adding actions'
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                # Loop count: '3' + Enter
                $tc.Input.PushText('3')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Loop action name: Enter (skip)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                # Action menu (3 actions; named non-Loop still exist → Create loop at 7):
                # 0=Move, 1=Box, 2=Circle, 3=Left, 4=Drag, 5=Screenshot, 6=Delay, 7=Create loop, 8=Save, 9=Discard
                # 8 DownArrows → 'Save macro'
                for ($i = 0; $i -lt 8; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                Should -Invoke Save-MacroFile -Times 1
                $script:_savedMacroData.sequence[2].type | Should -Be 'Loop'
                $script:_savedMacroData.sequence[2].actionNames | Should -Be @('action-one', 'action-two')
                $script:_savedMacroData.sequence[2].iterations | Should -Be 3
            }
        }

        It 'Does not show "Create loop" option when no named non-Loop actions exist' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Save-MacroFile -MockWith { @{ Success = $true; FilePath = 'C:\dummy.json' } }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Add unnamed LeftClick: 3 DownArrows + Enter
                for ($i = 0; $i -lt 3; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action name: Enter (skip — unnamed)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action menu (1 unnamed action — no Create loop, Save at 7):
                # 7 DownArrows → 'Save macro'
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                $tc.Output | Should -Not -Match 'Create loop'
            }
        }

        It 'Shows "Create loop" option in the action menu after a named action is recorded' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Save-MacroFile -MockWith { @{ Success = $true; FilePath = 'C:\dummy.json' } }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Add named LeftClick 'action-one': 3 DownArrows + Enter
                for ($i = 0; $i -lt 3; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushText('action-one')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Second menu render: Create loop now at 7, Save at 8
                # 8 DownArrows → 'Save macro'
                for ($i = 0; $i -lt 8; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                $tc.Output | Should -Match 'Create loop'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Save macro visibility
    # ════════════════════════════════════════════════════════════════════════
    Context 'Save macro menu item visibility' {

        It 'Does not show "Save macro" in the action menu when the sequence is empty' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Discard immediately (sequence empty): 7 DownArrows → 'Discard and exit'
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                $tc.Output | Should -Not -Match 'Save macro'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Discard behaviour
    # ════════════════════════════════════════════════════════════════════════
    Context 'When discarding with recorded actions' {

        It 'Shows "Are you sure" confirmation and returns $null when user confirms discard' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Add unnamed LeftClick: 3 DownArrows + Enter
                for ($i = 0; $i -lt 3; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action name: Enter (skip)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action menu (1 action, Save at 7, Discard at 8):
                # 8 DownArrows → 'Discard and exit'
                for ($i = 0; $i -lt 8; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Confirmation: Enter → 'Yes, discard' (index 0)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-RecordMacroScreen -Console $tc
                $result | Should -BeNullOrEmpty
                $tc.Output | Should -Match 'Are you sure'
            }
        }

        It 'Continues recording when the user declines discard' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Save-MacroFile -MockWith { @{ Success = $true; FilePath = 'C:\dummy.json' } }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Add unnamed LeftClick
                for ($i = 0; $i -lt 3; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action name: Enter (skip)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 8 DownArrows → 'Discard and exit'
                for ($i = 0; $i -lt 8; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Confirmation: DownArrow + Enter → 'No, continue recording' (index 1)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Back in action loop — save to exit: 7 DownArrows → 'Save macro'
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-RecordMacroScreen -Console $tc
                $result | Should -BeNullOrEmpty
                Should -Invoke Save-MacroFile -Times 1
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Macro name auto-fix (spaces → hyphens)
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the macro name contains spaces' {

        It 'Shows a sanitised name confirmation and saves using the sanitised name' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                # Specific mock for the spaced name → auto-fixed
                Mock Get-ValidMacroName -ParameterFilter { $Name -eq 'my macro' } -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = 'my-macro'; WasAutoFixed = $true; Message = '' }
                }
                # General mock for all other names (action names etc.)
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                $script:_savedMacroData = $null
                Mock Save-MacroFile -MockWith {
                    $script:_savedMacroData = $MacroData
                    @{ Success = $true; FilePath = 'C:\dummy.json' }
                }

                $tc = $script:tc
                # Macro name with spaces
                $tc.Input.PushText('my macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Auto-fix confirmation prompt: Enter → 'Use "my-macro"' (index 0)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Add unnamed LeftClick: 3 DownArrows + Enter
                for ($i = 0; $i -lt 3; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action name: Enter (skip)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 7 DownArrows → 'Save macro'
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                $script:_savedMacroData.metadata.name | Should -Be 'my-macro'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Save failure
    # ════════════════════════════════════════════════════════════════════════
    Context 'When Save-MacroFile returns a failure result' {

        It 'Displays the error message and allows the user to discard and exit' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Save-MacroFile -MockWith {
                    @{ Success = $false; Message = 'Disk full' }
                }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Add unnamed LeftClick
                for ($i = 0; $i -lt 3; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action name: Enter (skip)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 7 DownArrows → 'Save macro'
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Save fails; error panel shown; back in action loop
                # 8 DownArrows → 'Discard and exit' (Save still at 7, Discard at 8)
                for ($i = 0; $i -lt 8; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Confirmation: Enter → 'Yes, discard'
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-RecordMacroScreen -Console $tc
                $result | Should -BeNullOrEmpty
                $tc.Output | Should -Match 'Disk full'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Save confirmation banner
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user records and saves a macro' {

        It 'Writes a "Saved" panel containing "saved successfully" to the console' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Invoke-CaptureMousePosition -MockWith {
                    [PSCustomObject]@{ RelativeX = 0.0; RelativeY = 0.0 }
                }
                Mock Save-MacroFile -MockWith { @{ Success = $true; FilePath = 'C:\dummy.json' } }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action menu: 3 DownArrows → index 3 'Left-click'
                for ($i = 0; $i -lt 3; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action name: Enter (skip)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 7 DownArrows → 'Save macro' (index 7; no Create loop; Discard is at index 8)
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                $tc.Output | Should -Match 'saved successfully'
            }
        }

        It 'The "Saved" panel output contains the macro name' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ ProcessName = 'game.exe'; WindowTitle = 'Game'; WindowHandleInt64 = 12345 }
                }
                Mock Test-WindowHandleValid -MockWith { $true }
                Mock Get-LWASMacro -MockWith { @() }
                Mock Test-MacroFile -MockWith { @{ Valid = $true; Messages = @() } }
                Mock Write-LastWarLog {}
                Mock Get-ValidMacroName -MockWith {
                    [PSCustomObject]@{ Valid = $true; SanitisedName = $Name; WasAutoFixed = $false; Message = '' }
                }
                Mock Invoke-CaptureMousePosition -MockWith {
                    [PSCustomObject]@{ RelativeX = 0.0; RelativeY = 0.0 }
                }
                Mock Save-MacroFile -MockWith { @{ Success = $true; FilePath = 'C:\dummy.json' } }

                $tc = $script:tc
                $tc.Input.PushText('my-macro')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action menu: 3 DownArrows → index 3 'Left-click'
                for ($i = 0; $i -lt 3; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Action name: Enter (skip)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # 7 DownArrows → 'Save macro' (index 7; no Create loop; Discard is at index 8)
                for ($i = 0; $i -lt 7; $i++) { $tc.Input.PushKey([ConsoleKey]::DownArrow) }
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-RecordMacroScreen -Console $tc | Out-Null
                $tc.Output | Should -Match 'my-macro'
            }
        }
    }
}
