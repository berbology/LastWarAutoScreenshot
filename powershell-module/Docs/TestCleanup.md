# AI AGENTS IGNORE THIS FILE. DO NOT READ

# Test Suite Cleanup — Issue Register

Findings from a full audit of `powershell-module/Tests/`. Issues are grouped by severity.

---

## Severity 1 — Fudged (tests that cannot detect the bug they claim to cover)

### 1. (Completed) Invoke-StartupConfigValidation.Tests.ps1 — broken array type assertion

**File:** `Tests/ConsoleApp/Invoke-StartupConfigValidation.Tests.ps1`
**It block:** `Always returns an object with HasErrors (bool) and Messages (array) properties` (line 397)
**Issue:** The assertion `, $result.Messages | Should -BeOfType [array]` has a leading comma. In PowerShell a leading comma creates a new single-element array wrapping the value, so the expression is always of type `[array]` regardless of what `$result.Messages` actually is. The assertion can never fail.

**What it should do:** Assert `$result.Messages | Should -BeOfType [array]` (remove the leading comma).

---

### 2. (Completed) MouseMovement.Tests.ps1 — unreachable mock filter renders test hollow

**File:** `Tests/MouseMovement.Tests.ps1`
**It block:** `logs error and returns $false if virtual desktop dimensions are invalid` (lines 280–292)
**Issue:** The test sets `$mockCount = 0` and registers a mock with `-ParameterFilter { $mockCount -eq 999 }`. Because `$mockCount` is never incremented, the filter condition is never true and the mock never overrides the default `{ $true }` mock. The assertion `Should -Not -Be $null` is trivially true for any non-null return. The test cannot fail and does not exercise the claimed scenario (invalid virtual desktop dimensions).

---

## Severity 2 — Wrong target (test name / context does not match what is actually tested)

### 3. (Completed) Show-ConfigMenuScreen.Tests.ps1 — context and test name mismatch

**File:** `Tests/ConsoleApp/Show-ConfigMenuScreen.Tests.ps1`
**Context:** `When the user selects Screenshot settings then [Back to main menu]`
**It block:** `Screenshot settings option appears in console output` (lines 211–225)
**Issue:** The test only pushes a single Enter key, which selects `[Back to main menu]` (index 0, the default). Screenshot settings is never actually selected. The test only verifies that the text "Screenshot settings" appears in the rendered menu — which is covered identically by the `Output contains all five menu options` test in the `Console output` context.

---

### 4. (Completed) Show-MainMenu.Tests.ps1 — name claims "disabled Run macro label" but assertion checks unrelated strings

**File:** `Tests/ConsoleApp/Show-MainMenu.Tests.ps1`
**It block:** `Output contains the disabled Run macro label when no macros are present` (lines 98–112)
**Issue:** The assertion `$tc.Output | Should -Match 'Exit|Configure|Record'` checks for generic menu item text, not for a disabled "Run macro" label. A disabled item would typically render with different markup (e.g. a strikethrough or greyed colour). The test neither captures the specific "Run macro" text nor verifies any disabled styling. In fact, since when disabled the choice `Run macro` isn't shown to the user, the test should be renamed `Output does not contain Run macro label when no macros are present` and should test that instead.

---

### 5. (Completed) MouseMovement.Tests.ps1 — test claims to verify coordinate normalisation but checks only call count

**File:** `Tests/MouseMovement.Tests.ps1`
**It block:** `normalises coordinates to 0-65535 range based on virtual desktop` (lines 260–270)
**Issue:** The only assertion is `Should -Invoke Invoke-SendMouseInput -Exactly 1`. No assertion is made on the actual normalised coordinate values passed to `Invoke-SendMouseInput`. The comment in the test acknowledges this ("actual coordinate normalisation is tested via integration"), but the test name claims to verify normalisation. The test as written verifies only that `Invoke-SendMouseMoveAbsolute` delegates to `Invoke-SendMouseInput` once, which is already covered by the first test in the same Describe block.

---

## Severity 3 — Duplicate behaviour (two or more tests exercise the same observable outcome)

### 6. (Completed) Invoke-StartupConfigValidation.Tests.ps1 — identical "no output" assertions across two contexts

**File:** `Tests/ConsoleApp/Invoke-StartupConfigValidation.Tests.ps1`
**It blocks:**
- `Writes nothing to the Console output when all values are valid` (lines 59–74, context: *defaults*)
- `Does not write any panel to the Console when all values pass` (lines 96–111, context: *existing valid config*)

**Issue:** Both tests mock `Test-ConfigValue` to always return `Valid = $true` and assert `$tc.Output | Should -BeNullOrEmpty`. The mock configurations differ superficially (one has extra keys) but produce the same code path. The contexts should be distinguished by testing something that actually differs between the two scenarios. The names should obviously then change to reflect what they are actually testing

---

### 7. (Completed) Show-MainMenu.Tests.ps1 — three tests all navigate 3 DownArrows with no macros and assert ManageSchedules

**File:** `Tests/ConsoleApp/Show-MainMenu.Tests.ps1`
**It blocks:**
- `Navigating 3 DownArrows does not select RunMacro (RunMacro not available when no macros)` (lines 114–127) — returns `ManageSchedules`
- `Manage macros is not in menu when no macros present: 3 DownArrows reaches ManageSchedules` (lines 220–235) — returns `ManageSchedules`
- `Returns ManageSchedules when Manage schedules is selected (3 DownArrows, has window, no macros)` (lines 309–323) — returns `ManageSchedules`

**Issue:** All three push exactly 3 DownArrows and press Enter with no macros present, and all three assert the return value is `ManageSchedules`. The first two are identical. The third is in a separate context (`Manage schedules option`) but exercises the same code path with the same inputs.

---

### 8. (Completed) Show-ConfigMenuScreen.Tests.ps1 — negative invocation assertions duplicate what -Exactly 1 already implies

**File:** `Tests/ConsoleApp/Show-ConfigMenuScreen.Tests.ps1`
**It block:** `Does not call any other sub-screen when only Logging settings is chosen` (lines 85–105)
**Issue:** When `Should -Invoke Show-LoggingConfigScreen -Exactly 1` has already been asserted in the preceding test (line 81), asserting `Should -Not -Invoke Show-MouseControlConfigScreen` (etc.) adds no new information. If Logging was called exactly once, no other screen could have been called in the same iteration.

---

### 9. (Completed) Get-StorageInfo.Tests.ps1 — five separate tests for identical setup, one property each

**File:** `Tests/ConsoleApp/Get-StorageInfo.Tests.ps1`
**It blocks (lines 18–96):**
- `Returns IsConfigured=$false`
- `Returns 0.0 for UsedGB`
- `Returns 0.0 for MaxGB`
- `Returns 0.0 for UsedPercent`
- `Returns 0.0 for LogFileSizeGB`

**Issue:** All five tests in the `When Screenshots.StoragePath is an empty string` context use bit-for-bit identical mock setup (`Get-ModuleConfiguration` returning `StoragePath = ''`, `MaxStorageGB = 2.0`) and call `Get-StorageInfo` five separate times. Each test verifies a single property of the result. These should be consolidated into a single test (or use `-ForEach`).

---

### 10. (Completed) Show-LoggingConfigScreen.Tests.ps1 — two tests with identical setup checking different output subsets

**File:** `Tests/ConsoleApp/Show-LoggingConfigScreen.Tests.ps1`
**It blocks:**
- `Console output contains all five Logging key names` (lines 28–63)
- `Console output contains the current values from the loaded config` (lines 65–97)

**Issue:** Both tests use the same `$mockConfig` scriptblock, the same mock for `Save-ModuleSettings` and `Write-LastWarLog`, and the same input sequence (5x Enter, 2x DownArrow, Enter). They could be merged into a single test, or the setup should be extracted into a `BeforeEach`.

---

### 11. (Completed) MacroExecution.Tests.ps1 — DragClick test cannot distinguish correct start/end routing

**File:** `Tests/MacroExecution.Tests.ps1`
**It block:** `DragClick: calls ConvertTo-ScreenCoordinates twice and Invoke-MouseDragClick with screen coords` (lines 134–149)
**Issue:** `ConvertTo-ScreenCoordinates` is mocked in `BeforeEach` to always return `@{ X = 100; Y = 200 }` regardless of input. The `ParameterFilter` on `Invoke-MouseDragClick` asserts `$StartX -eq 100 -and $StartY -eq 200 -and $EndX -eq 100 -and $EndY -eq 200`. Because start and end map to the same mock return value, the filter would pass even if the function reversed start and end, or passed start for both arguments. The test cannot detect incorrect coordinate routing.

---

## Severity 4 — Structural / code quality smells

### 12. (Completed) WindowAndProcessMonitor.Tests.ps1 — Write-Host calls inside the test body

**File:** `Tests/WindowAndProcessMonitor.Tests.ps1`
**It block:** `Returns $false for an invalid handle` (lines 24–33)
**Issue:** The test calls `Write-Host` directly inside the `It` block to tell the runner to "ignore expected error messages". Tests should not emit diagnostic console output. The expected side-effect (an error print) should be handled by mocking the output function or by asserting it was called, not by manual suppression.

---

### 13. (Completed) Multiple files — shared TestConsole not reset between tests creates order-dependency

**Files:**
- `Tests/ConsoleApp/Invoke-StartupConfigValidation.Tests.ps1`
- `Tests/ConsoleApp/Show-ConfigMenuScreen.Tests.ps1`
- `Tests/ConsoleApp/Show-LoggingConfigScreen.Tests.ps1`
- `Tests/ConsoleApp/Show-MainMenu.Tests.ps1`
- `Tests/ConsoleApp/Show-MouseControlConfigScreen.Tests.ps1`
- `Tests/ConsoleApp/Show-ScreenshotConfigScreen.Tests.ps1`

**Issue:** These files create a single `$script:tc` TestConsole in `BeforeAll` and share it across all tests. The TestConsole's `Output` buffer accumulates across every test. This has two concrete consequences:

1. **False positives for `Should -Match`:** A test that asserts `$tc.Output | Should -Match 'SomeString'` will pass as long as *any prior test* rendered that string, even if the function under test in the current test produced no output at all.

2. **Fragile "no output" assertions:** Tests that assert `$tc.Output | Should -BeNullOrEmpty` are implicitly order-dependent — they only pass if they run before any test that writes to the console.

Tests in `Show-ManageMacrosScreen.Tests.ps1` correctly create a fresh TestConsole in `BeforeEach`. The same pattern should be applied to all files above.

**Additional concern:** Key presses pushed via `$tc.Input.PushKey()` accumulate in the input buffer. If a test pushes more keys than the function under test consumes, the leftover keys bleed into the next test's input. This can cause subsequent tests to navigate or confirm prompts unintentionally.

---

### 14. (Completed) Get-StorageInfo.Tests.ps1 — inexact assertion obscures a deterministic calculation

**File:** `Tests/ConsoleApp/Get-StorageInfo.Tests.ps1`
**It block:** `Calculates LogFileSizeGB from log files in the module root` (lines 277–300)
**Issue:** The mock returns a file of exactly 52,428,800 bytes. The test asserts `$result.LogFileSizeGB | Should -BeGreaterThan 0.04` and `Should -BeLessThan 0.06`. The calculation is entirely deterministic (`52428800 / 1073741824 ≈ 0.04883`). Using a fuzzy range hides potential precision or rounding errors that an exact assertion (e.g. `Should -BeApproximately 0.04883 0.00001`) would catch.

---

## Summary

| # | File | Severity | Category |
|---|------|----------|----------|
| 1 | Invoke-StartupConfigValidation.Tests.ps1 | Critical | Fudged — assertion always true |
| 2 | MouseMovement.Tests.ps1 | Critical | Fudged — unreachable mock, trivial assertion |
| 3 | Show-ConfigMenuScreen.Tests.ps1 | High | (Completed) Wrong target — context/name mismatch |
| 4 | Show-MainMenu.Tests.ps1 | High | (Completed) Wrong target — name doesn't match assertion |
| 5 | MouseMovement.Tests.ps1 | High | (Completed) Wrong target — claims normalisation, tests call count |
| 6 | Invoke-StartupConfigValidation.Tests.ps1 | Medium | (Completed) Duplicate — identical assertion in two contexts |
| 7 | Show-MainMenu.Tests.ps1 | Medium | (Completed) Duplicate — three tests, same 3-DownArrow navigation |
| 8 | Show-ConfigMenuScreen.Tests.ps1 | Medium | (Completed) Duplicate — negative mocks add no value |
| 9 | Get-StorageInfo.Tests.ps1 | Medium | (Completed) Duplicate — five separate tests, one property each |
| 10 | Show-LoggingConfigScreen.Tests.ps1 | Medium | (Completed) Duplicate — identical setup, split assertions |
| 11 | MacroExecution.Tests.ps1 | Medium | (Completed) Fudged — symmetric mock hides routing bugs |
| 12 | WindowAndProcessMonitor.Tests.ps1 | Low | (Completed) Write-Host in test body |
| 13 | Multiple files | High | (Completed) Structural — shared TestConsole, no reset |
| 14 | Get-StorageInfo.Tests.ps1 | Low | (Completed) Inexact assertion on deterministic value |
