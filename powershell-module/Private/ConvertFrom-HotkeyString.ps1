function ConvertFrom-HotkeyString {
    <#
    .SYNOPSIS
        Converts a key combination string to an array of virtual key codes.

    .DESCRIPTION
        Parses a plus-separated key combination string such as 'Ctrl+Shift+P' or 'Ctrl+Alt+F1'
        and returns the corresponding array of Windows virtual key code integers.

        Recognised key names (case-insensitive):
          Modifiers : Ctrl, Shift, Alt, Win, LCtrl, RCtrl, LShift, RShift, LAlt, RAlt, LWin, RWin
          Letters   : A-Z (single letter)
          Digits    : 0-9 (single digit)
          Function  : F1-F24
          Navigation: Left, Right, Up, Down, Home, End, PageUp, PageDown, Insert, Delete
          Other     : Backspace, Tab, Enter, Esc, Space, Pause, CapsLock, NumLock, ScrollLock
          Numpad    : Num0-Num9, Num*, Num+, Num-, Num., Num/
          OEM chars : A single character that the current keyboard layout produces without any
                      modifier key (e.g. '#' on a UK layout maps to VK_OEM_5 = 0xDC).
                      Characters that require Shift or another modifier to produce are not
                      accepted as standalone key names.

        This function is the inverse of ConvertTo-HotkeyDisplayString.

    .PARAMETER HotkeyString
        A plus-separated key combination string, e.g. 'Ctrl+Shift+P'.

    .OUTPUTS
        [int[]]  Array of virtual key code integers.

    .EXAMPLE
        ConvertFrom-HotkeyString -HotkeyString 'Ctrl+Shift+P'
        # Returns @(17, 16, 80)

    .EXAMPLE
        ConvertFrom-HotkeyString -HotkeyString 'Ctrl+Alt+F1'
        # Returns @(17, 18, 112)

    .NOTES
        'Num+' contains a '+' character which would otherwise be misidentified as a
        separator.  The function substitutes 'Num+' with a placeholder before splitting
        on '+', then restores it, ensuring it is treated as a single key name.

        OEM character resolution uses VkKeyScanEx against the current thread's keyboard
        layout.  Only characters that require no modifier (high-order byte of the return
        value is 0) are accepted; characters requiring Shift or another modifier are
        rejected because the modifier key would be specified explicitly in the combination.
    #>
    [CmdletBinding()]
    [OutputType([int[]])]
    param(
        [Parameter(Mandatory)]
        [string]$HotkeyString
    )

    # Lookup table: uppercase key name -> virtual key code.
    # OEM symbol keys (0xBA-0xDF) are intentionally absent; they are resolved via VkKeyScanEx below.
    $nameToVKey = @{
        'CTRL'        = 0x11; 'SHIFT'       = 0x10; 'ALT'         = 0x12; 'WIN'        = 0x5B
        'LCTRL'       = 0xA2; 'RCTRL'       = 0xA3; 'LSHIFT'      = 0xA0; 'RSHIFT'     = 0xA1
        'LALT'        = 0xA4; 'RALT'        = 0xA5; 'LWIN'        = 0x5B; 'RWIN'       = 0x5C
        'BACKSPACE'   = 0x08; 'TAB'         = 0x09; 'ENTER'       = 0x0D; 'PAUSE'      = 0x13
        'CAPSLOCK'    = 0x14; 'ESC'         = 0x1B; 'SPACE'       = 0x20; 'PAGEUP'     = 0x21
        'PAGEDOWN'    = 0x22; 'END'         = 0x23; 'HOME'        = 0x24; 'LEFT'       = 0x25
        'UP'          = 0x26; 'RIGHT'       = 0x27; 'DOWN'        = 0x28; 'INSERT'     = 0x2D
        'DELETE'      = 0x2E
        'F1'          = 0x70; 'F2'          = 0x71; 'F3'          = 0x72; 'F4'         = 0x73
        'F5'          = 0x74; 'F6'          = 0x75; 'F7'          = 0x76; 'F8'         = 0x77
        'F9'          = 0x78; 'F10'         = 0x79; 'F11'         = 0x7A; 'F12'        = 0x7B
        'F13'         = 0x7C; 'F14'         = 0x7D; 'F15'         = 0x7E; 'F16'        = 0x7F
        'F17'         = 0x80; 'F18'         = 0x81; 'F19'         = 0x82; 'F20'        = 0x83
        'F21'         = 0x84; 'F22'         = 0x85; 'F23'         = 0x86; 'F24'        = 0x87
        'NUMLOCK'     = 0x90; 'SCROLLLOCK'  = 0x91
        'NUM0'        = 0x60; 'NUM1'        = 0x61; 'NUM2'        = 0x62; 'NUM3'       = 0x63
        'NUM4'        = 0x64; 'NUM5'        = 0x65; 'NUM6'        = 0x66; 'NUM7'       = 0x67
        'NUM8'        = 0x68; 'NUM9'        = 0x69; 'NUM*'        = 0x6A; 'NUM+'       = 0x6B
        'NUM-'        = 0x6D; 'NUM.'        = 0x6E; 'NUM/'        = 0x6F
    }

    # Substitute 'Num+' before splitting so its '+' is not treated as a separator.
    $sanitized = $HotkeyString -ireplace 'Num\+', '_NUMPLUS_'
    $rawParts  = $sanitized -split '\+'
    $parts     = $rawParts | ForEach-Object { ($_ -ireplace '_NUMPLUS_', 'Num+').Trim() }

    $vkCodes = [System.Collections.Generic.List[int]]::new()

    foreach ($part in $parts) {
        $upperPart = $part.ToUpper()

        # Named key lookup (covers modifiers, function keys, navigation, numpad, etc.)
        if ($nameToVKey.ContainsKey($upperPart)) {
            $vkCodes.Add($nameToVKey[$upperPart])
            continue
        }

        if ($part.Length -eq 1) {
            $ch      = $part[0]
            $upperCh = [char]::ToUpper($ch)

            # Single letter A-Z
            if ($upperCh -ge 'A' -and $upperCh -le 'Z') {
                $vkCodes.Add([int]$upperCh)
                continue
            }

            # Single digit 0-9
            if ($ch -ge '0' -and $ch -le '9') {
                $vkCodes.Add([int]$ch)
                continue
            }

            # OEM character: resolve via VkKeyScanEx against the current keyboard layout.
            # Only accept characters that require no modifier key (high-order byte = 0).
            $layout     = [LastWarAutoScreenshot.WindowEnumerationAPI]::GetKeyboardLayout(0)
            $scanResult = [LastWarAutoScreenshot.WindowEnumerationAPI]::VkKeyScanEx($ch, $layout)
            $vkCode     = $scanResult -band 0xFF
            $shiftState = ($scanResult -shr 8) -band 0xFF
            if ($vkCode -ge 1 -and $vkCode -le 254 -and $shiftState -eq 0) {
                $vkCodes.Add($vkCode)
                continue
            }
        }

        throw "Unknown or unsupported key name: '$part'. " +
              'Valid names include: Ctrl, Shift, Alt, Win (and L/R variants), A-Z, 0-9, F1-F24, ' +
              'Esc, Enter, Tab, Space, Backspace, Pause, CapsLock, NumLock, ScrollLock, ' +
              'Left/Right/Up/Down, Home, End, PageUp, PageDown, Insert, Delete, ' +
              'Num0-Num9, Num*, Num+, Num-, Num., Num/, ' +
              "and single characters produced without a modifier on your keyboard layout (e.g. '#' on UK)."
    }

    return [int[]]$vkCodes.ToArray()
}
