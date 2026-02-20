# MouseMovement.Tests.ps1
# Pester tests for Move-MouseToPoint and Invoke-MouseClick (Phase 2, 1.14 step 1 only)

Describe 'Move-MouseToPoint' {
    Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 100; Y = 200 } }
    Mock Invoke-SendMouseInput { 1 } # Simulate success

    It 'calls Invoke-SendMouseInput with correct delta' {
        Move-MouseToPoint -X 110 -Y 220 | Should -Be $true
        Assert-MockCalled Invoke-GetCursorPosition -Exactly 1
        Assert-MockCalled Invoke-SendMouseInput -Exactly 1 -ParameterFilter {
            $DeltaX -eq 10 -and $DeltaY -eq 20
        }
    }

    It 'returns $false and logs error if SendInput fails' {
        Mock Invoke-SendMouseInput { 0 } # Simulate failure
        Mock Write-LastWarLog {}
        Move-MouseToPoint -X 110 -Y 220 | Should -Be $false
        Assert-MockCalled Write-LastWarLog -Exactly 1
    }
}

Describe 'Invoke-MouseClick' {
    Mock Move-MouseToPoint { $true }
    Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 10; Y = 20 } }
    Mock Invoke-SendMouseInput { 1 }
    Mock Start-Sleep {}
    Mock Get-ModuleConfiguration { @{ MouseControl = @{ ClickDownDurationRangeMs = @(50, 150) } } }

    It 'calls Move-MouseToPoint if position differs' {
        Invoke-MouseClick -X 30 -Y 40 -DownDurationMs 100 | Should -Be $true
        Assert-MockCalled Move-MouseToPoint -Exactly 1
    }

    It 'does not call Move-MouseToPoint if already at position' {
        Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 30; Y = 40 } }
        Invoke-MouseClick -X 30 -Y 40 -DownDurationMs 100 | Should -Be $true
        Assert-MockCalled Move-MouseToPoint -Exactly 0
    }

    It 'calls LEFTDOWN then sleeps then LEFTUP' {
        $calls = @()
        Mock Invoke-SendMouseInput {
            param($DeltaX, $DeltaY, $ButtonFlags)
            $calls += $ButtonFlags
            1
        }
        Invoke-MouseClick -X 30 -Y 40 -DownDurationMs 100 | Should -Be $true
       
        $calls[0] | Should -Be [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_LEFTDOWN
        $calls[1] | Should -Be [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_LEFTUP
        Assert-MockCalled Start-Sleep -Exactly 1 -ParameterFilter { $Milliseconds -eq 100 }
    }

    It 'uses config-derived duration if -DownDurationMs omitted' {
        Mock Get-Random { 75 }
        Invoke-MouseClick -X 30 -Y 40 | Should -Be $true
        Assert-MockCalled Start-Sleep -Exactly 1 -ParameterFilter { $Milliseconds -eq 75 }
    }

    It 'returns $false and logs error if SendInput fails' {
        Mock Invoke-SendMouseInput { 0 }
        Mock Write-LastWarLog {}
        Invoke-MouseClick -X 30 -Y 40 -DownDurationMs 100 | Should -Be $false
        Assert-MockCalled Write-LastWarLog -Exactly 1
    }
}
