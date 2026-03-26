BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'UploadProfileManagement Integration' -Tag 'Integration' {

    BeforeAll {
        $script:integrationDir = Join-Path $env:TEMP "LWASUploadProfilesIntegration_$([System.Guid]::NewGuid().ToString('N'))"
        New-Item -Path $script:integrationDir -ItemType Directory -Force | Out-Null
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:integrationDir) {
            Remove-Item -Path $script:integrationDir -Recurse -Force
        }
    }

    BeforeEach {
        # Clean the integration directory between tests
        Get-ChildItem -Path $script:integrationDir -Filter '*.json' -ErrorAction SilentlyContinue |
            Remove-Item -Force
    }

    It '1.6.1: Save-UploadProfileFile -> Get-UploadProfile round-trip preserves all fields' {
        InModuleScope LastWarAutoScreenshot -Parameters @{ dir = $script:integrationDir } {
            Mock Write-LastWarLog {}

            $profile = [PSCustomObject]@{
                name                  = 'round-trip'
                provider              = 'AzureBlobStorage'
                accountName           = 'myaccount'
                containerName         = 'screenshots'
                sasTokenEnvVar        = 'LWAS_AZURE_SAS_TOKEN_1'
                blobPathPattern       = '{MacroName}/{Date}/{Filename}'
                maxRetryAttempts      = 5
                retryBaseDelayMs      = 750
                deleteLocalAfterUpload = $true
                deleteLocalAfterDays  = 14
                createdUtc            = '2026-03-21T12:00:00Z'
                modifiedUtc           = '2026-03-21T12:00:00Z'
            }

            Save-UploadProfileFile -Profile $profile -ProfilesDirectory $dir

            $loaded = Get-UploadProfile -Name 'round-trip' -ProfilesDirectory $dir

            $loaded                         | Should -Not -BeNull
            $loaded.name                    | Should -Be 'round-trip'
            $loaded.provider                | Should -Be 'AzureBlobStorage'
            $loaded.accountName             | Should -Be 'myaccount'
            $loaded.containerName           | Should -Be 'screenshots'
            $loaded.sasTokenEnvVar          | Should -Be 'LWAS_AZURE_SAS_TOKEN_1'
            $loaded.blobPathPattern         | Should -Be '{MacroName}/{Date}/{Filename}'
            $loaded.maxRetryAttempts        | Should -Be 5
            $loaded.retryBaseDelayMs        | Should -Be 750
            $loaded.deleteLocalAfterUpload  | Should -BeTrue
            $loaded.deleteLocalAfterDays    | Should -Be 14
            $loaded.createdUtc.ToString('o') | Should -BeLike '2026-03-21T12:00:00*'
        }
    }

    It '1.6.2: Remove-LWASUploadProfile deletes the profile file from disk' {
        $profilesDir = Join-Path $env:APPDATA 'LastWarAutoScreenshot\UploadProfiles'
        $filePath    = Join-Path $profilesDir 'integration-to-remove.json'

        New-Item -Path $profilesDir -ItemType Directory -Force | Out-Null
        '{"name":"integration-to-remove"}' | Set-Content -Path $filePath -Encoding UTF8

        try {
            InModuleScope LastWarAutoScreenshot {
                Mock Write-LastWarLog {}
                Mock Remove-LWASSasToken {}
                Mock Get-UploadProfile {
                    [PSCustomObject]@{ name = 'integration-to-remove'; sasTokenEnvVar = $null }
                }

                Remove-LWASUploadProfile -Name 'integration-to-remove' -Force
            }

            Test-Path -LiteralPath $filePath | Should -BeFalse
        } finally {
            if (Test-Path -LiteralPath $filePath) {
                Remove-Item -LiteralPath $filePath -Force
            }
        }
    }

    It '1.6.3: Multiple saves -> Get-UploadProfile without -Name returns all profiles' {
        InModuleScope LastWarAutoScreenshot -Parameters @{ dir = $script:integrationDir } {
            Mock Write-LastWarLog {}

            $names = @('alpha', 'beta', 'gamma')
            foreach ($n in $names) {
                $p = [PSCustomObject]@{
                    name                  = $n
                    provider              = 'AzureBlobStorage'
                    accountName           = 'acct'
                    containerName         = 'c'
                    sasTokenEnvVar        = 'ENV'
                    blobPathPattern       = '{MacroName}/{Date}/{Filename}'
                    maxRetryAttempts      = 3
                    retryBaseDelayMs      = 500
                    deleteLocalAfterUpload = $false
                    deleteLocalAfterDays  = 30
                    createdUtc            = '2026-03-21T12:00:00Z'
                    modifiedUtc           = '2026-03-21T12:00:00Z'
                }
                Save-UploadProfileFile -Profile $p -ProfilesDirectory $dir
            }

            $result = @(Get-UploadProfile -ProfilesDirectory $dir)
            $result.Count | Should -Be 3
        }
    }
}
