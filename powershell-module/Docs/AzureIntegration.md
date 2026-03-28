# Azure Blob Storage Integration

This document covers screenshot upload to Azure Blob Storage — what the feature does,
how to set it up, and how to troubleshoot common problems.

---

## Overview

The upload feature lets you automatically push screenshots captured during macro execution
to an Azure Blob Storage container. Upload profiles store the connection settings; the SAS
token is never written to disk.

Two upload paths are available:

- **Inline macro step** — add an `UploadScreenshots` action to a macro so screenshots are
  uploaded immediately after they are captured, without any additional steps.
- **Command-line batch upload** — run `Send-LWASScreenshots` after a macro has finished to
  push all PNG files from the screenshots folder.

Both paths use the same upload profile and retry engine.

---

## Prerequisites

Before creating an upload profile you need:

1. **Azure Storage account** — create one in the Azure portal if you do not have one.
2. **Blob container** — create a container inside the storage account (e.g. `screenshots`).
3. **SAS token** — generate a Shared Access Signature with at minimum **Write** and **List**
   permissions scoped to the container. Set an expiry date that covers your expected usage period.

> **Security note:** The SAS token grants write access to your container. Treat it like a
> password. The module never stores the token on disk — it reads it from an environment
> variable at upload time.

---

## Setting Up an Upload Profile

### Via the console app

1. Launch the app: `Start-LWASConsole`
2. Navigate to **Configure module → Upload profiles → Add profile**.
3. Fill in the fields when prompted:
   - **Profile name** — letters, digits, hyphens, and underscores; 1–50 characters.
   - **Storage account name** — the Azure account name (e.g. `mystorageaccount`).
   - **Container name** — the blob container (e.g. `screenshots`).
   - **SAS token environment variable** — the name of the environment variable that will
     hold the token at runtime (e.g. `LWAS_AZURE_SAS`).
4. The profile is saved to `%APPDATA%\LastWarAutoScreenshot\UploadProfiles\{name}.json`.

### Via the command line

```powershell
# Minimal — uses all defaults
New-LWASUploadProfile `
    -Name            'azure-1' `
    -AccountName     'mystorageaccount' `
    -ContainerName   'screenshots' `
    -SasTokenEnvVar  'LWAS_AZURE_SAS'

# Full — all parameters specified
New-LWASUploadProfile `
    -Name                  'azure-daily' `
    -AccountName           'mystorageaccount' `
    -ContainerName         'screenshots' `
    -SasTokenEnvVar        'LWAS_AZURE_SAS' `
    -BlobPathPattern       '{MacroName}/{Date}/{Filename}' `
    -MaxRetryAttempts      5 `
    -RetryBaseDelayMs      1000 `
    -DeleteLocalAfterUpload `
    -DeleteLocalAfterDays  7
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Name` | _(required)_ | Profile name; `[a-zA-Z0-9_-]`, 1–50 characters |
| `AccountName` | _(required)_ | Azure Storage account name |
| `ContainerName` | _(required)_ | Blob container name |
| `SasTokenEnvVar` | _(required)_ | Name of the environment variable holding the SAS token |
| `BlobPathPattern` | `{MacroName}/{Date}/{Filename}` | Blob path pattern (see below) |
| `MaxRetryAttempts` | `3` | Retry attempts per file; 1–10 |
| `RetryBaseDelayMs` | `500` | Base retry delay in milliseconds; 100–60 000 |
| `DeleteLocalAfterUpload` | `$false` | Delete each local file after successful upload |
| `DeleteLocalAfterDays` | `30` | Delete local files older than N days; 1–3 650 |

#### Listing profiles

```powershell
Get-LWASUploadProfile           # all profiles
Get-LWASUploadProfile -Name 'azure-1'  # single profile
```

#### Removing a profile

```powershell
Remove-LWASUploadProfile -Name 'azure-1'          # prompts for confirmation
Remove-LWASUploadProfile -Name 'azure-1' -Force   # skips confirmation
Remove-LWASUploadProfile -Name 'azure-1' -WhatIf  # dry run
```

---

## Setting the SAS Token Environment Variable

When you save a profile through the console app or `New-LWASUploadProfile`, the module
checks the configured environment variable automatically. If the token is absent or within
five minutes of expiry, a new one-year SAS token is generated and stored for you — no
manual step is required.

If you prefer to set the token manually (for example, using a token generated outside this
module), you can still do so:

### Temporary (current session only)

```powershell
$env:LWAS_SAS_PROD = 'sv=2023-...&sig=...'
```

### Persistent (survives reboots, current user)

```powershell
Set-LWASSasToken -Name 'LWAS_SAS_PROD' -Token 'sv=2023-...&sig=...'
```

Or via the .NET API directly:

```powershell
[Environment]::SetEnvironmentVariable('LWAS_SAS_PROD', 'sv=2023-...&sig=...', 'User')
```

> **Naming convention:** All environment variables managed by this module must begin with
> `LWAS_SAS_` (e.g. `LWAS_SAS_PROD`, `LWAS_SAS_DEV`). This prefix is enforced when
> creating profiles and makes managed variables easy to identify.

---

## Automated SAS Token Management

SAS tokens are checked and renewed automatically whenever a profile is saved, so you do
not need to track expiry dates or regenerate tokens manually.

### Prerequisites

- **Az.Storage PowerShell module** — install once per machine:

  ```powershell
  Install-Module Az.Storage -Scope CurrentUser
  ```

- **Active Azure session** — authenticate before saving a profile or calling
  `Update-LWASSASToken`:

  ```powershell
  Connect-AzAccount
  ```

  The module does not call `Connect-AzAccount` automatically. If the session is not
  authenticated when a token is needed, a clear error message is shown with instructions
  to reconnect.

### How automatic renewal works

1. After a profile is saved (via the console app or `New-LWASUploadProfile`), the module
   reads the token from the `sasTokenEnvVar` environment variable.
2. `Test-LWASSASTokenIsValid` checks the `se=` (signed expiry) field in the token. A
   five-minute safety buffer is applied — a token expiring within five minutes is treated
   as expired.
3. If the token is absent or within the buffer period, `Update-LWASSASToken`
   generates a new token with a one-year expiry using `Az.Storage` and stores it at
   Windows User scope (persists across sessions) and in the current process scope
   (available immediately without restarting PowerShell).

### LWAS_SAS_ naming convention

All `sasTokenEnvVar` values must begin with `LWAS_SAS_` followed by a suffix of 1–30
letters, digits, or underscores (e.g. `LWAS_SAS_PROD`). The full name is uppercased on
save. This convention:

- Prevents collisions with unrelated environment variables.
- Makes all module-managed token variables discoverable via `Get-LWASSASToken`.
- Ensures consistency between the console UI and command-line paths.

### Manual renewal

To renew a token for a specific profile without re-saving it:

```powershell
Update-LWASSASToken -Profile (Get-LWASUploadProfile -Name 'azure-1')
```

To renew tokens for all profiles at once:

```powershell
Get-LWASUploadProfile | Update-LWASSASToken
```

### Checking a token

```powershell
Test-LWASSASTokenIsValid -SasToken $env:LWAS_SAS_PROD
```

Returns `$true` if the token is present and has more than five minutes remaining; `$false`
otherwise. No network call is made — only the `se=` field in the token string is inspected.

---

## Blob Path Pattern Reference

The `BlobPathPattern` controls where blobs are stored inside the container. The following
placeholders are supported:

| Placeholder | Value |
|-------------|-------|
| `{MacroName}` | Name of the macro that captured the screenshot |
| `{Date}` | UTC date at upload time (`yyyy-MM-dd`) |
| `{Time}` | UTC time at upload time (`HH-mm-ss`) |
| `{Filename}` | Original local filename including extension |

**Default pattern:** `{MacroName}/{Date}/{Filename}`

**Example blob path:** `get-vs-scores/2026-03-21/get-vs-scores_vs-shot_20260321_143022_0001.png`

Custom patterns may include literal path separators:

```
screenshots/{MacroName}/{Date}/{Time}/{Filename}
raw/{Filename}
```

---

## Adding an UploadScreenshots Step to a Macro

`UploadScreenshots` is a macro action type that uploads screenshots captured during the
current macro run. The action is recorded through the console app
(**Record macro → Add action → Upload screenshots**) or authored directly in the macro JSON.

### Scope options

| Scope | Behaviour |
|-------|-----------|
| `MacroSequence` | Uploads **all** screenshots captured during the entire current macro run |
| `NamedStep` | Uploads only screenshots captured by a specific named `Screenshot` action |

`MacroSequence` is the most common choice. Use `NamedStep` when a macro contains multiple
screenshot regions and you want to upload only one of them.

### JSON schema

```json
{
    "type": "UploadScreenshots",
    "name": "upload-to-azure",
    "uploadProfileName": "azure-1",
    "scope": "MacroSequence"
}
```

```json
{
    "type": "UploadScreenshots",
    "name": "upload-vs-shots",
    "uploadProfileName": "azure-1",
    "scope": "NamedStep",
    "screenshotActionName": "vs-screenshot-region"
}
```

> **Placement:** The `UploadScreenshots` step is blocking and executes synchronously.
> A warning is shown at save time if the step is not the last action in the sequence,
> because no screenshots captured after this point will be included in the upload.

---

## Running an Upload from the Command Line

`Send-LWASScreenshots` uploads all PNG files in the configured screenshots folder (or a
folder you specify) using the named profile.

```powershell
# Upload all PNGs from the configured StoragePath
Send-LWASScreenshots -UploadProfileName 'azure-1'

# Upload from a specific folder
Send-LWASScreenshots -UploadProfileName 'azure-1' -FolderPath 'C:\Screenshots'

# Preview what would be uploaded without transferring anything
Send-LWASScreenshots -UploadProfileName 'azure-1' -WhatIf

# Custom file filter
Send-LWASScreenshots -UploadProfileName 'azure-1' -Filter '2026-03-21*.png'
```

A progress bar is displayed during the upload. Failures are logged as warnings; the
command continues to attempt remaining files.

---

## Local File Retention

Two independent per-profile controls manage local file clean-up:

| Setting | Default | Description |
|---------|---------|-------------|
| `DeleteLocalAfterUpload` | `$false` | Delete each local file immediately after a successful upload. Failed uploads are not deleted. |
| `DeleteLocalAfterDays` | `30` | Delete all local screenshot files older than N days from `StoragePath` at the end of each upload run, regardless of upload status. |

Both controls may be active simultaneously. For example, setting `DeleteLocalAfterUpload`
and `DeleteLocalAfterDays 7` deletes successfully uploaded files immediately and also
purges any remaining files older than 7 days at the end of the run.

---

## Retry Behaviour

Each file upload is retried automatically on failure using exponential backoff with jitter.

**Delay formula:**

```
delay = min(baseDelayMs × 2^(attempt − 1) + random(0, baseDelayMs), 30 000 ms)
```

With the default `RetryBaseDelayMs = 500` and `MaxRetryAttempts = 3`:

| Attempt | Approximate max delay |
|---------|-----------------------|
| 1       | 500 ms |
| 2       | 1 000 ms + jitter |
| 3       | 2 000 ms + jitter |

**Retryable HTTP status codes:** 429, 500, 502, 503, 504

**Non-retryable HTTP status codes:** 400, 401, 403, 404 — the upload fails immediately
without retrying, as these indicate a configuration error rather than a transient fault.

---

## Troubleshooting

| Symptom | Likely cause | Resolution |
|---------|-------------|------------|
| `Environment variable 'LWAS_SAS_PROD' is not set` | The SAS token env var is missing or the variable name in the profile is wrong | Save the profile again to trigger auto-renewal, or run `Update-LWASSASToken` manually after connecting to Azure |
| Upload fails with HTTP 403 | SAS token has expired or was generated with insufficient permissions | Run `Update-LWASSASToken -Profile (Get-LWASUploadProfile -Name 'azure-1')` to renew; ensure the token has Write+List permissions |
| Upload fails with HTTP 404 | Container name or storage account name is wrong | Verify `accountName` and `containerName` in the profile match the Azure portal exactly; container names are lowercase |
| Some files upload but others fail | Transient Azure errors or network interruption | Check the log for details; re-run `Send-LWASScreenshots` — already-uploaded blobs will be overwritten (idempotent PUT) |
| `Upload profile 'xyz' not found` | Profile name was misspelled or the profile file was deleted | Run `Get-LWASUploadProfile` to list available profiles |
| No files uploaded, no error | `StoragePath` folder is empty or contains no PNG files | Confirm the folder contains screenshots; check `Screenshots.StoragePath` in the module config |
| `Az.Storage` module not found | `Az.Storage` is not installed | Run `Install-Module Az.Storage -Scope CurrentUser` then retry |
| `Connect-AzAccount` not authenticated | Azure session has expired or was never started | Run `Connect-AzAccount` to authenticate, then retry the operation |
| `Test-LWASSASTokenIsValid` returns `$false` for a token with time remaining | The token expires within the five-minute safety buffer | This is expected behaviour — the module treats tokens expiring within five minutes as expired to avoid race conditions. Renew early by running `Update-LWASSASToken` |
| `SasTokenEnvVar must begin with 'LWAS_SAS_'` | The supplied env var name does not follow the required naming convention | Use a name beginning with `LWAS_SAS_` (e.g. `LWAS_SAS_PROD`). This prefix is required for all profiles managed by this module |
