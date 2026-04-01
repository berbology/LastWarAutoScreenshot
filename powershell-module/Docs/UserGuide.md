# Last War AutoScript — User Guide

This guide is for **end users** who want to install and use the module. If you
are contributing to the codebase, see [Developer.md](Developer.md) instead.

PowerShell 7+ module that automates human-like mouse interactions and screen
captures in Windows game windows — built specifically for Last War: Survival,
adaptable to any application.

> **Anti-cheat warning:** Automating input may violate the game's terms of
> service and could trigger anti-cheat systems. Use at your own risk. The
> authors take no responsibility for bans or account actions.

## Requirements

- Windows 11 64-bit
- PowerShell 7.0+
- Admin privileges (first run only, to register the Windows Event Log source)
- No third-party dependencies for core functionality

## Getting Started

Install the module — see the [main README](../../README.md#get-started).
Then launch the app:

```powershell
Import-Module LastWarAutoScreenshot
Start-LWASConsole
```

The app walks you through everything: picking a target window, configuring
mouse behaviour, setting up storage, recording macros, and capturing screenshots.

For a first-use walkthrough see [QuickStart.md](QuickStart.md).

### First run

On a clean install with no config file, `Start-LWASConsole` creates
a default `ModuleConfig.jsonc` in `$env:APPDATA\LastWarAutoScreenshot\` and
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
- **Emergency stop** - configurable hotkey combination (default `Ctrl+Alt+Q`)
- **Configurable logging** - file, Windows Event Log, or both
- **Screenshot capture** - user-defined window regions saved as PNG with
  configurable naming; similarity detection to automatically detect scroll-list end
- **Macro recording** - record click sequences via the app
- **Task Scheduler integration** - automated, repeating execution

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

1. From the main menu select **"Record macro"**. Window selection is the
   first step inside the recording flow. The game window must be visible and
   **not** running in exclusive fullscreen mode — windowed or
   borderless-windowed mode is required so the module can read the window
   bounds.
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
   write the file to disk.

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
| **Screenshot region** | Capture a region of the game window and save it to the configured storage path. Capture top-left then bottom-right. |
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
   saved macro exists).
2. Choose the macro from the list (displayed as `<name> (dd/MM/yy HH:mm:ss)`).
3. A summary table shows all actions before you confirm.
4. Select **"Yes, run now"** to start execution.

The module validates the target window before running. If the window is not
open you will see an error and be returned to the macro list.

### Emergency stop integration

An emergency stop mechanism is available during macro execution:

- **Keyboard hotkey:** hold `Ctrl+Alt+Q` simultaneously.
  - `#` is only a standalone key on UK keyboard layouts. On other layouts,
    reconfigure `EmergencyStop.HotkeyKeyNames` via **Configure module →
    Emergency stop settings** in the app (e.g. change to `"Ctrl+Shift+P"`).

This trigger halts the current action at the next safe check point,
displays how many actions completed, and exits cleanly.

### Target window validation

Before execution the macro runner checks:

- The current configured window handle is still valid (window is open).
- The configured `ProcessName` matches the macro's recorded `targetWindow`.

If the process names differ a warning is shown and you are given the option
to continue anyway or cancel.

### Screenshot actions during execution

When a macro reaches a `Screenshot` action the module captures the defined
window region and saves a PNG file to `Screenshots.StoragePath`. If
`StoragePath` is not configured a warning is logged and the action is skipped
— the macro continues normally without halting.

A pre-flight warning is shown before execution when the macro contains
`Screenshot` actions and `StoragePath` is not configured, giving you the
option to cancel or continue.

The game window must be open, visible, and in windowed or borderless-windowed
mode — minimised and exclusive-fullscreen windows cannot be captured.

---

## Screenshot Capture

Screenshot actions in a macro capture a defined region of the game window and
save a PNG file to disk. The game window must be in windowed or borderless-
windowed mode (not minimised, not exclusive fullscreen) — the module uses
`PrintWindow(PW_RENDERFULLCONTENT)` which captures OpenGL-rendered content via
DWM composition.

### Configuring screenshot storage

1. From the main menu select **Configure module → Screenshot settings**.
2. Set **Storage path** to a folder on a drive with enough free space.
3. Set **Max storage (GB)** to your preferred storage cap. The app warns you
   when usage reaches the warning threshold (default: 90%).

`Screenshots.StoragePath` must be set before screenshot actions will save
files. If it is empty a warning is logged per screenshot action and the macro
continues without capturing.

### Filename pattern

Files are named according to `Screenshots.FilenamePattern`. The default
pattern is:

```
{MacroName}_{ActionName}_{Timestamp}_{Index}
```

**Example output:**

```
get-vs-scores_vs-screenshot-region_20260307_143022_0001.png
```

| Placeholder | Description |
|-------------|-------------|
| `{MacroName}` | Macro name (filename-safe characters only) |
| `{ActionName}` | Action name, or `Screenshot` if the action has no name |
| `{Timestamp}` | UTC date-time at capture (`yyyyMMdd_HHmmss`) |
| `{Date}` | UTC date at capture (`yyyyMMdd`) |
| `{Time}` | UTC time at capture (`HHmmss`) |
| `{Index}` | Zero-padded sequential counter (resets each macro run) |

The resolved filename (excluding the storage path prefix) is capped at 200
characters. Only PNG is supported; the format is lossless and avoids
compression artefacts that could cause false positives in similarity detection.

---

## Screenshot Uploads

Upload profiles let you push captured screenshots to Azure Blob Storage automatically,
either as an inline macro step or on demand from the command line.

Each profile stores the storage account name, container name, and the *name* of the
environment variable that holds the SAS token — the token itself is never written to disk.

### Setting up a profile

Create a profile via the console app (**Configure module → Upload profiles → Add profile**)
or via the command line:

```powershell
New-LWASUploadProfile -Name 'azure-1' -AccountName 'myaccount' `
    -ContainerName 'screenshots' -SasTokenEnvVar 'LWAS_AZURE_SAS'
```

### Adding an upload step to a macro

Add an `UploadScreenshots` action to a macro sequence. Set the scope to `MacroSequence`
to upload all screenshots captured during the run, or `NamedStep` to upload only the
files captured by a specific named `Screenshot` action.

### Uploading from the command line

```powershell
Send-LWASScreenshots -UploadProfileName 'azure-1'
```

For full details — prerequisites, blob path patterns, retry behaviour, and
troubleshooting — see [AzureIntegration.md](AzureIntegration.md).

---

## Similarity Detection

Similarity detection automatically compares each new screenshot to the
previous one. When consecutive screenshots are sufficiently similar (indicating
a scroll-list end or otherwise static content) a configured action is triggered.

### Enabling similarity detection

From **Configure module → Screenshot settings** set **Similarity check
enabled** to `true`, then adjust the settings below to suit your use case.

### Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `SimilarityCheck.Enabled` | `false` | Enable or disable duplicate detection |
| `SimilarityCheck.Threshold` | `0.98` | Fraction of sampled pixels that must match (0.0–1.0). `0.98` = 98% match |
| `SimilarityCheck.SampleCount` | `1000` | Number of pixels sampled per comparison (ignored when `FullScan` is enabled) |
| `SimilarityCheck.FullScan` | `false` | Compare every pixel — more accurate but slower |
| `SimilarityCheck.TolerancePerChannel` | `10` | Maximum per-channel (R/G/B) difference that counts as a matching pixel. `0` = exact |
| `SimilarityCheck.Action` | `StopLoop` | What to do when the threshold is reached |
| `SimilarityCheck.ConsecutiveThreshold` | `1` | How many consecutive similar screenshots must occur before the action fires |

**Threshold** is entered and stored as a decimal (0.0–1.0). `0.98` means 98%
of sampled pixels match. Sampling is grid-based (not random) — results are
reproducible across runs.

**ConsecutiveThreshold** — set to `1` (default) to act on the first match.
Set higher (e.g. `3`) to avoid false positives on briefly static content.

### Action values

| Action | Behaviour |
|--------|-----------|
| `StopLoop` (default) | Exits the current loop; the parent sequence continues. Ideal for scroll loops. |
| `StopMacro` | Halts the entire macro. Use when the screenshot is at the top level, not inside a loop. |
| `Warn` | Logs a warning and continues. Useful for monitoring without stopping. |

`StopLoop` and `StopMacro` are both reported as **success** — reaching the
end of a scroll list is the intended outcome.

---

## Managing Macros

From the main menu select **"Manage macros"** (always visible).

### Available operations

- **View details** — display macro metadata and the full action sequence.
- **Edit macro** — rename the macro, rename individual steps, or reorder
  steps (move up / move down). Saving updates the JSON file on disk.
- **Delete macro** — permanently removes the JSON file after confirmation.

### File location and naming convention

Macro files are stored in `%APPDATA%\LastWarAutoScreenshot\Macros\`.

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

See [ProjectPlan.md](ProjectPlan.md). Current status: Phase 7 complete.
Phase 8 (Documentation & Examples) in progress.

## License

MIT - see LICENSE file.
