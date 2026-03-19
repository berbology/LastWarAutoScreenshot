# Quick Start Guide

A first-use walkthrough for Last War AutoScript. For the full feature reference
see [UserGuide.md](UserGuide.md).

---

## Prerequisites

- Module installed — see the [installation steps](../../README.md#get-started)
  in the root README
- Last War: Survival running in **windowed** or **borderless-windowed** mode
  (exclusive fullscreen is not supported)

---

## Launch the app

Open a PowerShell 7 terminal and run:

```powershell
Import-Module LastWarAutoScreenshot
Start-LWASConsole
```

The interactive console app loads and presents the main menu.

---

## Step 1 — Select a target window

The module needs to know which game window to interact with. Without a selected
window, mouse-control and screenshot actions cannot run.

1. From the main menu select **"Select target window"**.
2. The app enumerates all visible windows and displays them as a list.
3. Use the arrow keys to highlight the Last War: Survival window, then press
   **Enter**.

The selected window handle is saved to config and persists across sessions.

---

## Step 2 — Record a simple macro

1. From the main menu select **"Record macro"**.
2. Enter a name for the macro (letters, digits, hyphens, and underscores only;
   spaces are auto-converted to hyphens with your confirmation).
3. Add a simple sequence using the action menu. For a click-and-wait example:
   - **Move to point** — position your mouse cursor over the target in the game
     window and press **Enter** to capture the position; then **Accept**.
   - **Left-click** — no position capture required; confirms immediately.
   - **Delay** — enter a duration in seconds (e.g. `2`).
   - **Move to point** — capture a second position.
   - **Left-click** — confirm.
4. Select **"Save macro"** to write the file to disk.

> **Tip:** The console must keep keyboard focus while you capture positions.
> Move the mouse over the game window, then click back on the console and press
> **Enter** to capture.

---

## Step 3 — Run the macro

1. From the main menu select **"Run macro"**.
2. Choose the macro from the list.
3. Review the action summary table, then select **"Yes, run now"**.

The module validates that the target window is open before starting. You will
see a progress indicator as each action executes.

---

## Step 4 — Emergency stop

Two mechanisms are available at any time during execution:

| Method | How to trigger |
|--------|----------------|
| **Keyboard hotkey** | Hold `Ctrl+Alt+Q` simultaneously |
| **Mouse gesture** | Hold both left and right mouse buttons for 3 seconds |

Either trigger halts the current action at the next safe checkpoint, reports
how many actions completed, and exits cleanly. To change the hotkey, go to
**Configure module → Emergency stop settings** in the app.

---

## Next steps

- [UserGuide.md](UserGuide.md) — full feature reference: macro recording
  workflows, screenshot configuration, similarity detection, managing macros
- [Configuration.md](Configuration.md) — all config keys with types, defaults,
  and accepted values
- [MacroFormat.md](MacroFormat.md) — JSON schema and action type reference for
  advanced users
