BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'Start-LWASAutomationSequence' -Tag 'Unit' {

    BeforeAll {
        # Helper that returns a valid mock window object
        function New-MockWindowObject {
            param([string]$Title = 'Test Window', [switch]$Minimised)
            return [PSCustomObject]@{
                ProcessName   = 'lastwar.exe'
                WindowTitle   = $Title
                WindowHandle  = [IntPtr]12345
                WindowState   = if ($Minimised) { 'Minimised' } else { 'Normal' }
                PID           = [uint32]1001
            }
        }

        # Helper that returns a mock macro result as returned by Get-LWASMacro
        function New-MockMacro {
            param([string]$Name = 'test-macro')
            return [PSCustomObject]@{
                FileName    = '20260101_120000_test-macro.json'
                FilePath    = 'C:\fake\test-macro.json'
                Name        = $Name
                CreatedUtc  = [datetime]'2026-01-01T12:00:00Z'
                DisplayDate = '01/01/26 12:00:00'
                ActionCount = 2
                Valid       = $true
                Metadata    = [PSCustomObject]@{ name = $Name; createdUtc = '2026-01-01T12:00:00Z' }
                Sequence    = @(
                    [PSCustomObject]@{ type = 'Delay'; durationMs = 100 },
                    [PSCustomObject]@{ type = 'Delay'; durationMs = 200 }
                )
            }
        }
    }

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            Mock Test-WindowHandleValid { $true }
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    EmergencyStop  = [PSCustomObject]@{ AutoStart = $true }
                    MacroExecution = [PSCustomObject]@{ WindowRestoreDelayMs = 500 }
                }
            }
            Mock Invoke-IsIconic { $false }
            Mock Set-WindowState { $true }
            Mock Get-LWASMacro {
                [PSCustomObject]@{
                    Name     = 'test-macro'
                    Metadata = [PSCustomObject]@{ name = 'test-macro'; createdUtc = '2026-01-01T12:00:00Z' }
                    Sequence = @(
                        [PSCustomObject]@{ type = 'Delay'; durationMs = 100 }
                    )
                    Valid    = $true
                }
            }
            Mock Invoke-MacroSequence {
                [PSCustomObject]@{
                    Success          = $true
                    CompletedActions = 1
                    TotalActions     = 1
                    SimilarityStop   = $false
                    Message          = 'Macro completed successfully.'
                }
            }
            Mock Start-LWASEmergencyStopMonitor {}
            Mock Stop-LWASEmergencyStopMonitor {}
            Mock Write-LastWarLog {}
            Mock Start-Sleep {}
        }
    }

    Context 'Valid window and macro' {
        It 'Invokes Invoke-MacroSequence exactly once and returns Success = true' {
            InModuleScope LastWarAutoScreenshot {
                $window = [PSCustomObject]@{
                    ProcessName  = 'lastwar.exe'
                    WindowTitle  = 'Test Window'
                    WindowHandle = [IntPtr]12345
                    WindowState  = 'Normal'
                }
                $result = $window | Start-LWASAutomationSequence -MacroName 'test-macro'
                Should -Invoke Invoke-MacroSequence -Times 1
                $result.Success | Should -BeTrue
                $result.MacroName | Should -Be 'test-macro'
            }
        }

        It 'Result contains the window title' {
            InModuleScope LastWarAutoScreenshot {
                $window = [PSCustomObject]@{
                    ProcessName  = 'lastwar.exe'
                    WindowTitle  = 'My Game Window'
                    WindowHandle = [IntPtr]12345
                    WindowState  = 'Normal'
                }
                $result = $window | Start-LWASAutomationSequence -MacroName 'test-macro'
                $result.WindowTitle | Should -Be 'My Game Window'
            }
        }
    }

    Context 'Invalid window handle' {
        It 'Does not call Invoke-MacroSequence and returns Success = false' {
            InModuleScope LastWarAutoScreenshot {
                Mock Test-WindowHandleValid { $false }
                $window = [PSCustomObject]@{
                    ProcessName  = 'lastwar.exe'
                    WindowTitle  = 'Gone Window'
                    WindowHandle = [IntPtr]99999
                    WindowState  = 'Normal'
                }
                $result = $window | Start-LWASAutomationSequence -MacroName 'test-macro' -ErrorAction SilentlyContinue
                Should -Invoke Invoke-MacroSequence -Times 0
                $result.Success | Should -BeFalse
            }
        }
    }

    Context 'Minimised window' {
        It 'Calls Set-WindowState with Restore and Start-Sleep with the configured delay' {
            InModuleScope LastWarAutoScreenshot {
                Mock Invoke-IsIconic { $true }
                $window = [PSCustomObject]@{
                    ProcessName  = 'lastwar.exe'
                    WindowTitle  = 'Minimised Window'
                    WindowHandle = [IntPtr]12345
                    WindowState  = 'Minimised'
                }
                $window | Start-LWASAutomationSequence -MacroName 'test-macro' | Out-Null
                Should -Invoke Set-WindowState -ParameterFilter { $State -eq 'Restore' } -Times 1
                Should -Invoke Start-Sleep -ParameterFilter { $Milliseconds -eq 500 } -Times 1
            }
        }

        It 'Calls Start-Sleep with 0 when WindowRestoreDelayMs is 0' {
            InModuleScope LastWarAutoScreenshot {
                Mock Invoke-IsIconic { $true }
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        EmergencyStop  = [PSCustomObject]@{ AutoStart = $true }
                        MacroExecution = [PSCustomObject]@{ WindowRestoreDelayMs = 0 }
                    }
                }
                $window = [PSCustomObject]@{
                    ProcessName  = 'lastwar.exe'
                    WindowTitle  = 'Minimised Window'
                    WindowHandle = [IntPtr]12345
                    WindowState  = 'Minimised'
                }
                $window | Start-LWASAutomationSequence -MacroName 'test-macro' | Out-Null
                Should -Invoke Start-Sleep -ParameterFilter { $Milliseconds -eq 0 } -Times 1
            }
        }

        It 'Logs Info when restoring a minimised window' {
            InModuleScope LastWarAutoScreenshot {
                Mock Invoke-IsIconic { $true }
                $window = [PSCustomObject]@{
                    ProcessName  = 'lastwar.exe'
                    WindowTitle  = 'Minimised Window'
                    WindowHandle = [IntPtr]12345
                    WindowState  = 'Minimised'
                }
                $window | Start-LWASAutomationSequence -MacroName 'test-macro' | Out-Null
                Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Info' } -Times 1
            }
        }
    }

    Context 'Non-minimised window' {
        It 'Does not call Set-WindowState' {
            InModuleScope LastWarAutoScreenshot {
                Mock Invoke-IsIconic { $false }
                $window = [PSCustomObject]@{
                    ProcessName  = 'lastwar.exe'
                    WindowTitle  = 'Normal Window'
                    WindowHandle = [IntPtr]12345
                    WindowState  = 'Normal'
                }
                $window | Start-LWASAutomationSequence -MacroName 'test-macro' | Out-Null
                Should -Invoke Set-WindowState -Times 0
            }
        }
    }

    Context 'Macro not found' {
        It 'Does not call Invoke-MacroSequence and returns Success = false' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-LWASMacro { @() }
                $window = [PSCustomObject]@{
                    ProcessName  = 'lastwar.exe'
                    WindowTitle  = 'Test Window'
                    WindowHandle = [IntPtr]12345
                    WindowState  = 'Normal'
                }
                $result = $window | Start-LWASAutomationSequence -MacroName 'missing-macro' -ErrorAction SilentlyContinue
                Should -Invoke Invoke-MacroSequence -Times 0
                $result.Success | Should -BeFalse
            }
        }
    }

    Context 'Macro execution throws' {
        It 'Returns Success = false when Invoke-MacroSequence throws' {
            InModuleScope LastWarAutoScreenshot {
                Mock Invoke-MacroSequence { throw 'Execution error' }
                $window = [PSCustomObject]@{
                    ProcessName  = 'lastwar.exe'
                    WindowTitle  = 'Test Window'
                    WindowHandle = [IntPtr]12345
                    WindowState  = 'Normal'
                }
                $result = $window | Start-LWASAutomationSequence -MacroName 'test-macro' -ErrorAction SilentlyContinue
                $result.Success | Should -BeFalse
            }
        }
    }

    Context 'Pipeline with multiple windows' {
        It 'Invokes Invoke-MacroSequence once per window and returns two result objects' {
            InModuleScope LastWarAutoScreenshot {
                $windows = @(
                    [PSCustomObject]@{ ProcessName = 'lastwar.exe'; WindowTitle = 'Window 1'; WindowHandle = [IntPtr]1001; WindowState = 'Normal' },
                    [PSCustomObject]@{ ProcessName = 'lastwar.exe'; WindowTitle = 'Window 2'; WindowHandle = [IntPtr]1002; WindowState = 'Normal' }
                )
                $results = @($windows | Start-LWASAutomationSequence -MacroName 'test-macro')
                Should -Invoke Invoke-MacroSequence -Times 2
                $results.Count | Should -Be 2
            }
        }
    }
}
