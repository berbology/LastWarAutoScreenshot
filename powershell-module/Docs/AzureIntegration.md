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

The SAS token must be present in the environment variable named in the profile before any
upload runs. The module reads it at upload time — if the variable is not set the upload
fails with a clear error message.

### Temporary (current session only)

```powershell
$env:LWAS_AZURE_SAS = 'sv=2023-...&sig=...'
```

### Persistent (survives reboots, current user)

```powershell
[Environment]::SetEnvironmentVariable('LWAS_AZURE_SAS', 'sv=2023-...&sig=...', 'User')
```

Open a new PowerShell session after setting a persistent variable — the current session
will not pick up the change until restarted.

> **Token expiry:** Generate a new SAS token before the current one expires and update the
> environment variable. The profile itself does not need to be recreated.

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
| `Environment variable 'LWAS_AZURE_SAS' is not set` | The SAS token env var is missing or the variable name in the profile is wrong | Set the environment variable (see [Setting the SAS Token](#setting-the-sas-token-environment-variable)) and verify the `SasTokenEnvVar` field in the profile matches exactly |
| Upload fails with HTTP 403 | SAS token has expired or was generated with insufficient permissions | Generate a new SAS token with Write+List permissions on the container; update the environment variable |
| Upload fails with HTTP 404 | Container name or storage account name is wrong | Verify `accountName` and `containerName` in the profile match the Azure portal exactly; container names are lowercase |
| Some files upload but others fail | Transient Azure errors or network interruption | Check the log for details; re-run `Send-LWASScreenshots` — already-uploaded blobs will be overwritten (idempotent PUT) |
| `Upload profile 'xyz' not found` | Profile name was misspelled or the profile file was deleted | Run `Get-LWASUploadProfile` to list available profiles |
| No files uploaded, no error | `StoragePath` folder is empty or contains no PNG files | Confirm the folder contains screenshots; check `Screenshots.StoragePath` in the module config |
