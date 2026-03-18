# scripts

Utility scripts for installing, uninstalling, and releasing the module. These
scripts are intended to be run from the repository root or from an extracted
release zip; they are not part of the module itself.

## Scripts

### `Install-LWAS.ps1`

Bootstrap installer. Imports the module and delegates to `Install-LWAS`.

**When to use:** first-time installation from a downloaded release zip, or
reinstalling over an existing version.

**Self-elevating:** if the current session is not Administrator the script
re-launches itself via `Start-Process pwsh -Verb RunAs` automatically.

```powershell
# Standard install — prompts before overwriting an existing installation
.\scripts\Install-LWAS.ps1

# Force overwrite without prompting
.\scripts\Install-LWAS.ps1 -Force

# Install and include test dependencies (Pester, Spectre.Console.Testing.dll)
.\scripts\Install-LWAS.ps1 -IncludeTests
```

**Prerequisites:** PowerShell 7+. Must be run from the directory that contains
both `scripts/` and the module folder (`powershell-module/` or
`LastWarAutoScreenshot/`).

---

### `Uninstall-LWAS.ps1`

Removes the module, its Windows Event Log source, and optionally the AppData
config directory.

**When to use:** removing a previous installation before a clean reinstall, or
permanently uninstalling the module.

**Self-elevating:** same automatic elevation behaviour as `Install-LWAS.ps1`.

```powershell
# Remove module and event log source; prompt before removing AppData
.\scripts\Uninstall-LWAS.ps1

# Remove everything including AppData without prompting
.\scripts\Uninstall-LWAS.ps1 -RemoveAppData
```

**After uninstalling:** start a new PowerShell session to ensure no module
assemblies remain loaded in memory.

---

### `New-LWASRelease.ps1`

Creates a versioned release zip. Validates the version string, updates
`ModuleVersion` and `ReleaseNotes` in the psd1, runs the full Pester suite,
and compresses the module into `releases/LastWarAutoScreenshot-v{version}.zip`.

**When to use:** cutting a new release for distribution.

**Prerequisites:** all Pester tests passing; psd1 metadata reviewed; module
installed to PSModulePath (the script offers to install if not found).

```powershell
.\scripts\New-LWASRelease.ps1 -Version '1.2.0' -ReleaseNotes 'Description of changes.'
```

The script does **not** perform any git operations. Follow the printed
post-release checklist to commit the psd1 change, tag the release, push, and
upload the zip to GitHub Releases.
