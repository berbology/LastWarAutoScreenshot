# Last War AutoScript

PowerShell 7+ module that automates human-like mouse interactions and screen
captures in Windows game windows - built specifically for Last War: Survival,
adaptable to any application.

> **Anti-cheat warning:** Automating input may violate the game's ToS and
> could trigger anti-cheat systems. Use at your own risk. The authors take
> no responsibility for bans or account actions.

## Requirements

- Windows 11 64-bit
- PowerShell 7.0+
- Admin privileges (first run only, to register the Windows Event Log source)
- No third-party dependencies for core functionality

## Getting Started

```powershell
# Clone and import
git clone https://github.com/berbology/LastWarAutoScreenshot.git
cd LastWarAutoScreenshot
Import-Module .\LastWarAutoScreenshot\LastWarAutoScreenshot.psd1

# Launch the interactive app - this is your entry point
Start-LastWarAutoScreenshot
```

The app walks you through everything: picking a target window, configuring
mouse behaviour, setting up storage, and (Phase 4) recording macros.

### First run

On a clean install with no config file, `Start-LastWarAutoScreenshot` creates
a default `ModuleConfig.json` in `$env:APPDATA\LastWarAutoScreenshot\` and
presents the main menu immediately. No manual config editing needed.

If you need to register the Windows Event Log source (one-time, admin only):

```powershell
# Run once in an elevated session
New-EventLog -LogName Application -Source "LastWarAutoScreenshot"
```

## Features

- **Interactive console app** - Spectre.Console-powered menus for all setup
  and config; no manual JSON editing required
- **Window management** - enumerate all open windows, select your target,
  auto-restore if minimised
- **Human-like mouse movement** - Bezier paths, ease-in/out, jitter,
  micro-pauses, and overshoot/correction to dodge bot detection
- **Flexible target regions** - define a bounding box or circle; each click
  lands at a random point within it
- **Emergency stop** - `Ctrl+Shift+#` (UK) or hold both mouse buttons for
  3 s to abort any running automation
- **Configurable logging** - file, Windows Event Log, or both
- **Screenshot capture** (Phase 6) - user-defined regions, PNG/JPEG,
  configurable naming
- **Macro recording** (Phase 4) - record click sequences via the app
- **Task Scheduler integration** (Phase 5) - automated, repeating execution

## Documentation

| Doc | What it covers |
|-----|----------------|
| [ConsoleApp.md](ConsoleApp.md) | Entry point, screen navigation, macro folder,
DLL versioning, `IAnsiConsole` injection |
| [Configuration.md](Configuration.md) | All config keys with types, defaults,
and examples |
| [WindowManagement.md](WindowManagement.md) | Window state functions,
monitoring, emergency stop |
| [Logging.md](Logging.md) | Log backends, levels, troubleshooting,
Event Log registration |
| [ProjectPlan.md](ProjectPlan.md) | Full phase-by-phase task list and
architecture decisions |

## Testing

Tests use [Pester v5](https://pester.dev). Run the full suite from the repo root:

```powershell
Invoke-Pester -Path .\LastWarAutoScreenshot\Tests -Output Detailed
```

All tests must pass with 0 failures before any phase is marked complete.
See `Tests/ConsoleApp/README.md` for notes on the console UI test harness.

## Roadmap

See [ProjectPlan.md](ProjectPlan.md). Current status: Phase 3 (Console App)
complete. Phase 4 (Macro Recording) is next.

## License

MIT - see LICENSE file.

