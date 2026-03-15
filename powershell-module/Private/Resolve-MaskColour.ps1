function Resolve-MaskColour {
    <#
    .SYNOPSIS
        Parses a colour string into a System.Drawing.Color value.

    .DESCRIPTION
        Attempts three parsing strategies in order:

        1. Named colour: one of 23 supported names (e.g. "red", "dark blue", "light green").
           Input is normalised to lowercase before lookup. The modifiers "light" and "dark"
           are not valid with "black" or "white" and return $null with a warning.

        2. RGB triplet: three comma-separated integers each in the range 0-255
           (e.g. "255,0,0" or " 128, 0, 128 ").

        3. 6-character hex code: exactly six hexadecimal characters, with an optional
           leading "#" (e.g. "FF0000", "#FF0000", or "ffffff").

        Returns $null without a warning for null or empty/whitespace-only input.
        Returns $null with a Write-Warning for input that matches none of the formats.

    .PARAMETER ColourString
        The colour value to parse. May be $null or empty.

    .OUTPUTS
        System.Drawing.Color
        The resolved colour, or $null if the input is null/empty or cannot be parsed.

    .EXAMPLE
        Resolve-MaskColour -ColourString 'dark blue'
        # Returns [System.Drawing.Color] with R=0, G=0, B=139

    .EXAMPLE
        Resolve-MaskColour -ColourString '255,128,0'
        # Returns [System.Drawing.Color] with R=255, G=128, B=0

    .EXAMPLE
        Resolve-MaskColour -ColourString 'FF0000'
        # Returns [System.Drawing.Color] with R=255, G=0, B=0

    .EXAMPLE
        Resolve-MaskColour -ColourString '#FF0000'
        # Returns [System.Drawing.Color] with R=255, G=0, B=0
    #>
    [CmdletBinding()]
    [OutputType([System.Drawing.Color])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ColourString
    )

    # Null / empty / whitespace: return $null silently
    if ([string]::IsNullOrWhiteSpace($ColourString)) {
        return $null
    }

    # ── Named colour table (23 supported combinations) ──────────────────────
    $namedColours = @{
        'black'        = [System.Drawing.Color]::FromArgb(0,   0,   0)
        'white'        = [System.Drawing.Color]::FromArgb(255, 255, 255)
        'red'          = [System.Drawing.Color]::FromArgb(255, 0,   0)
        'green'        = [System.Drawing.Color]::FromArgb(0,   128, 0)
        'blue'         = [System.Drawing.Color]::FromArgb(0,   0,   255)
        'yellow'       = [System.Drawing.Color]::FromArgb(255, 255, 0)
        'pink'         = [System.Drawing.Color]::FromArgb(255, 192, 203)
        'orange'       = [System.Drawing.Color]::FromArgb(255, 165, 0)
        'purple'       = [System.Drawing.Color]::FromArgb(128, 0,   128)
        'light red'    = [System.Drawing.Color]::FromArgb(255, 128, 128)
        'light green'  = [System.Drawing.Color]::FromArgb(144, 238, 144)
        'light blue'   = [System.Drawing.Color]::FromArgb(173, 216, 230)
        'light yellow' = [System.Drawing.Color]::FromArgb(255, 255, 224)
        'light pink'   = [System.Drawing.Color]::FromArgb(255, 218, 238)
        'light orange' = [System.Drawing.Color]::FromArgb(255, 210, 150)
        'light purple' = [System.Drawing.Color]::FromArgb(221, 160, 221)
        'dark red'     = [System.Drawing.Color]::FromArgb(139, 0,   0)
        'dark green'   = [System.Drawing.Color]::FromArgb(0,   100, 0)
        'dark blue'    = [System.Drawing.Color]::FromArgb(0,   0,   139)
        'dark yellow'  = [System.Drawing.Color]::FromArgb(204, 204, 0)
        'dark pink'    = [System.Drawing.Color]::FromArgb(220, 100, 130)
        'dark orange'  = [System.Drawing.Color]::FromArgb(255, 140, 0)
        'dark purple'  = [System.Drawing.Color]::FromArgb(75,  0,   130)
    }

    # ── Attempt 1: named colour ─────────────────────────────────────────────
    $normalisedName = ($ColourString.Trim() -replace '\s+', ' ').ToLower()

    # Reject invalid modifier combinations before table lookup
    $invalidModifierPairs = @('light black', 'dark black', 'light white', 'dark white')
    if ($normalisedName -in $invalidModifierPairs) {
        Write-Warning "Resolve-MaskColour: The modifier 'light'/'dark' is not valid for 'black' or 'white'. Input: '$ColourString'."
        return $null
    }

    if ($namedColours.ContainsKey($normalisedName)) {
        return $namedColours[$normalisedName]
    }

    # ── Attempt 2: RGB triplet ──────────────────────────────────────────────
    $rgbParts = $ColourString -split ','
    if ($rgbParts.Count -eq 3) {
        $parsedOk = $true
        $rgb      = [int[]]::new(3)
        for ($i = 0; $i -lt 3; $i++) {
            $trimmed = $rgbParts[$i].Trim()
            $intVal  = 0
            if ([int]::TryParse($trimmed, [ref]$intVal) -and $intVal -ge 0 -and $intVal -le 255) {
                $rgb[$i] = $intVal
            } else {
                $parsedOk = $false
                break
            }
        }
        if ($parsedOk) {
            return [System.Drawing.Color]::FromArgb($rgb[0], $rgb[1], $rgb[2])
        }
    }

    # ── Attempt 3: 6-character hex code (optional leading '#' is stripped) ──
    $hexCandidate = $ColourString.Trim()
    if ($hexCandidate.StartsWith('#')) {
        $hexCandidate = $hexCandidate.Substring(1)
    }
    if ($hexCandidate -match '^[0-9A-Fa-f]{6}$') {
        $r = [Convert]::ToInt32($hexCandidate.Substring(0, 2), 16)
        $g = [Convert]::ToInt32($hexCandidate.Substring(2, 2), 16)
        $b = [Convert]::ToInt32($hexCandidate.Substring(4, 2), 16)
        return [System.Drawing.Color]::FromArgb($r, $g, $b)
    }

    # ── Failure ─────────────────────────────────────────────────────────────
    Write-Warning "Resolve-MaskColour: Cannot parse colour string '$ColourString'. Expected a named colour (e.g. 'red', 'dark blue'), RGB triplet (e.g. '255,0,0'), or 6-character hex code (e.g. 'FF0000')."
    return $null
}
