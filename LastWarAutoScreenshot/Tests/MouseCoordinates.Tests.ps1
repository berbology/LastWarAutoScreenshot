# MouseCoordinates.Tests.ps1
# Pester tests for Get-WindowBounds and ConvertTo-ScreenCoordinates


BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

#region Get-WindowBounds
Describe 'Get-WindowBounds' {
    It 'returns correct PSCustomObject shape and width/height' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-GetWindowRect {
                param($WindowHandle)
                if ($WindowHandle -eq 'fail') {
                    throw 'Win32 error'
                }
                return @{ Left = 10; Top = 20; Right = 110; Bottom = 220 }
            } -ModuleName LastWarAutoScreenshot
            $result = Get-WindowBounds -WindowHandle 123
            $result | Should -BeOfType PSCustomObject
            $result.Left | Should -Be 10
            $result.Top | Should -Be 20
            $result.Right | Should -Be 110
            $result.Bottom | Should -Be 220
            $result.Width | Should -Be 100
            $result.Height | Should -Be 200
        }
    }
    It 'logs error and returns $null on invalid handle or Win32 failure' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {} -ModuleName LastWarAutoScreenshot
            # 'fail' is an invalid string handle — conversion throws in the catch block, returning $null
            $result = Get-WindowBounds -WindowHandle 'fail'
            $result | Should -BeNullOrEmpty
            Should -Invoke Write-LastWarLog -Exactly 1
        }
    }
}
#endregion

#region ConvertTo-ScreenCoordinates
Describe 'ConvertTo-ScreenCoordinates' {
    It 'returns correct absolute coordinates for (0.0, 0.0)' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-WindowBounds {
                param($WindowHandle)
                return @{ Left = 100; Top = 200; Width = 400; Height = 300 }
            } -ModuleName LastWarAutoScreenshot
            $result = ConvertTo-ScreenCoordinates -WindowHandle 1 -RelativeX 0.0 -RelativeY 0.0
            $result.X | Should -Be 100
            $result.Y | Should -Be 200
        }
    }
    It 'returns correct absolute coordinates for (1.0, 1.0)' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-WindowBounds {
                param($WindowHandle)
                return @{ Left = 100; Top = 200; Width = 400; Height = 300 }
            } -ModuleName LastWarAutoScreenshot
            $result = ConvertTo-ScreenCoordinates -WindowHandle 1 -RelativeX 1.0 -RelativeY 1.0
            $result.X | Should -Be 500
            $result.Y | Should -Be 500
        }
    }
    It 'returns correct absolute coordinates for (0.5, 0.5)' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-WindowBounds {
                param($WindowHandle)
                return @{ Left = 100; Top = 200; Width = 400; Height = 300 }
            } -ModuleName LastWarAutoScreenshot
            $result = ConvertTo-ScreenCoordinates -WindowHandle 1 -RelativeX 0.5 -RelativeY 0.5
            $result.X | Should -Be 300
            $result.Y | Should -Be 350
        }
    }
    It 'throws when input is out of range (ValidateRange enforcement)' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-WindowBounds {
                param($WindowHandle)
                return @{ Left = 100; Top = 200; Width = 400; Height = 300 }
            } -ModuleName LastWarAutoScreenshot
            # [ValidateRange(0.0, 1.0)] throws before the function body runs
            { ConvertTo-ScreenCoordinates -WindowHandle 1 -RelativeX 1.5 -RelativeY 0.5 } | Should -Throw
        }
    }
}
#endregion
