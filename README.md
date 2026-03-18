# Last War AutoScript

PowerShell 7+ module that automates human-like mouse interactions and screen
captures in Windows game windows — built specifically for Last War: Survival,
adaptable to any application.

> **Anti-cheat warning:** Automating input may violate the game's terms of
> service and could trigger anti-cheat systems. Use at your own risk. The
> authors take no responsibility for bans or account actions.

---

## Contents

### For Users

- [Get Started](#get-started)
- [Features](#features)
- [User Guide](powershell-module/Docs/README.md)
- [Configuration reference](powershell-module/Docs/Configuration.md)
- [Macro format reference](powershell-module/Docs/MacroFormat.md)
- [Example configuration file](examples/)

### For Developers

- [Developer Guide](powershell-module/Docs/Developer.md)
- [Console app architecture](powershell-module/Docs/ConsoleApp.md)
- [Window management](powershell-module/Docs/WindowManagement.md)
- [Logging](powershell-module/Docs/Logging.md)
- [Project plan](powershell-module/Docs/ProjectPlan.md)
- [Spectre.Console documentation](https://spectreconsole.net/)

---

## Requirements

- Windows 11 64-bit
- PowerShell 7.0+
- Administrator privileges — first run only, to register the Windows Event
  Log source (optional; file logging works without admin)

## Get Started

### 1. Download and install

1. Go to the [Releases](https://github.com/berbology/LastWarAutoScreenshot/releases)
   page and download the latest `LastWarAutoScreenshot-v{version}.zip`.
2. Extract the zip to any folder.
3. Open a PowerShell 7 terminal in the extracted folder and run:

   ```powershell
   .\scripts\Install-LWAS.ps1
   ```

   The script self-elevates automatically — a UAC prompt will appear if your
   session is not already running as Administrator.

The module is installed to:

```
$HOME\Documents\PowerShell\Modules\LastWarAutoScreenshot\{version}\
```

### 2. Launch the app

Open any PowerShell 7 terminal and run:

```powershell
Import-Module LastWarAutoScreenshot
Start-LWASConsole
```

The interactive console app is your entry point for everything: selecting a
target window, adjusting mouse behaviour, configuring storage, and running
macros. No manual JSON editing is required.

### 3. First run

On a clean install with no config file, `Start-LWASConsole` creates
a default `ModuleConfig.json` at:

```
%APPDATA%\LastWarAutoScreenshot\ModuleConfig.json
```

The main menu loads immediately. Nothing needs editing before you start.

---

## Features

- **Interactive console app** — Spectre.Console-powered menus for all setup
  and configuration; no manual JSON editing required
- **Window management** — enumerate all open windows, select your target,
  auto-restore if minimised
- **Human-like mouse movement** — Bézier paths, ease-in/out, jitter,
  micro-pauses, and overshoot/correction to avoid bot detection
- **Flexible target regions** — define a bounding box or circle; each click
  lands at a random point within it
- **Emergency stop** — `Ctrl+Shift+#` (UK layout) or hold both mouse buttons
  for 3 seconds to abort any running automation
- **Configurable logging** — file, Windows Event Log, or both
- **Macro recording** — record screenshot, mouse action sequences via the app and replay them
  on demand
- **Screenshot capture** — user-defined regions, PNG/JPEG, configurable naming
- **ESP32-S3 hardware HID mouse toggle** _(planned)_ — USB hardware device
  presenting as a genuine physical HID mouse; selectable alongside the existing
  `SendInput` software approach, providing greater resilience to anti-cheat
  detection
- **Task Scheduler integration** _(Phase 5)_ — automated, repeating execution

---

## Roadmap

See [ProjectPlan.md](powershell-module/Docs/ProjectPlan.md) for the full
phase-by-phase task list. Phase 7 (Module Installation & Versioning) complete.
Phase 8 (Documentation & Examples) in progress.

## License

MIT — see the LICENSE file.
