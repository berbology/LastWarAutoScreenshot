# MacroSchema.ps1
# Defines the JSON macro schema version, action type registry, and validation functions.

$script:MacroSchemaVersion = '1.0'

$script:MacroActionTypes = @{
    'MoveToPoint' = @{
        Required = @('position.relativeX', 'position.relativeY')
        Ranges   = @{
            'position.relativeX' = @(0.0, 1.0)
            'position.relativeY' = @(0.0, 1.0)
        }
    }
    'MoveToRegion' = @{
        Required = @('region.type')
        SubTypes = @{
            'Box'    = @{
                Required = @('region.relativeX', 'region.relativeY', 'region.relativeWidth', 'region.relativeHeight')
                Ranges   = @{
                    'region.relativeX'      = @(0.0, 1.0)
                    'region.relativeY'      = @(0.0, 1.0)
                    'region.relativeWidth'  = @(0.0, 1.0)
                    'region.relativeHeight' = @(0.0, 1.0)
                }
            }
            'Circle' = @{
                Required = @('region.relativeCentreX', 'region.relativeCentreY', 'region.relativeRadius')
                Ranges   = @{
                    'region.relativeCentreX' = @(0.0, 1.0)
                    'region.relativeCentreY' = @(0.0, 1.0)
                    'region.relativeRadius'  = @(0.0, 1.0)
                }
            }
        }
    }
    'LeftClick'   = @{ Required = @() }
    'DragClick'   = @{
        Required = @('start.relativeX', 'start.relativeY', 'end.relativeX', 'end.relativeY')
        Ranges   = @{
            'start.relativeX' = @(0.0, 1.0)
            'start.relativeY' = @(0.0, 1.0)
            'end.relativeX'   = @(0.0, 1.0)
            'end.relativeY'   = @(0.0, 1.0)
        }
    }
    'Screenshot'  = @{
        Required = @(
            'region.topLeft.relativeX', 'region.topLeft.relativeY',
            'region.bottomRight.relativeX', 'region.bottomRight.relativeY'
        )
        Ranges   = @{
            'region.topLeft.relativeX'     = @(0.0, 1.0)
            'region.topLeft.relativeY'     = @(0.0, 1.0)
            'region.bottomRight.relativeX' = @(0.0, 1.0)
            'region.bottomRight.relativeY' = @(0.0, 1.0)
        }
    }
    'Delay'       = @{
        Required = @('seconds')
        Ranges   = @{ 'seconds' = @(0.1, 3600) }
    }
    'Loop'        = @{
        Required = @('iterations')
        Ranges   = @{ 'iterations' = @(1, 10000) }
    }
}

function Get-NestedProperty {
    <#
    .SYNOPSIS
        Resolves a dot-notation property path on a PSCustomObject.

    .DESCRIPTION
        Walks the dot-separated path segments and returns the value at the final
        segment, or $null if any segment is missing or the intermediate value is
        not an object with properties.

    .PARAMETER Object
        The root PSCustomObject to traverse.

    .PARAMETER Path
        A dot-separated property path, e.g. 'region.relativeX'.

    .OUTPUTS
        System.Object
        The resolved value, or $null if the path cannot be resolved.

    .EXAMPLE
        $action = [PSCustomObject]@{ position = [PSCustomObject]@{ relativeX = 0.5 } }
        Get-NestedProperty -Object $action -Path 'position.relativeX'
        # Returns: 0.5
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [object]$Object,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $segments = $Path -split '\.'
    $current  = $Object
    foreach ($segment in $segments) {
        if ($null -eq $current) { return $null }
        if ($current -is [System.Collections.IDictionary]) {
            if (-not $current.Contains($segment)) { return $null }
            $current = $current[$segment]
        } elseif ($current.PSObject.Properties[$segment]) {
            $current = $current.PSObject.Properties[$segment].Value
        } else {
            return $null
        }
    }
    return $current
}

function Get-ValidMacroName {
    <#
    .SYNOPSIS
        Validates (and optionally sanitises) a macro or action name.

    .DESCRIPTION
        Checks that the supplied name matches the allowed character set
        ([a-zA-Z0-9_-]), is between 1 and 50 characters, and is not already
        present in $ExistingNames (case-insensitive).

        When -AutoFix is specified:
          - Leading/trailing whitespace is trimmed.
          - Spaces are converted to hyphens.
          - All characters not matching [a-zA-Z0-9_-] are stripped.
          - The result is truncated to 50 characters.
        If the name contained spaces and AutoFix was applied, WasAutoFixed is
        set to $true so callers can prompt for confirmation.

    .PARAMETER Name
        The raw name string to validate.

    .PARAMETER ExistingNames
        Optional array of names already in use.  Comparison is case-insensitive.

    .PARAMETER AutoFix
        When present, applies automatic sanitisation before validation.

    .OUTPUTS
        PSCustomObject
        Properties: Valid [bool], SanitisedName [string], WasAutoFixed [bool], Message [string].
        Message is an empty string when Valid = $true.

    .EXAMPLE
        $result = Get-ValidMacroName -Name 'my macro' -AutoFix
        # $result.Valid = $true, $result.SanitisedName = 'my-macro', $result.WasAutoFixed = $true

    .EXAMPLE
        $result = Get-ValidMacroName -Name 'bad name!' -AutoFix -ExistingNames @('existing')
        # Strips '!' and converts space; checks uniqueness against 'existing'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name,

        [Parameter()]
        [string[]]$ExistingNames = @(),

        [Parameter()]
        [switch]$AutoFix
    )

    $sanitised    = $Name
    $wasAutoFixed = $false

    if ($AutoFix) {
        $sanitised = $sanitised.Trim()
        $hadSpaces = $sanitised -match ' '
        $sanitised = $sanitised -replace ' ', '-'
        $sanitised = $sanitised -replace '[^a-zA-Z0-9_-]', ''
        if ($sanitised.Length -gt 50) { $sanitised = $sanitised.Substring(0, 50) }
        # WasAutoFixed is true when the original name had spaces that were converted
        if ($hadSpaces) { $wasAutoFixed = $true }
    }

    if ([string]::IsNullOrEmpty($sanitised)) {
        return [PSCustomObject]@{
            Valid         = $false
            SanitisedName = $sanitised
            WasAutoFixed  = $wasAutoFixed
            Message       = 'Name must not be empty after sanitisation.'
        }
    }

    if ($sanitised -notmatch '^[a-zA-Z0-9_-]+$') {
        return [PSCustomObject]@{
            Valid         = $false
            SanitisedName = $sanitised
            WasAutoFixed  = $wasAutoFixed
            Message       = "Name '$sanitised' contains invalid characters. Only a-z, A-Z, 0-9, _ and - are allowed."
        }
    }

    if ($sanitised.Length -gt 50) {
        return [PSCustomObject]@{
            Valid         = $false
            SanitisedName = $sanitised
            WasAutoFixed  = $wasAutoFixed
            Message       = 'Name must be 50 characters or fewer.'
        }
    }

    foreach ($existing in $ExistingNames) {
        if ($sanitised -ieq $existing) {
            return [PSCustomObject]@{
                Valid         = $false
                SanitisedName = $sanitised
                WasAutoFixed  = $wasAutoFixed
                Message       = "Name '$sanitised' is already in use."
            }
        }
    }

    return [PSCustomObject]@{
        Valid         = $true
        SanitisedName = $sanitised
        WasAutoFixed  = $wasAutoFixed
        Message       = ''
    }
}

function Test-MacroAction {
    <#
    .SYNOPSIS
        Validates a single macro action object against the schema.

    .DESCRIPTION
        Checks that the action has a recognised type, all required properties
        exist and are non-null, all numeric properties are within their defined
        ranges, and (if the action has a name) the name is valid and unique.

        For MoveToRegion actions, the region.type sub-type is validated and the
        corresponding required properties are checked.

        For Screenshot actions, bottomRight coordinates must be strictly greater
        than topLeft.

        For Loop actions, each name in actionNames must exist in ExistingNames
        and must not resolve to a Loop action (using ActionTypeLookup).

    .PARAMETER Action
        The PSCustomObject representing the action to validate.

    .PARAMETER ExistingNames
        Names of actions already defined earlier in the sequence.  Used to
        validate action names (uniqueness) and Loop actionNames references.

    .PARAMETER ActionTypeLookup
        Optional hashtable mapping action name -> action type string.  Passed to
        the Loop validator so it can detect loop-references-loop violations.

    .OUTPUTS
        PSCustomObject
        Properties: Valid [bool], Message [string].
        Message is empty when Valid = $true; first error found when $false.

    .EXAMPLE
        $result = Test-MacroAction -Action $action -ExistingNames @()
        if (-not $result.Valid) { Write-Warning $result.Message }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Action,

        [Parameter()]
        [string[]]$ExistingNames = @(),

        [Parameter()]
        [hashtable]$ActionTypeLookup = @{}
    )

    # Type must be present and recognised
    if (-not $Action.PSObject.Properties['type'] -or [string]::IsNullOrEmpty($Action.type)) {
        return [PSCustomObject]@{ Valid = $false; Message = "Action is missing the 'type' property." }
    }

    $typeName = $Action.type
    if (-not $script:MacroActionTypes.ContainsKey($typeName)) {
        return [PSCustomObject]@{ Valid = $false; Message = "Unknown action type '$typeName'." }
    }

    $schema = $script:MacroActionTypes[$typeName]

    # Validate name if present
    if ($Action.PSObject.Properties['name'] -and -not [string]::IsNullOrEmpty($Action.name)) {
        $nameResult = Get-ValidMacroName -Name $Action.name -ExistingNames $ExistingNames
        if (-not $nameResult.Valid) {
            return [PSCustomObject]@{ Valid = $false; Message = "Action name: $($nameResult.Message)" }
        }
    }

    # MoveToRegion sub-type handling
    if ($typeName -eq 'MoveToRegion') {
        $regionType = Get-NestedProperty -Object $Action -Path 'region.type'
        if ($null -eq $regionType) {
            return [PSCustomObject]@{ Valid = $false; Message = "MoveToRegion action is missing 'region.type'." }
        }
        if (-not $schema.SubTypes.ContainsKey($regionType)) {
            return [PSCustomObject]@{ Valid = $false; Message = "MoveToRegion region.type must be 'Box' or 'Circle', got '$regionType'." }
        }
        $subSchema = $schema.SubTypes[$regionType]
        foreach ($prop in $subSchema.Required) {
            $value = Get-NestedProperty -Object $Action -Path $prop
            if ($null -eq $value) {
                return [PSCustomObject]@{ Valid = $false; Message = "MoveToRegion ($regionType) is missing required property '$prop'." }
            }
        }
        foreach ($prop in $subSchema.Ranges.Keys) {
            $value = Get-NestedProperty -Object $Action -Path $prop
            if ($null -ne $value) {
                $min = $subSchema.Ranges[$prop][0]
                $max = $subSchema.Ranges[$prop][1]
                if ($value -lt $min -or $value -gt $max) {
                    return [PSCustomObject]@{ Valid = $false; Message = "Property '$prop' value $value is outside allowed range [$min, $max]." }
                }
            }
        }
        return [PSCustomObject]@{ Valid = $true; Message = '' }
    }

    # Required properties check
    foreach ($prop in $schema.Required) {
        $value = Get-NestedProperty -Object $Action -Path $prop
        if ($null -eq $value) {
            return [PSCustomObject]@{ Valid = $false; Message = "Action type '$typeName' is missing required property '$prop'." }
        }
    }

    # Range checks
    if ($schema.ContainsKey('Ranges')) {
        foreach ($prop in $schema.Ranges.Keys) {
            $value = Get-NestedProperty -Object $Action -Path $prop
            if ($null -ne $value) {
                $min = $schema.Ranges[$prop][0]
                $max = $schema.Ranges[$prop][1]
                if ($value -lt $min -or $value -gt $max) {
                    return [PSCustomObject]@{ Valid = $false; Message = "Property '$prop' value $value is outside allowed range [$min, $max]." }
                }
            }
        }
    }

    # Screenshot: bottomRight must be strictly greater than topLeft
    if ($typeName -eq 'Screenshot') {
        $topLeftX    = Get-NestedProperty -Object $Action -Path 'region.topLeft.relativeX'
        $topLeftY    = Get-NestedProperty -Object $Action -Path 'region.topLeft.relativeY'
        $bottomRightX = Get-NestedProperty -Object $Action -Path 'region.bottomRight.relativeX'
        $bottomRightY = Get-NestedProperty -Object $Action -Path 'region.bottomRight.relativeY'
        if ($null -ne $topLeftX -and $null -ne $bottomRightX -and $bottomRightX -le $topLeftX) {
            return [PSCustomObject]@{ Valid = $false; Message = "Screenshot region.bottomRight.relativeX must be greater than region.topLeft.relativeX." }
        }
        if ($null -ne $topLeftY -and $null -ne $bottomRightY -and $bottomRightY -le $topLeftY) {
            return [PSCustomObject]@{ Valid = $false; Message = "Screenshot region.bottomRight.relativeY must be greater than region.topLeft.relativeY." }
        }
    }

    # Loop: actionNames must be non-empty, each name must exist, none may be a Loop
    if ($typeName -eq 'Loop') {
        $actionNames = Get-NestedProperty -Object $Action -Path 'actionNames'
        if ($null -eq $actionNames -or $actionNames.Count -eq 0) {
            return [PSCustomObject]@{ Valid = $false; Message = "Loop action must have a non-empty 'actionNames' array." }
        }
        foreach ($refName in $actionNames) {
            if ($ExistingNames -notcontains $refName) {
                return [PSCustomObject]@{ Valid = $false; Message = "Loop references action '$refName' which does not exist in the sequence." }
            }
            if ($ActionTypeLookup.ContainsKey($refName) -and $ActionTypeLookup[$refName] -eq 'Loop') {
                return [PSCustomObject]@{ Valid = $false; Message = "Loop nesting is not permitted: '$refName' is itself a Loop action." }
            }
        }
    }

    return [PSCustomObject]@{ Valid = $true; Message = '' }
}

function Test-MacroFile {
    <#
    .SYNOPSIS
        Validates a complete macro data object against the schema.

    .DESCRIPTION
        Checks the top-level structure (version, metadata, targetWindow, sequence),
        then iterates through each action in the sequence, accumulating a running
        set of named actions and a type lookup for Loop validation.

        All validation errors are collected and returned together; execution does
        not stop at the first error.

        Each validation error is also logged via Write-LastWarLog at Warning level.

    .PARAMETER MacroData
        The PSCustomObject representing the parsed macro (e.g. from ConvertFrom-Json).

    .OUTPUTS
        PSCustomObject
        Properties: Valid [bool], Messages [string[]].
        Messages is an empty array when Valid = $true.

    .EXAMPLE
        $result = Test-MacroFile -MacroData $macro
        if (-not $result.Valid) { $result.Messages | ForEach-Object { Write-Warning $_ } }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$MacroData
    )

    $errors = [System.Collections.Generic.List[string]]::new()

    # version
    if (-not $MacroData.PSObject.Properties['version'] -or [string]::IsNullOrEmpty($MacroData.version)) {
        $errors.Add("Macro is missing the 'version' field.")
    } elseif ($MacroData.version -ne $script:MacroSchemaVersion) {
        $errors.Add("Macro version '$($MacroData.version)' does not match expected version '$script:MacroSchemaVersion'.")
    }

    # metadata
    if (-not $MacroData.PSObject.Properties['metadata'] -or $null -eq $MacroData.metadata) {
        $errors.Add("Macro is missing the 'metadata' object.")
    } else {
        $meta = $MacroData.metadata
        if (-not $meta.PSObject.Properties['name'] -or [string]::IsNullOrEmpty($meta.name)) {
            $errors.Add("metadata.name is missing or empty.")
        } else {
            $nameResult = Get-ValidMacroName -Name $meta.name
            if (-not $nameResult.Valid) {
                $errors.Add("metadata.name is invalid: $($nameResult.Message)")
            }
        }
        foreach ($utcProp in @('createdUtc', 'modifiedUtc')) {
            if (-not $meta.PSObject.Properties[$utcProp] -or [string]::IsNullOrEmpty($meta.$utcProp)) {
                $errors.Add("metadata.$utcProp is missing or empty.")
            } else {
                try {
                    [datetime]::Parse($meta.$utcProp) | Out-Null
                } catch {
                    $errors.Add("metadata.$utcProp '$($meta.$utcProp)' is not a valid ISO 8601 datetime.")
                }
            }
        }
    }

    # targetWindow
    if (-not $MacroData.PSObject.Properties['targetWindow'] -or $null -eq $MacroData.targetWindow) {
        $errors.Add("Macro is missing the 'targetWindow' object.")
    } else {
        $tw = $MacroData.targetWindow
        foreach ($twProp in @('processName', 'windowTitle')) {
            if (-not $tw.PSObject.Properties[$twProp] -or [string]::IsNullOrEmpty($tw.$twProp)) {
                $errors.Add("targetWindow.$twProp is missing or empty.")
            }
        }
    }

    # sequence
    if (-not $MacroData.PSObject.Properties['sequence'] -or $null -eq $MacroData.sequence) {
        $errors.Add("Macro is missing the 'sequence' array.")
    } elseif ($MacroData.sequence.Count -eq 0) {
        $errors.Add("Macro sequence must contain at least one action.")
    } else {
        $existingNames    = [System.Collections.Generic.List[string]]::new()
        $actionTypeLookup = @{}

        foreach ($action in $MacroData.sequence) {
            $result = Test-MacroAction -Action $action -ExistingNames $existingNames -ActionTypeLookup $actionTypeLookup
            if (-not $result.Valid) {
                $errors.Add($result.Message)
            }
            # Accumulate name after validation so duplicate detection works correctly
            if ($action.PSObject.Properties['name'] -and -not [string]::IsNullOrEmpty($action.name)) {
                $existingNames.Add($action.name)
                $actionTypeLookup[$action.name] = $action.type
            }
        }
    }

    $valid = $errors.Count -eq 0
    foreach ($msg in $errors) {
        Write-LastWarLog -Level Warning -Message $msg -FunctionName 'Test-MacroFile'
    }

    return [PSCustomObject]@{
        Valid    = $valid
        Messages = $errors.ToArray()
    }
}
