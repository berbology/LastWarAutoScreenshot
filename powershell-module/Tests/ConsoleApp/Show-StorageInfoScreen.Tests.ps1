# Show-StorageInfoScreen.Tests.ps1
# Pester v5 tests for the Show-StorageInfoScreen private function.
#
# Show-StorageInfoScreen is a read-only view + navigation screen.  It shows storage
# status (info panel when not configured, chart/table/warning panels when configured)
# and presents a SelectionPrompt with Back / Configure screenshot settings /
# Open storage folder in Explorer.  It does NOT contain editing prompts, save logic,
# or validation.  Those live in Show-ScreenshotConfigScreen.

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
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Nav prompt: select [[Back]]

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
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Nav prompt: select [[Back]]

                Show-StorageInfoScreen -Console $tc

                $tc.Output | Should -Match 'not yet configured'
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
                        IsConfigured    = $true
                        UsedGB          = 1.9
                        MaxGB           = 2.0
                        UsedPercent     = 95.0
                        LogFileSizeGB   = 0.05
                        DiskFreeGB      = 50.0
                        DiskTotalGB     = 500.0
                        ScreenshotCount = 0
                    }
                }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Nav prompt: select [[Back]]

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
                        IsConfigured    = $true
                        UsedGB          = 1.9
                        MaxGB           = 2.0
                        UsedPercent     = 95.0
                        LogFileSizeGB   = 0.05
                        DiskFreeGB      = 50.0
                        DiskTotalGB     = 500.0
                        ScreenshotCount = 0
                    }
                }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Nav prompt: select [[Back]]

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
                        IsConfigured    = $true
                        UsedGB          = 1.0
                        MaxGB           = 2.0
                        UsedPercent     = 50.0
                        LogFileSizeGB   = 0.01
                        DiskFreeGB      = 50.0
                        DiskTotalGB     = 500.0
                        ScreenshotCount = 0
                    }
                }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Nav prompt: select [[Back]]

                Show-StorageInfoScreen -Console $tc

                $tc.Output | Should -Not -Match 'over 90'
            }
        }
    }
}
