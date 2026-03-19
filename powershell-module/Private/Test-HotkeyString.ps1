function Test-HotkeyString {
    <#
    .SYNOPSIS
        Validates a key combination string and returns a normalised form if valid.

    .DESCRIPTION
        Validates that the supplied string represents a well-formed key combination:

          - Must contain 2 or 3 keys separated by '+'.
          - All keys except the last must be modifier keys (Ctrl, Shift, Alt, Win, or
            their left/right variants: LCtrl, RCtrl, LShift, RShift, LAlt, RAlt, LWin, RWin).
          - The last key must NOT be a modifier.
          - Modifier keys must not be duplicated (e.g. Ctrl+Ctrl+P is invalid).
          - All key names must be recognisable by ConvertFrom-HotkeyString.

        When valid, returns the combination in canonical casing with modifiers
        title-cased (e.g. 'ctrl+alt+p' becomes 'Ctrl+Alt+P').

    .PARAMETER HotkeyString
        The key combination string to validate, e.g. 'Ctrl+Shift+P'.

    .OUTPUTS
        PSCustomObject with:
          Valid      [bool]   - $true when the combination passes all rules.
          Message    [string] - Empty string when valid; human-readable error when invalid.
          Normalized [string] - Canonical form when valid (e.g. 'Ctrl+Alt+P'); $null when invalid.

    .EXAMPLE
        Test-HotkeyString -HotkeyString 'ctrl+shift+p'
        # Returns { Valid = $true; Message = ''; Normalized = 'Ctrl+Shift+P' }

    .EXAMPLE
        Test-HotkeyString -HotkeyString 'Ctrl+Ctrl+Egg'
        # Returns { Valid = $false; Message = 'Duplicate modifier keys are not allowed...'; Normalized = $null }

    .EXAMPLE
        Test-HotkeyString -HotkeyString 'a+b+c'
        # Returns { Valid = $false; Message = "'a' is not a valid modifier key..."; Normalized = $null }

    .NOTES
        'Num+' contains a '+' character that would be misidentified as a separator if the
        string were naively split on '+'.  This function uses the same pre-substitution
        technique as ConvertFrom-HotkeyString to handle 'Num+' correctly.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$HotkeyString
    )

    # Set of valid modifier names (uppercase).
    $validModifiers = @(
        'CTRL', 'SHIFT', 'ALT', 'WIN',
        'LCTRL', 'RCTRL', 'LSHIFT', 'RSHIFT', 'LALT', 'RALT', 'LWIN', 'RWIN'
    )

    # Canonical casing for modifier names.
    $canonicalModifier = @{
        'CTRL'    = 'Ctrl'  ; 'SHIFT'   = 'Shift'  ; 'ALT'     = 'Alt'    ; 'WIN'    = 'Win'
        'LCTRL'   = 'LCtrl' ; 'RCTRL'   = 'RCtrl'  ; 'LSHIFT'  = 'LShift' ; 'RSHIFT' = 'RShift'
        'LALT'    = 'LAlt'  ; 'RALT'    = 'RAlt'   ; 'LWIN'    = 'LWin'   ; 'RWIN'   = 'RWin'
    }

    # Canonical casing for non-modifier named keys.
    $canonicalKey = @{
        'BACKSPACE'  = 'Backspace' ; 'TAB'        = 'Tab'        ; 'ENTER'      = 'Enter'
        'PAUSE'      = 'Pause'     ; 'CAPSLOCK'   = 'CapsLock'   ; 'ESC'        = 'Esc'
        'SPACE'      = 'Space'     ; 'PAGEUP'     = 'PageUp'     ; 'PAGEDOWN'   = 'PageDown'
        'END'        = 'End'       ; 'HOME'       = 'Home'       ; 'LEFT'       = 'Left'
        'UP'         = 'Up'        ; 'RIGHT'      = 'Right'      ; 'DOWN'       = 'Down'
        'INSERT'     = 'Insert'    ; 'DELETE'     = 'Delete'
        'F1'         = 'F1'  ; 'F2'  = 'F2'  ; 'F3'  = 'F3'  ; 'F4'  = 'F4'
        'F5'         = 'F5'  ; 'F6'  = 'F6'  ; 'F7'  = 'F7'  ; 'F8'  = 'F8'
        'F9'         = 'F9'  ; 'F10' = 'F10' ; 'F11' = 'F11' ; 'F12' = 'F12'
        'F13'        = 'F13' ; 'F14' = 'F14' ; 'F15' = 'F15' ; 'F16' = 'F16'
        'F17'        = 'F17' ; 'F18' = 'F18' ; 'F19' = 'F19' ; 'F20' = 'F20'
        'F21'        = 'F21' ; 'F22' = 'F22' ; 'F23' = 'F23' ; 'F24' = 'F24'
        'NUMLOCK'    = 'NumLock'   ; 'SCROLLLOCK' = 'ScrollLock'
        'NUM0'       = 'Num0' ; 'NUM1' = 'Num1' ; 'NUM2' = 'Num2' ; 'NUM3' = 'Num3'
        'NUM4'       = 'Num4' ; 'NUM5' = 'Num5' ; 'NUM6' = 'Num6' ; 'NUM7' = 'Num7'
        'NUM8'       = 'Num8' ; 'NUM9' = 'Num9' ; 'NUM*' = 'Num*'
        'NUM+'       = 'Num+' ; 'NUM-' = 'Num-' ; 'NUM.' = 'Num.' ; 'NUM/' = 'Num/'
    }

    # Substitute 'Num+' before splitting to avoid splitting on its '+' character.
    $sanitized = $HotkeyString -ireplace 'Num\+', '_NUMPLUS_'
    $rawParts  = $sanitized -split '\+'
    $parts     = @($rawParts | ForEach-Object { ($_ -ireplace '_NUMPLUS_', 'Num+').Trim() })

    # Reject empty parts (leading, trailing, or consecutive '+' characters).
    if ($parts | Where-Object { [string]::IsNullOrEmpty($_) }) {
        return [PSCustomObject]@{
            Valid      = $false
            Message    = "Key combination contains an empty part. Check for leading, trailing, or consecutive '+' characters."
            Normalized = $null
        }
    }

    # Must have exactly 2 or 3 keys.
    if ($parts.Count -lt 2) {
        return [PSCustomObject]@{
            Valid      = $false
            Message    = "A hotkey combination must have at least 2 keys (e.g. 'Ctrl+P')."
            Normalized = $null
        }
    }

    if ($parts.Count -gt 3) {
        return [PSCustomObject]@{
            Valid      = $false
            Message    = "A hotkey combination can have at most 3 keys (e.g. 'Ctrl+Shift+P')."
            Normalized = $null
        }
    }

    # All parts except the last must be modifier keys.
    $modifierParts   = @($parts[0..($parts.Count - 2)])
    $nonModifierPart = $parts[$parts.Count - 1]

    foreach ($mod in $modifierParts) {
        if ($validModifiers -notcontains $mod.ToUpper()) {
            return [PSCustomObject]@{
                Valid      = $false
                Message    = "'$mod' is not a valid modifier key. Valid modifiers: Ctrl, Shift, Alt, Win (and L/R variants such as LCtrl, RAlt)."
                Normalized = $null
            }
        }
    }

    # The last part must NOT be a modifier.
    if ($validModifiers -contains $nonModifierPart.ToUpper()) {
        return [PSCustomObject]@{
            Valid      = $false
            Message    = "'$nonModifierPart' is a modifier key and cannot be the last key in a combination."
            Normalized = $null
        }
    }

    # No duplicate modifier names.
    $upperMods   = @($modifierParts | ForEach-Object { $_.ToUpper() })
    $uniqueUpper = @($upperMods | Select-Object -Unique)
    if ($uniqueUpper.Count -ne $modifierParts.Count) {
        return [PSCustomObject]@{
            Valid      = $false
            Message    = 'Duplicate modifier keys are not allowed (e.g. Ctrl+Ctrl+P is invalid).'
            Normalized = $null
        }
    }

    # Validate the non-modifier key by attempting to convert it.
    try {
        ConvertFrom-HotkeyString -HotkeyString $nonModifierPart | Out-Null
    }
    catch {
        return [PSCustomObject]@{
            Valid      = $false
            Message    = $_.Exception.Message
            Normalized = $null
        }
    }

    # Build the normalised form with canonical casing.
    $normalizedParts = @()

    foreach ($mod in $modifierParts) {
        $normalizedParts += $canonicalModifier[$mod.ToUpper()]
    }

    # Normalise the non-modifier key.
    $upperNonMod = $nonModifierPart.ToUpper()
    if ($canonicalKey.ContainsKey($upperNonMod)) {
        $normalizedParts += $canonicalKey[$upperNonMod]
    }
    elseif ($nonModifierPart.Length -eq 1) {
        $ch      = $nonModifierPart[0]
        $upperCh = [char]::ToUpper($ch)
        if ($upperCh -ge 'A' -and $upperCh -le 'Z') {
            # Letter: always uppercase.
            $normalizedParts += [string]$upperCh
        }
        else {
            # Digit or OEM character: preserve as-is.
            $normalizedParts += $nonModifierPart
        }
    }
    else {
        # Fallback: use as entered.
        $normalizedParts += $nonModifierPart
    }

    return [PSCustomObject]@{
        Valid      = $true
        Message    = ''
        Normalized = $normalizedParts -join '+'
    }
}
