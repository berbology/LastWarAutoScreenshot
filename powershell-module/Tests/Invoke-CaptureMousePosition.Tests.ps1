BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force

    $testingDll = Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}

Describe 'Invoke-CaptureMousePosition' -Tag 'Unit' {

    # ════════════════════════════════════════════════════════════════════════
    # Context: User accepts the first capture
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user accepts the first capture' {

        It 'Returns a PSCustomObject with correct RelativeX and RelativeY' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 300; Y = 200 } }
                Mock Get-WindowBounds {
                    [PSCustomObject]@{ Left = 100; Top = 100; Right = 500; Bottom = 500; Width = 400; Height = 400 }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)   # Submit empty text prompt
                $tc.Input.PushKey([ConsoleKey]::Enter)   # SelectionPrompt: confirm 'Accept' (first option)

                $result = Invoke-CaptureMousePosition `
                    -WindowHandle ([IntPtr]::new(1001)) `
                    -Console $tc `
                    -PromptMessage 'Test prompt'

                $result | Should -Not -BeNullOrEmpty
                $result.RelativeX | Should -BeOfType [double]
                $result.RelativeX | Should -Be 0.5
                $result.RelativeY | Should -BeOfType [double]
                $result.RelativeY | Should -Be 0.25
            }
        }

        It 'Returns AbsoluteX and AbsoluteY matching the captured cursor position' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 300; Y = 200 } }
                Mock Get-WindowBounds {
                    [PSCustomObject]@{ Left = 100; Top = 100; Right = 500; Bottom = 500; Width = 400; Height = 400 }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Invoke-CaptureMousePosition `
                    -WindowHandle ([IntPtr]::new(1001)) `
                    -Console $tc `
                    -PromptMessage 'Test prompt'

                $result.AbsoluteX | Should -BeOfType [int]
                $result.AbsoluteX | Should -Be 300
                $result.AbsoluteY | Should -BeOfType [int]
                $result.AbsoluteY | Should -Be 200
            }
        }

        It 'Returns an object with RelativeX, RelativeY, AbsoluteX, and AbsoluteY properties' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 300; Y = 200 } }
                Mock Get-WindowBounds {
                    [PSCustomObject]@{ Left = 100; Top = 100; Right = 500; Bottom = 500; Width = 400; Height = 400 }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Invoke-CaptureMousePosition `
                    -WindowHandle ([IntPtr]::new(1001)) `
                    -Console $tc `
                    -PromptMessage 'Test prompt'

                $result.PSObject.Properties.Name | Should -Contain 'RelativeX'
                $result.PSObject.Properties.Name | Should -Contain 'RelativeY'
                $result.PSObject.Properties.Name | Should -Contain 'AbsoluteX'
                $result.PSObject.Properties.Name | Should -Contain 'AbsoluteY'
            }
        }

        It 'Displays the PromptMessage text in the console output' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 300; Y = 200 } }
                Mock Get-WindowBounds {
                    [PSCustomObject]@{ Left = 100; Top = 100; Right = 500; Bottom = 500; Width = 400; Height = 400 }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Invoke-CaptureMousePosition `
                    -WindowHandle ([IntPtr]::new(1001)) `
                    -Console $tc `
                    -PromptMessage 'Position the mouse now' | Out-Null

                $tc.Output | Should -Match 'Position the mouse now'
            }
        }

        It 'Displays the captured position in the console output' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 300; Y = 200 } }
                Mock Get-WindowBounds {
                    [PSCustomObject]@{ Left = 100; Top = 100; Right = 500; Bottom = 500; Width = 400; Height = 400 }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Invoke-CaptureMousePosition `
                    -WindowHandle ([IntPtr]::new(1001)) `
                    -Console $tc `
                    -PromptMessage 'Test prompt' | Out-Null

                $tc.Output | Should -Match 'Position captured'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Position outside window triggers automatic redo
    # $script:_icmpCallCount is set/reset in BeforeEach/AfterEach so that
    # each It block starts with a clean counter in the module's script scope.
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the first captured position is outside the window bounds' {

        BeforeEach {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $script:_icmpCallCount = 0
            }
        }

        AfterEach {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Remove-Variable -Name '_icmpCallCount' -Scope Script -ErrorAction SilentlyContinue
            }
        }

        It 'Displays a warning containing "outside the target window" and then returns correct coordinates on the second capture' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-GetCursorPosition {
                    $script:_icmpCallCount++
                    if ($script:_icmpCallCount -eq 1) {
                        return [PSCustomObject]@{ X = 50; Y = 50 }   # outside window (Left=100)
                    }
                    return [PSCustomObject]@{ X = 300; Y = 200 }     # inside window
                }
                Mock Get-WindowBounds {
                    [PSCustomObject]@{ Left = 100; Top = 100; Right = 500; Bottom = 500; Width = 400; Height = 400 }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)   # text prompt: first (outside) capture
                $tc.Input.PushKey([ConsoleKey]::Enter)   # text prompt: second (inside) capture
                $tc.Input.PushKey([ConsoleKey]::Enter)   # SelectionPrompt: 'Accept'

                $result = Invoke-CaptureMousePosition `
                    -WindowHandle ([IntPtr]::new(1001)) `
                    -Console $tc `
                    -PromptMessage 'Test prompt'

                $tc.Output | Should -Match 'outside the target window'
                $result | Should -Not -BeNullOrEmpty
                $result.RelativeX | Should -BeOfType [double]
                $result.RelativeX | Should -Be 0.5
                $result.RelativeY | Should -BeOfType [double]
                $result.RelativeY | Should -Be 0.25
            }
        }

        It 'Calls Invoke-GetCursorPosition at least twice when the first position is outside the window' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-GetCursorPosition {
                    $script:_icmpCallCount++
                    if ($script:_icmpCallCount -eq 1) {
                        return [PSCustomObject]@{ X = 50; Y = 50 }
                    }
                    return [PSCustomObject]@{ X = 300; Y = 200 }
                }
                Mock Get-WindowBounds {
                    [PSCustomObject]@{ Left = 100; Top = 100; Right = 500; Bottom = 500; Width = 400; Height = 400 }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Invoke-CaptureMousePosition `
                    -WindowHandle ([IntPtr]::new(1001)) `
                    -Console $tc `
                    -PromptMessage 'Test prompt' | Out-Null

                Should -Invoke Invoke-GetCursorPosition -Times 2
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: User selects Redo
    # $script:_icmpRedoCallCount tracks which capture is being returned.
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user selects Redo after the first capture' {

        BeforeEach {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $script:_icmpRedoCallCount = 0
            }
        }

        AfterEach {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Remove-Variable -Name '_icmpRedoCallCount' -Scope Script -ErrorAction SilentlyContinue
            }
        }

        It 'Returns the position from the second capture, not the first' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-GetCursorPosition {
                    $script:_icmpRedoCallCount++
                    if ($script:_icmpRedoCallCount -eq 1) {
                        return [PSCustomObject]@{ X = 300; Y = 200 }   # first: RelativeX=0.5
                    }
                    return [PSCustomObject]@{ X = 200; Y = 200 }       # second: RelativeX=0.25
                }
                Mock Get-WindowBounds {
                    [PSCustomObject]@{ Left = 100; Top = 100; Right = 500; Bottom = 500; Width = 400; Height = 400 }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)       # text prompt: first capture
                $tc.Input.PushKey([ConsoleKey]::DownArrow)   # SelectionPrompt: move to 'Redo' (index 1)
                $tc.Input.PushKey([ConsoleKey]::Enter)       # SelectionPrompt: confirm 'Redo'
                $tc.Input.PushKey([ConsoleKey]::Enter)       # text prompt: second capture
                $tc.Input.PushKey([ConsoleKey]::Enter)       # SelectionPrompt: confirm 'Accept' (index 0)

                $result = Invoke-CaptureMousePosition `
                    -WindowHandle ([IntPtr]::new(1001)) `
                    -Console $tc `
                    -PromptMessage 'Test prompt'

                $result | Should -Not -BeNullOrEmpty
                $result.RelativeX | Should -BeOfType [double]
                $result.RelativeX | Should -Be 0.25
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: User selects Cancel
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user selects Cancel' {

        It 'Returns $null' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 300; Y = 200 } }
                Mock Get-WindowBounds {
                    [PSCustomObject]@{ Left = 100; Top = 100; Right = 500; Bottom = 500; Width = 400; Height = 400 }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)       # text prompt
                $tc.Input.PushKey([ConsoleKey]::DownArrow)   # SelectionPrompt: move to 'Redo'
                $tc.Input.PushKey([ConsoleKey]::DownArrow)   # SelectionPrompt: move to 'Cancel' (index 2)
                $tc.Input.PushKey([ConsoleKey]::Enter)       # SelectionPrompt: confirm 'Cancel'

                $result = Invoke-CaptureMousePosition `
                    -WindowHandle ([IntPtr]::new(1001)) `
                    -Console $tc `
                    -PromptMessage 'Test prompt'

                $result | Should -BeNullOrEmpty
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Relative coordinate precision
    # ════════════════════════════════════════════════════════════════════════
    Context 'Relative coordinate precision' {

        It 'Rounds relative coordinates to 4 decimal places' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                # 1/3 = 0.33333... and 1/7 = 0.142857... both require rounding to 4dp
                Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 1; Y = 1 } }
                Mock Get-WindowBounds {
                    [PSCustomObject]@{ Left = 0; Top = 0; Right = 3; Bottom = 7; Width = 3; Height = 7 }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Invoke-CaptureMousePosition `
                    -WindowHandle ([IntPtr]::new(1001)) `
                    -Console $tc `
                    -PromptMessage 'Test prompt'

                $result.RelativeX | Should -BeOfType [double]
                $result.RelativeX | Should -Be 0.3333
                $result.RelativeY | Should -BeOfType [double]
                $result.RelativeY | Should -Be 0.1429
            }
        }
    }
}
