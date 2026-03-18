# MouseControl_TypeDefinition.Tests.ps1
# Pester tests for [LastWarAutoScreenshot.MouseControlAPI] type definition

BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe '[LastWarAutoScreenshot.MouseControlAPI] type definition' -Tag 'Unit' {
    It 'Loads the MouseControlAPI type without error' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            { [void][LastWarAutoScreenshot.MouseControlAPI] } | Should -Not -Throw
        }
    }

    It 'Has static method SendInput with correct signature' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            $method = [LastWarAutoScreenshot.MouseControlAPI].GetMethod('SendInput', [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static)
            $method | Should -Not -BeNullOrEmpty
            $method.GetParameters().Count | Should -Be 3
            $method.ReturnType.Name | Should -Be 'UInt32'
        }
    }

    It 'Has static method GetCursorPos with correct signature' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            $method = [LastWarAutoScreenshot.MouseControlAPI].GetMethod('GetCursorPos', [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static)
            $method | Should -Not -BeNullOrEmpty
            $method.GetParameters().Count | Should -Be 1
            $method.GetParameters()[0].IsOut | Should -Be $true
        }
    }

    It 'Has static method GetWindowRect with correct signature' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            $method = [LastWarAutoScreenshot.MouseControlAPI].GetMethod('GetWindowRect', [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static)
            $method | Should -Not -BeNullOrEmpty
            $method.GetParameters().Count | Should -Be 2
            $method.GetParameters()[1].IsOut | Should -Be $true
        }
    }

    It 'Has nested type POINT with expected public fields' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            $type = [LastWarAutoScreenshot.MouseControlAPI].GetNestedType('POINT')
            $type | Should -Not -BeNullOrEmpty
            $fields = $type.GetFields('Public, Instance')
            $fields.Name | Should -Contain 'X'
            $fields.Name | Should -Contain 'Y'
        }
    }

    It 'Has nested type RECT with expected public fields' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            $type = [LastWarAutoScreenshot.MouseControlAPI].GetNestedType('RECT')
            $type | Should -Not -BeNullOrEmpty
            $fields = $type.GetFields('Public, Instance')
            $fields.Name | Should -Contain 'Left'
            $fields.Name | Should -Contain 'Top'
            $fields.Name | Should -Contain 'Right'
            $fields.Name | Should -Contain 'Bottom'
        }
    }

    It 'Has nested type MOUSEINPUT with expected public fields' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            $type = [LastWarAutoScreenshot.MouseControlAPI].GetNestedType('MOUSEINPUT')
            $type | Should -Not -BeNullOrEmpty
            $fields = $type.GetFields('Public, Instance')
            $fields.Name | Should -Contain 'dx'
            $fields.Name | Should -Contain 'dy'
            $fields.Name | Should -Contain 'mouseData'
            $fields.Name | Should -Contain 'dwFlags'
            $fields.Name | Should -Contain 'time'
            $fields.Name | Should -Contain 'dwExtraInfo'
        }
    }

    It 'Has nested type INPUT with expected public fields' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            $type = [LastWarAutoScreenshot.MouseControlAPI].GetNestedType('INPUT')
            $type | Should -Not -BeNullOrEmpty
            $fields = $type.GetFields('Public, Instance')
            $fields.Name | Should -Contain 'type'
            $fields.Name | Should -Contain 'mi'
        }
    }

    It 'Has static method GetAsyncKeyState with correct signature' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            $method = [LastWarAutoScreenshot.MouseControlAPI].GetMethod(
                'GetAsyncKeyState',
                [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static
            )
            $method | Should -Not -BeNullOrEmpty
            $method.GetParameters().Count | Should -Be 1
            $method.GetParameters()[0].ParameterType.Name | Should -Be 'Int32'
            $method.ReturnType.Name | Should -Be 'Int16'
        }
    }

    It 'GetAsyncKeyState is callable with VK_SHIFT (0x10) without throwing' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            # VK_SHIFT = 0x10 (16) - safe to call; returns 0 when Shift is not held.
            # We only verify no exception is thrown, not the actual key state.
            { [LastWarAutoScreenshot.MouseControlAPI]::GetAsyncKeyState(0x10) } | Should -Not -Throw
        }
    }

    It 'Has static constant MOUSEEVENTF_ABSOLUTE = 0x8000' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_ABSOLUTE | Should -Be 0x8000
        }
    }

    It 'Has static constant MOUSEEVENTF_VIRTUALDESK = 0x4000' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_VIRTUALDESK | Should -Be 0x4000
        }
    }

    It 'Has static constant SM_XVIRTUALSCREEN = 76' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            [LastWarAutoScreenshot.MouseControlAPI]::SM_XVIRTUALSCREEN | Should -Be 76
        }
    }

    It 'Has static constant SM_YVIRTUALSCREEN = 77' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            [LastWarAutoScreenshot.MouseControlAPI]::SM_YVIRTUALSCREEN | Should -Be 77
        }
    }

    It 'Has static constant SM_CXVIRTUALSCREEN = 78' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            [LastWarAutoScreenshot.MouseControlAPI]::SM_CXVIRTUALSCREEN | Should -Be 78
        }
    }

    It 'Has static constant SM_CYVIRTUALSCREEN = 79' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            [LastWarAutoScreenshot.MouseControlAPI]::SM_CYVIRTUALSCREEN | Should -Be 79
        }
    }

    It 'Has static method GetSystemMetrics with correct signature' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            $method = [LastWarAutoScreenshot.MouseControlAPI].GetMethod('GetSystemMetrics', [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static)
            $method | Should -Not -BeNullOrEmpty
            $method.GetParameters().Count | Should -Be 1
            $method.GetParameters()[0].ParameterType.Name | Should -Be 'Int32'
            $method.ReturnType.Name | Should -Be 'Int32'
        }
    }

    It 'GetSystemMetrics returns positive values for virtual screen dimensions' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            $width = [LastWarAutoScreenshot.MouseControlAPI]::GetSystemMetrics([LastWarAutoScreenshot.MouseControlAPI]::SM_CXVIRTUALSCREEN)
            $height = [LastWarAutoScreenshot.MouseControlAPI]::GetSystemMetrics([LastWarAutoScreenshot.MouseControlAPI]::SM_CYVIRTUALSCREEN)
            
            $width | Should -BeGreaterThan 0
            $height | Should -BeGreaterThan 0
        }
    }
}

