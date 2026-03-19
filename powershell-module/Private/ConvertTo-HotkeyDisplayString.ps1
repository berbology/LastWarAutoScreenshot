function ConvertTo-HotkeyDisplayString {
    <#
    .SYNOPSIS
        Converts an array of virtual key codes to a human-readable hotkey combination string.

    .DESCRIPTION
        Maps virtual key codes to their display names using a lookup table for well-known keys
        (modifiers, function keys, navigation keys, numpad keys, etc.). For keys whose character
        is keyboard-layout-dependent (such as OEM symbol keys), uses the MapVirtualKeyEx Win32
        API with the current thread's keyboard layout to resolve the actual character the key
        produces without modifiers.

        This allows a hotkey combination to be displayed as, for example, 'Ctrl+Alt+Q' on a
        UK keyboard layout rather than as raw hex codes such as '0x11+0x10+0xDC'.

        Keys that have no printable mapping under the current layout fall back to hex notation
        (e.g. '0x6C').

    .PARAMETER VKeyCodes
        An array of virtual key code integers (e.g. @(17, 16, 220)).

    .OUTPUTS
        [string] A human-readable hotkey string such as 'Ctrl+Alt+Q' or 'Ctrl+Alt+F2'.

    .EXAMPLE
        ConvertTo-HotkeyDisplayString -VKeyCodes @(17, 16, 220)
        # Returns 'Ctrl+Alt+Q' on a UK keyboard layout, or 'Ctrl+Shift+\' on a US layout.

    .EXAMPLE
        ConvertTo-HotkeyDisplayString -VKeyCodes @(17, 18, 113)
        # Returns 'Ctrl+Alt+F2'.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int[]]$VKeyCodes
    )

    # Lookup table for well-known virtual key codes with stable, layout-independent names.
    # OEM symbol keys (e.g. 0xBA-0xDF) are intentionally omitted; they are resolved via
    # MapVirtualKeyEx against the current keyboard layout below.
    $knownKeys = @{
        0x08 = 'Backspace'
        0x09 = 'Tab'
        0x0D = 'Enter'
        0x10 = 'Shift'
        0x11 = 'Ctrl'
        0x12 = 'Alt'
        0x13 = 'Pause'
        0x14 = 'CapsLock'
        0x1B = 'Esc'
        0x20 = 'Space'
        0x21 = 'PageUp'
        0x22 = 'PageDown'
        0x23 = 'End'
        0x24 = 'Home'
        0x25 = 'Left'
        0x26 = 'Up'
        0x27 = 'Right'
        0x28 = 'Down'
        0x2D = 'Insert'
        0x2E = 'Delete'
        0x5B = 'LWin'
        0x5C = 'RWin'
        0x60 = 'Num0'
        0x61 = 'Num1'
        0x62 = 'Num2'
        0x63 = 'Num3'
        0x64 = 'Num4'
        0x65 = 'Num5'
        0x66 = 'Num6'
        0x67 = 'Num7'
        0x68 = 'Num8'
        0x69 = 'Num9'
        0x6A = 'Num*'
        0x6B = 'Num+'
        0x6D = 'Num-'
        0x6E = 'Num.'
        0x6F = 'Num/'
        0x70 = 'F1'
        0x71 = 'F2'
        0x72 = 'F3'
        0x73 = 'F4'
        0x74 = 'F5'
        0x75 = 'F6'
        0x76 = 'F7'
        0x77 = 'F8'
        0x78 = 'F9'
        0x79 = 'F10'
        0x7A = 'F11'
        0x7B = 'F12'
        0x7C = 'F13'
        0x7D = 'F14'
        0x7E = 'F15'
        0x7F = 'F16'
        0x80 = 'F17'
        0x81 = 'F18'
        0x82 = 'F19'
        0x83 = 'F20'
        0x84 = 'F21'
        0x85 = 'F22'
        0x86 = 'F23'
        0x87 = 'F24'
        0x90 = 'NumLock'
        0x91 = 'ScrollLock'
        0xA0 = 'LShift'
        0xA1 = 'RShift'
        0xA2 = 'LCtrl'
        0xA3 = 'RCtrl'
        0xA4 = 'LAlt'
        0xA5 = 'RAlt'
    }

    # Retrieve the current thread's keyboard layout handle once for all OEM key lookups.
    $keyboardLayout = [LastWarAutoScreenshot.WindowEnumerationAPI]::GetKeyboardLayout(0)

    $names = foreach ($code in $VKeyCodes) {
        # Cast to [int] to ensure hashtable lookup matches [int] keys regardless of whether
        # the value arrived as [long] (JSON deserialisation) or another numeric type.
        $intCode = [int]$code
        if ($knownKeys.ContainsKey($intCode)) {
            $knownKeys[$intCode]
        } elseif ($intCode -ge 0x30 -and $intCode -le 0x39) {
            # Digit keys 0-9: VK code equals ASCII digit character code.
            [char]$intCode
        } elseif ($intCode -ge 0x41 -and $intCode -le 0x5A) {
            # Alpha keys A-Z: VK code equals uppercase ASCII character code.
            [char]$intCode
        } else {
            # OEM and other keys: resolve the unshifted character via the current keyboard layout.
            # MAPVK_VK_TO_CHAR = 2; the return value is a Unicode character code.
            # The high-order bit is set for dead keys; mask it off before converting to char.
            $rawChar = [LastWarAutoScreenshot.WindowEnumerationAPI]::MapVirtualKeyEx(
                [uint32]$intCode, 2, $keyboardLayout
            )
            $charValue = $rawChar -band 0x7FFFFFFF
            if ($charValue -ge 0x21 -and $charValue -le 0xFFFF) {
                [char]$charValue
            } else {
                # No printable mapping available; fall back to hex notation.
                '0x{0:X2}' -f $intCode
            }
        }
    }

    return $names -join '+'
}
