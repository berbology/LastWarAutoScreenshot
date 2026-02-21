BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'WindowEnumeration_TypeDefinition' {
    Context 'Type Definition Loading' {
        It 'Should load WindowEnumerationAPI type without errors' {
            $type = [LastWarAutoScreenshot.WindowEnumerationAPI]
            $type | Should -Not -BeNullOrEmpty
            $type.FullName | Should -Be 'LastWarAutoScreenshot.WindowEnumerationAPI'
        }

        It 'Should load EnumWindowsProc delegate without errors' {
            $delegateType = [LastWarAutoScreenshot.EnumWindowsProc]
            $delegateType | Should -Not -BeNullOrEmpty
            $delegateType.BaseType.Name | Should -Be 'MulticastDelegate'
        }
    }

    Context 'ShowWindow Functional Tests' -Tag 'Integration' {
        BeforeAll {
            $script:showWindowHandle = [LastWarAutoScreenshot.WindowEnumerationAPI]::GetForegroundWindow()
        }
        It 'Should call ShowWindow without throwing' -Tag 'Integration' -Skip:(-not [Environment]::UserInteractive -or [bool]$env:CI -or [bool]$env:TF_BUILD -or [bool]$env:GITHUB_ACTIONS) {
            $hWnd = $script:showWindowHandle
            $SW_MINIMIZE = 2
            $SW_MAXIMIZE = 3
            {
                [LastWarAutoScreenshot.WindowEnumerationAPI]::ShowWindow($hWnd, $SW_MINIMIZE) | Out-Null
                [LastWarAutoScreenshot.WindowEnumerationAPI]::ShowWindow($hWnd, $SW_MAXIMIZE) | Out-Null
            } | Should -Not -Throw
        }
    }
    Context 'API Calls With Real Handles' {
        BeforeAll {
            # GetForegroundWindow always returns a valid handle in an active terminal session.
            # Uses the module's own API directly — no Add-Type required.
            $script:testWindowHandle = [LastWarAutoScreenshot.WindowEnumerationAPI]::GetForegroundWindow()
            $script:hasValidHandle = ($script:testWindowHandle -ne [IntPtr]::Zero)
        }
        It 'Should have obtained a valid window handle for testing' {
            $script:testWindowHandle | Should -Not -Be ([IntPtr]::Zero)
            $script:hasValidHandle | Should -Be $true
        }
        It 'Should successfully call IsWindowVisible with valid window handle' {
            $result = [LastWarAutoScreenshot.WindowEnumerationAPI]::IsWindowVisible($script:testWindowHandle)
            $result | Should -BeOfType [bool]
        }
        It 'Should successfully call GetWindowTextLength with valid window handle' {
            $length = [LastWarAutoScreenshot.WindowEnumerationAPI]::GetWindowTextLength($script:testWindowHandle)
            $length | Should -BeOfType [int]
            $length | Should -BeGreaterOrEqual 0
        }
        It 'Should successfully call GetWindowText with valid window handle' {
            $length = [LastWarAutoScreenshot.WindowEnumerationAPI]::GetWindowTextLength($script:testWindowHandle)
            if ($length -gt 0) {
                $buffer = [System.Text.StringBuilder]::new($length + 1)
                $result = [LastWarAutoScreenshot.WindowEnumerationAPI]::GetWindowText($script:testWindowHandle, $buffer, $buffer.Capacity)
                $result | Should -BeOfType [int]
                $result | Should -BeGreaterOrEqual 0
            }
        }
        It 'Should successfully call GetWindowThreadProcessId with valid window handle' {
            $processId = 0
            $threadId = [LastWarAutoScreenshot.WindowEnumerationAPI]::GetWindowThreadProcessId($script:testWindowHandle, [ref]$processId)
            $threadId | Should -BeOfType [uint32]
            $processId | Should -BeOfType [uint32]
            $processId | Should -BeGreaterThan 0
        }
        It 'Should successfully call IsIconic with valid window handle' {
            $result = [LastWarAutoScreenshot.WindowEnumerationAPI]::IsIconic($script:testWindowHandle)
            $result | Should -BeOfType [bool]
        }
        It 'Should successfully call GetForegroundWindow' {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                $result = [LastWarAutoScreenshot.WindowEnumerationAPI]::GetForegroundWindow()
                $result | Should -BeOfType [IntPtr]
                # Foreground window may be Zero if no window is in foreground (rare)
                # but the call should not throw an exception
            }
        }
        It 'Should return valid window handle from GetForegroundWindow' {
            $foregroundHandle = [LastWarAutoScreenshot.WindowEnumerationAPI]::GetForegroundWindow()
            
            # If we got a handle, verify it's valid by checking if it's visible
            if ($foregroundHandle -ne [IntPtr]::Zero) {
                $isVisible = [LastWarAutoScreenshot.WindowEnumerationAPI]::IsWindowVisible($foregroundHandle)
                $isVisible | Should -BeOfType [bool]
            }
        }

        It 'Should successfully call EnumWindows with callback delegate' {
            $counter = @{ Count = 0 }
            $callback = [LastWarAutoScreenshot.EnumWindowsProc] {
                param($hwnd, $lParam)
                $counter.Count++
                return $true  # Continue enumeration
            }.GetNewClosure()
            
            $result = [LastWarAutoScreenshot.WindowEnumerationAPI]::EnumWindows($callback, [IntPtr]::Zero)
            $result | Should -Be $true
            $counter.Count | Should -BeGreaterThan 0
        }

        It 'Should stop enumeration when callback returns false' {
            $counter = @{ Count = 0 }
            $callback = [LastWarAutoScreenshot.EnumWindowsProc] {
                param($hwnd, $lParam)
                $counter.Count++
                return $false  # Stop enumeration after first window
            }.GetNewClosure()
            
            $result = [LastWarAutoScreenshot.WindowEnumerationAPI]::EnumWindows($callback, [IntPtr]::Zero)
            $result | Should -Be $false
            $counter.Count | Should -Be 1
        }

        It 'Should call SetForegroundWindow without throwing' {
            { [LastWarAutoScreenshot.WindowEnumerationAPI]::SetForegroundWindow($script:testWindowHandle) | Out-Null } | Should -Not -Throw
        }
    }

    Context 'Error Handling' {
        It 'Should handle invalid window handle gracefully in IsWindowVisible' {
            $invalidHandle = [IntPtr]::Zero
            $result = [LastWarAutoScreenshot.WindowEnumerationAPI]::IsWindowVisible($invalidHandle)
            $result | Should -BeOfType [bool]
            $result | Should -Be $false
        }

        It 'Should return 0 for GetWindowTextLength with invalid handle' {
            $invalidHandle = [IntPtr]::Zero
            $length = [LastWarAutoScreenshot.WindowEnumerationAPI]::GetWindowTextLength($invalidHandle)
            $length | Should -Be 0
        }

        It 'Should return 0 for GetWindowText with invalid handle' {
            $invalidHandle = [IntPtr]::Zero
            $buffer = [System.Text.StringBuilder]::new(256)
            $result = [LastWarAutoScreenshot.WindowEnumerationAPI]::GetWindowText($invalidHandle, $buffer, $buffer.Capacity)
            $result | Should -Be 0
        }
    }
}