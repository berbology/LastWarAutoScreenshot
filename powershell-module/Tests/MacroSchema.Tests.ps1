BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'Get-ValidMacroName' -Tag 'Unit' {

    Context 'Valid names' {

        It 'accepts a simple valid name' {
            InModuleScope LastWarAutoScreenshot {
                $result = Get-ValidMacroName -Name 'my-macro-1'
                $result.Valid | Should -BeTrue
                $result.SanitisedName | Should -Be 'my-macro-1'
                $result.Message | Should -BeNullOrEmpty
            }
        }

        It 'accepts underscores and hyphens' {
            InModuleScope LastWarAutoScreenshot {
                $result = Get-ValidMacroName -Name 'macro_name-v2'
                $result.Valid | Should -BeTrue
            }
        }

        It 'accepts alphanumeric only' {
            InModuleScope LastWarAutoScreenshot {
                $result = Get-ValidMacroName -Name 'MacroABC123'
                $result.Valid | Should -BeTrue
            }
        }

        It 'accepts a name at exactly 50 characters' {
            InModuleScope LastWarAutoScreenshot {
                $name   = 'a' * 50
                $result = Get-ValidMacroName -Name $name
                $result.Valid | Should -BeTrue
            }
        }
    }

    Context 'Invalid names without AutoFix' {

        It 'rejects an empty string' {
            InModuleScope LastWarAutoScreenshot {
                $result = Get-ValidMacroName -Name ''
                $result.Valid | Should -BeFalse
                $result.Message | Should -Not -BeNullOrEmpty
            }
        }

        It 'rejects a name with spaces' {
            InModuleScope LastWarAutoScreenshot {
                $result = Get-ValidMacroName -Name 'my macro'
                $result.Valid | Should -BeFalse
            }
        }

        It 'rejects a name exceeding 50 characters' {
            InModuleScope LastWarAutoScreenshot {
                $result = Get-ValidMacroName -Name ('a' * 51)
                $result.Valid | Should -BeFalse
            }
        }

        It 'rejects a name with only invalid characters' {
            InModuleScope LastWarAutoScreenshot {
                $result = Get-ValidMacroName -Name '!!!'
                $result.Valid | Should -BeFalse
            }
        }

        It 'rejects a duplicate name (case-insensitive)' {
            InModuleScope LastWarAutoScreenshot {
                $result = Get-ValidMacroName -Name 'MyMacro' -ExistingNames @('mymacro')
                $result.Valid | Should -BeFalse
                $result.Message | Should -Match 'already in use'
            }
        }
    }

    Context 'AutoFix behaviour' {

        It 'converts spaces to hyphens and sets WasAutoFixed' {
            InModuleScope LastWarAutoScreenshot {
                $result = Get-ValidMacroName -Name 'my macro' -AutoFix
                $result.Valid | Should -BeTrue
                $result.SanitisedName | Should -Be 'my-macro'
                $result.WasAutoFixed | Should -BeTrue
            }
        }

        It 'strips invalid characters' {
            InModuleScope LastWarAutoScreenshot {
                $result = Get-ValidMacroName -Name 'my macro!@#' -AutoFix
                $result.Valid | Should -BeTrue
                $result.SanitisedName | Should -Be 'my-macro'
            }
        }

        It 'truncates to 50 characters' {
            InModuleScope LastWarAutoScreenshot {
                $result = Get-ValidMacroName -Name ('a' * 55) -AutoFix
                $result.Valid | Should -BeTrue
                $result.SanitisedName.Length | Should -Be 50
            }
        }

        It 'returns Valid=$false when only invalid characters remain after stripping' {
            InModuleScope LastWarAutoScreenshot {
                $result = Get-ValidMacroName -Name '!!!' -AutoFix
                $result.Valid | Should -BeFalse
            }
        }

        It 'does not set WasAutoFixed for a name without spaces that was otherwise clean' {
            InModuleScope LastWarAutoScreenshot {
                $result = Get-ValidMacroName -Name 'clean-name' -AutoFix
                $result.Valid | Should -BeTrue
                $result.WasAutoFixed | Should -BeFalse
            }
        }
    }
}

Describe 'Test-MacroAction' -Tag 'Unit' {

    Context 'MoveToPoint' {

        It 'accepts a valid MoveToPoint action' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type     = 'MoveToPoint'
                    position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.3 }
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeTrue
            }
        }

        It 'rejects MoveToPoint missing position.relativeX' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type     = 'MoveToPoint'
                    position = [PSCustomObject]@{ relativeY = 0.3 }
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeFalse
                $result.Message | Should -Match 'relativeX'
            }
        }

        It 'rejects MoveToPoint with relativeX = 1.5 (out of range)' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type     = 'MoveToPoint'
                    position = [PSCustomObject]@{ relativeX = 1.5; relativeY = 0.3 }
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeFalse
            }
        }
    }

    Context 'MoveToRegion' {

        It 'accepts a valid MoveToRegion Box action' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type   = 'MoveToRegion'
                    region = [PSCustomObject]@{
                        type           = 'Box'
                        relativeX      = 0.1
                        relativeY      = 0.2
                        relativeWidth  = 0.3
                        relativeHeight = 0.4
                    }
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeTrue
            }
        }

        It 'accepts a valid MoveToRegion Circle action' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type   = 'MoveToRegion'
                    region = [PSCustomObject]@{
                        type            = 'Circle'
                        relativeCentreX = 0.5
                        relativeCentreY = 0.5
                        relativeRadius  = 0.1
                    }
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeTrue
            }
        }

        It 'rejects MoveToRegion with invalid region.type' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type   = 'MoveToRegion'
                    region = [PSCustomObject]@{ type = 'Triangle' }
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeFalse
                $result.Message | Should -Match 'Box.*Circle'
            }
        }
    }

    Context 'LeftClick' {

        It 'accepts a valid LeftClick action (no required properties)' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{ type = 'LeftClick' }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeTrue
            }
        }
    }

    Context 'DragClick' {

        It 'accepts a valid DragClick action' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type  = 'DragClick'
                    start = [PSCustomObject]@{ relativeX = 0.2; relativeY = 0.3 }
                    end   = [PSCustomObject]@{ relativeX = 0.8; relativeY = 0.7 }
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeTrue
            }
        }
    }

    Context 'Screenshot' {

        It 'accepts a valid Screenshot action' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type   = 'Screenshot'
                    region = [PSCustomObject]@{
                        topLeft     = [PSCustomObject]@{ relativeX = 0.1; relativeY = 0.1 }
                        bottomRight = [PSCustomObject]@{ relativeX = 0.9; relativeY = 0.9 }
                    }
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeTrue
            }
        }

        It 'rejects Screenshot where bottomRight.relativeX <= topLeft.relativeX' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type   = 'Screenshot'
                    region = [PSCustomObject]@{
                        topLeft     = [PSCustomObject]@{ relativeX = 0.9; relativeY = 0.1 }
                        bottomRight = [PSCustomObject]@{ relativeX = 0.1; relativeY = 0.9 }
                    }
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeFalse
            }
        }

        It 'rejects Screenshot where bottomRight.relativeY <= topLeft.relativeY' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type   = 'Screenshot'
                    region = [PSCustomObject]@{
                        topLeft     = [PSCustomObject]@{ relativeX = 0.1; relativeY = 0.9 }
                        bottomRight = [PSCustomObject]@{ relativeX = 0.9; relativeY = 0.1 }
                    }
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeFalse
            }
        }

        It 'accepts a Screenshot action with no maskRegions property (regression guard)' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type   = 'Screenshot'
                    region = [PSCustomObject]@{
                        topLeft     = [PSCustomObject]@{ relativeX = 0.1; relativeY = 0.1 }
                        bottomRight = [PSCustomObject]@{ relativeX = 0.9; relativeY = 0.9 }
                    }
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeTrue
            }
        }

        It 'accepts a Screenshot action with an empty maskRegions array' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type        = 'Screenshot'
                    region      = [PSCustomObject]@{
                        topLeft     = [PSCustomObject]@{ relativeX = 0.1; relativeY = 0.1 }
                        bottomRight = [PSCustomObject]@{ relativeX = 0.9; relativeY = 0.9 }
                    }
                    maskRegions = @()
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeTrue
            }
        }

        It 'accepts a Screenshot action with one valid maskRegion' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type        = 'Screenshot'
                    region      = [PSCustomObject]@{
                        topLeft     = [PSCustomObject]@{ relativeX = 0.1; relativeY = 0.1 }
                        bottomRight = [PSCustomObject]@{ relativeX = 0.9; relativeY = 0.9 }
                    }
                    maskRegions = @(
                        [PSCustomObject]@{
                            topLeft     = [PSCustomObject]@{ relativeX = 0.2; relativeY = 0.2 }
                            bottomRight = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.5 }
                        }
                    )
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeTrue
            }
        }

        It 'accepts a Screenshot action with exactly 10 maskRegions (boundary maximum)' {
            InModuleScope LastWarAutoScreenshot {
                $masks = 1..10 | ForEach-Object {
                    [PSCustomObject]@{
                        topLeft     = [PSCustomObject]@{ relativeX = 0.0; relativeY = 0.0 }
                        bottomRight = [PSCustomObject]@{ relativeX = 0.1; relativeY = 0.1 }
                    }
                }
                $action = [PSCustomObject]@{
                    type        = 'Screenshot'
                    region      = [PSCustomObject]@{
                        topLeft     = [PSCustomObject]@{ relativeX = 0.0; relativeY = 0.0 }
                        bottomRight = [PSCustomObject]@{ relativeX = 1.0; relativeY = 1.0 }
                    }
                    maskRegions = $masks
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeTrue
            }
        }

        It 'rejects a Screenshot action with 11 maskRegions' {
            InModuleScope LastWarAutoScreenshot {
                $masks = 1..11 | ForEach-Object {
                    [PSCustomObject]@{
                        topLeft     = [PSCustomObject]@{ relativeX = 0.0; relativeY = 0.0 }
                        bottomRight = [PSCustomObject]@{ relativeX = 0.1; relativeY = 0.1 }
                    }
                }
                $action = [PSCustomObject]@{
                    type        = 'Screenshot'
                    region      = [PSCustomObject]@{
                        topLeft     = [PSCustomObject]@{ relativeX = 0.0; relativeY = 0.0 }
                        bottomRight = [PSCustomObject]@{ relativeX = 1.0; relativeY = 1.0 }
                    }
                    maskRegions = $masks
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeFalse
                $result.Message | Should -Match '11'
            }
        }

        It 'rejects a maskRegion element missing topLeft' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type        = 'Screenshot'
                    region      = [PSCustomObject]@{
                        topLeft     = [PSCustomObject]@{ relativeX = 0.1; relativeY = 0.1 }
                        bottomRight = [PSCustomObject]@{ relativeX = 0.9; relativeY = 0.9 }
                    }
                    maskRegions = @(
                        [PSCustomObject]@{
                            bottomRight = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.5 }
                        }
                    )
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeFalse
                $result.Message | Should -Match 'topLeft'
            }
        }

        It 'rejects a maskRegion element missing bottomRight' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type        = 'Screenshot'
                    region      = [PSCustomObject]@{
                        topLeft     = [PSCustomObject]@{ relativeX = 0.1; relativeY = 0.1 }
                        bottomRight = [PSCustomObject]@{ relativeX = 0.9; relativeY = 0.9 }
                    }
                    maskRegions = @(
                        [PSCustomObject]@{
                            topLeft = [PSCustomObject]@{ relativeX = 0.1; relativeY = 0.1 }
                        }
                    )
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeFalse
                $result.Message | Should -Match 'bottomRight'
            }
        }

        It 'rejects a maskRegion with a coordinate outside 0.0-1.0' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type        = 'Screenshot'
                    region      = [PSCustomObject]@{
                        topLeft     = [PSCustomObject]@{ relativeX = 0.1; relativeY = 0.1 }
                        bottomRight = [PSCustomObject]@{ relativeX = 0.9; relativeY = 0.9 }
                    }
                    maskRegions = @(
                        [PSCustomObject]@{
                            topLeft     = [PSCustomObject]@{ relativeX = -0.1; relativeY = 0.0 }
                            bottomRight = [PSCustomObject]@{ relativeX = 0.5;  relativeY = 0.5 }
                        }
                    )
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeFalse
                $result.Message | Should -Match 'range'
            }
        }

        It 'rejects a maskRegion where bottomRight.relativeX <= topLeft.relativeX' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type        = 'Screenshot'
                    region      = [PSCustomObject]@{
                        topLeft     = [PSCustomObject]@{ relativeX = 0.1; relativeY = 0.1 }
                        bottomRight = [PSCustomObject]@{ relativeX = 0.9; relativeY = 0.9 }
                    }
                    maskRegions = @(
                        [PSCustomObject]@{
                            topLeft     = [PSCustomObject]@{ relativeX = 0.8; relativeY = 0.1 }
                            bottomRight = [PSCustomObject]@{ relativeX = 0.2; relativeY = 0.9 }
                        }
                    )
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeFalse
                $result.Message | Should -Match 'relativeX'
            }
        }

        It 'rejects a maskRegion where bottomRight.relativeY <= topLeft.relativeY' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type        = 'Screenshot'
                    region      = [PSCustomObject]@{
                        topLeft     = [PSCustomObject]@{ relativeX = 0.1; relativeY = 0.1 }
                        bottomRight = [PSCustomObject]@{ relativeX = 0.9; relativeY = 0.9 }
                    }
                    maskRegions = @(
                        [PSCustomObject]@{
                            topLeft     = [PSCustomObject]@{ relativeX = 0.1; relativeY = 0.8 }
                            bottomRight = [PSCustomObject]@{ relativeX = 0.9; relativeY = 0.2 }
                        }
                    )
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeFalse
                $result.Message | Should -Match 'relativeY'
            }
        }

        It 'reports the correct index [1] when the second maskRegion element is invalid' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type        = 'Screenshot'
                    region      = [PSCustomObject]@{
                        topLeft     = [PSCustomObject]@{ relativeX = 0.1; relativeY = 0.1 }
                        bottomRight = [PSCustomObject]@{ relativeX = 0.9; relativeY = 0.9 }
                    }
                    maskRegions = @(
                        [PSCustomObject]@{
                            topLeft     = [PSCustomObject]@{ relativeX = 0.1; relativeY = 0.1 }
                            bottomRight = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.5 }
                        },
                        [PSCustomObject]@{
                            bottomRight = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.5 }
                        }
                    )
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeFalse
                $result.Message | Should -Match '\[1\]'
            }
        }
    }

    Context 'Delay' {

        It 'accepts a valid Delay with seconds = 5' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{ type = 'Delay'; seconds = 5 }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeTrue
            }
        }

        It 'rejects Delay with seconds = 0 (below minimum 0.1)' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{ type = 'Delay'; seconds = 0 }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeFalse
            }
        }

        It 'rejects Delay with seconds = 4000 (above maximum 3600)' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{ type = 'Delay'; seconds = 4000 }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeFalse
            }
        }
    }

    Context 'Loop' {

        It 'accepts a valid Loop referencing existing named actions' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type        = 'Loop'
                    iterations  = 5
                    actionNames = @('action-a', 'action-b')
                }
                $result = Test-MacroAction -Action $action -ExistingNames @('action-a', 'action-b') -ActionTypeLookup @{ 'action-a' = 'MoveToPoint'; 'action-b' = 'LeftClick' }
                $result.Valid | Should -BeTrue
            }
        }

        It 'rejects Loop referencing a non-existent action name' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type        = 'Loop'
                    iterations  = 2
                    actionNames = @('does-not-exist')
                }
                $result = Test-MacroAction -Action $action -ExistingNames @('other-action')
                $result.Valid | Should -BeFalse
                $result.Message | Should -Match 'does-not-exist'
            }
        }

        It 'rejects Loop referencing another Loop action' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type        = 'Loop'
                    iterations  = 2
                    actionNames = @('inner-loop')
                }
                $result = Test-MacroAction -Action $action -ExistingNames @('inner-loop') -ActionTypeLookup @{ 'inner-loop' = 'Loop' }
                $result.Valid | Should -BeFalse
                $result.Message | Should -Match 'nesting'
            }
        }

        It 'rejects Loop with iterations = 0' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type        = 'Loop'
                    iterations  = 0
                    actionNames = @('action-a')
                }
                $result = Test-MacroAction -Action $action -ExistingNames @('action-a')
                $result.Valid | Should -BeFalse
            }
        }

        It 'rejects Loop with empty actionNames array' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{
                    type        = 'Loop'
                    iterations  = 3
                    actionNames = @()
                }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeFalse
                $result.Message | Should -Match 'non-empty'
            }
        }
    }

    Context 'Action name validation' {

        It 'rejects action with duplicate name in ExistingNames' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{ type = 'LeftClick'; name = 'existing-name' }
                $result = Test-MacroAction -Action $action -ExistingNames @('existing-name')
                $result.Valid | Should -BeFalse
                $result.Message | Should -Match 'already in use'
            }
        }
    }

    Context 'Unknown type' {

        It 'rejects an action with an unknown type' {
            InModuleScope LastWarAutoScreenshot {
                $action = [PSCustomObject]@{ type = 'FlyToMoon' }
                $result = Test-MacroAction -Action $action
                $result.Valid | Should -BeFalse
                $result.Message | Should -Match 'FlyToMoon'
            }
        }
    }
}

Describe 'Test-MacroFile' -Tag 'Unit' {

    BeforeAll {
        InModuleScope LastWarAutoScreenshot {
            # Helper to build a minimal valid macro object
            $script:BuildValidMacro = {
                [PSCustomObject]@{
                    version      = '1.0'
                    metadata     = [PSCustomObject]@{
                        name        = 'test-macro'
                        createdUtc  = '2026-01-01T00:00:00Z'
                        modifiedUtc = '2026-01-01T00:00:00Z'
                        description = ''
                    }
                    targetWindow = [PSCustomObject]@{
                        processName = 'LastWar'
                        windowTitle = 'Last War: Survival'
                    }
                    sequence     = @(
                        [PSCustomObject]@{
                            type     = 'MoveToPoint'
                            name     = 'target-point'
                            position = [PSCustomObject]@{ relativeX = 0.5; relativeY = 0.5 }
                        },
                        [PSCustomObject]@{ type = 'LeftClick' }
                    )
                }
            }
        }
    }

    It 'returns Valid=$true for a valid complete macro' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
            $macro  = & $script:BuildValidMacro
            $result = Test-MacroFile -MacroData $macro
            $result.Valid | Should -BeTrue
            $result.Messages | Should -HaveCount 0
        }
    }

    It 'returns Valid=$false when version is missing' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
            $macro = & $script:BuildValidMacro
            $macro.PSObject.Properties.Remove('version')
            $result = Test-MacroFile -MacroData $macro
            $result.Valid | Should -BeFalse
            $result.Messages | Should -Contain ($result.Messages | Where-Object { $_ -match 'version' })
        }
    }

    It 'returns Valid=$false when version value is wrong' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
            $macro         = & $script:BuildValidMacro
            $macro.version = '9.9'
            $result        = Test-MacroFile -MacroData $macro
            $result.Valid | Should -BeFalse
        }
    }

    It 'returns Valid=$false when metadata.name is missing' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
            $macro = & $script:BuildValidMacro
            $macro.metadata.PSObject.Properties.Remove('name')
            $result = Test-MacroFile -MacroData $macro
            $result.Valid | Should -BeFalse
        }
    }

    It 'returns Valid=$false when targetWindow.processName is missing' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
            $macro = & $script:BuildValidMacro
            $macro.targetWindow.PSObject.Properties.Remove('processName')
            $result = Test-MacroFile -MacroData $macro
            $result.Valid | Should -BeFalse
        }
    }

    It 'returns Valid=$false for an empty sequence' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
            $macro          = & $script:BuildValidMacro
            $macro.sequence = @()
            $result         = Test-MacroFile -MacroData $macro
            $result.Valid | Should -BeFalse
        }
    }

    It 'returns Valid=$false and collects all errors when there are multiple problems' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
            $macro         = & $script:BuildValidMacro
            $macro.version = '9.9'
            $macro.targetWindow.PSObject.Properties.Remove('processName')
            $result = Test-MacroFile -MacroData $macro
            $result.Valid | Should -BeFalse
            $result.Messages.Count | Should -BeGreaterThan 1
        }
    }

    It 'returns Valid=$false for duplicate action names in the sequence' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
            $macro          = & $script:BuildValidMacro
            $macro.sequence = @(
                [PSCustomObject]@{
                    type     = 'MoveToPoint'
                    name     = 'same-name'
                    position = [PSCustomObject]@{ relativeX = 0.1; relativeY = 0.1 }
                },
                [PSCustomObject]@{
                    type     = 'MoveToPoint'
                    name     = 'same-name'
                    position = [PSCustomObject]@{ relativeX = 0.2; relativeY = 0.2 }
                }
            )
            $result = Test-MacroFile -MacroData $macro
            $result.Valid | Should -BeFalse
        }
    }

    It 'returns Valid=$false for a broken loop reference' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
            $macro          = & $script:BuildValidMacro
            $macro.sequence = @(
                [PSCustomObject]@{
                    type        = 'Loop'
                    iterations  = 2
                    actionNames = @('ghost-action')
                }
            )
            $result = Test-MacroFile -MacroData $macro
            $result.Valid | Should -BeFalse
        }
    }

    It 'returns Valid=$false when a Loop references another Loop (nested)' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
            $macro          = & $script:BuildValidMacro
            $macro.sequence = @(
                [PSCustomObject]@{
                    type        = 'Loop'
                    name        = 'outer-loop'
                    iterations  = 2
                    actionNames = @('inner-loop')
                },
                [PSCustomObject]@{
                    type        = 'Loop'
                    name        = 'inner-loop'
                    iterations  = 3
                    actionNames = @('outer-loop')
                }
            )
            $result = Test-MacroFile -MacroData $macro
            $result.Valid | Should -BeFalse
        }
    }

    It 'calls Write-LastWarLog with Level Warning for each error' {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
            $macro         = & $script:BuildValidMacro
            $macro.version = '9.9'
            Test-MacroFile -MacroData $macro | Out-Null
            Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Warning' } -Exactly -Times 1
        }
    }
}
