

BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'WindowEnumeration_TypeDefinition' -Tag 'Unit' {
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

    # NOTE: The tests in this context make live Win32 API calls (IsWindowVisible,
    # GetWindowTextLength, GetWindowText) with invalid/zero handles. They are not
    # pure unit tests — they exercise real kernel calls against the live environment.
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
