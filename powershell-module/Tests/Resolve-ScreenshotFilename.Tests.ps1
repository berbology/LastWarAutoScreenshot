BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'Resolve-ScreenshotFilename' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
        }
    }

    # ── Placeholder substitution ────────────────────────────────────────────

    It '{MacroName} is replaced with the supplied MacroName' {
        InModuleScope LastWarAutoScreenshot {
            $result = Resolve-ScreenshotFilename `
                -Pattern '{MacroName}_shot' `
                -MacroName 'my-macro' -ActionName 'cap' -ActionType 'Screenshot' `
                -Index 1 -Format 'PNG'
            $result | Should -BeLike '*my-macro*'
        }
    }

    It '{ActionName} non-empty is replaced with ActionName' {
        InModuleScope LastWarAutoScreenshot {
            $result = Resolve-ScreenshotFilename `
                -Pattern '{ActionName}_shot' `
                -MacroName 'm' -ActionName 'my-action' -ActionType 'Screenshot' `
                -Index 1 -Format 'PNG'
            $result | Should -BeLike '*my-action*'
        }
    }

    It '{ActionName} empty string falls back to ActionType' {
        InModuleScope LastWarAutoScreenshot {
            $result = Resolve-ScreenshotFilename `
                -Pattern '{ActionName}_shot' `
                -MacroName 'm' -ActionName '' -ActionType 'Screenshot' `
                -Index 1 -Format 'PNG'
            $result | Should -BeLike '*Screenshot*'
        }
    }

    It '{ActionName} $null falls back to ActionType' {
        InModuleScope LastWarAutoScreenshot {
            $result = Resolve-ScreenshotFilename `
                -Pattern '{ActionName}_shot' `
                -MacroName 'm' -ActionName $null -ActionType 'Screenshot' `
                -Index 1 -Format 'PNG'
            $result | Should -BeLike '*Screenshot*'
        }
    }

    It '{Timestamp} matches yyyyMMdd_HHmmss pattern' {
        InModuleScope LastWarAutoScreenshot {
            $result = Resolve-ScreenshotFilename `
                -Pattern 'shot_{Timestamp}' `
                -MacroName 'm' -ActionName 'a' -ActionType 'Screenshot' `
                -Index 1 -Format 'PNG'
            $result | Should -Match '\d{8}_\d{6}'
        }
    }

    It '{Date} matches yyyyMMdd pattern' {
        InModuleScope LastWarAutoScreenshot {
            $result = Resolve-ScreenshotFilename `
                -Pattern 'shot_{Date}' `
                -MacroName 'm' -ActionName 'a' -ActionType 'Screenshot' `
                -Index 1 -Format 'PNG'
            $result | Should -Match '\d{8}'
        }
    }

    It '{Time} matches HHmmss pattern' {
        InModuleScope LastWarAutoScreenshot {
            $result = Resolve-ScreenshotFilename `
                -Pattern 'shot_{Time}' `
                -MacroName 'm' -ActionName 'a' -ActionType 'Screenshot' `
                -Index 1 -Format 'PNG'
            $result | Should -Match '\d{6}'
        }
    }

    It '{Index} = 1 produces 0001 in result' {
        InModuleScope LastWarAutoScreenshot {
            $result = Resolve-ScreenshotFilename `
                -Pattern 'shot_{Index}' `
                -MacroName 'm' -ActionName 'a' -ActionType 'Screenshot' `
                -Index 1 -Format 'PNG'
            $result | Should -BeLike '*0001*'
        }
    }

    It '{Index} = 9999 produces 9999 in result' {
        InModuleScope LastWarAutoScreenshot {
            $result = Resolve-ScreenshotFilename `
                -Pattern 'shot_{Index}' `
                -MacroName 'm' -ActionName 'a' -ActionType 'Screenshot' `
                -Index 9999 -Format 'PNG'
            $result | Should -BeLike '*9999*'
        }
    }

    It '{Index} = 10000 produces 10000 in result without truncation' {
        InModuleScope LastWarAutoScreenshot {
            $result = Resolve-ScreenshotFilename `
                -Pattern 'shot_{Index}' `
                -MacroName 'm' -ActionName 'a' -ActionType 'Screenshot' `
                -Index 10000 -Format 'PNG'
            $result | Should -BeLike '*10000*'
        }
    }

    # ── Extension ───────────────────────────────────────────────────────────

    It 'Format = PNG results in .png extension' {
        InModuleScope LastWarAutoScreenshot {
            $result = Resolve-ScreenshotFilename `
                -Pattern 'shot' `
                -MacroName 'm' -ActionName 'a' -ActionType 'Screenshot' `
                -Index 1 -Format 'PNG'
            $result | Should -BeLike '*.png'
        }
    }

    It 'Format = UNKNOWN returns $null and calls Write-LastWarLog with Level Error' {
        InModuleScope LastWarAutoScreenshot {
            $result = Resolve-ScreenshotFilename `
                -Pattern 'shot' `
                -MacroName 'm' -ActionName 'a' -ActionType 'Screenshot' `
                -Index 1 -Format 'UNKNOWN'
            $result | Should -BeNullOrEmpty
            Should -Invoke Write-LastWarLog -Times 1 -ParameterFilter { $Level -eq 'Error' }
        }
    }

    # ── Defensive sanitisation ──────────────────────────────────────────────

    It 'MacroName with a space has space replaced with underscore in result' {
        InModuleScope LastWarAutoScreenshot {
            $result = Resolve-ScreenshotFilename `
                -Pattern '{MacroName}_shot' `
                -MacroName 'my macro' -ActionName 'a' -ActionType 'Screenshot' `
                -Index 1 -Format 'PNG'
            $result | Should -Not -BeLike '* *'
            $result | Should -BeLike '*my_macro*'
        }
    }

    # ── Length validation ───────────────────────────────────────────────────

    It 'Pattern resolving to exactly 200 characters returns a non-null result' {
        InModuleScope LastWarAutoScreenshot {
            # Build a fixed-length pattern: 196 chars of 'a' + '.png' = 200 total
            $base = 'a' * 196
            $result = Resolve-ScreenshotFilename `
                -Pattern $base `
                -MacroName 'm' -ActionName 'a' -ActionType 'Screenshot' `
                -Index 1 -Format 'PNG'
            $result | Should -Not -BeNullOrEmpty
            $result.Length | Should -BeExactly 200
        }
    }

    It 'Pattern resolving to 201 characters returns $null, calls Write-LastWarLog Level Error with char count' {
        InModuleScope LastWarAutoScreenshot {
            # 197 chars of 'a' + '.png' = 201 total
            $base = 'a' * 197
            $result = Resolve-ScreenshotFilename `
                -Pattern $base `
                -MacroName 'm' -ActionName 'a' -ActionType 'Screenshot' `
                -Index 1 -Format 'PNG'
            $result | Should -BeNullOrEmpty
            Should -Invoke Write-LastWarLog -Times 1 -ParameterFilter {
                $Level -eq 'Error' -and $Message -like '*201*'
            }
        }
    }

    # ── Invalid input ───────────────────────────────────────────────────────

    It 'Pattern = empty string returns $null and calls Write-LastWarLog Level Error' {
        InModuleScope LastWarAutoScreenshot {
            $result = Resolve-ScreenshotFilename `
                -Pattern '' `
                -MacroName 'm' -ActionName 'a' -ActionType 'Screenshot' `
                -Index 1 -Format 'PNG'
            $result | Should -BeNullOrEmpty
            Should -Invoke Write-LastWarLog -Times 1 -ParameterFilter { $Level -eq 'Error' }
        }
    }

    # ── Full-pattern integration ────────────────────────────────────────────

    It 'Full pattern with all placeholders produces correctly formatted filename' {
        InModuleScope LastWarAutoScreenshot {
            $result = Resolve-ScreenshotFilename `
                -Pattern '{MacroName}_{ActionName}_{Timestamp}_{Index}' `
                -MacroName 'get-vs-scores' -ActionName 'vs-screenshot' `
                -ActionType 'Screenshot' -Index 3 -Format 'PNG'
            $result | Should -Match '^get-vs-scores_vs-screenshot_\d{8}_\d{6}_0003\.png$'
        }
    }
}
