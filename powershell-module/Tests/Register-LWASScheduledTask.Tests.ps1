BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Register-LWASScheduledTask' -Tag 'Unit' {

    BeforeEach {
        Mock Get-LWASMacro {
            [PSCustomObject]@{ Name = 'my-macro'; Valid = $true }
        } -ModuleName LastWarAutoScreenshot

        Mock New-LWASLauncherScript {
            'TestDrive:\Schedulers\LWAS_my-macro.ps1'
        } -ModuleName LastWarAutoScreenshot

        Mock New-ScheduledTaskTrigger {
            [PSCustomObject]@{
                RepetitionDuration = $null
                RandomDelay        = $null
                EndBoundary        = $null
            }
        } -ModuleName LastWarAutoScreenshot

        Mock New-ScheduledTaskAction { [PSCustomObject]@{} } -ModuleName LastWarAutoScreenshot
        Mock Invoke-NewScheduledTaskSettingsSet { [PSCustomObject]@{} } -ModuleName LastWarAutoScreenshot
        Mock Invoke-RegisterScheduledTask { } -ModuleName LastWarAutoScreenshot
        Mock Write-LastWarLog { } -ModuleName LastWarAutoScreenshot
        Mock Get-Module {
            [PSCustomObject]@{ Path = 'C:\Modules\LastWarAutoScreenshot.psd1' }
        } -ModuleName LastWarAutoScreenshot
    }

    Context 'Happy path' {

        It 'Registers the task with the correct task name and returns success result' {
            InModuleScope LastWarAutoScreenshot {
                $result = Register-LWASScheduledTask `
                    -MacroName 'my-macro' `
                    -ProcessName 'lastwar.exe' `
                    -StartAt ([datetime]'2026-06-01 08:00')

                Should -Invoke Invoke-RegisterScheduledTask -Times 1 -ModuleName LastWarAutoScreenshot `
                    -ParameterFilter { $TaskName -eq 'LWAS_my-macro' }

                $result.Success   | Should -BeTrue
                $result.TaskName  | Should -BeExactly 'LWAS_my-macro'
                $result.MacroName | Should -BeExactly 'my-macro'
                $result.LauncherPath | Should -Not -BeNullOrEmpty
            }
        }

        It 'Creates a trigger without a repetition interval when -RepeatEvery is not supplied' {
            InModuleScope LastWarAutoScreenshot {
                Register-LWASScheduledTask `
                    -MacroName 'my-macro' `
                    -ProcessName 'lastwar.exe' `
                    -StartAt ([datetime]'2026-06-01 08:00') | Out-Null

                Should -Invoke New-ScheduledTaskTrigger -Times 1 -ModuleName LastWarAutoScreenshot `
                    -ParameterFilter { $null -eq $RepetitionInterval }
            }
        }

        It 'Sets trigger RandomDelay when -RandomDelayMinutes 30 is supplied' {
            InModuleScope LastWarAutoScreenshot {
                $capturedTrigger = $null
                Mock New-ScheduledTaskTrigger {
                    $t = [PSCustomObject]@{
                        RepetitionDuration = $null
                        RandomDelay        = $null
                        EndBoundary        = $null
                    }
                    $script:capturedTrigger = $t
                    $t
                }

                Register-LWASScheduledTask `
                    -MacroName 'my-macro' `
                    -ProcessName 'lastwar.exe' `
                    -StartAt ([datetime]'2026-06-01 08:00') `
                    -RandomDelayMinutes 30 | Out-Null

                $script:capturedTrigger.RandomDelay | Should -Be ([TimeSpan]::FromMinutes(30))
            }
        }

        It 'Sets trigger EndBoundary when -ExpiresAt is supplied' {
            InModuleScope LastWarAutoScreenshot {
                $capturedTrigger = $null
                Mock New-ScheduledTaskTrigger {
                    $t = [PSCustomObject]@{
                        RepetitionDuration = $null
                        RandomDelay        = $null
                        EndBoundary        = $null
                    }
                    $script:capturedTrigger = $t
                    $t
                }

                $expiry = [datetime]'2026-12-31 23:59'
                Register-LWASScheduledTask `
                    -MacroName 'my-macro' `
                    -ProcessName 'lastwar.exe' `
                    -StartAt ([datetime]'2026-06-01 08:00') `
                    -ExpiresAt $expiry | Out-Null

                $script:capturedTrigger.EndBoundary | Should -Not -BeNullOrEmpty
            }
        }

        It 'Sets trigger RepetitionDuration when -RepeatFor is a specific timespan' {
            InModuleScope LastWarAutoScreenshot {
                $capturedTrigger = $null
                Mock New-ScheduledTaskTrigger {
                    $t = [PSCustomObject]@{
                        RepetitionDuration = $null
                        RandomDelay        = $null
                        EndBoundary        = $null
                    }
                    $script:capturedTrigger = $t
                    $t
                }

                $duration = [TimeSpan]::FromDays(7)
                Register-LWASScheduledTask `
                    -MacroName 'my-macro' `
                    -ProcessName 'lastwar.exe' `
                    -StartAt ([datetime]'2026-06-01 08:00') `
                    -RepeatFor $duration | Out-Null

                $script:capturedTrigger.RepetitionDuration | Should -Be $duration
            }
        }

        It 'Uses the supplied -RepeatEvery timespan for the trigger interval' {
            InModuleScope LastWarAutoScreenshot {
                Register-LWASScheduledTask `
                    -MacroName 'my-macro' `
                    -ProcessName 'lastwar.exe' `
                    -StartAt ([datetime]'2026-06-01 08:00') `
                    -RepeatEvery ([TimeSpan]::FromHours(2)) | Out-Null

                Should -Invoke New-ScheduledTaskTrigger -Times 1 -ModuleName LastWarAutoScreenshot `
                    -ParameterFilter { $RepetitionInterval -eq [TimeSpan]::FromHours(2) }
            }
        }
    }

    Context 'Error handling' {

        It 'Throws when the macro is not found' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-LWASMacro { }

                { Register-LWASScheduledTask `
                    -MacroName 'missing-macro' `
                    -ProcessName 'lastwar.exe' `
                    -StartAt ([datetime]'2026-06-01 08:00') } | Should -Throw '*missing-macro*'
            }
        }
    }

    Context '-WhatIf' {

        It 'Does not call Register-ScheduledTask when -WhatIf is supplied' {
            InModuleScope LastWarAutoScreenshot {
                Register-LWASScheduledTask `
                    -MacroName 'my-macro' `
                    -ProcessName 'lastwar.exe' `
                    -StartAt ([datetime]'2026-06-01 08:00') `
                    -WhatIf | Out-Null

                Should -Invoke Invoke-RegisterScheduledTask -Times 0 -ModuleName LastWarAutoScreenshot
            }
        }
    }
}
