# Quick Start Guide

A first-use walkthrough covering the four essential tasks: select a target
window, record a macro, run it, and stop it. For the complete feature reference
see the [User Guide](UserGuide.md).

---

## Prerequisites

- **Module installed** — follow the
  [installation steps](../../README.md#get-started) in the root README if you
  have not done this yet.
- **Game running in windowed or borderless-windowed mode** — exclusive
  fullscreen prevents the module from reading the live window bounds and
  capturing screen regions.

## Launch

Open a PowerShell 7 terminal and run:

```powershell
Import-Module LastWarAutoScreenshot
Start-LWASConsole
```

A default configuration file is created automatically on first launch at
`%APPDATA%\LastWarAutoScreenshot\ModuleConfig.json`. No manual editing is
required — the main menu appears immediately.

---

## Step 1 — Select a target window

From the main menu choose **Select target window**.

A sorted list of all open windows appears. Highlight the game window (e.g.
`Last War: Survival`) using the arrow keys and press Enter to confirm.

The selected window handle is saved to your configuration. If the window is
minimised before a macro runs, the module restores it automatically.

---

## Step 2 — Record a macro

From the main menu choose **Record macro**.

1. **Enter a name** — letters, digits, hyphens, and underscores only; max
   50 characters. Spaces are automatically converted to hyphens.
2. **Add actions** one at a time from the action menu. For a basic two-click
   sequence:
   - **Move to point** — move your mouse cursor over the game window to the
     first target position, then press Enter in the console to capture it.
   - **Left-click** — adds a click at the current cursor position. No
     capture needed.
   - **Delay** — enter a pause in seconds (e.g. `2`).
   - **Move to point** — capture a second position.
   - **Left-click** — click the second position.
3. Choose **Save macro** to write the sequence to disk.

> **Tip:** Keep keyboard focus on the console window during coordinate capture.
> If focus has moved to the game window, click the console title bar to return
> focus before pressing Enter.

---

## Step 3 — Run the macro

From the main menu choose **Run macro**.

Select your macro from the list. A summary table shows every action in the
sequence before you commit. Choose **Yes, run now** to start execution.

The module validates that the target window is open before running. If the
window is not found, an error is displayed and you are returned to the macro
list.

---

## Step 4 — Emergency stop

Two mechanisms halt any running macro immediately:

| Method | How to trigger |
|--------|----------------|
| Keyboard | Hold `Ctrl+Shift+#` simultaneously (UK layout — `0xDC`) |
| Mouse gesture | Hold both left and right mouse buttons for 3 seconds |

Either trigger halts execution at the next safe checkpoint, reports how many
actions completed, and exits cleanly.

If you are on a non-UK keyboard, update `EmergencyStop.HotkeyVKeyCodes` via
**Configure module → Emergency stop settings**, or edit `ModuleConfig.json`
directly. See [Configuration.md](Configuration.md#emergencystop) for the full
key code reference.

---

## Next steps

| Topic | Where to look |
|-------|--------------|
| All macro action types and the JSON format | [MacroFormat.md](MacroFormat.md) |
| Screenshot capture and similarity detection | [User Guide](UserGuide.md#screenshot-capture) |
| Scheduling macros to run automatically | [User Guide](UserGuide.md#running-macros) |
| All configuration keys | [Configuration.md](Configuration.md) |
| Contributing or working on the module | [Developer.md](Developer.md) |
