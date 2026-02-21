# MouseMovement.Tests.ps1
# Pester tests for Move-MouseToPoint and Invoke-MouseClick (Phase 2, 1.14 step 1 only)

BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'Move-MouseToPoint' {
    It 'calls Invoke-SendMouseInput with correct delta' {
        InModuleScope -ModuleName LastWarAutoScreenshot {
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 100; Y = 200 } } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { 1 } -ModuleName LastWarAutoScreenshot
            Move-MouseToPoint -X 110 -Y 220 | Should -Be $true
            Should -Invoke Invoke-GetCursorPosition -Exactly 1
            Should -Invoke Invoke-SendMouseInput -Exactly 1 -ParameterFilter {
                $DeltaX -eq 10 -and $DeltaY -eq 20
            }
        }
    }

    It 'returns $false and logs error if SendInput fails' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-SendMouseInput { 0 } -ModuleName LastWarAutoScreenshot
            Mock Write-LastWarLog {} -ModuleName LastWarAutoScreenshot
            Move-MouseToPoint -X 110 -Y 220 | Should -Be $false
            Should -Invoke Write-LastWarLog -Exactly 1
        }
    }
}


Describe 'Invoke-MouseClick' {
    It 'calls Move-MouseToPoint if position differs' {
        InModuleScope LastWarAutoScreenshot {
            Mock Move-MouseToPoint { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 10; Y = 20 } } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { 1 } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration { @{ MouseControl = @{ ClickDownDurationRangeMs = @(50, 150) } } } -ModuleName LastWarAutoScreenshot
            Invoke-MouseClick -X 30 -Y 40 -DownDurationMs 100 | Should -Be $true
            Should -Invoke Move-MouseToPoint -Exactly 1
        }
    }

    It 'does not call Move-MouseToPoint if already at position' {
        InModuleScope LastWarAutoScreenshot {
            Mock Move-MouseToPoint { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 30; Y = 40 } } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { 1 } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration { @{ MouseControl = @{ ClickDownDurationRangeMs = @(50, 150) } } } -ModuleName LastWarAutoScreenshot
            Invoke-MouseClick -X 30 -Y 40 -DownDurationMs 100 | Should -Be $true
            Should -Invoke Move-MouseToPoint -Exactly 0
        }
    }

    It 'calls LEFTDOWN then sleeps then LEFTUP' {
        InModuleScope LastWarAutoScreenshot {
            Mock Move-MouseToPoint { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 10; Y = 20 } } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { 1 } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration { @{ MouseControl = @{ ClickDownDurationRangeMs = @(50, 150) } } } -ModuleName LastWarAutoScreenshot
            Invoke-MouseClick -X 30 -Y 40 -DownDurationMs 100 | Should -Be $true
            # Verify LEFTDOWN and LEFTUP were each sent exactly once via ParameterFilter
            Should -Invoke Invoke-SendMouseInput -Exactly 1 -ParameterFilter { $ButtonFlags -eq [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_LEFTDOWN }
            Should -Invoke Invoke-SendMouseInput -Exactly 1 -ParameterFilter { $ButtonFlags -eq [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_LEFTUP }
            Should -Invoke Start-Sleep -Exactly 1 -ParameterFilter { $Milliseconds -eq 100 }
        }
    }

    It 'uses config-derived duration if -DownDurationMs omitted' {
        InModuleScope LastWarAutoScreenshot {
            Mock Move-MouseToPoint { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 10; Y = 20 } } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { 1 } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration { @{ MouseControl = @{ ClickDownDurationRangeMs = @(50, 150) } } } -ModuleName LastWarAutoScreenshot
            Mock Get-Random { 75 } -ModuleName LastWarAutoScreenshot
            Invoke-MouseClick -X 30 -Y 40 | Should -Be $true
            Should -Invoke Start-Sleep -Exactly 1 -ParameterFilter { $Milliseconds -eq 75 }
        }
    }

    It 'returns $false and logs error if SendInput fails' {
        InModuleScope LastWarAutoScreenshot {
            Mock Move-MouseToPoint { $true } -ModuleName LastWarAutoScreenshot
            Mock Invoke-GetCursorPosition { [PSCustomObject]@{ X = 10; Y = 20 } } -ModuleName LastWarAutoScreenshot
            Mock Invoke-SendMouseInput { 0 } -ModuleName LastWarAutoScreenshot
            Mock Start-Sleep {} -ModuleName LastWarAutoScreenshot
            Mock Get-ModuleConfiguration { @{ MouseControl = @{ ClickDownDurationRangeMs = @(50, 150) } } } -ModuleName LastWarAutoScreenshot
            Mock Write-LastWarLog {} -ModuleName LastWarAutoScreenshot
            Invoke-MouseClick -X 30 -Y 40 -DownDurationMs 100 | Should -Be $false
            Should -Invoke Write-LastWarLog -Exactly 1
        }
    }
}
