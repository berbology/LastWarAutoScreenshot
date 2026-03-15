BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
    Add-Type -AssemblyName 'System.Drawing.Common'
}

Describe 'Resolve-MaskColour' -Tag 'Unit' {

    Context 'Named colour lookup' {

        It 'resolves <Name> to R=<R> G=<G> B=<B>' -ForEach @(
            @{ Name = 'black';        R = 0;   G = 0;   B = 0   }
            @{ Name = 'white';        R = 255; G = 255; B = 255 }
            @{ Name = 'red';          R = 255; G = 0;   B = 0   }
            @{ Name = 'green';        R = 0;   G = 128; B = 0   }
            @{ Name = 'blue';         R = 0;   G = 0;   B = 255 }
            @{ Name = 'yellow';       R = 255; G = 255; B = 0   }
            @{ Name = 'pink';         R = 255; G = 192; B = 203 }
            @{ Name = 'orange';       R = 255; G = 165; B = 0   }
            @{ Name = 'purple';       R = 128; G = 0;   B = 128 }
            @{ Name = 'light red';    R = 255; G = 128; B = 128 }
            @{ Name = 'light green';  R = 144; G = 238; B = 144 }
            @{ Name = 'light blue';   R = 173; G = 216; B = 230 }
            @{ Name = 'light yellow'; R = 255; G = 255; B = 224 }
            @{ Name = 'light pink';   R = 255; G = 218; B = 238 }
            @{ Name = 'light orange'; R = 255; G = 210; B = 150 }
            @{ Name = 'light purple'; R = 221; G = 160; B = 221 }
            @{ Name = 'dark red';     R = 139; G = 0;   B = 0   }
            @{ Name = 'dark green';   R = 0;   G = 100; B = 0   }
            @{ Name = 'dark blue';    R = 0;   G = 0;   B = 139 }
            @{ Name = 'dark yellow';  R = 204; G = 204; B = 0   }
            @{ Name = 'dark pink';    R = 220; G = 100; B = 130 }
            @{ Name = 'dark orange';  R = 255; G = 140; B = 0   }
            @{ Name = 'dark purple';  R = 75;  G = 0;   B = 130 }
        ) {
            InModuleScope LastWarAutoScreenshot -Parameters @{ Name = $Name; R = $R; G = $G; B = $B } {
                $colour = Resolve-MaskColour -ColourString $Name
                $colour | Should -Not -BeNullOrEmpty
                $colour.R | Should -Be $R
                $colour.G | Should -Be $G
                $colour.B | Should -Be $B
            }
        }

        It 'resolves "RED" (uppercase) correctly' {
            InModuleScope LastWarAutoScreenshot {
                $colour = Resolve-MaskColour -ColourString 'RED'
                $colour.R | Should -Be 255
                $colour.G | Should -Be 0
                $colour.B | Should -Be 0
            }
        }

        It 'resolves "DARK BLUE" (mixed case) correctly' {
            InModuleScope LastWarAutoScreenshot {
                $colour = Resolve-MaskColour -ColourString 'DARK BLUE'
                $colour.R | Should -Be 0
                $colour.G | Should -Be 0
                $colour.B | Should -Be 139
            }
        }

        It 'resolves "  light red  " (leading/trailing whitespace) correctly' {
            InModuleScope LastWarAutoScreenshot {
                $colour = Resolve-MaskColour -ColourString '  light red  '
                $colour.R | Should -Be 255
                $colour.G | Should -Be 128
                $colour.B | Should -Be 128
            }
        }

        It 'resolves "dark  blue" (extra internal whitespace) correctly' {
            InModuleScope LastWarAutoScreenshot {
                $colour = Resolve-MaskColour -ColourString 'dark  blue'
                $colour.R | Should -Be 0
                $colour.G | Should -Be 0
                $colour.B | Should -Be 139
            }
        }

        It 'returns $null and emits a warning for "light black"' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-Warning {}
                $result = Resolve-MaskColour -ColourString 'light black'
                $result | Should -BeNullOrEmpty
                Should -Invoke Write-Warning -Times 1
            }
        }

        It 'returns $null and emits a warning for "dark white"' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-Warning {}
                $result = Resolve-MaskColour -ColourString 'dark white'
                $result | Should -BeNullOrEmpty
                Should -Invoke Write-Warning -Times 1
            }
        }

        It 'returns $null for an unrecognised name "magenta"' {
            InModuleScope LastWarAutoScreenshot {
                $result = Resolve-MaskColour -ColourString 'magenta'
                $result | Should -BeNullOrEmpty
            }
        }

        It 'returns $null for "light magenta" (unrecognised base name)' {
            InModuleScope LastWarAutoScreenshot {
                $result = Resolve-MaskColour -ColourString 'light magenta'
                $result | Should -BeNullOrEmpty
            }
        }
    }

    Context 'RGB triplet parsing' {

        It 'parses "0,0,0" as black' {
            InModuleScope LastWarAutoScreenshot {
                $colour = Resolve-MaskColour -ColourString '0,0,0'
                $colour.R | Should -Be 0
                $colour.G | Should -Be 0
                $colour.B | Should -Be 0
            }
        }

        It 'parses "255,255,255" as white' {
            InModuleScope LastWarAutoScreenshot {
                $colour = Resolve-MaskColour -ColourString '255,255,255'
                $colour.R | Should -Be 255
                $colour.G | Should -Be 255
                $colour.B | Should -Be 255
            }
        }

        It 'parses "255,200,100" correctly' {
            InModuleScope LastWarAutoScreenshot {
                $colour = Resolve-MaskColour -ColourString '255,200,100'
                $colour.R | Should -Be 255
                $colour.G | Should -Be 200
                $colour.B | Should -Be 100
            }
        }

        It 'parses " 255 , 200 , 100 " (whitespace around commas) correctly' {
            InModuleScope LastWarAutoScreenshot {
                $colour = Resolve-MaskColour -ColourString ' 255 , 200 , 100 '
                $colour.R | Should -Be 255
                $colour.G | Should -Be 200
                $colour.B | Should -Be 100
            }
        }

        It 'returns $null for "256,0,0" (component out of range)' {
            InModuleScope LastWarAutoScreenshot {
                $result = Resolve-MaskColour -ColourString '256,0,0'
                $result | Should -BeNullOrEmpty
            }
        }

        It 'returns $null for "-1,0,0" (negative component)' {
            InModuleScope LastWarAutoScreenshot {
                $result = Resolve-MaskColour -ColourString '-1,0,0'
                $result | Should -BeNullOrEmpty
            }
        }

        It 'returns $null for "255,255" (only two components)' {
            InModuleScope LastWarAutoScreenshot {
                $result = Resolve-MaskColour -ColourString '255,255'
                $result | Should -BeNullOrEmpty
            }
        }

        It 'returns $null for "255,255,255,0" (four components)' {
            InModuleScope LastWarAutoScreenshot {
                $result = Resolve-MaskColour -ColourString '255,255,255,0'
                $result | Should -BeNullOrEmpty
            }
        }

        It 'returns $null for "abc,0,0" (non-numeric component)' {
            InModuleScope LastWarAutoScreenshot {
                $result = Resolve-MaskColour -ColourString 'abc,0,0'
                $result | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Hex code parsing' {

        It 'parses "000000" as black' {
            InModuleScope LastWarAutoScreenshot {
                $colour = Resolve-MaskColour -ColourString '000000'
                $colour.R | Should -Be 0
                $colour.G | Should -Be 0
                $colour.B | Should -Be 0
            }
        }

        It 'parses "FFFFFF" as white' {
            InModuleScope LastWarAutoScreenshot {
                $colour = Resolve-MaskColour -ColourString 'FFFFFF'
                $colour.R | Should -Be 255
                $colour.G | Should -Be 255
                $colour.B | Should -Be 255
            }
        }

        It 'parses "ffaa55" (lowercase) correctly' {
            InModuleScope LastWarAutoScreenshot {
                $colour = Resolve-MaskColour -ColourString 'ffaa55'
                $colour.R | Should -Be 255
                $colour.G | Should -Be 170
                $colour.B | Should -Be 85
            }
        }

        It 'parses "FFAA55" (uppercase) correctly' {
            InModuleScope LastWarAutoScreenshot {
                $colour = Resolve-MaskColour -ColourString 'FFAA55'
                $colour.R | Should -Be 255
                $colour.G | Should -Be 170
                $colour.B | Should -Be 85
            }
        }

        It 'parses "FfAa55" (mixed case) correctly' {
            InModuleScope LastWarAutoScreenshot {
                $colour = Resolve-MaskColour -ColourString 'FfAa55'
                $colour.R | Should -Be 255
                $colour.G | Should -Be 170
                $colour.B | Should -Be 85
            }
        }

        It 'parses "#FF0000" (leading hash) as red' {
            InModuleScope LastWarAutoScreenshot {
                $colour = Resolve-MaskColour -ColourString '#FF0000'
                $colour.R | Should -Be 255
                $colour.G | Should -Be 0
                $colour.B | Should -Be 0
            }
        }

        It 'parses "#ffaa55" (leading hash, lowercase) correctly' {
            InModuleScope LastWarAutoScreenshot {
                $colour = Resolve-MaskColour -ColourString '#ffaa55'
                $colour.R | Should -Be 255
                $colour.G | Should -Be 170
                $colour.B | Should -Be 85
            }
        }

        It 'returns $null for "FFAA5" (5 characters)' {
            InModuleScope LastWarAutoScreenshot {
                $result = Resolve-MaskColour -ColourString 'FFAA5'
                $result | Should -BeNullOrEmpty
            }
        }

        It 'returns $null for "FFAA556" (7 characters without hash)' {
            InModuleScope LastWarAutoScreenshot {
                $result = Resolve-MaskColour -ColourString 'FFAA556'
                $result | Should -BeNullOrEmpty
            }
        }

        It 'returns $null for "GGAA55" (invalid hex character)' {
            InModuleScope LastWarAutoScreenshot {
                $result = Resolve-MaskColour -ColourString 'GGAA55'
                $result | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Null and empty input' {

        It 'returns $null for $null input without warning' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-Warning {}
                $result = Resolve-MaskColour -ColourString $null
                $result | Should -BeNullOrEmpty
                Should -Invoke Write-Warning -Times 0
            }
        }

        It 'returns $null for empty string without warning' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-Warning {}
                $result = Resolve-MaskColour -ColourString ''
                $result | Should -BeNullOrEmpty
                Should -Invoke Write-Warning -Times 0
            }
        }

        It 'returns $null for whitespace-only string without warning' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-Warning {}
                $result = Resolve-MaskColour -ColourString '   '
                $result | Should -BeNullOrEmpty
                Should -Invoke Write-Warning -Times 0
            }
        }
    }

    Context 'Unrecognised input' {

        It 'returns $null and emits a warning for a completely unknown string' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-Warning {}
                $result = Resolve-MaskColour -ColourString 'chartreuse'
                $result | Should -BeNullOrEmpty
                Should -Invoke Write-Warning -Times 1
            }
        }

        It 'returns $null and emits a warning for a 4-component RGB-like string' {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-Warning {}
                $result = Resolve-MaskColour -ColourString '255,0,0,128'
                $result | Should -BeNullOrEmpty
                Should -Invoke Write-Warning -Times 1
            }
        }
    }
}
