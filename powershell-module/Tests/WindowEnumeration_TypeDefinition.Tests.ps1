

BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
    ${script:Get-TestRunnerWindowHandle} = {
        $processPID = [System.Diagnostics.Process]::GetCurrentProcess().Id
        $resultContainer = @{ Handle = [IntPtr]::Zero }
        $callback = [LastWarAutoScreenshot.EnumWindowsProc] {
            param($hwnd, $lParam)
            $procId = 0
            [LastWarAutoScreenshot.WindowEnumerationAPI]::GetWindowThreadProcessId($hwnd, [ref]$procId) | Out-Null
            if ($procId -eq $lParam.ToInt32()) {
                $resultContainer.Handle = $hwnd
                return $false
            }
            return $true
        }.GetNewClosure()
        [LastWarAutoScreenshot.WindowEnumerationAPI]::EnumWindows($callback, [IntPtr]$processPID) | Out-Null
        return $resultContainer.Handle
    }
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
