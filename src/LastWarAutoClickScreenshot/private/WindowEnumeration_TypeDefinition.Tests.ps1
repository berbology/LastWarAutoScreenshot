<#
.SYNOPSIS
    Pester tests for WindowEnumeration_TypeDefinition.ps1

.DESCRIPTION
    This test suite validates the Win32 API type definitions for window enumeration.
    Tests verify that the WindowEnumerationAPI class is properly defined with all
    required P/Invoke methods.

.NOTES
    - Tests use actual type definitions since Add-Type cannot be mocked
    - Type definitions are loaded once and remain in memory for the session
    - Tests verify type structure and method signatures

#>

BeforeAll {
    # Dot-source the type definition script
    . $PSScriptRoot/WindowEnumeration_TypeDefinition.ps1
}

Describe 'WindowEnumeration_TypeDefinition' {
    Context 'Type Definition Loading' {
        It 'Should load WindowEnumerationAPI type without errors' {
            $type = [WindowEnumerationAPI]
            $type | Should -Not -BeNullOrEmpty
            $type.FullName | Should -Be 'WindowEnumerationAPI'
        }

        It 'Should load EnumWindowsProc delegate without errors' {
            $delegateType = [EnumWindowsProc]
            $delegateType | Should -Not -BeNullOrEmpty
            $delegateType.BaseType.Name | Should -Be 'MulticastDelegate'
        }
    }

    Context 'Required Methods' {
        It 'Should have EnumWindows method' {
            $method = [WindowEnumerationAPI].GetMethod('EnumWindows')
            $method | Should -Not -BeNullOrEmpty
            $method.IsStatic | Should -Be $true
            $method.ReturnType.Name | Should -Be 'Boolean'
        }

        It 'Should have GetWindowText method' {
            $method = [WindowEnumerationAPI].GetMethod('GetWindowText')
            $method | Should -Not -BeNullOrEmpty
            $method.IsStatic | Should -Be $true
            $method.ReturnType.Name | Should -Be 'Int32'
        }

        It 'Should have GetWindowTextLength method' {
            $method = [WindowEnumerationAPI].GetMethod('GetWindowTextLength')
            $method | Should -Not -BeNullOrEmpty
            $method.IsStatic | Should -Be $true
            $method.ReturnType.Name | Should -Be 'Int32'
        }

        It 'Should have IsWindowVisible method' {
            $method = [WindowEnumerationAPI].GetMethod('IsWindowVisible')
            $method | Should -Not -BeNullOrEmpty
            $method.IsStatic | Should -Be $true
            $method.ReturnType.Name | Should -Be 'Boolean'
        }

        It 'Should have GetWindowThreadProcessId method' {
            $method = [WindowEnumerationAPI].GetMethod('GetWindowThreadProcessId')
            $method | Should -Not -BeNullOrEmpty
            $method.IsStatic | Should -Be $true
            $method.ReturnType.Name | Should -Be 'UInt32'
        }

        It 'Should have IsIconic method' {
            $method = [WindowEnumerationAPI].GetMethod('IsIconic')
            $method | Should -Not -BeNullOrEmpty
            $method.IsStatic | Should -Be $true
            $method.ReturnType.Name | Should -Be 'Boolean'
        }

        It 'Should have GetForegroundWindow method' {
            $method = [WindowEnumerationAPI].GetMethod('GetForegroundWindow')
            $method | Should -Not -BeNullOrEmpty
            $method.IsStatic | Should -Be $true
            $method.ReturnType.Name | Should -Be 'IntPtr'
        }
    }

    Context 'Functional Tests' {
        BeforeAll {
            # Get a valid window handle for testing - try multiple approaches
            
            # Define helper functions only if not already defined
            if (-not ([System.Management.Automation.PSTypeName]'WindowTestHelper').Type) {
                Add-Type -TypeDefinition @'
                    using System;
                    using System.Runtime.InteropServices;
                    public class WindowTestHelper {
                        [DllImport("kernel32.dll", SetLastError = true)]
                        public static extern IntPtr GetConsoleWindow();
                        
                        [DllImport("user32.dll", SetLastError = true)]
                        public static extern IntPtr GetDesktopWindow();
                        
                        [DllImport("user32.dll", SetLastError = true)]
                        public static extern IntPtr GetForegroundWindow();
                        
                        [DllImport("user32.dll", SetLastError = true)]
                        public static extern IntPtr GetShellWindow();
                    }
'@ -ErrorAction Stop
            }
            
            # Approach 1: Try to get console window
            $script:testWindowHandle = [WindowTestHelper]::GetConsoleWindow()
            
            # Approach 2: Try to get foreground window
            if ($script:testWindowHandle -eq [IntPtr]::Zero) {
                $script:testWindowHandle = [WindowTestHelper]::GetForegroundWindow()
            }
            
            # Approach 3: Try to get shell window
            if ($script:testWindowHandle -eq [IntPtr]::Zero) {
                $script:testWindowHandle = [WindowTestHelper]::GetShellWindow()
            }
            
            # Approach 4: Find any visible window on the system
            if ($script:testWindowHandle -eq [IntPtr]::Zero) {
                $foundHandle = [IntPtr]::Zero
                
                $callback = [EnumWindowsProc] {
                    param($hwnd, $lParam)
                    if ([WindowEnumerationAPI]::IsWindowVisible($hwnd)) {
                        $length = [WindowEnumerationAPI]::GetWindowTextLength($hwnd)
                        if ($length -gt 0) {
                            $script:foundHandle = $hwnd
                            return $false  # Stop enumeration - we found one
                        }
                    }
                    return $true  # Continue enumeration
                }.GetNewClosure()
                
                [WindowEnumerationAPI]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null
                $script:testWindowHandle = $foundHandle
            }
            
            # Approach 5: As last resort, use desktop window (always valid but has limited functionality)
            if ($script:testWindowHandle -eq [IntPtr]::Zero) {
                $script:testWindowHandle = [WindowTestHelper]::GetDesktopWindow()
            }
            
            # Store whether we have a valid handle
            $script:hasValidHandle = ($script:testWindowHandle -ne [IntPtr]::Zero)
        }

        It 'Should have obtained a valid window handle for testing' {
            $script:testWindowHandle | Should -Not -Be ([IntPtr]::Zero)
            $script:hasValidHandle | Should -Be $true
        }

        It 'Should successfully call IsWindowVisible with valid window handle' {
            $result = [WindowEnumerationAPI]::IsWindowVisible($script:testWindowHandle)
            $result | Should -BeOfType [bool]
        }

        It 'Should successfully call GetWindowTextLength with valid window handle' {
            $length = [WindowEnumerationAPI]::GetWindowTextLength($script:testWindowHandle)
            $length | Should -BeOfType [int]
            $length | Should -BeGreaterOrEqual 0
        }

        It 'Should successfully call GetWindowText with valid window handle' {
            $length = [WindowEnumerationAPI]::GetWindowTextLength($script:testWindowHandle)
            if ($length -gt 0) {
                $buffer = [System.Text.StringBuilder]::new($length + 1)
                $result = [WindowEnumerationAPI]::GetWindowText($script:testWindowHandle, $buffer, $buffer.Capacity)
                $result | Should -BeOfType [int]
                $result | Should -BeGreaterOrEqual 0
            }
        }

        It 'Should successfully call GetWindowThreadProcessId with valid window handle' {
            $processId = 0
            $threadId = [WindowEnumerationAPI]::GetWindowThreadProcessId($script:testWindowHandle, [ref]$processId)
            $threadId | Should -BeOfType [uint32]
            $processId | Should -BeOfType [uint32]
            $processId | Should -BeGreaterThan 0
        }

        It 'Should successfully call IsIconic with valid window handle' {
            $result = [WindowEnumerationAPI]::IsIconic($script:testWindowHandle)
            $result | Should -BeOfType [bool]
        }

        It 'Should successfully call GetForegroundWindow' {
            $result = [WindowEnumerationAPI]::GetForegroundWindow()
            $result | Should -BeOfType [IntPtr]
            # Foreground window may be Zero if no window is in foreground (rare)
            # but the call should not throw an exception
        }

        It 'Should return valid window handle from GetForegroundWindow' {
            $foregroundHandle = [WindowEnumerationAPI]::GetForegroundWindow()
            
            # If we got a handle, verify it's valid by checking if it's visible
            if ($foregroundHandle -ne [IntPtr]::Zero) {
                $isVisible = [WindowEnumerationAPI]::IsWindowVisible($foregroundHandle)
                $isVisible | Should -BeOfType [bool]
            }
        }

        It 'Should successfully call EnumWindows with callback delegate' {
            $counter = @{ Count = 0 }
            $callback = [EnumWindowsProc] {
                param($hwnd, $lParam)
                $counter.Count++
                return $true  # Continue enumeration
            }.GetNewClosure()
            
            $result = [WindowEnumerationAPI]::EnumWindows($callback, [IntPtr]::Zero)
            $result | Should -Be $true
            $counter.Count | Should -BeGreaterThan 0
        }

        It 'Should stop enumeration when callback returns false' {
            $counter = @{ Count = 0 }
            $callback = [EnumWindowsProc] {
                param($hwnd, $lParam)
                $counter.Count++
                return $false  # Stop enumeration after first window
            }.GetNewClosure()
            
            $result = [WindowEnumerationAPI]::EnumWindows($callback, [IntPtr]::Zero)
            $result | Should -Be $false
            $counter.Count | Should -Be 1
        }
    }

    Context 'Error Handling' {
        It 'Should handle invalid window handle gracefully in IsWindowVisible' {
            $invalidHandle = [IntPtr]::Zero
            $result = [WindowEnumerationAPI]::IsWindowVisible($invalidHandle)
            $result | Should -BeOfType [bool]
            $result | Should -Be $false
        }

        It 'Should return 0 for GetWindowTextLength with invalid handle' {
            $invalidHandle = [IntPtr]::Zero
            $length = [WindowEnumerationAPI]::GetWindowTextLength($invalidHandle)
            $length | Should -Be 0
        }

        It 'Should return 0 for GetWindowText with invalid handle' {
            $invalidHandle = [IntPtr]::Zero
            $buffer = [System.Text.StringBuilder]::new(256)
            $result = [WindowEnumerationAPI]::GetWindowText($invalidHandle, $buffer, $buffer.Capacity)
            $result | Should -Be 0
        }
    }
}