## Codebase Simplification Refactor Plan

This document describes a set of targeted fixes and simplifications to the
codebase. Each item includes a description of the problem, the exact files
affected, what the fix is, and the justification for making it. Items are
ordered by priority (highest impact / least risk first).

This plan was produced by reviewing all source and test files after a previous
session resolved the `EventLogBackend` C# / `Add-Type` assembly reference
problem. The recommendations below are the follow-on issues discovered during
that review.

---

## Item 1 — Fix broken test structure in `LoggingBackend.Tests.ps1` **[COMPLETED 2026-02-18]**

**Priority:** High — affects test reliability and file system cleanliness

### Problem

The `Describe 'FileLogBackend Logging Enhancements'` block in
`Tests/LoggingBackend.Tests.ps1` has its `AfterAll` cleanup block placed
**outside** the `Describe` block. There are also two orphaned closing braces
(`}`) at file scope that do not belong to any block. The result is:

- The `Remove-Item $testLogDir -Recurse -Force` cleanup in `AfterAll` never
  runs in Pester v5, because it is not inside a valid Pester block.
- A `testlogs/` directory is left behind in `Tests/` after every test run.
- Pester may emit parse warnings or behave unpredictably due to the stray
  braces.

The second half of the file (the `Logging Backend Abstraction` and
`Get-LoggingBackendConfig` `describe` blocks) has a second `BeforeAll` block
at file scope, outside any `Describe`. This is also invalid in Pester v5.

### Affected file

`Tests/LoggingBackend.Tests.ps1`

### Fix

1. Move the `AfterAll { Remove-Item $testLogDir ... }` block to be the last
   statement **inside** the `Describe 'FileLogBackend Logging Enhancements'`
   block, before its closing `}`.
2. Remove the two orphaned closing braces that sit between the `AfterAll` and
   the next `BeforeAll`.
3. Wrap the second `BeforeAll` (which dot-sources `Get-LoggingBackendConfig`)
   and the two `describe` blocks below it in a single outer `Describe` to
   make the file structurally valid, or merge them into the existing structure.

### Status

**Completed 2026-02-18:** Test structure fixed, all blocks are now valid, cleanup runs as intended, and file parses with no errors. See commit for details.

---

## Item 2 — Fix broken test structure in `LoggingBackend.RetentionPolicy.Isolated.Tests.ps1` **[COMPLETED 2026-02-18]**

**Priority:** High — the test is likely not being discovered or run at all

### Problem

The file has the following layout:

```powershell
BeforeAll { ... }
    }           # orphaned closing brace — not valid at file scope

    It 'cleans up old logs by retention policy (isolated)' { ... }

    AfterAll { Remove-Item $testLogDir ... }
}               # orphaned closing brace
```

The `It` block and `AfterAll` are at file scope with no enclosing `Describe`.
In Pester v5, `It` blocks **must** be inside a `Describe`. A file-scope `It`
is not a valid test and will not be discovered or reported by Pester's test
runner. The `AfterAll` will also not execute.

### Affected file

`Tests/LoggingBackend.RetentionPolicy.Isolated.Tests.ps1`

### Fix

Wrap the `BeforeAll`, `It`, and `AfterAll` in a proper `Describe` block:

```powershell
BeforeAll {
    # module import here
}

Describe 'FileLogBackend retention policy (isolated)' {
    BeforeAll {
        # test directory setup here
    }

    It 'cleans up old logs by retention policy (isolated)' {
        # test body here
    }

    AfterAll {
        Remove-Item $testLogDir -Recurse -Force
    }
}
```

Remove the two orphaned closing braces.

### Status

**Completed 2026-02-18:** Test structure fixed, all blocks are now valid, test is now discovered and run by Pester, and cleanup executes as intended. See commit for details.

---

## Item 3 — Remove redundant dot-source in `Write-LastWarLog.ps1` **[COMPLETED 2026-02-18]**

**Priority:** Medium — unnecessary file I/O on every log call

### Problem

Inside `Write-LastWarLog`, after the verbosity check, these two lines appear:

```powershell
$privatePath = $PSScriptRoot
. (Join-Path $privatePath 'Get-LoggingBackendConfig.ps1')
```

`Get-LoggingBackendConfig.ps1` is **already dot-sourced at module load time**
by the `.psm1` file, which iterates `Private/*.ps1` and dot-sources each one.
The function `Get-LoggingBackendConfig` is therefore already in scope when
`Write-LastWarLog` is called.

Re-dot-sourcing the file on every `Write-LastWarLog` invocation:

- Performs a file read on every log call (a hot path).
- Re-defines the `Get-LoggingBackendConfig` function object in memory
  on every call, which is wasteful.
- Could cause unexpected behaviour if the file is missing at call time
  even though the function was already loaded.

### Affected file

`Private/Write-LastWarLog.ps1`

### Fix

Remove these two lines entirely:

```powershell
# DELETE these two lines:
$privatePath = $PSScriptRoot
. (Join-Path $privatePath 'Get-LoggingBackendConfig.ps1')
```

The variable `$privatePath` is only used for the dot-source and for the
fallback log path at the bottom of the function. Replace the fallback
reference with `$PSScriptRoot` directly (it is valid inside the function
scope).

### Status

**Completed 2026-02-18:** Redundant dot-source and variable removed, fallback now uses $PSScriptRoot directly, and no unnecessary file I/O occurs on log calls. See commit for details.

---

## Item 4 — Clean up `WindowAndProcessMonitor.Tests.ps1`

**Priority:** Medium — debug noise in output, code at file scope, and tests
that may test the wrong thing

### Problem

This file has several distinct issues:

**a) Code at file scope (violates Pester v5 rules)**

```powershell
$moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
Write-Host 'Module Manifest path: ' + $moduleManifest
Import-Module $moduleManifest -Force
```

All three lines are outside any Pester block. In Pester v5, all code must be
inside `BeforeAll`, `Describe`, `Context`, `It`, etc. Code at file scope is
unreliable and produces unpredictable results.

**b) `BeforeAll` dot-sources from the wrong directory**

```powershell
BeforeAll {
    $privateDir = $PSScriptRoot   # $PSScriptRoot resolves to Tests/
    . (Join-Path $privateDir 'Write-LastWarLog.ps1')        # does not exist in Tests/
    . (Join-Path $privateDir 'Test-WindowHandleValid.ps1')  # does not exist in Tests/
}
```

Both files live in `Private/`, not `Tests/`. This dot-source will silently
fail or throw a path error, meaning the functions being tested are only
available because of the earlier `Import-Module` call, not from these
dot-sources as intended.

**c) Debug `Write-Host` traces left in `It` blocks**

Multiple `It` blocks contain lines such as:

```powershell
Write-Host "[TEST-TRACE] About to call Start-WindowAndProcessMonitor"
Write-Host "[TEST] monitor object: $monitor"
Write-Host "[TEST] monitor type: $($monitor.GetType().FullName)"
Write-Host "[TEST] monitor.Stop: $($monitor.Stop)"
```

These were debugging traces that were never removed. They produce noise in
every test run and mask real failure messages.

**d) `$monitor` null-check appears before `$monitor` is assigned**

In two of the integration `It` blocks, the pattern is:

```powershell
Mock ...
if ($null -eq $monitor) {           # $monitor not yet assigned here
    throw "monitor is null"
}
Mock ...
$monitor = Start-WindowAndProcessMonitor ...
```

The null-check fires before `$monitor` exists, so it always sees `$null` at
that point and throws, meaning the actual `Start-WindowAndProcessMonitor` call
is never reached. These tests are not testing what they claim to test.

### Affected file

`Tests/WindowAndProcessMonitor.Tests.ps1`

### Fix

1. Move the three file-scope lines into the outer `BeforeAll` that already
   exists in the file.
2. Correct the `BeforeAll` dot-source paths to use
   `Join-Path (Split-Path -Parent $PSScriptRoot) 'Private'` as the base.
3. Remove all `Write-Host "[TEST..."` and `Write-Host "[TEST-TRACE..."` lines.
4. Move the `Mock` calls and the `$monitor = Start-WindowAndProcessMonitor`
   call into the correct order: all `Mock` calls first, then the function
   call, then assertions. Remove the premature null-check blocks.

tests makes it harder to identify real failures. Code at file scope in Pester
v5 is out of spec and unreliable.

### Why this matters

Tests that have code in the wrong order (mock after the call they're meant to
intercept) do not validate the behaviour they claim to test. Debug output in
tests makes it harder to identify real failures. Code at file scope in Pester
v5 is out of spec and unreliable.

### Status

**Completed 2026-02-18:** File-scope code moved into BeforeAll, dot-source paths fixed, all debug Write-Host lines removed, mock/call order corrected, and premature null-checks eliminated. Tests now run cleanly and as intended. See commit for details.

---

## Item 5 — Replace `Assert-MockCalled` with `Should -Invoke` in

`Set-WindowActive.Tests.ps1` and `Set-WindowState.Tests.ps1`

**Priority:** Low — deprecated API, not currently broken but will break in
future Pester releases

### Problem

Both test files use `Assert-MockCalled`, the Pester v4 assertion syntax:

```powershell
Assert-MockCalled Write-LastWarLog -ParameterFilter { ... } -Times 1 -Exactly
```

In Pester v5, the correct syntax is `Should -Invoke`:

```powershell
Should -Invoke Write-LastWarLog -ParameterFilter { ... } -Exactly 1
```

Pester v5 supports `Assert-MockCalled` for backwards compatibility but emits
deprecation warnings. Future versions of Pester may remove it entirely.

### Affected files

- `Tests/Set-WindowActive.Tests.ps1`
- `Tests/Set-WindowState.Tests.ps1`

### Fix

Replace every occurrence of:

```powershell
Assert-MockCalled <Command> [-ParameterFilter { ... }] -Times <N> [-Exactly]
```

with:

```powershell
Should -Invoke <Command> [-ParameterFilter { ... }] -Exactly <N>
```

Note the parameter name change: `-Times` becomes the positional value after
`-Exactly`, and the order of `-Exactly` and `-Times` is reversed. Refer to
the Pester v5 `Should -Invoke` documentation to confirm parameter names before
making changes.

### Why this matters

Deprecation warnings in the test output make it harder to spot real warnings.
Staying on deprecated API paths is a maintenance liability.

### Status

**Completed 2026-02-18:** All Assert-MockCalled assertions replaced with Should -Invoke in Set-WindowActive.Tests.ps1 and Set-WindowState.Tests.ps1. Deprecation warnings eliminated, tests are now future-proof for Pester v5 and later.

## Item 6 — Delete the dead `EventLogBackend.cs` source file

**Priority:** Low — no runtime impact, but misleading to readers

### Problem

`src/EventLogBackend.cs` still exists in the repository. It is **not**
compiled or loaded — it was removed from the `Add-Type` call in
`LastWarAutoScreenshot.psm1` during a previous refactor session. The current
architecture handles the EventLog backend entirely within
`Private/Write-LastWarLog.ps1` using PowerShell's Write-EventLog cmdlet.

The file contains a full C# class (`EventLogBackend`) that inherits from
`LogBackend`, uses P/Invoke against `advapi32.dll`, and is fully functional
on its own — but it is never invoked. Any developer reading the `src/`
directory would reasonably assume it is part of the active code.

### Affected file

`src/EventLogBackend.cs`

### Fix

Delete the file. If the EventLog backend ever needs to be moved back to C#
(for performance or other reasons), the current `Write-LastWarLog.ps1`
implementation or the git history provides a clear reference.

If you prefer not to delete it, add a comment block at the top of the file:

```csharp
// ARCHIVED — This file is not compiled or loaded.
// The EventLog backend is implemented in Private/Write-LastWarLog.ps1 using PowerShell's Write-EventLog.
// See git log for the history of why this approach was abandoned.
```

### Why this matters

Dead code creates confusion. A developer (or AI agent) encountering this file
would not know whether it is intentionally dormant or accidentally omitted
from the build. The `.psm1` already explicitly lists what is compiled, so the
presence of an unlisted `.cs` file is actively misleading.
[blank line]

### Status

**Completed 2026-02-18:** src/EventLogBackend.cs deleted. No dead code remains in src/. The EventLog backend is now implemented only in PowerShell. See git log for history.

---

## Item 7 — Simplify `Get-LoggingBackendConfig` tests

**Priority:** Low — the tests work, but they are fragile and test
implementation instead of behaviour

### Problem

In `Tests/LoggingBackend.Tests.ps1`, the `describe 'Get-LoggingBackendConfig'`
block mocks `Test-Path`, `Get-Content`, and `ConvertFrom-Json` — all
built-in PowerShell cmdlets. It then re-dot-sources `Get-LoggingBackendConfig`
inside each test body. There are two problems:

**a) Mocking core cmdlets is fragile.** A mock on `Test-Path` or
`ConvertFrom-Json` at this scope can bleed into other tests running in the
same session if Pester's scope cleanup does not fire correctly (e.g., if an
earlier test throws). Both cmdlets are used internally by other tested code.

**b) The tests verify internal plumbing, not behaviour.** The test for
"returns File and EventLog when both are set" mocks `ConvertFrom-Json` to
return a specific object. This means it is testing whether `Get-LoggingBackendConfig`
calls `ConvertFrom-Json` and handles its output, not whether the function
produces the correct output when given a real JSON file.

The `Write-LastWarLog.Tests.ps1` pattern of writing a real temp file and
asserting on real output is more robust and equally fast.

### Affected file

`Tests/LoggingBackend.Tests.ps1` (the `describe 'Get-LoggingBackendConfig'`
section)

### Fix

Replace the mock-heavy tests with tests that write a real temporary config
file, call `Get-LoggingBackendConfig` with that file path, and assert on the
return value. This removes the need to mock `Test-Path`, `Get-Content`, and
`ConvertFrom-Json` entirely.

Example pattern:

```powershell
It 'Returns File and EventLog when both are set' {
    $tmp = New-TemporaryFile
    Set-Content $tmp.FullName '{"Logging":{"Backend":"File,EventLog"}}' -Encoding UTF8
    # Pass path to function or test via a known config location
    $result = Get-LoggingBackendConfig
    $result | Should -Contain 'File'
    $result | Should -Contain 'EventLog'
    Remove-Item $tmp.FullName -Force
}
```

Note: `Get-LoggingBackendConfig` currently hard-codes its config path as
`Join-Path $PSScriptRoot 'ModuleConfig.json'`. To make it testable without
mocks, add an optional `-ConfigPath` parameter with the hard-coded path as
default. This is a minimal interface change with no impact on production
callers.

### Why this matters

Tests should verify observable behaviour, not internal call sequences.
Behaviour-based tests survive refactoring; implementation-based tests break
when internal details change even though the behaviour is identical. This is
the same lesson learned from the `EventLogBackend` saga.

### Status

**Completed 2026-02-18:** Get-LoggingBackendConfig now accepts optional -ConfigPath parameter for testability. All tests rewritten to use real temporary config files instead of mocking Test-Path, Get-Content, and ConvertFrom-Json. Tests now verify behaviour, not implementation details. See commit for details.

---

## Item 8 — Delete or archive the `.ps1.old` files in `Private/`

**Priority:** Low — no runtime impact, but dead code cluttering the module

### Problem

Two archived files exist in `Private/`:

- `Private/EventLogBackend.ps1.old`
- `Private/LogBackend.ps1.old`

Neither is dot-sourced (the `.psm1` uses `Get-ChildItem -Filter *.ps1`, which
excludes `.ps1.old` extensions). They are informal archives of code that was
superseded during earlier refactoring sessions.

`EventLogBackend.ps1.old` contains a PowerShell class-based EventLog backend
that was abandoned due to test scoping problems with PowerShell classes.
`LogBackend.ps1.old` contains an earlier iteration of the logging backend
abstraction.

Having these in `Private/` is misleading — the directory is supposed to
contain active private functions. A developer reading the directory listing
cannot easily tell which files are live and which are dead.

### Affected files

- `Private/EventLogBackend.ps1.old`
- `Private/LogBackend.ps1.old`

### Fix

Delete both files. The git history preserves them if they are ever needed for
reference. If you prefer to keep them, move them to a dedicated `Archive/`
folder at the module root and add a `README` there explaining what they are
and why they were retired.

### Why this matters

The `Private/` directory should only contain active code. Dead files in an
active directory are a maintenance liability — they will confuse future
developers and AI agents working on the codebase.

### Status

**Completed 2026-02-18:** EventLogBackend.ps1.old and LogBackend.ps1.old deleted from Private/. All archived code removed. Private/ now contains only active functions. Git history preserves the archived code for future reference if needed. See commit for details.

---

## Architectural Decision Record — EventLog Backend Extensibility

This section records a deliberate architectural trade-off made during the
EventLog refactoring. It is here so that future developers and AI agents do
not attempt to "fix" the current design without understanding why it exists.

### What the original design intended

The original architecture used a C# abstract base class (`LogBackend`) with
concrete implementations (`FileLogBackend`, `EventLogBackend`) loaded via
`Add-Type`. The dispatch in `Write-LastWarLog.ps1` was a loop:

```powershell
foreach ($backend in $backends) {
    $backend.Log($message, $level, ...)
}
```

The goal was extensibility: any new logging sink would simply be a new class
inheriting `LogBackend`, and the dispatch loop would call it automatically
without any changes to `Write-LastWarLog.ps1`.

### Why it was abandoned

1. `System.Diagnostics.EventLog` is a Windows-specific NuGet package that is
   not in the standard `Add-Type` reference set. Adding it caused cascading
   assembly reference failures that could not be reliably resolved.

2. `Mock Write-EventLog` cannot intercept calls made from inside C# methods.
   C# calls the .NET API directly, bypassing PowerShell's mock infrastructure.
   To compensate, scriptblock delegates were injected into the C# constructor
   as a mock seam — reimplementing dependency injection in C# purely to satisfy
   PowerShell tests. This made the code more complex, not less.

3. PowerShell classes were tried as an alternative (see the `.ps1.old` files)
   and abandoned due to test scoping problems inherent to PowerShell classes.

### What replaced it

The EventLog backend is now implemented as a direct `Write-EventLog` call
inside `Write-LastWarLog.ps1`, inside an `if ($backendNames -contains
'EventLog')` block. `Mock Write-EventLog` works correctly because it is
intercepting a PowerShell cmdlet, not a C# method call.

### What this means for future backend additions

Adding a new backend now requires:

1. Adding a new `if ($backendNames -contains 'NewBackend') { }` block to
   `Write-LastWarLog.ps1`.
2. Implementing the sink logic inside that block (or delegating to a private
   function if the logic is non-trivial).
3. Adding the backend name to `ModuleConfig.json` and `Get-LoggingBackendConfig`.

This is less formally extensible than the original loop-based dispatch, but
it is simpler, fully testable with `Mock`, and appropriate for a codebase
where the realistic set of backends is small (File, EventLog, and possibly
an Azure sink in future).

**Do not reintroduce PowerShell classes or new C# logging classes without
first reading this section and the git history for the EventLog backend.**

---

## Summary Table

| # | File(s) | Problem | Effort |
|---|---------|---------|--------|
| 1 | `Tests/LoggingBackend.Tests.ps1` | `AfterAll` outside `Describe`, orphaned braces | Low |
| 2 | `Tests/LoggingBackend.RetentionPolicy.Isolated.Tests.ps1` | `It`/`AfterAll` outside `Describe`, test never runs | Low |
| 3 | `Private/Write-LastWarLog.ps1` | Redundant dot-source on every log call | Trivial |
| 4 | `Tests/WindowAndProcessMonitor.Tests.ps1` | File-scope code, wrong paths, debug noise, bad mock order | Medium |
| 5 | `Tests/Set-WindowActive.Tests.ps1`, `Set-WindowState.Tests.ps1` | Pester v4 `Assert-MockCalled` deprecated | Low |
| 6 | `src/EventLogBackend.cs` | Dead code, never compiled, actively misleading | Trivial |
| 7 | `Tests/LoggingBackend.Tests.ps1` | Tests verify internals not behaviour, fragile mocks | Medium |
| 8 | `Private/EventLogBackend.ps1.old`, `Private/LogBackend.ps1.old` | Dead archive files in active code directory | Trivial |

Items 1–3, 6, and 8 are safe to implement independently with no risk of regression.
Items 4, 5, and 7 require reading the relevant source files carefully before
making changes to avoid accidentally altering test intent.
