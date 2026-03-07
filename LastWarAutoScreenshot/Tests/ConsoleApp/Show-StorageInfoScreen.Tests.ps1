# Show-StorageInfoScreen.Tests.ps1
# Pester v5 tests for the Show-StorageInfoScreen private function.

BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force

    # Spectre.Console.Testing.dll ships in lib\test\ and is required for TestConsole
    $testingDll = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}

Describe 'Show-StorageInfoScreen' -Tag 'Unit' {

    # ════════════════════════════════════════════════════════════════════════
    # Context: Storage is not yet configured (IsConfigured=$false)
    # ════════════════════════════════════════════════════════════════════════
    Context 'When storage is not yet configured (IsConfigured=$false)' {

        It 'Does not throw when storage is not configured' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = ''
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured  = $false
                        UsedGB        = 0.0
                        MaxGB         = 0.0
                        UsedPercent   = 0.0
                        LogFileSizeGB = 0.0
                    }
                }
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)    # StoragePath: keep current
                $tc.Input.PushKey([ConsoleKey]::Enter)    # MaxStorageGB: keep current
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Discard changes

                { Show-StorageInfoScreen -Console $tc } | Should -Not -Throw
            }
        }

        It 'Writes the "not yet configured" info panel to the console output' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = ''
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured  = $false
                        UsedGB        = 0.0
                        MaxGB         = 0.0
                        UsedPercent   = 0.0
                        LogFileSizeGB = 0.0
                    }
                }
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-StorageInfoScreen -Console $tc

                $tc.Output | Should -Match 'not yet configured'
            }
        }

        It 'Presents prompts containing both Screenshots key names in console output' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = ''
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured  = $false
                        UsedGB        = 0.0
                        MaxGB         = 0.0
                        UsedPercent   = 0.0
                        LogFileSizeGB = 0.0
                    }
                }
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-StorageInfoScreen -Console $tc

                $tc.Output | Should -Match 'Screenshots\.Storage[\s\S]*Path'
                $tc.Output | Should -Match 'Screenshots\.Max[\s\S]*ageGB'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Storage usage is at or above 90 percent
    # ════════════════════════════════════════════════════════════════════════
    Context 'When storage usage is at or above 90 percent (UsedPercent=95.0)' {

        It 'Writes the over-90-percent warning panel to the console output' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\Screenshots'
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured  = $true
                        UsedGB        = 1.9
                        MaxGB         = 2.0
                        UsedPercent   = 95.0
                        LogFileSizeGB = 0.05
                    }
                }
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)    # StoragePath: keep current
                $tc.Input.PushKey([ConsoleKey]::Enter)    # MaxStorageGB: keep current
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Discard changes

                Show-StorageInfoScreen -Console $tc

                $tc.Output | Should -Match 'over 90'
            }
        }

        It 'Warning panel mentions clearing or increasing limit in console output' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\Screenshots'
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured  = $true
                        UsedGB        = 1.9
                        MaxGB         = 2.0
                        UsedPercent   = 95.0
                        LogFileSizeGB = 0.05
                    }
                }
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-StorageInfoScreen -Console $tc

                $tc.Output | Should -Match 'full'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Storage usage is below 90 percent
    # ════════════════════════════════════════════════════════════════════════
    Context 'When storage usage is below 90 percent (UsedPercent=50.0)' {

        It 'Does not include the over-90-percent warning in console output' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\Screenshots'
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured  = $true
                        UsedGB        = 1.0
                        MaxGB         = 2.0
                        UsedPercent   = 50.0
                        LogFileSizeGB = 0.01
                    }
                }
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)    # StoragePath: keep current
                $tc.Input.PushKey([ConsoleKey]::Enter)    # MaxStorageGB: keep current
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Discard changes

                Show-StorageInfoScreen -Console $tc

                $tc.Output | Should -Not -Match 'over 90'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: User enters valid path and MaxStorageGB then chooses Yes - save now
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user enters valid values for both keys and chooses Yes - save now' {

        It 'Calls Save-ModuleSettings exactly once' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = ''
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured  = $false
                        UsedGB        = 0.0
                        MaxGB         = 0.0
                        UsedPercent   = 0.0
                        LogFileSizeGB = 0.0
                    }
                }
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('C:\NewScreenshots')    # StoragePath: valid new value
                $tc.Input.PushTextWithEnter('3.0')                  # MaxStorageGB: valid new value
                $tc.Input.PushKey([ConsoleKey]::Enter)              # Yes - save now

                Show-StorageInfoScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1
            }
        }

        It 'The config passed to Save-ModuleSettings contains the new StoragePath' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = ''
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured  = $false
                        UsedGB        = 0.0
                        MaxGB         = 0.0
                        UsedPercent   = 0.0
                        LogFileSizeGB = 0.0
                    }
                }
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('C:\NewScreenshots')
                $tc.Input.PushTextWithEnter('3.0')
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-StorageInfoScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.Screenshots.StoragePath -eq 'C:\NewScreenshots'
                }
            }
        }

        It 'The config passed to Save-ModuleSettings contains MaxStorageGB coerced to double 3.0' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = ''
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured  = $false
                        UsedGB        = 0.0
                        MaxGB         = 0.0
                        UsedPercent   = 0.0
                        LogFileSizeGB = 0.0
                    }
                }
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('C:\NewScreenshots')
                $tc.Input.PushTextWithEnter('3.0')
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-StorageInfoScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    [double]$Config.Screenshots.MaxStorageGB -eq 3.0
                }
            }
        }

        It 'Writes a success panel containing "saved" to the console' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = ''
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured  = $false
                        UsedGB        = 0.0
                        MaxGB         = 0.0
                        UsedPercent   = 0.0
                        LogFileSizeGB = 0.0
                    }
                }
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('C:\NewScreenshots')
                $tc.Input.PushTextWithEnter('3.0')
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-StorageInfoScreen -Console $tc

                $tc.Output | Should -Match 'saved'
            }
        }

        It 'Calls Write-LastWarLog with Level Info on successful save' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = ''
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured  = $false
                        UsedGB        = 0.0
                        MaxGB         = 0.0
                        UsedPercent   = 0.0
                        LogFileSizeGB = 0.0
                    }
                }
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('C:\NewScreenshots')
                $tc.Input.PushTextWithEnter('3.0')
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-StorageInfoScreen -Console $tc

                Should -Invoke Write-LastWarLog -Exactly 1 -ParameterFilter { $Level -eq 'Info' }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Invalid MaxStorageGB value entered (below minimum)
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user enters an invalid MaxStorageGB value (e.g. -1)' {

        It 'Does not throw when an invalid value is entered for MaxStorageGB' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = ''
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured  = $false
                        UsedGB        = 0.0
                        MaxGB         = 0.0
                        UsedPercent   = 0.0
                        LogFileSizeGB = 0.0
                    }
                }
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StoragePath: keep current
                $tc.Input.PushTextWithEnter('-1')            # MaxStorageGB: invalid (below Min=0.1)
                $tc.Input.PushKey([ConsoleKey]::Enter)       # MaxStorageGB: keep current (after error)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Discard changes

                { Show-StorageInfoScreen -Console $tc } | Should -Not -Throw
            }
        }

        It 'Validation error message appears in console output when -1 is entered for MaxStorageGB' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = ''
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured  = $false
                        UsedGB        = 0.0
                        MaxGB         = 0.0
                        UsedPercent   = 0.0
                        LogFileSizeGB = 0.0
                    }
                }
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushTextWithEnter('-1')
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-StorageInfoScreen -Console $tc

                # Test-ConfigValue returns "'Screenshots.MaxStorageGB' must be at least 0.1. Got: -1."
                $tc.Output | Should -Match 'at least 0\.1'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: User chooses Discard changes
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user chooses Discard changes' {

        It 'Does not call Save-ModuleSettings' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = ''
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured  = $false
                        UsedGB        = 0.0
                        MaxGB         = 0.0
                        UsedPercent   = 0.0
                        LogFileSizeGB = 0.0
                    }
                }
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)    # StoragePath: keep current
                $tc.Input.PushKey([ConsoleKey]::Enter)    # MaxStorageGB: keep current
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Discard changes

                Show-StorageInfoScreen -Console $tc

                Should -Not -Invoke Save-ModuleSettings
            }
        }

        It 'Writes a "No changes saved" panel to the console' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = ''
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured  = $false
                        UsedGB        = 0.0
                        MaxGB         = 0.0
                        UsedPercent   = 0.0
                        LogFileSizeGB = 0.0
                    }
                }
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-StorageInfoScreen -Console $tc

                $tc.Output | Should -Match 'No changes saved'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: User chooses Reset ALL Screenshots settings to defaults
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user chooses Reset ALL Screenshots settings to defaults' {

        It 'Calls Save-ModuleSettings exactly once' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\Custom\Screenshots'
                            MaxStorageGB = 5.0
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured  = $false
                        UsedGB        = 0.0
                        MaxGB         = 0.0
                        UsedPercent   = 0.0
                        LogFileSizeGB = 0.0
                    }
                }
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)    # StoragePath: keep current
                $tc.Input.PushKey([ConsoleKey]::Enter)    # MaxStorageGB: keep current
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Reset ALL Screenshots settings to defaults

                Show-StorageInfoScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1
            }
        }

        It 'The config passed to Save-ModuleSettings contains default StoragePath (empty string)' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\Custom\Screenshots'
                            MaxStorageGB = 5.0
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured  = $false
                        UsedGB        = 0.0
                        MaxGB         = 0.0
                        UsedPercent   = 0.0
                        LogFileSizeGB = 0.0
                    }
                }
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-StorageInfoScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.Screenshots.StoragePath -eq '' -and
                    [double]$Config.Screenshots.MaxStorageGB -eq 2.0
                }
            }
        }

        It 'Writes a success panel containing "Reset" to the console' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\Custom\Screenshots'
                            MaxStorageGB = 5.0
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured  = $false
                        UsedGB        = 0.0
                        MaxGB         = 0.0
                        UsedPercent   = 0.0
                        LogFileSizeGB = 0.0
                    }
                }
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-StorageInfoScreen -Console $tc

                $tc.Output | Should -Match 'Reset'
                $tc.Output | Should -Match '[Ss]aved'
            }
        }

        It 'Calls Write-LastWarLog with Level Info when Reset ALL is chosen' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\Custom\Screenshots'
                            MaxStorageGB = 5.0
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured  = $false
                        UsedGB        = 0.0
                        MaxGB         = 0.0
                        UsedPercent   = 0.0
                        LogFileSizeGB = 0.0
                    }
                }
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-StorageInfoScreen -Console $tc

                Should -Invoke Write-LastWarLog -Exactly 1 -ParameterFilter { $Level -eq 'Info' }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: [Reset to default] sentinel on an individual key
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user enters [Reset to default] for the StoragePath key' {

        It 'The saved config contains the default StoragePath value (empty string)' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\OldPath'
                            MaxStorageGB = 5.0
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured  = $false
                        UsedGB        = 0.0
                        MaxGB         = 0.0
                        UsedPercent   = 0.0
                        LogFileSizeGB = 0.0
                    }
                }
                Mock Save-ModuleSettings {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                # StoragePath: enter [Reset to default] sentinel - resets to '' (empty string default)
                $tc.Input.PushTextWithEnter('[Reset to default]')
                $tc.Input.PushKey([ConsoleKey]::Enter)    # MaxStorageGB: keep current
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Yes - save now

                Show-StorageInfoScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.Screenshots.StoragePath -eq ''
                }
            }
        }
    }
}
