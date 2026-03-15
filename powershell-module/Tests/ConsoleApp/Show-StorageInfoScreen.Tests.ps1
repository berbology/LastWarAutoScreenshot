# Show-StorageInfoScreen.Tests.ps1
# Pester v5 tests for the Show-StorageInfoScreen private function.
#
# Show-StorageInfoScreen is a read-only view screen divided into two sections:
#   Section 1 — Screenshot Storage: info panel (not configured) or chart/table/warnings (configured)
#   Section 2 — Log Files: log size table when Logging.Backend includes File, or EventLog info panel
# Navigation offers [[Back]] always, 'Open log folder in Explorer' when Logging.Backend includes File,
# and 'Open screenshot folder in Explorer' when configured.

BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force

    # Spectre.Console.Testing.dll ships in lib\test\ and is required for TestConsole
    $testingDll = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll

}

Describe 'Show-StorageInfoScreen' -Tag 'Unit' {

    BeforeEach {
        # Create a fresh TestConsole for each test to prevent output accumulation.
        # Width/height are set from module-scope variables defined in LastWarAutoScreenshot.psm1.
        InModuleScope 'LastWarAutoScreenshot' {
            $script:tc = [Spectre.Console.Testing.TestConsole]::new()
            $script:tc.Profile.Width  = $script:TestConsoleWidth
            $script:tc.Profile.Height = $script:TestConsoleHeight
            $script:tc.Profile.Capabilities.Interactive = $true
        }
    }

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
                        Logging = [PSCustomObject]@{
                            Backend = 'EventLog'
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

                $tc = $script:tc
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
                        Logging = [PSCustomObject]@{
                            Backend = 'EventLog'
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

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Nav prompt: select [[Back]]

                Show-StorageInfoScreen -Console $tc

                $tc.Output | Should -Match 'not yet configured'
            }
        }

        It 'Shows the Screenshot Storage section heading in the not-configured panel' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = ''
                            MaxStorageGB = 2.0
                        }
                        Logging = [PSCustomObject]@{
                            Backend = 'EventLog'
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

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Nav prompt: select [[Back]]

                Show-StorageInfoScreen -Console $tc

                $tc.Output | Should -Match 'Screenshot Storage'
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
                        Logging = [PSCustomObject]@{
                            Backend = 'EventLog'
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

                $tc = $script:tc
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
                        Logging = [PSCustomObject]@{
                            Backend = 'EventLog'
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

                $tc = $script:tc
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
                        Logging = [PSCustomObject]@{
                            Backend = 'EventLog'
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

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Nav prompt: select [[Back]]

                Show-StorageInfoScreen -Console $tc

                $tc.Output | Should -Not -Match 'over 90'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Logging.Backend is EventLog only
    # ════════════════════════════════════════════════════════════════════════
    Context 'When Logging.Backend is EventLog only' {

        It 'Shows the Event log info panel in the Log Files section' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = ''
                            MaxStorageGB = 2.0
                        }
                        Logging = [PSCustomObject]@{
                            Backend = 'EventLog'
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

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Nav prompt: select [[Back]]

                Show-StorageInfoScreen -Console $tc

                $tc.Output | Should -Match 'Event log'
            }
        }

        It 'Does not show log file size row when Logging.Backend is EventLog only' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = ''
                            MaxStorageGB = 2.0
                        }
                        Logging = [PSCustomObject]@{
                            Backend = 'EventLog'
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

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Nav prompt: select [[Back]]

                Show-StorageInfoScreen -Console $tc

                $tc.Output | Should -Not -Match 'Log Files GB'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Logging.Backend includes File
    # ════════════════════════════════════════════════════════════════════════
    Context 'When Logging.Backend includes File' {

        It 'Shows the log file size row in the Log Files section' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\Screenshots'
                            MaxStorageGB = 2.0
                        }
                        Logging = [PSCustomObject]@{
                            Backend = 'File'
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured    = $true
                        UsedGB          = 0.5
                        MaxGB           = 2.0
                        UsedPercent     = 25.0
                        LogFileSizeGB   = 0.012
                        DiskFreeGB      = 100.0
                        DiskTotalGB     = 500.0
                        ScreenshotCount = 3
                        OldestScreenshotDate = [datetime]::new(2026, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc)
                        NewestScreenshotDate = [datetime]::new(2026, 3, 1, 0, 0, 0, [System.DateTimeKind]::Utc)
                    }
                }
                Mock Write-LastWarLog {}

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Nav prompt: select [[Back]]

                Show-StorageInfoScreen -Console $tc

                $tc.Output | Should -Match 'Log Files GB'
            }
        }

        It 'Shows disk space row in the Log Files section when backend includes File' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\Screenshots'
                            MaxStorageGB = 2.0
                        }
                        Logging = [PSCustomObject]@{
                            Backend = 'File'
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured    = $true
                        UsedGB          = 0.5
                        MaxGB           = 2.0
                        UsedPercent     = 25.0
                        LogFileSizeGB   = 0.012
                        DiskFreeGB      = 100.0
                        DiskTotalGB     = 500.0
                        ScreenshotCount = 0
                    }
                }
                Mock Write-LastWarLog {}

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Nav prompt: select [[Back]]

                Show-StorageInfoScreen -Console $tc

                $tc.Output | Should -Match 'Disk space'
            }
        }

        It 'Does not show the Event log info panel when backend includes File' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\Screenshots'
                            MaxStorageGB = 2.0
                        }
                        Logging = [PSCustomObject]@{
                            Backend = 'File'
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured    = $true
                        UsedGB          = 0.5
                        MaxGB           = 2.0
                        UsedPercent     = 25.0
                        LogFileSizeGB   = 0.012
                        DiskFreeGB      = 100.0
                        DiskTotalGB     = 500.0
                        ScreenshotCount = 0
                    }
                }
                Mock Write-LastWarLog {}

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Nav prompt: select [[Back]]

                Show-StorageInfoScreen -Console $tc

                $tc.Output | Should -Not -Match 'Event log backend is active'
            }
        }

        It 'Shows the Open log folder in Explorer choice in the nav prompt when backend includes File' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\Screenshots'
                            MaxStorageGB = 2.0
                        }
                        Logging = [PSCustomObject]@{
                            Backend = 'File'
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured    = $true
                        UsedGB          = 0.5
                        MaxGB           = 2.0
                        UsedPercent     = 25.0
                        LogFileSizeGB   = 0.012
                        DiskFreeGB      = 100.0
                        DiskTotalGB     = 500.0
                        ScreenshotCount = 0
                    }
                }
                Mock Write-LastWarLog {}

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Nav prompt: select [[Back]]

                Show-StorageInfoScreen -Console $tc

                $tc.Output | Should -Match 'Open log folder in Explorer'
            }
        }

        It 'Does not show the Open log folder in Explorer choice when backend is EventLog only' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = ''
                            MaxStorageGB = 2.0
                        }
                        Logging = [PSCustomObject]@{
                            Backend = 'EventLog'
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

                $tc = $script:tc
                $tc.Input.PushKey([ConsoleKey]::Enter)    # Nav prompt: select [[Back]]

                Show-StorageInfoScreen -Console $tc

                $tc.Output | Should -Not -Match 'Open log folder in Explorer'
            }
        }

        It 'Invokes Start-Process for explorer.exe with ModuleRootPath when Open log folder in Explorer is selected' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\Screenshots'
                            MaxStorageGB = 2.0
                        }
                        Logging = [PSCustomObject]@{
                            Backend = 'File'
                        }
                    }
                }
                Mock Get-StorageInfo {
                    [PSCustomObject]@{
                        IsConfigured    = $true
                        UsedGB          = 0.5
                        MaxGB           = 2.0
                        UsedPercent     = 25.0
                        LogFileSizeGB   = 0.012
                        DiskFreeGB      = 100.0
                        DiskTotalGB     = 500.0
                        ScreenshotCount = 0
                    }
                }
                Mock Write-LastWarLog {}
                Mock Start-Process {}

                $tc = $script:tc
                # The nav prompt order is: [Back], Open log folder in Explorer, Open screenshot folder in Explorer
                # Press Down to move to 'Open log folder in Explorer', then Enter to select it
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-StorageInfoScreen -Console $tc

                Should -Invoke Start-Process -Times 1 -ParameterFilter {
                    $FilePath -eq 'explorer.exe' -and $ArgumentList -eq $script:ModuleRootPath
                }
            }
        }
    }
}
