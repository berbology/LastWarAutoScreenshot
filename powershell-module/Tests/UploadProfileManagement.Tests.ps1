BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

# ============================================================
# Get-UploadProfile
# ============================================================

Describe 'Get-UploadProfile' -Tag 'Unit' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
        }
    }

    It '1.5.1: Returns an empty array when the profiles directory does not exist' {
        InModuleScope LastWarAutoScreenshot -Parameters @{ td = $TestDrive } {
            $dir    = Join-Path $td 'NoSuchDir\UploadProfiles'
            $result = @(Get-UploadProfile -ProfilesDirectory $dir)
            $result.Count | Should -Be 0
        }
    }

    It '1.5.2: Returns two objects with all schema fields when two profile files exist' {
        $profilesDir = Join-Path $TestDrive 'Profiles_1_5_2'
        New-Item -Path $profilesDir -ItemType Directory -Force | Out-Null

        $json1 = '{"name":"profile-1","provider":"AzureBlobStorage","accountName":"acct1","containerName":"c1","sasTokenEnvVar":"ENV1","blobPathPattern":"{MacroName}/{Date}/{Filename}","maxRetryAttempts":3,"retryBaseDelayMs":500,"deleteLocalAfterUpload":false,"deleteLocalAfterDays":30,"createdUtc":"2026-03-21T12:00:00Z","modifiedUtc":"2026-03-21T12:00:00Z"}'
        $json2 = '{"name":"profile-2","provider":"AzureBlobStorage","accountName":"acct2","containerName":"c2","sasTokenEnvVar":"ENV2","blobPathPattern":"{MacroName}/{Date}/{Filename}","maxRetryAttempts":3,"retryBaseDelayMs":500,"deleteLocalAfterUpload":false,"deleteLocalAfterDays":30,"createdUtc":"2026-03-21T12:00:00Z","modifiedUtc":"2026-03-21T12:00:00Z"}'

        $json1 | Set-Content -Path (Join-Path $profilesDir 'profile-1.json') -Encoding UTF8
        $json2 | Set-Content -Path (Join-Path $profilesDir 'profile-2.json') -Encoding UTF8

        InModuleScope LastWarAutoScreenshot -Parameters @{ dir = $profilesDir } {
            $result = @(Get-UploadProfile -ProfilesDirectory $dir)
            $result.Count | Should -Be 2

            $schemaFields = @('name','provider','accountName','containerName','sasTokenEnvVar',
                              'blobPathPattern','maxRetryAttempts','retryBaseDelayMs',
                              'deleteLocalAfterUpload','deleteLocalAfterDays','createdUtc','modifiedUtc')
            foreach ($obj in $result) {
                foreach ($field in $schemaFields) {
                    $obj.PSObject.Properties[$field] | Should -Not -BeNull
                }
            }
        }
    }

    It '1.5.3: Returns the correct single object when -Name matches' {
        $profilesDir = Join-Path $TestDrive 'Profiles_1_5_3'
        New-Item -Path $profilesDir -ItemType Directory -Force | Out-Null

        $json1 = '{"name":"profile-1","provider":"AzureBlobStorage","accountName":"acct1","containerName":"c1","sasTokenEnvVar":"ENV1","blobPathPattern":"{MacroName}/{Date}/{Filename}","maxRetryAttempts":3,"retryBaseDelayMs":500,"deleteLocalAfterUpload":false,"deleteLocalAfterDays":30,"createdUtc":"2026-03-21T12:00:00Z","modifiedUtc":"2026-03-21T12:00:00Z"}'
        $json2 = '{"name":"profile-2","provider":"AzureBlobStorage","accountName":"acct2","containerName":"c2","sasTokenEnvVar":"ENV2","blobPathPattern":"{MacroName}/{Date}/{Filename}","maxRetryAttempts":3,"retryBaseDelayMs":500,"deleteLocalAfterUpload":false,"deleteLocalAfterDays":30,"createdUtc":"2026-03-21T12:00:00Z","modifiedUtc":"2026-03-21T12:00:00Z"}'

        $json1 | Set-Content -Path (Join-Path $profilesDir 'profile-1.json') -Encoding UTF8
        $json2 | Set-Content -Path (Join-Path $profilesDir 'profile-2.json') -Encoding UTF8

        InModuleScope LastWarAutoScreenshot -Parameters @{ dir = $profilesDir } {
            $result = Get-UploadProfile -Name 'profile-1' -ProfilesDirectory $dir
            $result           | Should -Not -BeNull
            $result.name      | Should -Be 'profile-1'
            $result.accountName | Should -Be 'acct1'
        }
    }

    It '1.5.4: Returns $null when -Name does not match any profile' {
        $profilesDir = Join-Path $TestDrive 'Profiles_1_5_4'
        New-Item -Path $profilesDir -ItemType Directory -Force | Out-Null

        InModuleScope LastWarAutoScreenshot -Parameters @{ dir = $profilesDir } {
            $result = Get-UploadProfile -Name 'does-not-exist' -ProfilesDirectory $dir
            $result | Should -BeNull
        }
    }

    It '1.5.5: Injects default values for missing optional fields' {
        $profilesDir = Join-Path $TestDrive 'Profiles_1_5_5'
        New-Item -Path $profilesDir -ItemType Directory -Force | Out-Null

        # Profile JSON with no blobPathPattern, maxRetryAttempts, retryBaseDelayMs,
        # deleteLocalAfterUpload, or deleteLocalAfterDays fields
        $minimalJson = '{"name":"minimal","accountName":"acct","containerName":"c","sasTokenEnvVar":"ENV","createdUtc":"2026-03-21T12:00:00Z","modifiedUtc":"2026-03-21T12:00:00Z"}'
        $minimalJson | Set-Content -Path (Join-Path $profilesDir 'minimal.json') -Encoding UTF8

        InModuleScope LastWarAutoScreenshot -Parameters @{ dir = $profilesDir } {
            $result = Get-UploadProfile -Name 'minimal' -ProfilesDirectory $dir
            $result                       | Should -Not -BeNull
            $result.blobPathPattern       | Should -Be '{MacroName}/{Date}/{Filename}'
            $result.maxRetryAttempts      | Should -Be 3
            $result.retryBaseDelayMs      | Should -Be 500
            $result.deleteLocalAfterUpload | Should -BeFalse
            $result.deleteLocalAfterDays  | Should -Be 30
        }
    }

    It '1.5.6: Save-UploadProfileFile calls New-Item, ConvertTo-Json, and Set-Content; modifiedUtc is updated' {
        InModuleScope LastWarAutoScreenshot -Parameters @{ td = $TestDrive } {
            $dir = Join-Path $td 'SaveTest_1_5_6'

            Mock New-Item {}
            Mock ConvertTo-Json { '{}' }
            Mock Set-Content {}
            Mock Write-LastWarLog {}

            $profile = [PSCustomObject]@{
                name          = 'test-profile'
                modifiedUtc   = '2020-01-01T00:00:00Z'
                accountName   = 'acct'
                containerName = 'c'
            }

            Save-UploadProfileFile -Profile $profile -ProfilesDirectory $dir

            Should -Invoke New-Item -Times 1 -ParameterFilter { $Path -eq $dir }
            Should -Invoke Set-Content -Times 1 -ParameterFilter { $Path -eq (Join-Path $dir 'test-profile.json') }
            $profile.modifiedUtc | Should -Not -Be '2020-01-01T00:00:00Z'
        }
    }

    It '1.5.7: Remove-UploadProfileFile calls Remove-Item with the correct path' {
        InModuleScope LastWarAutoScreenshot -Parameters @{ td = $TestDrive } {
            $dir      = Join-Path $td 'RemoveTest_1_5_7'
            $filePath = Join-Path $dir 'my-profile.json'

            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            'dummy' | Set-Content -Path $filePath -Encoding UTF8

            Mock Remove-Item {}
            Mock Write-LastWarLog {}

            Remove-UploadProfileFile -Name 'my-profile' -ProfilesDirectory $dir

            Should -Invoke Remove-Item -Times 1 -ParameterFilter { $LiteralPath -eq $filePath }
        }
    }

    It '1.5.8: Remove-UploadProfileFile calls Write-Error when the file does not exist' {
        InModuleScope LastWarAutoScreenshot -Parameters @{ td = $TestDrive } {
            $dir = Join-Path $td 'RemoveTest_1_5_8'
            New-Item -Path $dir -ItemType Directory -Force | Out-Null

            Mock Write-Error {}
            Mock Write-LastWarLog {}

            Remove-UploadProfileFile -Name 'nonexistent' -ProfilesDirectory $dir

            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*nonexistent*' }
        }
    }
}
