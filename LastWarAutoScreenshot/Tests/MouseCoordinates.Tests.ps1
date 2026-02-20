# MouseCoordinates.Tests.ps1
# Pester tests for Get-WindowBounds and ConvertTo-ScreenCoordinates

#region Get-WindowBounds
Describe 'Get-WindowBounds' {
    Mock Invoke-GetWindowRect {
        param($WindowHandle)
        if ($WindowHandle -eq 'fail') {
            throw 'Win32 error'
        }
        return @{ Left = 10; Top = 20; Right = 110; Bottom = 220 }
    }
    It 'returns correct PSCustomObject shape and width/height' {
        $result = . $PSScriptRoot/../Private/Get-WindowBounds.ps1; Get-WindowBounds -WindowHandle 123
        $result | Should -BeOfType PSCustomObject
        $result.Left | Should -Be 10
        $result.Top | Should -Be 20
        $result.Right | Should -Be 110
        $result.Bottom | Should -Be 220
        $result.Width | Should -Be 100
        $result.Height | Should -Be 200
    }
    It 'logs error and returns $false on Win32 failure' {
        Mock Write-LastWarLog {}
        $result = . $PSScriptRoot/../Private/Get-WindowBounds.ps1; Get-WindowBounds -WindowHandle 'fail'
        $result | Should -Be $false
        Assert-MockCalled Write-LastWarLog -Exactly 1
    }
}
#endregion

#region ConvertTo-ScreenCoordinates
Describe 'ConvertTo-ScreenCoordinates' {
    Mock Get-WindowBounds {
        param($WindowHandle)
        return @{ Left = 100; Top = 200; Width = 400; Height = 300 }
    }
    It 'returns correct absolute coordinates for (0.0, 0.0)' {
        $result = . $PSScriptRoot/../Private/ConvertTo-ScreenCoordinates.ps1; ConvertTo-ScreenCoordinates -WindowHandle 1 -RelativeX 0.0 -RelativeY 0.0
        $result.X | Should -Be 100
        $result.Y | Should -Be 200
    }
    It 'returns correct absolute coordinates for (1.0, 1.0)' {
        $result = . $PSScriptRoot/../Private/ConvertTo-ScreenCoordinates.ps1; ConvertTo-ScreenCoordinates -WindowHandle 1 -RelativeX 1.0 -RelativeY 1.0
        $result.X | Should -Be 500
        $result.Y | Should -Be 500
    }
    It 'returns correct absolute coordinates for (0.5, 0.5)' {
        $result = . $PSScriptRoot/../Private/ConvertTo-ScreenCoordinates.ps1; ConvertTo-ScreenCoordinates -WindowHandle 1 -RelativeX 0.5 -RelativeY 0.5
        $result.X | Should -Be 300
        $result.Y | Should -Be 350
    }
    It 'returns $null and logs error when input is out of range' {
        Mock Write-LastWarLog {}
        $result = . $PSScriptRoot/../Private/ConvertTo-ScreenCoordinates.ps1; ConvertTo-ScreenCoordinates -WindowHandle 1 -RelativeX 1.5 -RelativeY 0.5
        $result | Should -Be $null
        Assert-MockCalled Write-LastWarLog -Exactly 1
    }
}
#endregion
