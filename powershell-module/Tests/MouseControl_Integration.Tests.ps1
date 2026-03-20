# MouseControl_Integration.Tests.ps1
# Integration tests for MouseControlAPI P/Invoke wrappers
# Tests our C# functions directly (no mocking) to verify struct marshalling and Win32 calls work correctly

BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe '[LastWarAutoScreenshot.MouseControlAPI] P/Invoke Integration Tests' -Tag 'Integration' {

    Context 'SendInput' {
        It 'Successfully sends a mouse movement input without throwing' {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                # Save current cursor position before moving
                $startPoint = New-Object 'LastWarAutoScreenshot.MouseControlAPI+POINT'
                [LastWarAutoScreenshot.MouseControlAPI]::GetCursorPos([ref]$startPoint) | Out-Null

                try {
                    # Create MOUSEINPUT structure for small movement
                    $mouseInput = New-Object 'LastWarAutoScreenshot.MouseControlAPI+MOUSEINPUT'
                    $mouseInput.dx = 1
                    $mouseInput.dy = 1
                    $mouseInput.mouseData = 0
                    $mouseInput.dwFlags = [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_MOVE
                    $mouseInput.time = 0
                    $mouseInput.dwExtraInfo = [System.IntPtr]::Zero

                    # Create INPUT structure wrapper
                    $inputStruct = New-Object 'LastWarAutoScreenshot.MouseControlAPI+INPUT'
                    $inputStruct.type = [LastWarAutoScreenshot.MouseControlAPI]::INPUT_MOUSE
                    $inputStruct.mi = $mouseInput

                    # Create array and call SendInput
                    $inputArray = @($inputStruct)
                    $inputSize = [System.Runtime.InteropServices.Marshal]::SizeOf($inputStruct)

                    # Call SendInput - will throw on exception
                    $result = [LastWarAutoScreenshot.MouseControlAPI]::SendInput(1, $inputArray, $inputSize)

                    # Result should be 1 (one input successfully inserted)
                    $result | Should -Be 1
                } finally {
                    # Restore cursor to saved position using absolute normalised coordinates
                    $vdLeft   = [LastWarAutoScreenshot.MouseControlAPI]::GetSystemMetrics([LastWarAutoScreenshot.MouseControlAPI]::SM_XVIRTUALSCREEN)
                    $vdTop    = [LastWarAutoScreenshot.MouseControlAPI]::GetSystemMetrics([LastWarAutoScreenshot.MouseControlAPI]::SM_YVIRTUALSCREEN)
                    $vdWidth  = [LastWarAutoScreenshot.MouseControlAPI]::GetSystemMetrics([LastWarAutoScreenshot.MouseControlAPI]::SM_CXVIRTUALSCREEN)
                    $vdHeight = [LastWarAutoScreenshot.MouseControlAPI]::GetSystemMetrics([LastWarAutoScreenshot.MouseControlAPI]::SM_CYVIRTUALSCREEN)
                    $restoreX = [int](($startPoint.X - $vdLeft) * 65535 / $vdWidth)
                    $restoreY = [int](($startPoint.Y - $vdTop)  * 65535 / $vdHeight)

                    $restoreInput = New-Object 'LastWarAutoScreenshot.MouseControlAPI+MOUSEINPUT'
                    $restoreInput.dx = $restoreX
                    $restoreInput.dy = $restoreY
                    $restoreInput.mouseData = 0
                    $restoreInput.dwFlags = [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_MOVE `
                                           -bor [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_ABSOLUTE `
                                           -bor [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_VIRTUALDESK
                    $restoreInput.time = 0
                    $restoreInput.dwExtraInfo = [System.IntPtr]::Zero

                    $restoreStruct = New-Object 'LastWarAutoScreenshot.MouseControlAPI+INPUT'
                    $restoreStruct.type = [LastWarAutoScreenshot.MouseControlAPI]::INPUT_MOUSE
                    $restoreStruct.mi = $restoreInput

                    [void][LastWarAutoScreenshot.MouseControlAPI]::SendInput(1, @($restoreStruct), [System.Runtime.InteropServices.Marshal]::SizeOf($restoreStruct))
                }
            }
        }

        It 'Correctly marshals MOUSEINPUT structure with click flags' {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                # Create MOUSEINPUT for left mouse down
                $mouseInput = New-Object 'LastWarAutoScreenshot.MouseControlAPI+MOUSEINPUT'
                $mouseInput.dx = 0
                $mouseInput.dy = 0
                $mouseInput.mouseData = 0
                $mouseInput.dwFlags = [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_LEFTDOWN
                $mouseInput.time = 0
                $mouseInput.dwExtraInfo = [System.IntPtr]::Zero

                $inputStruct = New-Object 'LastWarAutoScreenshot.MouseControlAPI+INPUT'
                $inputStruct.type = [LastWarAutoScreenshot.MouseControlAPI]::INPUT_MOUSE
                $inputStruct.mi = $mouseInput

                $inputArray = @($inputStruct)
                $inputSize = [System.Runtime.InteropServices.Marshal]::SizeOf($inputStruct)

                # Call and check result
                $result = [LastWarAutoScreenshot.MouseControlAPI]::SendInput(1, $inputArray, $inputSize)
                $result | Should -Be 1

                # Immediately send left mouse up to restore state
                $mouseInputUp = New-Object 'LastWarAutoScreenshot.MouseControlAPI+MOUSEINPUT'
                $mouseInputUp.dx = 0
                $mouseInputUp.dy = 0
                $mouseInputUp.mouseData = 0
                $mouseInputUp.dwFlags = [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_LEFTUP
                $mouseInputUp.time = 0
                $mouseInputUp.dwExtraInfo = [System.IntPtr]::Zero

                $inputStructUp = New-Object 'LastWarAutoScreenshot.MouseControlAPI+INPUT'
                $inputStructUp.type = [LastWarAutoScreenshot.MouseControlAPI]::INPUT_MOUSE
                $inputStructUp.mi = $mouseInputUp

                $inputArrayUp = @($inputStructUp)
                [void][LastWarAutoScreenshot.MouseControlAPI]::SendInput(1, $inputArrayUp, $inputSize)
            }
        }
    }

    Context 'GetCursorPos' {
        It 'Returns POINT structure with X and Y fields properly marshalled' {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                $point = New-Object 'LastWarAutoScreenshot.MouseControlAPI+POINT'
                $success = [LastWarAutoScreenshot.MouseControlAPI]::GetCursorPos([ref]$point)

                $success | Should -Be $true
                $point.PSObject.Properties.Name | Should -Contain 'X'
                $point.PSObject.Properties.Name | Should -Contain 'Y'
                $point.X | Should -BeOfType [int]
                $point.Y | Should -BeOfType [int]
            }
        }
    }

    Context 'GetWindowRect' {
        It 'RECT structure has valid coordinate fields' {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                $rect = New-Object 'LastWarAutoScreenshot.MouseControlAPI+RECT'
                
                # Verify the structure has the expected properties
                $rect.PSObject.Properties.Name | Should -Contain 'Left'
                $rect.PSObject.Properties.Name | Should -Contain 'Right'
                $rect.PSObject.Properties.Name | Should -Contain 'Top'
                $rect.PSObject.Properties.Name | Should -Contain 'Bottom'
                
                # Test that we can set and read values
                $rect.Left = 10
                $rect.Right = 100
                $rect.Top = 20
                $rect.Bottom = 200
                
                $rect.Left | Should -Be 10
                $rect.Right | Should -Be 100
                $rect.Top | Should -Be 20
                $rect.Bottom | Should -Be 200
            }
        }
    }

    Context 'GetAsyncKeyState' {
        It 'Returns a valid key state value without throwing' {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                # VK_F24 (0x87) is rarely used, should return mostly 0
                $state = [LastWarAutoScreenshot.MouseControlAPI]::GetAsyncKeyState(0x87)

                # Result is a short (-32768 to 32767)
                $state | Should -BeOfType [System.Int16]
            }
        }

        # KNOWN FLAKINESS RISK: GetAsyncKeyState also clears the "pressed since last call" bit
        # (bit 0) on first read, so $state1 and $state2 can legitimately differ if the key was
        # pressed between test runs. VK_F24 (0x87) is used here as it is extremely rarely pressed,
        # but any physical key press between the two calls will cause a non-deterministic failure.
        # This is inherent to the live Win32 approach and cannot be avoided without mocking.
        It 'Returns consistent state values for the same key across calls' {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                # VK_F24 (0x87) — rarely used key, minimises race condition risk
                $state1 = [LastWarAutoScreenshot.MouseControlAPI]::GetAsyncKeyState(0x87)
                $state2 = [LastWarAutoScreenshot.MouseControlAPI]::GetAsyncKeyState(0x87)

                # States should be equal (key state shouldn't change in this short window)
                $state1 | Should -Be $state2
            }
        }
    }

    Context 'GetSystemMetrics' {
        It 'Returns positive screen dimensions for virtual desktop' {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                $width = [LastWarAutoScreenshot.MouseControlAPI]::GetSystemMetrics([LastWarAutoScreenshot.MouseControlAPI]::SM_CXVIRTUALSCREEN)
                $height = [LastWarAutoScreenshot.MouseControlAPI]::GetSystemMetrics([LastWarAutoScreenshot.MouseControlAPI]::SM_CYVIRTUALSCREEN)

                $width | Should -BeGreaterThan 0
                $height | Should -BeGreaterThan 0
            }
        }

        It 'Returns valid origin coordinates for virtual desktop' {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                $left = [LastWarAutoScreenshot.MouseControlAPI]::GetSystemMetrics([LastWarAutoScreenshot.MouseControlAPI]::SM_XVIRTUALSCREEN)
                $top = [LastWarAutoScreenshot.MouseControlAPI]::GetSystemMetrics([LastWarAutoScreenshot.MouseControlAPI]::SM_YVIRTUALSCREEN)

                # On single-monitor systems, typically (0,0). On multi-monitor, may be negative.
                $left | Should -BeOfType [int]
                $top | Should -BeOfType [int]
            }
        }
    }

    Context 'SendInput with MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_VIRTUALDESK' {
        It 'Successfully sends absolute move input without throwing' {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                # Save current cursor position before moving
                $startPoint = New-Object 'LastWarAutoScreenshot.MouseControlAPI+POINT'
                [LastWarAutoScreenshot.MouseControlAPI]::GetCursorPos([ref]$startPoint) | Out-Null

                try {
                    $vdWidth = [LastWarAutoScreenshot.MouseControlAPI]::GetSystemMetrics([LastWarAutoScreenshot.MouseControlAPI]::SM_CXVIRTUALSCREEN)
                    $vdHeight = [LastWarAutoScreenshot.MouseControlAPI]::GetSystemMetrics([LastWarAutoScreenshot.MouseControlAPI]::SM_CYVIRTUALSCREEN)

                    # Normalise a screen coordinate to 0-65535 range
                    $normX = [int](32767)  # Mid-range
                    $normY = [int](32767)

                    $mouseInput = New-Object 'LastWarAutoScreenshot.MouseControlAPI+MOUSEINPUT'
                    $mouseInput.dx = $normX
                    $mouseInput.dy = $normY
                    $mouseInput.mouseData = 0
                    $mouseInput.dwFlags = [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_MOVE `
                                         -bor [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_ABSOLUTE `
                                         -bor [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_VIRTUALDESK
                    $mouseInput.time = 0
                    $mouseInput.dwExtraInfo = [System.IntPtr]::Zero

                    $inputStruct = New-Object 'LastWarAutoScreenshot.MouseControlAPI+INPUT'
                    $inputStruct.type = [LastWarAutoScreenshot.MouseControlAPI]::INPUT_MOUSE
                    $inputStruct.mi = $mouseInput

                    $inputArray = @($inputStruct)
                    $inputSize = [System.Runtime.InteropServices.Marshal]::SizeOf($inputStruct)

                    $result = [LastWarAutoScreenshot.MouseControlAPI]::SendInput(1, $inputArray, $inputSize)
                    $result | Should -Be 1
                } finally {
                    # Restore cursor to saved position using absolute normalised coordinates
                    $vdLeft   = [LastWarAutoScreenshot.MouseControlAPI]::GetSystemMetrics([LastWarAutoScreenshot.MouseControlAPI]::SM_XVIRTUALSCREEN)
                    $vdTop    = [LastWarAutoScreenshot.MouseControlAPI]::GetSystemMetrics([LastWarAutoScreenshot.MouseControlAPI]::SM_YVIRTUALSCREEN)
                    $vdWidth  = [LastWarAutoScreenshot.MouseControlAPI]::GetSystemMetrics([LastWarAutoScreenshot.MouseControlAPI]::SM_CXVIRTUALSCREEN)
                    $vdHeight = [LastWarAutoScreenshot.MouseControlAPI]::GetSystemMetrics([LastWarAutoScreenshot.MouseControlAPI]::SM_CYVIRTUALSCREEN)
                    $restoreX = [int](($startPoint.X - $vdLeft) * 65535 / $vdWidth)
                    $restoreY = [int](($startPoint.Y - $vdTop)  * 65535 / $vdHeight)

                    $restoreInput = New-Object 'LastWarAutoScreenshot.MouseControlAPI+MOUSEINPUT'
                    $restoreInput.dx = $restoreX
                    $restoreInput.dy = $restoreY
                    $restoreInput.mouseData = 0
                    $restoreInput.dwFlags = [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_MOVE `
                                           -bor [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_ABSOLUTE `
                                           -bor [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_VIRTUALDESK
                    $restoreInput.time = 0
                    $restoreInput.dwExtraInfo = [System.IntPtr]::Zero

                    $restoreStruct = New-Object 'LastWarAutoScreenshot.MouseControlAPI+INPUT'
                    $restoreStruct.type = [LastWarAutoScreenshot.MouseControlAPI]::INPUT_MOUSE
                    $restoreStruct.mi = $restoreInput

                    [void][LastWarAutoScreenshot.MouseControlAPI]::SendInput(1, @($restoreStruct), [System.Runtime.InteropServices.Marshal]::SizeOf($restoreStruct))
                }
            }
        }
    }
}
