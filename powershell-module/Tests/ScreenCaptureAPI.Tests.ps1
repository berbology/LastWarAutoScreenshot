BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force

    # System.Drawing.Common is loaded by the module; make sure Bitmap is available here.
    Add-Type -AssemblyName 'System.Drawing.Common'
}

Describe 'ScreenCaptureAPI type verification' {
    It 'loads the ScreenCaptureAPI type without error' {
        { [LastWarAutoScreenshot.ScreenCaptureAPI] } | Should -Not -Throw
    }

    It 'PrintWindow static method exists' {
        $method = [LastWarAutoScreenshot.ScreenCaptureAPI].GetMethod('PrintWindow')
        $method | Should -Not -BeNullOrEmpty
    }

    It 'PW_RENDERFULLCONTENT constant equals 0x00000002' {
        [LastWarAutoScreenshot.ScreenCaptureAPI]::PW_RENDERFULLCONTENT | Should -BeExactly 2
    }
}

Describe 'Invoke-CaptureWindowRegion parameter validation' {
    It 'returns $false when WindowHandle is [IntPtr]::Zero' {
        InModuleScope LastWarAutoScreenshot {
            $result = Invoke-CaptureWindowRegion `
                -WindowHandle ([IntPtr]::Zero) `
                -RelativeX 0.0 -RelativeY 0.0 `
                -RelativeWidth 1.0 -RelativeHeight 1.0 `
                -OutputPath 'C:\Temp\out.png'
            $result | Should -BeFalse
        }
    }

    It 'returns $false when RelativeX is out of range (1.5)' {
        InModuleScope LastWarAutoScreenshot {
            $result = Invoke-CaptureWindowRegion `
                -WindowHandle ([IntPtr]1) `
                -RelativeX 1.5 -RelativeY 0.0 `
                -RelativeWidth 0.5 -RelativeHeight 0.5 `
                -OutputPath 'C:\Temp\out.png'
            $result | Should -BeFalse
        }
    }

    It 'returns $false when RelativeY is out of range (-0.1)' {
        InModuleScope LastWarAutoScreenshot {
            $result = Invoke-CaptureWindowRegion `
                -WindowHandle ([IntPtr]1) `
                -RelativeX 0.0 -RelativeY -0.1 `
                -RelativeWidth 0.5 -RelativeHeight 0.5 `
                -OutputPath 'C:\Temp\out.png'
            $result | Should -BeFalse
        }
    }

    It 'returns $false when RelativeWidth is zero' {
        InModuleScope LastWarAutoScreenshot {
            $result = Invoke-CaptureWindowRegion `
                -WindowHandle ([IntPtr]1) `
                -RelativeX 0.0 -RelativeY 0.0 `
                -RelativeWidth 0.0 -RelativeHeight 0.5 `
                -OutputPath 'C:\Temp\out.png'
            $result | Should -BeFalse
        }
    }

    It 'returns $false when RelativeX + RelativeWidth exceeds 1.0' {
        InModuleScope LastWarAutoScreenshot {
            $result = Invoke-CaptureWindowRegion `
                -WindowHandle ([IntPtr]1) `
                -RelativeX 0.5 -RelativeY 0.0 `
                -RelativeWidth 0.6 -RelativeHeight 0.5 `
                -OutputPath 'C:\Temp\out.png'
            $result | Should -BeFalse
        }
    }

    It 'returns $false when OutputPath is empty string' {
        InModuleScope LastWarAutoScreenshot {
            $result = Invoke-CaptureWindowRegion `
                -WindowHandle ([IntPtr]1) `
                -RelativeX 0.0 -RelativeY 0.0 `
                -RelativeWidth 1.0 -RelativeHeight 1.0 `
                -OutputPath ''
            $result | Should -BeFalse
        }
    }
}

Describe 'Invoke-CompareImages unit tests' {
    BeforeAll {
        # Helper: create a solid-colour 10x10 bitmap and save as PNG
        function New-TestBitmap {
            param(
                [string]$Path,
                [System.Drawing.Color]$Colour,
                [int]$Width = 10,
                [int]$Height = 10,
                [int]$ChannelDelta = 0
            )
            $bmp = [System.Drawing.Bitmap]::new($Width, $Height)
            for ($x = 0; $x -lt $Width; $x++) {
                for ($y = 0; $y -lt $Height; $y++) {
                    $r = [Math]::Min(255, $Colour.R + $ChannelDelta)
                    $g = [Math]::Min(255, $Colour.G + $ChannelDelta)
                    $b = [Math]::Min(255, $Colour.B + $ChannelDelta)
                    $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($r, $g, $b))
                }
            }
            $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
            $bmp.Dispose()
        }
    }

    It 'returns >= 0.98 for two identical bitmaps' {
        $path1 = Join-Path $TestDrive 'identical_a.png'
        $path2 = Join-Path $TestDrive 'identical_b.png'
        New-TestBitmap -Path $path1 -Colour ([System.Drawing.Color]::Red)
        New-TestBitmap -Path $path2 -Colour ([System.Drawing.Color]::Red)

        InModuleScope LastWarAutoScreenshot -Parameters @{ p1 = $path1; p2 = $path2 } {
            $result = Invoke-CompareImages -Path1 $p1 -Path2 $p2 -SampleCount 1000 -TolerancePerChannel 0 -FullScan $false
            $result | Should -BeGreaterOrEqual 0.98
        }
    }

    It 'returns >= 0.98 for bitmaps differing by 5 per channel (tolerancePerChannel = 10)' {
        $path1 = Join-Path $TestDrive 'tol_a.png'
        $path2 = Join-Path $TestDrive 'tol_b.png'
        New-TestBitmap -Path $path1 -Colour ([System.Drawing.Color]::FromArgb(100, 100, 100))
        New-TestBitmap -Path $path2 -Colour ([System.Drawing.Color]::FromArgb(100, 100, 100)) -ChannelDelta 5

        InModuleScope LastWarAutoScreenshot -Parameters @{ p1 = $path1; p2 = $path2 } {
            $result = Invoke-CompareImages -Path1 $p1 -Path2 $p2 -SampleCount 1000 -TolerancePerChannel 10 -FullScan $false
            $result | Should -BeGreaterOrEqual 0.98
        }
    }

    It 'returns <= 0.05 for completely different bitmaps (red vs blue)' {
        $path1 = Join-Path $TestDrive 'diff_a.png'
        $path2 = Join-Path $TestDrive 'diff_b.png'
        New-TestBitmap -Path $path1 -Colour ([System.Drawing.Color]::Red)
        New-TestBitmap -Path $path2 -Colour ([System.Drawing.Color]::Blue)

        InModuleScope LastWarAutoScreenshot -Parameters @{ p1 = $path1; p2 = $path2 } {
            $result = Invoke-CompareImages -Path1 $p1 -Path2 $p2 -SampleCount 1000 -TolerancePerChannel 0 -FullScan $false
            $result | Should -BeLessOrEqual 0.05
        }
    }

    It 'returns 0.0 for bitmaps with different dimensions' {
        $path1 = Join-Path $TestDrive 'dim_a.png'
        $path2 = Join-Path $TestDrive 'dim_b.png'
        New-TestBitmap -Path $path1 -Colour ([System.Drawing.Color]::Red) -Width 10 -Height 10
        New-TestBitmap -Path $path2 -Colour ([System.Drawing.Color]::Red) -Width 20 -Height 20

        InModuleScope LastWarAutoScreenshot -Parameters @{ p1 = $path1; p2 = $path2 } {
            $result = Invoke-CompareImages -Path1 $p1 -Path2 $p2 -SampleCount 1000 -TolerancePerChannel 0 -FullScan $false
            $result | Should -BeExactly 0.0
        }
    }

    It 'returns -1.0 when Path1 does not exist' {
        $path2 = Join-Path $TestDrive 'exists.png'
        New-TestBitmap -Path $path2 -Colour ([System.Drawing.Color]::Red)

        InModuleScope LastWarAutoScreenshot -Parameters @{ p2 = $path2 } {
            $result = Invoke-CompareImages -Path1 'C:\nonexistent\file.png' -Path2 $p2 -SampleCount 1000 -TolerancePerChannel 0 -FullScan $false
            $result | Should -BeOfType [double]
            $result | Should -Be (-1.0)
        }
    }

    It 'returns -1.0 when SampleCount is 0' {
        $path1 = Join-Path $TestDrive 'sc0_a.png'
        $path2 = Join-Path $TestDrive 'sc0_b.png'
        New-TestBitmap -Path $path1 -Colour ([System.Drawing.Color]::Red)
        New-TestBitmap -Path $path2 -Colour ([System.Drawing.Color]::Red)

        InModuleScope LastWarAutoScreenshot -Parameters @{ p1 = $path1; p2 = $path2 } {
            $result = Invoke-CompareImages -Path1 $p1 -Path2 $p2 -SampleCount 0 -TolerancePerChannel 0 -FullScan $false
            $result | Should -BeOfType [double]
            $result | Should -Be (-1.0)
        }
    }

    It 'returns -1.0 when TolerancePerChannel is -1 (invalid)' {
        $path1 = Join-Path $TestDrive 'tpc_a.png'
        $path2 = Join-Path $TestDrive 'tpc_b.png'
        New-TestBitmap -Path $path1 -Colour ([System.Drawing.Color]::Red)
        New-TestBitmap -Path $path2 -Colour ([System.Drawing.Color]::Red)

        InModuleScope LastWarAutoScreenshot -Parameters @{ p1 = $path1; p2 = $path2 } {
            $result = Invoke-CompareImages -Path1 $p1 -Path2 $p2 -SampleCount 1000 -TolerancePerChannel -1 -FullScan $false
            $result | Should -BeOfType [double]
            $result | Should -Be (-1.0)
        }
    }

    It 'returns >= 0.98 for two identical bitmaps with FullScan = $true' {
        $path1 = Join-Path $TestDrive 'fs_a.png'
        $path2 = Join-Path $TestDrive 'fs_b.png'
        New-TestBitmap -Path $path1 -Colour ([System.Drawing.Color]::Green)
        New-TestBitmap -Path $path2 -Colour ([System.Drawing.Color]::Green)

        InModuleScope LastWarAutoScreenshot -Parameters @{ p1 = $path1; p2 = $path2 } {
            $result = Invoke-CompareImages -Path1 $p1 -Path2 $p2 -SampleCount 1000 -TolerancePerChannel 0 -FullScan $true
            $result | Should -BeGreaterOrEqual 0.98
        }
    }

    It 'returns the same value on two successive calls (determinism)' {
        $path1 = Join-Path $TestDrive 'det_a.png'
        $path2 = Join-Path $TestDrive 'det_b.png'
        New-TestBitmap -Path $path1 -Colour ([System.Drawing.Color]::Red)
        New-TestBitmap -Path $path2 -Colour ([System.Drawing.Color]::Blue)

        InModuleScope LastWarAutoScreenshot -Parameters @{ p1 = $path1; p2 = $path2 } {
            $r1 = Invoke-CompareImages -Path1 $p1 -Path2 $p2 -SampleCount 1000 -TolerancePerChannel 0 -FullScan $false
            $r2 = Invoke-CompareImages -Path1 $p1 -Path2 $p2 -SampleCount 1000 -TolerancePerChannel 0 -FullScan $false
            $r1 | Should -BeExactly $r2
        }
    }
}

Describe 'ScreenCaptureAPI wrapper functions exist in module scope' {
    It 'Invoke-CaptureWindowRegion is available as a module command' {
        InModuleScope LastWarAutoScreenshot {
            $cmd = Get-Command Invoke-CaptureWindowRegion -ErrorAction SilentlyContinue
            $cmd | Should -Not -BeNullOrEmpty
        }
    }

    It 'Invoke-CompareImages is available as a module command' {
        InModuleScope LastWarAutoScreenshot {
            $cmd = Get-Command Invoke-CompareImages -ErrorAction SilentlyContinue
            $cmd | Should -Not -BeNullOrEmpty
        }
    }
}
