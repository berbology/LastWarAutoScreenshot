# Last War Auto Screenshot

Automate human-like mouse interactions and screen
captures in Windows games and other applications - built predominantly for Last War: Survival

> **Anti-cheat warning:** Automating input may violate the game's terms of
> service and could trigger anti-cheat systems. Use at your own risk. The
> authors take no responsibility for bans or account actions.

---

## Contents

### User

- [Getting Started](#getting-started)
- [Features](#features)
- [User Guide](powershell-module/Docs/UserGuide.md)
- [Configuration reference](powershell-module/Docs/Configuration.md)
- [Macro format reference](powershell-module/Docs/MacroFormat.md)
- [Azure Blob Storage integration](powershell-module/Docs/AzureIntegration.md)

### Developer

- [Developer Guide](powershell-module/Docs/Developer.md)
- [Console app architecture](powershell-module/Docs/ConsoleApp.md)
- [Configuration File Example](examples/)
- [Window management](powershell-module/Docs/WindowManagement.md)
- [Logging](powershell-module/Docs/Logging.md)
- [Project plan](powershell-module/Docs/ProjectPlan.md)
- [Spectre.Console documentation](https://spectreconsole.net/)
- [Pester documentation](https://pester.dev)

---

## Requirements

- Windows 11
- PowerShell 7.0+
- Administrator privileges - Install script only (self-elevating)

## Getting Started

For a detailed first-use walkthrough (select window → record a macro → run it →
emergency stop) see [QuickStart.md](powershell-module/Docs/QuickStart.md).

### 1. Download

1. Download latest from [Releases](https://github.com/berbology/LastWarAutoScreenshot/releases)
2. Extract zip.

### 2. Install

  ```powershell
  .\scripts\Install-LWAS.ps1
  ```

Module install path:

```
$HOME\Documents\PowerShell\Modules\LastWarAutoScreenshot\{version}\
```

### 2. Launch app

```powershell
Import-Module LastWarAutoScreenshot
Start-LWASConsole
```

The interactive console app is your entry point for everything: selecting a
target window, adjusting mouse behaviour, configuring storage, and running
macros.

### 3. Target a window

- Make sure application to target is open and visible
- In console app: Select target window -> Process name -> notepad.exe -> Save

### 4. Record macro

- Make sure application to target is open and visible
- In console app: Record macro -> Enter a name -> Add desired action -> Name step -> follow prompts -> Save
- Repeat for as many actions as desired the Save macro

### 5. Run macro

- Make sure application to target is open and visible
- In console app: Run macro -> Choose macro from list -> Run

---

## Features

- **Interactive console app** - Spectre.Console-powered configuration, macro creation, execution and scheduling
- **Cmdlets** - Control macro execution via Powershell cmdlets
- **Window management** - enumerate all open windows, select target,
  auto-restore if minimised
- **Human-like mouse movement** - Bézier paths, ease-in/out, jitter,
  micro-pauses, and overshoot/correction to avoid bot detection
- **Flexible target regions** - define a bounding box or circle; each click
  lands at a random point within it
- **Emergency stop** - `Ctrl+Alt+Q` (configurable)
- **Configurable logging** - File, Windows Event Log, or both
- **Macro recording** - record sequence via app and replay on demand
  - **Looping** - Create loop steps within macro sequences to repeat actions
- **Screenshot capture** - user-defined regions, PNG, configurable naming
  - **Region masking** - Optionally mask out one or more areas within the screenshot on-the-fly
- **Azure Blob Storage screenshot upload with retry** - upload profiles with SAS token auth,
  configurable blob path patterns, exponential backoff retry, and automatic local file cleanup
- **Task Scheduler integration** - Automated execution via Windows Task Scheduler
- **ESP32-S3 USB hardware HID mouse toggle** _(planned)_ - Hardware device
  presenting as genuine physical HID mouse, toggled alongside the existing
  `SendInput` software approach; input arrives at driver level,
  indistinguishable from a physical mouse, providing greater resilience to
  anti-cheat detection

---

## Command Reference

### Upload profiles

```powershell
# Create an upload profile (SAS token is generated automatically on save)
New-LWASUploadProfile -Name 'azure-1' -AccountName 'myaccount' `
    -ContainerName 'screenshots' -SasTokenEnvVar 'LWAS_SAS_PROD'

# List all profiles / get a specific profile
Get-LWASUploadProfile
Get-LWASUploadProfile -Name 'azure-1'

# Remove a profile
Remove-LWASUploadProfile -Name 'azure-1'

# Upload screenshots to Azure Blob Storage
Send-LWASScreenshots -UploadProfileName 'azure-1'
Send-LWASScreenshots -UploadProfileName 'azure-1' -WhatIf  # dry run

# Check whether a SAS token is still valid
Test-LWASSASTokenIsValid -SasToken $env:LWAS_SAS_PROD

# Renew the SAS token for a profile (requires Connect-AzAccount and Az.Storage)
Update-LWASSASToken -Profile (Get-LWASUploadProfile -Name 'azure-1')
Get-LWASUploadProfile | Update-LWASSASToken
```

See [AzureIntegration.md](powershell-module/Docs/AzureIntegration.md) for full setup instructions.

---

## Roadmap

See [ProjectPlan.md](powershell-module/Docs/ProjectPlan.md) for full
phase-by-phase task list. Current status: Phase 9b (Automated SAS Token Management).

## License

MIT - see the LICENSE file.
