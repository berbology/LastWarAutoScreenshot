BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Get-LWASTargetWindow' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            $script:mockWindowList = @(
                [PSCustomObject]@{ ProcessName = 'lastwar.exe'; WindowTitle = 'Last War';     WindowState = 'Normal';    PID = 100; WindowHandle = 1 },
                [PSCustomObject]@{ ProcessName = 'lastwar.exe'; WindowTitle = 'Last War (2)'; WindowState = 'Minimised'; PID = 101; WindowHandle = 2 },
                [PSCustomObject]@{ ProcessName = 'notepad.exe'; WindowTitle = 'Notepad';      WindowState = 'Normal';    PID = 200; WindowHandle = 3 }
            )
        }
    }

    Context 'Input validation' {

        It 'Calls Write-Error and returns nothing when neither -ProcessName nor -WindowTitle is provided' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-EnumeratedWindows { $script:mockWindowList }

                Mock Write-Error {}

                $result = @(Get-LWASTargetWindow -ErrorAction SilentlyContinue)
                $result | Should -BeNullOrEmpty
                Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*At least one of -ProcessName or -WindowTitle*' }
            }
        }

        It 'Does not call Get-EnumeratedWindows when neither -ProcessName nor -WindowTitle is provided' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-EnumeratedWindows { $script:mockWindowList }

                Get-LWASTargetWindow -ErrorAction SilentlyContinue | Out-Null
                Should -Invoke Get-EnumeratedWindows -Times 0
            }
        }

    }

    Context 'Filtering by -ProcessName' {

        It 'Returns 2 objects for -ProcessName lastwar.exe' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-EnumeratedWindows { $script:mockWindowList }

                $result = @(Get-LWASTargetWindow -ProcessName 'lastwar.exe' -WarningAction SilentlyContinue)
                $result.Count | Should -Be 2
                $result | ForEach-Object { $_.ProcessName | Should -Be 'lastwar.exe' }
            }
        }

        It 'Emits Write-Warning once for the minimised window when -ProcessName lastwar.exe' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-EnumeratedWindows { $script:mockWindowList }

                $warnings = @()
                Get-LWASTargetWindow -ProcessName 'lastwar.exe' -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null
                $warnings.Count | Should -Be 1
                $warnings[0].ToString() | Should -BeLike '*Last War (2)*minimised*'
            }
        }

        It 'Returns 1 object for -ProcessName notepad.exe' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-EnumeratedWindows { $script:mockWindowList }

                $result = @(Get-LWASTargetWindow -ProcessName 'notepad.exe')
                $result.Count | Should -Be 1
                $result[0].ProcessName | Should -Be 'notepad.exe'
            }
        }

        It 'Does not emit Write-Warning for -ProcessName notepad.exe (no minimised windows)' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-EnumeratedWindows { $script:mockWindowList }

                $warnings = @()
                Get-LWASTargetWindow -ProcessName 'notepad.exe' -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null
                $warnings.Count | Should -Be 0
            }
        }

        It 'Calls Write-Error and returns nothing for -ProcessName chrome.exe (no match)' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-EnumeratedWindows { $script:mockWindowList }
                Mock Write-Error {}

                $result = @(Get-LWASTargetWindow -ProcessName 'chrome.exe' -ErrorAction SilentlyContinue)
                $result.Count | Should -Be 0
                Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*No window found*' }
            }
        }

        It 'Matches case-insensitively: -ProcessName LASTWAR.EXE returns 2 objects' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-EnumeratedWindows { $script:mockWindowList }

                $result = @(Get-LWASTargetWindow -ProcessName 'LASTWAR.EXE' -WarningAction SilentlyContinue)
                $result.Count | Should -Be 2
            }
        }

    }

    Context 'Filtering by -WindowTitle' {

        It 'Returns 2 objects for -WindowTitle *War*' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-EnumeratedWindows { $script:mockWindowList }

                $result = @(Get-LWASTargetWindow -WindowTitle '*War*' -WarningAction SilentlyContinue)
                $result.Count | Should -Be 2
            }
        }

    }

    Context 'Combined -ProcessName and -WindowTitle filtering' {

        It 'Returns 1 object for -ProcessName lastwar.exe -WindowTitle *(2)*' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-EnumeratedWindows { $script:mockWindowList }

                $result = @(Get-LWASTargetWindow -ProcessName 'lastwar.exe' -WindowTitle '*(2)*' -WarningAction SilentlyContinue)
                $result.Count | Should -Be 1
                $result[0].WindowTitle | Should -Be 'Last War (2)'
            }
        }

    }

    Context '-First switch behaviour' {

        It 'Returns exactly 1 object when -First is used with multiple matches' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-EnumeratedWindows { $script:mockWindowList }

                $result = @(Get-LWASTargetWindow -ProcessName 'lastwar.exe' -First -WarningAction SilentlyContinue)
                $result.Count | Should -Be 1
                $result[0].WindowTitle | Should -Be 'Last War'
            }
        }

        It 'Returns 1 object when -First is used with a single match' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-EnumeratedWindows { $script:mockWindowList }

                $result = @(Get-LWASTargetWindow -ProcessName 'notepad.exe' -First)
                $result.Count | Should -Be 1
                $result[0].ProcessName | Should -Be 'notepad.exe'
                $result[0].WindowTitle | Should -Be 'Notepad'
            }
        }

        It 'Calls Write-Error and returns nothing when -First is used with no matches' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-EnumeratedWindows { $script:mockWindowList }
                Mock Write-Error {}

                $result = @(Get-LWASTargetWindow -ProcessName 'chrome.exe' -First -ErrorAction SilentlyContinue)
                $result.Count | Should -Be 0
                Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*No window found*' }
            }
        }

        It 'Returns all matching objects when -First is not used with multiple matches' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-EnumeratedWindows { $script:mockWindowList }

                $result = @(Get-LWASTargetWindow -ProcessName 'lastwar.exe' -WarningAction SilentlyContinue)
                $result.Count | Should -Be 2
            }
        }

    }

}
