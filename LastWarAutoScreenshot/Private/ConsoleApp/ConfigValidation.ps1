function Test-ConfigValue {
    <#
    .SYNOPSIS
        Validates a single module configuration value against the schema.

    .DESCRIPTION
        Looks up the validation rule for the supplied key in the module-scoped
        $script:ConfigValidationSchema hashtable and checks whether the value
        satisfies all declared constraints (type, range, allowed values, nullable).

        Unknown keys (not present in the schema) are treated as valid and pass
        through silently, so callers do not need to know the full schema.

        Supported types: 'int', 'double', 'bool', 'string', 'stringEnum', 'intArray'.

        For 'intArray': the value must be an array of exactly two integers where
        element[0] is less than or equal to element[1].  Both elements are also
        checked against optional Min/Max bounds.

        String input is accepted for numeric and bool types so that values entered
        via Spectre.Console TextPrompt can be validated before conversion.

    .PARAMETER Key
        The dot-notation configuration key to validate, e.g.
        'Logging.MinimumLogLevel' or 'MouseControl.MovementDurationRangeMs'.

    .PARAMETER Value
        The configuration value to validate.  May be a typed value (as returned
        by Get-ModuleConfiguration / ConvertFrom-Json) or a raw string captured
        from a user prompt.  Pass $null to test nullable constraints.

    .OUTPUTS
        PSCustomObject
        Returns a result object with:
        - Valid   [bool]   - $true if the value is valid, $false otherwise.
        - Message [string] - Human-readable explanation when Valid is $false;
                             empty string when Valid is $true.

    .EXAMPLE
        $result = Test-ConfigValue -Key 'Logging.MinimumLogLevel' -Value 'Info'
        if (-not $result.Valid) { Write-Host $result.Message -ForegroundColor Red }

    .EXAMPLE
        # Validates user-entered string for an intArray key
        $result = Test-ConfigValue -Key 'MouseControl.MovementDurationRangeMs' -Value '200, 600'

    .NOTES
        Pure PowerShell - no Add-Type calls.  All logic is based on the
        $script:ConfigValidationSchema hashtable populated in
        Get-DefaultModuleSettings.ps1 at module load time.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [object]$Value
    )

    # Unknown key - pass through silently
    if (-not $script:ConfigValidationSchema.ContainsKey($Key)) {
        return [PSCustomObject]@{ Valid = $true; Message = '' }
    }

    $rule = $script:ConfigValidationSchema[$Key]

    # Nullable check
    if ($null -eq $Value) {
        if ($rule.Nullable) {
            return [PSCustomObject]@{ Valid = $true; Message = '' }
        }
        return [PSCustomObject]@{ Valid = $false; Message = "'$Key' cannot be null." }
    }

    switch ($rule.Type) {

        'int' {
            $intValue = 0
            try {
                $intValue = [int]$Value
            }
            catch {
                return [PSCustomObject]@{
                    Valid   = $false
                    Message = "'$Key' must be a whole number. Got: '$Value'."
                }
            }
            if ($rule.ContainsKey('Min') -and $intValue -lt $rule.Min) {
                return [PSCustomObject]@{
                    Valid   = $false
                    Message = "'$Key' must be at least $($rule.Min). Got: $intValue."
                }
            }
            if ($rule.ContainsKey('Max') -and $intValue -gt $rule.Max) {
                return [PSCustomObject]@{
                    Valid   = $false
                    Message = "'$Key' must be at most $($rule.Max). Got: $intValue."
                }
            }
            return [PSCustomObject]@{ Valid = $true; Message = '' }
        }

        'double' {
            $dblValue = [double]0
            if ($Value -is [double] -or $Value -is [float] -or
                $Value -is [int]    -or $Value -is [long]   -or $Value -is [decimal]) {
                $dblValue = [double]$Value
            }
            elseif ($Value -is [string]) {
                $parsed = [double]0
                $ok = [double]::TryParse(
                    $Value,
                    [System.Globalization.NumberStyles]::Float,
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [ref]$parsed
                )
                if (-not $ok) {
                    return [PSCustomObject]@{
                        Valid   = $false
                        Message = "'$Key' must be a decimal number. Got: '$Value'."
                    }
                }
                $dblValue = $parsed
            }
            else {
                $cast = $Value -as [double]
                if ($null -eq $cast) {
                    return [PSCustomObject]@{
                        Valid   = $false
                        Message = "'$Key' must be a decimal number. Got: '$Value'."
                    }
                }
                $dblValue = $cast
            }
            if ($rule.ContainsKey('Min') -and $dblValue -lt $rule.Min) {
                return [PSCustomObject]@{
                    Valid   = $false
                    Message = "'$Key' must be at least $($rule.Min). Got: $dblValue."
                }
            }
            if ($rule.ContainsKey('Max') -and $dblValue -gt $rule.Max) {
                return [PSCustomObject]@{
                    Valid   = $false
                    Message = "'$Key' must be at most $($rule.Max). Got: $dblValue."
                }
            }
            return [PSCustomObject]@{ Valid = $true; Message = '' }
        }

        'bool' {
            if ($Value -is [bool]) {
                return [PSCustomObject]@{ Valid = $true; Message = '' }
            }
            if ($Value -is [string]) {
                $lower = $Value.ToLowerInvariant()
                if ($lower -in @('true', 'false', 'yes', 'no', '1', '0')) {
                    return [PSCustomObject]@{ Valid = $true; Message = '' }
                }
            }
            return [PSCustomObject]@{
                Valid   = $false
                Message = "'$Key' must be a true/false value (true, false, yes, no, 1, 0). Got: '$Value'."
            }
        }

        'string' {
            # Any non-null string is valid; null is caught above
            return [PSCustomObject]@{ Valid = $true; Message = '' }
        }

        'stringEnum' {
            $strValue = "$Value"
            $isMatch = $false
            foreach ($allowed in $rule.AllowedValues) {
                if ($allowed -ieq $strValue) {
                    $isMatch = $true
                    break
                }
            }
            if (-not $isMatch) {
                return [PSCustomObject]@{
                    Valid   = $false
                    Message = "'$Key' must be one of: $($rule.AllowedValues -join ', '). Got: '$strValue'."
                }
            }
            return [PSCustomObject]@{ Valid = $true; Message = '' }
        }

        'intArray' {
            # Accept a real array, or a "min, max" comma-separated string from user input
            $arrItems = $null
            if ($Value -is [array]) {
                $arrItems = $Value
            }
            elseif ($Value -is [string]) {
                $parts = ($Value -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
                $parsed = @()
                foreach ($part in $parts) {
                    $n = 0
                    if (-not [int]::TryParse($part, [ref]$n)) {
                        return [PSCustomObject]@{
                            Valid   = $false
                            Message = "'$Key' must be two comma-separated whole numbers (e.g. '200, 600'). Got: '$Value'."
                        }
                    }
                    $parsed += $n
                }
                $arrItems = $parsed
            }
            else {
                return [PSCustomObject]@{
                    Valid   = $false
                    Message = "'$Key' must be an array of two integers."
                }
            }

            if ($arrItems.Count -ne 2) {
                return [PSCustomObject]@{
                    Valid   = $false
                    Message = "'$Key' must have exactly 2 elements. Got: $($arrItems.Count)."
                }
            }

            $elem0 = 0
            $elem1 = 0
            try { $elem0 = [int]$arrItems[0] } catch {
                return [PSCustomObject]@{
                    Valid   = $false
                    Message = "'$Key' elements must be whole numbers."
                }
            }
            try { $elem1 = [int]$arrItems[1] } catch {
                return [PSCustomObject]@{
                    Valid   = $false
                    Message = "'$Key' elements must be whole numbers."
                }
            }

            if ($rule.ContainsKey('Min') -and $elem0 -lt $rule.Min) {
                return [PSCustomObject]@{
                    Valid   = $false
                    Message = "'$Key'[0] must be at least $($rule.Min). Got: $elem0."
                }
            }
            if ($rule.ContainsKey('Max') -and $elem0 -gt $rule.Max) {
                return [PSCustomObject]@{
                    Valid   = $false
                    Message = "'$Key'[0] must be at most $($rule.Max). Got: $elem0."
                }
            }
            if ($rule.ContainsKey('Min') -and $elem1 -lt $rule.Min) {
                return [PSCustomObject]@{
                    Valid   = $false
                    Message = "'$Key'[1] must be at least $($rule.Min). Got: $elem1."
                }
            }
            if ($rule.ContainsKey('Max') -and $elem1 -gt $rule.Max) {
                return [PSCustomObject]@{
                    Valid   = $false
                    Message = "'$Key'[1] must be at most $($rule.Max). Got: $elem1."
                }
            }
            if ($elem0 -gt $elem1) {
                return [PSCustomObject]@{
                    Valid   = $false
                    Message = "'$Key' minimum value ($elem0) must not exceed the maximum value ($elem1)."
                }
            }
            return [PSCustomObject]@{ Valid = $true; Message = '' }
        }

        default {
            # Unknown type in schema - treat as valid to avoid false positives
            return [PSCustomObject]@{ Valid = $true; Message = '' }
        }
    }
}

