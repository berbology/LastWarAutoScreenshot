BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force

    # Spectre.Console.Testing.dll ships in lib\test\ and is required for TestConsole
    $testingDll = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}

Describe 'Show-ScreenshotConfigScreen' -Tag 'Unit' {

    BeforeEach {
        InModuleScope -ModuleName 'LastWarAutoScreenshot' {
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    Screenshots = [PSCustomObject]@{
                        StoragePath                    = 'C:\Screenshots'
                        MaxStorageGB                   = 2.0
                        StorageWarningThresholdPercent = 90
                        FileFormat                     = 'PNG'
                        FilenamePattern                = '{MacroName}_{ActionName}_{Timestamp}_{Index}'
                        SimilarityCheck                = [PSCustomObject]@{
                            Enabled              = $false
                            Threshold            = 0.98
                            SampleCount          = 1000
                            FullScan             = $false
                            TolerancePerChannel  = 10
                            Action               = 'StopNestedMacro'
                            ConsecutiveThreshold = 1
                        }
                    }
                }
            }
            Mock Save-ModuleSettings {}
            Mock Write-LastWarLog {}
            Mock Resolve-ScreenshotFilename { 'my-macro_screenshot_20260101_120000_0001.png' }
            Mock Test-Path { $true }
            Mock New-Item {}
        }
    }

    # Helper: push the full default input sequence (all empty/keep + 'Yes - save now')
    # Input order matches the key definition order in Show-ScreenshotConfigScreen:
    #   1  StoragePath                      TextPrompt   Enter (empty → keep)
    #   2  MaxStorageGB                     TextPrompt   Enter (empty → keep)
    #   3  StorageWarningThresholdPercent   TextPrompt   Enter (empty → keep)
    #   4  FileFormat                       SelectPrompt Enter (first = 'PNG')
    #   5  FilenamePattern                  TextPrompt   Enter (empty → keep)
    #   6  SimilarityCheck.Enabled          ConfirmPrompt 'n' (keep false)
    #   7  SimilarityCheck.Threshold        TextPrompt   Enter (empty → keep)
    #   8  SimilarityCheck.SampleCount      TextPrompt   Enter (empty → keep)
    #   9  SimilarityCheck.FullScan         ConfirmPrompt 'n' (keep false)
    #  10  SimilarityCheck.TolerancePerChannel TextPrompt Enter (empty → keep)
    #  11  SimilarityCheck.Action           SelectPrompt Enter (first = StopNestedMacro display)
    #  12  SimilarityCheck.ConsecutiveThreshold TextPrompt Enter (empty → keep)
    #  13  Save prompt                      SelectPrompt Enter ('Yes - save now')

    # ════════════════════════════════════════════════════════════════════════
    # Context: Empty input keeps non-StoragePath values; Yes - save now persists
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user presses Enter for all keys and chooses Yes - save now' {

        It 'Calls Save-ModuleSettings exactly once' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StoragePath: keep
                $tc.Input.PushKey([ConsoleKey]::Enter)       # MaxStorageGB: keep
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StorageWarningThresholdPercent: keep
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FileFormat SelectionPrompt → PNG
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FilenamePattern: keep
                $tc.Input.PushTextWithEnter('n')             # SimilarityCheck.Enabled: keep false
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Threshold: keep
                $tc.Input.PushKey([ConsoleKey]::Enter)       # SampleCount: keep
                $tc.Input.PushTextWithEnter('n')             # FullScan: keep false
                $tc.Input.PushKey([ConsoleKey]::Enter)       # TolerancePerChannel: keep
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Action SelectionPrompt → StopNestedMacro
                $tc.Input.PushKey([ConsoleKey]::Enter)       # ConsecutiveThreshold: keep
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Save: 'Yes - save now' (first choice)

                Show-ScreenshotConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1
            }
        }

        It 'The config passed to Save-ModuleSettings retains FileFormat=PNG' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StoragePath
                $tc.Input.PushKey([ConsoleKey]::Enter)       # MaxStorageGB
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StorageWarningThresholdPercent
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FileFormat SelectionPrompt
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FilenamePattern
                $tc.Input.PushTextWithEnter('n')             # Enabled
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Threshold
                $tc.Input.PushKey([ConsoleKey]::Enter)       # SampleCount
                $tc.Input.PushTextWithEnter('n')             # FullScan
                $tc.Input.PushKey([ConsoleKey]::Enter)       # TolerancePerChannel
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Action
                $tc.Input.PushKey([ConsoleKey]::Enter)       # ConsecutiveThreshold
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Save

                Show-ScreenshotConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.Screenshots.FileFormat -eq 'PNG'
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: StoragePath invalid parent directory
    # ════════════════════════════════════════════════════════════════════════
    Context 'When StoragePath has a parent directory that does not exist' {

        It 'Console output contains Parent directory does not exist and prompt re-displays' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                # Test-Path returns false for the parent directory check
                Mock Test-Path { $false }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('C:\NonExistent\Screenshots')  # 1st StoragePath: invalid parent
                $tc.Input.PushKey([ConsoleKey]::Enter)                     # 2nd StoragePath: keep and break
                $tc.Input.PushKey([ConsoleKey]::Enter)       # MaxStorageGB
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StorageWarningThresholdPercent
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FileFormat
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FilenamePattern
                $tc.Input.PushTextWithEnter('n')             # Enabled
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Threshold
                $tc.Input.PushKey([ConsoleKey]::Enter)       # SampleCount
                $tc.Input.PushTextWithEnter('n')             # FullScan
                $tc.Input.PushKey([ConsoleKey]::Enter)       # TolerancePerChannel
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Action
                $tc.Input.PushKey([ConsoleKey]::Enter)       # ConsecutiveThreshold
                $tc.Input.PushKey([ConsoleKey]::DownArrow)   # Save: move to 'Discard changes'
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ScreenshotConfigScreen -Console $tc

                $tc.Output | Should -Match 'Parent directory does not exist'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: FileFormat info note displayed
    # ════════════════════════════════════════════════════════════════════════
    Context 'FileFormat info note' {

        It 'Console output contains Only PNG is supported' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StoragePath
                $tc.Input.PushKey([ConsoleKey]::Enter)       # MaxStorageGB
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StorageWarningThresholdPercent
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FileFormat SelectionPrompt
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FilenamePattern
                $tc.Input.PushTextWithEnter('n')             # Enabled
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Threshold
                $tc.Input.PushKey([ConsoleKey]::Enter)       # SampleCount
                $tc.Input.PushTextWithEnter('n')             # FullScan
                $tc.Input.PushKey([ConsoleKey]::Enter)       # TolerancePerChannel
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Action
                $tc.Input.PushKey([ConsoleKey]::Enter)       # ConsecutiveThreshold
                $tc.Input.PushKey([ConsoleKey]::DownArrow)   # Save: Discard
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ScreenshotConfigScreen -Console $tc

                $tc.Output | Should -Match 'Only PNG is supported'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: FilenamePattern example filename displayed
    # ════════════════════════════════════════════════════════════════════════
    Context 'FilenamePattern example filename' {

        It 'Console output contains the example filename returned by Resolve-ScreenshotFilename' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)                              # StoragePath
                $tc.Input.PushKey([ConsoleKey]::Enter)                              # MaxStorageGB
                $tc.Input.PushKey([ConsoleKey]::Enter)                              # StorageWarningThresholdPercent
                $tc.Input.PushKey([ConsoleKey]::Enter)                              # FileFormat
                $tc.Input.PushTextWithEnter('{MacroName}_{Timestamp}_{Index}')     # FilenamePattern: non-empty
                $tc.Input.PushTextWithEnter('n')                                    # Enabled
                $tc.Input.PushKey([ConsoleKey]::Enter)                              # Threshold
                $tc.Input.PushKey([ConsoleKey]::Enter)                              # SampleCount
                $tc.Input.PushTextWithEnter('n')                                    # FullScan
                $tc.Input.PushKey([ConsoleKey]::Enter)                              # TolerancePerChannel
                $tc.Input.PushKey([ConsoleKey]::Enter)                              # Action
                $tc.Input.PushKey([ConsoleKey]::Enter)                              # ConsecutiveThreshold
                $tc.Input.PushKey([ConsoleKey]::DownArrow)                          # Save: Discard
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ScreenshotConfigScreen -Console $tc

                $tc.Output | Should -Match 'my-macro_screenshot_20260101_120000_0001'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: FilenamePattern too long — error shown, prompt repeats
    # ════════════════════════════════════════════════════════════════════════
    Context 'When FilenamePattern resolves to null (pattern too long)' {

        It 'Console output contains error text and second input is accepted' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $script:_resolveCallCount = 0
                Mock Resolve-ScreenshotFilename {
                    $script:_resolveCallCount++
                    if ($script:_resolveCallCount -eq 1) {
                        return $null
                    }
                    return 'my-macro_screenshot_20260101_120000_0001.png'
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)                              # StoragePath
                $tc.Input.PushKey([ConsoleKey]::Enter)                              # MaxStorageGB
                $tc.Input.PushKey([ConsoleKey]::Enter)                              # StorageWarningThresholdPercent
                $tc.Input.PushKey([ConsoleKey]::Enter)                              # FileFormat
                $tc.Input.PushTextWithEnter('{MacroName}_{ActionName}_{Timestamp}_{Index}_too_long_pattern') # 1st: null
                $tc.Input.PushTextWithEnter('{MacroName}_{Timestamp}')              # 2nd: valid
                $tc.Input.PushTextWithEnter('n')                                    # Enabled
                $tc.Input.PushKey([ConsoleKey]::Enter)                              # Threshold
                $tc.Input.PushKey([ConsoleKey]::Enter)                              # SampleCount
                $tc.Input.PushTextWithEnter('n')                                    # FullScan
                $tc.Input.PushKey([ConsoleKey]::Enter)                              # TolerancePerChannel
                $tc.Input.PushKey([ConsoleKey]::Enter)                              # Action
                $tc.Input.PushKey([ConsoleKey]::Enter)                              # ConsecutiveThreshold
                $tc.Input.PushKey([ConsoleKey]::DownArrow)                          # Save: Discard
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ScreenshotConfigScreen -Console $tc

                $tc.Output | Should -Match 'exceeding 200 characters'
                Should -Invoke Resolve-ScreenshotFilename -Times 2
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: SimilarityCheck.Enabled set to yes — info note displayed
    # ════════════════════════════════════════════════════════════════════════
    Context 'When SimilarityCheck.Enabled is set to yes' {

        It 'Console output contains PNG format info note' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StoragePath
                $tc.Input.PushKey([ConsoleKey]::Enter)       # MaxStorageGB
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StorageWarningThresholdPercent
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FileFormat
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FilenamePattern
                $tc.Input.PushTextWithEnter('y')             # SimilarityCheck.Enabled: set to true
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Threshold
                $tc.Input.PushKey([ConsoleKey]::Enter)       # SampleCount
                $tc.Input.PushTextWithEnter('n')             # FullScan
                $tc.Input.PushKey([ConsoleKey]::Enter)       # TolerancePerChannel
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Action
                $tc.Input.PushKey([ConsoleKey]::Enter)       # ConsecutiveThreshold
                $tc.Input.PushKey([ConsoleKey]::DownArrow)   # Save: Discard
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ScreenshotConfigScreen -Console $tc

                $tc.Output | Should -Match 'PNG format'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: SimilarityCheck.FullScan enabled — warning displayed
    # ════════════════════════════════════════════════════════════════════════
    Context 'When SimilarityCheck.FullScan is set to yes' {

        It 'Console output contains may be slow warning' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StoragePath
                $tc.Input.PushKey([ConsoleKey]::Enter)       # MaxStorageGB
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StorageWarningThresholdPercent
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FileFormat
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FilenamePattern
                $tc.Input.PushTextWithEnter('n')             # Enabled
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Threshold
                $tc.Input.PushKey([ConsoleKey]::Enter)       # SampleCount
                $tc.Input.PushTextWithEnter('y')             # FullScan: set to true
                $tc.Input.PushKey([ConsoleKey]::Enter)       # TolerancePerChannel
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Action
                $tc.Input.PushKey([ConsoleKey]::Enter)       # ConsecutiveThreshold
                $tc.Input.PushKey([ConsoleKey]::DownArrow)   # Save: Discard
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ScreenshotConfigScreen -Console $tc

                $tc.Output | Should -Match 'may be slow'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: SimilarityCheck.Action display choice mapped to raw value
    # ════════════════════════════════════════════════════════════════════════
    Context 'When SimilarityCheck.Action StopNestedMacro display choice is selected' {

        It 'The saved config contains Action = StopNestedMacro (raw value, not display string)' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StoragePath
                $tc.Input.PushKey([ConsoleKey]::Enter)       # MaxStorageGB
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StorageWarningThresholdPercent
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FileFormat
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FilenamePattern
                $tc.Input.PushTextWithEnter('n')             # Enabled
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Threshold
                $tc.Input.PushKey([ConsoleKey]::Enter)       # SampleCount
                $tc.Input.PushTextWithEnter('n')             # FullScan
                $tc.Input.PushKey([ConsoleKey]::Enter)       # TolerancePerChannel
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Action: Enter → first = StopNestedMacro
                $tc.Input.PushKey([ConsoleKey]::Enter)       # ConsecutiveThreshold
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Save: 'Yes - save now'

                Show-ScreenshotConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.Screenshots.SimilarityCheck.Action -eq 'StopNestedMacro'
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: SimilarityCheck.ConsecutiveThreshold saved correctly
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user enters 3 for ConsecutiveThreshold' {

        It 'The saved config contains ConsecutiveThreshold = 3' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StoragePath
                $tc.Input.PushKey([ConsoleKey]::Enter)       # MaxStorageGB
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StorageWarningThresholdPercent
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FileFormat
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FilenamePattern
                $tc.Input.PushTextWithEnter('n')             # Enabled
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Threshold
                $tc.Input.PushKey([ConsoleKey]::Enter)       # SampleCount
                $tc.Input.PushTextWithEnter('n')             # FullScan
                $tc.Input.PushKey([ConsoleKey]::Enter)       # TolerancePerChannel
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Action
                $tc.Input.PushTextWithEnter('3')             # ConsecutiveThreshold: set to 3
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Save: 'Yes - save now'

                Show-ScreenshotConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.Screenshots.SimilarityCheck.ConsecutiveThreshold -eq 3
                }
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Reset ALL Screenshot settings to defaults
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user chooses Reset ALL Screenshot settings to defaults at the save prompt' {

        It 'Calls Save-ModuleSettings exactly once' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StoragePath
                $tc.Input.PushKey([ConsoleKey]::Enter)       # MaxStorageGB
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StorageWarningThresholdPercent
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FileFormat
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FilenamePattern
                $tc.Input.PushTextWithEnter('n')             # Enabled
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Threshold
                $tc.Input.PushKey([ConsoleKey]::Enter)       # SampleCount
                $tc.Input.PushTextWithEnter('n')             # FullScan
                $tc.Input.PushKey([ConsoleKey]::Enter)       # TolerancePerChannel
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Action
                $tc.Input.PushKey([ConsoleKey]::Enter)       # ConsecutiveThreshold
                $tc.Input.PushKey([ConsoleKey]::DownArrow)   # Save: 'Reset ALL...' (second choice)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ScreenshotConfigScreen -Console $tc

                Should -Invoke Save-ModuleSettings -Exactly 1
            }
        }

        It 'The config passed to Save-ModuleSettings has default ConsecutiveThreshold=1 and Action=StopNestedMacro' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                # Start with non-default values to confirm they are overwritten
                Mock Get-ModuleConfiguration {
                    [PSCustomObject]@{
                        Screenshots = [PSCustomObject]@{
                            StoragePath                    = 'C:\Screenshots'
                            MaxStorageGB                   = 99.0
                            StorageWarningThresholdPercent = 50
                            FileFormat                     = 'PNG'
                            FilenamePattern                = '{MacroName}'
                            SimilarityCheck                = [PSCustomObject]@{
                                Enabled              = $true
                                Threshold            = 0.50
                                SampleCount          = 500
                                FullScan             = $true
                                TolerancePerChannel  = 50
                                Action               = 'Warn'
                                ConsecutiveThreshold = 5
                            }
                        }
                    }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StoragePath
                $tc.Input.PushKey([ConsoleKey]::Enter)       # MaxStorageGB
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StorageWarningThresholdPercent
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FileFormat
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FilenamePattern
                $tc.Input.PushTextWithEnter('y')             # Enabled: true (non-default)
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Threshold
                $tc.Input.PushKey([ConsoleKey]::Enter)       # SampleCount
                $tc.Input.PushTextWithEnter('y')             # FullScan: true (non-default)
                $tc.Input.PushKey([ConsoleKey]::Enter)       # TolerancePerChannel
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Action
                $tc.Input.PushTextWithEnter('5')             # ConsecutiveThreshold: 5 (non-default)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)   # Save: 'Reset ALL...' (second choice)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ScreenshotConfigScreen -Console $tc

                # Reset ALL replaces $config.Screenshots with defaults; verify key default values
                Should -Invoke Save-ModuleSettings -Exactly 1 -ParameterFilter {
                    $Config.Screenshots.SimilarityCheck.ConsecutiveThreshold -eq 1 -and
                    $Config.Screenshots.SimilarityCheck.Action -eq 'StopNestedMacro'
                }
            }
        }

        It 'Writes a panel containing reset to the console' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StoragePath
                $tc.Input.PushKey([ConsoleKey]::Enter)       # MaxStorageGB
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StorageWarningThresholdPercent
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FileFormat
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FilenamePattern
                $tc.Input.PushTextWithEnter('n')             # Enabled
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Threshold
                $tc.Input.PushKey([ConsoleKey]::Enter)       # SampleCount
                $tc.Input.PushTextWithEnter('n')             # FullScan
                $tc.Input.PushKey([ConsoleKey]::Enter)       # TolerancePerChannel
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Action
                $tc.Input.PushKey([ConsoleKey]::Enter)       # ConsecutiveThreshold
                $tc.Input.PushKey([ConsoleKey]::DownArrow)   # Save: 'Reset ALL...'
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ScreenshotConfigScreen -Console $tc

                $tc.Output | Should -Match 'reset'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Discard changes does not call Save-ModuleSettings
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user chooses Discard changes' {

        It 'Does not call Save-ModuleSettings' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StoragePath
                $tc.Input.PushKey([ConsoleKey]::Enter)       # MaxStorageGB
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StorageWarningThresholdPercent
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FileFormat
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FilenamePattern
                $tc.Input.PushTextWithEnter('n')             # Enabled
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Threshold
                $tc.Input.PushKey([ConsoleKey]::Enter)       # SampleCount
                $tc.Input.PushTextWithEnter('n')             # FullScan
                $tc.Input.PushKey([ConsoleKey]::Enter)       # TolerancePerChannel
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Action
                $tc.Input.PushKey([ConsoleKey]::Enter)       # ConsecutiveThreshold
                $tc.Input.PushKey([ConsoleKey]::DownArrow)   # Save: 'Discard changes' (third choice)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ScreenshotConfigScreen -Console $tc

                Should -Not -Invoke Save-ModuleSettings
            }
        }

        It 'Writes a No changes saved panel to the console' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StoragePath
                $tc.Input.PushKey([ConsoleKey]::Enter)       # MaxStorageGB
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StorageWarningThresholdPercent
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FileFormat
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FilenamePattern
                $tc.Input.PushTextWithEnter('n')             # Enabled
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Threshold
                $tc.Input.PushKey([ConsoleKey]::Enter)       # SampleCount
                $tc.Input.PushTextWithEnter('n')             # FullScan
                $tc.Input.PushKey([ConsoleKey]::Enter)       # TolerancePerChannel
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Action
                $tc.Input.PushKey([ConsoleKey]::Enter)       # ConsecutiveThreshold
                $tc.Input.PushKey([ConsoleKey]::DownArrow)   # Save: Discard
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ScreenshotConfigScreen -Console $tc

                $tc.Output | Should -Match 'No changes saved'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Relative path is rejected
    # ════════════════════════════════════════════════════════════════════════
    Context 'When StoragePath input is a relative path' {

        It 'Console output contains full file path error and prompt re-displays' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('MyFolder')          # 1st StoragePath: relative → error, re-prompt
                $tc.Input.PushKey([ConsoleKey]::Enter)           # 2nd StoragePath: keep and break
                $tc.Input.PushKey([ConsoleKey]::Enter)           # MaxStorageGB
                $tc.Input.PushKey([ConsoleKey]::Enter)           # StorageWarningThresholdPercent
                $tc.Input.PushKey([ConsoleKey]::Enter)           # FileFormat
                $tc.Input.PushKey([ConsoleKey]::Enter)           # FilenamePattern
                $tc.Input.PushTextWithEnter('n')                 # Enabled
                $tc.Input.PushKey([ConsoleKey]::Enter)           # Threshold
                $tc.Input.PushKey([ConsoleKey]::Enter)           # SampleCount
                $tc.Input.PushTextWithEnter('n')                 # FullScan
                $tc.Input.PushKey([ConsoleKey]::Enter)           # TolerancePerChannel
                $tc.Input.PushKey([ConsoleKey]::Enter)           # Action
                $tc.Input.PushKey([ConsoleKey]::Enter)           # ConsecutiveThreshold
                $tc.Input.PushKey([ConsoleKey]::DownArrow)       # Save: Discard changes
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ScreenshotConfigScreen -Console $tc

                $tc.Output | Should -Match 'full file path'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Directory creation when StoragePath does not exist
    # ════════════════════════════════════════════════════════════════════════
    Context 'When saving with a non-empty StoragePath that does not exist on disk' {

        It 'Calls New-Item to create the directory' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                # Mock Test-Path: returns false when -PathType is specified (directory check),
                # returns true otherwise (parent directory validation)
                Mock Test-Path {
                    if ($null -ne $PathType) {
                        return $false
                    }
                    return $true
                }
                Mock New-Item {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushTextWithEnter('C:\Screenshots')    # StoragePath: absolute path
                $tc.Input.PushKey([ConsoleKey]::Enter)           # MaxStorageGB
                $tc.Input.PushKey([ConsoleKey]::Enter)           # StorageWarningThresholdPercent
                $tc.Input.PushKey([ConsoleKey]::Enter)           # FileFormat
                $tc.Input.PushKey([ConsoleKey]::Enter)           # FilenamePattern
                $tc.Input.PushTextWithEnter('n')                 # Enabled
                $tc.Input.PushKey([ConsoleKey]::Enter)           # Threshold
                $tc.Input.PushKey([ConsoleKey]::Enter)           # SampleCount
                $tc.Input.PushTextWithEnter('n')                 # FullScan
                $tc.Input.PushKey([ConsoleKey]::Enter)           # TolerancePerChannel
                $tc.Input.PushKey([ConsoleKey]::Enter)           # Action
                $tc.Input.PushKey([ConsoleKey]::Enter)           # ConsecutiveThreshold
                $tc.Input.PushKey([ConsoleKey]::Enter)           # Save: 'Yes - save now'

                Show-ScreenshotConfigScreen -Console $tc

                Should -Invoke New-Item -Times 1
            }
        }

        It 'Does not call New-Item when the screenshot directory already exists' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                # Mock Test-Path to return true for all checks (parent exists, directory exists)
                Mock Test-Path { $true }
                Mock New-Item {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)           # StoragePath: keep
                $tc.Input.PushKey([ConsoleKey]::Enter)           # MaxStorageGB
                $tc.Input.PushKey([ConsoleKey]::Enter)           # StorageWarningThresholdPercent
                $tc.Input.PushKey([ConsoleKey]::Enter)           # FileFormat
                $tc.Input.PushKey([ConsoleKey]::Enter)           # FilenamePattern
                $tc.Input.PushTextWithEnter('n')                 # Enabled
                $tc.Input.PushKey([ConsoleKey]::Enter)           # Threshold
                $tc.Input.PushKey([ConsoleKey]::Enter)           # SampleCount
                $tc.Input.PushTextWithEnter('n')                 # FullScan
                $tc.Input.PushKey([ConsoleKey]::Enter)           # TolerancePerChannel
                $tc.Input.PushKey([ConsoleKey]::Enter)           # Action
                $tc.Input.PushKey([ConsoleKey]::Enter)           # ConsecutiveThreshold
                $tc.Input.PushKey([ConsoleKey]::Enter)           # Save: 'Yes - save now'

                Show-ScreenshotConfigScreen -Console $tc

                Should -Not -Invoke New-Item
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Function contract
    # ════════════════════════════════════════════════════════════════════════
    Context 'Function contract' {

        It 'Does not throw under normal conditions' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StoragePath
                $tc.Input.PushKey([ConsoleKey]::Enter)       # MaxStorageGB
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StorageWarningThresholdPercent
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FileFormat
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FilenamePattern
                $tc.Input.PushTextWithEnter('n')             # Enabled
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Threshold
                $tc.Input.PushKey([ConsoleKey]::Enter)       # SampleCount
                $tc.Input.PushTextWithEnter('n')             # FullScan
                $tc.Input.PushKey([ConsoleKey]::Enter)       # TolerancePerChannel
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Action
                $tc.Input.PushKey([ConsoleKey]::Enter)       # ConsecutiveThreshold
                $tc.Input.PushKey([ConsoleKey]::DownArrow)   # Save: Discard
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                { Show-ScreenshotConfigScreen -Console $tc } | Should -Not -Throw
            }
        }

        It 'Calls Get-ModuleConfiguration exactly once to load current settings' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StoragePath
                $tc.Input.PushKey([ConsoleKey]::Enter)       # MaxStorageGB
                $tc.Input.PushKey([ConsoleKey]::Enter)       # StorageWarningThresholdPercent
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FileFormat
                $tc.Input.PushKey([ConsoleKey]::Enter)       # FilenamePattern
                $tc.Input.PushTextWithEnter('n')             # Enabled
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Threshold
                $tc.Input.PushKey([ConsoleKey]::Enter)       # SampleCount
                $tc.Input.PushTextWithEnter('n')             # FullScan
                $tc.Input.PushKey([ConsoleKey]::Enter)       # TolerancePerChannel
                $tc.Input.PushKey([ConsoleKey]::Enter)       # Action
                $tc.Input.PushKey([ConsoleKey]::Enter)       # ConsecutiveThreshold
                $tc.Input.PushKey([ConsoleKey]::DownArrow)   # Save: Discard
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-ScreenshotConfigScreen -Console $tc

                Should -Invoke Get-ModuleConfiguration -Exactly 1
            }
        }
    }
}
