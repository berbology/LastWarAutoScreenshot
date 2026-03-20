# Test Suite Code Review — TestCleanup2.md

Review of all 58 test files in `powershell-module\Tests` (including subdirectories).
Conducted: 2026-03-20

---

## Critical Issues

### 1. (Completed) `Tests\EventLogBackend_Integration.Tests.ps1` — Complete Duplicate File

Every `It` block, mock, and assertion is an **exact copy** of `EventLogBackend.Tests.ps1`. The only difference is the `Describe` tag is `'Integration'` instead of `'Unit'`. This file is entirely redundant and should be deleted.

### 2. (Completed) `Tests\Select-TargetWindowFromMenu_Integration.Tests.ps1` — Empty Placeholder File

The file contains only a comment: *"No integration tests found in snippet, placeholder for future if needed."* It has zero tests. Dead file that should be deleted.

### 3. (Completed) `Tests\ConsoleApp\Show-WindowSelectionScreen.Tests.ps1` — Shared TestConsole Across All Tests

`$script:tc` (the `TestConsole` instance) is created **once in `BeforeAll`** and never reset. Output accumulates across every test in the file. Tests using `Should -Not -Match` may pass spuriously (if prior tests didn't produce the text) or fail incorrectly (if they did). There is no `BeforeEach` to create a fresh console for each test. This is particularly risky for negative assertions.

### 4. (Completed) `Tests\ConsoleApp\Show-EmergencyStopConfigScreen.Tests.ps1` — Shared TestConsole Across All Tests

Same problem as `Show-WindowSelectionScreen.Tests.ps1`: `$script:tc` is created in `BeforeAll`, not `BeforeEach`. All tests share one accumulating output buffer. Any `Should -Not -Match` assertion in this file is unreliable.

### 5. (Completed) `Tests\ConsoleApp\Show-EditMacroScreen.Tests.ps1` — Extreme Code Duplication

The 3-action `$mockMacroData` scriptblock is copy-pasted **verbatim into every single `It` block** (approximately 15 times). This is a significant maintenance burden and the likely source of subtle bugs if the mock data ever needs to change. It should be extracted to a `BeforeEach` block.

---

## Incorrect Test Tagging

### 6. (Completed) `Tests\Get-EnumeratedWindows.Tests.ps1` — Integration Test Tagged as Unit

The file header explicitly states: *"Because Get-EnumeratedWindows wraps Win32 API calls that cannot be mocked via Pester, these tests exercise the function against the live Windows environment."* Despite this, the `Describe` block is tagged `'Unit'`. It should be tagged `'Integration'`.

Additionally, the tests for `-ExcludeMinimized` and `-VisibleOnly` switches both check `WindowState -eq 'Visible'`, making them potentially redundant with each other.

### 7. (Completed) `Tests\WindowEnumeration_TypeDefinition.Tests.ps1` — Live API Calls Tagged as Unit

The `'Error Handling'` context calls real Win32 APIs (`IsWindowVisible`, `GetWindowTextLength`, `GetWindowText`) with invalid/zero handles and observes the live return values. These are not unit tests — they exercise real kernel calls. The file is tagged `'Unit'`. It should either be re-tagged `'Integration'` or the live calls should be acknowledged with a comment.

### 8. (Completed) `Tests\MouseControl_TypeDefinition.Tests.ps1` — Live Win32 Call in Unit Test File

"GetSystemMetrics returns positive values for virtual screen dimensions" (line 157–165) makes a live `GetSystemMetrics` Win32 call. The whole file is tagged `'Unit'`. This specific test is duplicated in `MouseControl_Integration.Tests.ps1` as "Returns positive screen dimensions for virtual desktop" (tagged `'Integration'`). The test exists in both files with different tags — one copy should be removed.

---

## Duplicate Tests Across Files

### 9. (Completed) `Tests\MouseMovement.Tests.ps1` — Duplicates `Invoke-MouseDragClick.Tests.ps1`

`MouseMovement.Tests.ps1` contains a `Describe 'Invoke-MouseDragClick'` block (lines 375–513) that substantially overlaps with the dedicated `Invoke-MouseDragClick.Tests.ps1`. The following scenarios are tested in both files:

- Emergency stop check
- LEFTDOWN/LEFTUP sequence
- Drag failure handling
- LEFTUP in finally block

The dedicated file should be the sole home for these tests.

### 10. `Tests\WindowEnumeration_Integration.Tests.ps1` — Redundant GetForegroundWindow Tests

"Should return valid window handle from GetForegroundWindow" (lines 97–105) is redundant with "Should successfully call GetForegroundWindow" (lines 89–96). Both call `GetForegroundWindow` and verify non-throw behaviour. The second test adds no meaningful new assertion that the first doesn't already cover.

### 11. (Completed) `Tests\Invoke-CaptureScreenRegion.Tests.ps1` — Near-Identical Tests for MaskRegions

"passes empty rectangle array when MaskRegions is absent (null)" (lines 372–387) and "passes empty rectangle array when MaskRegions is an empty array" (lines 389–405) are near-identical. Both verify `$MaskPixelRects.Length -eq 0`. These should be combined as a single parameterised test using `-TestCases`.

### 12. (Completed) `Tests\New-LWASLauncherScript.Tests.ps1` — Redundant Path Verification

"Returns the expected launcher file path string" and "Creates the launcher file at the expected path" both run the function with identical parameters and verify the same path. These could be a single test.

### 13. (Completed) `Tests\Invoke-CaptureMousePosition.Tests.ps1` — Repeated Assertions Across Three Tests

"Returns an object with RelativeX, RelativeY, AbsoluteX, and AbsoluteY properties" (lines 66–88) largely duplicates assertions already made in the preceding two tests. All three tests set up identical mocks and verify the same first capture. The property-existence assertions should be in one test only.

---

## Fudged / Misleading Assertions

### 14. (Completed) `Tests\MacroSchema.Tests.ps1` — Circular Assertion

"returns Valid=$false when version is missing" (line 663–671) contains:

```powershell
$result.Messages | Should -Contain ($result.Messages | Where-Object { $_ -match 'version' })
```

This is a **circular assertion**: it checks that `Messages` contains something from `Messages` itself filtered by `'version'`. If `Messages` is empty, `Where-Object` returns an empty array and `Should -Contain` passes vacuously. The test should assert a specific expected string, e.g.:

```powershell
$result.Messages | Should -Contain 'Macro version is missing'
```

### 15. (Completed) `Tests\MacroFileManagement.Tests.ps1` — Assertion Output Suppressed

"excludes files with non-matching filename patterns" uses:

```powershell
$result.Count | Should -Be 0 | Out-Null
```

The `| Out-Null` is appended to the `Should` assertion. While this is harmless for passing tests, it is an unusual pattern that could mask assertion output in failure reports and suggests the author may have added it to suppress unexpected output rather than fix its cause.

### 16. (Completed) `Tests\Install-LWAS.Tests.ps1` — Indirect String Assertion

Test `7.7` uses:

```powershell
($output -like '*already installed*') | Should -Not -BeNullOrEmpty
```

This is an indirect assertion pattern. The `-like` operator returns the matching strings (truthy) or nothing (falsy), and the result is then tested for nullability. A direct assertion would be clearer and produce a better failure message:

```powershell
$output | Should -BeLike '*already installed*'
```

### 17. (Completed) `Tests\Select-TargetWindowFromMenu.Tests.ps1` — Assertion Inside Mock Body

"Should pass ProcessName parameter to Get-EnumeratedWindows" places a `Should -Be` assertion **inside the mock's scriptblock**:

```powershell
Mock Get-EnumeratedWindows { $ProcessName | Should -Be 'LastWar' }
```

If `Get-EnumeratedWindows` is never called, the mock body never executes and the assertion never runs — the test passes silently. A `Should -Invoke` check must be added after the function call to guarantee the mock was actually invoked.

### 18. (Completed) `Tests\LoggingBackend_Integration.Tests.ps1` — Name-Behaviour Contradiction

"handles permission errors gracefully" (line 51–63) uses `{ $backend.Log(...) } | Should -Throw`. The test name says "gracefully", which universally implies the operation should **not** throw. Either the test name is wrong (it should say "throws on permission error") or the implementation should be catching the exception internally, and the assertion is wrong.

---

## Fragile or Weak Assertions

### 19. (Completed) `Tests\Get-DefaultModuleSettings.Tests.ps1` — Fragile Property Count

"Should have correct EmergencyStop structure" (line 85–90) asserts:

```powershell
@($defaults.EmergencyStop.PSObject.Properties).Count | Should -Be 3
```

This breaks if any new property is ever added to `EmergencyStop`, even if all existing properties are correct. The test enforces a structure count rather than validating behaviour. It should assert the specific properties that are expected, not a total count.

### 20. (Completed) `Tests\Get-DefaultModuleSettings.Tests.ps1` — Redundant Assertion

"Should have correct HotkeyKeyNames value" (line 104–109) tests:

```powershell
$defaults.EmergencyStop.HotkeyKeyNames | Should -Be 'Ctrl+Alt+Q'
```

This is already asserted in the immediately preceding `It` block "Should have all required EmergencyStop properties with correct defaults" (line 93–101). The separate test is pure duplication.

**FIXED:** The redundant test has been removed. Only two references to `HotkeyKeyNames` remain:
- Line 90: Property existence check (structure validation)
- Line 101: Value assertion (defaults validation)

### 21. (Completed) `Tests\Get-LWASTargetWindow.Tests.ps1` — Weak `-First` Assertion

"Returns 1 object when -First is used with a single match" checks only `Count -eq 1` but does not verify that the returned object is actually the correct window. A stronger assertion would check a property of the returned object (e.g. `ProcessName` or `WindowTitle`).

### 22. (Completed) `Tests\Get-LWASTargetWindow.Tests.ps1` — Missing ParameterFilter on Mock Assertion

"-First is used with no matches" checks `Should -Invoke Write-Error -Times 1` without a `ParameterFilter`. This is less specific than the non-`-First` error test and would pass even if a different error message were written. A `ParameterFilter` matching the expected error message content should be added.

### 23. (Completed) `Tests\ModuleConfiguration.Tests.ps1` — Over-Granular Tests (Slow)

The "Phase 5 config round-trip" and "Phase 3 config default injection" contexts each contain 10–12 individual `It` blocks, each calling `Get-ModuleConfiguration` separately to check one single field. This generates a lot of repetitive setup/teardown overhead. These should be consolidated into a small number of data-driven tests using `-TestCases` / `-ForEach`.

Additionally, these tests write to `$env:APPDATA` paths (not `TestDrive:\`), meaning they create real files on the developer's machine and may leave artefacts if a test fails mid-run.

---

## Scoping and Lifecycle Issues

### 24. (Completed) `Tests\MacroExecution.Tests.ps1` — Potential Scope Issue in Loop Test

The `Loop: StopLoop consumed` test uses `$script:_loopSimCallCount` which is reset inline inside the `It` block but **outside** `InModuleScope`. Per CLAUDE.md: *"`$script:` inside `InModuleScope` resolves to the module's script scope, not the test file's scope."* If the variable is read inside `InModuleScope` after being set outside it, the value will not be the test file's value. This should be verified against the actual code flow and potentially moved into `InModuleScope` or reworked.

### 25. (Completed) `Tests\ConsoleApp\Show-MainMenu.Tests.ps1` — Inconsistent Console Usage

Some tests use the shared `$script:tc` (accumulating output) and some create a `$freshTc` locally. The inconsistency within the same file makes it harder to reason about test isolation. Tests using `$script:tc` inherit all prior output, making their `Should -Match` / `Should -Not -Match` assertions potentially order-dependent. It's probably best to create the test console in BeforeEach block

**FIXED:** The four tests that created `$freshTc` locally (two in `Context 'Manage schedules option'`, two in `Context 'When no target window has been configured'`) now use `$script:tc`, which is already created fresh in the `BeforeEach` block at the `Describe` level. All stale-output workaround comments removed.

### 26. (Completed) `Tests\ConsoleApp\Show-ManageMacrosScreen.Tests.ps1` — Redundant Closely-Paired Tests

"Calls Remove-MacroFile exactly once" and "Calls Remove-MacroFile with the correct FilePath" use identical mock setups and navigation key sequences. These could be a single `It` block with two assertions, reducing test setup overhead and making the intent clearer.

"Returns $null when no macros exist" and "Does not throw when back is selected immediately" in the 'When no macros are saved' context both exercise the same empty-state path and largely overlap in what they verify.

**FIXED:** The two `Remove-MacroFile` tests merged into "Calls Remove-MacroFile exactly once with the correct FilePath" with both `Should -Invoke` assertions. The two back-selection tests merged into "Returns $null without throwing when back is selected immediately" using the `{ $result = ... } | Should -Not -Throw` then `$result | Should -BeNullOrEmpty` pattern.

### 27. (Completed) `Tests\Get-RandomTargetPosition.Tests.ps1` — Non-Standard BeforeAll Placement

`BeforeAll` is placed **inside** the `Describe` block rather than at the top level. While Pester supports this, CLAUDE.md guidance prefers top-level `BeforeAll` for module import. This is a minor style inconsistency.

The statistical tests using 100-iteration loops could produce rare false failures if the random distribution is poor on a given run. Consider using a seeded random or wider tolerance bands.

**FIXED:** Module import (`Remove-Module` + `Import-Module`) moved to a top-level `BeforeAll` above `Describe`. The `Mock Write-LastWarLog` remains in a `BeforeAll` inside `Describe` (correct scope for mocks). Statistical tolerance multiplier widened from `0.16` to `0.20` (~4 standard errors, >99.99% pass rate) and comments updated with the actual standard-error derivation.

### 28. (Completed) `Tests\ConsoleApp\Invoke-StartupConfigValidation.Tests.ps1` — Non-Standard Assertion Syntax

Line 398 uses:

```powershell
Should -ActualValue $result.Messages -BeOfType [array]
```

This uses the `ActualValue` named parameter directly rather than the standard pipeline syntax. The correct form is:

```powershell
$result.Messages | Should -BeOfType [array]
```

---

## Questionable Test Approach

### 29. (Completed) `Tests\WindowAndProcessMonitor.Tests.ps1` — Wrong Cmdlet Checked for Error Reporting

"Returns $false and logs error" for unsupported handle type (line 34–41) uses `Should -Invoke Write-Host` to verify error reporting. Per project conventions, `Write-Host` is explicitly avoided; errors should be reported via `Write-Warning`, `Write-Error`, or `Write-LastWarLog`. This test may be checking the wrong cmdlet entirely, meaning it would pass even if the implementation changed to the correct error-reporting mechanism.

### 30. (Completed) `Tests\MouseControl_Integration.Tests.ps1` — Race Condition Risk

"Returns consistent state values for the same key across calls" makes two consecutive live calls to a keyboard state API and asserts the results are equal. If the user presses or releases a key between the two calls, the test will fail non-deterministically. This is inherent to the live Win32 approach, but should be documented as a known flakiness risk.

### 31. (Completed) `Tests\ConsoleApp\Show-ScheduleScreen.Tests.ps1` — Inconsistent TestConsole Pattern

Creates `TestConsole` inline in each `It` block rather than using `BeforeEach`. This is not harmful (it gives better isolation than some other files), but it is inconsistent with the rest of the ConsoleApp test suite pattern and could confuse future contributors.

**FIXED:** Removed the unused `New-ScheduleTestConsole` helper function. Added a `BeforeEach` block at the `Describe` level that creates a fresh `$script:tc` inside `InModuleScope` (matching the pattern established in `Show-MainMenu.Tests.ps1` and `Show-ManageMacrosScreen.Tests.ps1`). All 15 `It` blocks now open with `$tc = $script:tc` rather than re-creating and configuring a `TestConsole` inline.

---

## Summary Table

| # | File | Severity | Category |
|---|------|----------|----------|
| 1 | `EventLogBackend_Integration.Tests.ps1` | Critical | Duplicate file |
| 2 | `Select-TargetWindowFromMenu_Integration.Tests.ps1` | Critical | Empty dead file |
| 3 | `Show-WindowSelectionScreen.Tests.ps1` | Critical | Shared TestConsole — unreliable assertions |
| 4 | `Show-EmergencyStopConfigScreen.Tests.ps1` | Critical | Shared TestConsole — unreliable assertions |
| 5 | `Show-EditMacroScreen.Tests.ps1` | Critical | Extreme mock data duplication (~15 copies) |
| 6 | `Get-EnumeratedWindows.Tests.ps1` | ~~High~~ Completed | Integration test tagged Unit |
| 7 | `WindowEnumeration_TypeDefinition.Tests.ps1` | ~~High~~ Completed | Live API calls tagged Unit |
| 8 | `MouseControl_TypeDefinition.Tests.ps1` | ~~High~~ Completed | Duplicate live test + wrong tag |
| 9 | `MouseMovement.Tests.ps1` | ~~High~~ Completed | Duplicate Invoke-MouseDragClick coverage |
| 10 | `WindowEnumeration_Integration.Tests.ps1` | ~~Medium~~ Completed | Redundant GetForegroundWindow test |
| 11 | `Invoke-CaptureScreenRegion.Tests.ps1` | ~~Medium~~ Completed | Near-identical MaskRegions tests |
| 12 | `New-LWASLauncherScript.Tests.ps1` | ~~Medium~~ Completed | Redundant path verification tests |
| 13 | `Invoke-CaptureMousePosition.Tests.ps1` | ~~Medium~~ Completed | Repeated assertions across three tests |
| 14 | `MacroSchema.Tests.ps1` | ~~High~~ Completed | Circular assertion (vacuously true when empty) |
| 15 | `MacroFileManagement.Tests.ps1` | ~~Low~~ Completed | `\| Out-Null` on assertion |
| 16 | `Install-LWAS.Tests.ps1` | ~~Low~~ Completed | Indirect string assertion pattern |
| 17 | `Select-TargetWindowFromMenu.Tests.ps1` | ~~High~~ Completed | Assertion inside mock body — silent pass |
| 18 | `LoggingBackend_Integration.Tests.ps1` | ~~Medium~~ Completed | Name-behaviour contradiction |
| 19 | `Get-DefaultModuleSettings.Tests.ps1` | ~~Medium~~ Completed | Fragile property count assertion |
| 20 | `Get-DefaultModuleSettings.Tests.ps1` | ~~Low~~ Completed | Redundant HotkeyKeyNames assertion |
| 21 | `Get-LWASTargetWindow.Tests.ps1` | ~~Low~~ Completed | Weak `-First` result assertion |
| 22 | `Get-LWASTargetWindow.Tests.ps1` | ~~Low~~ Completed | Missing ParameterFilter on Write-Error mock |
| 23 | `ModuleConfiguration.Tests.ps1` | ~~Medium~~ Completed | Over-granular tests; writes to real AppData |
| 24 | `MacroExecution.Tests.ps1` | ~~Medium~~ Completed | Potential `$script:` scope issue |
| 25 | `Show-MainMenu.Tests.ps1` | ~~Medium~~ Completed | Mixed shared/fresh console — order-dependent |
| 26 | `Show-ManageMacrosScreen.Tests.ps1` | ~~Low~~ Completed | Redundant closely-paired tests |
| 27 | `Get-RandomTargetPosition.Tests.ps1` | ~~Low~~ Completed | Non-standard BeforeAll placement; flaky stats |
| 28 | `Invoke-StartupConfigValidation.Tests.ps1` | ~~Low~~ Completed | Non-standard assertion syntax |
| 29 | `WindowAndProcessMonitor.Tests.ps1` | ~~Medium~~ Completed | Wrong cmdlet checked for error reporting |
| 30 | `MouseControl_Integration.Tests.ps1` | ~~Low~~ Completed | Race condition risk on keyboard state |
| 31 | `Show-ScheduleScreen.Tests.ps1` | ~~Low~~ Completed | Inconsistent TestConsole creation pattern |

---

## Files Reviewed and Found Clean

The following files were reviewed and contain no significant issues:

- `Set-WindowActive.Tests.ps1`
- `Set-WindowState.Tests.ps1`
- `Start-LWASAutomationSequence.Tests.ps1`
- `Test-ScreenshotSimilarity.Tests.ps1`
- `Unregister-LWASScheduledTask.Tests.ps1`
- `Write-LastWarLog.Tests.ps1`
- `WindowAndProcessMonitor_Integration.Tests.ps1`
- `ConsoleApp\ConsoleAppBridge.Tests.ps1`
- `ConsoleApp\Show-RecordMacroScreen.Tests.ps1`
- `ConsoleApp\Show-StorageInfoScreen.Tests.ps1`
- `ConsoleApp\Show-RunMacroScreen.Tests.ps1`
- `ConsoleApp\ConfigValidation.Tests.ps1`
- `ConsoleApp\Start-LWASConsole.Tests.ps1`
- `ConsoleApp\Show-ConfigMenuScreen.Tests.ps1`
- `ConsoleApp\Show-LoggingConfigScreen.Tests.ps1`
- `Get-LWASScheduledTask.Tests.ps1`
- `Register-LWASScheduledTask.Tests.ps1`
- `Resolve-MaskColour.Tests.ps1`
- `Resolve-ScreenshotFilename.Tests.ps1`
- `MouseCoordinates.Tests.ps1`
- `LoggingBackend.Tests.ps1`
- `Invoke-MouseDragClick.Tests.ps1`
