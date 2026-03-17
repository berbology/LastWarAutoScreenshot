BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'Unregister-LWASScheduledTask' -Tag 'Unit' {

    BeforeEach {
        Mock Get-ScheduledTask {
            [PSCustomObject]@{ TaskName = 'LWAS_my-macro' }
        } -ModuleName LastWarAutoScreenshot

        Mock Unregister-ScheduledTask { } -ModuleName LastWarAutoScreenshot
        Mock Remove-Item { } -ModuleName LastWarAutoScreenshot
        Mock Test-Path { $true } -ModuleName LastWarAutoScreenshot
        Mock Write-LastWarLog { } -ModuleName LastWarAutoScreenshot
        Mock Write-Warning { } -ModuleName LastWarAutoScreenshot
    }

    Context 'Happy path' {

        It 'Calls Unregister-ScheduledTask when the task exists' {
            InModuleScope LastWarAutoScreenshot {
                Unregister-LWASScheduledTask -MacroName 'my-macro' -Force

                Should -Invoke Unregister-ScheduledTask -Times 1 -ModuleName LastWarAutoScreenshot `
                    -ParameterFilter { $TaskName -eq 'LWAS_my-macro' }
            }
        }

        It 'Calls Remove-Item for the launcher script when task and launcher exist' {
            InModuleScope LastWarAutoScreenshot {
                Unregister-LWASScheduledTask -MacroName 'my-macro' -Force

                Should -Invoke Remove-Item -Times 1 -ModuleName LastWarAutoScreenshot `
                    -ParameterFilter { $Path -like '*LWAS_my-macro.ps1' }
            }
        }

        It 'Does not throw when launcher file is missing (-ErrorAction SilentlyContinue)' {
            InModuleScope LastWarAutoScreenshot {
                Mock Test-Path { $false }

                { Unregister-LWASScheduledTask -MacroName 'my-macro' -Force } | Should -Not -Throw

                Should -Invoke Unregister-ScheduledTask -Times 1 -ModuleName LastWarAutoScreenshot
            }
        }
    }

    Context 'Task not found' {

        It 'Emits a warning and does not call Unregister-ScheduledTask when task is missing' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-ScheduledTask { $null }

                Unregister-LWASScheduledTask -MacroName 'nonexistent' -Force

                Should -Invoke Write-Warning -Times 1 -ModuleName LastWarAutoScreenshot `
                    -ParameterFilter { $Message -like '*nonexistent*' }
                Should -Invoke Unregister-ScheduledTask -Times 0 -ModuleName LastWarAutoScreenshot
            }
        }
    }

    Context '-WhatIf' {

        It 'Does not call Unregister-ScheduledTask when -WhatIf is supplied' {
            InModuleScope LastWarAutoScreenshot {
                Unregister-LWASScheduledTask -MacroName 'my-macro' -WhatIf

                Should -Invoke Unregister-ScheduledTask -Times 0 -ModuleName LastWarAutoScreenshot
            }
        }
    }
}
