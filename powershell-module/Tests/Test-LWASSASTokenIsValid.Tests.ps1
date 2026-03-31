BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Test-LWASSASTokenIsValid' -Tag 'Unit' {

    # ── Helper: build a SAS token string with a given se= value ──────────────

    BeforeAll {
        function New-FakeSasToken {
            param([string]$ExpiryValue, [switch]$LeadingQuestion)
            $token = "sv=2021-06-08&ss=b&srt=o&sp=rwdlacupiytfx&se=$ExpiryValue&st=2026-01-01T00:00:00Z&spr=https&sig=FAKESIG"
            if ($LeadingQuestion) { $token = "?$token" }
            return $token
        }
    }

    # ── 2.2.1 ────────────────────────────────────────────────────────────────

    It '2.2.1: Empty string returns $false' {
        Test-LWASSASTokenIsValid -SasToken '' | Should -BeFalse
    }

    # ── 2.2.2 ────────────────────────────────────────────────────────────────

    It '2.2.2: Whitespace-only string returns $false' {
        Test-LWASSASTokenIsValid -SasToken '   ' | Should -BeFalse
    }

    # ── 2.2.3 ────────────────────────────────────────────────────────────────

    It '2.2.3: Token with no se= parameter returns $false' {
        $token = 'sv=2021-06-08&ss=b&srt=o&sp=rwdl&spr=https&sig=FAKESIG'
        Test-LWASSASTokenIsValid -SasToken $token | Should -BeFalse
    }

    # ── 2.2.4 ────────────────────────────────────────────────────────────────

    It '2.2.4: Token with se= 1 year in the future returns $true' {
        $future = [datetime]::UtcNow.AddYears(1).ToString('yyyy-MM-ddTHH:mm:ssZ')
        $token  = New-FakeSasToken -ExpiryValue $future
        Test-LWASSASTokenIsValid -SasToken $token | Should -BeTrue
    }

    # ── 2.2.5 ────────────────────────────────────────────────────────────────

    It '2.2.5: Token with se= in the past returns $false' {
        $past  = [datetime]::UtcNow.AddDays(-1).ToString('yyyy-MM-ddTHH:mm:ssZ')
        $token = New-FakeSasToken -ExpiryValue $past
        Test-LWASSASTokenIsValid -SasToken $token | Should -BeFalse
    }

    # ── 2.2.6 ────────────────────────────────────────────────────────────────

    It '2.2.6: Token expiring in exactly 3 minutes (within 5-minute buffer) returns $false' {
        $nearFuture = [datetime]::UtcNow.AddMinutes(3).ToString('yyyy-MM-ddTHH:mm:ssZ')
        $token      = New-FakeSasToken -ExpiryValue $nearFuture
        Test-LWASSASTokenIsValid -SasToken $token | Should -BeFalse
    }

    # ── 2.2.7 ────────────────────────────────────────────────────────────────

    It '2.2.7: Token expiring in exactly 6 minutes (outside 5-minute buffer) returns $true' {
        $safeFuture = [datetime]::UtcNow.AddMinutes(6).ToString('yyyy-MM-ddTHH:mm:ssZ')
        $token      = New-FakeSasToken -ExpiryValue $safeFuture
        Test-LWASSASTokenIsValid -SasToken $token | Should -BeTrue
    }

    # ── 2.2.8 ────────────────────────────────────────────────────────────────

    It '2.2.8: Token with malformed se= value returns $false' {
        $token = New-FakeSasToken -ExpiryValue 'not-a-date'
        Test-LWASSASTokenIsValid -SasToken $token | Should -BeFalse
    }

    # ── 2.2.9 ────────────────────────────────────────────────────────────────

    It '2.2.9: Token starting with ? has leading ? stripped and is parsed correctly' {
        $future = [datetime]::UtcNow.AddYears(1).ToString('yyyy-MM-ddTHH:mm:ssZ')
        $token  = New-FakeSasToken -ExpiryValue $future -LeadingQuestion

        $token | Should -BeLike '?*'
        Test-LWASSASTokenIsValid -SasToken $token | Should -BeTrue
    }

    # ── 2.2.10 ───────────────────────────────────────────────────────────────

    It '2.2.10: Realistic multi-parameter SAS token with se= in the middle returns $true for future expiry' {
        $future = [datetime]::UtcNow.AddMonths(6).ToString('yyyy-MM-ddTHH:mm:ssZ')
        $token  = "sv=2021-06-08&ss=b&srt=co&sp=rwdlacupiytfx&st=2026-03-01T00:00:00Z&se=$future&spr=https&sig=ABCDEF1234567890"
        Test-LWASSASTokenIsValid -SasToken $token | Should -BeTrue
    }

    It '2.2.10: Realistic multi-parameter SAS token with se= in the middle returns $false for past expiry' {
        $past  = [datetime]::UtcNow.AddMonths(-1).ToString('yyyy-MM-ddTHH:mm:ssZ')
        $token = "sv=2021-06-08&ss=b&srt=co&sp=rwdlacupiytfx&st=2025-01-01T00:00:00Z&se=$past&spr=https&sig=ABCDEF1234567890"
        Test-LWASSASTokenIsValid -SasToken $token | Should -BeFalse
    }
}
