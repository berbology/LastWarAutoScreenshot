# Last War Auto Screenshot

Automate human-like mouse interactions and screen
captures in Windows games and other applications - built predominantly for Last War: Survival

> **Anti-cheat warning:** Automating input may violate the game's terms of
> service and could trigger anti-cheat systems. Use at your own risk. The
> authors take no responsibility for bans or account actions.

---

## Contents

### Users

- [Get Started](#get-started)
- [Features](#features)
- [User Guide](powershell-module/Docs/UserGuide.md)
- [Configuration reference](powershell-module/Docs/Configuration.md)
- [Macro format reference](powershell-module/Docs/MacroFormat.md)
- [Examples](examples/)

### Developers

- [Developer Guide](powershell-module/Docs/Developer.md)
- [Console app architecture](powershell-module/Docs/ConsoleApp.md)
- [Window management](powershell-module/Docs/WindowManagement.md)
- [Logging](powershell-module/Docs/Logging.md)
- [Project plan](powershell-module/Docs/ProjectPlan.md)
- [Spectre.Console documentation](https://spectreconsole.net/)
- [Pester documentation](https://pester.dev)

---

## Requirements

- Windows 11
- PowerShell 7.0+
- Administrator privileges - Install script only

## Getting Started

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

For a first-use walkthrough (select window → record a macro → run it →
emergency stop) see [QuickStart.md](powershell-module/Docs/QuickStart.md).

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
- **Task Scheduler integration** - Automated execution via Windows Task Scheduler
- **ESP32-S3 USB hardware HID mouse toggle** _(planned)_ - Hardware device
  presenting as genuine physical HID mouse, toggled alongside the existing
  `SendInput` software approach; input arrives at driver level,
  indistinguishable from a physical mouse, providing greater resilience to
  anti-cheat detection

---

## Roadmap

See [ProjectPlan.md](powershell-module/Docs/ProjectPlan.md) for full
phase-by-phase task list. Current status: Phase 7 complete. Phase 8
(Documentation & Examples) in progress.

## License

MIT - see the LICENSE file.
