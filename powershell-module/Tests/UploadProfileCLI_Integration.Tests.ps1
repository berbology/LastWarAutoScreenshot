BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'UploadProfileCLI Integration' -Tag 'Integration' {

    BeforeAll {
        $script:integrationDir = Join-Path $env:TEMP "LWASCLIIntegration_$([System.Guid]::NewGuid().ToString('N'))"
        New-Item -Path $script:integrationDir -ItemType Directory -Force | Out-Null

        # Store original APPDATA so we can restore it
        $script:origAppData = $env:APPDATA
        $env:APPDATA = $script:integrationDir
    }

    AfterAll {
        $env:APPDATA = $script:origAppData
        if (Test-Path -LiteralPath $script:integrationDir) {
            Remove-Item -Path $script:integrationDir -Recurse -Force
        }
    }

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
            Mock Write-Warning {}
        }
        # Ensure the profiles directory is empty between tests
        $profilesDir = Join-Path $script:integrationDir 'LastWarAutoScreenshot\UploadProfiles'
        if (Test-Path -LiteralPath $profilesDir) {
            Get-ChildItem -Path $profilesDir -Filter '*.json' -ErrorAction SilentlyContinue |
                Remove-Item -Force
        }
        # Set a fake SAS token with a far-future expiry so Test-LWASSASTokenIsValid returns $true
        $env:LWAS_SAS_CLI_INT = 'sv=2020-08-04&se=2099-01-01T00:00:00Z&sp=racwdlup'
    }

    AfterEach {
        Remove-Item -Path Env:\LWAS_SAS_CLI_INT -ErrorAction SilentlyContinue
    }

    It 'New-LWASUploadProfile -> Get-LWASUploadProfile -> Remove-LWASUploadProfile round-trip' {
        InModuleScope LastWarAutoScreenshot {
            New-LWASUploadProfile -Name 'cli-test-1' -AccountName 'myaccount' `
                -ResourceGroupName 'my-rg' `
                -ContainerName 'screenshots' -SasTokenEnvVar 'LWAS_SAS_CLI_INT'

            $profiles = @(Get-LWASUploadProfile)
            $profiles.Count | Should -BeGreaterOrEqual 1
            ($profiles | Where-Object { $_.name -eq 'cli-test-1' }) | Should -Not -BeNull

            Remove-LWASUploadProfile -Name 'cli-test-1' -Force

            $afterRemove = @(Get-LWASUploadProfile)
            ($afterRemove | Where-Object { $_.name -eq 'cli-test-1' }) | Should -BeNull
        }
    }

    It 'New-LWASUploadProfile followed by Get-LWASUploadProfile -Name returns correct profile with all fields intact after JSON serialisation' {
        InModuleScope LastWarAutoScreenshot {
            New-LWASUploadProfile -Name 'cli-test-2' -AccountName 'storageacct' `
                -ResourceGroupName 'my-rg' `
                -ContainerName 'mycontainer' -SasTokenEnvVar 'LWAS_SAS_CLI_INT' `
                -BlobPathPattern '{MacroName}/{Date}/{Filename}' `
                -MaxRetryAttempts 5 -RetryBaseDelayMs 750 `
                -DeleteLocalAfterUpload -DeleteLocalAfterDays 7

            $loaded = Get-LWASUploadProfile -Name 'cli-test-2'

            $loaded                         | Should -Not -BeNull
            $loaded.name                    | Should -Be 'cli-test-2'
            $loaded.accountName             | Should -Be 'storageacct'
            $loaded.containerName           | Should -Be 'mycontainer'
            $loaded.sasTokenEnvVar          | Should -Be 'LWAS_SAS_CLI_INT'
            $loaded.blobPathPattern         | Should -Be '{MacroName}/{Date}/{Filename}'
            $loaded.maxRetryAttempts        | Should -Be 5
            $loaded.retryBaseDelayMs        | Should -Be 750
            $loaded.deleteLocalAfterUpload  | Should -BeTrue
            $loaded.deleteLocalAfterDays    | Should -Be 7
            $loaded.createdUtc              | Should -Not -BeNullOrEmpty
        }
    }

    It 'Remove-LWASUploadProfile -Force removes the file; subsequent Get-LWASUploadProfile -Name returns $null' {
        InModuleScope LastWarAutoScreenshot {
            New-LWASUploadProfile -Name 'cli-test-3' -AccountName 'acct' `
                -ResourceGroupName 'my-rg' `
                -ContainerName 'c' -SasTokenEnvVar 'LWAS_SAS_CLI_INT'

            $before = Get-LWASUploadProfile -Name 'cli-test-3'
            $before | Should -Not -BeNull

            Remove-LWASUploadProfile -Name 'cli-test-3' -Force

            $after = Get-LWASUploadProfile -Name 'cli-test-3'
            $after | Should -BeNull
        }
    }
}
