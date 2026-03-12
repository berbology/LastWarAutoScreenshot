BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'Test-ConfigValue' -Tag 'Unit' {

    Context 'When the key is not present in the schema (unknown key)' {
        It 'Should return Valid=$true for an unrecognised key' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'Completely.Unknown.Key' -Value 'anything'
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return an empty Message string for an unrecognised key' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'Completely.Unknown.Key' -Value 42
                $result.Message | Should -Be ''
            }
        }
    }

    Context 'Nullable constraint' {
        It 'Should return Valid=$false with a non-empty message when $null is given for a non-nullable key' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'Logging.MinimumLogLevel' -Value $null
                $result.Valid | Should -BeFalse
                $result.Message | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Output shape' {
        It 'Should always return an object with a Valid (bool) property and a Message (string) property' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'Logging.MinimumLogLevel' -Value 'Info'
                $result.PSObject.Properties.Name | Should -Contain 'Valid'
                $result.PSObject.Properties.Name | Should -Contain 'Message'
                @($result.PSObject.Properties).Count | Should -Be 2
                $result.Valid | Should -BeOfType [bool]
                $result.Message | Should -BeOfType [string]
            }
        }

        It 'Should return an empty string (not $null) for Message when the value is Valid' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'Logging.MinimumLogLevel' -Value 'Info'
                $result.Valid | Should -BeTrue
                $result.Message | Should -Be ''
            }
        }
    }

    Context 'int type validation' {
        It 'Should return Valid=$true for an integer within range' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'Logging.FileBackend.MaxSizeMB' -Value 50
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return Valid=$true for the minimum boundary value' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'Logging.FileBackend.MaxSizeMB' -Value 1
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return Valid=$true for the maximum boundary value' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'Logging.FileBackend.MaxSizeMB' -Value 10240
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return Valid=$false with a non-empty message when value is below Min' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'Logging.FileBackend.MaxSizeMB' -Value 0
                $result.Valid | Should -BeFalse
                $result.Message | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should return Valid=$false with a non-empty message when value is above Max' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'Logging.FileBackend.MaxSizeMB' -Value 10241
                $result.Valid | Should -BeFalse
                $result.Message | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should return Valid=$true when an in-range integer is supplied as a string' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'Logging.FileBackend.MaxSizeMB' -Value '50'
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return Valid=$false with a non-empty message for a non-numeric string' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'Logging.FileBackend.MaxSizeMB' -Value 'not-a-number'
                $result.Valid | Should -BeFalse
                $result.Message | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'double type validation' {
        It 'Should return Valid=$true for a double within range' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'MouseControl.OvershootFactor' -Value 0.5
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return Valid=$true for the minimum boundary value (0.0)' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'MouseControl.OvershootFactor' -Value 0.0
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return Valid=$true for the maximum boundary value (1.0)' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'MouseControl.OvershootFactor' -Value 1.0
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return Valid=$false with a non-empty message when value is below Min' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'MouseControl.OvershootFactor' -Value -0.1
                $result.Valid | Should -BeFalse
                $result.Message | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should return Valid=$false with a non-empty message when value is above Max' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'MouseControl.OvershootFactor' -Value 1.1
                $result.Valid | Should -BeFalse
                $result.Message | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should return Valid=$true for a string that parses as a valid in-range double' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'MouseControl.OvershootFactor' -Value '0.5'
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return Valid=$false with a non-empty message for a non-numeric string' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'MouseControl.OvershootFactor' -Value 'abc'
                $result.Valid | Should -BeFalse
                $result.Message | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'bool type validation' {
        It 'Should return Valid=$true for the PowerShell $true boolean' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'MouseControl.EasingEnabled' -Value $true
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return Valid=$true for the PowerShell $false boolean' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'MouseControl.EasingEnabled' -Value $false
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return Valid=$true for the string representation "<BoolStr>"' -ForEach @(
            @{ BoolStr = 'true'  }
            @{ BoolStr = 'false' }
            @{ BoolStr = 'yes'   }
            @{ BoolStr = 'no'    }
            @{ BoolStr = '1'     }
            @{ BoolStr = '0'     }
        ) {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' -Parameters @{ BoolStr = $BoolStr } {
                $result = Test-ConfigValue -Key 'MouseControl.EasingEnabled' -Value $BoolStr
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return Valid=$false with a non-empty message for an unrecognised boolean string' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'MouseControl.EasingEnabled' -Value 'maybe'
                $result.Valid | Should -BeFalse
                $result.Message | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'stringEnum type validation' {
        It 'Should return Valid=$true for a valid enum value' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'Logging.MinimumLogLevel' -Value 'Info'
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return Valid=$true for each valid MinimumLogLevel value - "<EnumVal>"' -ForEach @(
            @{ EnumVal = 'Verbose' }
            @{ EnumVal = 'Info'    }
            @{ EnumVal = 'Warning' }
            @{ EnumVal = 'Error'   }
        ) {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' -Parameters @{ EnumVal = $EnumVal } {
                $result = Test-ConfigValue -Key 'Logging.MinimumLogLevel' -Value $EnumVal
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return Valid=$true regardless of case for a valid stringEnum value' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'Logging.MinimumLogLevel' -Value 'info'
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return Valid=$false with a non-empty message for a value not in AllowedValues' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'Logging.MinimumLogLevel' -Value 'Debug'
                $result.Valid | Should -BeFalse
                $result.Message | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should return Valid=$true for each valid Logging.Backend value - "<EnumVal>"' -ForEach @(
            @{ EnumVal = 'File'          }
            @{ EnumVal = 'EventLog'      }
            @{ EnumVal = 'File,EventLog' }
        ) {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' -Parameters @{ EnumVal = $EnumVal } {
                $result = Test-ConfigValue -Key 'Logging.Backend' -Value $EnumVal
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return Valid=$false for an invalid Logging.Backend value' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'Logging.Backend' -Value 'Console'
                $result.Valid | Should -BeFalse
                $result.Message | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'intArray type validation' {
        It 'Should return Valid=$true for a valid two-element array within bounds' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'MouseControl.ClickDownDurationRangeMs' -Value @(200, 600)
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return Valid=$true when element[0] equals element[1] (min equals max)' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'MouseControl.ClickDownDurationRangeMs' -Value @(300, 300)
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return Valid=$false with a non-empty message when element[0] exceeds element[1]' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'MouseControl.ClickDownDurationRangeMs' -Value @(600, 200)
                $result.Valid | Should -BeFalse
                $result.Message | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should return Valid=$false with a non-empty message when element[0] is below Min' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'MouseControl.ClickDownDurationRangeMs' -Value @(-1, 200)
                $result.Valid | Should -BeFalse
                $result.Message | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should return Valid=$false with a non-empty message when element[1] exceeds Max' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'MouseControl.ClickDownDurationRangeMs' -Value @(200, 5001)
                $result.Valid | Should -BeFalse
                $result.Message | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should return Valid=$false with a non-empty message for an array with more than two elements' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'MouseControl.ClickDownDurationRangeMs' -Value @(100, 200, 300)
                $result.Valid | Should -BeFalse
                $result.Message | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should return Valid=$false with a non-empty message for a single-element array' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'MouseControl.ClickDownDurationRangeMs' -Value @(200)
                $result.Valid | Should -BeFalse
                $result.Message | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should return Valid=$true for a comma-separated string with valid values' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'MouseControl.ClickDownDurationRangeMs' -Value '200, 600'
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return Valid=$false for a comma-separated string where min exceeds max' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'MouseControl.ClickDownDurationRangeMs' -Value '600, 200'
                $result.Valid | Should -BeFalse
                $result.Message | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should return Valid=$false for a comma-separated string with non-integer values' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'MouseControl.ClickDownDurationRangeMs' -Value '200.5, 600.5'
                $result.Valid | Should -BeFalse
                $result.Message | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should return Valid=$false for a plain non-array, non-string object' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'MouseControl.ClickDownDurationRangeMs' -Value ([hashtable]@{})
                $result.Valid | Should -BeFalse
                $result.Message | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'EmergencyStop key validation' {
        It 'Should return Valid=$true for EmergencyStop.PollIntervalMs within range' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'EmergencyStop.PollIntervalMs' -Value 100
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return Valid=$false for EmergencyStop.PollIntervalMs below Min (10)' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'EmergencyStop.PollIntervalMs' -Value 9
                $result.Valid | Should -BeFalse
                $result.Message | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should return Valid=$true for EmergencyStop.AutoStart as a bool' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'EmergencyStop.AutoStart' -Value $true
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return Valid=$true for EmergencyStop.MouseGestureHoldDurationMs at boundary' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'EmergencyStop.MouseGestureHoldDurationMs' -Value 500
                $result.Valid | Should -BeTrue
            }
        }

        It 'Should return Valid=$false for EmergencyStop.MouseGestureHoldDurationMs below Min (500)' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $result = Test-ConfigValue -Key 'EmergencyStop.MouseGestureHoldDurationMs' -Value 499
                $result.Valid | Should -BeFalse
                $result.Message | Should -Not -BeNullOrEmpty
            }
        }
    }
}

