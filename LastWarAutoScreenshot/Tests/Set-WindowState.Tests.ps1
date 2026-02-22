BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'Set-WindowState' {
    BeforeAll {
        Mock Write-LastWarLog { } -ModuleName LastWarAutoScreenshot
        Mock Write-Host { } -ModuleName LastWarAutoScreenshot
    }
    Context 'Parameter validation' {
        It 'Returns false on unsupported WindowHandle type' {
            InModuleScope LastWarAutoScreenshot {
                Set-WindowState -WindowHandle @() -State Minimize | Should -Be $false
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*Unsupported WindowHandle type*' -and $Level -eq 'Error' -and $FunctionName -eq 'Set-WindowState' }
                Set-WindowState -WindowHandle $null -State Minimize | Should -Be $false
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*Unsupported WindowHandle type*' -and $Level -eq 'Error' -and $FunctionName -eq 'Set-WindowState' }
                Set-WindowState -WindowHandle '' -State Minimize | Should -Be $false
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*Unsupported WindowHandle type*' -and $Level -eq 'Error' -and $FunctionName -eq 'Set-WindowState' }
                Set-WindowState -WindowHandle 0.123 -State Minimize | Should -Be $false
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*Unsupported WindowHandle type*' -and $Level -eq 'Error' -and $FunctionName -eq 'Set-WindowState' }
            }
        }
        It 'Accepts IntPtr, int64, and string handles' {
            InModuleScope LastWarAutoScreenshot {
                Mock Invoke-ShowWindow { $true }
                $h = [IntPtr]12345
                Set-WindowState -WindowHandle $h -State Minimize | Should -Be $true
                Set-WindowState -WindowHandle 12345 -State Maximize | Should -Be $true
                Set-WindowState -WindowHandle '12345' -State Minimize | Should -Be $true
                Set-WindowState -WindowHandle ([int64]12345) -State Minimize | Should -Be $true
            }
        }
    }
    Context 'ShowWindow API call' {
        BeforeEach {
            Mock Invoke-ShowWindow { $true } -ModuleName LastWarAutoScreenshot
        }
        It 'Returns true on success' {
            InModuleScope LastWarAutoScreenshot {
                Set-WindowState -WindowHandle 12345 -State Minimize | Should -Be $true
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*succeeded*' -and $Level -eq 'Info' -and $FunctionName -eq 'Set-WindowState' }
            }
        }
        It 'Returns false and logs on failure' {
            InModuleScope LastWarAutoScreenshot {
                Mock Invoke-ShowWindow { $false }
                Set-WindowState -WindowHandle 12345 -State Maximize | Should -Be $false
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*ShowWindow failed*' -and $Level -eq 'Error' -and $FunctionName -eq 'Set-WindowState' }
            }
        }
    }
    Context 'Error handling' {
        It 'Returns false and logs on exception' {
            InModuleScope LastWarAutoScreenshot {
                Mock Invoke-ShowWindow { throw 'API error' }
                Set-WindowState -WindowHandle 12345 -State Minimize | Should -Be $false
                Should -Invoke Write-LastWarLog -ParameterFilter { $Message -like '*Exception in Set-WindowState*' -and $Level -eq 'Error' -and $FunctionName -eq 'Set-WindowState' }
            }
        }
    }
}
