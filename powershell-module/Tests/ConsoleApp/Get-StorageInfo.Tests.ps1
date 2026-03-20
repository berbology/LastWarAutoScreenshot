# Get-StorageInfo.Tests.ps1
# Pester v5 tests for the Get-StorageInfo private function.

BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; navigate up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Get-StorageInfo' -Tag 'Unit' {

    # ════════════════════════════════════════════════════════════════════════
    # Context: StoragePath is empty string (not yet configured)
    # ════════════════════════════════════════════════════════════════════════
    Context 'When Screenshots.StoragePath is an empty string (not yet configured)' {

        It 'Returns IsConfigured=$false and zero values for all numeric properties' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = ''
                            MaxStorageGB = 2.0
                        }
                    }
                }

                $result = Get-StorageInfo
                $result.IsConfigured  | Should -BeFalse
                $result.UsedGB        | Should -Be 0.0
                $result.MaxGB         | Should -Be 0.0
                $result.UsedPercent   | Should -Be 0.0
                $result.LogFileSizeGB | Should -Be 0.0
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: StoragePath is $null (defensive null handling)
    # ════════════════════════════════════════════════════════════════════════
    Context 'When Screenshots.StoragePath is $null (defensive null handling)' {

        It 'Returns IsConfigured=$false without throwing' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = $null
                            MaxStorageGB = 2.0
                        }
                    }
                }

                { Get-StorageInfo | Out-Null } | Should -Not -Throw
            }
        }

        It 'Returns IsConfigured=$false when StoragePath is $null' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = $null
                            MaxStorageGB = 2.0
                        }
                    }
                }

                $result = Get-StorageInfo
                $result.IsConfigured | Should -BeFalse
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: StoragePath is set but the path does not exist on disk
    # ════════════════════════════════════════════════════════════════════════
    Context 'When Screenshots.StoragePath is set but the directory does not exist' {

        It 'Returns IsConfigured=$false' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\NonExistent\Screenshots'
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Test-Path { $false }

                $result = Get-StorageInfo
                $result.IsConfigured | Should -BeFalse
            }
        }

        It 'Does not call Get-ChildItem when the path does not exist' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\NonExistent\Screenshots'
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Test-Path { $false }
                Mock Get-ChildItem {}

                Get-StorageInfo | Out-Null
                Should -Not -Invoke Get-ChildItem -ParameterFilter { $Recurse -eq $true }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: StoragePath exists and contains files of known sizes
    # ════════════════════════════════════════════════════════════════════════
    Context 'When StoragePath exists and contains files with known total size of 1.5 GB' {

        It 'Returns IsConfigured=$true' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\Screenshots'
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Test-Path { $true }
                Mock Get-ChildItem {
                    @([PSCustomObject]@{ Length = [long]52428800 })
                } -ParameterFilter { $Filter -eq 'LastWarAutoScreenshot.log*' }
                Mock Get-ChildItem {
                    @(
                        [PSCustomObject]@{ Length = [long]1073741824 },
                        [PSCustomObject]@{ Length = [long]536870912  }
                    )
                } -ParameterFilter { $Recurse -eq $true }

                $result = Get-StorageInfo
                $result.IsConfigured | Should -BeTrue
            }
        }

        It 'Calculates UsedGB correctly as 1.5 for 1.5 GiB of screenshot files' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\Screenshots'
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Test-Path { $true }
                Mock Get-ChildItem { @() } -ParameterFilter { $Filter -eq 'LastWarAutoScreenshot.log*' }
                Mock Get-ChildItem {
                    @(
                        [PSCustomObject]@{ Length = [long]1073741824 },
                        [PSCustomObject]@{ Length = [long]536870912  }
                    )
                } -ParameterFilter { $Recurse -eq $true }

                $result = Get-StorageInfo
                $result.UsedGB | Should -Be 1.5
            }
        }

        It 'Populates MaxGB from the configured MaxStorageGB value' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\Screenshots'
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Test-Path { $true }
                Mock Get-ChildItem { @() } -ParameterFilter { $Filter -eq 'LastWarAutoScreenshot.log*' }
                Mock Get-ChildItem {
                    @([PSCustomObject]@{ Length = [long]1073741824 })
                } -ParameterFilter { $Recurse -eq $true }

                $result = Get-StorageInfo
                $result.MaxGB | Should -Be 2.0
            }
        }

        It 'Calculates UsedPercent correctly as 75.0 for 1.5 GB used of 2.0 GB max' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\Screenshots'
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Test-Path { $true }
                Mock Get-ChildItem { @() } -ParameterFilter { $Filter -eq 'LastWarAutoScreenshot.log*' }
                Mock Get-ChildItem {
                    @(
                        [PSCustomObject]@{ Length = [long]1073741824 },
                        [PSCustomObject]@{ Length = [long]536870912  }
                    )
                } -ParameterFilter { $Recurse -eq $true }

                $result = Get-StorageInfo
                $result.UsedPercent | Should -Be 75.0
            }
        }

        It 'Calculates LogFileSizeGB from log files in the module root' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                # 52428800 bytes = 50 MiB = ~0.04883 GB
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\Screenshots'
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Test-Path { $true }
                Mock Get-ChildItem {
                    @([PSCustomObject]@{ Length = [long]52428800 })
                } -ParameterFilter { $Filter -eq 'LastWarAutoScreenshot.log*' }
                Mock Get-ChildItem {
                    @([PSCustomObject]@{ Length = [long]1073741824 })
                } -ParameterFilter { $Recurse -eq $true }

                $result = Get-StorageInfo
                # 52428800 / 1073741824 = 0.048828125 exactly (25/512)
                $result.LogFileSizeGB | Should -Be ([double]52428800 / 1GB)
            }
        }

        It 'Returns LogFileSizeGB of 0.0 when no log files are present' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\Screenshots'
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Test-Path { $true }
                Mock Get-ChildItem { @() } -ParameterFilter { $Filter -eq 'LastWarAutoScreenshot.log*' }
                Mock Get-ChildItem {
                    @([PSCustomObject]@{ Length = [long]1073741824 })
                } -ParameterFilter { $Recurse -eq $true }

                $result = Get-StorageInfo
                $result.LogFileSizeGB | Should -Be 0.0
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Storage path exists but access is denied
    # ════════════════════════════════════════════════════════════════════════
    Context 'When StoragePath exists but access is denied (UnauthorizedAccessException)' {

        It 'Returns IsConfigured=$false' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\Screenshots'
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Test-Path { $true }
                Mock Get-ChildItem { @() } -ParameterFilter { $Filter -eq 'LastWarAutoScreenshot.log*' }
                Mock Get-ChildItem {
                    throw [System.UnauthorizedAccessException]::new('Access to the path is denied.')
                } -ParameterFilter { $Recurse -eq $true }
                Mock Write-LastWarLog {}

                $result = Get-StorageInfo
                $result.IsConfigured | Should -BeFalse
            }
        }

        It 'Does not throw an unhandled exception when access is denied' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\Screenshots'
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Test-Path { $true }
                Mock Get-ChildItem { @() } -ParameterFilter { $Filter -eq 'LastWarAutoScreenshot.log*' }
                Mock Get-ChildItem {
                    throw [System.UnauthorizedAccessException]::new('Access to the path is denied.')
                } -ParameterFilter { $Recurse -eq $true }
                Mock Write-LastWarLog {}

                { Get-StorageInfo } | Should -Not -Throw
            }
        }

        It 'Calls Write-LastWarLog with Level=Error when access is denied' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = 'C:\Screenshots'
                            MaxStorageGB = 2.0
                        }
                    }
                }
                Mock Test-Path { $true }
                Mock Get-ChildItem { @() } -ParameterFilter { $Filter -eq 'LastWarAutoScreenshot.log*' }
                Mock Get-ChildItem {
                    throw [System.UnauthorizedAccessException]::new('Access to the path is denied.')
                } -ParameterFilter { $Recurse -eq $true }
                Mock Write-LastWarLog {}

                Get-StorageInfo | Out-Null
                Should -Invoke Write-LastWarLog -Exactly 1 -ParameterFilter { $Level -eq 'Error' }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Output object shape
    # ════════════════════════════════════════════════════════════════════════
    Context 'Output shape' {

        It 'Returns an object with all required properties' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = ''
                            MaxStorageGB = 2.0
                        }
                    }
                }

                $result = Get-StorageInfo
                $result.PSObject.Properties.Name | Should -Contain 'IsConfigured'
                $result.PSObject.Properties.Name | Should -Contain 'UsedGB'
                $result.PSObject.Properties.Name | Should -Contain 'MaxGB'
                $result.PSObject.Properties.Name | Should -Contain 'UsedPercent'
                $result.PSObject.Properties.Name | Should -Contain 'LogFileSizeGB'
                $result.PSObject.Properties.Name | Should -Contain 'DiskFreeGB'
                $result.PSObject.Properties.Name | Should -Contain 'DiskTotalGB'
                $result.PSObject.Properties.Name | Should -Contain 'ScreenshotCount'
                $result.PSObject.Properties.Name | Should -Contain 'OldestScreenshotDate'
                $result.PSObject.Properties.Name | Should -Contain 'NewestScreenshotDate'
            }
        }

        It 'Returns exactly ten properties (no unexpected extras)' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = ''
                            MaxStorageGB = 2.0
                        }
                    }
                }

                $result = Get-StorageInfo
                @($result.PSObject.Properties).Count | Should -Be 10
            }
        }

        It 'IsConfigured property is of type bool' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath  = ''
                            MaxStorageGB = 2.0
                        }
                    }
                }

                $result = Get-StorageInfo
                $result.IsConfigured | Should -BeOfType [bool]
            }
        }
    }
}
