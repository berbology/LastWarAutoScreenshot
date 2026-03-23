BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Resolve-BlobPath' -Tag 'Unit' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
        }
    }

    It '2.2.1: Default pattern resolves {MacroName}, {Date}, and {Filename}' {
        InModuleScope LastWarAutoScreenshot {
            $fixedTime = [datetime]::new(2026, 3, 21, 14, 30, 0, [System.DateTimeKind]::Utc)
            $result = Resolve-BlobPath `
                -BlobPathPattern '{MacroName}/{Date}/{Filename}' `
                -MacroName 'my-macro' `
                -Filename 'screenshot_001.png' `
                -UploadTime $fixedTime

            $result | Should -Be 'my-macro/2026-03-21/screenshot_001.png'
        }
    }

    It '2.2.2: {Time} resolves to HH-mm-ss format' {
        InModuleScope LastWarAutoScreenshot {
            $fixedTime = [datetime]::new(2026, 3, 21, 9, 5, 7, [System.DateTimeKind]::Utc)
            $result = Resolve-BlobPath `
                -BlobPathPattern '{Time}' `
                -MacroName 'macro' `
                -Filename 'file.png' `
                -UploadTime $fixedTime

            $result | Should -Be '09-05-07'
        }
    }

    It '2.2.3: Unknown placeholder {Foo} is left unchanged in the output' {
        InModuleScope LastWarAutoScreenshot {
            $fixedTime = [datetime]::new(2026, 3, 21, 0, 0, 0, [System.DateTimeKind]::Utc)
            $result = Resolve-BlobPath `
                -BlobPathPattern '{MacroName}/{Foo}/{Filename}' `
                -MacroName 'macro' `
                -Filename 'file.png' `
                -UploadTime $fixedTime

            $result | Should -BeLike '*{Foo}*'
        }
    }

    It '2.2.3: Unknown placeholder logs a warning' {
        InModuleScope LastWarAutoScreenshot {
            $fixedTime = [datetime]::new(2026, 3, 21, 0, 0, 0, [System.DateTimeKind]::Utc)
            Resolve-BlobPath `
                -BlobPathPattern '{Foo}' `
                -MacroName 'macro' `
                -Filename 'file.png' `
                -UploadTime $fixedTime | Out-Null

            Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Warning' } -Times 1
        }
    }

    It '2.2.4: Pattern with no placeholders is returned unchanged' {
        InModuleScope LastWarAutoScreenshot {
            $fixedTime = [datetime]::new(2026, 3, 21, 0, 0, 0, [System.DateTimeKind]::Utc)
            $result = Resolve-BlobPath `
                -BlobPathPattern 'static/path/file.png' `
                -MacroName 'macro' `
                -Filename 'file.png' `
                -UploadTime $fixedTime

            $result | Should -Be 'static/path/file.png'
        }
    }

    It '2.2.5: MacroName containing - and _ characters is preserved as-is in the blob path' {
        InModuleScope LastWarAutoScreenshot {
            $fixedTime = [datetime]::new(2026, 3, 21, 0, 0, 0, [System.DateTimeKind]::Utc)
            $result = Resolve-BlobPath `
                -BlobPathPattern '{MacroName}/{Filename}' `
                -MacroName 'my-macro_name' `
                -Filename 'file.png' `
                -UploadTime $fixedTime

            $result | Should -Be 'my-macro_name/file.png'
        }
    }

    It '2.2.6: A fixed UploadTime value produces a deterministic output' {
        InModuleScope LastWarAutoScreenshot {
            $fixedTime = [datetime]::new(2026, 6, 15, 23, 59, 59, [System.DateTimeKind]::Utc)
            $result1 = Resolve-BlobPath `
                -BlobPathPattern '{MacroName}/{Date}/{Time}/{Filename}' `
                -MacroName 'macro' `
                -Filename 'img.png' `
                -UploadTime $fixedTime
            $result2 = Resolve-BlobPath `
                -BlobPathPattern '{MacroName}/{Date}/{Time}/{Filename}' `
                -MacroName 'macro' `
                -Filename 'img.png' `
                -UploadTime $fixedTime

            $result1 | Should -Be $result2
            $result1 | Should -Be 'macro/2026-06-15/23-59-59/img.png'
        }
    }
}
