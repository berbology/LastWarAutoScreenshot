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

### 1. Clone and import

```powershell
git clone https://github.com/berbology/LastWarAutoScreenshot.git
cd LastWarAutoScreenshot
Import-Module .\powershell-module\LastWarAutoScreenshot.psd1
```

### 2. Launch the app

```powershell
Start-LastWarAutoScreenshot
```

The interactive console app is your entry point for everything: selecting a
target window, adjusting mouse behaviour, configuring storage, and recording
macros. No manual JSON editing is required.

### 3. First run

On a clean install with no config file, `Start-LastWarAutoScreenshot` creates
a default `ModuleConfig.json` at:

```
%APPDATA%\LastWarAutoScreenshot\ModuleConfig.json
```

The main menu loads immediately. Nothing needs editing before you start.

### 4. Optional — register the Windows Event Log source

If you want log entries written to the Windows Event Log, run this **once**
in an elevated (Administrator) PowerShell session:

```powershell
New-EventLog -LogName Application -Source "LastWarAutoScreenshot"
```

File logging works without this step and is the default.

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
- **Macro recording** _(Phase 4)_ — record click sequences via the app and
  replay them on demand
- **Screenshot capture** _(Phase 6)_ — user-defined regions, PNG/JPEG,
  configurable naming
- **Task Scheduler integration** _(Phase 5)_ — automated, repeating execution

---

## Roadmap

See [ProjectPlan.md](powershell-module/Docs/ProjectPlan.md) for the full
phase-by-phase task list. Current status: Phase 4 (Macro Recording) in
progress.

## License

MIT — see the LICENSE file.
