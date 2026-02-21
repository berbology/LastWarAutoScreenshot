# MouseControl_TypeDefinition.Tests.ps1
# Pester tests for [LastWarAutoScreenshot.MouseControlAPI] type definition

BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe '[LastWarAutoScreenshot.MouseControlAPI] type definition' {
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
}
