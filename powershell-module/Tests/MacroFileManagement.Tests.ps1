BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

# ============================================================
# Save-MacroFile
# ============================================================

Describe 'Save-MacroFile' -Tag 'Unit' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot -Parameters @{ td = $TestDrive } {
            $script:MacrosPath = Join-Path $td 'Macros'
            Mock Write-LastWarLog
            Mock Test-MacroFile { [PSCustomObject]@{ Valid = $true; Messages = @() } }
        }
    }

    It 'returns Success=true and a non-empty FilePath when the macro is valid' {
        InModuleScope LastWarAutoScreenshot {
            $macroData = [PSCustomObject]@{
                metadata = [PSCustomObject]@{
                    name       = 'my-macro'
                    createdUtc = '2026-01-01T12:00:00Z'
                }
            }
            $result = Save-MacroFile -MacroData $macroData
            $result.Success  | Should -BeTrue
            $result.FilePath | Should -Not -BeNullOrEmpty
        }
    }

    It 'creates the Macros directory when it does not already exist' {
        InModuleScope LastWarAutoScreenshot -Parameters @{ td = $TestDrive } {
            $macrosDir = Join-Path $td 'Macros'
            # Clean up in case a previous test created the directory
            if (Test-Path -LiteralPath $macrosDir) {
                Remove-Item -Path $macrosDir -Recurse -Force | Out-Null
            }
            Test-Path -LiteralPath $macrosDir | Should -BeFalse

            $macroData = [PSCustomObject]@{
                metadata = [PSCustomObject]@{
                    name       = 'dir-test'
                    createdUtc = '2026-01-01T12:00:00Z'
                }
            }
            Save-MacroFile -MacroData $macroData | Out-Null

            Test-Path -LiteralPath $macrosDir | Should -BeTrue
        }
    }

    It 'generates a filename matching yyyyMMdd_HHmmss_<name>.json from createdUtc and name' {
        InModuleScope LastWarAutoScreenshot {
            $macroData = [PSCustomObject]@{
                metadata = [PSCustomObject]@{
                    name       = 'my-macro'
                    createdUtc = '2026-01-15T09:30:45Z'
                }
            }
            $result = Save-MacroFile -MacroData $macroData
            $result.FilePath | Should -Match '20260115_093045_my-macro\.json$'
        }
    }

    It 'writes valid JSON to disk whose content matches the input macro data' {
        InModuleScope LastWarAutoScreenshot {
            $macroData = [PSCustomObject]@{
                version  = '1.0'
                metadata = [PSCustomObject]@{
                    name       = 'content-check'
                    createdUtc = '2026-02-01T08:00:00Z'
                }
            }
            $result = Save-MacroFile -MacroData $macroData
            $raw    = Get-Content -LiteralPath $result.FilePath -Raw
            { $raw | ConvertFrom-Json } | Should -Not -Throw
            ($raw | ConvertFrom-Json).metadata.name | Should -Be 'content-check'
        }
    }

    It 'returns Success=false when the file already exists and -Force is not specified' {
        InModuleScope LastWarAutoScreenshot {
            $macroData = [PSCustomObject]@{
                metadata = [PSCustomObject]@{
                    name       = 'dup'
                    createdUtc = '2026-01-01T12:00:00Z'
                }
            }
            Save-MacroFile -MacroData $macroData | Out-Null  # first save

            $result = Save-MacroFile -MacroData $macroData   # second save, no -Force
            $result.Success | Should -BeFalse
        }
    }

    It 'returns Success=true when the file already exists and -Force is specified' {
        InModuleScope LastWarAutoScreenshot {
            $macroData = [PSCustomObject]@{
                metadata = [PSCustomObject]@{
                    name       = 'force-ok'
                    createdUtc = '2026-01-01T12:00:00Z'
                }
            }
            Save-MacroFile -MacroData $macroData | Out-Null
            $result = Save-MacroFile -MacroData $macroData -Force
            $result.Success | Should -BeTrue
        }
    }

    It 'returns Success=false and logs at Error level when macro fails validation' {
        InModuleScope LastWarAutoScreenshot {
            Mock Test-MacroFile { [PSCustomObject]@{ Valid = $false; Messages = @('missing version') } }
            $macroData = [PSCustomObject]@{
                metadata = [PSCustomObject]@{
                    name       = 'bad'
                    createdUtc = '2026-01-01T12:00:00Z'
                }
            }
            $result = Save-MacroFile -MacroData $macroData
            $result.Success | Should -BeFalse
            Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Error' } -Times 1
        }
    }

    It 'does not write any file when macro fails validation' {
        InModuleScope LastWarAutoScreenshot -Parameters @{ td = $TestDrive } {
            Mock Test-MacroFile { [PSCustomObject]@{ Valid = $false; Messages = @('bad') } }

            # Clean up any files from previous tests
            $macrosDir = Join-Path $td 'Macros'
            if (Test-Path -LiteralPath $macrosDir) {
                Remove-Item -Path $macrosDir -Recurse -Force | Out-Null
            }

            $macroData = [PSCustomObject]@{
                metadata = [PSCustomObject]@{
                    name       = 'no-write'
                    createdUtc = '2026-01-01T12:00:00Z'
                }
            }
            Save-MacroFile -MacroData $macroData | Out-Null

            $count = @(Get-ChildItem -Path $macrosDir -Filter '*.json' -ErrorAction SilentlyContinue).Count
            $count | Should -Be 0
        }
    }
}

# ============================================================
# Get-MacroFile
# ============================================================

Describe 'Get-MacroFile' -Tag 'Unit' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog
            Mock Test-MacroFile { [PSCustomObject]@{ Valid = $true; Messages = @() } }
        }
    }

    It 'returns a result with Valid=true and populated Data for a parseable JSON file' {
        $jsonPath = Join-Path $TestDrive '20260101_120000_valid.json'
        '{ "metadata": { "name": "valid-macro" } }' | Set-Content -Path $jsonPath -Encoding UTF8

        InModuleScope LastWarAutoScreenshot -Parameters @{ path = $jsonPath } {
            $result = Get-MacroFile -FilePath $path
            $result                    | Should -Not -BeNull
            $result.Valid              | Should -BeTrue
            $result.Data.metadata.name | Should -Be 'valid-macro'
        }
    }

    It 'returns $null and logs at Error level when the file does not exist' {
        InModuleScope LastWarAutoScreenshot {
            $result = Get-MacroFile -FilePath 'C:\nonexistent\missing.json'
            $result | Should -BeNull
            Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Error' } -Exactly 1
        }
    }

    It 'returns $null and logs at Error level when the file contains invalid JSON' {
        $badPath = Join-Path $TestDrive 'bad.json'
        'not { valid json !!!' | Set-Content -Path $badPath -Encoding UTF8

        InModuleScope LastWarAutoScreenshot -Parameters @{ path = $badPath } {
            $result = Get-MacroFile -FilePath $path
            $result | Should -BeNull
            Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Error' } -Exactly 1
        }
    }

    It 'returns Valid=false with non-empty Messages and populated Data when schema validation fails' {
        $jsonPath = Join-Path $TestDrive 'schema-fail.json'
        '{ "metadata": { "name": "ok" } }' | Set-Content -Path $jsonPath -Encoding UTF8

        InModuleScope LastWarAutoScreenshot -Parameters @{ path = $jsonPath } {
            Mock Test-MacroFile { [PSCustomObject]@{ Valid = $false; Messages = @('missing version') } }
            $result = Get-MacroFile -FilePath $path
            $result              | Should -Not -BeNull
            $result.Valid        | Should -BeFalse
            $result.Data         | Should -Not -BeNull
            $result.Messages     | Should -Contain 'missing version'
        }
    }
}

# ============================================================
# Get-LWASMacro
# ============================================================

Describe 'Get-LWASMacro' -Tag 'Unit' {

    BeforeEach {
        # Clean up the macros directory before each test to prevent file pollution
        $macrosDir = Join-Path $TestDrive 'Macros'
        if (Test-Path -LiteralPath $macrosDir) {
            Remove-Item -Path $macrosDir -Recurse -Force | Out-Null
        }

        InModuleScope LastWarAutoScreenshot -Parameters @{ td = $TestDrive } {
            $script:MacrosPath = Join-Path $td 'Macros'
            Mock Write-LastWarLog
            Mock Test-MacroFile { [PSCustomObject]@{ Valid = $true; Messages = @() } }
        }
    }

    It 'returns an empty array when the Macros folder does not exist' {
        InModuleScope LastWarAutoScreenshot -Parameters @{ td = $TestDrive } {
            # Point to a path that does not exist
            $script:MacrosPath = Join-Path $td 'NoSuchFolder\Macros'
            $result = @(Get-LWASMacro)
            $result.Count | Should -Be 0
        }
    }

    It 'returns an empty array when the macros folder exists but contains no JSON files' {
        $emptyDir = Join-Path $TestDrive 'Macros'
        New-Item -Path $emptyDir -ItemType Directory -Force | Out-Null

        InModuleScope LastWarAutoScreenshot {
            $result = @(Get-LWASMacro)
            $result.Count | Should -Be 0
        }
    }

    It 'returns entries sorted newest-first with correct Name and ActionCount' {
        $macrosDir = Join-Path $TestDrive 'Macros'
        New-Item -Path $macrosDir -ItemType Directory -Force | Out-Null

        $olderJson = '{"version":"1.0","metadata":{"name":"macro-older","createdUtc":"2026-01-01T12:00:00Z","modifiedUtc":"2026-01-01T12:00:00Z","description":""},"targetWindow":{"processName":"P","windowTitle":"T"},"sequence":[{"type":"LeftClick"}]}'
        $newerJson = '{"version":"1.0","metadata":{"name":"macro-newer","createdUtc":"2026-02-01T12:00:00Z","modifiedUtc":"2026-02-01T12:00:00Z","description":""},"targetWindow":{"processName":"P","windowTitle":"T"},"sequence":[{"type":"LeftClick"},{"type":"LeftClick"}]}'

        $olderJson | Set-Content -Path (Join-Path $macrosDir '20260101_120000_macro-older.json') -Encoding UTF8
        $newerJson | Set-Content -Path (Join-Path $macrosDir '20260201_120000_macro-newer.json') -Encoding UTF8

        InModuleScope LastWarAutoScreenshot {
            $result = @(Get-LWASMacro)
            $result.Count           | Should -Be 2
            $result[0].Name         | Should -Be 'macro-newer'
            $result[1].Name         | Should -Be 'macro-older'
            $result[0].ActionCount  | Should -Be 2
            $result[1].ActionCount  | Should -Be 1
        }
    }

    It 'excludes files with non-matching filename patterns and logs at Warning level' {
        $macrosDir = Join-Path $TestDrive 'Macros'
        New-Item -Path $macrosDir -ItemType Directory -Force | Out-Null
        '{}' | Set-Content -Path (Join-Path $macrosDir 'bad-filename.json') -Encoding UTF8

        InModuleScope LastWarAutoScreenshot {
            $result = @(Get-LWASMacro)
            $result.Count | Should -Be 0
            Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Warning' }
        }
    }

    It 'excludes corrupt JSON files and logs at Warning level' {
        $macrosDir = Join-Path $TestDrive 'Macros'
        New-Item -Path $macrosDir -ItemType Directory -Force | Out-Null
        'not valid json {' | Set-Content -Path (Join-Path $macrosDir '20260101_120000_corrupt.json') -Encoding UTF8

        InModuleScope LastWarAutoScreenshot {
            $result = @(Get-LWASMacro)
            $result.Count | Should -Be 0
            Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Warning' }
        }
    }

    It 'returns a DisplayDate string matching the dd/MM/yy HH:mm:ss format' {
        InModuleScope LastWarAutoScreenshot -Parameters @{ td = $TestDrive } {
            $script:MacrosPath = Join-Path $td 'Macros'
            $macrosDir = $script:MacrosPath
            if (-not (Test-Path -LiteralPath $macrosDir)) {
                New-Item -Path $macrosDir -ItemType Directory -Force | Out-Null
            }
            $json = '{"version":"1.0","metadata":{"name":"date-check","createdUtc":"2026-03-15T10:30:00Z","modifiedUtc":"2026-03-15T10:30:00Z","description":""},"targetWindow":{"processName":"P","windowTitle":"T"},"sequence":[{"type":"LeftClick"}]}'
            $macroFilePath = Join-Path $macrosDir '20260315_103000_date-check.json'
            $json | Set-Content -Path $macroFilePath -Encoding UTF8
            $result = @(Get-LWASMacro)
            $result.Count | Should -Be 1 | Out-Null
            $result[0].DisplayDate | Should -Match '^\d{2}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}$'
        }
    }

    Context '-Name filter' {

        BeforeEach {
            $macrosDir = Join-Path $TestDrive 'Macros'
            New-Item -Path $macrosDir -ItemType Directory -Force | Out-Null

            $json1 = '{"version":"1.0","metadata":{"name":"macro-one","createdUtc":"2026-01-01T12:00:00Z","modifiedUtc":"2026-01-01T12:00:00Z","description":""},"targetWindow":{"processName":"P","windowTitle":"T"},"sequence":[{"type":"LeftClick"}]}'
            $json2 = '{"version":"1.0","metadata":{"name":"macro-two","createdUtc":"2026-02-01T12:00:00Z","modifiedUtc":"2026-02-01T12:00:00Z","description":""},"targetWindow":{"processName":"P","windowTitle":"T"},"sequence":[{"type":"LeftClick"},{"type":"LeftClick"}]}'

            $json1 | Set-Content -Path (Join-Path $macrosDir '20260101_120000_macro-one.json') -Encoding UTF8
            $json2 | Set-Content -Path (Join-Path $macrosDir '20260201_120000_macro-two.json') -Encoding UTF8

            InModuleScope LastWarAutoScreenshot {
                Mock Write-Error { }
            }
        }

        It '-Name ''<name>'' returns only the matching macro' -TestCases @(
            @{ name = 'macro-one' }
            @{ name = 'macro-two' }
        ) {
            InModuleScope LastWarAutoScreenshot -Parameters @{ name = $name } {
                $result = @(Get-LWASMacro -Name $name)
                $result.Count   | Should -Be 1
                $result[0].Name | Should -Be $name
            }
        }

        It '-Name with an array returns all matching macros' {
            InModuleScope LastWarAutoScreenshot {
                $result = @(Get-LWASMacro -Name @('macro-one', 'macro-two'))
                $result.Count | Should -Be 2
            }
        }

        It '-Name with a comma-separated string returns all matching macros' {
            InModuleScope LastWarAutoScreenshot {
                $result = @(Get-LWASMacro -Name 'macro-one, macro-two')
                $result.Count | Should -Be 2
            }
        }

        It '-Name with an unknown name writes a non-terminating error and returns 0 results' {
            InModuleScope LastWarAutoScreenshot {
                $result = @(Get-LWASMacro -Name 'nonexistent')
                $result.Count | Should -Be 0
                Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*nonexistent*' }
            }
        }

        It '-Name with one match and one miss returns 1 result and writes 1 error for the miss' {
            InModuleScope LastWarAutoScreenshot {
                $result = @(Get-LWASMacro -Name @('macro-one', 'nonexistent'))
                $result.Count   | Should -Be 1
                $result[0].Name | Should -Be 'macro-one'
                Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*nonexistent*' }
            }
        }

        It 'accepts pipeline input of macro names and returns matching macros' {
            InModuleScope LastWarAutoScreenshot {
                $result = @('macro-one', 'macro-two' | Get-LWASMacro)
                $result.Count | Should -Be 2
            }
        }
    }

    Context 'returned object shape' {

        BeforeEach {
            $macrosDir = Join-Path $TestDrive 'Macros'
            New-Item -Path $macrosDir -ItemType Directory -Force | Out-Null

            $json = '{"version":"1.0","metadata":{"name":"shape-check","createdUtc":"2026-03-01T10:00:00Z","modifiedUtc":"2026-03-01T10:00:00Z","description":"desc"},"targetWindow":{"processName":"P","windowTitle":"T"},"sequence":[{"type":"LeftClick"},{"type":"LeftClick"}]}'
            $json | Set-Content -Path (Join-Path $macrosDir '20260301_100000_shape-check.json') -Encoding UTF8
        }

        It 'returned object has a non-null Metadata property containing the macro metadata' {
            InModuleScope LastWarAutoScreenshot {
                $result = @(Get-LWASMacro)
                $result[0].Metadata      | Should -Not -BeNull
                $result[0].Metadata.name | Should -Be 'shape-check'
            }
        }

        It 'returned object has a Sequence property with the correct action count' {
            InModuleScope LastWarAutoScreenshot {
                $result = @(Get-LWASMacro)
                $result[0].Sequence                 | Should -Not -BeNull
                @($result[0].Sequence).Count        | Should -Be 2
            }
        }

        It 'Sequence is an empty array when the macro JSON has no sequence property' {
            $macrosDir = Join-Path $TestDrive 'Macros'
            $noSeqJson = '{"version":"1.0","metadata":{"name":"no-seq","createdUtc":"2026-03-01T11:00:00Z","modifiedUtc":"2026-03-01T11:00:00Z","description":""},"targetWindow":{"processName":"P","windowTitle":"T"}}'
            $noSeqJson | Set-Content -Path (Join-Path $macrosDir '20260301_110000_no-seq.json') -Encoding UTF8

            InModuleScope LastWarAutoScreenshot {
                $result = @(Get-LWASMacro -Name 'no-seq')
                @($result[0].Sequence).Count | Should -Be 0
            }
        }
    }
}

# ============================================================
# Remove-MacroFile
# ============================================================

Describe 'Remove-MacroFile' -Tag 'Unit' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog
        }
    }

    It 'deletes the file, returns true, and logs at Info level when the file exists' {
        $filePath = Join-Path $TestDrive 'to-delete.json'
        'dummy' | Set-Content -Path $filePath -Encoding UTF8

        InModuleScope LastWarAutoScreenshot -Parameters @{ path = $filePath } {
            $result = Remove-MacroFile -FilePath $path
            $result                          | Should -BeTrue
            Test-Path -LiteralPath $path     | Should -BeFalse
            Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Info' } -Exactly 1
        }
    }

    It 'returns false and logs at Warning level when the file does not exist' {
        InModuleScope LastWarAutoScreenshot {
            $result = Remove-MacroFile -FilePath 'C:\nonexistent\missing.json'
            $result | Should -BeFalse
            Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Warning' } -Exactly 1
        }
    }
}

# ============================================================
# Rename-MacroFile
# ============================================================

Describe 'Rename-MacroFile' -Tag 'Unit' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot -Parameters @{ td = $TestDrive } {
            $script:MacrosPath = Join-Path $td 'Macros'
            Mock Write-LastWarLog
            Mock Get-LWASMacro { @() }
            Mock Get-MacroFile {
                [PSCustomObject]@{
                    Valid    = $true
                    Data     = [PSCustomObject]@{
                        metadata = [PSCustomObject]@{
                            name        = 'old-name'
                            modifiedUtc = '2026-01-01T12:00:00Z'
                        }
                    }
                    Messages = @()
                }
            }
        }

        # Create the macros directory and old file shared by most tests in this Describe
        $macrosDir = Join-Path $TestDrive 'Macros'
        New-Item -Path $macrosDir -ItemType Directory -Force | Out-Null
        'dummy' | Set-Content -Path (Join-Path $macrosDir '20260101_120000_old-name.json') -Encoding UTF8
    }

    It 'returns Success=true on a valid rename' {
        $oldPath = Join-Path $TestDrive 'Macros\20260101_120000_old-name.json'

        InModuleScope LastWarAutoScreenshot -Parameters @{ oldPath = $oldPath } {
            $result = Rename-MacroFile -FilePath $oldPath -NewName 'new-name'
            $result.Success | Should -BeTrue
        }
    }

    It 'creates the new file and deletes the old file on a valid rename' {
        $oldPath   = Join-Path $TestDrive 'Macros\20260101_120000_old-name.json'
        $newPath   = Join-Path $TestDrive 'Macros\20260101_120000_new-name.json'

        InModuleScope LastWarAutoScreenshot -Parameters @{ oldPath = $oldPath; newPath = $newPath } {
            Rename-MacroFile -FilePath $oldPath -NewName 'new-name' | Out-Null
            Test-Path -LiteralPath $newPath  | Should -BeTrue
            Test-Path -LiteralPath $oldPath  | Should -BeFalse
        }
    }

    It 'preserves the original datetime prefix in the new filename' {
        $oldPath = Join-Path $TestDrive 'Macros\20260101_120000_old-name.json'

        InModuleScope LastWarAutoScreenshot -Parameters @{ oldPath = $oldPath } {
            $result = Rename-MacroFile -FilePath $oldPath -NewName 'new-name'
            $result.NewFilePath | Should -Match '20260101_120000_new-name\.json$'
        }
    }

    It 'updates metadata.name to the new name in the written file' {
        $oldPath = Join-Path $TestDrive 'Macros\20260101_120000_old-name.json'

        InModuleScope LastWarAutoScreenshot -Parameters @{ oldPath = $oldPath } {
            $result  = Rename-MacroFile -FilePath $oldPath -NewName 'new-name'
            $content = Get-Content -LiteralPath $result.NewFilePath -Raw | ConvertFrom-Json
            $content.metadata.name | Should -Be 'new-name'
        }
    }

    It 'returns Success=false without changing files when the new name clashes with an existing macro' {
        $oldPath = Join-Path $TestDrive 'Macros\20260101_120000_old-name.json'

        InModuleScope LastWarAutoScreenshot -Parameters @{ oldPath = $oldPath } {
            Mock Get-LWASMacro {
                @([PSCustomObject]@{
                    FilePath = 'C:\other\20260201_120000_taken-name.json'
                    Name     = 'taken-name'
                })
            }
            $result = Rename-MacroFile -FilePath $oldPath -NewName 'taken-name'
            $result.Success                  | Should -BeFalse
            Test-Path -LiteralPath $oldPath  | Should -BeTrue
        }
    }

    It 'returns Success=false when the new name contains invalid characters' {
        $oldPath = Join-Path $TestDrive 'Macros\20260101_120000_old-name.json'

        InModuleScope LastWarAutoScreenshot -Parameters @{ oldPath = $oldPath } {
            $result = Rename-MacroFile -FilePath $oldPath -NewName 'bad name!'
            $result.Success | Should -BeFalse
        }
    }

    It 'returns Success=false when the source file does not exist' {
        InModuleScope LastWarAutoScreenshot {
            $result = Rename-MacroFile -FilePath 'C:\nonexistent\missing.json' -NewName 'new-name'
            $result.Success | Should -BeFalse
        }
    }

    It 'calls Write-LastWarLog at Info level on a successful rename' {
        $oldPath = Join-Path $TestDrive 'Macros\20260101_120000_old-name.json'

        InModuleScope LastWarAutoScreenshot -Parameters @{ oldPath = $oldPath } {
            Rename-MacroFile -FilePath $oldPath -NewName 'new-name' | Out-Null
            Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Info' } -Exactly 1
        }
    }
}
