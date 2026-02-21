# Pester tests for Set-WindowActive helper function

BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'Set-WindowActive' {
    BeforeAll {
        Mock Write-Host { } -ModuleName LastWarAutoScreenshot
    }
    Context 'Parameter validation' {
        BeforeEach {
            Mock Write-LastWarLog { } -ModuleName LastWarAutoScreenshot
        }
        It 'Returns false on unsupported WindowHandle type' {
            InModuleScope LastWarAutoScreenshot {
                $unsupported = [PSCustomObject]@{ Foo = 'Bar' }
                $result = Set-WindowActive -WindowHandle $unsupported
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*Unsupported WindowHandle type*' -and $Level -eq 'Error' -and $FunctionName -eq 'Set-WindowActive' } -Exactly 1
                $result | Should -Be $false
                $result = Set-WindowActive -WindowHandle $null
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*Unsupported WindowHandle type*' -and $Level -eq 'Error' -and $FunctionName -eq 'Set-WindowActive' }
                $result | Should -Be $false
                $result = Set-WindowActive -WindowHandle ''
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*Unsupported WindowHandle type*' -and $Level -eq 'Error' -and $FunctionName -eq 'Set-WindowActive' }
                $result | Should -Be $false
                $result = Set-WindowActive -WindowHandle 0.123
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*Unsupported WindowHandle type*' -and $Level -eq 'Error' -and $FunctionName -eq 'Set-WindowActive' }
                $result | Should -Be $false
            }
        }
        It 'Accepts IntPtr, int64, and string handles' {
            InModuleScope LastWarAutoScreenshot {
                Mock Invoke-SetForegroundWindow { $true }
                $h = [IntPtr]12345
                Set-WindowActive -WindowHandle $h | Should -Be $true
                Set-WindowActive -WindowHandle 12345 | Should -Be $true
                Set-WindowActive -WindowHandle '12345' | Should -Be $true
                Set-WindowActive -WindowHandle ([int64]12345) | Should -Be $true
            }
        }
    }
    Context 'Window lookup by name or PID' {
        BeforeEach {
            Mock Write-LastWarLog { } -ModuleName LastWarAutoScreenshot
            # Simulate EnumWindows callback: return handle directly when criteria matches
            Mock Invoke-EnumWindows {
                $callback = $args[0]
                $hwnd = [IntPtr]12345
                $lParam = [IntPtr]::Zero
                $result = $callback.Invoke($hwnd, $lParam)
                if ($result -is [IntPtr] -and $result -ne [IntPtr]::Zero) {
                    return $result
                }
                return $true
            } -ModuleName LastWarAutoScreenshot
            Mock Invoke-GetWindowThreadProcessId {
                param($hwnd, $procIdRef)
                $procIdRef.Value = 12345
                $true
            } -ModuleName LastWarAutoScreenshot
            Mock Invoke-GetWindowTextLength {
                param($hwnd)
                8
            } -ModuleName LastWarAutoScreenshot
            Mock Invoke-GetWindowText {
                param($hwnd, $sb, $cap)
                $sb.Clear() | Out-Null
                $sb.Append('Last War: Survival') | Out-Null
                8
            } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SetForegroundWindow { $true } -ModuleName LastWarAutoScreenshot
        }
        It 'Returns true for valid WindowName' {
            InModuleScope LastWarAutoScreenshot {
                Mock Invoke-EnumWindows {
                    $callback = $args[0]
                    $hwnd = [IntPtr]12345
                    $lParam = [IntPtr]::Zero
                    # Simulate callback returning handle for WindowName match
                    return $hwnd
                }
                Set-WindowActive -WindowName 'Last War: Survival' | Should -Be $true
            }
        }
        It 'Returns true for valid ProcessID' {
            InModuleScope LastWarAutoScreenshot {
                Mock Invoke-EnumWindows {
                    $callback = $args[0]
                    $hwnd = [IntPtr]12345
                    $lParam = [IntPtr]::Zero
                    # Simulate callback returning handle for ProcessID match
                    return $hwnd
                }
                Set-WindowActive -ProcessID 12345 | Should -Be $true
            }
        }
        It 'Returns false if no window found' {
            InModuleScope LastWarAutoScreenshot {
                Mock Invoke-EnumWindows { $true }
                Set-WindowActive -WindowName 'NotFound' | Should -Be $false
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*No window found matching criteria*' -and $Level -eq 'Error' -and $FunctionName -eq 'Set-WindowActive' }
            }
        }
    }
    Context 'SetForegroundWindow API call' {
        BeforeEach {
            Mock Write-LastWarLog { } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SetForegroundWindow { $true } -ModuleName LastWarAutoScreenshot
        }
        It 'Returns true on success' {
            InModuleScope LastWarAutoScreenshot {
                Set-WindowActive -WindowHandle 12345 | Should -Be $true
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*succeeded*' -and $Level -eq 'Info' -and $FunctionName -eq 'Set-WindowActive' }
            }
        }
        It 'Returns false and logs on failure' {
            InModuleScope LastWarAutoScreenshot {
                Mock Invoke-SetForegroundWindow { $false }
                Set-WindowActive -WindowHandle 12345 | Should -Be $false
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*SetForegroundWindow failed*' -and $Level -eq 'Error' -and $FunctionName -eq 'Set-WindowActive' }
            }
        }
    }
    Context 'Error handling' {
        BeforeEach {
            Mock Write-LastWarLog { } -ModuleName LastWarAutoScreenshot
        }
        It 'Returns false and logs on exception' {
            InModuleScope LastWarAutoScreenshot {
                Mock Invoke-SetForegroundWindow { throw 'API error' }
                Set-WindowActive -WindowHandle 12345 | Should -Be $false
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*Exception in Set-WindowActive*' -and $Level -eq 'Error' -and $FunctionName -eq 'Set-WindowActive' }
            }
        }
    }
}
