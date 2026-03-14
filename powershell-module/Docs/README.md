# Last War AutoScript — User Guide

PowerShell 7+ module that automates human-like mouse interactions and screen
captures in Windows game windows — built specifically for Last War: Survival,
adaptable to any application.

> **Anti-cheat warning:** Automating input may violate the game's terms of
> service and could trigger anti-cheat systems. Use at your own risk. The
> authors take no responsibility for bans or account actions.

> **Contributing?** See [Developer.md](Developer.md) for the module
> architecture, testing guide, and how to add new screens.

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
Import-Module .\powershell-module\LastWarAutoScreenshot.psd1

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
| [ConsoleApp.md](ConsoleApp.md) | Entry point, screen navigation, macro folder, DLL versioning, `IAnsiConsole` injection |
| [Configuration.md](Configuration.md) | All config keys with types, defaults, and examples |
| [MacroFormat.md](MacroFormat.md) | Full JSON macro schema, action type reference, validation rules, annotated example files |
| [WindowManagement.md](WindowManagement.md) | Window state functions, monitoring, emergency stop |
| [Logging.md](Logging.md) | Log backends, levels, troubleshooting, Event Log registration |
| [ProjectPlan.md](ProjectPlan.md) | Full phase-by-phase task list and architecture decisions |

## Macro Recording

Macros let you record a sequence of mouse actions against a game window and
replay them on demand. All recording is done through the interactive console
app — no JSON editing required.

### Recording a macro — step by step

1. **Select a target window** first (main menu → "Select target window").
   The game window must be visible and **not** running in exclusive
   fullscreen mode — windowed or borderless-windowed mode is required so the
   module can read the window bounds.
2. From the main menu select **"Record macro"**.
3. Enter a name for the macro. Names may contain letters, digits, hyphens,
   and underscores only (`[a-zA-Z0-9_-]`, 1–50 characters). Spaces are
   auto-converted to hyphens with your confirmation.
4. Add actions one at a time from the action menu. For actions that require
   a position, move your mouse to the target location over the game window
   and press **Enter** in the console (the console must keep keyboard
   focus throughout recording).
5. After each coordinate capture you are offered **Accept / Redo / Cancel**.
   Accept confirms the position; Redo lets you re-capture; Cancel returns
   to the action menu.
6. Once you have added all the actions you want, select **"Save macro"** to
   write the file to `Private/Macros/`.

### Coordinate capture workflow

Each position action captures coordinates by:

1. Displaying a prompt telling you which point to position the mouse on
   (e.g. "Move your mouse to the target position, then press Enter...").
2. When you press **Enter**, the module reads the current cursor position and
   converts it to window-relative coordinates (0.0–1.0 on each axis).
3. The relative coordinates are shown for confirmation before you
   accept or redo.

If the cursor is outside the target window when you press Enter, a warning is
shown and you are asked to capture again — no explicit Redo is needed.

### Action types

| Action | Description |
|--------|-------------|
| **Move to point** | Move to an exact relative coordinate within the window. Capture one position. |
| **Move to region (box)** | Move to a random point within a rectangular region. Capture top-left then bottom-right corners. |
| **Move to region (circle)** | Move to a random point within a circular region. Capture the centre then a point on the edge. |
| **Left-click** | Click at the current cursor position (normally follows a Move action). No capture required. |
| **Drag-click** | Hold the left button, drag along a Bezier path, release. Capture start then end position. |
| **Screenshot region** | Mark a region for screenshot capture (deferred to Phase 6). Capture top-left then bottom-right. |
| **Delay** | Pause execution for a specified number of seconds (0.1–3600). |
| **Loop** | Repeat a set of named actions N times (1–10 000). Only available when named actions exist. |

### Creating loops

Loops let you repeat a set of named actions without manually duplicating
them in the sequence:

1. Give each action you want to loop an optional name when recording it.
2. Once at least one named (non-Loop) action exists, **"Create loop"** appears
   in the action menu.
3. Select the actions to include in the loop (you can add the same action
   more than once to create patterns like move → click → move → click).
4. Specify the iteration count (1–10 000).
5. Optionally give the loop itself a name.

> **Loops cannot reference other loops.** This is enforced at save time.

### Macro naming rules

- Characters: `[a-zA-Z0-9_-]` only.
- Length: 1–50 characters.
- Spaces are automatically converted to hyphens; you will be asked to
  confirm before the conversion is applied.
- Names must be unique among saved macros (case-insensitive comparison).

---

## Running Macros

### Selecting and running a saved macro

1. From the main menu select **"Run macro"** (only visible when at least one
   `*.json` file exists in `Private/Macros/`).
2. Choose the macro from the list (displayed as `<name> (dd/MM/yy HH:mm:ss)`).
3. A summary table shows all actions before you confirm.
4. Select **"Yes, run now"** to start execution.

The module validates the target window before running. If the window is not
open you will see an error and be returned to the macro list.

### Emergency stop integration

Two emergency stop mechanisms are available during macro execution:

- **Keyboard hotkey:** hold `Ctrl+Shift+#` simultaneously.
  - `#` is `0xDC` on UK keyboard layouts; on other layouts the key code
    may differ. See the Emergency Stop section for how to change it via
    the config app.
- **Mouse gesture:** hold both left and right mouse buttons for 3 seconds.

Either trigger halts the current action at the next safe check point,
displays how many actions completed, and exits cleanly.

### Target window validation

Before execution the macro runner checks:

- The current configured window handle is still valid (window is open).
- The configured `ProcessName` matches the macro's recorded `targetWindow`.

If the process names differ a warning is shown and you are given the option
to continue anyway or cancel.

### Screenshot actions during execution

Screenshot actions are logged as a warning and skipped — they do not cause
an error or halt the macro. Capture will be implemented in Phase 6.

---

## Managing Macros

From the main menu select **"Manage macros"** (always visible).

### Available operations

- **View details** — display macro metadata and the full action sequence.
- **Edit macro** — rename the macro, rename individual steps, or reorder
  steps (move up / move down). Saving updates the JSON file on disk.
- **Delete macro** — permanently removes the JSON file after confirmation.

### File location and naming convention

Macro files are stored in `Private/Macros/` within the module root.

**Filename format:** `yyyyMMdd_HHmmss_<name>.json`

The datetime prefix is the UTC creation timestamp and is preserved when
you rename a macro through the app.

**Example:** `20260310_143022_OpenAllianceShop.json`

### JSON format overview

Each macro file is a JSON object with four top-level keys:

```json
{
    "version": "1.0",
    "metadata": { "name": "...", "createdUtc": "...", "modifiedUtc": "...", "description": "" },
    "targetWindow": { "processName": "...", "windowTitle": "..." },
    "sequence": [ { "type": "...", ... }, ... ]
}
```

See [MacroFormat.md](MacroFormat.md) for the full schema, annotated example,
and action type reference.

---

## Roadmap

See [ProjectPlan.md](ProjectPlan.md). Current status: Phase 4 (Macro
Recording) in progress.

## License

MIT - see LICENSE file.

