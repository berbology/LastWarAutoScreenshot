# Last War Auto Screenshot (LWAS)

Automate human-like mouse interactions and screen
captures in Windows games and other applications — built predominantly for Last War: Survival,
adaptable to any application.

> **Anti-cheat warning:** Automating input may violate the game's terms of
> service and could trigger anti-cheat systems. Use at your own risk. The
> authors take no responsibility for bans or account actions.

---

## Contents

### Users

- [Getting started](#getting-started)
- [Features](#features)
- [User Guide](powershell-module/Docs/UserGuide.md)
- [Quick Start Guide](powershell-module/Docs/QuickStart.md)
- [Configuration reference](powershell-module/Docs/Configuration.md)
- [Macro format reference](powershell-module/Docs/MacroFormat.md)
- [Example configuration file](examples/)

### Developers

- [Developer Guide](powershell-module/Docs/Developer.md)
- [Console app architecture](powershell-module/Docs/ConsoleApp.md)
- [Window management](powershell-module/Docs/WindowManagement.md)
- [Logging](powershell-module/Docs/Logging.md)
- [Project plan](powershell-module/Docs/ProjectPlan.md)
- [Spectre.Console documentation](https://spectreconsole.net/)
- [Pester v5 documentation](https://pester.dev)

---

## Requirements

- Windows 11
- PowerShell 7.0+
- Administrator privileges — install script only, registers Windows Event
  Log source, installs module in PSModulePath

## Getting started

### 1. Download and install

1. Download latest from [Releases](https://github.com/berbology/LastWarAutoScreenshot/releases)
2. Extract zip
3. Open PowerShell 7 in extracted folder and run:

   ```powershell
   .\scripts\Install-LWAS.ps1
   ```

Module install path:

```
$HOME\Documents\PowerShell\Modules\LastWarAutoScreenshot\{version}\
```

### 2. Launch the app

```powershell
Import-Module LastWarAutoScreenshot
Start-LWASConsole
```

The interactive console app allows you to select a
target application window, adjust mouse behaviour, configure screenshots and storage, record and run
macros.

See [Quick Start Guide](powershell-module/Docs/QuickStart.md) for a
step-by-step first-use walkthrough.


### 3. Target an application window

1. Open the game or application to target ensuring LWAS console and target window are visible
2. Select "target window" -> "Process name" -> Select target app from list
3. Save changes

### 4. Record macro

1. Select "Record macro"
2. Enter macro name eg. "my-macro-1"
3. Choose action to add to macro sequence and follow prompts
4. Name action eg. "click-score-icon-1" and save
5. When done adding macro sequence steps, select "Save macro"

---

### 5. Run macro

1. Ensure LWAS console and target window are visible
2. Select "Run macro"
3. Choose macro from list
4. Click "Run"

## Features

- **Interactive console app** — Spectre.Console-powered menus for setup
  and configuration
- **Window management** — enumerate all open windows, select target,
  auto-restore if minimised
- **Human-like mouse movement** — Bézier paths, ease-in/out, jitter,
  micro-pauses, and overshoot/correction to avoid bot detection
- **Flexible target regions** — define a bounding box or circle; each click
  lands at a random point within
- **Emergency stop** — `Ctrl+Shift+#` (UK layout) or hold both mouse buttons
  for 3 seconds to abort any running automation (key combination configurable in LWAS Console)
- **Configurable logging** — File, Windows Event Log, or both
- **Macro recording** — Record screenshots with or without masking (black-out) regions, mouse action sequences
- **Macro playback** — On demand or on a schedule
- **Screenshot capture** — User-defined regions, PNG/JPEG, configurable naming, optional masking (blackout) of screenshot regions
- **ESP32-S3 hardware HID mouse toggle** _(planned)_ — USB hardware device
  presenting as a genuine physical HID mouse; selectable alongside the existing
  `SendInput` software approach, providing greater resilience to anti-cheat (future release)
  detection
- **Task Scheduler integration** — automated, repeating execution

---

## Roadmap

See [ProjectPlan.md](powershell-module/Docs/ProjectPlan.md) for full
phase-by-phase task list. Phase 7 (Module Installation & Versioning) complete.
Phase 8 (Documentation & Examples) in progress.

## License

MIT — see LICENSE file.
