# scripts

Utility scripts for installing, uninstalling, and releasing the
`LastWarAutoScreenshot` module.

---

## Scripts

### `Install-LWAS.ps1` — bootstrap install from a release zip

Installs the module to the user's PowerShell module path. Self-elevates
automatically via `Start-Process pwsh -Verb RunAs` if the current session is
not running as Administrator.

```powershell
# Standard install (prompts before overwriting an existing installation)
.\scripts\Install-LWAS.ps1

# Overwrite an existing installation without prompting
.\scripts\Install-LWAS.ps1 -Force
```

**When to use:** After extracting a GitHub release zip, or after making source
changes that you want available as an installed module.

**Prerequisites:** PowerShell 7.0+. No elevated session required — the script
elevates itself.

---

### `Uninstall-LWAS.ps1` — remove the installed module

Removes all installed copies of the module, deletes the Windows Event Log
source, and optionally removes the AppData config and log directory.

```powershell
# Remove module and event log source; prompt before removing AppData
.\scripts\Uninstall-LWAS.ps1

# Remove everything including AppData without prompting
.\scripts\Uninstall-LWAS.ps1 -RemoveAppData
```

**When to use:** Cleanly removing the module before a fresh install, or when
decommissioning the tool entirely.

**Prerequisites:** Administrator rights (script self-elevates). After
uninstalling, start a new PowerShell session to ensure no module assemblies
remain loaded in memory.

---

### `New-LWASRelease.ps1` — create a versioned release zip

Bumps the module version, runs the full test suite, and produces a release
zip ready for upload to GitHub Releases.

```powershell
.\scripts\New-LWASRelease.ps1 -Version '1.1.0' -ReleaseNotes 'Description of changes.'
```

**What it does:**

1. Validates the version string (semver `x.y.z`).
2. Updates `ModuleVersion` and `ReleaseNotes` in `LastWarAutoScreenshot.psd1`.
3. Runs the full Pester test suite (aborts on failure unless `-SkipTests` is specified).
4. Assembles a staging directory and compresses to `releases\LastWarAutoScreenshot-v{version}.zip`.
5. Prints a post-release checklist: commit the psd1 change, tag, push, and upload.

**When to use:** When cutting a new release. The `releases/` output directory
is in `.gitignore` and is created at runtime.

**Prerequisites:** Pester 5.x installed. All tests must pass.
