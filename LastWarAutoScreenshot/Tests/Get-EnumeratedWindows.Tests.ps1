<#
.SYNOPSIS
    Pester tests for Get-EnumeratedWindows function.

.DESCRIPTION
    Tests for window enumeration functionality using Pester v5.
    Because Get-EnumeratedWindows wraps Win32 API calls that cannot be mocked
    via Pester, these tests exercise the function against the live Windows environment.
#>

BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe "Get-EnumeratedWindows" -Tag "Unit" {

    Context "Parameter validation" {

        It "Should throw when ProcessName is an empty string" {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                { Get-EnumeratedWindows -ProcessName '' } | Should -Throw
            }
        }

        It "Should not throw when ProcessName is a valid string" {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                $VerbosePreference = 'SilentlyContinue'
                { Get-EnumeratedWindows -ProcessName 'NonExistentProcess12345' } | Should -Not -Throw
            }
        }

        It "Should not throw when ExcludeMinimized switch is used" {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                $VerbosePreference = 'SilentlyContinue'
                { Get-EnumeratedWindows -ExcludeMinimized } | Should -Not -Throw
            }
        }

        It "Should not throw when VisibleOnly switch is used" {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                $VerbosePreference = 'SilentlyContinue'
                { Get-EnumeratedWindows -VisibleOnly } | Should -Not -Throw
            }
        }
    }

    Context "Return object structure" {

        It "Should return at least one window on a running Windows system" {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                $VerbosePreference = 'SilentlyContinue'
                $allWindows = Get-EnumeratedWindows
                $allWindows | Should -Not -BeNullOrEmpty
            }
        }

        It "Should return objects with a non-empty ProcessName" {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                $VerbosePreference = 'SilentlyContinue'
                $allWindows = Get-EnumeratedWindows
                $allWindows[0].ProcessName | Should -Not -BeNullOrEmpty
            }
        }

        It "Should return objects with a non-empty WindowTitle" {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                $VerbosePreference = 'SilentlyContinue'
                $allWindows = Get-EnumeratedWindows
                $allWindows[0].WindowTitle | Should -Not -BeNullOrEmpty
            }
        }

        It "Should return objects with a WindowHandleInt greater than zero" {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                $VerbosePreference = 'SilentlyContinue'
                $allWindows = Get-EnumeratedWindows
                $allWindows[0].WindowHandleInt | Should -BeGreaterThan 0
            }
        }

        It "Should return objects with a ProcessID greater than zero" {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                $VerbosePreference = 'SilentlyContinue'
                $allWindows = Get-EnumeratedWindows
                [int64]$allWindows[0].ProcessID | Should -BeGreaterThan 0
            }
        }

        It "Should return only valid WindowState values" {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                $VerbosePreference = 'SilentlyContinue'
                $allWindows = Get-EnumeratedWindows
                $validStates = @('Visible', 'Minimized', 'Hidden')
                $allWindows | ForEach-Object {
                    $_.WindowState | Should -BeIn $validStates
                }
            }
        }
    }

    Context "ProcessName filtering" {

        It "Should return empty result for a non-existent ProcessName" {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                $VerbosePreference = 'SilentlyContinue'
                $result = Get-EnumeratedWindows -ProcessName 'NonExistentProcess12345'
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return only windows matching the specified ProcessName" {
            InModuleScope -ModuleName LastWarAutoScreenshot {
                $VerbosePreference = 'SilentlyContinue'
                $result = Get-EnumeratedWindows -ProcessName 'explorer'
                if ($null -eq $result) {
                    Set-ItResult -Skipped -Because "No titled 'explorer' windows found on this system"
                    return
                }
                $result | ForEach-Object {
                    $_.ProcessName | Should -Be 'explorer'
                }
            }
        }
    }

    Context "Visibility filtering" {

        It "Should return only Visible windows when ExcludeMinimized is specified" {
            InModuleScope LastWarAutoScreenshot {
                $VerbosePreference = 'SilentlyContinue'
                $result = Get-EnumeratedWindows -ExcludeMinimized
                $result | ForEach-Object {
                    $_.WindowState | Should -Be 'Visible'
                }
            }
        }

        It "Should return only Visible windows when VisibleOnly is specified" {
            InModuleScope LastWarAutoScreenshot {
                $VerbosePreference = 'SilentlyContinue'
                $result = Get-EnumeratedWindows -VisibleOnly
                $result | ForEach-Object {
                    $_.WindowState | Should -Be 'Visible'
                }
            }
        }
    }

}
