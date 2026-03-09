BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force

    # Spectre.Console.Testing.dll is required for TestConsole
    $testingDll = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}

Describe 'Invoke-StartupConfigValidation' -Tag 'Unit' {

    Context 'When the config file does not exist (Get-ModuleConfiguration returns defaults)' {

        It 'Returns HasErrors=$false when all defaults are valid' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{
                        Logging       = [PSCustomObject]@{ MinimumLogLevel = 'Info' }
                        MouseControl  = [PSCustomObject]@{ OvershootFactor = 0.5 }
                        EmergencyStop = [PSCustomObject]@{ PollIntervalMs = 100 }
                    }
                }
                Mock Test-ConfigValue -MockWith { [PSCustomObject]@{ Valid = $true; Message = '' } }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $result = Invoke-StartupConfigValidation -Console $tc
                $result.HasErrors | Should -BeFalse
            }
        }

        It 'Returns an empty Messages array when all defaults are valid' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{
                        Logging       = [PSCustomObject]@{ MinimumLogLevel = 'Info' }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Test-ConfigValue -MockWith { [PSCustomObject]@{ Valid = $true; Message = '' } }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $result = Invoke-StartupConfigValidation -Console $tc
                $result.Messages.Count | Should -Be 0
            }
        }

        It 'Writes nothing to the Console output when all values are valid' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{
                        Logging       = [PSCustomObject]@{ MinimumLogLevel = 'Info' }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Test-ConfigValue -MockWith { [PSCustomObject]@{ Valid = $true; Message = '' } }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                Invoke-StartupConfigValidation -Console $tc | Out-Null
                $tc.Output | Should -BeNullOrEmpty
            }
        }
    }

    Context 'When the config file exists and all values are valid' {

        It 'Returns HasErrors=$false' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{
                        Logging       = [PSCustomObject]@{ MinimumLogLevel = 'Warning'; Backend = 'File' }
                        MouseControl  = [PSCustomObject]@{ OvershootFactor = 0.3; EasingEnabled = $true }
                        EmergencyStop = [PSCustomObject]@{ PollIntervalMs = 250; AutoStart = $false }
                    }
                }
                Mock Test-ConfigValue -MockWith { [PSCustomObject]@{ Valid = $true; Message = '' } }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $result = Invoke-StartupConfigValidation -Console $tc
                $result.HasErrors | Should -BeFalse
            }
        }

        It 'Does not write any panel to the Console when all values pass' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{
                        Logging       = [PSCustomObject]@{ MinimumLogLevel = 'Info' }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Test-ConfigValue -MockWith { [PSCustomObject]@{ Valid = $true; Message = '' } }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                Invoke-StartupConfigValidation -Console $tc | Out-Null
                $tc.Output | Should -BeNullOrEmpty
            }
        }
    }

    Context 'When one config value is invalid' {

        It 'Returns HasErrors=$true' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{
                        Logging       = [PSCustomObject]@{ MinimumLogLevel = 'BadValue' }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Test-ConfigValue -MockWith { [PSCustomObject]@{ Valid = $true; Message = '' } }
                Mock Test-ConfigValue -ParameterFilter { $Key -eq 'Logging.MinimumLogLevel' } -MockWith {
                    [PSCustomObject]@{ Valid = $false; Message = 'must be one of: Verbose, Info, Warning, Error' }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Input.PushKey([ConsoleKey]::Enter)  # Acknowledge the warning panel

                $result = Invoke-StartupConfigValidation -Console $tc
                $result.HasErrors | Should -BeTrue
            }
        }

        It 'The failing key name appears in Console output' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{
                        Logging       = [PSCustomObject]@{ MinimumLogLevel = 'BadValue' }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Test-ConfigValue -MockWith { [PSCustomObject]@{ Valid = $true; Message = '' } }
                Mock Test-ConfigValue -ParameterFilter { $Key -eq 'Logging.MinimumLogLevel' } -MockWith {
                    [PSCustomObject]@{ Valid = $false; Message = 'must be one of: Verbose, Info, Warning, Error' }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Invoke-StartupConfigValidation -Console $tc | Out-Null
                $tc.Output | Should -Match 'Logging.MinimumLogLevel'
            }
        }

        It 'The validation message for the failing key appears in Console output' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{
                        Logging       = [PSCustomObject]@{ MinimumLogLevel = 'BadValue' }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Test-ConfigValue -MockWith { [PSCustomObject]@{ Valid = $true; Message = '' } }
                Mock Test-ConfigValue -ParameterFilter { $Key -eq 'Logging.MinimumLogLevel' } -MockWith {
                    [PSCustomObject]@{ Valid = $false; Message = 'must be one of: Verbose, Info, Warning, Error' }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Invoke-StartupConfigValidation -Console $tc | Out-Null
                $tc.Output | Should -Match 'must be one of'
            }
        }

        It 'Returns Messages array containing the failing key and its message' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{
                        Logging       = [PSCustomObject]@{ MinimumLogLevel = 'BadValue' }
                        MouseControl  = [PSCustomObject]@{}
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Test-ConfigValue -MockWith { [PSCustomObject]@{ Valid = $true; Message = '' } }
                Mock Test-ConfigValue -ParameterFilter { $Key -eq 'Logging.MinimumLogLevel' } -MockWith {
                    [PSCustomObject]@{ Valid = $false; Message = 'must be one of: Verbose, Info, Warning, Error' }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Invoke-StartupConfigValidation -Console $tc
                $result.Messages | Should -Not -BeNullOrEmpty
                ($result.Messages -join '') | Should -Match 'Logging.MinimumLogLevel'
            }
        }
    }

    Context 'When multiple config values are invalid' {

        It 'Returns HasErrors=$true' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{
                        Logging       = [PSCustomObject]@{ MinimumLogLevel = 'Bad' }
                        MouseControl  = [PSCustomObject]@{ OvershootFactor = 99.0 }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Test-ConfigValue -MockWith { [PSCustomObject]@{ Valid = $true; Message = '' } }
                Mock Test-ConfigValue -ParameterFilter { $Key -eq 'Logging.MinimumLogLevel' } -MockWith {
                    [PSCustomObject]@{ Valid = $false; Message = 'must be one of: Verbose, Info, Warning, Error' }
                }
                Mock Test-ConfigValue -ParameterFilter { $Key -eq 'MouseControl.OvershootFactor' } -MockWith {
                    [PSCustomObject]@{ Valid = $false; Message = 'must be between 0.0 and 1.0' }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Invoke-StartupConfigValidation -Console $tc
                $result.HasErrors | Should -BeTrue
            }
        }

        It 'All failing key names appear in Console output' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{
                        Logging       = [PSCustomObject]@{ MinimumLogLevel = 'Bad' }
                        MouseControl  = [PSCustomObject]@{ OvershootFactor = 99.0 }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Test-ConfigValue -MockWith { [PSCustomObject]@{ Valid = $true; Message = '' } }
                Mock Test-ConfigValue -ParameterFilter { $Key -eq 'Logging.MinimumLogLevel' } -MockWith {
                    [PSCustomObject]@{ Valid = $false; Message = 'must be one of: Verbose, Info, Warning, Error' }
                }
                Mock Test-ConfigValue -ParameterFilter { $Key -eq 'MouseControl.OvershootFactor' } -MockWith {
                    [PSCustomObject]@{ Valid = $false; Message = 'must be between 0.0 and 1.0' }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Invoke-StartupConfigValidation -Console $tc | Out-Null
                $tc.Output | Should -Match 'Logging.MinimumLogLevel'
                $tc.Output | Should -Match 'MouseControl.OvershootFactor'
            }
        }

        It 'Returns Messages array with one entry per failing key' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{
                        Logging       = [PSCustomObject]@{ MinimumLogLevel = 'Bad' }
                        MouseControl  = [PSCustomObject]@{ OvershootFactor = 99.0 }
                        EmergencyStop = [PSCustomObject]@{}
                    }
                }
                Mock Test-ConfigValue -MockWith { [PSCustomObject]@{ Valid = $true; Message = '' } }
                Mock Test-ConfigValue -ParameterFilter { $Key -eq 'Logging.MinimumLogLevel' } -MockWith {
                    [PSCustomObject]@{ Valid = $false; Message = 'must be one of: Verbose, Info, Warning, Error' }
                }
                Mock Test-ConfigValue -ParameterFilter { $Key -eq 'MouseControl.OvershootFactor' } -MockWith {
                    [PSCustomObject]@{ Valid = $false; Message = 'must be between 0.0 and 1.0' }
                }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Invoke-StartupConfigValidation -Console $tc
                $result.Messages.Count | Should -Be 2
            }
        }
    }

    Context 'When the config file contains invalid JSON' {

        It 'Returns HasErrors=$true' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith { throw [System.ArgumentException] 'Invalid JSON format' }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Input.PushKey([ConsoleKey]::Enter)  # Acknowledge the error panel

                $result = Invoke-StartupConfigValidation -Console $tc
                $result.HasErrors | Should -BeTrue
            }
        }

        It 'Writes an error panel to Console describing the JSON problem' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith { throw [System.ArgumentException] 'Invalid JSON format' }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Invoke-StartupConfigValidation -Console $tc | Out-Null
                $tc.Output | Should -Match 'invalid JSON'
            }
        }

        It 'Calls Write-LastWarLog with Level Warning for the invalid JSON case' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith { throw [System.ArgumentException] 'Invalid JSON format' }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Invoke-StartupConfigValidation -Console $tc | Out-Null
                Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Warning' } -Exactly 1
            }
        }

        It 'Does not proceed to schema validation when JSON is invalid' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith { throw [System.ArgumentException] 'Invalid JSON format' }
                Mock Write-LastWarLog {}
                Mock Test-ConfigValue {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Invoke-StartupConfigValidation -Console $tc | Out-Null
                Should -Not -Invoke Test-ConfigValue
            }
        }
    }

    Context 'Return value shape' {

        It 'Always returns an object with HasErrors (bool) and Messages (array) properties' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-ModuleConfiguration -MockWith {
                    [PSCustomObject]@{ Logging = [PSCustomObject]@{}; MouseControl = [PSCustomObject]@{}; EmergencyStop = [PSCustomObject]@{} }
                }
                Mock Test-ConfigValue -MockWith { [PSCustomObject]@{ Valid = $true; Message = '' } }

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $result = Invoke-StartupConfigValidation -Console $tc

                $result.PSObject.Properties.Name | Should -Contain 'HasErrors'
                $result.PSObject.Properties.Name | Should -Contain 'Messages'
                $result.HasErrors | Should -BeOfType [bool]
                , $result.Messages | Should -BeOfType [array]
            }
        }
    }
}

