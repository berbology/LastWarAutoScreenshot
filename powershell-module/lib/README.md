# lib

Bundled DLLs required by the module. All files in this directory are tracked
in git and must not be fetched or replaced at runtime.

## Contents

| File | Purpose |
|------|---------|
| `Spectre.Console.dll` | Core rendering library used by all screen functions |
| `VERSIONS.txt` | Records the exact bundled version and target framework moniker |
| `test/Spectre.Console.Testing.dll` | `TestConsole` for Pester tests only — not loaded in production |

## Current versions

From `VERSIONS.txt`:

```
Spectre.Console=0.54.0
Spectre.Console.Testing=0.54.0
TFM=net9.0
```

## Why bundled in git

The module is distributed as a standalone zip that must work without internet
access or NuGet. Bundling the DLLs ensures:

- No network dependency at install or runtime.
- The tested DLL version is exactly what ships — no silent upgrades.
- Side-by-side module versions each carry their own DLL snapshot.

`Spectre.Console.Testing.dll` is included in the git tree so that the test
suite runs from source without any additional setup steps.

## Updating the bundled DLLs

Updates must go through a pull request with a full Pester test run. Do not
replace DLLs outside of this process.

1. Download the target NuGet packages:

   ```powershell
   Invoke-WebRequest "https://www.nuget.org/api/v2/package/Spectre.Console/0.54.0" -OutFile spectre.nupkg
   Rename-Item spectre.nupkg spectre.zip
   Expand-Archive spectre.zip -DestinationPath spectre_extracted
   ```

2. Copy `lib/net9.0/Spectre.Console.dll` from the extracted folder to
   `powershell-module/lib/Spectre.Console.dll`.

3. Repeat for `Spectre.Console.Testing`, placing the DLL in
   `powershell-module/lib/test/`.

4. Update `VERSIONS.txt` with the new version strings and TFM.

5. Run the full Pester suite and confirm all tests pass.

6. Commit the updated DLLs and `VERSIONS.txt` in the same PR.
