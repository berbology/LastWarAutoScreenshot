BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'Get-LWASScheduledTask' -Tag 'Unit' {

    BeforeEach {
        Mock Get-ScheduledTask {
            @(
                [PSCustomObject]@{ TaskName = 'LWAS_macro-1'; State = 'Ready' },
                [PSCustomObject]@{ TaskName = 'LWAS_macro-2'; State = 'Running' }
            )
        } -ModuleName LastWarAutoScreenshot

        Mock Get-ScheduledTaskInfo {
            [PSCustomObject]@{
                NextRunTime    = [datetime]'2026-06-01 10:00'
                LastRunTime    = [datetime]'2026-05-31 10:00'
                LastTaskResult = 0
            }
        } -ModuleName LastWarAutoScreenshot
    }

    Context 'No tasks exist and no -MacroName filter' {

        It 'Writes a warning and returns 0 objects when no LWAS tasks are registered' {
            Mock Get-ScheduledTask { @() } -ModuleName LastWarAutoScreenshot

            InModuleScope LastWarAutoScreenshot {
                Mock Write-Warning { }

                $result = @(Get-LWASScheduledTask)
                $result.Count | Should -Be 0

                Should -Invoke Write-Warning -Times 1 `
                    -ParameterFilter { $Message -like '*No LWAS scheduled tasks found*' }
            }
        }
    }

    Context 'No -MacroName filter' {

        It 'Returns 2 objects when 2 LWAS tasks exist' {
            InModuleScope LastWarAutoScreenshot {
                $result = @(Get-LWASScheduledTask)
                $result.Count | Should -Be 2
            }
        }

        It 'Strips the LWAS_ prefix from the MacroName property' {
            InModuleScope LastWarAutoScreenshot {
                $result = @(Get-LWASScheduledTask)
                $result[0].MacroName | Should -BeExactly 'macro-1'
                $result[1].MacroName | Should -BeExactly 'macro-2'
            }
        }

        It 'Preserves the full task name including LWAS_ prefix in TaskName property' {
            InModuleScope LastWarAutoScreenshot {
                $result = @(Get-LWASScheduledTask)
                $result[0].TaskName | Should -BeExactly 'LWAS_macro-1'
            }
        }
    }

    Context '-MacroName filter' {

        It 'Returns 1 object when -MacroName matches exactly one task' {
            InModuleScope LastWarAutoScreenshot {
                $result = @(Get-LWASScheduledTask -MacroName 'macro-1')
                $result.Count | Should -Be 1
                $result[0].MacroName | Should -BeExactly 'macro-1'
            }
        }

        It 'Writes a non-terminating error and returns 0 objects when macro is not found' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-Error { }

                $result = @(Get-LWASScheduledTask -MacroName 'nonexistent' -ErrorAction SilentlyContinue)
                $result.Count | Should -Be 0

                Should -Invoke Write-Error -Times 1 `
                    -ParameterFilter { $Message -like '*nonexistent*' }
            }
        }
    }

    Context 'Returned object shape' {

        It 'Has NextRunTime, LastRunTime, LastTaskResult, and LauncherPath properties' {
            InModuleScope LastWarAutoScreenshot {
                $result = @(Get-LWASScheduledTask)
                $obj = $result[0]

                $obj.PSObject.Properties.Name | Should -Contain 'NextRunTime'
                $obj.PSObject.Properties.Name | Should -Contain 'LastRunTime'
                $obj.PSObject.Properties.Name | Should -Contain 'LastTaskResult'
                $obj.PSObject.Properties.Name | Should -Contain 'LauncherPath'
            }
        }

        It 'LauncherPath ends with the task name and .ps1 extension' {
            InModuleScope LastWarAutoScreenshot {
                $result = @(Get-LWASScheduledTask)
                $result[0].LauncherPath | Should -BeLike '*LWAS_macro-1.ps1'
            }
        }

        It 'NextRunTime and LastRunTime are populated from Get-ScheduledTaskInfo' {
            InModuleScope LastWarAutoScreenshot {
                $result = @(Get-LWASScheduledTask)
                $result[0].NextRunTime | Should -Not -BeNullOrEmpty
                $result[0].LastRunTime | Should -Not -BeNullOrEmpty
            }
        }
    }
}
