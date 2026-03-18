# High-Level Task List for Auto Mouse Control Module

## Phase 1: Window Management & Safety

1. [x] Enumerate all open windows, including minimized and background apps, and allow user to select a target (e.g., LastWar.exe)
   1. [x] Design and create PowerShell Type Definitions for Win32 API window enumeration
      - [x] Define P/Invoke signatures for `EnumWindows` callback
      - [x] Define P/Invoke signatures for `GetWindowText` and `GetWindowTextLength`
      - [x] Define P/Invoke signatures for `IsWindowVisible`
      - [x] Define P/Invoke signatures for `GetWindowThreadProcessId`
      - [x] Define P/Invoke signatures for `IsIconic` (check if minimized)
      - [x] Define P/Invoke signatures for `GetForegroundWindow` (detect active window)
      - [x] Create `WindowEnumeration_TypeDefinition.ps1` in `powershell-module/private/` folder
      - [x] Add proper error handling for P/Invoke calls
   2. [x] Implement window enumeration function
      - [x] Create private function `Get-EnumeratedWindows` with comment-based help
      - [x] Implement enumeration logic using Win32 API callbacks
      - [x] Return collection of window objects with properties: ProcessName, WindowTitle, WindowHandle, PID, WindowState (Visible/Minimized)
      - [x] Ensure function is modular and testable via Pester
      - [x] Add optional filtering parameters: -ProcessName, -ExcludeMinimized, -VisibleOnly
      - [x] Implement ForEach-Object -Parallel optimization for Get-Process calls (ThrottleLimit 16)
      - [x] Handle process termination between enumeration and Get-Process gracefully
      - [x] Return both raw IntPtr handle and serializable string/int64 formats
      - [x] Filter out empty/null window titles and hidden system processes
      - [x] Collect enumeration errors for Event Log reporting
      - [x] Add comprehensive verbose output at each processing stage
      - [x] Create Pester unit tests with mock helper function New-MockWindowData
   3. [x] Implement console-based menu for user selection
      - [x] Create private function `Select-TargetWindowFromMenu` with comment-based help
      - [x] Display numbered list showing Process, Application (WindowTitle), Minimised status, Active indicator
      - [x] Accept user input (number) for window selection
      - [x] Validate user input and handle invalid selections
      - [x] Allow user to cancel selection (press 'x' to exit)
      - [x] Keep code modular for future GUI integration
      - [x] Implement arrow key navigation with scroll mode and blue text highlighting
      - [x] Support sorting by Process (P), Application (A), or Minimised (M) with ascending/descending toggle
      - [x] Implement simple and detailed view modes (toggle with D key)
      - [x] Add refresh capability (R key) for internally enumerated windows
      - [x] Display help menu (H key) below window list
      - [x] Detect and mark active (foreground) window with asterisk
      - [x] Use ANSI escape codes for colors and underlined header text
      - [x] Create comprehensive Pester unit tests in `Select-TargetWindowFromMenu.Tests.ps1`
   4. [x] Implement configuration persistence
      - [x] Check if existing configuration file exists (Test-ModuleConfigurationExists)
      - [x] Prompt user to save current config before overwriting (ShouldProcess with -Force parameter)
      - [x] Create function to save selected window target to configuration (Save-ModuleConfiguration)
      - [x] Store ProcessName, WindowTitle, WindowHandle, ProcessID, WindowState, and metadata in config
      - [x] Create function to load configuration from file (Get-ModuleConfiguration)
      - [x] Create comprehensive Pester unit tests in `ModuleConfiguration.Tests.ps1` (26 tests, all passing)
   5. [x] Implement error handling for all scenarios
        - [x] 1.5.1: No Windows Found After Filtering
           - [x] Add check after window enumeration and filtering for empty result.
           - [x] Log an error event (to file or event log).
           - [x] Display a clear, user-friendly message and exit gracefully.
           - [x] Write a Pester test for this scenario.
        - [x] 1.5.2: User Cancels Selection
           - [x] Detect user cancellation (e.g., 'x' key or cancel input).
           - [x] Log an informational event.
           - [x] Display a confirmation message and exit gracefully.
           - [x] Write a Pester test for this scenario.
        - [x] 1.5.3: Selected Window Closes Before Action
           - [x] Before performing any action on the selected window, check if the window still exists.
           - [x] If not, log an error event.
           - [x] Show an error popup or message to the user.
           - [x] Ensure the workflow aborts cleanly.
           - [x] Write a Pester test for this scenario.
        - [x] 1.5.4: Add Try-Catch to All Win32 API Calls
           - [x] Review all Win32 API calls in enumeration and selection logic.
           - [x] Wrap each call in a try-catch block.
           - [x] On exception, log error details (including exception message and stack trace).
           - [x] Display a user-friendly error message.
           - [x] Write a Pester test that simulates a Win32 API failure.
        - [x] 1.5.5: General Error Logging Consistency
            - [x] 1.5.5.1: Define standard logging format
               - [x] Specify required fields (function name, error type, context, timestamp, etc.)
               - [x] Document the format and update logging helper functions
            - [x] 1.5.5.2: Audit all error paths
               - [x] Review all functions for error/exception paths
               - [x] Ensure each path logs using the standardized format
               - [x] Add/modify log statements as needed
               - [x] Create/Amend tests for error logging
            - [x] 1.5.5.3: User feedback consistency
               - [x] Ensure every error log is paired with clear user-facing feedback
               - [x] Standardize user messages for common error types
            - [x] 1.5.5.4: Update/refactor logging functions
               - [x] Refactor or create logging functions to enforce the standard
               - [x] Add unit tests for these helpers
            - [x] 1.5.5.5: Pester tests for logging
               - [x] Mock logging/event functions
               - [x] Write tests to verify correct log output for each error scenario
            - [x] 1.5.5.6: Documentation
               - [x] Document the logging standard and usage in the codebase
   6. [x] Add Windows Event Logging
      1. [x] Design Logging Backend Abstraction
         - [x] 1.6.1.1: Define interface/contract for logging backends (event log, file, etc.)
         - [x] 1.6.1.2: Update logging helper functions to use backend abstraction (now script-based, not class-based)
         - [x] 1.6.1.3: Add configuration option to select logging backend (event log, file, both)
         - [x] 1.6.1.4: Document backend selection in module configuration schema
         - [x] 1.6.1.5: Create unit tests for backend abstraction and configuration logic
      2. [x] Implement Windows Event Log Backend
         - [x] 1.6.2.1: Register custom event log source ("LastWarAutoScreenshot") if not present
         - [x] 1.6.2.2: Implement event log writing using PowerShell Write-EventLog (with fallback/error handling)
         - [x] 1.6.2.3: Define event types and IDs for verbose, info, warning, error
         - [x] 1.6.2.4: Ensure all log fields (PID, WindowHandle, etc.) are included in event details
         - [x] 1.6.2.5: Add logic to handle permission errors (e.g., fallback to Application log or prompt user)
         - [x] 1.6.2.6: Create unit tests for event log backend, including source registration, event writing, error handling, and field coverage
      3. [x] Implement Local File Logging Backend Enhancements
         - [x] 1.6.3.1: Add log file rollover (by size, count, or age; configurable)
         - [x] 1.6.3.2: Implement cleanup of old log files based on retention policy
         - [x] 1.6.3.3: Ensure log format matches documented standard
         - [x] 1.6.3.4: Make rollover and retention settings configurable in module configuration
         - [x] 1.6.3.5: Create unit tests for file logging enhancements, including rollover, cleanup, and format validation
      4. [x] Update Logging Calls Throughout Codebase
          - [x] 1.6.4.1: Audit all existing logging calls and document locations/functions needing update
          - [x] 1.6.4.2: Refactor logging in each file (incremental, mark each as complete after tests pass):
             - [x] 1.6.4.2.1: Refactor logging in public functions (file-by-file)
             - [x] 1.6.4.2.2: Refactor logging in private/helper functions (file-by-file)
             - [x] 1.6.4.2.3: Refactor logging in error handling paths (file-by-file)
          - [x] 1.6.4.3: Review and ensure all event types (verbose, info, warning, error) are used appropriately in each function
          - [x] 1.6.4.4: Add/Update Pester tests for each logging scenario and backend (success and failure/error for each backend)
          - [x] 1.6.4.5: Validate test coverage for logging (aim for 100% of loggable paths)
      5. [x] Documentation
         - [x] 1.6.5.1: Document new logging backend options and configuration keys in Logging.md
         - [x] 1.6.5.2: Add PowerShell command-line usage examples for configuring and using logging backends (Logging.md)
         - [x] 1.6.5.3: Add troubleshooting section to Logging.md covering:
             - Permissions errors (file and event log)
             - Log file locations
             - Backend selection issues
         - [x] 1.6.5.4: Document event log source registration and permissions for both user and admin install scenarios (Logging.md)
         - [x] 1.6.5.5: Add screenshots, diagrams, and step-by-step walkthroughs for logging configuration and troubleshooting, following best practices and examples from popular projects (Logging.md)
         - [x] 1.6.5.6: Ensure all documentation is clear and targeted at gamers who are also developers
   7. [x] Create Pester unit tests
      - [x] Mock Win32 API calls for enumeration function tests
      - [x] Test filtering logic with various window states
      - [x] Test console menu input validation (valid, invalid, cancel)
      - [x] Test configuration save/load logic
      - [x] Test error handling scenarios
      - [x] Achieve minimum 80% code coverage
   8. [x] Update README.md
      - [x] Document new exported functions (if any made public)
      - [x] Update "Features" section to reflect window enumeration capabilities
      - [x] Add usage examples for window selection workflow
      - [x] Document configuration schema for window target settings
2. [x] Implement window state management: bring target window to front, restore if minimized, detect and handle window close/crash events
   1. [x] Extend PowerShell Type Definitions for window state management
      - [x] 2.1.1: Add P/Invoke signature for `ShowWindow` (support only minimize and maximize)
        - Only implement support for minimize and maximize window states (not restore or others)
        - Follow existing error handling and logging patterns
      - [x] 2.1.2: Add P/Invoke signature for `SetForegroundWindow` (bring window to front)
      - [x] 2.1.3: Update `WindowEnumeration_TypeDefinition.ps1` accordingly
      - [x] 2.1.4: Create Pester unit tests for new type definitions (ensure direct tests for type and method signatures)
   2. [x] Implement window state management functions
      - [x] 2.2.1: Create `Set-WindowState` (minimize/maximize window by handle)
        - Implement as a helper function to call ShowWindow for testability
        - Use approved PowerShell verbs and best practices for naming
      - [x] 2.2.2: Create `Set-WindowActive` (bring window to foreground by handle, optionally by WindowName or ProcessID)
        - Name function Set-WindowActive (not Activate-Window)
        - Parameters: same as Set-WindowState, plus optional WindowName or ProcessID
        - Provide user-facing feedback and log errors using conventions from Set-WindowState
        - Return $true on success, $false on failure
        - Display errors in red text in console footer
        - Pester tests for helper function and type definition, as with Set-WindowState
      - [x] 2.2.3: Add comment-based help and usage examples
      - [x] 2.2.4: Add error handling for all Win32 API calls (try/catch, log errors)
      - [x] 2.2.5: Provide user-facing feedback for all state changes (success/failure), display errors in red text in a console footer with a note to check event log or local log file for details
      - [x] 2.2.6: Log all errors using the standard logging backend
      - [x] 2.2.7: Create Pester unit tests for all new functions and error scenarios (include both type definition and helper function tests)
   3. [x] Implement window close/crash detection and handling (polling)
      - [x] 2.3.1: Use polling to check if the window handle is still valid (window close detection)
      - [x] 2.3.2: Implement process exit/crash detection using polling (not .NET event subscription) due to PowerShell runspace/test limitations
      - [x] 2.3.3: Detection of window closure or process exit should run continuously once started, until a function is called to stop it, or it dies and triggers error handling with retry/abort logic
      - [x] 2.3.4: If window is closed or process exits, prompt user to retry or abort; log as error
      - [x] 2.3.5: Provide user-facing feedback for all detection events (red text footer, log reference)
      - [x] 2.3.6: Document in code and README.md that true Win32 event hooks are not used due to complexity and maintainability concerns
        - In-code documentation added to both `Invoke-MonitorPoll` and `Start-WindowAndProcessMonitor` (.NOTES sections)
        - README.md Window Management section updated with polling rationale
      - [x] 2.3.7: Create Pester unit tests for detection and handling logic
   4. [x] Documentation
      - [x] 2.4.1: Document new functions and usage in README.md
      - [x] 2.4.2: Add usage and troubleshooting examples for window state management

## Phase 2: Mouse Control & Automation

1. [x] Implement mouse movement and click logic using `SendInput` Win32 API with window-relative percentage coordinate system
   1. [x] 1.1: Create `powershell-module/src/MouseControlAPI.cs`
      - Namespace `LastWarAutoScreenshot`, class `MouseControlAPI`
      - Structs: `POINT`, `RECT`, `MOUSEINPUT`, `INPUT` (FieldOffset union layout for unmanaged interop)
      - Constants: `INPUT_MOUSE`, `MOUSEEVENTF_MOVE`, `MOUSEEVENTF_LEFTDOWN`, `MOUSEEVENTF_LEFTUP`
      - P/Invoke: `SendInput(uint nInputs, INPUT[] pInputs, int cbSize)`, `GetCursorPos(out POINT lpPoint)`, `GetWindowRect(IntPtr hWnd, out RECT lpRect)`
      - `SetLastError = true` on every DllImport; `CharSet.Auto` only where a string parameter is present
      - Note: step 4.1's `GetAsyncKeyState` is added to this same class in step 4 - no `CursorControl_TypeDefinitions.ps1` file is needed
   2. [x] 1.2: Update `LastWarAutoScreenshot.psm1`
      - Add `MouseControlAPI.cs` path to the existing `Add-Type -Path` call
      - Add `'LastWarAutoScreenshot.MouseControlAPI'` to the `$typeNames` guard array (prevents re-adding in the same session)
   3. [x] 1.3: Create `powershell-module/Private/MouseControlHelpers.ps1`
      - `Invoke-SendMouseInput -DeltaX [int] -DeltaY [int] [-ButtonFlags [uint]]` - thin wrapper calling `[LastWarAutoScreenshot.MouseControlAPI]::SendInput`; logs Win32 error via `Write-LastWarLog` if return value = 0; returns $true/$false
      - `Invoke-GetCursorPosition` - thin wrapper calling `[LastWarAutoScreenshot.MouseControlAPI]::GetCursorPos`; returns `[PSCustomObject]@{X=[int]; Y=[int]}`
   4. [x] 1.4: Create `powershell-module/Private/Get-WindowBounds.ps1`
      - `Invoke-GetWindowRect -WindowHandle [IntPtr]` - one-liner thin wrapper calling `[LastWarAutoScreenshot.MouseControlAPI]::GetWindowRect`
      - `Get-WindowBounds -WindowHandle [object]` - accepts IntPtr, int64, int, string (same handle-conversion pattern as `Set-WindowState`); calls `Invoke-GetWindowRect`; returns `[PSCustomObject]@{Left; Top; Right; Bottom; Width; Height}`; error handling + `Write-LastWarLog`
   5. [x] 1.5: Create `powershell-module/Private/ConvertTo-ScreenCoordinates.ps1`
      - `ConvertTo-ScreenCoordinates -WindowHandle [object] -RelativeX [double] -RelativeY [double]`
      - Validates RelativeX and RelativeY are in range [0.0, 1.0]; logs error + returns `$null` if out-of-range
      - Calls `Get-WindowBounds`; computes `AbsoluteX = [int]($Bounds.Left + $RelativeX * $Bounds.Width)` and equivalent for Y
      - Returns `[PSCustomObject]@{X=[int]; Y=[int]}`
   6. [x] 1.6: Create `powershell-module/Private/Move-MouseToPoint.ps1` (step 1 placeholder - replaced by `Invoke-MouseMovePath` in step 2)
      - `Move-MouseToPoint -X [int] -Y [int]`
      - Calls `Invoke-GetCursorPosition` to get current position; computes delta to target; calls `Invoke-SendMouseInput` with `MOUSEEVENTF_MOVE`
      - Returns $true/$false; red ANSI footer on failure; logs error via `Write-LastWarLog`
      - `.NOTES`: documents this as a placeholder; replaced by `Invoke-MouseMovePath` in step 2.5
   7. [x] 1.7: Create `powershell-module/Private/Invoke-MouseClick.ps1`
      - `Invoke-MouseClick -X [int] -Y [int] [-DownDurationMs [int]]`
      - If X/Y differs from current cursor position, moves to X,Y first via `Move-MouseToPoint`
      - Reads `ClickDownDurationRangeMs` from config (random value within range) when `-DownDurationMs` is omitted
      - Calls `Invoke-SendMouseInput` for `MOUSEEVENTF_LEFTDOWN`, sleeps `DownDurationMs`, calls `Invoke-SendMouseInput` for `MOUSEEVENTF_LEFTUP`
      - Returns $true/$false; error handling + logging
   8. [x] 1.8: Add minimal `MouseControl` section to `powershell-module/Private/ModuleConfig.json`
      - `"MouseControl": { "ClickDownDurationRangeMs": [50, 150] }` - full section added in step 2.1
   9. [x] 1.9: Update `powershell-module/Private/Get-ModuleConfiguration.ps1` and `powershell-module/Private/Save-ModuleConfiguration.ps1`
      - Handle new `MouseControl` key with defaults; no breaking changes to existing keys
   10. [x] 1.10: Create `powershell-module/Public/Start-AutomationSequence.ps1` (skeleton)
       - `[CmdletBinding()]` parameters: `-WindowHandle [object]` (mandatory), `-RelativeX [double]`, `-RelativeY [double]`
       - Reads config `EmergencyStop.AutoStart`; calls `Start-EmergencyStopMonitor` if `$true`
       - Checks `$script:EmergencyStopRequested` - logs warning and exits cleanly if set before move
       - Calls `ConvertTo-ScreenCoordinates` → `Move-MouseToPoint` (step 1 placeholder; updated in step 2.6)
       - Checks `$script:EmergencyStopRequested` again after move - skips click and exits cleanly if set
       - Calls `Invoke-MouseClick`
       - `finally` block always calls `Stop-EmergencyStopMonitor`
       - Returns `[PSCustomObject]@{Success=[bool]; Message=[string]}`
       - `.NOTES`: documents step 2.6 as the upgrade point for human-like movement
   11. [x] 1.11: Update `LastWarAutoScreenshot.psd1`
       - Add `'Start-AutomationSequence'` to `FunctionsToExport`
   12. [x] 1.12: Create `powershell-module/Tests/MouseControl_TypeDefinition.Tests.ps1`
       - Verify `[LastWarAutoScreenshot.MouseControlAPI]` type loads without error
       - Verify `SendInput`, `GetCursorPos`, `GetWindowRect` static methods exist with correct signatures
       - Verify `POINT`, `RECT`, `MOUSEINPUT`, `INPUT` nested types exist and have expected public fields
   13. [x] 1.13: Create `powershell-module/Tests/MouseCoordinates.Tests.ps1`
       - `Get-WindowBounds`: mock `Invoke-GetWindowRect`; verify PSCustomObject shape; verify `Width = Right - Left`; verify error log + $false on Win32 failure
       - `ConvertTo-ScreenCoordinates`: mock `Get-WindowBounds`; verify correct absolute coordinates for several (x%, y%) values; verify `$null` + error log when input is outside [0.0, 1.0]
   14. [x] 1.14: Create `powershell-module/Tests/MouseMovement.Tests.ps1` (step 1 sections)
       - `Move-MouseToPoint`: mock `Invoke-GetCursorPosition` + `Invoke-SendMouseInput`; verify single SendInput call with correct delta; verify $false + error log on SendInput returning 0
       - `Invoke-MouseClick`: mock `Move-MouseToPoint` + `Invoke-SendMouseInput` + `Start-Sleep`; verify LEFTDOWN then LEFTUP calls with sleep between; verify config-derived duration used when `-DownDurationMs` omitted; verify $false + error log on failure
   15. [x] 1.15: Create `powershell-module/Tests/Start-AutomationSequence.Tests.ps1` (step 1 sections)
       - Mock `ConvertTo-ScreenCoordinates`, `Move-MouseToPoint`, `Invoke-MouseClick`, `Start-EmergencyStopMonitor`, `Stop-EmergencyStopMonitor`
       - `EmergencyStop.AutoStart = $true` → `Start-EmergencyStopMonitor` called
       - `$script:EmergencyStopRequested = $true` before move → exits cleanly; `Move-MouseToPoint` not called
       - `$script:EmergencyStopRequested = $true` after move → `Invoke-MouseClick` not called
       - `Stop-EmergencyStopMonitor` called in `finally` on both success and error paths
       - Correct PSCustomObject returned on success and failure
   16. [x] 1.16: Run full Pester suite - all existing + new tests pass
2. [x] Develop human-like mouse movement
   1. [x] 2.1: Expand `powershell-module/Private/ModuleConfig.json` with full `MouseControl` section (replaces the minimal step 1.8 entry)

      ```json
      "MouseControl": {
          "EasingEnabled": true,
          "OvershootEnabled": true,
          "OvershootFactor": 0.1,
          "MicroPausesEnabled": true,
          "MicroPauseChance": 0.2,
          "MinMicroPauseDurationMs": 20,
          "MaxMicroPauseDurationMs": 80,
          "JitterEnabled": true,
          "JitterRadiusPx": 2,
          "BezierControlPointOffsetFactor": 0.3,
          "MovementDurationRangeMs": [200, 600],
          "ClickDownDurationRangeMs": [50, 150],
          "ClickPreDelayRangeMs": [50, 200],
          "ClickPostDelayRangeMs": [100, 300],
          "PathPointCount": 20
      }
      ```

   2. [x] 2.2: Update `powershell-module/Private/Get-ModuleConfiguration.ps1` and `powershell-module/Private/Save-ModuleConfiguration.ps1`
      - Full `MouseControl` defaults; no breaking changes to existing keys
   3. [x] 2.3: Add round-trip tests for all new config keys to `powershell-module/Tests/ModuleConfiguration.Tests.ps1`
      - Verify all new defaults present when key is missing from file; verify save/load round-trip
   4. [x] 2.4: Create `powershell-module/Private/Get-BezierPoints.ps1`
      - `Get-BezierPoints -StartX [int] -StartY [int] -EndX [int] -EndY [int] [-NumPoints [int]] [-ControlPointOffsetFactor [double]] [-JitterRadiusPx [int]]`
      - All parameters default from config when omitted
      - `NumPoints` randomised ±20% before use (eliminates consistent step-interval timing signature)
      - Control point = midpoint + random perpendicular offset scaled by `ControlPointOffsetFactor × pathLength`
      - Bezier formula: `B(t) = (1−t)²·P₀ + 2(1−t)t·P₁ + t²·P₂` for t = 0..1 across `NumPoints` steps
      - Jitter: if `JitterEnabled`, add ±`JitterRadiusPx` random noise (integer) to each computed X, Y
      - Returns `[PSCustomObject[]]` each with integer `X` and `Y` properties
      - Pure `[math]` only - no `Add-Type`, no P/Invoke; fully testable
   5. [x] 2.5: Create `powershell-module/Private/Invoke-MouseMovePath.ps1`
      - `Invoke-MouseMovePath -Points [PSCustomObject[]]`
      - Total move duration: random within `MovementDurationRangeMs` config range
      - Ease-in/out: per-step delay derived from sinusoidal curve so movement is slow at start and end, fast mid-path
      - At each step: compute delta from previous point → `Invoke-SendMouseInput` → sleep step delay
      - Micro-pauses: after each step delay, with probability `MicroPauseChance` add an extra random sleep between `MinMicroPauseDurationMs` and `MaxMicroPauseDurationMs`
      - Overshoot: after main path completes, if `OvershootEnabled`, compute a small vector past the final point (scaled by `OvershootFactor × last-step-length`); execute a mini correction path back to the target using a second Bezier (no further overshoot on the correction move)
      - Returns $true/$false; logs any SendInput errors; red ANSI footer on failure
   6. [x] 2.6: Update `powershell-module/Public/Start-AutomationSequence.ps1`
      - Replace `Move-MouseToPoint` call with: `Invoke-GetCursorPosition` → `Get-BezierPoints` → `Invoke-MouseMovePath`
      - Add `ClickPreDelay` (random sleep within `ClickPreDelayRangeMs`) before `Invoke-MouseClick`
      - Add `ClickPostDelay` (random sleep within `ClickPostDelayRangeMs`) after `Invoke-MouseClick`
   7. [x] 2.7: Add step 2 sections to `powershell-module/Tests/MouseMovement.Tests.ps1`
      - `Get-BezierPoints`:
        - At least one intermediate point is non-collinear with start/end (confirms curve is not a straight line)
        - Returned count within ±40% of base `NumPoints` (accounts for ±20% randomisation)
        - All returned objects have integer `X` and `Y` properties
        - No `[LastWarAutoScreenshot.*]` type invocation (confirms pure `[math]` implementation)
      - `Invoke-MouseMovePath`:
        - Mock `Invoke-SendMouseInput` + `Start-Sleep`; verify `Invoke-SendMouseInput` called once per point
        - Ease-in/out: capture delay args to `Start-Sleep`; assert first + last delays are greater than median delay
        - `MicroPauseChance = 1.0`: extra `Start-Sleep` calls equal to point count
        - `OvershootEnabled = $true`: `Invoke-SendMouseInput` called beyond point count (extra correction path)
        - SendInput failure: error logged, no unhandled exception
   8. [x] 2.8: Add step 2 sections to `powershell-module/Tests/Start-AutomationSequence.Tests.ps1`
      - Verify `Invoke-MouseMovePath` called instead of `Move-MouseToPoint`
      - Verify `ClickPreDelay` and `ClickPostDelay` `Start-Sleep` calls are present
   9. [x] 2.9: Run full Pester suite - all existing + new tests pass
   10. [x] 2.10: Update `LastWarAutoScreenshot/Docs/README.md`
       - Document all `MouseControl` config keys with types, defaults, and examples
       - Document human-like movement behaviour: Bezier path shaping, ease-in/out, jitter, micro-pauses, overshoot/correction
3. [x] Allow user to define bounding box or circle as cursor target; randomly select position within defined area for each action
   1. [x] 3.1: Create `powershell-module/Private/Get-RandomTargetPosition.ps1`
      - Two `[CmdletBinding()]` parameter sets:
        - **Box**: `-Box [PSCustomObject]` with properties `RelativeX`, `RelativeY`, `RelativeWidth`, `RelativeHeight` (all 0.0-1.0) - uniform random within `[RelativeX, RelativeX+RelativeWidth] × [RelativeY, RelativeY+RelativeHeight]`
        - **Circle**: `-Circle [PSCustomObject]` with `RelativeCentreX`, `RelativeCentreY`, `RelativeRadius` - `angle = 2π × random`, `r = √random × RelativeRadius` (sqrt ensures uniform density, not concentrated at centre), `X = CentreX + r·cos(angle)`, `Y = CentreY + r·sin(angle)`
      - Output clamped to [0.0, 1.0] on both axes
      - Returns `[PSCustomObject]@{RelativeX=[double]; RelativeY=[double]}` or `$null` with error log on invalid input
      - Pure PowerShell - no `Add-Type`
   2. [x] 3.2: Create `powershell-module/Tests/Get-RandomTargetPosition.Tests.ps1`
      - Box: 100-iteration loop - all returned points within `[RelativeX, RelativeX+RelativeWidth]` × `[RelativeY, RelativeY+RelativeHeight]`
      - Circle: 100-iteration loop - all returned points within `RelativeRadius` of centre
      - Circle distribution: mean of 100 points clusters near centre (within 10% of radius on each axis)
      - Invalid input (negative radius, region values outside [0.0, 1.0]) → `$null` returned + error logged
      - Clamp: no returned value is below 0.0 or above 1.0
   3. [x] 3.3: Update `powershell-module/Public/Start-AutomationSequence.ps1`
      - Add optional `-Region [PSCustomObject]` parameter via parameter sets (mutually exclusive with `-RelativeX`/`-RelativeY`)
      - If `-Region` provided: call `Get-RandomTargetPosition` to obtain `RelativeX`, `RelativeY`
      - If scalar `-RelativeX`/`-RelativeY` provided: use directly
      - Both paths produce a single (RelativeX, RelativeY) pair before `ConvertTo-ScreenCoordinates`; downstream logic unchanged
   4. [x] 3.4: Add step 3 sections to `powershell-module/Tests/Start-AutomationSequence.Tests.ps1`
      - Mock `Get-RandomTargetPosition`; verify called when `-Region` is provided
      - Verify `Get-RandomTargetPosition` not called when scalar `-RelativeX`/`-RelativeY` are provided
   5. [x] 3.5: Run full Pester suite - new test count meets or exceeds the pre-steps-1-3 baseline
   6. [x] 3.6: Update `LastWarAutoScreenshot/Docs/README.md`
      - Document `-Region` parameter with Box and Circle formats, field descriptions, and usage examples
4. [x] Implement emergency stop mechanisms
   1. [x] Add `GetAsyncKeyState` P/Invoke to `powershell-module/src/MouseControlAPI.cs` (created in step 1.1)
      - Add single `GetAsyncKeyState(int vKey)` DllImport method to the existing `LastWarAutoScreenshot.MouseControlAPI` C# class - no new files or types
      - All references to `[Win32.MouseControl]::` in steps 4.3-4.5 use `[LastWarAutoScreenshot.MouseControlAPI]::` to match the established namespace convention
      - Note: the virtual key code for `#` is keyboard-layout-dependent (`VK_OEM_5` = 0xDC on UK layouts; Shift+3 on US layouts) - document this in code comments and README
      - Pester test for the type definition goes in `powershell-module/Tests/MouseControl_TypeDefinition.Tests.ps1` (created in step 1.12); add a test verifying `GetAsyncKeyState` exists on the type and is callable with a known safe key code (e.g. VK_SHIFT = 0x10)
   2. [x] Add emergency stop settings to module configuration
      - Add `EmergencyStop.HotkeyVKeyCodes` (int array, default: [0x11, 0x10, 0xDC] - Ctrl, Shift, # on UK layout)
      - Add `EmergencyStop.PollIntervalMs` (int, default: 100)
      - Add `EmergencyStop.AutoStart` (bool, default: true - monitor auto-starts when the automation sequence starts)
      - Update `ModuleConfig.json` with new keys and defaults
      - Update `Get-ModuleConfiguration` and `Save-ModuleConfiguration` to handle new keys (no breaking changes)
      - Update `ModuleConfiguration.Tests.ps1` to cover new config keys (round-trip save/load, defaults)
   3. [x] Implement `Invoke-EmergencyStopPoll` (private)
      - Same extracted-poll pattern as `Invoke-MonitorPoll` - exists solely to make the timer callback testable without physical keypresses
      - Parameter: `$State` hashtable with keys: `Stopped` (bool), `Timer` (System.Timers.Timer), `HotkeyVKeyCodes` (int[]), `GetKeyStateFn` (ScriptBlock - injectable mock; defaults to `[LastWarAutoScreenshot.MouseControlAPI]::GetAsyncKeyState($vKey)` when $null)
      - Early-return if `$State.Stopped -eq $true`
      - Check each VKey code via `GetKeyStateFn`; test the high-order bit (0x8000) - key currently held down, not the "pressed since last call" bit
      - If all keys held: set `$script:EmergencyStopRequested = $true`, set `$State.Stopped = $true`, stop timer, log Error via `Write-LastWarLog`, write red ANSI console message advising user to check logs
      - Write Pester tests covering:
         - All keys held → flag set, timer stopped, log called, red console message written
         - Partial key hold → no action taken
         - No keys held → no action taken
         - `$State.Stopped` already `$true` → returns immediately, nothing else called
         - `GetKeyStateFn` throws → error logged, no unhandled exception
   4. [x] Implement `Start-EmergencyStopMonitor` (public)
      - `[CmdletBinding()]` with optional parameters: `-PollIntervalMs` (int), `-HotkeyVKeyCodes` (int[]) - both read from module config when omitted
      - Idempotent: if `$script:EmergencyStopTimer` is already running, log Info `"Emergency stop monitor is already running - ignoring duplicate start"` and return without starting a second timer
      - On a clean start: reset `$script:EmergencyStopRequested = $false`
      - Build `$State` hashtable; create and start `System.Timers.Timer` with `AutoReset = $true`; store in `$script:EmergencyStopTimer`; Elapsed handler calls `Invoke-EmergencyStopPoll` via `.GetNewClosure()`
      - Return `[PSCustomObject]` with `Stop` and `Cleanup` scriptblocks (same contract as `Start-WindowAndProcessMonitor`)
      - Add full comment-based help including `.NOTES` documenting: why polling is used over `RegisterHotKey`, the re-arming requirement, and that automation loop integration is in Mouse Control step 1
      - Write Pester tests:
         - First call starts timer, `$script:EmergencyStopRequested` reset to `$false`, correct object returned
         - Second call logs Info and returns without starting another timer
         - Config defaults used when parameters are omitted
         - Returned `Stop` scriptblock sets `$State.Stopped = $true` and stops the timer
   5. [x] Implement `Stop-EmergencyStopMonitor` (public)
      - Stops and disposes `$script:EmergencyStopTimer`; sets `$script:EmergencyStopTimer = $null`
      - Does NOT reset `$script:EmergencyStopRequested` - document clearly: callers must reset the flag manually before re-arming
      - Log Info `"Emergency stop monitor stopped"` via `Write-LastWarLog`
      - Calling when already stopped must not throw
      - Add full comment-based help
      - Write Pester tests:
         - Timer stopped and variable nulled
         - `$script:EmergencyStopRequested` not modified by this call
         - Log call verified via mock
         - Calling when monitor is not running does not throw
   6. [x] Implement mouse gesture detection: hold both mouse buttons for 3 seconds
      - Detect simultaneous left and right mouse button hold using `GetAsyncKeyState` (VK_LBUTTON 0x01, VK_RBUTTON 0x02) - reuse same poll infrastructure from 4.3
      - Count consecutive polls where both buttons are held; trigger after 3 seconds worth of poll intervals (3000 / PollIntervalMs ticks)
      - On trigger: same behaviour as hotkey (set `$script:EmergencyStopRequested`, log Error, red console message)
      - Write Pester tests via injected mock with a counter simulating consecutive held polls
   7. [x] Integration point - implement as part of Mouse Control step 1
      - If `$Config.EmergencyStop.AutoStart -eq $true`, automation sequence start function calls `Start-EmergencyStopMonitor`
      - Each iteration of the automation loop checks `if ($script:EmergencyStopRequested)` and exits gracefully with cleanup if true
      - Automation sequence end/cleanup calls `Stop-EmergencyStopMonitor`
   8. [x] Run full Pester test suite; confirm test count meets or exceeds the pre-task baseline before marking any sub-task complete
   9. [x] Update README.md
   10. [x] Move hardcoded module configuration values out of `Start-EmergencyStopMonitor`; make `Get-ModuleConfiguration` the single source of truth
       - `Get-ModuleConfiguration` must never return `$null`; when the config file does not exist it creates one at the default path containing only the module-settings sections (Logging, MouseControl, EmergencyStop) with all defaults, logs an Info message, and returns the defaults object (required window-property validation is skipped for a fresh defaults-only file)
       - Remove the hardcoded `$effectivePollIntervalMs = 100` and `$effectiveHotkeyVKeyCodes = @(0x11, 0x10, 0xDC)` fallback constants from `Start-EmergencyStopMonitor`; remove the surrounding `try/catch` that guarded the config load; call `Get-ModuleConfiguration` directly and use `$config.EmergencyStop.PollIntervalMs` / `$config.EmergencyStop.HotkeyVKeyCodes`
       - Update `ModuleConfiguration.Tests.ps1`: replace the "returns `$null` when file does not exist" tests with tests that assert a default config is created and returned; add `AfterEach` cleanup for the generated file; add a test that verifies `Get-ModuleConfiguration` creates the config file on disk
       - Update `EmergencyStop.Tests.ps1` (if needed): add a test asserting that `Start-EmergencyStopMonitor` propagates an error when `Get-ModuleConfiguration` throws; remove any test that relied on the hardcoded fallback path
      - Document `Start-EmergencyStopMonitor` and `Stop-EmergencyStopMonitor` with usage examples
      - Document the default hotkey (`Ctrl+Shift+#`), how to change it via config, and the keyboard-layout caveat for the `#` key VKCode
      - Document `$script:EmergencyStopRequested`: what sets it, what reads it, and the re-arming requirement
      - Document all three config keys (`HotkeyVKeyCodes`, `PollIntervalMs`, `AutoStart`) with types, defaults, and examples

## Phase 3: Design & Build Console App

### Architecture decisions (record here for future reference)

- **UI library:** Spectre.Console loaded via `Add-Type` from bundled DLLs in `powershell-module/lib/`
- **Bridge pattern:** A thin C# wrapper class `ConsoleAppBridge.cs` in `powershell-module/src/` exposes PowerShell-friendly static methods over Spectre.Console's fluent API, consistent with the existing `MouseControlAPI.cs` / `WindowEnumerationAPI.cs` pattern
- **Testability:** Every screen function accepts a `$Console` parameter typed `[Spectre.Console.IAnsiConsole]`; tests inject `[Spectre.Console.Testing.TestConsole]::new()` and assert on `$testConsole.Output`
- **Entry point:** `Start-LastWarAutoScreenshot` (public, exported) - the single function users call to launch the app
- **Folder layout:** All screen/page functions live in `Private/ConsoleApp/`; tests in `Tests/ConsoleApp/`
- **Macro storage:** `Private/Macros/yyyyMMdd_HHmmss_<name>.json` - one file per macro; Phase 3 only checks existence; Phase 4 defines the format
- **DLL versioning:** Bundled at a specific version recorded in `lib/VERSIONS.txt`; never auto-updated
- **Config validation:** Per-key validation rules co-located with defaults in `Get-DefaultModuleSettings.ps1`; a new `$script:ConfigValidationSchema` hashtable is added alongside the existing defaults object

### Phase 3 scope (what is and is not included)

**Included:** Main menu, window selection screen, configuration screens (Logging, MouseControl, EmergencyStop), storage info screen, startup config validation, `IAnsiConsole` injection throughout, full Pester test coverage using `TestConsole`.

**Explicitly out of scope for Phase 3:** Task Scheduler (6), visual screenshot region selection (Phase 5), live mouse coordinate display during recording (Phase 4).

---

1. [x] Acquire, bundle and load `Spectre.Console` DLLs
   1. [x] 1.1: Create `powershell-module/lib/` folder
      - Download `Spectre.Console` NuGet package at the latest stable version using:

        ```powershell
        # One-time command to extract the DLL (does not require dotnet SDK, only nuget.exe or Invoke-WebRequest)
        Invoke-WebRequest "https://www.nuget.org/api/v2/package/Spectre.Console/<version>" -OutFile spectre.nupkg
        # Rename to .zip, extract, copy net6.0/Spectre.Console.dll to powershell-module/lib/
        ```

      - Copy `Spectre.Console.dll` to `powershell-module/lib/Spectre.Console.dll`
      - Repeat for `Spectre.Console.Testing` NuGet package; copy `Spectre.Console.Testing.dll` to `powershell-module/lib/test/Spectre.Console.Testing.dll`
      - Create `powershell-module/lib/VERSIONS.txt` with content:

        ```
        Spectre.Console=<exact version bundled>
        Spectre.Console.Testing=<exact version bundled>
        ```

        Record the exact version strings here in the plan once known
      - Add `powershell-module/lib/**/*.dll` to `.gitattributes` with `binary` attribute so git does not diff the DLLs
      - Do NOT add them to `.gitignore` - they must be committed and shipped with the module
   2. [x] 1.2: Create `powershell-module/src/ConsoleAppBridge.cs`
      - Namespace `LastWarAutoScreenshot`, class `ConsoleAppBridge`
      - References `Spectre.Console.dll`; must be compiled via `Add-Type -Path ... -ReferencedAssemblies`
      - Purpose: expose clean, PowerShell-callable static factory/helper methods that hide Spectre.Console's fluent/generic API from PowerShell callers; keeps PS code readable
      - Initial methods to include (others added per screen as needed):
        - `static IAnsiConsole CreateConsole()` - returns `AnsiConsole.Console` (the real live console)
        - `static SelectionPrompt<string> CreateSelectionPrompt(string title, string[] choices)` - creates a standard prompt ready to call `.Show(console)`
        - `static Table CreateTable(string[] columns)` - creates a `Table` with standard border style used project-wide
        - `static Panel CreatePanel(string content, string header)` - creates a `Panel` with standard styling
      - `SetLastError = false` - no P/Invoke in this file; it is pure managed .NET
      - Full XML doc comments on all public methods
   3. [x] 1.3: Update `LastWarAutoScreenshot.psm1`
      - Add `$spectreConsolePath = "$PSScriptRoot\lib\Spectre.Console.dll"` alongside the existing source path variables
      - Add `$consoleAppBridgePath = "$PSScriptRoot\src\ConsoleAppBridge.cs"` alongside the existing source path variables
      - Add both to the existing `$missingFiles` check loop (fatal if absent)
      - Add `'LastWarAutoScreenshot.ConsoleAppBridge'` to the `$typeNames` guard array
      - Load `Spectre.Console.dll` first (before compiling `ConsoleAppBridge.cs`) using `Add-Type -Path $spectreConsolePath`
      - Compile `ConsoleAppBridge.cs` using `Add-Type -Path $consoleAppBridgePath -ReferencedAssemblies $spectreConsolePath`
      - Dot-source all `Private/ConsoleApp/*.ps1` files in the existing private dot-sourcing loop (the loop already covers `Private/` - ensure it uses `-Recurse` so the subfolder is picked up automatically, or add an explicit `Get-ChildItem` call for the subfolder if `-Recurse` causes ordering issues)
   4. [x] 1.4: Create `powershell-module/Tests/ConsoleApp/` folder
      - Add a `README.md` placeholder noting this folder holds all Phase 3 tests; to be populated per screen
   5. [x] 1.5: Verify the module loads cleanly after steps 1.1-1.4
      - Run: `Import-Module .\LastWarAutoScreenshot\LastWarAutoScreenshot.psd1 -Force -Verbose`
      - Confirm `[LastWarAutoScreenshot.ConsoleAppBridge]` type is accessible with no errors
      - Confirm `[Spectre.Console.AnsiConsole]` type is accessible
      - Confirm existing tests still pass (run full Pester suite; count must meet or exceed previous baseline)
   6. [x] 1.6: Create `powershell-module/Tests/ConsoleApp/ConsoleAppBridge.Tests.ps1`
      - `[LastWarAutoScreenshot.ConsoleAppBridge]` type loads without error
      - `CreateConsole()` returns a non-null object
      - `CreateSelectionPrompt(title, choices)` returns a non-null object with `.Title` equal to the supplied title
      - `CreateTable(columns)` returns a non-null `Table`-typed object
      - `CreatePanel(content, header)` returns a non-null `Panel`-typed object
      - Run full Pester suite; confirm count increases

2. [x] Add config validation schema to `Get-DefaultModuleSettings.ps1`
   1. [x] 2.1: Define the validation schema structure
      - Add a `$script:ConfigValidationSchema` hashtable to `Get-DefaultModuleSettings.ps1` alongside the existing `Get-DefaultModuleSettings` function (not inside of it - module-scoped constant)
      - Schema format - each entry is keyed by `"Section.Key"` and contains:

        ```powershell
        @{
            Type         = 'int'                      # 'int', 'double', 'bool', 'string', 'intArray', 'stringEnum'
            Min          = 1                           # optional; numeric lower bound (inclusive)
            Max          = 1000                        # optional; numeric upper bound (inclusive)
            AllowedValues = @('File', 'EventLog', 'File,EventLog')  # optional; for stringEnum
            Description  = 'Human-readable description shown in the config screen'
            Nullable     = $false                      # whether $null is a valid value
        }
        ```

      - Populate entries for all keys in `Logging`, `MouseControl`, and `EmergencyStop` sections (every key that a user can change via the config screen)
      - Example entries to include:
        - `'Logging.MinimumLogLevel'` - `stringEnum`; `AllowedValues = @('Verbose','Info','Warning','Error')`
        - `'Logging.Backend'` - `stringEnum`; `AllowedValues = @('File','EventLog','File,EventLog')`
        - `'Logging.FileBackend.MaxSizeMB'` - `int`; `Min = 1`, `Max = 10240`
        - `'Logging.FileBackend.MaxAgeDays'` - `int`; `Min = 1`, `Max = 3650`
        - `'Logging.FileBackend.MaxLogFileCount'` - `int`; `Min = 1`, `Max = 100000`
        - `'MouseControl.OvershootFactor'` - `double`; `Min = 0.0`, `Max = 1.0`
        - `'MouseControl.MicroPauseChance'` - `double`; `Min = 0.0`, `Max = 1.0`
        - `'MouseControl.JitterRadiusPx'` - `int`; `Min = 0`, `Max = 20`
        - `'MouseControl.BezierControlPointOffsetFactor'` - `double`; `Min = 0.0`, `Max = 2.0`
        - `'MouseControl.MovementDurationRangeMs'` - `intArray`; both elements `Min = 0`, `Max = 5000`; element[0] must be ≤ element[1]
        - `'MouseControl.ClickDownDurationRangeMs'` - `intArray`; same constraints as above
        - `'MouseControl.ClickPreDelayRangeMs'` - `intArray`; same
        - `'MouseControl.ClickPostDelayRangeMs'` - `intArray`; same
        - `'MouseControl.MinMicroPauseDurationMs'` - `int`; `Min = 0`, `Max = 5000`
        - `'MouseControl.MaxMicroPauseDurationMs'` - `int`; `Min = 0`, `Max = 5000`
        - `'MouseControl.PathPointCount'` - `int`; `Min = 5`, `Max = 200`
        - `'EmergencyStop.PollIntervalMs'` - `int`; `Min = 10`, `Max = 5000`
        - `'EmergencyStop.MouseGestureHoldDurationMs'` - `int`; `Min = 500`, `Max = 30000`
        - `'EmergencyStop.AutoStart'` - `bool`
        - `'EmergencyStop.MouseGestureEnabled'` - `bool`
        - `'MouseControl.EasingEnabled'`, `'MouseControl.OvershootEnabled'`, `'MouseControl.MicroPausesEnabled'`, `'MouseControl.JitterEnabled'` - all `bool`
   2. [x] 2.2: Create `Test-ConfigValue` (private) in `Private/ConsoleApp/Test-ConfigValue.ps1`
      - `Test-ConfigValue -Key [string] -Value [object]`
      - Looks up `$script:ConfigValidationSchema[$Key]` - returns `[PSCustomObject]@{Valid=$true; Message=''}` if key not in schema (unknown keys pass through silently)
      - Validates `Type`, `Min`/`Max` (for numerics and each element of intArray), `AllowedValues` (case-insensitive for stringEnum), `Nullable`
      - For `intArray`: validates element count is exactly 2 and element[0] ≤ element[1]
      - Returns `[PSCustomObject]@{Valid=[bool]; Message=[string]}` - `Message` is the human-readable error shown in the config screen when `Valid = $false`
      - Pure PowerShell; no `Add-Type`; fully testable
   3. [x] 2.3: Create `powershell-module/Tests/ConsoleApp/ConfigValidation.Tests.ps1`
      - `Test-ConfigValue`: valid int within range → `Valid=$true`; int below Min → `Valid=$false` with non-empty message; int above Max → same; stringEnum valid value → `Valid=$true`; invalid value → `Valid=$false`; bool true → `Valid=$true`; intArray with element[0] > element[1] → `Valid=$false`; unknown key not in schema → `Valid=$true`
      - Run full Pester suite; confirm count increases

3. [x] Create the entry point and main menu screen
   1. [x] 3.1: Create `powershell-module/Private/ConsoleApp/Show-MainMenu.ps1`
      - `Show-MainMenu -Console [Spectre.Console.IAnsiConsole]`
      - Displays a `SelectionPrompt` with the following options:
        - `Select target window`
        - `Configure module`
        - `Record macro` (stub - displays "Not yet available" panel when chosen; returns to main menu)
        - `Run macro` - greyed out (disabled choice text, different Spectre.Console style) when no `*.json` files exist in the module's `Macros/` folder; shows `SelectionPrompt` of macro filenames (parsed from `yyyyMMdd_HHmmss_<name>.json` filenames) when macros do exist
        - `Exit`
      - To detect macros: check `Join-Path $script:ModuleRootPath 'Private\Macros\*.json'` using `Get-ChildItem`; if count is 0 the option is rendered as `[grey](No macros recorded)[/]` and is excluded from selectable choices
      - Returns a string matching one of the menu option identifiers: `'SelectWindow'`, `'Configure'`, `'RecordMacro'`, `'RunMacro'`, `'Exit'`
      - Full comment-based help
   2. [x] 3.2: Create `powershell-module/Public/Start-LastWarAutoScreenshot.ps1`
      - `[CmdletBinding()]` - no mandatory parameters
      - Optional `[Spectre.Console.IAnsiConsole]$Console` parameter defaulting to `[LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()`; this is the testability injection point
      - On startup:
        1. Validates the config file via `Invoke-StartupConfigValidation` (step 3.3) - displays any errors/warnings as a Spectre.Console `Panel` with red/yellow markup before the main menu appears; does not abort, user must acknowledge with Enter
        2. Enters an infinite `while ($true)` loop calling `Show-MainMenu -Console $Console`
        3. Dispatches on the returned menu option string via `switch`
        4. `'Exit'` breaks the loop
        5. All other options call the relevant screen function (steps 4, 5, 6) passing `$Console`
      - Full comment-based help with `.NOTES` documenting the `$Console` injection pattern
   3. [x] 3.3: Create `powershell-module/Private/ConsoleApp/Invoke-StartupConfigValidation.ps1`
      - `Invoke-StartupConfigValidation -Console [Spectre.Console.IAnsiConsole]`
      - Calls `Get-ModuleConfiguration`; if the file does not exist or is empty (both handled by `Get-ModuleConfiguration`'s own defaults path) the function returns immediately with no warnings - a freshly-created default config is always valid
      - If the file exists but contains invalid JSON: displays an error panel `"Configuration file contains invalid JSON. Default values will be used. Please reconfigure via Configure Module."` via `$Console.Write()`
      - If the file exists and is valid JSON: calls `Test-ConfigValue` for every key in `$script:ConfigValidationSchema`; collects all failures; if any exist, displays a warning panel listing each failing key and the validation message; user presses Enter to continue
      - Logs any discovered issues via `Write-LastWarLog -Level Warning`
      - Does NOT abort startup; only informs the user
      - Returns `[PSCustomObject]@{HasErrors=[bool]; Messages=[string[]]}`
      - Full comment-based help
   4. [x] 3.4: Update `LastWarAutoScreenshot.psd1`
      - Add `'Start-LastWarAutoScreenshot'` to `FunctionsToExport`
   5. [x] 3.5: Update `LastWarAutoScreenshot.psm1`
      - Add `Export-ModuleMember -Function 'Start-LastWarAutoScreenshot'` alongside the existing exports
   6. [x] 3.6: Create `powershell-module/Tests/ConsoleApp/Show-MainMenu.Tests.ps1`
      - Import module; all tests use `InModuleScope`
      - Setup: `$testConsole = [Spectre.Console.Testing.TestConsole]::new()`; load `Spectre.Console.Testing.dll` via `Add-Type` in `BeforeAll`
      - Mock `Get-ChildItem` returning empty list → "Run macro" option rendered, is not in selectable choices (assert `$testConsole.Output` does not contain a selectable "Run macro" choice); queue `testConsole.Input.PushTextWithEnter('Exit')` to break prompt
      - Mock `Get-ChildItem` returning one mock file `'20260101_120000_TestMacro.json'` → "Run macro" choice is present in output
      - Return value from `Show-MainMenu` matches expected identifier string for each choice
   7. [x] 3.7: Create `powershell-module/Tests/ConsoleApp/Start-LastWarAutoScreenshot.Tests.ps1`
      - Mock `Show-MainMenu` returning `'Exit'` → loop exits cleanly, no exception
      - Mock `Invoke-StartupConfigValidation` returning `@{HasErrors=$false; Messages=@()}` → no error panel rendered; assert `$testConsole.Output` does not contain error markup
      - Mock `Invoke-StartupConfigValidation` returning `@{HasErrors=$true; Messages=@('Logging.MinimumLogLevel: invalid value')}` → error panel content appears in `$testConsole.Output`
      - Mock `Show-MainMenu` returning `'SelectWindow'` once, then `'Exit'` → window selection screen function called exactly once
      - `$Console` defaulting to real console when not provided - verify the parameter default is `[LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()`
   8. [x] 3.8: Create `powershell-module/Tests/ConsoleApp/Invoke-StartupConfigValidation.Tests.ps1`
      - Config file does not exist → `Get-ModuleConfiguration` creates defaults; function returns `HasErrors=$false`; no output written to `$testConsole`
      - Config file exists, all values valid → returns `HasErrors=$false`; no panel written
      - Config file exists, one invalid value → returns `HasErrors=$true`; `$testConsole.Output` contains the key name and validation message
      - Multiple invalid values → all listed in output
      - Invalid JSON in config file → error panel shown; `Write-LastWarLog` called with `Level = 'Warning'`
   9. [x] 3.9: Run full Pester suite; confirm count increases and all tests pass

4. [x] Implement the window selection screen
   1. [x] 4.1: Create `powershell-module/Private/ConsoleApp/Show-WindowSelectionScreen.ps1`
      - `Show-WindowSelectionScreen -Console [Spectre.Console.IAnsiConsole]`
      - **Step 1 - Sort/filter selection:**
        - Display a `SelectionPrompt` "Sort windows by:" with choices: `'Process name'`, `'Window title'`
        - Map choice to a sort expression used in step 2
      - **Step 2 - Enumerate and display windows:**
        - Call `Get-EnumeratedWindows` (with no filters - same behaviour as current `Select-TargetWindowFromMenu` with no parameters)
        - If result is empty: display error `Panel` `"No windows found. Ensure at least one application is open and try again."` using red markup; log via `Write-LastWarLog -Level Error`; return `$null`
        - Sort the results using the sort expression from step 1
        - Build a Spectre.Console `Table` with columns: `#`, `Active`, `Process`, `Application`, `Minimised`; populate with window data; mark the active (foreground) window with `[bold]*[/]` in the Active column
        - Write the table to `$Console`
      - **Step 3 - Window selection:**
        - Build a `SelectionPrompt` from the sorted window list; display format per choice: `"<#>: <ProcessName> - <WindowTitle> (<WindowState>)"`; add `"[Back to main menu]"` as the last choice
        - Show the prompt; if user chooses `"[Back to main menu]"` return `$null`
        - Get selected window object by correlating the numbered choice back to the sorted list
      - **Step 4 - Validate window still exists:**
        - Call `Test-WindowHandleValid` (existing private function); if window is closed display error panel `"The selected window has closed. Please select another."`, log Error, re-display step 2 (loop back - do not return to main menu)
      - **Step 5 - Save and return:**
        - Call `Save-ModuleConfiguration` to persist the selected window
        - Display success panel `"Window '[bold]<WindowTitle>[/]' selected and saved to configuration."`
        - Return the selected window object
      - Full comment-based help; all error paths log via `Write-LastWarLog`
   2. [x] 4.2: Create `powershell-module/Tests/ConsoleApp/Show-WindowSelectionScreen.Tests.ps1`
      - Mock `Get-EnumeratedWindows` returning empty list → error panel shown; `$testConsole.Output` contains "No windows found"; `Write-LastWarLog` called with `Level = 'Error'`; returns `$null`
      - Mock `Get-EnumeratedWindows` returning two mock windows → table and selection prompt rendered; `$testConsole.Output` contains both window titles
      - Queue input selecting `"[Back to main menu]"` → returns `$null`
      - Queue input selecting a valid window → `Save-ModuleConfiguration` called; returns selected window object
      - Mock `Test-WindowHandleValid` returning `$false` - error panel shown; mock `Test-WindowHandleValid` is called again after user re-selects (loop test - use a counter mock that returns `$false` once, then `$true`)
      - Sort selection propagated: mock `Get-EnumeratedWindows`; verify the table rows in `$testConsole.Output` appear in the expected sorted order
      - Run full Pester suite; confirm count increases

5. [x] Implement the configuration screens
   1. [x] 5.1: Create `powershell-module/Private/ConsoleApp/Show-ConfigMenuScreen.ps1`
      - `Show-ConfigMenuScreen -Console [Spectre.Console.IAnsiConsole]`
      - Displays a `SelectionPrompt` "Configuration area:" with choices:
        - `Logging settings`
        - `Mouse control settings`
        - `Emergency stop settings`
        - `Storage & log file info`
        - `[Back to main menu]`
      - Loops until user selects `"[Back to main menu]"`; dispatches each choice to the appropriate config sub-screen (steps 5.2-5.4, 6)
      - Passes `$Console` to all sub-screens
      - Full comment-based help
   2. [x] 5.2: Create `powershell-module/Private/ConsoleApp/Show-LoggingConfigScreen.ps1`
      - `Show-LoggingConfigScreen -Console [Spectre.Console.IAnsiConsole]`
      - Loads current config via `Get-ModuleConfiguration`
      - Displays a `Table` showing current values for all `Logging.*` and `Logging.FileBackend.*` keys, their current values, allowed values / range, and a description sourced from `$script:ConfigValidationSchema`
      - For each key in turn (via a `TextPrompt` loop):
        - Prompt: `"<Description> [<value>] (<constraints>):"`
        - If the user enters an empty string (just presses Enter), keep the existing value
        - If the user types a value, call `Test-ConfigValue`; if invalid, display the error message in red and re-prompt the same key (do not advance to the next key until valid input is given or user accepts the current value)
        - Offer `"[Reset to default]"` as a recognised input string that substitutes the default value from `Get-DefaultModuleSettings`
      - After all keys: display a `SelectionPrompt` `"Save changes?"` with choices `'Yes - save now'`, `'Reset ALL Logging settings to defaults'`, `'Discard changes'`
      - `'Yes - save now'`: call `Save-ModuleConfiguration` with updated config; display success panel; log Info
      - `'Reset ALL Logging settings to defaults'`: replace all Logging keys with defaults from `Get-DefaultModuleSettings`; save; display success panel; log Info
      - `'Discard changes'`: return without saving; display info panel `"No changes saved."`
      - Full comment-based help; all error paths logged
   3. [x] 5.3: Create `powershell-module/Private/ConsoleApp/Show-MouseControlConfigScreen.ps1`
      - `Show-MouseControlConfigScreen -Console [Spectre.Console.IAnsiConsole]`
      - Identical pattern to `Show-LoggingConfigScreen` but for all `MouseControl.*` keys
      - For `bool` keys (`EasingEnabled`, `OvershootEnabled`, `MicroPausesEnabled`, `JitterEnabled`): use `ConfirmationPrompt` (yes/no) instead of `TextPrompt`
      - For `intArray` keys (range pairs): prompt for min and max separately; label as `"<Key> minimum (ms):"` and `"<Key> maximum (ms):"` respectively; after both are entered, validate the pair as a unit via `Test-ConfigValue`
      - Save/reset/discard options identical to `Show-LoggingConfigScreen`
      - Full comment-based help; all error paths logged
   4. [x] 5.4: Create `powershell-module/Private/ConsoleApp/Show-EmergencyStopConfigScreen.ps1`
      - `Show-EmergencyStopConfigScreen -Console [Spectre.Console.IAnsiConsole]`
      - Identical pattern to `Show-LoggingConfigScreen` but for all `EmergencyStop.*` keys
      - For `HotkeyVKeyCodes` (int array of variable length): display as comma-separated hex strings (e.g. `0x11, 0x10, 0xDC`); accept input as comma-separated hex or decimal integers; parse and validate each element is a valid VKey code (0x01-0xFE); display informational note: `"Note: '#' key is 0xDC on UK layouts and layout-dependent on others. See README for details."`
      - Save/reset/discard options identical above
      - Full comment-based help; all error paths logged
   5. [x] 5.5: Create `powershell-module/Tests/ConsoleApp/Show-ConfigMenuScreen.Tests.ps1`
      - Queue `"[Back to main menu]"` → loop exits; no sub-screen called
      - Queue `"Logging settings"` then `"[Back to main menu]"` → `Show-LoggingConfigScreen` called exactly once
      - Repeat for each sub-screen option
      - Run full Pester suite; confirm count increases
   6. [x] 5.6: Create `powershell-module/Tests/ConsoleApp/Show-LoggingConfigScreen.Tests.ps1`
      - Mock `Get-ModuleConfiguration` returning a known config; mock `Save-ModuleConfiguration`
      - Queue empty string for all prompts - all current values retained; `Save-ModuleConfiguration` called with unchanged config when user chooses `'Yes - save now'`
      - Queue an invalid value for `MinimumLogLevel` → error message appears in `$testConsole.Output`; prompt is repeated
      - Queue `'[Reset to default]'` for one key → that key's value in the saved config equals the default from `Get-DefaultModuleSettings`
      - Queue `'Reset ALL Logging settings to defaults'` at save prompt → all Logging keys in saved config equal defaults
      - Queue `'Discard changes'` → `Save-ModuleConfiguration` NOT called
      - Run full Pester suite; confirm count increases
   7. [x] 5.7: Create `powershell-module/Tests/ConsoleApp/Show-MouseControlConfigScreen.Tests.ps1`
      - Same pattern as 5.6 but for `MouseControl.*` keys
      - Bool key: queue `'n'` for an enabled bool key → value saved as `$false`
      - intArray: queue min > max → error message appears; pair is not saved; re-prompt
      - Queue valid min and max in order → saved as `@(min, max)` array
      - Run full Pester suite; confirm count increases
   8. [x] 5.8: Create `powershell-module/Tests/ConsoleApp/Show-EmergencyStopConfigScreen.Tests.ps1`
      - Same pattern as 5.6 but for `EmergencyStop.*` keys
      - `HotkeyVKeyCodes`: queue `'0x11, 0x10, 0xDC'` → saved as `@(17, 16, 220)`
      - Queue `'0xFF, 0x200'` (second value out of range) → error; re-prompt
      - Informational note about `#` key layout appears in `$testConsole.Output`
      - Run full Pester suite; confirm count increases

6. [x] Implement the storage & log file info screen
   1. [x] 6.1: Add a `Screenshots` section to `ModuleConfig.json` and defaults
      - New key: `"Screenshots": { "StoragePath": "", "MaxStorageGB": 2.0 }`
      - `StoragePath` default: `""` (empty string = not yet configured; storage screen shows "Not configured")
      - `MaxStorageGB` default: `2.0`; validation: `double`, `Min = 0.1`, `Max = 2048.0`
      - Add entries to `$script:ConfigValidationSchema` for `'Screenshots.StoragePath'` (string, nullable = true) and `'Screenshots.MaxStorageGB'` (double, Min = 0.1, Max = 2048.0)
      - Update `Get-DefaultModuleSettings` to include `Screenshots` section
      - Update `Get-ModuleConfiguration` to inject missing `Screenshots` keys using the same `Add-Member` pattern as existing sections
      - Update `Save-ModuleConfiguration` to persist `Screenshots` keys
      - Update `ModuleConfiguration.Tests.ps1`: add round-trip tests for `Screenshots.StoragePath` and `Screenshots.MaxStorageGB`; add default-injection test
   2. [x] 6.2: Create `powershell-module/Private/ConsoleApp/Get-StorageInfo.ps1`
      - `Get-StorageInfo`
      - Reads `Screenshots.StoragePath` and `Screenshots.MaxStorageGB` from config
      - If `StoragePath` is empty or path does not exist: returns `[PSCustomObject]@{IsConfigured=$false; UsedGB=0.0; MaxGB=0.0; UsedPercent=0.0; LogFileSizeGB=0.0}`
        - Should handle $null StoragePath defensively as in Get-DefaultModuleSettings.ps1
      - If configured: sums `(Get-ChildItem -Path $StoragePath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum` for screenshot files; converts to GB
      - Also computes log file folder size using `Logging.FileBackend` path (module root by convention)
      - Returns `[PSCustomObject]@{IsConfigured=[bool]; UsedGB=[double]; MaxGB=[double]; UsedPercent=[double]; LogFileSizeGB=[double]}`
      - Error handling: if path exists but access is denied, returns `IsConfigured=$false`; logs Error
      - Pure PowerShell; no `Add-Type`
   3. [x] 6.3: Create `powershell-module/Private/ConsoleApp/Show-StorageInfoScreen.ps1`
      - `Show-StorageInfoScreen -Console [Spectre.Console.IAnsiConsole]`
      - Calls `Get-StorageInfo`
      - If not configured: display info panel `"Screenshot storage path is not yet configured. Set it in the Screenshots section below."`  then prompts for `StoragePath` and `MaxStorageGB` using `TextPrompt` with `Test-ConfigValue` validation (same save/discard pattern as config screens)
      - If configured: display a Spectre.Console `BreakdownChart` (or `BarChart` if `BreakdownChart` is unavailable in the bundled version) showing used vs free storage as a percentage; display current values as a `Table` (Used GB, Max GB, % used, Log files GB); display current config values for `MaxStorageGB` with option to update them
      - If `UsedPercent >= 90`: display warning panel `"Screenshot storage is over 90% full. Consider increasing the limit or clearing old screenshots."` in yellow
      - Save/discard pattern identical to config screens
      - Full comment-based help; all error paths logged
   4. [x] 6.4: Create `powershell-module/Tests/ConsoleApp/Get-StorageInfo.Tests.ps1`
      - Mock `Get-ModuleConfiguration` returning `StoragePath = ''` → returns `IsConfigured=$false`
      - Mock `Get-ModuleConfiguration` returning a valid path that does not exist → returns `IsConfigured=$false`
      - Mock `Get-ChildItem` returning a fixed list of files with known sizes → `UsedGB` calculated correctly; `UsedPercent` calculated correctly against `MaxStorageGB`
      - Access denied path → returns `IsConfigured=$false`; `Write-LastWarLog` called with `Level = 'Error'`
      - Run full Pester suite; confirm count increases
   5. [x] 6.5: Create `powershell-module/Tests/ConsoleApp/Show-StorageInfoScreen.Tests.ps1`
      - Mock `Get-StorageInfo` returning `IsConfigured=$false` → info panel shown; prompts for `StoragePath` and `MaxStorageGB`
      - Mock `Get-StorageInfo` returning `UsedPercent = 95.0` → warning panel content appears in `$testConsole.Output`
      - Mock `Get-StorageInfo` returning `UsedPercent = 50.0` → no warning panel
      - Queue valid values for storage prompts → `Save-ModuleConfiguration` called with correct values
      - Queue invalid `MaxStorageGB` (e.g. `-1`) → error shown; re-prompt
      - Run full Pester suite; confirm count increases

7. [x] Run full Pester suite and validate
   1. [x] 7.1: Run the complete, unfiltered Pester suite (all files, no tag filters)
      - Record total test count; it must meet or exceed the Phase 2 final baseline
      - All tests must pass with 0 failures
      - If any test fails that previously passed, halt and investigate; do not proceed
   2. [x] 7.2: Manually smoke-test `Start-LastWarAutoScreenshot` in a real terminal
      - Import module; call `Start-LastWarAutoScreenshot`
      - Navigate every screen at least once; exercise sort options in window selection; save and reload a config change; observe the storage screen
      - Confirm no ANSI artefacts or rendering glitches
   3. [x] 7.3: Update `LastWarAutoScreenshot/Docs/README.md`
      - Add "Getting Started" section documenting `Start-LastWarAutoScreenshot` as the entry point with a usage example
      - Document the `Private/Macros/` folder naming convention for macros
      - Document the `lib/VERSIONS.txt` file and how to update the bundled DLLs if needed
      - Document all new config keys (`Screenshots.StoragePath`, `Screenshots.MaxStorageGB`) with types, defaults, and examples
      - Document the `IAnsiConsole` injection pattern for contributors writing new screens

8. [x] Use alternate screen buffer for each sub-screen

   ### Background and goal

   Currently all console output accumulates in a single terminal buffer. Each time a sub-screen
   (window selection, configuration, storage info) is displayed, its output appends below the
   main menu, producing cluttered terminal history that never scrolls away. The goal of this task
   is to render every sub-screen in a dedicated alternate screen buffer, exactly as demonstrated
   by the Spectre.Console "Mirror universe" example (`examples/Console/AlternateScreen`), so that:
   - Each sub-screen renders into a clean, empty terminal buffer
   - When the sub-screen exits (for any reason, including unhandled exceptions), the original
     terminal content (the main menu) is automatically restored by the OS/terminal
   - The user experience is equivalent to a proper full-screen TUI application
   - Terminals that do not support alternate buffers (e.g. CI runners, legacy consoles) continue
     to function without error via graceful degradation

   ### Architecture decision

   Alternate screen management is **centralised in `Start-LastWarAutoScreenshot.ps1`**, not
   distributed across each `Show-*Screen.ps1` function. Reasons:
   - Screen functions remain pure; they have no awareness of buffer management
   - `Show-ConfigMenuScreen` dispatches to config sub-screens; centralising avoids double-nesting
     the alternate buffer (entering it again inside an already-entered alternate screen)
   - Simpler to reason about: one place owns the enter/exit lifecycle
   - Existing screen tests call functions directly and are completely unaffected

   The `[System.Action]` delegate pattern with `.GetNewClosure()` is used when passing a
   PowerShell scriptblock to the C# `RunInAlternateScreen` method.  This is consistent with
   the `.GetNewClosure()` pattern already used in `Start-EmergencyStopMonitor.ps1` for timer
   callbacks.

   ---

   1. [x] 8.1: Add `RunInAlternateScreen` static method to `powershell-module/src/ConsoleAppBridge.cs`
      - Add the following method to the existing `ConsoleAppBridge` static class (no new files):

        ```csharp
        /// <summary>
        /// Runs the supplied <paramref name="action"/> inside an alternate terminal screen
        /// buffer when the terminal supports it.  If the terminal does not support alternate
        /// buffers (e.g. CI runners, legacy consoles) the action is invoked directly so that
        /// callers degrade gracefully without any code change.
        /// </summary>
        /// <param name="console">
        /// The <see cref="IAnsiConsole"/> instance to use.  The buffer capability is checked
        /// on this instance so that injected test consoles are respected correctly.
        /// </param>
        /// <param name="action">The screen content to run inside the alternate buffer.</param>
        /// <exception cref="ArgumentNullException">
        /// Thrown when <paramref name="console"/> or <paramref name="action"/> is <c>null</c>.
        /// </exception>
        public static void RunInAlternateScreen(IAnsiConsole console, Action action)
        {
            if (console == null) throw new ArgumentNullException(nameof(console));
            if (action == null) throw new ArgumentNullException(nameof(action));

            if (console.Profile.Capabilities.AlternateBuffer)
            {
                // Spectre.Console IAnsiConsole extension method (Spectre.Console >= 0.42;
                // bundled version is 0.54.0 so this is guaranteed available).
                // It writes ESC[?1049h, clears the screen, runs the action, then writes
                // ESC[?1049l in a finally block, restoring the original buffer even if
                // the action throws.
                console.AlternateScreen(action);
            }
            else
            {
                // Graceful degradation: run the action directly in the current buffer.
                // No ANSI sequences are written; output accumulates as before.
                action();
            }
        }
        ```

      - The `using System;` directive is already present in `ConsoleAppBridge.cs`; no new
        `using` directives are required because `AlternateScreen` is an extension method in
        the `Spectre.Console` namespace which is already imported.
      - Do NOT add `SetLastError`, P/Invoke, or any unmanaged code; this is pure managed .NET.
      - Place the method after the existing `CreatePanel` method, before the closing `}` of the
        class.

   2. [x] 8.2: Update `powershell-module/Public/Start-LastWarAutoScreenshot.ps1` to wrap each sub-screen dispatch in `RunInAlternateScreen`

      - **Do not change** `Invoke-StartupConfigValidation` or `Show-MainMenu`; these must
        remain in the normal terminal buffer so the user always returns to a clean menu.
      - Modify only the `switch` body inside the `while ($true)` loop.
      - For each case, assign the content to a named scriptblock variable, call `.GetNewClosure()`
        on it (to capture `$Console` from the enclosing function scope), cast to `[System.Action]`,
        and pass to `RunInAlternateScreen`.  This is identical to the `.GetNewClosure()` pattern
        already used for timer callbacks in `Start-EmergencyStopMonitor.ps1`.
      - Updated switch body (replace the entire `switch ($choice) { … }` block):

        ```powershell
        switch ($choice) {

            'SelectWindow' {
                $screenBlock = { Show-WindowSelectionScreen -Console $Console }.GetNewClosure()
                [LastWarAutoScreenshot.ConsoleAppBridge]::RunInAlternateScreen(
                    $Console, [System.Action]$screenBlock)
            }

            'Configure' {
                $screenBlock = { Show-ConfigMenuScreen -Console $Console }.GetNewClosure()
                [LastWarAutoScreenshot.ConsoleAppBridge]::RunInAlternateScreen(
                    $Console, [System.Action]$screenBlock)
            }

            'RecordMacro' {
                $screenBlock = {
                    $stubPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                        'Macro recording is not yet available. This feature will be implemented in a future release.',
                        'Record Macro'
                    )
                    $Console.Write($stubPanel)
                }.GetNewClosure()
                [LastWarAutoScreenshot.ConsoleAppBridge]::RunInAlternateScreen(
                    $Console, [System.Action]$screenBlock)
            }

            'RunMacro' {
                # Phase 4 placeholder - macro running requires the recording feature first
            }

            'Exit' {
                return
            }
        }
        ```

      - `RunMacro` is a no-op placeholder and does not need wrapping yet (nothing is rendered).
      - Update the `.NOTES` section of the function's comment-based help to document that
        sub-screen dispatches use alternate screen buffers via `RunInAlternateScreen`, and that
        terminals not supporting alternate buffers fall back to in-place rendering automatically.

   3. [x] 8.3: Review all existing `Tests/ConsoleApp/*.Tests.ps1` files - confirm no changes are needed

      ✓ **Review completed** — All existing tests in `Tests/ConsoleApp/` call `Show-*Screen` functions
      directly (not via `Start-LastWarAutoScreenshot`). They inject `TestConsole` which has
      `AlternateBuffer = $false` by default. Since `RunInAlternateScreen` is only called from
      within `Start-LastWarAutoScreenshot` and not from the screen functions themselves, these
      tests do not call or reference `RunInAlternateScreen` or `AlternateBuffer` at all.

      **Confirmed - No changes required:**
      - ✓ `Tests/ConsoleApp/ConfigValidation.Tests.ps1`
      - `Tests/ConsoleApp/ConsoleAppBridge.Tests.ps1` — updated in step 8.4
      - ✓ `Tests/ConsoleApp/Get-StorageInfo.Tests.ps1`
      - ✓ `Tests/ConsoleApp/Invoke-StartupConfigValidation.Tests.ps1`
      - ✓ `Tests/ConsoleApp/Show-ConfigMenuScreen.Tests.ps1`
      - ✓ `Tests/ConsoleApp/Show-EmergencyStopConfigScreen.Tests.ps1`
      - ✓ `Tests/ConsoleApp/Show-LoggingConfigScreen.Tests.ps1`
      - ✓ `Tests/ConsoleApp/Show-MainMenu.Tests.ps1`
      - ✓ `Tests/ConsoleApp/Show-MouseControlConfigScreen.Tests.ps1`
      - ✓ `Tests/ConsoleApp/Show-StorageInfoScreen.Tests.ps1`
      - ✓ `Tests/ConsoleApp/Show-WindowSelectionScreen.Tests.ps1`
      - `Tests/ConsoleApp/Start-LastWarAutoScreenshot.Tests.ps1` — updated in step 8.5

   4. [x] 8.4: Add `RunInAlternateScreen` tests to `powershell-module/Tests/ConsoleApp/ConsoleAppBridge.Tests.ps1`

      Add a new `Context 'RunInAlternateScreen'` block after the existing `Context 'CreatePanel'`
      block.  Load `Spectre.Console.Testing.dll` is already loaded via the `BeforeAll` at the top
      of the file — no new setup is needed.

      Tests to add:

      - **Action invoked when AlternateBuffer capability is false (graceful degradation)**

        ```
        $tc = [Spectre.Console.Testing.TestConsole]::new()
        # AlternateBuffer defaults to $false on TestConsole - no need to set it explicitly
        $invoked = $false
        $action  = [System.Action]{ $invoked = $true }
        [LastWarAutoScreenshot.ConsoleAppBridge]::RunInAlternateScreen($tc, $action)
        $invoked | Should -BeTrue
        ```

      - **Action invoked when AlternateBuffer capability is true**

        ```
        $tc = [Spectre.Console.Testing.TestConsole]::new()
        $tc.Profile.Capabilities.AlternateBuffer = $true
        $invoked = $false
        $action  = [System.Action]{ $invoked = $true }
        [LastWarAutoScreenshot.ConsoleAppBridge]::RunInAlternateScreen($tc, $action)
        $invoked | Should -BeTrue
        ```

      - **Throws ArgumentNullException when console is null**

        ```
        { [LastWarAutoScreenshot.ConsoleAppBridge]::RunInAlternateScreen($null, [System.Action]{}) }
            | Should -Throw
        ```

      - **Throws ArgumentNullException when action is null**

        ```
        $tc = [Spectre.Console.Testing.TestConsole]::new()
        { [LastWarAutoScreenshot.ConsoleAppBridge]::RunInAlternateScreen($tc, $null) }
            | Should -Throw
        ```

      - **Alternate screen ANSI sequence appears in output when AlternateBuffer is true**
        - Set `$tc.Profile.Capabilities.AlternateBuffer = $true`
        - Queue an empty action; call `RunInAlternateScreen`
        - Assert `$tc.Output` contains the ANSI entry sequence `ESC[?1049h` (as a raw byte
          sequence in the output string): `$tc.Output | Should -Match '\x1b\[\?1049h'`
        - This confirms Spectre.Console's `AlternateScreen` extension method was actually
          invoked (not just the graceful-degradation path)

      Important scoping note: these tests do NOT use `InModuleScope` because
      `[LastWarAutoScreenshot.ConsoleAppBridge]` is a .NET type, not a PowerShell function.
      The `$invoked = $false` / `$invoked = $true` pattern works because the `[System.Action]`
      delegate captures the enclosing PowerShell scope via closure.

   5. [x] 8.5: Update `powershell-module/Tests/ConsoleApp/Start-LastWarAutoScreenshot.Tests.ps1` to cover the `RunInAlternateScreen` dispatch path

      **Existing tests must not be removed or altered** — verify they still pass as-is after
      the `Start-LastWarAutoScreenshot.ps1` changes from step 8.2 (they should, because
      `TestConsole.AlternateBuffer = $false` means `RunInAlternateScreen` calls the action
      directly, so mocked screen functions are still called in exactly the same way).

      Add a new `Context 'Alternate screen dispatch'` block with the following tests:

      - **Screen function is called when AlternateBuffer is false (default)**

        ```
        Mock Invoke-StartupConfigValidation { [PSCustomObject]@{HasErrors=$false;Messages=@()} }
        Mock Show-WindowSelectionScreen { }
        $callCount = 0
        Mock Show-MainMenu -MockWith {
            $callCount++
            if ($callCount -eq 1) { return 'SelectWindow' }
            return 'Exit'
        }
        $tc = [Spectre.Console.Testing.TestConsole]::new()
        # AlternateBuffer is $false by default; action runs directly
        Start-LastWarAutoScreenshot -Console $tc
        Should -Invoke Show-WindowSelectionScreen -Exactly 1
        ```

      - **Screen function is called when AlternateBuffer is true**

        ```
        Mock Invoke-StartupConfigValidation { [PSCustomObject]@{HasErrors=$false;Messages=@()} }
        Mock Show-ConfigMenuScreen { }
        $callCount = 0
        Mock Show-MainMenu -MockWith {
            $callCount++
            if ($callCount -eq 1) { return 'Configure' }
            return 'Exit'
        }
        $tc = [Spectre.Console.Testing.TestConsole]::new()
        $tc.Profile.Capabilities.Interactive = $true
        $tc.Profile.Capabilities.AlternateBuffer = $true
        Start-LastWarAutoScreenshot -Console $tc
        Should -Invoke Show-ConfigMenuScreen -Exactly 1
        ```

      - **RecordMacro stub renders inside alternate screen when AlternateBuffer is true**

        ```
        Mock Invoke-StartupConfigValidation { [PSCustomObject]@{HasErrors=$false;Messages=@()} }
        $callCount = 0
        Mock Show-MainMenu -MockWith {
            $callCount++
            if ($callCount -eq 1) { return 'RecordMacro' }
            return 'Exit'
        }
        $tc = [Spectre.Console.Testing.TestConsole]::new()
        $tc.Profile.Capabilities.Interactive = $true
        $tc.Profile.Capabilities.AlternateBuffer = $true
        Start-LastWarAutoScreenshot -Console $tc
        # Stub panel content must appear in the TestConsole output regardless of buffer mode
        $tc.Output | Should -Match 'Macro recording is not yet available'
        ```

      All three tests use `InModuleScope -ModuleName 'LastWarAutoScreenshot'` consistent with
      the existing tests in this file.

   6. [x] 8.6: Run the full Pester suite and validate

      - Run the complete, unfiltered Pester suite (all files, no tag or name filters)
      - Total test count must meet or exceed the Phase 3 Task 7 baseline plus the new tests
        added in steps 8.4 and 8.5
      - All tests must pass with 0 failures and 0 errors
      - If any previously-passing test now fails, halt immediately; do not proceed until the
        regression is understood and fixed (do not delete or skip failing tests)

   7. [x] 8.7: Manually smoke-test the alternate screen behaviour in a real terminal

      - Import the module: `Import-Module .\LastWarAutoScreenshot\LastWarAutoScreenshot.psd1 -Force`
      - Call `Start-LastWarAutoScreenshot`
      - Navigate to "Select target window" — confirm the terminal clears and shows only the
        window selection screen; no main menu content is visible behind it
      - Press back / select a window and return — confirm the main menu is restored cleanly with
        no artefacts from the window selection screen
      - Repeat for "Configure module" and the macro stub
      - Navigate two levels deep: main menu → Configure → Logging settings; confirm only one
        alternate screen is active (the config menu and its sub-screens share the same buffer;
        there is no double-nesting)
      - Hold `Ctrl+Shift+#` during a screen to trigger emergency stop; confirm the terminal
        restores correctly after the stop message
      - If your terminal does not support alternate buffers, confirm the application still works
        (output accumulates in-place; no crash or error)

   8. [x] 8.8: Update `LastWarAutoScreenshot/Docs/README.md`

      - In the "Console Application" or "Getting Started" section, add a note explaining that
        each sub-screen uses an alternate terminal buffer; users with terminals that do not
        support alternate buffers will see output accumulate in-place (this is expected and not
        a bug)
      - Document that `Start-LastWarAutoScreenshot` is the sole entry point and that buffer
        management is handled automatically — no user action is required

## Phase 4: Mouse Macro Recording

### Architecture decisions (record here for future reference)

- **Macro storage format:** Pure JSON files stored in `Private/Macros/`. Macros are both stored and executed as JSON — the PowerShell module's existing mouse control infrastructure (`Start-AutomationSequence`, `Invoke-MouseMovePath`, `Invoke-MouseClick`, etc.) handles execution directly.
- **File naming convention:** `yyyyMMdd_HHmmss_<name>.json` — datetime prefix is the creation timestamp (UTC); `<name>` is user-supplied, validated to `[a-zA-Z0-9_-]`, max 50 characters. Spaces are auto-converted to hyphens with user confirmation.
- **Macro file location:** `Private/Macros/` within the module root. The folder is created on first macro save if it doesn't exist. `Show-MainMenu` already checks this folder for `*.json` files (Phase 3).
- **Action naming:** All action types support an optional `name` property. Named actions can be referenced by Loop actions. Names must be unique within a macro (enforced across all action types). Unnamed actions execute in sequence but cannot be referenced by loops. They can also be given a name via Manage Macros -> Edit Macro -> Rename macro step
- **Coordinate capture method:** The user moves the mouse to the target position over the game window (which must be visible and windowed — not exclusive fullscreen), then presses Enter in the console app (which retains keyboard focus throughout). On Enter press, the module calls `Invoke-GetCursorPosition` and converts the absolute screen coordinates to window-relative coordinates via `Get-WindowBounds`. After each capture, the user is offered Accept / Redo / Cancel. No hotkey polling or background listeners are required — standard Spectre.Console `TextPrompt` with `AllowEmpty` handles the Enter key press, making the capture flow fully testable with `TestConsole`.
- **Sequence model:** Flat ordered array of actions. Execution walks the array in order. Loop actions look up referenced named actions from the full sequence by name (position-independent — reordering in the edit screen cannot break loop references). Each iteration of a loop executes the referenced actions in the order specified by the loop's `actionNames` array.
- **Loop constraints:** Loops cannot reference other Loop actions (no nesting). This is validated at save time and during recording. Loops can only reference non-Loop named actions.
- **Emergency stop integration:** `$script:EmergencyStopRequested` is checked between every action during macro execution. If triggered, execution halts cleanly and reports which action was interrupted.
- **DragClick:** New `Invoke-MouseDragClick` private function — orchestrates existing `Invoke-MouseMovePath` (Bezier path to start), `Invoke-SendMouseInput` (button down), `Invoke-MouseMovePath` (Bezier path to end), `Invoke-SendMouseInput` (button up). No new Win32 API required — existing `MOUSEEVENTF_LEFTDOWN`, `MOUSEEVENTF_LEFTUP`, and `MOUSEEVENTF_MOVE` constants in `MouseControlAPI.cs` suffice.
- **Screenshot actions:** Region coordinates are recorded in the macro JSON during Phase 4. Actual screenshot capture is deferred to Phase 6. During execution, screenshot actions log a warning (`"Screenshot capture not yet implemented — skipping"`) and continue without error.
- **Main menu additions:** Three macro-related options: "Record macro" (always visible), "Run macro" (visible only when `*.json` files exist in `Private/Macros/` — existing Phase 3 behaviour), "Manage macros" (always visible — shows `"No macros saved yet"` message when no macros exist).
- **Testability:** All screen functions follow the established `$Console` / `IAnsiConsole` injection pattern. All file I/O is mockable. Coordinate capture is mockable via `Invoke-GetCursorPosition` mock. Macro file operations use `TestDrive:\` in Pester tests.

### Phase 4 scope (what is and is not included)

**Included:** JSON macro schema definition and validation, macro file CRUD operations (save, load, list, rename, delete), coordinate capture via Enter key with Accept/Redo/Cancel, recording screen with full action type support (MoveToPoint, MoveToRegion box/circle, LeftClick, DragClick, Screenshot region stub, Delay, Loop), macro execution engine with emergency stop integration and progress display, "Run macro" screen with macro selection and execution, "Manage macros" screen (view details, edit macro with macro rename and step rename/reorder, delete macro), main menu updates, `Invoke-MouseDragClick` implementation, full Pester test coverage using `TestConsole`.

**Explicitly out of scope for Phase 4:** Visual overlays showing shapes on the game window (see Phase 4b), actual screenshot capture (Phase 5), Task Scheduler integration (Phase 6), step deletion within edit macro (future enhancement), YAML import/export.

### Naming and validation rules

- **Macro names:** `[a-zA-Z0-9_-]` only, 1–50 characters. Spaces auto-converted to hyphens with user confirmation. Must be unique among all saved macro files. Validated by `Get-ValidMacroName`.
- **Action names (within a macro):** Same character rules as macro names. Must be unique within the macro (enforced across all action types — cannot have a MoveToPoint and a LeftClick both named `action1`). Validated by `Test-MacroAction`.
- **Filename format:** `yyyyMMdd_HHmmss_<name>.json` — datetime portion is UTC, `<name>` is the validated macro name. On rename, the datetime prefix is preserved; only the name portion changes.
- **Display format:** When presenting macros to the user, show `"<name> (dd/MM/yy HH:mm:ss)"` using the current localisation format, e.g. `"my-saved-sequence (29/01/26 19:29:22)"`.

### JSON macro file schema

```json
{
    "version": "1.0",
    "metadata": {
        "name": "get-vs-scores",
        "createdUtc": "2026-02-24T12:12:12Z",
        "modifiedUtc": "2026-02-24T12:12:12Z",
        "description": ""
    },
    "targetWindow": {
        "processName": "LastWar",
        "windowTitle": "Last War: Survival"
    },
    "sequence": [
        {
            "name": "target-vs-icon",
            "type": "MoveToRegion",
            "region": {
                "type": "Circle",
                "relativeCentreX": 0.452,
                "relativeCentreY": 0.621,
                "relativeRadius": 0.053
            }
        },
        {
            "type": "LeftClick"
        },
        {
            "name": "ranking-icon",
            "type": "MoveToRegion",
            "region": {
                "type": "Box",
                "relativeX": 0.30,
                "relativeY": 0.20,
                "relativeWidth": 0.10,
                "relativeHeight": 0.05
            }
        },
        {
            "type": "LeftClick"
        },
        {
            "name": "vs-score-screenshot-region",
            "type": "Screenshot",
            "region": {
                "topLeft": { "relativeX": 0.10, "relativeY": 0.15 },
                "bottomRight": { "relativeX": 0.90, "relativeY": 0.85 }
            }
        },
        {
            "name": "move-vs-score-bottom",
            "type": "MoveToPoint",
            "position": {
                "relativeX": 0.50,
                "relativeY": 0.90
            }
        },
        {
            "name": "scroll-next-vs-scores",
            "type": "DragClick",
            "start": { "relativeX": 0.50, "relativeY": 0.80 },
            "end": { "relativeX": 0.50, "relativeY": 0.20 }
        },
        {
            "name": "loop-get-vs-screenshots",
            "type": "Loop",
            "iterations": 19,
            "actionNames": [
                "move-vs-score-bottom",
                "scroll-next-vs-scores",
                "vs-score-screenshot-region"
            ]
        },
        {
            "type": "MoveToPoint",
            "position": { "relativeX": 0.05, "relativeY": 0.05 }
        },
        {
            "type": "LeftClick"
        },
        {
            "type": "Delay",
            "seconds": 5
        },
        {
            "type": "LeftClick"
        },
        {
            "type": "Delay",
            "seconds": 5
        },
        {
            "type": "LeftClick"
        }
    ]
}
```

**Action type specifications:**

| Type | Required properties | Optional | Notes |
|------|-------------------|----------|-------|
| `MoveToPoint` | `position.relativeX` (double 0.0–1.0), `position.relativeY` (double 0.0–1.0) | `name` | Moves mouse to exact relative coordinate |
| `MoveToRegion` | `region.type` (`'Box'` or `'Circle'`); if Box: `region.relativeX`, `region.relativeY`, `region.relativeWidth`, `region.relativeHeight` (all double 0.0–1.0); if Circle: `region.relativeCentreX`, `region.relativeCentreY`, `region.relativeRadius` (all double 0.0–1.0) | `name` | Random point within region selected at execution time via `Get-RandomTargetPosition` |
| `LeftClick` | *(none)* | `name` | Clicks at current mouse position (typically follows a Move action) |
| `DragClick` | `start.relativeX`, `start.relativeY`, `end.relativeX`, `end.relativeY` (all double 0.0–1.0) | `name` | Mouse down at start, Bezier path to end, mouse up |
| `Screenshot` | `region.topLeft.relativeX`, `region.topLeft.relativeY`, `region.bottomRight.relativeX`, `region.bottomRight.relativeY` (all double 0.0–1.0) | `name` | Capture deferred to Phase 6; logs warning and skips during execution |
| `Delay` | `seconds` (double, 0.1–3600) | `name` | Pauses execution for the specified duration |
| `Loop` | `iterations` (int, 1–10000), `actionNames` (string array, non-empty) | `name` | Executes referenced named actions in order, repeated N times; cannot reference other Loops |

### Reference: example macro sequences

These example sequences informed the JSON schema design and are used as validation
test cases throughout Phase 4 implementation.

**Sequence 1 — "Get VS Scores"**

1. Move mouse to first target circle (name: target-vs-icon)
2. Left-click
3. Move mouse to target square (name: ranking-icon)
4. Left-click
5. Move mouse to target square (name: your-alliance)
6. Left-click
7. Screenshot region (name: vs-score-screenshot-region)
8. Move mouse to bottom of vs scores (name: move-vs-score-bottom)
9. Click drag up to top of vs scores (name: scroll-next-vs-scores)
10. Screenshot region (reuse named action vs-score-screenshot-region)
11. Loop (name: loop-get-vs-screenshots): move-vs-score-bottom → scroll-next-vs-scores → vs-score-screenshot-region × 19 iterations
12. Move mouse outside VS window (unnamed)
13. Left-click
14. Pause 5 seconds
15. Left-click
16. Pause 5 seconds
17. Left-click

**Sequence 2 — "Get Arms Race Scores"**

1. Move mouse to first target circle (name: target-events-icon)
2. Left-click
3. Move mouse to bottom of arms race scores (name: move-arms-race-score-bottom)
4. Click drag up to top of arms race scores (name: scroll-next-arms-race-scores)
5. Screenshot region (name: arms-race-screenshot-region)
6. Left-click
7. Pause 5 seconds
8. Left-click
9. Pause 5 seconds
10. Left-click

### Tasks

1. [x] Define JSON macro schema and validation functions
   1. [x] 1.1: Create `powershell-module/Private/MacroSchema.ps1`
      - Define `$script:MacroSchemaVersion = '1.0'` (module-scoped constant, not inside a function)
      - Define `$script:MacroActionTypes` as a hashtable of valid action types and their required/optional properties:

        ```powershell
        $script:MacroActionTypes = @{
            'MoveToPoint' = @{
                Required = @('position.relativeX', 'position.relativeY')
                Ranges   = @{ 'position.relativeX' = @(0.0, 1.0); 'position.relativeY' = @(0.0, 1.0) }
            }
            'MoveToRegion' = @{
                Required    = @('region.type')
                SubTypes    = @{
                    'Box'    = @{
                        Required = @('region.relativeX', 'region.relativeY', 'region.relativeWidth', 'region.relativeHeight')
                        Ranges   = @{
                            'region.relativeX'      = @(0.0, 1.0); 'region.relativeY'      = @(0.0, 1.0)
                            'region.relativeWidth'  = @(0.0, 1.0); 'region.relativeHeight'  = @(0.0, 1.0)
                        }
                    }
                    'Circle' = @{
                        Required = @('region.relativeCentreX', 'region.relativeCentreY', 'region.relativeRadius')
                        Ranges   = @{
                            'region.relativeCentreX' = @(0.0, 1.0); 'region.relativeCentreY' = @(0.0, 1.0)
                            'region.relativeRadius'  = @(0.0, 1.0)
                        }
                    }
                }
            }
            'LeftClick'   = @{ Required = @() }
            'DragClick'   = @{
                Required = @('start.relativeX', 'start.relativeY', 'end.relativeX', 'end.relativeY')
                Ranges   = @{
                    'start.relativeX' = @(0.0, 1.0); 'start.relativeY' = @(0.0, 1.0)
                    'end.relativeX'   = @(0.0, 1.0); 'end.relativeY'   = @(0.0, 1.0)
                }
            }
            'Screenshot'  = @{
                Required = @('region.topLeft.relativeX', 'region.topLeft.relativeY',
                             'region.bottomRight.relativeX', 'region.bottomRight.relativeY')
                Ranges   = @{
                    'region.topLeft.relativeX'     = @(0.0, 1.0); 'region.topLeft.relativeY'     = @(0.0, 1.0)
                    'region.bottomRight.relativeX' = @(0.0, 1.0); 'region.bottomRight.relativeY' = @(0.0, 1.0)
                }
            }
            'Delay'       = @{
                Required = @('seconds')
                Ranges   = @{ 'seconds' = @(0.1, 3600) }
            }
            'Loop'        = @{
                Required = @('iterations', 'actionNames')
                Ranges   = @{ 'iterations' = @(1, 10000) }
            }
        }
        ```

      - All dot-notation property paths (e.g. `position.relativeX`) are resolved by a private helper `Get-NestedProperty -Object [PSCustomObject] -Path [string]` that walks the dot-separated segments and returns the value or `$null` if any segment is missing
      - Full comment-based help on all functions in this file
   2. [x] 1.2: Create `Get-ValidMacroName` in `Private/MacroSchema.ps1`
      - `Get-ValidMacroName -Name [string] -ExistingNames [string[]] [-AutoFix]`
      - Validates name against rules: matches regex `^[a-zA-Z0-9_-]+$`, 1–50 characters
      - If `-AutoFix`: trims leading/trailing whitespace, converts spaces to hyphens, strips characters not matching `[a-zA-Z0-9_-]`, truncates to 50 characters
      - If the original name contained spaces and `-AutoFix` was applied, the `WasAutoFixed` flag is set to `$true` so the caller can prompt the user for confirmation
      - Checks uniqueness against `$ExistingNames` (case-insensitive comparison)
      - Returns `[PSCustomObject]@{Valid=[bool]; SanitisedName=[string]; WasAutoFixed=[bool]; Message=[string]}`
      - `Message` is empty string when `Valid = $true`; human-readable error when `Valid = $false`
      - Full comment-based help
   3. [x] 1.3: Create `Test-MacroAction` in `Private/MacroSchema.ps1`
      - `Test-MacroAction -Action [PSCustomObject] -ExistingNames [string[]]`
      - Validates a single action against `$script:MacroActionTypes`:
        - `type` property exists and is a recognised action type
        - All required properties exist and are non-null
        - All numeric properties are within their defined ranges
        - For `MoveToRegion`: `region.type` is `'Box'` or `'Circle'`; the correct sub-type required properties are validated
        - For `Screenshot`: `bottomRight.relativeX > topLeft.relativeX` and `bottomRight.relativeY > topLeft.relativeY`
        - For `Loop`: `actionNames` is a non-empty string array; each name exists in `$ExistingNames`; no name in `actionNames` resolves to a Loop action (loop nesting check requires the caller to pass action type information — use an optional `-ActionTypeLookup [hashtable]` parameter mapping name → type)
        - If action has a `name` property: validates via `Get-ValidMacroName` against `$ExistingNames`
      - Returns `[PSCustomObject]@{Valid=[bool]; Message=[string]}`
      - `Message` is empty string when `Valid = $true`; first validation error found when `Valid = $false`
   4. [x] 1.4: Create `Test-MacroFile` in `Private/MacroSchema.ps1`
      - `Test-MacroFile -MacroData [PSCustomObject]`
      - Validates the complete macro structure:
        - `version` field exists and equals `$script:MacroSchemaVersion`
        - `metadata` object exists with `name` (valid via `Get-ValidMacroName`), `createdUtc` (valid ISO 8601), `modifiedUtc` (valid ISO 8601)
        - `targetWindow` object exists with non-empty `processName` and `windowTitle` strings
        - `sequence` is a non-empty array
        - Builds a running names set and action-type lookup as it iterates through the sequence
        - Each action in sequence passes `Test-MacroAction` with the names set accumulated so far
        - After full iteration: all Loop `actionNames` references resolve to named actions in the sequence
        - No Loop action references another Loop action
      - Returns `[PSCustomObject]@{Valid=[bool]; Messages=[string[]]}`
      - `Messages` is empty array when `Valid = $true`; all validation errors collected when `Valid = $false`
      - Logs each validation error via `Write-LastWarLog -Level Warning`
   5. [x] 1.5: Create `powershell-module/Tests/MacroSchema.Tests.ps1`
      - Import module in `BeforeAll` using the manifest path (standard pattern)
      - **`Get-ValidMacroName` tests:**
        - Valid name `'my-macro-1'` → `Valid=$true`, `SanitisedName='my-macro-1'`
        - Name with spaces `'my macro'` with `-AutoFix` → `SanitisedName='my-macro'`, `WasAutoFixed=$true`, `Valid=$true`
        - Name with invalid characters `'my macro!@#'` with `-AutoFix` → stripped to `'my-macro'`
        - Name exceeding 50 characters → truncated to 50
        - Empty string → `Valid=$false` with non-empty `Message`
        - Duplicate name in `$ExistingNames` → `Valid=$false`
        - Name with only invalid characters `'!!!'` with `-AutoFix` → `Valid=$false` (empty after stripping)
      - **`Test-MacroAction` tests:**
        - Valid `MoveToPoint` action → `Valid=$true`
        - `MoveToPoint` missing `position.relativeX` → `Valid=$false` with message
        - `MoveToPoint` with `relativeX` = 1.5 (out of range) → `Valid=$false`
        - Valid `MoveToRegion` Box → `Valid=$true`
        - Valid `MoveToRegion` Circle → `Valid=$true`
        - `MoveToRegion` with invalid `region.type` → `Valid=$false`
        - Valid `LeftClick` (no required properties) → `Valid=$true`
        - Valid `DragClick` → `Valid=$true`
        - Valid `Screenshot` → `Valid=$true`
        - `Screenshot` with `bottomRight.relativeX < topLeft.relativeX` → `Valid=$false`
        - Valid `Delay` with `seconds = 5` → `Valid=$true`
        - `Delay` with `seconds = 0` (below minimum) → `Valid=$false`
        - `Delay` with `seconds = 4000` (above maximum) → `Valid=$false`
        - Valid `Loop` referencing existing named actions → `Valid=$true`
        - `Loop` referencing non-existent action name → `Valid=$false`
        - `Loop` referencing another Loop action → `Valid=$false`
        - `Loop` with `iterations = 0` → `Valid=$false`
        - `Loop` with empty `actionNames` array → `Valid=$false`
        - Action with duplicate `name` in `$ExistingNames` → `Valid=$false`
        - Unknown action `type` → `Valid=$false`
      - **`Test-MacroFile` tests:**
        - Valid complete macro (based on "Get VS Scores" example) → `Valid=$true`, empty `Messages`
        - Missing `version` → `Valid=$false`
        - Wrong `version` value → `Valid=$false`
        - Missing `metadata.name` → `Valid=$false`
        - Missing `targetWindow.processName` → `Valid=$false`
        - Empty `sequence` array → `Valid=$false`
        - Duplicate action names in sequence → `Valid=$false`
        - Broken loop reference → `Valid=$false`
        - Nested loop (Loop referencing another Loop) → `Valid=$false`
        - Multiple errors collected → `Messages` array contains all errors
      - Run full Pester suite; confirm count increases

2. [x] Implement macro file management functions
   1. [x] 2.1: Create `powershell-module/Private/Save-MacroFile.ps1`
      - `Save-MacroFile -MacroData [PSCustomObject] [-Force]`
      - Validates macro via `Test-MacroFile`; if invalid, logs Error with all validation messages and returns `Success=$false`
      - Creates `Private/Macros/` directory if it doesn't exist (`New-Item -ItemType Directory -Force`)
      - Generates filename from `metadata.createdUtc` and `metadata.name`:
        - Parse `createdUtc` as `[datetime]`; format as `yyyyMMdd_HHmmss`
        - Sanitise name via `Get-ValidMacroName`
        - Result: `<yyyyMMdd_HHmmss>_<name>.json`
      - Full file path: `Join-Path $script:ModuleRootPath 'Private\Macros' $filename`
      - If file already exists and `-Force` not specified: log Warning `"Macro file already exists. Use -Force to overwrite."`, return `Success=$false`
      - Serialise `$MacroData` to JSON via `ConvertTo-Json -Depth 10` and write to file via `Set-Content -Encoding UTF8`
      - Log Info `"Macro '<name>' saved to <filepath>"` via `Write-LastWarLog`
      - Returns `[PSCustomObject]@{Success=[bool]; FilePath=[string]; Message=[string]}`
      - Error handling: `try/catch` around file write; logs Error on failure; returns `Success=$false`
      - Full comment-based help
   2. [x] 2.2: Create `powershell-module/Private/Get-MacroFile.ps1`
      - `Get-MacroFile -FilePath [string]`
      - Validates file exists via `Test-Path`; if not, logs Error and returns `$null`
      - Reads file content via `Get-Content -Raw -Encoding UTF8`
      - Parses JSON via `ConvertFrom-Json`; if JSON is invalid, logs Error and returns `$null`
      - Validates via `Test-MacroFile`; attaches validation result to the return object
      - Returns `[PSCustomObject]@{Valid=[bool]; Data=[PSCustomObject]; Messages=[string[]]}`
      - `Data` is the parsed macro object; `Valid` and `Messages` come from `Test-MacroFile`
      - If the file contained valid JSON but failed schema validation, `Data` is still returned (allows the manage screen to display and potentially fix the macro); `Valid=$false` with `Messages` describing the issues
      - Full comment-based help
   3. [x] 2.3: Create `powershell-module/Private/Get-MacroFileList.ps1`
      - `Get-MacroFileList`
      - Scans `Join-Path $script:ModuleRootPath 'Private\Macros'` for `*.json` files via `Get-ChildItem`
      - If folder does not exist or contains no JSON files: returns empty array `@()`
      - For each file: parses the filename to extract datetime and name portions using regex `'^(\d{8}_\d{6})_(.+)\.json$'`
      - For each file: reads JSON via `Get-MacroFile`; extracts `metadata.name`, `metadata.createdUtc`, sequence length
      - Constructs display date from `createdUtc` in localised format `dd/MM/yy HH:mm:ss`
      - Returns `[PSCustomObject[]]` each with properties: `FileName`, `FilePath`, `Name`, `CreatedUtc`, `DisplayDate`, `ActionCount`, `Valid`
      - Sorted by `CreatedUtc` descending (newest first)
      - Corrupt files (invalid JSON or failed filename parse): logged as Warning via `Write-LastWarLog` and excluded from results
      - Full comment-based help
   4. [x] 2.4: Create `powershell-module/Private/Remove-MacroFile.ps1`
      - `Remove-MacroFile -FilePath [string]`
      - Validates file exists via `Test-Path`; if not, logs Warning and returns `$false`
      - Deletes the file via `Remove-Item -Force`
      - Logs Info `"Macro file deleted: <filepath>"` via `Write-LastWarLog`
      - Returns `$true` on success, `$false` on failure
      - Error handling: `try/catch` around `Remove-Item`; logs Error on access denied or other failure
      - Full comment-based help
   5. [x] 2.5: Create `powershell-module/Private/Rename-MacroFile.ps1`
      - `Rename-MacroFile -FilePath [string] -NewName [string]`
      - Validates file exists; if not, returns `Success=$false`
      - Validates new name via `Get-ValidMacroName` (checking against existing macro names from `Get-MacroFileList`, excluding the current file)
      - If name is invalid, returns `Success=$false` with validation message
      - Reads the existing macro file via `Get-MacroFile`
      - Updates `metadata.name` to the new name
      - Updates `metadata.modifiedUtc` to current UTC time in ISO 8601 format
      - Extracts the original datetime prefix from the existing filename using regex
      - Generates new filename: `<original-datetime-prefix>_<new-name>.json`
      - Writes updated JSON to new file path; deletes old file
      - Logs Info `"Macro renamed from '<old>' to '<new>'"` via `Write-LastWarLog`
      - Returns `[PSCustomObject]@{Success=[bool]; NewFilePath=[string]; Message=[string]}`
      - Error handling: if write succeeds but delete of old file fails, logs Error but returns `Success=$true` (the renamed file exists; user may need to manually clean up the old one)
      - Full comment-based help
   6. [x] 2.6: Create `powershell-module/Tests/MacroFileManagement.Tests.ps1`
      - Import module in `BeforeAll`; all file operations use `TestDrive:\` via mocking `$script:ModuleRootPath`
      - **`Save-MacroFile` tests:**
        - Valid macro → file created on disk at expected path; file content is valid JSON matching input; returns `Success=$true` with `FilePath`
        - Creates `Private/Macros/` directory if it doesn't exist
        - Filename matches `yyyyMMdd_HHmmss_<name>.json` convention
        - File already exists without `-Force` → returns `Success=$false`; file not overwritten
        - File already exists with `-Force` → file overwritten; returns `Success=$true`
        - Invalid macro (fails `Test-MacroFile`) → returns `Success=$false`; no file written; `Write-LastWarLog` called with Level Error
      - **`Get-MacroFile` tests:**
        - Valid JSON file → returns `Valid=$true` with `Data` containing parsed macro
        - Non-existent file → returns `$null`; `Write-LastWarLog` called with Level Error
        - Invalid JSON → returns `$null`; `Write-LastWarLog` called with Level Error
        - Valid JSON but schema-invalid macro → returns `Valid=$false` with `Data` still populated and `Messages` listing errors
      - **`Get-MacroFileList` tests:**
        - Empty/non-existent folder → returns empty array
        - Multiple valid files → returned sorted by `CreatedUtc` descending; each has correct `Name`, `DisplayDate`, `ActionCount`
        - Corrupt file (invalid JSON) → excluded from results; `Write-LastWarLog` called with Level Warning
        - File with non-matching filename pattern → excluded with Warning logged
        - `DisplayDate` format matches `dd/MM/yy HH:mm:ss` localised pattern
      - **`Remove-MacroFile` tests:**
        - Existing file → deleted; returns `$true`; `Write-LastWarLog` called with Level Info
        - Non-existent file → returns `$false`; `Write-LastWarLog` called with Level Warning
      - **`Rename-MacroFile` tests:**
        - Valid rename → new file created with updated name in JSON and filename; old file deleted; `metadata.modifiedUtc` updated; returns `Success=$true`
        - Datetime prefix preserved in new filename
        - Duplicate name (clash with another macro) → returns `Success=$false`; no files changed
        - Invalid characters in new name → returns `Success=$false`
      - Run full Pester suite; confirm count increases

3. [x] Implement coordinate capture helper
   1. [x] 3.1: Add `CreateEmptyTextPrompt` to `powershell-module/src/ConsoleAppBridge.cs`
      - Add the following method to the existing `ConsoleAppBridge` static class (after `RunInAlternateScreen`):

        ```csharp
        /// <summary>
        /// Creates a <see cref="TextPrompt{T}"/> that accepts empty input (the user can
        /// press Enter without typing anything).  Used by the macro recording coordinate
        /// capture flow where the user positions the mouse and presses Enter to confirm.
        /// </summary>
        /// <param name="title">The prompt text displayed to the user.</param>
        /// <returns>A configured <see cref="TextPrompt{T}"/> ready to call <c>.Show(console)</c>.</returns>
        public static TextPrompt<string> CreateEmptyTextPrompt(string title)
        {
            var prompt = new TextPrompt<string>(title);
            prompt.AllowEmpty = true;
            return prompt;
        }
        ```

      - No new `using` directives required; `TextPrompt<string>` is in the `Spectre.Console` namespace already imported
   2. [x] 3.2: Add `CreateEmptyTextPrompt` test to `powershell-module/Tests/ConsoleApp/ConsoleAppBridge.Tests.ps1`
      - Add a new `Context 'CreateEmptyTextPrompt'` block:
        - Returns non-null object with `.AllowEmpty` equal to `$true`
        - Title property matches supplied title string
        - Accepts empty input via `TestConsole`: queue `$tc.Input.PushKey([System.ConsoleKey]::Enter)`; call `$prompt.Show($tc)`; no exception thrown; returned value is empty string
   3. [x] 3.3: Create `powershell-module/Private/Invoke-CaptureMousePosition.ps1`
      - `Invoke-CaptureMousePosition -WindowHandle [object] -Console [Spectre.Console.IAnsiConsole] -PromptMessage [string]`
      - Accepts/Redo/Cancel loop:
        1. Displays `$PromptMessage` via `$Console.MarkupLine()` (the message should instruct the user to position the mouse and press Enter)
        2. Creates an empty text prompt via `[LastWarAutoScreenshot.ConsoleAppBridge]::CreateEmptyTextPrompt('')` and calls `.Show($Console)` — blocks until the user presses Enter
        3. Immediately calls `Invoke-GetCursorPosition` to capture absolute screen coordinates
        4. Calls `Get-WindowBounds -WindowHandle $WindowHandle` to get the window rectangle
        5. Computes relative coordinates:
           - `$relativeX = [math]::Round(($absolute.X - $bounds.Left) / $bounds.Width, 4)`
           - `$relativeY = [math]::Round(($absolute.Y - $bounds.Top) / $bounds.Height, 4)`
        6. Validates relative coordinates are within [0.0, 1.0]; if outside, displays warning markup `"[red]Position is outside the target window. Please position the mouse within the window bounds.[/]"` and loops back to step 1 automatically (no Accept/Redo prompt shown for out-of-bounds captures)
        7. Displays captured position: `"[green]Position captured: ($relativeX, $relativeY) relative to window[/]"`
        8. Shows `SelectionPrompt` with choices: `'Accept'`, `'Redo'`, `'Cancel'`
           - `'Accept'`: returns the captured position
           - `'Redo'`: loops back to step 1
           - `'Cancel'`: returns `$null`
      - Returns `[PSCustomObject]@{RelativeX=[double]; RelativeY=[double]; AbsoluteX=[int]; AbsoluteY=[int]}` or `$null` on cancel
      - Full comment-based help with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.OUTPUTS`
   4. [x] 3.4: Create `powershell-module/Tests/Invoke-CaptureMousePosition.Tests.ps1`
      - Import module in `BeforeAll`; load `Spectre.Console.Testing.dll`
      - **User accepts first capture:**
        - Mock `Invoke-GetCursorPosition` returning `@{X=300; Y=200}`
        - Mock `Get-WindowBounds` returning `@{Left=100; Top=100; Right=500; Bottom=500; Width=400; Height=400}`
        - Queue Enter key + 'Accept' selection on TestConsole
        - Call `Invoke-CaptureMousePosition`; verify returned `RelativeX = 0.5`, `RelativeY = 0.25`
      - **Position outside window triggers automatic redo:**
        - Mock `Invoke-GetCursorPosition` returning `@{X=50; Y=50}` (outside window bounds Left=100)
        - First capture is outside → warning text appears in `$testConsole.Output`
        - Second call returns position inside window → user accepts → correct coordinates returned
        - Verify `Invoke-GetCursorPosition` called at least twice
      - **User selects Redo:**
        - Mock `Invoke-GetCursorPosition` returning two different positions (first call, second call)
        - Queue Enter + 'Redo' + Enter + 'Accept' on TestConsole
        - Returned position matches the second capture, not the first
      - **User selects Cancel:**
        - Queue Enter + 'Cancel' on TestConsole
        - Returns `$null`
      - **Relative coordinate precision:**
        - Verify coordinates are rounded to 4 decimal places
      - Run full Pester suite; confirm count increases

4. [x] Implement DragClick action
   1. [x] 4.1: Create `powershell-module/Private/Invoke-MouseDragClick.ps1`
      - `Invoke-MouseDragClick -StartX [int] -StartY [int] -EndX [int] -EndY [int]`
      - Reads `MouseControl` config section via `Get-ModuleConfiguration` for movement parameters, click delays, and Bezier settings
      - Execution steps:
        1. **Move to start position:** `Invoke-GetCursorPosition` → `Get-BezierPoints` from current position to `($StartX, $StartY)` → `Invoke-MouseMovePath`; if move fails, return `Success=$false`
        2. **Check emergency stop:** if `$script:EmergencyStopRequested`, return `Success=$false` with `Message = 'Emergency stop triggered before drag'`
        3. **Pre-click delay:** `Start-Sleep -Milliseconds` (random within `ClickPreDelayRangeMs` config range)
        4. **Mouse button down:** `Invoke-SendMouseInput -DeltaX 0 -DeltaY 0 -ButtonFlags $MOUSEEVENTF_LEFTDOWN`; if fails, return `Success=$false`
        5. **Hold delay:** `Start-Sleep -Milliseconds` (random within `ClickDownDurationRangeMs`)
        6. **Check emergency stop:** if `$script:EmergencyStopRequested`, release button (step 8) immediately and return `Success=$false`
        7. **Drag to end position:** `Get-BezierPoints` from `($StartX, $StartY)` to `($EndX, $EndY)` → `Invoke-MouseMovePath`; button remains held because only `LEFTDOWN` was sent
        8. **Mouse button up:** `Invoke-SendMouseInput -DeltaX 0 -DeltaY 0 -ButtonFlags $MOUSEEVENTF_LEFTUP`
        9. **Post-click delay:** `Start-Sleep -Milliseconds` (random within `ClickPostDelayRangeMs`)
      - **Critical safety:** Step 8 (button up) is in a `finally` block to ensure the mouse button is always released, even on exceptions or emergency stop. A stuck mouse button would render the system unusable.
      - Returns `[PSCustomObject]@{Success=[bool]; Message=[string]}`
      - Full comment-based help including `.NOTES` documenting the `finally` block safety mechanism
   2. [x] 4.2: Create `powershell-module/Tests/Invoke-MouseDragClick.Tests.ps1`
      - Import module in `BeforeAll`
      - Mock `Invoke-GetCursorPosition`, `Get-BezierPoints`, `Invoke-MouseMovePath`, `Invoke-SendMouseInput`, `Start-Sleep`, `Get-ModuleConfiguration` (returning known config with `MouseControl` section)
      - **Successful drag-click:**
        - Verify `Invoke-MouseMovePath` called twice (once to move to start, once for the drag path)
        - Verify `Invoke-SendMouseInput` called with `$MOUSEEVENTF_LEFTDOWN` before the drag path
        - Verify `Invoke-SendMouseInput` called with `$MOUSEEVENTF_LEFTUP` after the drag path
        - Verify `Start-Sleep` called for pre-delay, hold, and post-delay
        - Returns `Success=$true`
      - **Emergency stop before drag:**
        - Set `$script:EmergencyStopRequested = $true` before call
        - Verify `Invoke-SendMouseInput` for LEFTDOWN is NOT called
        - Returns `Success=$false`
      - **Emergency stop during drag (after button down):**
        - Set `$script:EmergencyStopRequested = $true` inside mock of `Invoke-MouseMovePath` (second call)
        - Verify `Invoke-SendMouseInput` with `MOUSEEVENTF_LEFTUP` IS called (button released in finally block)
        - Returns `Success=$false`
      - **SendInput failure on button down:**
        - Mock `Invoke-SendMouseInput` returning `$false` for LEFTDOWN
        - `Write-LastWarLog` called with Level Error
        - Returns `Success=$false`
      - **Move to start fails:**
        - Mock `Invoke-MouseMovePath` returning `$false` on first call
        - Button down is NOT called; returns `Success=$false`
      - Run full Pester suite; confirm count increases

5. [x] Update main menu and entry point
   1. [x] 5.1: Update `powershell-module/Private/ConsoleApp/Show-MainMenu.ps1`
      - Add `'Manage macros'` as a new menu option, positioned after `'Run macro'` (or after the disabled macro indicator when no macros exist) and before `'Exit'`
      - `'Manage macros'` is always visible regardless of whether macros exist
      - Add mapping in the `switch` block: `'Manage macros' { return 'ManageMacros' }`
      - Update comment-based help: add `'ManageMacros'` to `.OUTPUTS` list
   2. [x] 5.2: Update `powershell-module/Public/Start-LastWarAutoScreenshot.ps1`
      - Replace the `'RecordMacro'` stub block with a dispatch to `Show-RecordMacroScreen`:

        ```powershell
        'RecordMacro' {
            $screenBlock = {
                param([Spectre.Console.IAnsiConsole]$Console)
                Show-RecordMacroScreen -Console $Console
            }
            Invoke-InAlternateScreen -Console $Console -Action $screenBlock
        }
        ```

      - Replace the `'RunMacro'` placeholder comment with a dispatch to `Show-RunMacroScreen`:

        ```powershell
        'RunMacro' {
            $screenBlock = {
                param([Spectre.Console.IAnsiConsole]$Console)
                Show-RunMacroScreen -Console $Console
            }
            Invoke-InAlternateScreen -Console $Console -Action $screenBlock
        }
        ```

      - Add a new `'ManageMacros'` case dispatching to `Show-ManageMacrosScreen`:

        ```powershell
        'ManageMacros' {
            $screenBlock = {
                param([Spectre.Console.IAnsiConsole]$Console)
                Show-ManageMacrosScreen -Console $Console
            }
            Invoke-InAlternateScreen -Console $Console -Action $screenBlock
        }
        ```

      - Update comment-based help: remove "not yet available" notes for RecordMacro; document all dispatch targets including ManageMacros; update `.NOTES` Phase notes
   3. [x] 5.3: Update `powershell-module/Tests/ConsoleApp/Show-MainMenu.Tests.ps1`
      - Add test: `'Manage macros'` option always appears in `$testConsole.Output` regardless of macro folder state (mock `Get-ChildItem` returning empty)
      - Add test: `'Manage macros'` option appears when macros exist (mock `Get-ChildItem` returning files)
      - Add test: selecting `'Manage macros'` returns `'ManageMacros'`
      - Existing tests must continue to pass unchanged
   4. [x] 5.4: Update `powershell-module/Tests/ConsoleApp/Start-LastWarAutoScreenshot.Tests.ps1`
      - Add test: `'ManageMacros'` dispatches to `Show-ManageMacrosScreen` (mock `Show-MainMenu` returning `'ManageMacros'` then `'Exit'`; verify `Should -Invoke Show-ManageMacrosScreen -Exactly 1`)
      - Add test: `'RecordMacro'` dispatches to `Show-RecordMacroScreen` (same pattern)
      - Add test: `'RunMacro'` dispatches to `Show-RunMacroScreen` (same pattern)
      - Update any existing tests that reference the `'Macro recording is not yet available'` stub panel text — the stub is now replaced with a real screen dispatch
      - Existing tests for `'SelectWindow'`, `'Configure'`, `'Exit'` must continue to pass unchanged
   5. [x] 5.5: Run full Pester suite; confirm count increases and all tests pass

6. [x] Implement macro recording screen
   1. [x] 6.1: Create `powershell-module/Private/ConsoleApp/Show-RecordMacroScreen.ps1`
      - `Show-RecordMacroScreen -Console [Spectre.Console.IAnsiConsole]`
      - Full recording workflow:

      **Step 1 — Validate target window:**
      - Load config via `Get-ModuleConfiguration`
      - Check that a target window is configured (config has `ProcessName` and `WindowHandle`); if not, display error panel `"No target window configured. Please select a target window from the main menu first."` via `$Console.Write()` and return `$null`
      - Validate window handle is still valid via `Test-WindowHandleValid`; if not, display error panel `"Target window is no longer open. Please select a new target window."` and return `$null`
      - Store `$windowHandle` for use in coordinate capture calls

      **Step 2 — Prompt for macro name:**
      - Display info panel explaining the recording workflow: `"You will build a macro by adding actions one at a time. Position your mouse over the game window and press Enter to capture coordinates. The console must have keyboard focus while recording."`
      - `TextPrompt`: `"Enter a name for this macro:"`
      - Validate via `Get-ValidMacroName -AutoFix` (checking against existing macro names from `Get-MacroFileList`)
      - If `WasAutoFixed` is `$true` (spaces were converted): display the sanitised name and confirm via `SelectionPrompt` with `'Use "<sanitised-name>"'` / `'Enter a different name'` / `'Cancel'`
      - If `Valid = $false`: display error message in red markup and re-prompt
      - `'Cancel'` at any point: return `$null` (back to main menu)

      **Step 3 — Action recording loop:**
      - Initialise empty sequence array `$sequence = @()` and names set `$existingNames = @()`
      - Main loop: display current sequence summary as a `Table` with columns `#`, `Type`, `Name`, `Details`; for each action show its type, optional name, and a brief summary of key parameters (e.g. `"(0.45, 0.62)"` for a point, `"Box 0.3×0.2 at (0.1, 0.1)"` for a region)
      - Show `SelectionPrompt` "Add action to sequence:" with dynamic choices:
        - Always shown: `'Move mouse to point'`, `'Move mouse to region (box)'`, `'Move mouse to region (circle)'`, `'Left-click'`, `'Drag-click'`, `'Screenshot region'`, `'Add delay'`
        - Shown only when one or more NAMED non-Loop actions exist: `'Create loop'`
        - Shown only when one or more actions exist in the sequence: `'Save macro'`
        - Always shown: `'Discard and exit'`

      **Step 3a — Move mouse to point:**
      - Call `Invoke-CaptureMousePosition -WindowHandle $windowHandle -Console $Console -PromptMessage '[yellow]Move your mouse to the target position, then press [[Enter]]...[/]'`
      - If `$null` returned (user cancelled): return to action menu
      - Prompt for optional name: `TextPrompt` `"Enter a name for this action (or press [[Enter]] to skip):"` via `CreateEmptyTextPrompt`
      - If name provided: validate via `Get-ValidMacroName -AutoFix -ExistingNames $existingNames`; if `WasAutoFixed`, confirm; if invalid, re-prompt; add to `$existingNames`
      - Build action object:

        ```powershell
        $action = [PSCustomObject]@{
            type     = 'MoveToPoint'
            position = [PSCustomObject]@{
                relativeX = $captured.RelativeX
                relativeY = $captured.RelativeY
            }
        }
        if ($actionName) { $action | Add-Member -NotePropertyName 'name' -NotePropertyValue $actionName }
        ```

      - Append to `$sequence`; display confirmation `"[green]MoveToPoint action added to sequence (step $($sequence.Count)).[/]"`
      - Return to action menu

      **Step 3b — Move mouse to region (box):**
      - Call `Invoke-CaptureMousePosition` with prompt: `"[yellow]Move your mouse to the TOP-LEFT corner of the target box, then press [[Enter]]...[/]"`
      - If cancelled: return to action menu
      - Call `Invoke-CaptureMousePosition` with prompt: `"[yellow]Move your mouse to the BOTTOM-RIGHT corner of the target box, then press [[Enter]]...[/]"`
      - If cancelled: return to action menu
      - Compute region:
        - `$relativeX = $topLeft.RelativeX`; `$relativeY = $topLeft.RelativeY`
        - `$relativeWidth = [math]::Round($bottomRight.RelativeX - $topLeft.RelativeX, 4)`
        - `$relativeHeight = [math]::Round($bottomRight.RelativeY - $topLeft.RelativeY, 4)`
      - Validate width and height are positive; if not, display error `"[red]Bottom-right must be below and to the right of top-left. Please try again.[/]"` and redo both captures (loop back to first capture prompt)
      - Display summary: `"Box region: position ($relativeX, $relativeY) size ($relativeWidth × $relativeHeight)"`
      - Prompt for optional name (same pattern as step 3a)
      - Build action object with `type = 'MoveToRegion'`, `region` containing `type = 'Box'` and all four properties
      - Append to `$sequence`; return to action menu

      **Step 3c — Move mouse to region (circle):**
      - Call `Invoke-CaptureMousePosition` with prompt: `"[yellow]Move your mouse to the CENTRE of the target circle, then press [[Enter]]...[/]"`
      - If cancelled: return to action menu
      - Call `Invoke-CaptureMousePosition` with prompt: `"[yellow]Move your mouse to the EDGE of the circle, then press [[Enter]]...[/]"`
      - If cancelled: return to action menu
      - Compute radius: `$radius = [math]::Round([math]::Sqrt([math]::Pow($edge.RelativeX - $centre.RelativeX, 2) + [math]::Pow($edge.RelativeY - $centre.RelativeY, 2)), 4)`
      - Validate radius is greater than 0; if not, display error `"[red]Edge point must be different from centre. Please try again.[/]"` and redo both captures
      - Display summary: `"Circle region: centre ($centre.RelativeX, $centre.RelativeY), radius $radius"`
      - Prompt for optional name
      - Build action object with `type = 'MoveToRegion'`, `region` containing `type = 'Circle'`, `relativeCentreX`, `relativeCentreY`, `relativeRadius`
      - Append to `$sequence`; return to action menu

      **Step 3d — Left-click:**
      - No position capture required (clicks wherever the mouse is at execution time, typically following a Move action)
      - Display info: `"Left-click action will execute at the current mouse position during playback."`
      - Prompt for optional name
      - Build action object with `type = 'LeftClick'`; optional `name`
      - Append to `$sequence`; return to action menu

      **Step 3e — Drag-click:**
      - Call `Invoke-CaptureMousePosition` with prompt: `"[yellow]Move your mouse to the DRAG START position, then press [[Enter]]...[/]"`
      - If cancelled: return to action menu
      - Call `Invoke-CaptureMousePosition` with prompt: `"[yellow]Move your mouse to the DRAG END position (where the button will be released), then press [[Enter]]...[/]"`
      - If cancelled: return to action menu
      - Display summary: `"Drag from ($start.RelativeX, $start.RelativeY) to ($end.RelativeX, $end.RelativeY)"`
      - Prompt for optional name
      - Build action object with `type = 'DragClick'`, `start` and `end` sub-objects each containing `relativeX` and `relativeY`
      - Append to `$sequence`; return to action menu

      **Step 3f — Screenshot region:**
      - Call `Invoke-CaptureMousePosition` with prompt: `"[yellow]Move your mouse to the TOP-LEFT of the screenshot region, then press [[Enter]]...[/]"`
      - If cancelled: return to action menu
      - Call `Invoke-CaptureMousePosition` with prompt: `"[yellow]Move your mouse to the BOTTOM-RIGHT of the screenshot region, then press [[Enter]]...[/]"`
      - If cancelled: return to action menu
      - Validate bottom-right is below and to the right of top-left (same validation as step 3b box)
      - Display summary: `"Screenshot region: ($topLeft.RelativeX, $topLeft.RelativeY) to ($bottomRight.RelativeX, $bottomRight.RelativeY)"`
      - Display note: `"[grey]Note: Screenshot capture will be available in a future release. The region coordinates are recorded for later use.[/]"`
      - Prompt for optional name (recommended — display `"[grey]Naming screenshot actions is recommended so they can be referenced in loops.[/]"`)
      - Build action object with `type = 'Screenshot'`, `region` containing `topLeft` and `bottomRight` sub-objects
      - Append to `$sequence`; return to action menu

      **Step 3g — Add delay:**
      - `TextPrompt`: `"Enter delay in seconds (0.1 - 3600):"`
      - Validate: parse as `[double]`; must be ≥ 0.1 and ≤ 3600
      - If invalid: display error in red markup and re-prompt
      - Prompt for optional name
      - Build action object with `type = 'Delay'`, `seconds` property
      - Append to `$sequence`; return to action menu

      **Step 3h — Create loop:**
      - Collect all NAMED non-Loop actions from `$sequence` into a selectable list
      - Display table of available named actions: `#`, `Name`, `Type`, `Details`
      - Initialise empty loop action list `$loopActionNames = @()`
      - Loop action selection via `SelectionPrompt`:
        - List all named actions + `'Done adding actions'` + `'Cancel loop'`
        - User selects an action → name added to `$loopActionNames`; display current loop contents as `"Loop so far: action1 → action2 → ..."`
        - An action can be added multiple times to the loop (allows patterns like move → click → move → click)
        - Repeat until `'Done adding actions'` or `'Cancel loop'`
      - If `'Cancel loop'` or `$loopActionNames` is empty: return to action menu
      - `TextPrompt`: `"How many times should this loop repeat? (1 - 10000):"`
      - Validate: parse as `[int]`; must be ≥ 1 and ≤ 10000; re-prompt on invalid input
      - Prompt for optional loop name
      - Display summary: `"Loop: action1 → action2 → ... × N iterations"`
      - Build action object with `type = 'Loop'`, `iterations`, `actionNames` array
      - Append to `$sequence`; return to action menu

      **Step 3i — Save macro:**
      - Build complete macro object:

        ```powershell
        $macroData = [PSCustomObject]@{
            version      = $script:MacroSchemaVersion
            metadata     = [PSCustomObject]@{
                name        = $macroName
                createdUtc  = (Get-Date).ToUniversalTime().ToString('o')
                modifiedUtc = (Get-Date).ToUniversalTime().ToString('o')
                description = ''
            }
            targetWindow = [PSCustomObject]@{
                processName = $config.ProcessName
                windowTitle = $config.WindowTitle
            }
            sequence     = $sequence
        }
        ```

      - Validate via `Test-MacroFile`; if invalid, display error panel listing all validation messages; return to action menu (do not lose the recorded sequence — user can fix issues and try saving again)
      - Call `Save-MacroFile -MacroData $macroData`
      - If `Success=$true`: display success panel `"[green]Macro '<name>' saved successfully with <N> actions.[/]"`; log Info; return `$null` (back to main menu)
      - If `Success=$false`: display error panel with the save error message; return to action menu

      **Step 3j — Discard and exit:**
      - If `$sequence.Count -gt 0`: `SelectionPrompt` `"Are you sure you want to discard this macro? All <N> recorded actions will be lost."` with choices `'Yes, discard'`, `'No, continue recording'`
        - `'No, continue recording'`: return to action menu
        - `'Yes, discard'`: return `$null` (back to main menu)
      - If `$sequence.Count -eq 0`: return `$null` immediately (nothing to lose)

      - Full comment-based help with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.OUTPUTS`, `.NOTES` documenting the coordinate capture flow and the requirement for the game window to be visible/windowed

   2. [x] 6.2: Create `powershell-module/Tests/ConsoleApp/Show-RecordMacroScreen.Tests.ps1`
      - Import module in `BeforeAll`; load `Spectre.Console.Testing.dll`
      - All tests use `InModuleScope -ModuleName 'LastWarAutoScreenshot'` inside `It` blocks
      - Common mocks in `BeforeEach`: `Get-ModuleConfiguration` returning config with valid window target, `Test-WindowHandleValid` returning `$true`, `Get-MacroFileList` returning empty array, `Save-MacroFile` returning `Success=$true`
      - **No target window configured:**
        - Mock `Get-ModuleConfiguration` returning config without `ProcessName`
        - `$testConsole.Output` contains `'No target window configured'`
        - Returns `$null`
      - **Target window no longer open:**
        - Mock `Test-WindowHandleValid` returning `$false`
        - `$testConsole.Output` contains `'no longer open'`
        - Returns `$null`
      - **User enters macro name and immediately discards (empty sequence):**
        - Queue name input + 'Discard and exit' selection
        - Returns `$null`; `Save-MacroFile` NOT called
      - **Record a single MoveToPoint and save:**
        - Mock `Invoke-CaptureMousePosition` returning `@{RelativeX=0.5; RelativeY=0.3; AbsoluteX=300; AbsoluteY=200}`
        - Queue: macro name → 'Move mouse to point' → Enter (capture) → action name → 'Save macro'
        - Verify `Save-MacroFile` called once with macro data containing one `MoveToPoint` action
        - Verify the action's `position.relativeX` = 0.5 and `position.relativeY` = 0.3
        - `$testConsole.Output` contains `'saved successfully'`
      - **Record MoveToRegion (box) — validates bottom-right > top-left:**
        - Mock `Invoke-CaptureMousePosition` returning top-left then bottom-right coordinates
        - Queue appropriate inputs
        - Verify the action's `region.type` = `'Box'` and width/height are positive
      - **Record MoveToRegion (circle) — computes radius:**
        - Mock `Invoke-CaptureMousePosition` returning centre then edge coordinates
        - Verify the action's `region.relativeRadius` matches expected calculation
      - **Record LeftClick — no capture required:**
        - Queue: 'Left-click' → optional name → 'Save macro'
        - `Invoke-CaptureMousePosition` NOT called
        - Saved action has `type = 'LeftClick'`
      - **Record DragClick — captures start and end:**
        - Mock `Invoke-CaptureMousePosition` returning start then end coordinates
        - Saved action has `type = 'DragClick'` with correct `start` and `end`
      - **Record Screenshot — includes future-release note:**
        - `$testConsole.Output` contains `'future release'`
        - Saved action has `type = 'Screenshot'`
      - **Record Delay — validates range:**
        - Queue: 'Add delay' → '5' → 'Save macro'
        - Saved action has `type = 'Delay'`, `seconds = 5`
      - **Create Loop — references named actions:**
        - Record two named actions first, then create a loop referencing them
        - Saved loop action has correct `actionNames` and `iterations`
      - **Loop option hidden when no named actions exist:**
        - Queue: 'Left-click' (unnamed) → verify `'Create loop'` does NOT appear in the menu
      - **Loop option shown when named actions exist:**
        - Record a named action → verify `'Create loop'` DOES appear in the menu
      - **Save macro option hidden when sequence is empty:**
        - Verify `'Save macro'` does NOT appear in the initial menu (no actions recorded yet)
      - **Discard with actions — confirmation prompt shown:**
        - Record one action, then select 'Discard and exit'
        - `$testConsole.Output` contains `'Are you sure'`
        - Queue 'Yes, discard' → returns `$null`
      - **Discard with actions — user declines:**
        - Queue 'No, continue recording' → user remains in recording loop
      - **Macro name with spaces — auto-fix confirmation:**
        - Queue name with spaces `'my macro'` → sanitised version shown → user confirms
        - Saved macro name uses hyphens
      - **Save fails — error displayed, user stays in recording loop:**
        - Mock `Save-MacroFile` returning `Success=$false`
        - Error message appears in output; user can try saving again
      - Run full Pester suite; confirm count increases

7. [x] Implement macro execution engine
   1. [x] 7.1: Create `powershell-module/Private/Invoke-MacroAction.ps1`
      - `Invoke-MacroAction -Action [PSCustomObject] -WindowHandle [object] -ActionLookup [hashtable]`
      - `$ActionLookup` is a hashtable of `name → action` built from the full sequence; used by Loop actions to resolve references
      - Checks `$script:EmergencyStopRequested` before executing; if set, returns immediately with `Success=$false`, `Message='Emergency stop active'`, `Skipped=$true`
      - Dispatches based on `$Action.type`:

        | Type | Execution |
        |------|-----------|
        | `MoveToPoint` | `ConvertTo-ScreenCoordinates` → `Invoke-GetCursorPosition` → `Get-BezierPoints` → `Invoke-MouseMovePath` |
        | `MoveToRegion` | `Get-RandomTargetPosition` (Box or Circle) → `ConvertTo-ScreenCoordinates` → Bezier path as above |
        | `LeftClick` | `Invoke-MouseClick` at current position (no X/Y parameters — clicks in place) |
        | `DragClick` | `ConvertTo-ScreenCoordinates` for start and end → `Invoke-MouseDragClick` |
        | `Screenshot` | `Write-LastWarLog -Level Warning 'Screenshot capture not yet implemented — skipping action'`; returns `Success=$true`, `Skipped=$true` |
        | `Delay` | `Start-Sleep -Seconds $Action.seconds` |
        | `Loop` | For `1..$Action.iterations`: for each name in `$Action.actionNames`: resolve from `$ActionLookup` → recursive call to `Invoke-MacroAction` (same `$ActionLookup` passed through); emergency stop checked between each iteration and each action within the loop |

      - Includes a `$Depth` parameter (default 0, max 1) to guard against unexpected recursion — Loop actions increment depth; if depth exceeds 1, logs Error `'Loop nesting detected — aborting'` and returns `Success=$false` (this should never happen due to validation, but provides defence in depth)
      - Returns `[PSCustomObject]@{Success=[bool]; Message=[string]; Skipped=[bool]}`
      - Full comment-based help

   2. [x] 7.2: Create `powershell-module/Private/Invoke-MacroSequence.ps1`
      - `Invoke-MacroSequence -MacroData [PSCustomObject] -WindowHandle [object] -Console [Spectre.Console.IAnsiConsole]`
      - Validates macro via `Test-MacroFile`; if invalid, displays error panel with all messages and returns `Success=$false`
      - Builds `$actionLookup` hashtable from all named actions in the sequence:

        ```powershell
        $actionLookup = @{}
        foreach ($action in $MacroData.sequence) {
            if ($action.name) { $actionLookup[$action.name] = $action }
        }
        ```

      - Reads `EmergencyStop.AutoStart` from config; if `$true`, calls `Start-EmergencyStopMonitor`
      - Displays macro name and total action count
      - Iterates through `$MacroData.sequence` in order:
        - For each action: displays progress markup `"[blue]Executing step $i of $total: $($action.type)$(if ($action.name) {" '$($action.name)'"})[/]"` via `$Console.MarkupLine()`
        - Calls `Invoke-MacroAction -Action $action -WindowHandle $WindowHandle -ActionLookup $actionLookup`
        - If `Success=$false` and not `Skipped`: halts execution; displays error panel `"[red]Macro halted at step $i: $($result.Message)[/]"`; breaks out of loop
        - If `$script:EmergencyStopRequested` after action: halts; displays `"[red]Emergency stop triggered at step $i. Macro execution halted.[/]"`; breaks
        - If `Skipped=$true`: displays `"[grey]Step $i skipped ($($action.type) not yet implemented).[/]"`; continues to next action
      - `finally` block: always calls `Stop-EmergencyStopMonitor`
      - Returns `[PSCustomObject]@{Success=[bool]; CompletedActions=[int]; TotalActions=[int]; Message=[string]}`
      - `CompletedActions` counts successfully executed (non-skipped) actions
      - Full comment-based help

   3. [x] 7.3: Create `powershell-module/Tests/MacroExecution.Tests.ps1`
      - Import module in `BeforeAll`
      - Common mocks: `ConvertTo-ScreenCoordinates`, `Invoke-GetCursorPosition`, `Get-BezierPoints`, `Invoke-MouseMovePath`, `Invoke-MouseClick`, `Invoke-MouseDragClick`, `Start-Sleep`, `Get-ModuleConfiguration`, `Start-EmergencyStopMonitor`, `Stop-EmergencyStopMonitor`, `Write-LastWarLog`, `Test-MacroFile` returning `Valid=$true`
      - **`Invoke-MacroAction` tests:**
        - `MoveToPoint` action → `ConvertTo-ScreenCoordinates` called with correct relative coordinates; `Invoke-MouseMovePath` called; returns `Success=$true`
        - `MoveToRegion` Box action → `Get-RandomTargetPosition` called with Box parameter set; then coordinates converted and path followed
        - `MoveToRegion` Circle action → `Get-RandomTargetPosition` called with Circle parameter set
        - `LeftClick` action → `Invoke-MouseClick` called; returns `Success=$true`
        - `DragClick` action → `Invoke-MouseDragClick` called with correct start/end coordinates
        - `Screenshot` action → `Write-LastWarLog` called with Level Warning; returns `Success=$true`, `Skipped=$true`
        - `Delay` action with `seconds = 5` → `Start-Sleep -Seconds 5` called; returns `Success=$true`
        - `Loop` action with 3 iterations and 2 action names → referenced actions executed 6 times total (3 × 2)
        - Emergency stop set → returns `Success=$false`, `Skipped=$false` immediately; no action function called
        - Unknown action type → returns `Success=$false` with descriptive message
      - **`Invoke-MacroSequence` tests:**
        - Valid macro with 3 actions → all 3 executed in order; returns `CompletedActions=3`, `TotalActions=3`, `Success=$true`
        - `EmergencyStop.AutoStart=$true` in config → `Start-EmergencyStopMonitor` called before execution; `Stop-EmergencyStopMonitor` called in finally
        - Emergency stop triggered mid-sequence → execution halts; `CompletedActions` reflects actions completed before stop; `Success=$false`
        - Action failure mid-sequence → halts at failing action; `CompletedActions` reflects completed count
        - Screenshot action → skipped with message; sequence continues; `CompletedActions` does not count skipped actions
        - Invalid macro → error displayed; returns `Success=$false`, `CompletedActions=0`
        - Progress output appears in `$testConsole.Output` for each step
      - Run full Pester suite; confirm count increases

8. [x] Implement Run Macro screen
   1. [x] 8.1: Create `powershell-module/Private/ConsoleApp/Show-RunMacroScreen.ps1`
      - `Show-RunMacroScreen -Console [Spectre.Console.IAnsiConsole]`

      **Step 1 — List and select macro:**
      - Call `Get-MacroFileList`
      - If empty: display info panel `"No macros saved yet. Record a macro from the main menu to get started."` and return `$null`
      - Build `SelectionPrompt` listing macros in display format: `"<name> (<DisplayDate>)"` plus `'[[Back to main menu]]'`
      - If `'[Back to main menu]'` selected: return `$null`
      - Identify selected macro by matching the display string back to the `Get-MacroFileList` results

      **Step 2 — Load and validate macro:**
      - Call `Get-MacroFile -FilePath $selectedMacro.FilePath`
      - If `$null` returned: display error panel `"Failed to load macro file."` and return to step 1
      - If `Valid=$false`: display error panel listing all validation messages from `Messages` array; return to step 1

      **Step 3 — Display macro summary:**
      - Display metadata as a `Panel`: macro name, created date, action count, target window process/title
      - Display sequence as a `Table` with columns: `#`, `Type`, `Name`, `Details`
        - `Details` column shows a brief human-readable summary per action type:
          - `MoveToPoint`: `"(0.45, 0.62)"`
          - `MoveToRegion` Box: `"Box at (0.3, 0.2) size (0.1 × 0.05)"`
          - `MoveToRegion` Circle: `"Circle at (0.45, 0.62) r=0.05"`
          - `LeftClick`: `"Click at current position"`
          - `DragClick`: `"(0.5, 0.8) → (0.5, 0.2)"`
          - `Screenshot`: `"(0.1, 0.15) → (0.9, 0.85) [deferred]"`
          - `Delay`: `"5 seconds"`
          - `Loop`: `"action1 → action2 × 19"`

      **Step 4 — Validate target window:**
      - Load current config via `Get-ModuleConfiguration`; check window handle valid via `Test-WindowHandleValid`
      - If window handle is not valid: display error panel `"[red]Target window is not open. Please select a target window from the main menu before running a macro.[/]"` and return to step 1
      - If the current config's `ProcessName` differs from the macro's `targetWindow.processName`: display warning panel `"[yellow]This macro was recorded for process '<macro-process>' but the current target window is '<config-process>'. The macro may not work correctly.[/]"` and show `SelectionPrompt` `'Continue anyway'` / `'Cancel'`; if `'Cancel'`, return to step 1

      **Step 5 — Confirm and execute:**
      - `SelectionPrompt`: `"Run this macro?"` with choices `'Yes, run now'`, `'Cancel'`
      - If `'Cancel'`: return to step 1
      - Call `Invoke-MacroSequence -MacroData $macro.Data -WindowHandle $config.WindowHandle -Console $Console`
      - Display results:
        - On success: `"[green]Macro completed successfully. $completedActions of $totalActions actions executed.[/]"`
        - On failure: `"[red]Macro execution failed at step $($completedActions + 1) of $totalActions. $completedActions actions completed before failure.[/]"` with `$result.Message`
        - On emergency stop: `"[yellow]Macro halted by emergency stop. $completedActions of $totalActions actions completed.[/]"`
      - Return `$null` (back to main menu) after displaying results

      - Full comment-based help

   2. [x] 8.2: Create `powershell-module/Tests/ConsoleApp/Show-RunMacroScreen.Tests.ps1`
      - Import module in `BeforeAll`; load `Spectre.Console.Testing.dll`
      - **No macros saved:**
        - Mock `Get-MacroFileList` returning empty array
        - `$testConsole.Output` contains `'No macros saved'`
        - Returns `$null`
      - **User selects Back to main menu:**
        - Mock `Get-MacroFileList` returning one macro
        - Queue '[[Back to main menu]]' selection
        - `Invoke-MacroSequence` NOT called; returns `$null`
      - **Load failure:**
        - Mock `Get-MacroFile` returning `$null`
        - Error panel displayed; user returns to macro list
      - **Validation failure:**
        - Mock `Get-MacroFile` returning `Valid=$false` with messages
        - Error messages appear in `$testConsole.Output`
      - **Macro summary table displayed:**
        - Mock with valid macro containing multiple action types
        - `$testConsole.Output` contains action type names and parameter summaries
      - **Target window not found:**
        - Mock `Test-WindowHandleValid` returning `$false`
        - Error panel with `'not open'` displayed
      - **Process name mismatch — user continues:**
        - Mock config with different `ProcessName` than macro's `targetWindow.processName`
        - Warning displayed; queue 'Continue anyway' → `Invoke-MacroSequence` called
      - **Process name mismatch — user cancels:**
        - Queue 'Cancel' → `Invoke-MacroSequence` NOT called
      - **Successful execution:**
        - Mock `Invoke-MacroSequence` returning `Success=$true`, `CompletedActions=5`, `TotalActions=5`
        - `$testConsole.Output` contains `'completed successfully'`
      - **Failed execution:**
        - Mock `Invoke-MacroSequence` returning `Success=$false`, `CompletedActions=2`, `TotalActions=5`
        - `$testConsole.Output` contains `'failed'`
      - **User cancels at confirmation:**
        - Queue 'Cancel' at run confirmation → `Invoke-MacroSequence` NOT called
      - Run full Pester suite; confirm count increases

9. [x] Implement Manage Macros screen with Edit Macro
   1. [x] 9.1: Create `powershell-module/Private/ConsoleApp/Show-ManageMacrosScreen.ps1`
      - `Show-ManageMacrosScreen -Console [Spectre.Console.IAnsiConsole]`

      **No macros state:**
      - Call `Get-MacroFileList`; if empty: display info panel `"No macros saved yet. Record a macro from the main menu to get started."` and return `$null`

      **Macro list loop:**
      - Show `SelectionPrompt` listing macros in display format `"<name> (<DisplayDate>)"` plus `'[[Back to main menu]]'`
      - If `'[Back to main menu]'` selected: return `$null`
      - For the selected macro, show management `SelectionPrompt` with choices:
        - `'View details'`
        - `'Edit macro'`
        - `'Delete macro'`
        - `'[[Back to macro list]]'`

      **View details:**
      - Load macro via `Get-MacroFile -FilePath $selectedMacro.FilePath`
      - Display metadata `Table`: Name, Created (localised), Modified (localised), Action count, Target window (process + title)
      - Display sequence `Table` with columns: `#`, `Type`, `Name`, `Details` (same format as Run Macro screen step 3)
      - Wait for user to acknowledge: `CreateEmptyTextPrompt` with message `"Press [[Enter]] to return..."` → user presses Enter
      - Return to management options for this macro

      **Edit macro:**
      - Dispatch to `Show-EditMacroScreen -Console $Console -FilePath $selectedMacro.FilePath`
      - After edit screen returns, refresh macro list (in case name changed) and return to macro list

      **Delete macro:**
      - `SelectionPrompt`: `"Are you sure you want to delete macro '<name>'? This cannot be undone."` with choices `'Yes, delete'`, `'No, keep it'`
      - If `'Yes, delete'`: call `Remove-MacroFile -FilePath $selectedMacro.FilePath`; if successful display `"[green]Macro '<name>' deleted.[/]"`; if failed display error panel
      - If `'No, keep it'`: return to management options
      - After deletion: refresh macro list and return to macro list (or to "no macros" state if last macro was deleted)

      - Full comment-based help

   2. [x] 9.2: Create `powershell-module/Private/ConsoleApp/Show-EditMacroScreen.ps1`
      - `Show-EditMacroScreen -Console [Spectre.Console.IAnsiConsole] -FilePath [string]`
      - Load macro via `Get-MacroFile`; if load fails, display error panel and return
      - Track whether changes have been made: `$hasChanges = $false`

      **Edit menu loop:**
      - Display macro name as a `Panel` header
      - Display sequence `Table` with columns: `#`, `Type`, `Name`, `Details`
      - Show `SelectionPrompt` with dynamic choices:
        - Always shown: `'Rename macro'`, `'Edit steps'`
        - Shown only if `$hasChanges`: `'Save changes'`, `'Discard changes'`
        - Shown only if NOT `$hasChanges`: `'[[Back]]'`

      **Rename macro:**
      - `TextPrompt` pre-populated with current name (display current name and prompt for new): `"Current name: <name>. Enter new name (or press [[Enter]] to keep current):"`
      - If empty input (Enter only): keep current name, return to edit menu
      - Validate via `Get-ValidMacroName -AutoFix` (checking against existing macro names from `Get-MacroFileList`, excluding current macro)
      - If `WasAutoFixed`: confirm sanitised name with user
      - If valid: update `$macroData.metadata.name`; set `$hasChanges = $true`
      - If invalid: display error and re-prompt
      - Return to edit menu

      **Edit steps:**
      - Display numbered `SelectionPrompt` listing all steps as `"#<N>: <type> [[<name>]]"` (or `"#<N>: <type>"` if unnamed) plus `'[[Back to edit menu]]'`
      - If `'[Back to edit menu]'` selected: return to edit menu
      - For the selected step, show step detail (type, name, all parameters) and `SelectionPrompt`:
        - `'Rename step'` (shown as `'Add name to step'` if step has no name)
        - `'Move up'` (hidden if step is first in sequence, i.e. index 0)
        - `'Move down'` (hidden if step is last in sequence)
        - `'[[Back to step list]]'`

      **Rename step / Add name to step:**
      - If step has existing name: `TextPrompt` `"Current name: <name>. Enter new name (or press [[Enter]] to keep current):"` via `CreateEmptyTextPrompt`
      - If step has no name: `TextPrompt` `"Enter a name for this step (or press [[Enter]] to skip):"`
      - If empty input: keep current name (or remain unnamed), return to step options
      - Validate via `Get-ValidMacroName -AutoFix -ExistingNames` (all other named actions in the sequence)
      - If valid and step was previously referenced by a Loop action: automatically update the Loop's `actionNames` array to use the new name; display `"[grey]Updated loop '<loop-name>' to reference new step name.[/]"`
      - Set `$hasChanges = $true`
      - Return to step list (re-display with updated name)

      **Move up:**
      - Swap the selected step with the step at index `(current - 1)` in the `$macroData.sequence` array
      - Set `$hasChanges = $true`
      - Return to step list (re-display with updated order; highlight moved step by its new position)

      **Move down:**
      - Swap the selected step with the step at index `(current + 1)` in the `$macroData.sequence` array
      - Set `$hasChanges = $true`
      - Return to step list (re-display with updated order)

      **Save changes:**
      - Update `$macroData.metadata.modifiedUtc` to current UTC time in ISO 8601 format
      - If macro name was changed: call `Rename-MacroFile -FilePath $FilePath -NewName $macroData.metadata.name`; update `$FilePath` to the new file path returned
      - Call `Save-MacroFile -MacroData $macroData -Force` (overwrite existing file)
      - If save successful: display `"[green]Changes saved successfully.[/]"`; return (back to manage macros screen)
      - If save failed: display error panel; remain on edit menu

      **Discard changes:**
      - `SelectionPrompt`: `"Discard all unsaved changes?"` with choices `'Yes, discard'`, `'No, keep editing'`
      - If `'Yes, discard'`: return (back to manage macros screen) without saving
      - If `'No, keep editing'`: return to edit menu

      - Full comment-based help

   3. [x] 9.3: Create `powershell-module/Tests/ConsoleApp/Show-ManageMacrosScreen.Tests.ps1`
      - Import module in `BeforeAll`; load `Spectre.Console.Testing.dll`
      - **No macros saved:**
        - Mock `Get-MacroFileList` returning empty array
        - `$testConsole.Output` contains `'No macros saved'`
        - Returns `$null`
      - **User selects Back to main menu:**
        - Mock `Get-MacroFileList` returning one macro
        - Queue `'[[Back to main menu]]'`
        - Returns `$null`
      - **View details:**
        - Mock `Get-MacroFile` returning valid macro with known actions
        - Queue: select macro → 'View details' → Enter (acknowledge) → '[[Back to macro list]]' → '[[Back to main menu]]'
        - `$testConsole.Output` contains macro name, action types, and parameter summaries
      - **Delete macro — confirmed:**
        - Mock `Remove-MacroFile` returning `$true`
        - Queue: select macro → 'Delete macro' → 'Yes, delete' → '[[Back to main menu]]'
        - `Should -Invoke Remove-MacroFile -Exactly 1`
        - `$testConsole.Output` contains `'deleted'`
      - **Delete macro — declined:**
        - Queue: select macro → 'Delete macro' → 'No, keep it' → '[[Back to macro list]]' → '[[Back to main menu]]'
        - `Should -Invoke Remove-MacroFile -Exactly 0`
      - **Edit macro dispatches to Show-EditMacroScreen:**
        - Mock `Show-EditMacroScreen`
        - Queue: select macro → 'Edit macro' → (edit screen returns) → '[[Back to main menu]]'
        - `Should -Invoke Show-EditMacroScreen -Exactly 1` with correct `-FilePath`
      - Run full Pester suite; confirm count increases

   4. [x] 9.4: Create `powershell-module/Tests/ConsoleApp/Show-EditMacroScreen.Tests.ps1`
      - Import module in `BeforeAll`; load `Spectre.Console.Testing.dll`
      - Common mock: `Get-MacroFile` returning valid macro with 3 actions (MoveToPoint named `'action-a'`, LeftClick unnamed, Loop named `'my-loop'` referencing `'action-a'`)
      - **Rename macro:**
        - Queue: 'Rename macro' → 'new-name' → 'Save changes'
        - Mock `Rename-MacroFile` returning `Success=$true`; mock `Save-MacroFile` returning `Success=$true`
        - Verify `Rename-MacroFile` called with `-NewName 'new-name'`
      - **Rename macro — keep current (empty input):**
        - Queue: 'Rename macro' → Enter (empty) → '[[Back]]'
        - `Rename-MacroFile` NOT called; `$hasChanges` remains `$false`
      - **Rename step — updates loop reference:**
        - Queue: 'Edit steps' → select `'action-a'` → 'Rename step' → 'action-b' → '[[Back to step list]]' → '[[Back to edit menu]]' → 'Save changes'
        - Verify the Loop action's `actionNames` array now contains `'action-b'` instead of `'action-a'`
      - **Add name to unnamed step:**
        - Queue: 'Edit steps' → select LeftClick step → 'Add name to step' → 'my-click' → back → back → 'Save changes'
        - Saved macro contains the LeftClick action with `name = 'my-click'`
      - **Move step up:**
        - Queue: 'Edit steps' → select second step → 'Move up' → '[[Back to step list]]' → '[[Back to edit menu]]' → 'Save changes'
        - Verify sequence order changed: originally-second step is now first
      - **Move step down:**
        - Queue: 'Edit steps' → select first step → 'Move down' → back → back → 'Save changes'
        - Verify sequence order changed: originally-first step is now second
      - **Move up hidden for first step:**
        - Queue: 'Edit steps' → select first step → verify `'Move up'` does NOT appear in options
      - **Move down hidden for last step:**
        - Queue: 'Edit steps' → select last step → verify `'Move down'` does NOT appear in options
      - **Save changes — success:**
        - Mock `Save-MacroFile` returning `Success=$true`
        - `$testConsole.Output` contains `'saved successfully'`
      - **Save changes — failure:**
        - Mock `Save-MacroFile` returning `Success=$false`
        - Error displayed; user remains on edit menu
      - **Discard changes — confirmed:**
        - Make a change, then queue 'Discard changes' → 'Yes, discard'
        - `Save-MacroFile` NOT called; screen returns
      - **Discard changes — declined:**
        - Queue 'Discard changes' → 'No, keep editing'
        - User remains on edit menu
      - **Back only shown when no changes:**
        - No changes made → `'[[Back]]'` appears; `'Save changes'` and `'Discard changes'` do NOT appear
      - **Save/Discard only shown when changes exist:**
        - After making a change → `'Save changes'` and `'Discard changes'` appear; `'[[Back]]'` does NOT appear
      - Run full Pester suite; confirm count increases

10. [x] Run full Pester suite and validate
    1. [x] 10.1: Run the complete, unfiltered Pester suite (all files, no tag or name filters)
       - Record total test count; it must meet or exceed the Phase 3 final baseline plus all new tests added in tasks 1–9
       - All tests must pass with 0 failures and 0 errors
       - If any test fails that previously passed, halt and investigate; do not proceed
    2. [x] 10.2: Manually smoke-test all macro workflows in a real terminal
       - Import module; call `Start-LastWarAutoScreenshot`
       - **Record macro:** Navigate to "Record macro"; enter a macro name; record at least one of each action type (MoveToPoint, MoveToRegion box, MoveToRegion circle, LeftClick, DragClick, Screenshot, Delay); create a Loop; save the macro. Verify the JSON file appears in `Private/Macros/` with correct content.
       - **Run macro:** Navigate to "Run macro"; select the recorded macro; verify the summary table displays all actions correctly; run the macro targeting a visible window (e.g. Notepad); observe mouse movements and clicks executing in order; verify the emergency stop (Ctrl+Shift+#) halts execution mid-macro.
       - **Manage macros:** Navigate to "Manage macros"; view macro details; edit macro (rename macro, rename a step, reorder steps, save changes); verify the JSON file is updated on disk; delete a macro; verify the file is removed.
       - **Edge cases:** Attempt to run a macro with the target window closed — verify error message. Record a macro with a name containing spaces — verify auto-fix to hyphens. Create a loop referencing multiple named actions — verify execution repeats correctly.
       - Confirm no ANSI artefacts or rendering glitches in any screen

11. [x] Documentation updates
    1. [x] 11.1: Update `LastWarAutoScreenshot/Docs/README.md`
       - Add "Macro Recording" section documenting:
         - How to record a macro (step-by-step user guide)
         - The coordinate capture workflow (position mouse, press Enter)
         - Requirement for the game window to be visible/windowed (not exclusive fullscreen)
         - All action types with descriptions and when to use each
         - How to create loops for repetitive actions
         - Macro naming rules (`[a-zA-Z0-9_-]`, max 50 characters)
       - Add "Running Macros" section documenting:
         - How to select and run a saved macro
         - Emergency stop integration (Ctrl+Shift+# or mouse gesture)
         - Target window validation and process mismatch warnings
         - Screenshot actions being deferred (logged as warning, skipped during execution)
       - Add "Managing Macros" section documenting:
         - View details, edit (rename macro, rename/reorder steps), delete
         - File location (`Private/Macros/`) and naming convention
         - JSON format overview with a brief example
       - Document `Invoke-MouseDragClick` function with usage example
    2. [x] 11.2: Create or update `LastWarAutoScreenshot/Docs/MacroFormat.md`
       - Full JSON schema documentation with annotated example
       - Action type reference table with all required/optional properties
       - Validation rules and error messages
       - Example macro files for both reference sequences ("Get VS Scores" and "Get Arms Race Scores")

12. [x] Bug fixes
    1. [x] 12.1: User prompt incorrect when recording a macro action
       - When recording coords for `Move mouse to point` and other actions in Record Macro it correctly prompts the user , upon hitting enter to record screen coords the next prompt displays as `Move your mouse to the target position, then press [Enter]...`. After pressing Enter the display output incorrectly shows `What would you like to do?, 0.2765) relative to windowWhat would you like to do?`. It should show the x,y coords in green on one line and the prompt `What would you like to do?` on the next line, followed by the choices (which display correctly already)
    2. [x] 12.2: Enable wrap around in all spectre.console screens showing selection prompts
       - Wrap around is currently disabled on all selection prompts. Enable it in ConsoleAppBridge.cs
    3. [x] 12.3: Ensure ConsoleAppBridge.cs helper classes are being used everywhere instead of directly instantiating new objects from Spectre.Console
       -In some places we are directly instantiating new objects such as Show-MainMenu.ps1: `$prompt = [Spectre.Console.SelectionPrompt[string]]::new()` when we have a helper class for this already
       - Check for any other places we are doing this and ensure it is deliberate. In those cases, explain why the decision was made to directly instantiate a Spectre.Console object and not use a helper class

## Phase 5: Screenshot Management

### Architecture decisions (future reference)

- **Capture library:** New `powershell-module/src/ScreenCaptureAPI.cs` compiled in the same `Add-Type` call as `MouseControlAPI.cs` and `WindowEnumerationAPI.cs` (not separately like `ConsoleAppBridge.cs`). It shares the `LastWarAutoScreenshot` namespace and references `MouseControlAPI.RECT` and calls `MouseControlAPI.GetWindowRect` directly without redeclaration. It references `System.Drawing.Common` (Windows-only, guaranteed available on PowerShell 7.x on Windows). `System.Drawing.Common` is loaded via `Add-Type -AssemblyName 'System.Drawing.Common'` before compilation; the assembly location is obtained from `[System.Drawing.Bitmap].Assembly.Location` and passed to `-ReferencedAssemblies`.
- **Capture method:** `PrintWindow(PW_RENDERFULLCONTENT 0x2)` only. This flag instructs DWM (Desktop Window Manager) to composite and return the full hardware-accelerated window content — including OpenGL and DirectX surfaces — into the provided HDC. Since the target game window is always active (not obscured) at capture time — all mouse clicks and drags execute before any Screenshot action in the sequence — there is no need for a `BitBlt` fallback. `BitBlt` cannot reliably capture OpenGL content and would return a black bitmap. Both methods require the window to be non-minimised; this constraint is documented in `.NOTES` on `Invoke-CaptureScreenRegion` and in `README.md`. Exclusive-fullscreen DirectX/Vulkan windows (not windowed mode) are out of scope.
- **File format:** PNG only (lossless, no compression artefacts that could cause false positives in similarity detection). The `FileFormat` config key is retained as a `string` field defaulting to `'PNG'` for future extensibility but only `'PNG'` is supported in Phase 5. No JPEG code exists anywhere in Phase 5.
- **Bitmap saving:** `System.Drawing.Bitmap.Save()` with `System.Drawing.Imaging.ImageFormat.Png`. All GDI object handles (DC, compatible DC, HBITMAP) are disposed in `finally` blocks inside the C# method — callers never hold raw GDI handles.

- **Filename pattern:** Configurable via `Screenshots.FilenamePattern`. Supported placeholders: `{MacroName}`, `{ActionName}` (falls back to the action's `type` property if the action has no `name`), `{Timestamp}` (UTC `yyyyMMdd_HHmmss`), `{Date}` (UTC `yyyyMMdd`), `{Time}` (UTC `HHmmss`), `{Index}` (zero-padded 4-digit integer per execution run, starting at `0001`). Default: `{MacroName}_{ActionName}_{Timestamp}_{Index}`. After placeholder substitution the resolved filename (before adding the storage path prefix) must be **≤ 200 characters** to stay within Windows' 260-character `MAX_PATH` limit and leave room for the path prefix.

- **Screenshot context:** A `$screenshotContext` hashtable `@{ Index=[int]; MacroName=[string]; ActionName=[string]; PreviousScreenshotPath=[string or $null]; ConsecutiveSimilarCount=[int] }` is initialised in `Invoke-MacroSequence` and passed to every `Invoke-MacroAction` call. Because PowerShell hashtables are reference types, mutations (incrementing `Index`, updating `PreviousScreenshotPath`, setting `ActionName`, incrementing/resetting `ConsecutiveSimilarCount`) propagate without `[ref]` parameters. Loop iterations share the same hashtable so screenshot index and previous-path tracking are continuous across loop repetitions. `ConsecutiveSimilarCount` counts how many successive Screenshot actions in a row have triggered the similarity threshold; it is incremented when similar and reset to `0` when not similar. The stop action only fires when `ConsecutiveSimilarCount` reaches `Screenshots.SimilarityCheck.ConsecutiveThreshold` (default `1`, meaning trigger on the first match — backward compatible).

- **Similarity detection algorithm:** `N` sample pixel coordinates are computed deterministically using evenly-distributed grid traversal (`x = (int)((double)i / sampleCount * bmp.Width) % bmp.Width`, `y = (int)((double)i / sampleCount * bmp.Height)`) — no randomness — so results are reproducible across test runs without seeding. Per-pixel comparison is against R, G, B channels; alpha is ignored. A pixel matches when all three channels differ by ≤ `TolerancePerChannel`. `MatchRatio = matchingPixels / sampleCount`. Implemented as a static C# method to avoid per-pixel PowerShell loop overhead. `FullScan = $true` computes `sampleCount = width * height` and iterates every pixel.

- **Similarity stop action options** (controlled by `Screenshots.SimilarityCheck.Action`):
  - `StopLoop` (default): when the Screenshot action is executing **inside a Loop action**, exits the loop cleanly and the parent macro sequence **continues with the next step** after the loop. When not inside any loop (top-level Screenshot), behaves identically to `StopMacro`. Reported as success.
  - `StopMacro`: halts the entire macro sequence regardless of nesting. Reported as **success** — similarity detection stopping the macro is the intended outcome (scroll end detected), not an error.
  - `Warn`: logs a `Warning` and continues execution; `SimilarityStop` is never set to `$true`.
  - **Implementation contract:** `SimilarityStop=$true` is returned from the Screenshot case in `Invoke-MacroAction` for both `StopLoop` and `StopMacro`. The `Loop` dispatch in `Invoke-MacroAction` inspects `Action` when it receives `SimilarityStop=$true` from a sub-action: for `StopLoop` it breaks the iteration loop and returns `SimilarityStop=$false` (parent continues); for `StopMacro` it propagates `SimilarityStop=$true` upward. `Invoke-MacroSequence` always treats a `SimilarityStop=$true` result from any top-level action as "stop macro, report success".

- **Storage guard:** Before each screenshot capture, `Get-StorageInfo` is called. If `UsedPercent >= 100.0` of `MaxStorageGB`, the screenshot is skipped with a logged `Error` and `Success=$false` returned (execution halts). If actual disk free space (`[System.IO.DriveInfo]`) is ≤ 0 bytes, execution halts entirely with an error panel. `StorageWarningThresholdPercent` (default 90) controls the warning-only band: `>= threshold and < 100%` logs `Warning` but capture continues.

- **Storage path auto-creation:** If `StoragePath` is configured but the directory does not exist, it is created automatically at first capture via `New-Item -ItemType Directory -Force` with an `Info` log. If `StoragePath` is empty/unconfigured, screenshot actions are skipped with a `Warning` and `Skipped=$true` returned (not an error — consistent with Phase 4 deferred behaviour).

#=# Phase 5 scope (what is and is not included)

**Included:** `ScreenCaptureAPI.cs` (Win32 `PrintWindow(PW_RENDERFULLCONTENT)` + `System.Drawing` PNG save; C# similarity comparison via deterministic grid sampling), `Invoke-CaptureWindowRegion.ps1` (thin wrapper over `[LastWarAutoScreenshot.ScreenCaptureAPI]::CaptureWindowRegion` — required for Pester mockability), `Invoke-CompareImages.ps1` (thin wrapper over `[LastWarAutoScreenshot.ScreenCaptureAPI]::CompareImages` — required for Pester mockability), `Resolve-ScreenshotFilename.ps1` (with 200-character resolved-length validation), `Invoke-CaptureScreenRegion.ps1`, `Test-ScreenshotSimilarity.ps1`, `Invoke-MacroAction.ps1` updated (Screenshot action now captures; N-consecutive similarity threshold; Loop dispatch handles `SimilarityStop` for `StopLoop`), `Invoke-MacroSequence.ps1` updated (context initialisation, `SimilarityStop` success messaging), `Show-ScreenshotConfigScreen.ps1`, `Show-ConfigMenuScreen.ps1` updated, `Get-StorageInfo.ps1` enhanced (disk free space, screenshot count, date range), `Show-StorageInfoScreen.ps1` enhanced (Explorer shortcut, disk free warning, screenshot count display), `Show-RunMacroScreen.ps1` pre-flight screenshot check, full Pester test coverage, documentation.

**Explicitly out of scope for Phase 5:** JPEG and other file formats, Azure upload (Phase 9), OCR processing, visual overlay showing capture regions on screen, exclusive-fullscreen DirectX/Vulkan window capture.

---

1. [x] Extend screenshot configuration keys and validation schema
   1. [x] 1.1: Extend the existing `Screenshots` section in `powershell-module/Private/ModuleConfig.json` (the `StoragePath` and `MaxStorageGB` keys added in Phase 3 Task 6.1 are preserved unchanged):

      ```json
      "Screenshots": {
          "StoragePath": "",
          "MaxStorageGB": 2.0,
          "StorageWarningThresholdPercent": 90,
          "FileFormat": "PNG",
          "FilenamePattern": "{MacroName}_{ActionName}_{Timestamp}_{Index}",
          "SimilarityCheck": {
              "Enabled": false,
              "Threshold": 0.98,
              "SampleCount": 1000,
              "FullScan": false,
              "TolerancePerChannel": 10,
              "Action": "StopLoop",
              "ConsecutiveThreshold": 1
          }
      }
      ```

      - `FileFormat` accepts only `'PNG'` in Phase 5; the key is retained as a string for future extensibility
      - `Threshold` is a decimal in the range 0.0–1.0; `0.98` means 98% of sampled pixels must match
      - `Action` valid values: `'StopLoop'`, `'StopMacro'`, `'Warn'`
   2. [x] 1.2: Add all new keys to `$script:ConfigValidationSchema` in `powershell-module/Private/Get-DefaultModuleSettings.ps1` alongside the existing `Screenshots.StoragePath` and `Screenshots.MaxStorageGB` entries:
      - `'Screenshots.StorageWarningThresholdPercent'` — `int`; `Min = 1`; `Max = 99`; `Description = 'Warn when screenshot storage usage exceeds this percentage of the configured MaxStorageGB limit'`
      - `'Screenshots.FileFormat'` — `stringEnum`; `AllowedValues = @('PNG')`; `Description = 'Screenshot file format. Only PNG is supported in this release'`
      - `'Screenshots.FilenamePattern'` — `string`; `Nullable = $false`; `Description = 'Filename pattern. Placeholders: {MacroName}, {ActionName}, {Timestamp}, {Date}, {Time}, {Index}. Resolved filename must not exceed 200 characters'`
      - `'Screenshots.SimilarityCheck.Enabled'` — `bool`; `Description = 'Enable similarity detection to automatically stop macro execution when consecutive screenshots match (scroll-end detection)'`
      - `'Screenshots.SimilarityCheck.Threshold'` — `double`; `Min = 0.01`; `Max = 1.0`; `Description = 'Similarity ratio required to trigger the configured Action (0.0 to 1.0, where 1.0 = 100% identical). Recommended: 0.98'`
      - `'Screenshots.SimilarityCheck.SampleCount'` — `int`; `Min = 100`; `Max = 100000`; `Description = 'Number of pixels sampled for comparison. Ignored when FullScan is true'`
      - `'Screenshots.SimilarityCheck.FullScan'` — `bool`; `Description = 'Compare every pixel instead of a sample. More accurate but slower for large screenshots'`
      - `'Screenshots.SimilarityCheck.TolerancePerChannel'` — `int`; `Min = 0`; `Max = 255`; `Description = 'Maximum per-channel (R/G/B) difference that still counts as a matching pixel. 0 = exact match required'`
      - `'Screenshots.SimilarityCheck.Action'` — `stringEnum`; `AllowedValues = @('StopLoop', 'StopMacro', 'Warn')`; `Description = 'Action when threshold is reached. StopLoop exits the current loop and continues the parent sequence. StopMacro halts the entire macro. Warn logs and continues'`
      - `'Screenshots.SimilarityCheck.ConsecutiveThreshold'` — `int`; `Min = 1`; `Max = 100`; `Description = 'Number of consecutive screenshots that must each exceed the similarity threshold before the configured Action fires. 1 = trigger on first match (default). Use a higher value to avoid false positives on briefly static content'`
   3. [x] 1.3: Update the `Get-DefaultModuleSettings` function body in `powershell-module/Private/Get-DefaultModuleSettings.ps1` — extend the existing `Screenshots` defaults hashtable to include all new keys with the values from step 1.1. Preserve existing `StoragePath` and `MaxStorageGB` defaults unchanged. The `SimilarityCheck` value is a nested hashtable:

      ```powershell
      Screenshots = @{
          StoragePath                    = ''
          MaxStorageGB                   = 2.0
          StorageWarningThresholdPercent = 90
          FileFormat                     = 'PNG'
          FilenamePattern                = '{MacroName}_{ActionName}_{Timestamp}_{Index}'
          SimilarityCheck                = @{
              Enabled              = $false
              Threshold            = 0.98
              SampleCount          = 1000
              FullScan             = $false
              TolerancePerChannel  = 10
              Action               = 'StopLoop'
              ConsecutiveThreshold = 1
          }
      }
      ```

   4. [x] 1.4: Update `powershell-module/Private/Get-ModuleConfiguration.ps1` — use the same `if (-not $config.Screenshots.PSObject.Properties['SimilarityCheck'])` pattern already established for other sections to inject the missing `SimilarityCheck` sub-object when loading older config files that predate Phase 5. Additionally inject each individual `SimilarityCheck` sub-key (`Enabled`, `Threshold`, `SampleCount`, `FullScan`, `TolerancePerChannel`, `Action`, `ConsecutiveThreshold`) if the sub-object exists but any key is absent. Inject `StorageWarningThresholdPercent`, `FileFormat`, and `FilenamePattern` at the `Screenshots` level if missing. No breaking changes to existing keys.
   5. [x] 1.5: Update `powershell-module/Private/Save-ModuleConfiguration.ps1` — ensure all new `Screenshots.*` and `Screenshots.SimilarityCheck.*` keys are persisted. No other changes.
   6. [x] 1.6: Update `powershell-module/Tests/ModuleConfiguration.Tests.ps1`:
      - Add round-trip save/load tests for each new key at both levels: `StorageWarningThresholdPercent`, `FileFormat`, `FilenamePattern`, and all seven `SimilarityCheck.*` keys (including `ConsecutiveThreshold`)
      - Add default-injection test: load a config file whose `Screenshots` section contains only `StoragePath` and `MaxStorageGB` (simulating a Phase 3 config file); verify all new keys are injected with defaults; verify `SimilarityCheck` sub-object is created
      - Add default-injection test: `SimilarityCheck` sub-object exists but is missing `Action`; verify `Action` is injected as `'StopLoop'`
      - Add default-injection test: `SimilarityCheck` sub-object exists but is missing `ConsecutiveThreshold`; verify `ConsecutiveThreshold` is injected as `1`
      - Run full Pester suite; confirm count increases

2. [x] Create `ScreenCaptureAPI.cs`
   1. [x] 2.1: Create `powershell-module/src/ScreenCaptureAPI.cs`:
      - Namespace `LastWarAutoScreenshot`, class `ScreenCaptureAPI`
      - `using` directives: `System`, `System.Drawing`, `System.Drawing.Imaging`, `System.Runtime.InteropServices`, `System.IO`
      - **P/Invoke declarations** (all `private`; do NOT redeclare `GetWindowRect` or `RECT` — reference `MouseControlAPI.GetWindowRect` and `MouseControlAPI.RECT` directly since both files are compiled in the same `Add-Type` call):

        ```csharp
        [DllImport("user32.dll", SetLastError = true)]
        private static extern IntPtr GetDC(IntPtr hWnd);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);

        [DllImport("gdi32.dll", SetLastError = true)]
        private static extern IntPtr CreateCompatibleDC(IntPtr hDC);

        [DllImport("gdi32.dll", SetLastError = true)]
        private static extern IntPtr CreateCompatibleBitmap(IntPtr hDC, int nWidth, int nHeight);

        [DllImport("gdi32.dll", SetLastError = true)]
        private static extern IntPtr SelectObject(IntPtr hDC, IntPtr hGdiObj);

        [DllImport("gdi32.dll", SetLastError = false)]
        private static extern bool DeleteDC(IntPtr hDC);

        [DllImport("gdi32.dll", SetLastError = false)]
        private static extern bool DeleteObject(IntPtr hObject);

        // PW_RENDERFULLCONTENT instructs DWM to composite all hardware-accelerated
        // surfaces (OpenGL, DirectX) into the provided HDC.  Required for games.
        // The window must not be minimised; exclusive-fullscreen windows are not supported.
        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool PrintWindow(IntPtr hwnd, IntPtr hdcBlt, uint nFlags);
        ```

      - **Constant:**

        ```csharp
        private const uint PW_RENDERFULLCONTENT = 0x00000002;
        ```

      - **`CaptureWindowRegion` public static method** — full XML doc comment required:

        ```csharp
        public static bool CaptureWindowRegion(
            IntPtr windowHandle,
            double relativeX,    double relativeY,
            double relativeWidth, double relativeHeight,
            string outputPath)
        ```

        Implementation steps (in order):
        1. Validate: `windowHandle != IntPtr.Zero`; `relativeX >= 0.0 && relativeX <= 1.0`; `relativeY >= 0.0 && relativeY <= 1.0`; `relativeWidth > 0.0 && relativeWidth <= 1.0`; `relativeHeight > 0.0 && relativeHeight <= 1.0`; `relativeX + relativeWidth <= 1.0`; `relativeY + relativeHeight <= 1.0`; `outputPath != null && outputPath.Length > 0`. Return `false` on any failure — do NOT throw; PowerShell callers check the bool return.
        2. Call `MouseControlAPI.GetWindowRect(windowHandle, out MouseControlAPI.RECT rect)`. If it returns `false`, return `false`.
        3. Compute window pixel dimensions: `int winWidth = rect.Right - rect.Left`, `int winHeight = rect.Bottom - rect.Top`. Return `false` if either is ≤ 0.
        4. Compute capture region pixel coordinates: `int captureX = (int)(relativeX * winWidth)`, `int captureY = (int)(relativeY * winHeight)`, `int captureW = (int)(relativeWidth * winWidth)`, `int captureH = (int)(relativeHeight * winHeight)`. Return `false` if `captureW <= 0 || captureH <= 0`.
        5. Declare `IntPtr hWinDC = IntPtr.Zero`, `IntPtr hCompatDC = IntPtr.Zero`, `IntPtr hBitmap = IntPtr.Zero`, `IntPtr hOldBitmap = IntPtr.Zero` outside the `try` block so they are accessible in `finally`.
        6. In a `try` block:
           a. `hWinDC = GetDC(windowHandle)` — gets the window's screen DC.
           b. `hCompatDC = CreateCompatibleDC(hWinDC)` — creates an off-screen DC compatible with the window DC.
           c. `hBitmap = CreateCompatibleBitmap(hWinDC, captureW, captureH)` — creates a bitmap of the capture region size.
           d. `hOldBitmap = SelectObject(hCompatDC, hBitmap)` — selects the new bitmap into the compatible DC.
           e. Call `PrintWindow(windowHandle, hCompatDC, PW_RENDERFULLCONTENT)`. If it returns `false`, return `false` from inside the `try` (the `finally` still runs and cleans up GDI objects).
           f. Create `using (Bitmap bmp = Image.FromHbitmap(hBitmap))`:
              - Crop to the capture region: `using (Bitmap region = bmp.Clone(new Rectangle(captureX, captureY, captureW, captureH), bmp.PixelFormat))`
              - Ensure output directory exists: `string dir = Path.GetDirectoryName(outputPath); if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);`
              - Save: `region.Save(outputPath, ImageFormat.Png)`
           g. Return `true`.
        7. In the `finally` block (always executes): restore old bitmap `if (hOldBitmap != IntPtr.Zero) SelectObject(hCompatDC, hOldBitmap)`; delete bitmap `if (hBitmap != IntPtr.Zero) DeleteObject(hBitmap)`; delete compatible DC `if (hCompatDC != IntPtr.Zero) DeleteDC(hCompatDC)`; release window DC `if (hWinDC != IntPtr.Zero) ReleaseDC(windowHandle, hWinDC)`.
        - **XML `.remarks`:** "Requires the target window to be non-minimised and in windowed (not exclusive-fullscreen) mode. Uses `PrintWindow(PW_RENDERFULLCONTENT)` to capture DWM-composited content including OpenGL surfaces. The capture region must be fully within the window bounds."

      - **`CompareImages` public static method** — full XML doc comment required:

        ```csharp
        public static double CompareImages(
            string path1, string path2,
            int sampleCount,
            int tolerancePerChannel,
            bool fullScan)
        ```

        Implementation steps:
        1. Validate: `path1 != null && File.Exists(path1)`; `path2 != null && File.Exists(path2)`; `sampleCount >= 1`; `tolerancePerChannel >= 0 && tolerancePerChannel <= 255`. Return `-1.0` on any failure.
        2. Declare `Bitmap bmp1 = null`, `Bitmap bmp2 = null` outside `try`.
        3. In a `try` block:
           a. `bmp1 = new Bitmap(path1)`, `bmp2 = new Bitmap(path2)`.
           b. If `bmp1.Width != bmp2.Width || bmp1.Height != bmp2.Height`: return `0.0` (different dimensions cannot be similar — indicates a capture setup error, not a scroll detection scenario).
           c. If `fullScan`: `sampleCount = bmp1.Width * bmp1.Height`.
           d. Comparison loop: `int matchCount = 0;` for `i = 0` to `sampleCount - 1`:
              - Compute sample coordinate:
                `int x = (int)((double)i / sampleCount * bmp1.Width) % bmp1.Width;`
                `int y = (int)((double)i / sampleCount * bmp1.Height);`
              - `Color c1 = bmp1.GetPixel(x, y); Color c2 = bmp2.GetPixel(x, y);`
              - If `Math.Abs(c1.R - c2.R) <= tolerancePerChannel && Math.Abs(c1.G - c2.G) <= tolerancePerChannel && Math.Abs(c1.B - c2.B) <= tolerancePerChannel`: `matchCount++`
           e. Return `(double)matchCount / sampleCount`.
        4. In `finally`: `bmp1?.Dispose(); bmp2?.Dispose()`.
        - **XML `.remarks`:** "Uses deterministic grid-based sampling for reproducible results without seeding. Full scan mode may be slow for large images; use when accuracy is critical. Returns -1.0 on argument errors, 0.0 on dimension mismatch, 0.0–1.0 on successful comparison."

      - No `SetLastError = true` on `DeleteDC`, `DeleteObject` — these do not reliably set the last error code on failure
      - Full XML doc comments on both public methods (`<summary>`, `<param>`, `<returns>`, `<remarks>`)

   2. [x] 2.2: Create `powershell-module/Tests/ScreenCaptureAPI.Tests.ps1`:
      - Import module in `BeforeAll` using the manifest path (standard pattern); load `System.Drawing.Common` via `Add-Type -AssemblyName 'System.Drawing.Common'` in `BeforeAll` so `[System.Drawing.Bitmap]` is available for test bitmap creation. No `InModuleScope` needed — these tests call static .NET types directly.
      - **Type verification:**
        - `[LastWarAutoScreenshot.ScreenCaptureAPI]` type loads without error
        - `CaptureWindowRegion` static method exists and has 6 parameters: `IntPtr`, `double`, `double`, `double`, `double`, `string`
        - `CompareImages` static method exists and has 5 parameters: `string`, `string`, `int`, `int`, `bool`
      - **`CaptureWindowRegion` parameter validation** (do NOT pass a real HWND — P/Invoke is not tested in unit tests; test validation logic only):
        - `windowHandle = [IntPtr]::Zero` → returns `$false`
        - `relativeX = 1.5` (out of range) → returns `$false`
        - `relativeY = -0.1` (out of range) → returns `$false`
        - `relativeWidth = 0.0` (zero is invalid) → returns `$false`
        - `relativeX + relativeWidth = 1.1` (exceeds 1.0) → returns `$false`
        - `outputPath = $null` → returns `$false`
        - `outputPath = ''` → returns `$false`
      - **`CompareImages` unit tests** (use real bitmap files written to `TestDrive:\`; create test PNGs using `[System.Drawing.Bitmap]::new(10,10)` and `SetPixel`):
        - Two identical bitmaps (all pixels `Color.Red`) → returns value ≥ `0.98`
        - Two bitmaps differing by 5 per channel on every pixel (within `tolerancePerChannel = 10`) → returns ≥ `0.98`
        - Two completely different bitmaps (one all red, one all blue) → returns ≤ `0.05`
        - Bitmaps with different dimensions → returns `0.0`
        - `path1` does not exist → returns `-1.0`
        - `sampleCount = 0` → returns `-1.0`
        - `tolerancePerChannel = -1` (invalid) → returns `-1.0`
        - `fullScan = $true` with two identical bitmaps → returns ≥ `0.98`
        - Determinism: call `CompareImages` twice with identical arguments → both calls return exactly the same value
      - Run full Pester suite; confirm count increases
   3. [x] 2.3: Create PowerShell wrapper functions for the two `ScreenCaptureAPI` static methods — required because Pester v5 `Mock` cannot mock static .NET methods; the established project pattern is thin wrapper functions (see `Invoke-SendMouseInput`, `Invoke-GetCursorPosition`, `Invoke-GetWindowRect`):
      1. [x] 2.3.1: Create `powershell-module/Private/Invoke-CaptureWindowRegion.ps1`:
         - `Invoke-CaptureWindowRegion -WindowHandle [IntPtr] -RelativeX [double] -RelativeY [double] -RelativeWidth [double] -RelativeHeight [double] -OutputPath [string]`
         - All parameters mandatory; thin one-liner body: `return [LastWarAutoScreenshot.ScreenCaptureAPI]::CaptureWindowRegion($WindowHandle, $RelativeX, $RelativeY, $RelativeWidth, $RelativeHeight, $OutputPath)`
         - Returns the `[bool]` result from `CaptureWindowRegion` unchanged; callers inspect the bool — no logging here (logging is the caller's responsibility, same as `Invoke-GetWindowRect`)
         - Full comment-based help with `.SYNOPSIS`, `.PARAMETER`, `.OUTPUTS`
      2. [x] 2.3.2: Create `powershell-module/Private/Invoke-CompareImages.ps1`:
         - `Invoke-CompareImages -Path1 [string] -Path2 [string] -SampleCount [int] -TolerancePerChannel [int] -FullScan [bool]`
         - All parameters mandatory; thin one-liner body: `return [LastWarAutoScreenshot.ScreenCaptureAPI]::CompareImages($Path1, $Path2, $SampleCount, $TolerancePerChannel, $FullScan)`
         - Returns the `[double]` result unchanged
         - Full comment-based help with `.SYNOPSIS`, `.PARAMETER`, `.OUTPUTS`
      3. [x] 2.3.3: Add wrapper smoke-tests to `powershell-module/Tests/ScreenCaptureAPI.Tests.ps1` — verify each function exists as a command in module scope (load module in `BeforeAll`; use `InModuleScope`; assert `Get-Command Invoke-CaptureWindowRegion` and `Get-Command Invoke-CompareImages` return non-null objects)
      4. [x] 2.3.4: Run full Pester suite; confirm count increases

3. [x] Update `LastWarAutoScreenshot.psm1` to load `ScreenCaptureAPI.cs`
   1. [x] 3.1: Update `powershell-module/LastWarAutoScreenshot.psm1`:
      - Add `$screenCaptureApiPath = "$PSScriptRoot\src\ScreenCaptureAPI.cs"` alongside the existing `$mouseControlApiPath`, `$windowEnumerationApiPath` source path variables
      - Add `$screenCaptureApiPath` to the existing `$missingFiles` check loop (if the file is absent the module fails to load with a clear error message — same pattern as all other source files)
      - Add `'LastWarAutoScreenshot.ScreenCaptureAPI'` to the `$typeNames` guard array (prevents re-adding the type if the module is imported multiple times in the same session)
      - **Before** the existing `Add-Type -Path @(...)` call for the main C# source files, add:

        ```powershell
        # Load System.Drawing.Common before compiling ScreenCaptureAPI.cs
        # because that file references System.Drawing.Bitmap.
        Add-Type -AssemblyName 'System.Drawing.Common'
        $drawingAssemblyPath = [System.Drawing.Bitmap].Assembly.Location
        ```

      - Add `$screenCaptureApiPath` to the existing `Add-Type -Path @(...)` array so it compiles in the same pass as `MouseControlAPI.cs` — this is required because `ScreenCaptureAPI.cs` calls `MouseControlAPI.GetWindowRect` and references `MouseControlAPI.RECT`
      - Add `-ReferencedAssemblies $drawingAssemblyPath` to the same `Add-Type` call
      - Add a code comment directly above the `Add-Type` call explaining why `System.Drawing.Common` must be loaded first and why `$drawingAssemblyPath` is passed as `-ReferencedAssemblies`
      - Do NOT alter the separate `Add-Type` call for `ConsoleAppBridge.cs` — that compilation pass is unrelated and unaffected
   2. [x] 3.2: Verify the module loads cleanly after step 3.1:
      - Run: `Import-Module .\LastWarAutoScreenshot.psd1 -Force -Verbose`
      - Confirm `[LastWarAutoScreenshot.ScreenCaptureAPI]` type is accessible: `[LastWarAutoScreenshot.ScreenCaptureAPI] | Should -Not -BeNullOrEmpty` (run interactively)
      - Confirm `[System.Drawing.Bitmap]` type is accessible (i.e. `System.Drawing.Common` loaded correctly)
      - Run the full Pester suite; confirm count meets or exceeds the previous baseline and all tests pass

4. [x] Create `Resolve-ScreenshotFilename.ps1`
   1. [x] 4.1: Create `powershell-module/Private/Resolve-ScreenshotFilename.ps1`:
      - `Resolve-ScreenshotFilename -Pattern [string] -MacroName [string] -ActionName [string] -ActionType [string] -Index [int] -Format [string]`
      - All parameters mandatory; no defaults — caller always supplies them (prevents silent failures from missing data)
      - Substitution rules applied in order:
        - `{MacroName}` → `$MacroName` (already validated at record time; re-sanitise defensively: replace any character not in `[a-zA-Z0-9_\-]` with `_`)
        - `{ActionName}` → `$ActionName` if non-empty and non-`$null`; otherwise `$ActionType` (e.g. `'Screenshot'`)
        - `{Timestamp}` → `(Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')`
        - `{Date}` → `(Get-Date).ToUniversalTime().ToString('yyyyMMdd')`
        - `{Time}` → `(Get-Date).ToUniversalTime().ToString('HHmmss')`
        - `{Index}` → `$Index.ToString('D4')` (zero-padded to 4 digits: `0001`, `0002`, …, `9999`; values ≥ 10000 render without padding, e.g. `10000`)
      - After all substitutions: replace any character NOT in `[a-zA-Z0-9_\-]` with `_` (defensive sanitisation for placeholder values that may have produced characters illegal in Windows filenames)
      - Append file extension based on `$Format`: `.png` if `$Format -ieq 'PNG'` (only valid value in Phase 5); log `Error` and return `$null` if `$Format` is not a recognised value
      - **Length validation:** if the resolved filename (including extension, excluding path) exceeds 200 characters: log `Error "Resolved screenshot filename exceeds 200 characters ($($resolvedFilename.Length) chars). Shorten the FilenamePattern or macro/action names."` via `Write-LastWarLog`; return `$null`
      - Return the fully resolved filename string (not a full path — the caller joins it with `StoragePath`)
      - Return `$null` with `Write-LastWarLog -Level Error` if `$Pattern` is `$null` or empty
      - Full comment-based help with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.OUTPUTS`
   2. [x] 4.2: Create `powershell-module/Tests/Resolve-ScreenshotFilename.Tests.ps1`:
      - Import module in `BeforeAll`; all tests use `InModuleScope -ModuleName 'LastWarAutoScreenshot'`
      - **Placeholder substitution:**
        - `{MacroName}` → replaced with exact supplied `MacroName` value
        - `{ActionName}` non-empty → replaced with supplied `ActionName`
        - `{ActionName}` empty string → replaced with `ActionType`
        - `{ActionName}` `$null` → replaced with `ActionType`
        - `{Timestamp}` → result matches regex `\d{8}_\d{6}`
        - `{Date}` → result matches `\d{8}`
        - `{Time}` → result matches `\d{6}`
        - `{Index}` with `$Index = 1` → substring `'0001'` present in result
        - `{Index}` with `$Index = 9999` → substring `'9999'` present
        - `{Index}` with `$Index = 10000` → substring `'10000'` present (no truncation)
      - **Extension:**
        - `Format = 'PNG'` → result ends with `'.png'`
        - `Format = 'UNKNOWN'` → returns `$null`; `Write-LastWarLog` called with `Level = 'Error'`
      - **Defensive sanitisation:**
        - `MacroName = 'my macro'` (space from an edge case) → space replaced with `_` in result
      - **Length validation:**
        - Pattern that resolves to exactly 200 characters → result returned successfully (boundary condition)
        - Pattern that resolves to 201 characters → returns `$null`; `Write-LastWarLog` called with `Level = 'Error'`; error message contains the actual character count
      - **Invalid input:**
        - `Pattern = ''` → returns `$null`; `Write-LastWarLog` called with `Level = 'Error'`
        - `Pattern = $null` → returns `$null`; `Write-LastWarLog` called with `Level = 'Error'`
      - **Full pattern with all placeholders:**
        - `Pattern = '{MacroName}_{ActionName}_{Timestamp}_{Index}'`, `MacroName = 'get-vs-scores'`, `ActionName = 'vs-screenshot'`, `Index = 3`, `Format = 'PNG'`
        - Result matches regex `'^get-vs-scores_vs-screenshot_\d{8}_\d{6}_0003\.png$'`
      - Run full Pester suite; confirm count increases

5. [x] Create `Invoke-CaptureScreenRegion.ps1`
   1. [x] 5.1: Create `powershell-module/Private/Invoke-CaptureScreenRegion.ps1`:
      - `Invoke-CaptureScreenRegion -WindowHandle [object] -RegionTopLeftRelativeX [double] -RegionTopLeftRelativeY [double] -RegionBottomRightRelativeX [double] -RegionBottomRightRelativeY [double] -ScreenshotContext [hashtable]`
      - All parameters mandatory
      - `$ScreenshotContext` must contain keys: `Index` (int), `MacroName` (string), `ActionName` (string), `PreviousScreenshotPath` (string or `$null`)
      - Execution steps (in order):
        1. **Load config:** read `Screenshots` section from `Get-ModuleConfiguration`: `$storePath`, `$maxStorageGB`, `$format`, `$filenamePattern`, `$warningThreshold`
        2. **Storage path check:** if `$storePath` is `$null` or empty string, log `Write-LastWarLog -Level Warning -Message 'Screenshot StoragePath is not configured — skipping screenshot action'`; return `[PSCustomObject]@{ Success=$false; Skipped=$true; FilePath=$null; Message='StoragePath not configured' }` immediately
        3. **Disk free space check:** use `(Get-PSDrive -Name $driveLetter -PSProvider FileSystem).Free` to get bytes free (We only support local Filesystem drives so this will always report correct freespace and is compatible with PSDrives in Pester such as `TestDrive:\`). Wrap in a `try/catch` in case `$storePath[0]` is not a valid drive root. If `Free -le 0`, log `Error 'Disk is full — cannot save screenshot'`; return `[PSCustomObject]@{ Success=$false; Skipped=$false; FilePath=$null; Message='Disk full' }`
        4. **Storage limit check:** call `Get-StorageInfo`. If `$storageInfo.UsedPercent -ge 100.0`, log `Error "Screenshot storage limit reached ($($storageInfo.UsedGB) GB used of $($storageInfo.MaxGB) GB limit)"` ; return `Success=$false`, `Skipped=$false`. If `$storageInfo.UsedPercent -ge $warningThreshold`, log `Warning "Screenshot storage at $([int]$storageInfo.UsedPercent)% of configured limit ($storePath)"` and **continue** (do not block capture)
        5. **Validate region dimensions:** `$relativeWidth = $RegionBottomRightRelativeX - $RegionTopLeftRelativeX`; `$relativeHeight = $RegionBottomRightRelativeY - $RegionTopLeftRelativeY`. If `$relativeWidth -le 0` or `$relativeHeight -le 0`, log `Error "Invalid screenshot region: bottom-right must be to the right of and below top-left"` ; return `Success=$false`, `Skipped=$false`
        6. **Increment index and resolve filename:** increment `$ScreenshotContext.Index` by 1. Call `Resolve-ScreenshotFilename -Pattern $filenamePattern -MacroName $ScreenshotContext.MacroName -ActionName $ScreenshotContext.ActionName -ActionType 'Screenshot' -Index $ScreenshotContext.Index -Format $format`. If `$null` returned (pattern error or length exceeded), return `Success=$false`, `Skipped=$false`
        7. **Resolve full path and auto-create directory:** `$fullPath = Join-Path $storePath $resolvedFilename`. If `(-not (Test-Path $storePath))`, create directory: `New-Item -ItemType Directory -Path $storePath -Force | Out-Null`; log `Write-LastWarLog -Level Info "Created screenshot storage directory: $storePath"`
        8. **Convert handle and capture:** convert `$WindowHandle` to `[IntPtr]` using the same handle-conversion pattern as `Set-WindowState` (accepts `IntPtr`, `int64`, `int`, `string`). Call `Invoke-CaptureWindowRegion -WindowHandle $hWnd -RelativeX $RegionTopLeftRelativeX -RelativeY $RegionTopLeftRelativeY -RelativeWidth $relativeWidth -RelativeHeight $relativeHeight -OutputPath $fullPath`. If returns `$false`, log `Error "CaptureWindowRegion failed for path: $fullPath"`; return `Success=$false`, `Skipped=$false`
        9. **Update context:** `$ScreenshotContext.PreviousScreenshotPath = $fullPath`
        10. Log `Write-LastWarLog -Level Info "Screenshot saved: $fullPath"` via `Write-LastWarLog`
        11. Return `[PSCustomObject]@{ Success=$true; Skipped=$false; FilePath=$fullPath; Message='' }`
      - Full comment-based help including `.NOTES` documenting: storage directory auto-creation, the `Skipped` return field meaning (storage not configured vs actual error), the `$ScreenshotContext` mutation side-effect, and the window handle conversion pattern
   2. [x] 5.2: Create `powershell-module/Tests/Invoke-CaptureScreenRegion.Tests.ps1`:
      - Import module in `BeforeAll`; all tests use `InModuleScope -ModuleName 'LastWarAutoScreenshot'`
      - Common mocks in `BeforeEach`: `Get-ModuleConfiguration` returning config with `StoragePath = 'TestDrive:\Screenshots'`, `MaxStorageGB = 2.0`, `FileFormat = 'PNG'`, `FilenamePattern = '{MacroName}_{ActionName}_{Timestamp}_{Index}'`, `StorageWarningThresholdPercent = 90`; `Get-StorageInfo` returning `IsConfigured=$true`, `UsedPercent = 50.0`, `UsedGB = 1.0`, `MaxGB = 2.0`; `Resolve-ScreenshotFilename` returning `'test_screenshot_20260101_120000_0001.png'`; mock `Invoke-CaptureWindowRegion` returning `$true` (the PowerShell wrapper function — not the static .NET method, which Pester cannot mock); `Test-Path` returning `$true` for storage path
      - **`StoragePath` not configured:**
        - Mock `Get-ModuleConfiguration` returning `StoragePath = ''`
        - Returns `Success=$false`, `Skipped=$true`, `FilePath=$null`
        - `Write-LastWarLog` called with `Level = 'Warning'`
      - **Storage limit reached (100%):**
        - Mock `Get-StorageInfo` returning `UsedPercent = 100.0`
        - Returns `Success=$false`, `Skipped=$false`
        - `Write-LastWarLog` called with `Level = 'Error'`
      - **Storage at warning threshold (92%):**
        - Mock `Get-StorageInfo` returning `UsedPercent = 92.0`
        - `Write-LastWarLog` called with `Level = 'Warning'`; capture still proceeds; returns `Success=$true`
      - **Storage directory auto-created:**
        - Mock `Test-Path` returning `$false` for the storage path; mock `New-Item`
        - Verify `New-Item` called with `-ItemType Directory`
        - `Write-LastWarLog` called with `Level = 'Info'` containing the storage path
      - **Region dimensions invalid (relativeWidth ≤ 0):**
        - Pass `RegionTopLeftRelativeX = 0.8`, `RegionBottomRightRelativeX = 0.2` (right > left violated)
        - Returns `Success=$false`, `Skipped=$false`; `Write-LastWarLog` called with `Level = 'Error'`
      - **Capture succeeds:**
        - Returns `Success=$true`, `FilePath` ends with `.png`
        - `$ScreenshotContext.Index` incremented: starts at 0, is 1 after call
        - `$ScreenshotContext.PreviousScreenshotPath` updated to the returned `FilePath`
      - **`CaptureWindowRegion` returns `$false`:**
        - Returns `Success=$false`, `Skipped=$false`; `Write-LastWarLog` called with `Level = 'Error'`
      - **`ScreenshotContext.Index` increments across multiple calls:**
        - Call twice with the same context; verify `$ScreenshotContext.Index` is 2 after the second call
      - **`Resolve-ScreenshotFilename` returns `$null` (length exceeded):**
        - Mock `Resolve-ScreenshotFilename` returning `$null`
        - Returns `Success=$false`, `Skipped=$false`
      - Run full Pester suite; confirm count increases

6. [x] Create `Test-ScreenshotSimilarity.ps1`
   1. [x] 6.1: Create `powershell-module/Private/Test-ScreenshotSimilarity.ps1`:
      - `Test-ScreenshotSimilarity -ReferencePath [string] -ComparePath [string]`
      - Both parameters mandatory
      - Reads `Screenshots.SimilarityCheck.*` config keys from `Get-ModuleConfiguration`: `$threshold`, `$sampleCount`, `$fullScan`, `$tolerancePerChannel`
      - **Path validation:** if `$ReferencePath` is `$null` or `(-not (Test-Path $ReferencePath))`: log `Write-LastWarLog -Level Warning 'Similarity check skipped: reference image path is null or does not exist'`; return `[PSCustomObject]@{ Similar=$false; MatchPercent=0.0; Skipped=$true; Message='Reference path invalid or not found' }`. Repeat equivalent check for `$ComparePath`.
      - Call `Invoke-CompareImages -Path1 $ReferencePath -Path2 $ComparePath -SampleCount $sampleCount -TolerancePerChannel $tolerancePerChannel -FullScan $fullScan` (the PowerShell wrapper — not the static .NET method directly, which Pester cannot mock)
      - If return value is `-1.0` (argument error inside C#): log `Write-LastWarLog -Level Error 'Similarity comparison returned an error (-1.0)'`; return `[PSCustomObject]@{ Similar=$false; MatchPercent=-1.0; Skipped=$false; Message='CompareImages returned error' }`
      - `$similar = ($matchRatio -ge $threshold)`
      - Returns `[PSCustomObject]@{ Similar=[bool]; MatchPercent=[double]; Skipped=[bool]; Message=[string] }`
        - `Similar`: `$true` if `$matchRatio -ge $threshold`; `$false` otherwise
        - `MatchPercent`: the raw `CompareImages` return value (0.0–1.0 or -1.0 on error)
        - `Skipped`: `$true` only when path validation prevents the comparison from running
        - `Message`: empty string on success; human-readable description of why comparison was skipped or failed
      - Full comment-based help with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.OUTPUTS`, `.NOTES` documenting that `MatchPercent` is a decimal ratio (0.0–1.0), `Threshold` in config is compared directly against it, and `Skipped=$true` means the comparison did not run (not that images are dissimilar)
   2. [x] 6.2: Create `powershell-module/Tests/Test-ScreenshotSimilarity.Tests.ps1`:
      - Import module in `BeforeAll`; all tests use `InModuleScope -ModuleName 'LastWarAutoScreenshot'`
      - Common mock in `BeforeEach`: `Get-ModuleConfiguration` returning config with `SimilarityCheck.Threshold = 0.98`, `SimilarityCheck.SampleCount = 1000`, `SimilarityCheck.TolerancePerChannel = 10`, `SimilarityCheck.FullScan = $false`; mock `Invoke-CompareImages` returning `0.99` (the PowerShell wrapper function — not the static .NET method, which Pester cannot mock); mock `Test-Path` returning `$true` for both paths
      - **Images similar (Invoke-CompareImages returns 0.99, threshold 0.98):**
        - Returns `Similar=$true`, `MatchPercent = 0.99`, `Skipped=$false`
      - **Images not similar (Invoke-CompareImages returns 0.40):**
        - Mock `Invoke-CompareImages` returning `0.40`
        - Returns `Similar=$false`, `MatchPercent = 0.40`, `Skipped=$false`
      - **Threshold boundary — exactly at threshold (0.98):**
        - Mock `Invoke-CompareImages` returning `0.98`
        - Returns `Similar=$true` (≥ threshold, not strictly greater than)
      - **`ReferencePath` is `$null`:**
        - Returns `Skipped=$true`, `Similar=$false`; `Write-LastWarLog` called with `Level = 'Warning'`
        - `Invoke-CompareImages` NOT called
      - **`ComparePath` does not exist:**
        - Mock `Test-Path` returning `$false` for `ComparePath`
        - Returns `Skipped=$true`, `Similar=$false`
        - `Invoke-CompareImages` NOT called
      - **`Invoke-CompareImages` returns `-1.0` (error in C#):**
        - Mock `Invoke-CompareImages` returning `-1.0`
        - Returns `Similar=$false`, `MatchPercent = -1.0`, `Skipped=$false`; `Write-LastWarLog` called with `Level = 'Error'`
      - **Config values read and passed to `Invoke-CompareImages`:**
        - Mock config with `SampleCount = 500`, `TolerancePerChannel = 5`, `FullScan = $false`
        - Verify `Should -Invoke Invoke-CompareImages -Times 1` with `-ParameterFilter { $SampleCount -eq 500 -and $TolerancePerChannel -eq 5 -and $FullScan -eq $false }`
      - Run full Pester suite; confirm count increases

7. [x] Update `Invoke-MacroAction.ps1` to implement screenshot capture and `SimilarityStop` handling
   1. [x] 7.1: Update `powershell-module/Private/Invoke-MacroAction.ps1`:
      - Add `[hashtable]$ScreenshotContext = $null` as an **optional** parameter (default `$null` — existing callers that do not pass it are unaffected; `Invoke-MacroSequence` always passes it)
      - **Replace the existing `'Screenshot'` case** (which logged a warning and returned `Skipped=$true`) with the following implementation:
        1. If `$ScreenshotContext -eq $null`: log `Write-LastWarLog -Level Warning 'ScreenshotContext not supplied — skipping Screenshot action'`; return `[PSCustomObject]@{ Success=$true; Skipped=$true; SimilarityStop=$false; Message='ScreenshotContext not supplied' }` immediately
        2. Store the previous path **before** calling `Invoke-CaptureScreenRegion`: `$prevPath = $ScreenshotContext.PreviousScreenshotPath` (used after capture for similarity comparison)
        3. Set `$ScreenshotContext.ActionName = if ($Action.name) { $Action.name } else { 'Screenshot' }`
        4. Call `Invoke-CaptureScreenRegion` with all region parameters and `$ScreenshotContext`
        5. If `$captureResult.Skipped -eq $true`: return `[PSCustomObject]@{ Success=$true; Skipped=$true; SimilarityStop=$false; Message=$captureResult.Message }` (storage not configured — warning already logged inside `Invoke-CaptureScreenRegion`)
        6. If `$captureResult.Success -eq $false`: return `[PSCustomObject]@{ Success=$false; Skipped=$false; SimilarityStop=$false; Message=$captureResult.Message }`
        7. **Similarity check** — only run if all conditions are true: `$ScreenshotContext.PreviousScreenshotPath` was non-`$null` **before this call** (i.e. `$prevPath -ne $null`), and `$simConfig.Enabled -eq $true` (where `$simConfig` is a single `Get-ModuleConfiguration` call stored at the top of the similarity check block — do NOT call `Get-ModuleConfiguration` twice):
           - `$simConfig = (Get-ModuleConfiguration).Screenshots.SimilarityCheck`
           a. Call `Test-ScreenshotSimilarity -ReferencePath $prevPath -ComparePath $captureResult.FilePath`
           b. If `$similarityResult.Skipped -eq $true`: log `Write-LastWarLog -Level Warning "Similarity check skipped: $($similarityResult.Message)"`; reset `$ScreenshotContext.ConsecutiveSimilarCount = 0`; return `Success=$true`, `SimilarityStop=$false`
           c. If `$similarityResult.Similar -eq $true`: increment `$ScreenshotContext.ConsecutiveSimilarCount` by 1
              - If `$ScreenshotContext.ConsecutiveSimilarCount -ge $simConfig.ConsecutiveThreshold`:
                - If `$simConfig.Action -ieq 'StopLoop'` OR `$simConfig.Action -ieq 'StopMacro'`: log `Write-LastWarLog -Level Info "Similarity threshold reached ($([int]($similarityResult.MatchPercent * 100))% match, $($ScreenshotContext.ConsecutiveSimilarCount) consecutive) — signalling similarity stop"`; return `[PSCustomObject]@{ Success=$true; Skipped=$false; SimilarityStop=$true; Message='Similarity threshold reached' }`
                - If `$simConfig.Action -ieq 'Warn'`: log `Write-LastWarLog -Level Warning "Screenshot similarity above threshold ($([int]($similarityResult.MatchPercent * 100))% match, $($ScreenshotContext.ConsecutiveSimilarCount) consecutive) — possible scroll end; continuing"`; return `Success=$true`, `SimilarityStop=$false`
              - If below threshold (accumulating): return `Success=$true`, `SimilarityStop=$false` (continue without action)
           d. If `$similarityResult.Similar -eq $false`: reset `$ScreenshotContext.ConsecutiveSimilarCount = 0`; return `Success=$true`, `SimilarityStop=$false`
        8. Return `[PSCustomObject]@{ Success=$true; Skipped=$false; SimilarityStop=$false; Message='' }`
      - **Update the `'Loop'` case** — after the recursive `Invoke-MacroAction` call for each sub-action within each iteration, add the following check:

        ```powershell
        if ($subResult.SimilarityStop -eq $true) {
            $loopSimConfig = (Get-ModuleConfiguration).Screenshots.SimilarityCheck
            if ($loopSimConfig.Action -ieq 'StopLoop') {
                Write-LastWarLog -Level Info `
                    "Similarity threshold reached inside loop '$($Action.name)' — exiting loop and continuing parent sequence"
                # Break out of ALL loop iterations; return SimilarityStop=$false so the parent sequence continues
                return [PSCustomObject]@{
                    Success       = $true
                    Skipped       = $false
                    SimilarityStop = $false
                    Message       = 'Similarity stop consumed by loop (StopLoop)'
                }
            }
            elseif ($loopSimConfig.Action -ieq 'StopMacro') {
                # Propagate SimilarityStop=$true upward; parent sequence will stop
                return [PSCustomObject]@{
                    Success       = $true
                    Skipped       = $false
                    SimilarityStop = $true
                    Message       = $subResult.Message
                }
            }
            # 'Warn' case: SimilarityStop is never $true from the Screenshot case when Action='Warn',
            # so this branch is unreachable; included for exhaustiveness
        }
        ```

      - Add `SimilarityStop=[bool]` (default `$false`) to **every** `[PSCustomObject]` return statement in this function for uniformity — including the emergency stop early-return and unknown-type error return
      - Update `$Depth` guard comment to note that Loop actions pass `$ScreenshotContext` unchanged to recursive calls (same hashtable reference, ensuring index and previous-path tracking are continuous across loop iterations)
      - Update comment-based help: add `$ScreenshotContext` parameter description; update the dispatch table to reflect that Screenshot now captures; add `.NOTES` explaining the `StopLoop` vs `StopMacro` contract and the `SimilarityStop=$false` return from the Loop case for `StopLoop`

   2. [x] 7.2: Update `powershell-module/Tests/MacroExecution.Tests.ps1` — replace the existing Screenshot action tests with the following (keep all existing non-Screenshot tests unchanged):
      - Common additional mocks: `Invoke-CaptureScreenRegion`, `Test-ScreenshotSimilarity`
      - **Screenshot action — `ScreenshotContext` supplied, capture succeeds:**
        - Mock `Invoke-CaptureScreenRegion` returning `Success=$true`, `Skipped=$false`, `FilePath='TestDrive:\Screenshots\test.png'`
        - Verify `Invoke-CaptureScreenRegion` called with correct `RegionTopLeftRelativeX`, `RegionTopLeftRelativeY`, `RegionBottomRightRelativeX`, `RegionBottomRightRelativeY`
        - Returns `Success=$true`, `Skipped=$false`, `SimilarityStop=$false`
      - **Screenshot action — `ScreenshotContext = $null`:**
        - `Invoke-CaptureScreenRegion` NOT called
        - Returns `Success=$true`, `Skipped=$true`; `Write-LastWarLog` called with `Level = 'Warning'`
      - **Screenshot action — storage not configured (capture returns `Skipped=$true`):**
        - Mock `Invoke-CaptureScreenRegion` returning `Skipped=$true`, `Success=$false`
        - Returns `Success=$true`, `Skipped=$true`, `SimilarityStop=$false` (not an error)
      - **Screenshot action — capture fails (e.g. storage full):**
        - Mock `Invoke-CaptureScreenRegion` returning `Success=$false`, `Skipped=$false`
        - Returns `Success=$false`, `Skipped=$false`
      - **Similarity detection — `StopLoop` on similar screenshots, `ConsecutiveThreshold = 1`:**
        - Set `$ScreenshotContext.PreviousScreenshotPath = 'TestDrive:\Screenshots\prev.png'` (non-null, so comparison runs); `$ScreenshotContext.ConsecutiveSimilarCount = 0`
        - Mock config with `SimilarityCheck.Enabled = $true`, `Action = 'StopLoop'`, `ConsecutiveThreshold = 1`
        - Mock `Test-ScreenshotSimilarity` returning `Similar=$true`
        - Returns `Success=$true`, `SimilarityStop=$true`; `Write-LastWarLog` called with `Level = 'Info'`; `$ScreenshotContext.ConsecutiveSimilarCount` is `1`
      - **Similarity detection — `ConsecutiveThreshold = 3`, only 2 consecutive matches so far — no stop yet:**
        - Mock config with `ConsecutiveThreshold = 3`; `$ScreenshotContext.ConsecutiveSimilarCount = 1` (already had 1 previous match)
        - Mock `Test-ScreenshotSimilarity` returning `Similar=$true`
        - Returns `Success=$true`, `SimilarityStop=$false` (threshold not yet reached); `$ScreenshotContext.ConsecutiveSimilarCount` is `2`
      - **Similarity detection — `ConsecutiveThreshold = 3`, 3rd consecutive match — stop fires:**
        - Mock config with `ConsecutiveThreshold = 3`; `$ScreenshotContext.ConsecutiveSimilarCount = 2`
        - Mock `Test-ScreenshotSimilarity` returning `Similar=$true`
        - Returns `Success=$true`, `SimilarityStop=$true`
      - **Consecutive count reset when not similar:**
        - `$ScreenshotContext.ConsecutiveSimilarCount = 2`; Mock `Test-ScreenshotSimilarity` returning `Similar=$false`
        - Returns `Success=$true`, `SimilarityStop=$false`; `$ScreenshotContext.ConsecutiveSimilarCount` is `0`
      - **Similarity detection — `Warn` on similar screenshots:**
        - Mock config with `Action = 'Warn'`, `ConsecutiveThreshold = 1`
        - Mock `Test-ScreenshotSimilarity` returning `Similar=$true`
        - Returns `Success=$true`, `SimilarityStop=$false`; `Write-LastWarLog` called with `Level = 'Warning'`
      - **Similarity detection not run on first screenshot (no previous path):**
        - `$ScreenshotContext.PreviousScreenshotPath = $null` before call
        - `Test-ScreenshotSimilarity` NOT called
      - **Similarity detection not run when `Enabled = $false`:**
        - `$ScreenshotContext.PreviousScreenshotPath = 'TestDrive:\prev.png'` (non-null)
        - Mock config with `SimilarityCheck.Enabled = $false`
        - `Test-ScreenshotSimilarity` NOT called
      - **Loop action — `StopLoop` consumed by loop:**
        - Build a Loop action with 3 iterations referencing a named Screenshot action
        - Mock the recursive `Invoke-MacroAction` call to return `SimilarityStop=$true` on the 2nd iteration
        - Mock config with `Action = 'StopLoop'`
        - Loop returns `Success=$true`, `SimilarityStop=$false` (loop exited, parent continues)
        - `Write-LastWarLog` called with `Level = 'Info'` containing 'exits loop'
      - **Loop action — `StopMacro` propagated through loop:**
        - Same setup but config `Action = 'StopMacro'`
        - Loop returns `Success=$true`, `SimilarityStop=$true` (propagated upward)
      - **Loop action — `$ScreenshotContext` reference passes through unchanged:**
        - Verify the same hashtable object (by reference) is passed to each recursive `Invoke-MacroAction` call
      - Run full Pester suite; confirm count increases

8. [x] Update `Invoke-MacroSequence.ps1` for screenshot context management
   1. [x] 8.1: Update `powershell-module/Private/Invoke-MacroSequence.ps1`:
      - Initialise `$screenshotContext` **before** the `$actionLookup` build loop and before the sequence iteration loop:

        ```powershell
        $screenshotContext = @{
            Index                  = 0
            MacroName              = $MacroData.metadata.name
            ActionName             = ''
            PreviousScreenshotPath = $null
            ConsecutiveSimilarCount = 0
        }
        ```

      - Pass `-ScreenshotContext $screenshotContext` to every `Invoke-MacroAction` call in the sequence iteration loop
      - After each `Invoke-MacroAction` return: add a check for `$result.SimilarityStop -eq $true`:

        ```powershell
        if ($result.SimilarityStop -eq $true) {
            $Console.Write(
                [Spectre.Console.Markup]::new("[yellow]Scroll end detected at step $i of $total — macro completed (similarity threshold reached).`n[/]"))
            $completedActions++
            $similarityStop = $true
            break
        }
        ```

      - Declare `$similarityStop = $false` before the iteration loop; set it to `$true` in the above block
      - Update the return object to include the new property:

        ```powershell
        return [PSCustomObject]@{
            Success          = $success
            CompletedActions = $completedActions
            TotalActions     = $total
            SimilarityStop   = $similarityStop
            Message          = $message
        }
        ```

      - `$success` is `$true` when `$similarityStop -eq $true` (scroll end is the intended outcome)
      - `$completedActions` counts the similarity-stop step (the Screenshot action that triggered the stop is counted as completed)
      - Update comment-based help: document `$ScreenshotContext` initialisation, the `SimilarityStop` result property, that `SimilarityStop=$true` always results in `Success=$true`, and how `CompletedActions` is counted when similarity stops the macro
   2. [x] 8.2: Update the `Invoke-MacroSequence` tests in `powershell-module/Tests/MacroExecution.Tests.ps1`:
      - **`ScreenshotContext` initialised and passed to `Invoke-MacroAction`:**
        - Mock `Invoke-MacroAction`; capture the `ScreenshotContext` parameter on first call
        - Verify `ScreenshotContext.MacroName` equals `$MacroData.metadata.name`
        - Verify `ScreenshotContext.Index` starts at `0`
        - Verify `ScreenshotContext.PreviousScreenshotPath` starts as `$null`
      - **`SimilarityStop` propagated — step 2 of 5 triggers stop:**
        - Mock `Invoke-MacroAction` returning `SimilarityStop=$false` on step 1, `SimilarityStop=$true` on step 2 (other fields: `Success=$true`)
        - Verify sequence exits after step 2; `CompletedActions = 2`; result `Success=$true`, `SimilarityStop=$true`
        - Verify `$testConsole.Output` contains `'Scroll end detected'` and `'similarity threshold reached'`
      - **Normal completion — `SimilarityStop=$false`:**
        - All actions return `SimilarityStop=$false`; verify result `SimilarityStop=$false`, `Success=$true`
      - **Emergency stop still works alongside similarity:**
        - Set `$script:EmergencyStopRequested = $true`; verify `SimilarityStop=$false` in result; `Success=$false`
      - Run full Pester suite; confirm count increases

9. [x] Create `Show-ScreenshotConfigScreen.ps1`
   1. [x] 9.1: Create `powershell-module/Private/ConsoleApp/Show-ScreenshotConfigScreen.ps1`:
      - `Show-ScreenshotConfigScreen -Console [Spectre.Console.IAnsiConsole]`
      - Pattern is identical to `Show-LoggingConfigScreen.ps1` and `Show-MouseControlConfigScreen.ps1`: load config from `Get-ModuleConfiguration`; display a `Table` showing all current `Screenshots.*` values, their constraints, and description from `$script:ConfigValidationSchema`; prompt for each key in turn via a `$screenshotsKeyDefs` array (each entry: `Key`, `Type`, `Get`, `Set`, `DefGet` scriptblocks — same pattern as `Show-MouseControlConfigScreen`); validate with `Test-ConfigValue`; save/reset/discard at the end. This screen is called from `Show-ConfigMenuScreen` which is already wrapped in `Invoke-InAlternateScreen` from `Start-LastWarAutoScreenshot` — do NOT add a further `Invoke-InAlternateScreen` call inside this function.
      - **Key-specific handling** (iterate `$screenshotsKeyDefs` in a `foreach` loop; the `Type` field on each def entry determines which prompt style to use — same dispatch as `Show-MouseControlConfigScreen`):
        - `StoragePath` (`string`): uses `[Spectre.Console.TextPrompt[string]]::new($promptText)` with `AllowEmpty = $true` (direct .NET type, same as `Show-LoggingConfigScreen` line 181-183). Accept empty string (clears the path). After the user enters a non-empty value: verify the parent directory exists via `Test-Path (Split-Path $enteredPath -Parent)`. If parent does not exist: display a red error via `$Console.Write([Spectre.Console.Markup]::new("[red]Parent directory does not exist...[/]`n"))` and re-prompt. Do NOT create the directory here — auto-creation happens at capture time.
        - `MaxStorageGB` (`double`): `TextPrompt` with `AllowEmpty = $true`; validate via `Test-ConfigValue`
        - `StorageWarningThresholdPercent` (`int`): `TextPrompt` with `AllowEmpty = $true`; validate via `Test-ConfigValue`
        - `FileFormat` (`stringEnum`): display an info note via `$Console.Write([Spectre.Console.Markup]::new("[grey]Only PNG is supported in this release. Additional formats will be available in a future update.`n[/]"))` before the prompt; then display as `SelectionPrompt` created via `[LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(...)` with `'PNG'` as the only choice
        - `FilenamePattern` (`string`): `TextPrompt` with `AllowEmpty = $true`; after the user enters a non-empty value, display the resolved example filename: compute `$example = Resolve-ScreenshotFilename -Pattern $newValue -MacroName 'my-macro' -ActionName 'screenshot' -ActionType 'Screenshot' -Index 1 -Format 'PNG'`; display `$Console.Write([Spectre.Console.Markup]::new("[grey]Example filename: $([Spectre.Console.Markup]::Escape($example))`n[/]"))`if non-`$null`; if `$null` (pattern too long etc.) display the error in red and re-prompt
        - `SimilarityCheck.Enabled` (`bool`): uses `[Spectre.Console.ConfirmationPrompt]::new($promptText)` with `.DefaultValue = [bool]$currentValue` — identical pattern to `Show-MouseControlConfigScreen.ps1` lines 259-261. When the user answers `$true`, display info note via `$Console.Write([Spectre.Console.Markup]::new("[grey]Similarity detection compares each screenshot with the previous one during macro execution. Use PNG format for best accuracy. Recommended threshold: 0.98.`n[/]"))`
        - `SimilarityCheck.Threshold` (`double`): `TextPrompt` with prompt title including hint `"(0.0 to 1.0, where 1.0 = 100% identical)"`; validate via `Test-ConfigValue`
        - `SimilarityCheck.SampleCount` (`int`): `TextPrompt` with `AllowEmpty = $true`; validate via `Test-ConfigValue`
        - `SimilarityCheck.FullScan` (`bool`): `ConfirmationPrompt` as above. When user answers `$true`, display warning via `$Console.Write([Spectre.Console.Markup]::new("[yellow]Full scan mode compares every pixel. This may be slow for large screenshots.`n[/]"))` before setting the value
        - `SimilarityCheck.TolerancePerChannel` (`int`): `TextPrompt` with prompt title including hint `"(0 = exact match, 255 = any pixel counts as matching)"`; validate via `Test-ConfigValue`
        - `SimilarityCheck.Action` (`stringEnum`): `SelectionPrompt` with display choices — use a hashtable `$actionDisplayMap` to map raw→display and display→raw; choices array: `@('StopLoop (exit current loop, parent sequence continues)', 'StopMacro (halt entire macro; reported as success)', 'Warn (log warning and continue)')`. After prompt returns, map back to raw value using `switch ($displayChoice) { 'StopLoop (exit current loop, parent sequence continues)' { 'StopLoop' } 'StopMacro (halt entire macro; reported as success)' { 'StopMacro' } default { 'Warn' } }` — use exact `-ieq`-style switch matching (no `-split` or substring extraction)
        - `SimilarityCheck.ConsecutiveThreshold` (`int`): `TextPrompt` with prompt title including hint `"(1 = trigger on first match; higher values require N consecutive similar screenshots)"`; validate via `Test-ConfigValue`
        - For `'[Reset to default]'` sentinel on `TextPrompt` keys: recognise `$answer -ieq '[Reset to default]'` (single brackets — this is the raw text the user types, not a Spectre markup string). When displaying the sentinel hint in the prompt title, escape it as `[[Reset to default]]` so Spectre renders it as literal text `[Reset to default]`
      - **Save/Reset/Discard `SelectionPrompt`:** `'Yes - save now'`, `'Reset ALL Screenshot settings to defaults'`, `'Discard changes'` — identical contract to `Show-LoggingConfigScreen.ps1`
        - `'Yes - save now'`: call `Save-ModuleConfiguration` with updated config; display `"[green]Screenshot settings saved.[/]"` panel; log `Info`
        - `'Reset ALL Screenshot settings to defaults'`: replace all `Screenshots.*` keys (including all `SimilarityCheck.*` sub-keys) with defaults from `Get-DefaultModuleSettings`; save; display success panel; log `Info`
        - `'Discard changes'`: return without saving; display `"[grey]No changes saved.[/]"` panel
      - Full comment-based help with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.OUTPUTS`, and `.NOTES` documenting the `$Console` injection pattern, the `ConfirmationPrompt` pattern for bool keys, the `SimilarityCheck.Action` display→raw mapping, and the `[[Reset to default]]` display vs `[Reset to default]` comparison sentinel
   2. [x] 9.2: Create `powershell-module/Tests/ConsoleApp/Show-ScreenshotConfigScreen.Tests.ps1`:
      - Import module in `BeforeAll`; load `Spectre.Console.Testing.dll`; all tests use `InModuleScope -ModuleName 'LastWarAutoScreenshot'`
      - Common mocks in `BeforeEach`: `Get-ModuleConfiguration` returning known config with all `Screenshots.*` fields; `Save-ModuleConfiguration`; `Resolve-ScreenshotFilename` returning `'my-macro_screenshot_20260101_120000_0001.png'`; `Test-Path` returning `$true`
      - **Empty input → current values retained; saved with 'Yes - save now':**
        - Queue Enter (empty) for all `TextPrompt` keys; queue `'PNG'` for `FileFormat`; queue `'Yes - save now'`
        - `Should -Invoke Save-ModuleConfiguration -Exactly 1`; verify saved config `FileFormat = 'PNG'` unchanged
      - **`StoragePath` invalid parent:**
        - Mock `Test-Path` returning `$false` for the parent of the entered path
        - `$testConsole.Output` contains `'Parent directory does not exist'`; prompt re-displayed (mock returns `$true` on second call to allow the test to exit)
      - **`FileFormat` info note displayed:**
        - `$testConsole.Output` contains `'Only PNG is supported'`
      - **`FilenamePattern` — example filename displayed:**
        - Queue a custom pattern; verify `$testConsole.Output` contains the `Resolve-ScreenshotFilename` mock return value `'my-macro_screenshot_20260101_120000_0001.png'`
      - **`FilenamePattern` too long — error shown, re-prompt:**
        - Mock `Resolve-ScreenshotFilename` returning `$null` on first call; returning valid filename on second call
        - `$testConsole.Output` contains error text; function does not advance to next key until valid input given
      - **`SimilarityCheck.Enabled` set to yes — info note displayed:**
        - Queue `'y'` for `Enabled` confirm prompt
        - `$testConsole.Output` contains `'PNG format'`
      - **`SimilarityCheck.FullScan` enabled — warning displayed:**
        - Queue `'y'` for `FullScan`
        - `$testConsole.Output` contains `'may be slow'`
      - **`SimilarityCheck.Action` selection mapped correctly:**
        - Queue `'StopLoop (exit current loop, parent sequence continues)'` at selection prompt
        - Saved config `SimilarityCheck.Action = 'StopLoop'` (raw value, not display string — confirms the switch mapping extracts raw value from full display string)
      - **`SimilarityCheck.ConsecutiveThreshold` saved correctly:**
        - Queue `'3'` for `ConsecutiveThreshold` TextPrompt; verify saved config `SimilarityCheck.ConsecutiveThreshold = 3`
      - **`Reset ALL Screenshot settings to defaults` at save prompt:**
        - All `Screenshots.*` and `SimilarityCheck.*` keys in saved config equal defaults from `Get-DefaultModuleSettings` (including `ConsecutiveThreshold = 1`)
      - **`Discard changes` — `Save-ModuleConfiguration` NOT called**
      - Run full Pester suite; confirm count increases

10. [x] Update `Show-ConfigMenuScreen.ps1`
    1. [x] 10.1: Update `powershell-module/Private/ConsoleApp/Show-ConfigMenuScreen.ps1`:
       - Add `'Screenshot settings'` as a new menu option — position it **between `'Emergency stop settings'` and `'Storage & log file info'`** in the `SelectionPrompt` choices array. `'[[Back to main menu]]'` remains the **first** entry in the choices array (existing behaviour — do not move it). The full choices array after this change: `@('[[Back to main menu]]', 'Logging settings', 'Mouse control settings', 'Emergency stop settings', 'Screenshot settings', 'Storage & log file info')`
       - Add a `switch` case dispatching to `Show-ScreenshotConfigScreen -Console $Console` (no `Invoke-InAlternateScreen` wrapper here — the entire `Show-ConfigMenuScreen` call is already wrapped in `Invoke-InAlternateScreen` by `Start-LastWarAutoScreenshot`)
       - The `default` branch of the `switch` already handles `'[Back to main menu]'` (the unescaped returned value) by returning — no change needed to that branch
       - Update comment-based help: add `'Screenshot settings'` to the list of options in `.SYNOPSIS` or `.DESCRIPTION`
    2. [x] 10.2: Update `powershell-module/Tests/ConsoleApp/Show-ConfigMenuScreen.Tests.ps1`:
       - Add test: `'Screenshot settings'` option appears in `$testConsole.Output`
       - Add test: selecting `'Screenshot settings'` calls `Show-ScreenshotConfigScreen` exactly once
       - Add test: `Show-ScreenshotConfigScreen` is called with the same `$Console` instance that was passed to `Show-ConfigMenuScreen`
       - All existing tests must continue to pass without modification
       - Run full Pester suite; confirm count increases

11. [x] Enhance `Get-StorageInfo.ps1` and `Show-StorageInfoScreen.ps1`
    1. [x] 11.1: Update `powershell-module/Private/ConsoleApp/Get-StorageInfo.ps1`:
       - Add the following new properties to the returned `[PSCustomObject]`:
         - `DiskFreeGB=[double]`: `[math]::Round($driveInfo.AvailableFreeSpace / 1GB, 2)`. If `StoragePath` is unconfigured, path does not exist, or `DriveInfo` throws: set to `0.0`.
         - `DiskTotalGB=[double]`: `[math]::Round($driveInfo.TotalSize / 1GB, 2)`. Same fallback.
         - `ScreenshotCount=[int]`: count of `*.png`, `*.jpg`, `*.jpeg` files in `$StoragePath` via `(Get-ChildItem -Path $storePath -Include '*.png','*.jpg','*.jpeg' -File -ErrorAction SilentlyContinue).Count`. Set to `0` if unconfigured.
         - `OldestScreenshotDate=[nullable datetime]`: `LastWriteTimeUtc` of the oldest screenshot file; `$null` if `ScreenshotCount` is 0.
         - `NewestScreenshotDate=[nullable datetime]`: `LastWriteTimeUtc` of the newest screenshot file; `$null` if `ScreenshotCount` is 0.
       - Obtain `[System.IO.DriveInfo]` via `[System.IO.DriveInfo]::new($storePath.Substring(0,1))` (single drive letter character). Wrap in `try/catch` — set `DiskFreeGB = 0.0` and `DiskTotalGB = 0.0` on any exception (e.g. UNC path, network drive with no letter).
       - No breaking changes to existing properties (`IsConfigured`, `UsedGB`, `MaxGB`, `UsedPercent`, `LogFileSizeGB`)
       - Update comment-based help to document new properties
    2. [x] 11.2: Update `powershell-module/Private/ConsoleApp/Show-StorageInfoScreen.ps1`:
       - Update the existing `Table` to include two additional rows:
         - `'Disk space'`: `"$($info.DiskFreeGB) GB free of $($info.DiskTotalGB) GB total"` (shown regardless of whether storage is configured, using the drive of `StoragePath` if configured, or the system drive otherwise)
         - `'Screenshots'`: `"$($info.ScreenshotCount) file(s)"`; if `$info.ScreenshotCount -gt 0`, append `" — oldest: <OldestScreenshotDate formatted dd/MM/yy HH:mm> UTC, newest: <NewestScreenshotDate>"` on the same row
       - Add disk low warning: if `IsConfigured=$true` and `$info.DiskFreeGB -lt 5.0` and `$info.DiskFreeGB -gt 0.0`: display warning panel `"[yellow]Disk is running low: $($info.DiskFreeGB) GB free remaining. Consider clearing old screenshots or moving the storage path.[/]"` below the main table
       - After the table (and any warnings), build a dynamic choices array for `SelectionPrompt` with `'[[Back]]'` **first** (consistent with the existing pattern — `'[[Back to main menu]]'` is always first in `Show-ConfigMenuScreen`); the full choices construction:

         ```powershell
         $choices = @('[[Back]]', 'Configure screenshot settings')
         if ($info.IsConfigured) { $choices += 'Open screenshot folder in Explorer' }
         $prompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt('Options:', $choices)
         $selection = $prompt.Show($Console)
         ```

       - Dispatch via `switch ($selection)`:
         - `'Configure screenshot settings'` → `Show-ScreenshotConfigScreen -Console $Console`
         - `'Open screenshot folder in Explorer'` → `Start-Process -FilePath 'explorer.exe' -ArgumentList $storePath`; then display `$Console.Write([Spectre.Console.Markup]::new("[green]Opening storage folder in Explorer...`n[/]"))` (use `$Console.Write([Spectre.Console.Markup]::new(...))` — **not** `$Console.MarkupLine()` which does not exist in this project)
         - `default` → returns (handles `'[Back]'` — the single-bracket unescaped value returned by the prompt — and any unrecognised value; no explicit comparison against `'[[Back]]'` needed)
       - Update comment-based help; add `.NOTES` documenting that `'[[Back]]'` uses double brackets for Spectre display but the `switch default` branch handles the returned single-bracket value `'[Back]'`
    3. [ ] 11.3: Update `powershell-module/Tests/ConsoleApp/Get-StorageInfo.Tests.ps1`:
       - Add tests for new properties (all using `InModuleScope`):
         - `DiskFreeGB` and `DiskTotalGB` computed from mocked `[System.IO.DriveInfo]` (mock the constructor or use `Test-Path` of a real `TestDrive:\` path for drive info)
         - `ScreenshotCount` correct when mock `Get-ChildItem` returns 3 PNG files and 1 JPG file → `ScreenshotCount = 4`
         - `OldestScreenshotDate` and `NewestScreenshotDate` reflect `LastWriteTimeUtc` from mock `Get-ChildItem` results (provide files with known timestamps)
         - `StoragePath = ''` → `DiskFreeGB = 0.0`, `DiskTotalGB = 0.0`, `ScreenshotCount = 0`, `OldestScreenshotDate = $null`, `NewestScreenshotDate = $null`
         - `DriveInfo` constructor throws (e.g. UNC path) → `DiskFreeGB = 0.0`, `DiskTotalGB = 0.0`; no exception propagated to caller
       - All existing tests must continue to pass
       - Run full Pester suite; confirm count increases
    4. [ ] 11.4: Update `powershell-module/Tests/ConsoleApp/Show-StorageInfoScreen.Tests.ps1`:
       - Add tests (all using `InModuleScope`):
         - `$testConsole.Output` contains `'Disk space'` when `IsConfigured=$true`
         - `$testConsole.Output` contains the `ScreenshotCount` value
         - `$testConsole.Output` contains oldest/newest date strings when `ScreenshotCount > 0`
         - `$testConsole.Output` does NOT contain date strings when `ScreenshotCount = 0`
         - `DiskFreeGB < 5.0` → `$testConsole.Output` contains `'running low'`
         - `DiskFreeGB >= 5.0` → `$testConsole.Output` does NOT contain `'running low'`
         - `'[[Back]]'` option appears in `$testConsole.Output` as the first choice (confirm `$testConsole.Output` contains `'[Back]'` — the rendered unescaped text)
         - `'Open screenshot folder in Explorer'` option present when `IsConfigured=$true`
         - `'Open screenshot folder in Explorer'` NOT present when `IsConfigured=$false`
         - Selecting `'Open screenshot folder in Explorer'` → mock `Start-Process` verified called with `'explorer.exe'` and the correct path; `$testConsole.Output` contains `'Opening storage folder'`
         - Selecting `'Configure screenshot settings'` → `Should -Invoke Show-ScreenshotConfigScreen -Exactly 1`
       - All existing tests must continue to pass
       - Run full Pester suite; confirm count increases

12. [x] Update `Show-RunMacroScreen.ps1` with pre-flight screenshot check
    1. [x] 12.1: Update `powershell-module/Private/ConsoleApp/Show-RunMacroScreen.ps1` — insert a pre-flight check in Step 4 (after target window validation, before the confirm-and-execute `SelectionPrompt`):
       - Determine whether the macro contains at least one `Screenshot` action: `$hasScreenshots = @($macro.Data.sequence | Where-Object { $_.type -eq 'Screenshot' }).Count -gt 0`
       - If `$hasScreenshots -eq $true`:
         - Load current config via `Get-ModuleConfiguration`; check `$config.Screenshots.StoragePath`
         - If `$null` or empty string: display warning panel:

           ```
           "[yellow]This macro contains screenshot actions but no screenshot storage path is
           configured. Screenshots will be skipped during execution, and no files will be
           saved. Configure a storage path via Configure Module → Screenshot settings to
           enable screenshot capture.[/]"
           ```

         - Show `SelectionPrompt` with choices `'Continue (screenshots will be skipped)'` and `'Cancel'`
         - If `'Cancel'`: return to Step 1 (macro selection list) — do NOT return `$null` to the main menu
         - If `StoragePath` is configured and non-empty: continue silently (no panel shown)
       - No changes to Step 5 (confirm-and-execute) or any other existing logic
       - Update comment-based help to document the pre-flight check
    2. [x] 12.2: Update `powershell-module/Tests/ConsoleApp/Show-RunMacroScreen.Tests.ps1`:
       - **Macro has Screenshot actions, `StoragePath` empty → pre-flight warning:**
         - Mock `Get-MacroFile` returning a macro object with the shape `@{ Data = @{ metadata = @{ name = 'test-macro' }; sequence = @(@{ type = 'Screenshot'; region = @{ topLeft = @{ relativeX = 0.0; relativeY = 0.0 }; bottomRight = @{ relativeX = 1.0; relativeY = 1.0 } } }) } }` (this is the structure accessed via `$macro.Data.sequence` in `Show-RunMacroScreen`); mock `Get-ModuleConfiguration` returning `Screenshots.StoragePath = ''`; mock `Test-WindowHandleValid` returning `$true`
         - Verify `$testConsole.Output` contains `'screenshots will be skipped'`
       - **Pre-flight — user continues:**
         - Queue `'Continue (screenshots will be skipped)'` → `Invoke-MacroSequence` called
       - **Pre-flight — user cancels:**
         - Queue `'Cancel'` → `Invoke-MacroSequence` NOT called; user returned to macro selection list (function does not return `$null` immediately)
       - **Macro has Screenshot actions, `StoragePath` configured → no pre-flight warning:**
         - Mock `GetModuleConfiguration` returning `Screenshots.StoragePath = 'C:\Screenshots'`
         - `$testConsole.Output` does NOT contain `'screenshots will be skipped'`
       - **Macro has no Screenshot actions → no pre-flight check at all:**
         - Mock macro containing only `MoveToPoint` and `LeftClick` actions
         - `$testConsole.Output` does NOT contain `'screenshots will be skipped'` regardless of `StoragePath`
       - All existing tests must continue to pass without modification
       - Run full Pester suite; confirm count increases

13. [x] Run full Pester suite and validate
    1. [x] 13.1: Run the complete, unfiltered Pester suite (all files, no tag or name filters):
       - Record total test count; it must meet or exceed the Phase 4 final baseline plus all new tests added in tasks 1–12
       - All tests must pass with 0 failures and 0 errors
       - If any test fails that previously passed, halt immediately and investigate; do not proceed; do not delete or skip failing tests
    2. [x] 13.2: Manually smoke-test all screenshot workflows in a real terminal:
       - Import module; call `Start-LastWarAutoScreenshot`
       - **Config screen:** Navigate to `Configure module` → `Screenshot settings`; confirm `'[[Back to main menu]]'` is the first option in the config menu; select `Screenshot settings`; set `StoragePath` to `C:\Temp\TestScreenshots`; verify `FileFormat` selection shows `'PNG'` with the "Only PNG is supported in this release" note; set a custom `FilenamePattern` and verify the example filename is displayed; enable `SimilarityCheck` and confirm the info note appears; set `Threshold = 0.95`; set `ConsecutiveThreshold = 3`; save; close config; reopen `Screenshot settings` and verify all saved values are displayed including `ConsecutiveThreshold = 3`
       - **Pre-flight warning:** record a macro with at least one `Screenshot` action; clear `StoragePath` (set to empty); run the macro; confirm the pre-flight warning panel appears with the two choices; choose `'Cancel'`; verify you return to the macro list (not the main menu)
       - **Screenshot capture:** set a valid `StoragePath`; open Notepad or any windowed app; select it as the target window; run the macro; verify PNG files appear in the configured storage folder with filenames matching the configured pattern; verify correct region is captured (not the entire screen)
       - **Similarity detection:** enable `SimilarityCheck`, `Action = 'StopLoop'`; record a macro with a Loop action that captures screenshots; run the macro on a static window (nothing changing on screen); confirm the loop exits when the threshold is reached and the parent sequence continues; confirm the run result is reported as success with "Scroll end detected" message
       - **`StopMacro` action:** change `Action = 'StopMacro'`; run same macro; confirm the entire macro halts at similarity detection; confirm reported as success
       - **Storage info screen:** navigate to `Configure module` → `Storage & log file info`; verify screenshot count, disk free space, and file date range are displayed correctly; confirm `'Open screenshot folder in Explorer'` opens Windows Explorer; confirm `'Configure screenshot settings'` navigates to the screenshot config screen
       - **Storage limit:** set `MaxStorageGB` to `0.0001` (a tiny value below current usage); run macro; confirm storage-limit warning appears for each Screenshot action and screenshots are skipped without halting the rest of the macro; confirm the run is reported as a failure at the first non-skipped error
       - Confirm no ANSI artefacts or rendering glitches on any screen

14. [x] Documentation updates
    1. [x] 14.1: Update `powershell-module/Docs/README.md`:
       - Add "Screenshot Capture" section documenting:
         - Supported format: PNG (lossless; recommended for accuracy with similarity detection)
         - How to configure the storage path and maximum size (`Configure module` → `Screenshot settings`)
         - The filename pattern syntax with all supported placeholders and an annotated example: `{MacroName}_{ActionName}_{Timestamp}_{Index}` → `get-vs-scores_vs-screenshot-region_20260307_143022_0001.png`
         - Resolved filename length limit (200 characters before path prefix)
         - Requirement for the game window to be in windowed mode (not exclusive fullscreen) and non-minimised
         - How `PrintWindow(PW_RENDERFULLCONTENT)` captures OpenGL-rendered content via DWM composition
       - Add "Similarity Detection" section documenting:
         - Purpose: automatically detecting scroll-list end without OCR
         - How to enable (`SimilarityCheck.Enabled = true`) and configure in the config screen
         - What each `Action` value does:
           - `StopLoop` (default): exits the current loop, parent sequence continues — ideal for scroll loops
           - `StopMacro`: halts the entire macro — use when the screenshot is at the top level, not inside a loop
           - `Warn`: logs a warning and continues — useful for monitoring without stopping
         - Why `StopMacro` and `StopLoop` are reported as **success** (scroll end is the intended outcome)
         - `Threshold` is entered and stored as a decimal (0.0–1.0); `0.98` means 98% of sampled pixels match
         - `ConsecutiveThreshold`: how many consecutive similar screenshots must occur before the action fires; default `1` (first match); set higher (e.g. `3`) to avoid false positives on briefly static content
         - Sampling is deterministic (grid-based, not random) — results are reproducible across runs
       - Update "Running Macros" section: note that `Screenshot` actions require a configured `StoragePath`; pre-flight warning shown at run time if not configured
       - Update "Configuration" section: list all new `Screenshots.*` config keys with types, defaults, and plain-English descriptions
    2. [x] 14.2: Update `powershell-module/Docs/MacroFormat.md`:
       - Update the `Screenshot` action type row to reflect that capture is now **fully implemented** in Phase 5 (remove any "Phase 6 deferred" or "logs warning and skips" wording carried over from Phase 4)
       - Add a note: `Screenshot` actions require `Screenshots.StoragePath` to be configured; if unconfigured, the action is skipped with a `Warning` log during execution (non-fatal)
       - Add a "Screenshot Capture Behaviour" subsection: explain that `region.topLeft` and `region.bottomRight` are window-relative coordinates (0.0–1.0); the capture region is computed at execution time using the live window bounds; the full window is never captured — only the specified region
    3. [x] 14.3: Update `CLAUDE.md`:
       - Update the "Current status" line from "Phase 3 (Console App) complete. Phase 4 (Macro Recording) is next." to "Phase 4 (Macro Recording) complete. Phase 5 (Screenshot Management) is next."

## Phase 5b: Screenshot Region Masking

### Architecture decisions (future reference)

- **Mask regions as optional Screenshot action property:** `maskRegions` is an optional array on the `Screenshot` action type in the macro JSON schema. No new action type is introduced. Each element has `topLeft` and `bottomRight` with window-relative coordinates (0.0–1.0), identical in structure and coordinate space to the screenshot `region` property. If `maskRegions` is absent or an empty array, capture behaviour is unchanged.

- **Mask colour in module config:** A new `Screenshots.MaskColour` string key is added to the module configuration. Default value: `"0,0,0"` (pure black). The colour applies to all Screenshot steps in all macros — one global setting simplifies the configuration surface. It is validated and previewed in `Show-ScreenshotConfigScreen`. Parsed at execution time via `Resolve-MaskColour`.

- **Colour parsing:** New `Resolve-MaskColour` private function. Parsing is fully case-insensitive. Three input formats are accepted:
  1. **Named colour:** one of nine base names — `black`, `white`, `red`, `green`, `blue`, `yellow`, `pink`, `orange`, `purple` — optionally preceded by `light` or `dark` (space-separated). `light` and `dark` modifiers are not valid for `black` or `white`. The full set of recognised combinations is defined in the named colour table below.
  2. **RGB triplet:** three comma-separated integers each in the range 0–255, e.g. `"255,200,100"` or `"0,0,0"`. Whitespace around commas is ignored.
  3. **Six-character hex code:** exactly six hexadecimal characters (no leading `#`), e.g. `"FFAA55"` or `"ffffff"`.
  Returns `[System.Drawing.Color]` on success. Returns `$null` on any parse failure — the caller warns and falls back to black.

- **In-memory masking via new C# overload:** `ScreenCaptureAPI.CaptureWindowRegion` is extended with a new 8-parameter overload that accepts `System.Drawing.Rectangle[] maskPixelRects` and `System.Drawing.Color maskColour`. After `bmp.Clone()` produces the cropped region bitmap and before `region.Save()`, the method iterates `maskPixelRects`: for each rectangle with positive width and height it calls `Graphics.FillRectangle` with a `SolidBrush` of `maskColour`. The existing 6-parameter overload is preserved unchanged for backward compatibility and delegates to the 8-parameter overload with `Array.Empty<System.Drawing.Rectangle>()` and `System.Drawing.Color.Black`.

- **Overlap computation in PowerShell:** The conversion from window-relative mask coordinates to pixel-space `System.Drawing.Rectangle` objects within the cropped bitmap is performed in `Invoke-CaptureScreenRegion`, not in C#. `Get-WindowBounds` is called with the macro's window handle to obtain window pixel dimensions (already used by `Invoke-CaptureMousePosition`). This keeps the overlap logic in PowerShell where it is straightforwardly testable with Pester mocks, without requiring real GDI handles. The C# overload receives pre-computed pixel rectangles and simply paints them.

- **Recording flow extension:** During `Show-RecordMacroScreen`, after the screenshot region top-left and bottom-right have been captured and accepted, an immediate yes/no prompt asks `"Add a black-out region?"`. If yes, `Invoke-CaptureMousePosition` is called twice (same window handle, same `Accept / Redo / Cancel` pattern) to capture the mask top-left and bottom-right. After each mask region is successfully recorded, a second yes/no prompt asks `"Add another black-out region?"`. This loop repeats until the user declines. If the user selects `Cancel` during any mask region capture, that mask region is discarded and the loop exits — previously recorded mask regions are retained.

- **Validation at recording time:** The mask region bottom-right must be strictly to the right of and below its top-left (`bottomRight.relativeX > topLeft.relativeX` and `bottomRight.relativeY > topLeft.relativeY`) — the same rule enforced for screenshot regions. If a captured mask region has no overlap with the screenshot region (the two rectangles are disjoint), a warning panel is displayed (`"This black-out region does not overlap the screenshot region and will have no visible effect"`) but recording continues — the user may intend it as a placeholder for a region that moves during macro execution.

- **Step list display in recording screen:** Screenshot steps with one or more mask regions show the mask count appended to the region detail in the step table, e.g. `"0.10,0.15 → 0.90,0.85 | 2 mask(s)"`. Steps with no mask regions show the region coordinates only, unchanged from existing behaviour.

- **Testability:** `Resolve-MaskColour` is pure PowerShell with no I/O — fully unit-testable. Overlap computation in `Invoke-CaptureScreenRegion` is isolated from GDI calls by mocking `Get-WindowBounds` and `Invoke-CaptureWindowRegion`. The C# overload is tested by creating real `System.Drawing.Bitmap` objects in `TestDrive:\` without a real window handle, consistent with the existing `ScreenCaptureAPI.Tests.ps1` pattern.

### Phase 5b scope (what is and is not included)

**Included:** `Screenshots.MaskColour` config key (string, default `"0,0,0"`), `Resolve-MaskColour` private function (case-insensitive named colours with `light`/`dark` modifiers, RGB triplet, 6-char hex), `MacroSchema.ps1` extended to validate optional `maskRegions` array on Screenshot actions, `ScreenCaptureAPI.cs` extended with new 8-parameter `CaptureWindowRegion` overload (existing 6-parameter overload delegates unchanged), `Invoke-CaptureWindowRegion.ps1` updated with optional mask parameters, `Invoke-CaptureScreenRegion.ps1` updated (overlap computation, colour resolution, pass mask data to wrapper), `Show-RecordMacroScreen.ps1` updated (mask region recording loop, step display), `Show-ScreenshotConfigScreen.ps1` updated (`MaskColour` setting with live resolution preview), `MacroFormat.md` and `Configuration.md` updated, full Pester test coverage throughout.

**Explicitly out of scope:** Per-step mask colours (all steps share the global `MaskColour` config setting), visual overlay showing mask regions on the game window during recording, mask region editing after recording (reuse existing "edit macro step" flow — future enhancement), mask region deletion during recording (user must cancel and re-record the Screenshot step), JPEG/other format support, per-mask-region opacity (fill is always fully opaque).

---

### JSON schema extension

The `Screenshot` action type gains an optional `maskRegions` array. Existing macros without `maskRegions` are valid and continue to behave identically.

```json
{
    "name": "vs-score-screenshot-region",
    "type": "Screenshot",
    "region": {
        "topLeft":     { "relativeX": 0.10, "relativeY": 0.15 },
        "bottomRight": { "relativeX": 0.90, "relativeY": 0.85 }
    },
    "maskRegions": [
        {
            "topLeft":     { "relativeX": 0.30, "relativeY": 0.40 },
            "bottomRight": { "relativeX": 0.55, "relativeY": 0.50 }
        },
        {
            "topLeft":     { "relativeX": 0.60, "relativeY": 0.20 },
            "bottomRight": { "relativeX": 0.80, "relativeY": 0.35 }
        }
    ]
}
```

**`maskRegions` validation rules:**

- `maskRegions` is optional; if absent or `[]`, no masking is applied
- Maximum 10 elements per Screenshot action
- Each element must have `topLeft.relativeX`, `topLeft.relativeY`, `bottomRight.relativeX`, `bottomRight.relativeY` — all doubles in the range 0.0–1.0
- `bottomRight.relativeX` must be strictly greater than `topLeft.relativeX`
- `bottomRight.relativeY` must be strictly greater than `topLeft.relativeY`
- No overlap with the screenshot `region` is not a validation error (logged as `Verbose` during execution)

---

### Named colour reference table

The following 23 combinations are the complete set recognised by `Resolve-MaskColour`. All parsing is case-insensitive; any combination of upper/lower case and any number of spaces between modifier and name is normalised before lookup.

| Input name | R | G | B |
-----------------------------------
| `black` | 0 | 0 | 0 |
| `white` | 255 | 255 | 255 |
| `red` | 255 | 0 | 0 |
| `green` | 0 | 128 | 0 |
| `blue` | 0 | 0 | 255 |
| `yellow` | 255 | 255 | 0 |
| `pink` | 255 | 192 | 203 |
| `orange` | 255 | 165 | 0 |
| `purple` | 128 | 0 | 128 |
| `light red` | 255 | 128 | 128 |
| `light green` | 144 | 238 | 144 |
| `light blue` | 173 | 216 | 230 |
| `light yellow` | 255 | 255 | 224 |
| `light pink` | 255 | 218 | 238 |
| `light orange` | 255 | 210 | 150 |
| `light purple` | 221 | 160 | 221 |
| `dark red` | 139 | 0 | 0 |
| `dark green` | 0 | 100 | 0 |
| `dark blue` | 0 | 0 | 139 |
| `dark yellow` | 204 | 204 | 0 |
| `dark pink` | 220 | 100 | 130 |
| `dark orange` | 255 | 140 | 0 |
| `dark purple` | 75 | 0 | 130 |

---

### Tasks

1. [x] Extend macro JSON schema for `maskRegions`
   1. [x] 1.1: Update `Test-MacroAction` in `powershell-module/Private/MacroSchema.ps1` to validate the `maskRegions` property on Screenshot actions:
      - If `maskRegions` is present and not `$null`, assert it is an array (type check: `$action.maskRegions -is [System.Collections.IEnumerable]` and not a string)
      - Assert array length is between 0 and 10 inclusive; return error `"Screenshot action '$name': maskRegions must contain at most 10 entries"` if exceeded
      - For each element at index `$i`:
        - Assert `topLeft` and `bottomRight` sub-objects exist
        - Assert `topLeft.relativeX`, `topLeft.relativeY`, `bottomRight.relativeX`, `bottomRight.relativeY` are all present and in the range 0.0–1.0
        - Assert `bottomRight.relativeX -gt topLeft.relativeX`; return error `"Screenshot action '$name': maskRegions[$i].bottomRight.relativeX must be greater than topLeft.relativeX"`
        - Assert `bottomRight.relativeY -gt topLeft.relativeY`; return error `"Screenshot action '$name': maskRegions[$i].bottomRight.relativeY must be greater than topLeft.relativeY"`
      - A Screenshot action with no `maskRegions` key continues to pass validation unchanged
   2. [x] 1.2: Update the `$script:MacroActionTypes` hashtable entry for `'Screenshot'` in `MacroSchema.ps1` to document `maskRegions` as an optional property with its validation constraints (parallel to the existing `Required` / `Ranges` structure for other action types)
   3. [x] 1.3: Update `powershell-module/Tests/MacroSchema.Tests.ps1`:
      - Add test: Screenshot action with no `maskRegions` key → passes validation (regression guard)
      - Add test: Screenshot action with `maskRegions = []` (empty array) → passes validation
      - Add test: Screenshot action with one valid mask region → passes validation
      - Add test: Screenshot action with 10 valid mask regions (boundary maximum) → passes validation
      - Add test: Screenshot action with 11 mask regions → fails validation with expected message
      - Add test: mask region with `bottomRight.relativeX` equal to `topLeft.relativeX` → fails validation
      - Add test: mask region with `bottomRight.relativeY` less than `topLeft.relativeY` → fails validation
      - Add test: mask region with a coordinate outside 0.0–1.0 → fails validation
      - Add test: mask region missing `bottomRight` entirely → fails validation
      - Run full Pester suite; confirm count increases

2. [x] Add `Screenshots.MaskColour` to module config schema
   1. [x] 2.1: Update `powershell-module/Private/Get-DefaultModuleSettings.ps1`:
      - Add `MaskColour = '0,0,0'` to the existing `Screenshots` defaults hashtable, positioned after `FilenamePattern`
      - Add `'Screenshots.MaskColour'` to `$script:ConfigValidationSchema`:
        - Type: `string`
        - `Nullable = $false`
        - `Description = 'Colour used to fill screenshot black-out regions. Accepted formats: named colour (e.g. "red", "dark blue", "light green"), RGB triplet (e.g. "255,0,0"), or 6-character hex code (e.g. "FF0000"). Default: 0,0,0 (black)'`
   2. [x] 2.2: Update `powershell-module/Private/Get-ModuleConfiguration.ps1`:
      - No code change required — the existing `foreach ($key in $defaults.Screenshots.PSObject.Properties.Name)` loop already injects all missing Screenshots keys from defaults; adding MaskColour to defaults is sufficient.
   3. [x] 2.3: Update `powershell-module/Private/Save-ModuleConfiguration.ps1`:
      - No code change required — serialisation already round-trips the full Screenshots object via `ConvertTo-Json -Depth 5`.
   4. [x] 2.4: Update `powershell-module/Tests/ModuleConfiguration.Tests.ps1`:
      - Add round-trip save/load test for `Screenshots.MaskColour` with value `"FFAA55"`
      - Add default-injection test: load a config file whose `Screenshots` section does not contain `MaskColour`; verify `MaskColour` is injected as `"0,0,0"`
      - Run full Pester suite; confirm count increases

3. [x] Create `Resolve-MaskColour.ps1`
   1. [x] 3.1: Create `powershell-module/Private/Resolve-MaskColour.ps1`:
      - Function signature: `Resolve-MaskColour -ColourString [string]`
      - `[CmdletBinding()]` first; full comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER ColourString`, `.OUTPUTS`, `.EXAMPLE`)
      - Trim leading/trailing whitespace from `$ColourString` before all parsing
      - **Named colour parsing (attempt first):**
        - Normalise: convert to lowercase, collapse multiple spaces to a single space
        - Split on a single space: if two tokens, the first must be `'light'` or `'dark'` and the second a base colour name; if one token, it must be a base colour name; any other token count fails named parsing
        - Look up the normalised name in the static colour table (see named colour reference table above); if found, return `[System.Drawing.Color]::FromArgb($r, $g, $b)`
        - If `light` or `dark` modifier is used with `black` or `white`, return `$null` (write `Write-Warning "Colour modifier 'light'/'dark' is not valid for 'black' or 'white'"`)
      - **RGB triplet parsing (attempt second):**
        - Split on `,`; trim each token; assert exactly 3 tokens
        - Assert each token is a non-empty string of digits; parse with `[int]`
        - Assert each value is in range 0–255
        - If all checks pass, return `[System.Drawing.Color]::FromArgb($r, $g, $b)`
      - **Hex parsing (attempt third):**
        - Assert length is exactly 6 after trimming
        - Assert all characters are valid hex digits (`[0-9A-Fa-f]`)
        - Parse: `$r = [Convert]::ToInt32($hex.Substring(0,2), 16)` etc.
        - Return `[System.Drawing.Color]::FromArgb($r, $g, $b)`
      - **Failure:** if all three formats fail, write `Write-Warning "Cannot parse colour string '$ColourString'. Expected a named colour (e.g. 'red', 'dark blue'), RGB triplet (e.g. '255,0,0'), or 6-character hex code (e.g. 'FF0000')"` and return `$null`
      - All three format attempts are tried in the order listed; the function returns on the first successful parse
   2. [x] 3.2: Create `powershell-module/Tests/Resolve-MaskColour.Tests.ps1`:
      - Import module in `BeforeAll` (standard pattern); load `System.Drawing.Common` via `Add-Type -AssemblyName 'System.Drawing.Common'` in `BeforeAll`
      - All assertions inside `InModuleScope LastWarAutoScreenshot`
      - **Named colour tests** (use `-TestCases` / `-ForEach` with the full table from section above):
        - Each of the 23 named colours returns a `[System.Drawing.Color]` with the exact R, G, B values from the table
        - Case variations: `'Red'`, `'RED'`, `'rEd'`, `'DARK BLUE'`, `'LiGhT GreeN'` → each resolves correctly
        - Extra whitespace: `'  light red  '`, `'dark  blue'` → resolves correctly after normalisation
        - `'light black'` → returns `$null`, emits a warning
        - `'dark white'` → returns `$null`, emits a warning
        - `'magenta'` (unrecognised name) → returns `$null`
        - `'light magenta'` (unrecognised base) → returns `$null`
      - **RGB triplet tests:**
        - `'0,0,0'` → Color with R=0, G=0, B=0
        - `'255,255,255'` → Color with R=255, G=255, B=255
        - `'255,200,100'` → Color with R=255, G=200, B=100
        - `' 255 , 200 , 100 '` (whitespace around commas) → resolves correctly
        - `'256,0,0'` (out of range) → returns `$null`
        - `'-1,0,0'` (negative) → returns `$null`
        - `'255,255'` (only two components) → returns `$null`
        - `'255,255,255,0'` (four components) → returns `$null`
        - `'abc,0,0'` (non-numeric) → returns `$null`
      - **Hex tests:**
        - `'000000'` → Color with R=0, G=0, B=0
        - `'FFFFFF'` → Color with R=255, G=255, B=255
        - `'ffaa55'` (lowercase) → Color with R=255, G=170, B=85
        - `'FFAA55'` → same as above
        - `'FfAa55'` (mixed case) → same as above
        - `'FFAA5'` (5 chars) → returns `$null`
        - `'FFAA556'` (7 chars) → returns `$null`
        - `'GGAA55'` (invalid hex char) → returns `$null`
        - `'#FF0000'` (hash prefix not accepted) → returns `$null`
      - **Null/empty input:**
        - `$null` → returns `$null`
        - `''` → returns `$null`
        - `'   '` (whitespace only) → returns `$null`
      - Run full Pester suite; confirm count increases

4. [x] Extend `ScreenCaptureAPI.cs` with mask support
   1. [x] 4.1: Update `powershell-module/src/ScreenCaptureAPI.cs`:
      - Add `using System.Drawing;` and `using System.Drawing.Imaging;` to the existing `using` directives if not already present (both are already referenced for the existing `CaptureWindowRegion` implementation)
      - **Refactor existing `CaptureWindowRegion` (6-parameter) into a delegation wrapper:**
        - Retain the existing public 6-parameter signature unchanged (no breaking change to callers)
        - Change the body to a single delegation call:
          ```csharp
          return CaptureWindowRegion(windowHandle, relativeX, relativeY,
              relativeWidth, relativeHeight, outputPath,
              Array.Empty<Rectangle>(), Color.Black);
          ```
        - Retain the full existing XML doc comment unchanged
      - **Add new 8-parameter `CaptureWindowRegion` overload** — full XML doc comment required:
        ```csharp
        public static bool CaptureWindowRegion(
            IntPtr windowHandle,
            double relativeX,    double relativeY,
            double relativeWidth, double relativeHeight,
            string outputPath,
            System.Drawing.Rectangle[] maskPixelRects,
            System.Drawing.Color maskColour)
        ```
        - Move all existing implementation logic (validation, `GetWindowRect`, DC creation, `PrintWindow`, `bmp.Clone`, save, `finally` GDI cleanup) into this overload
        - After the `bmp.Clone(...)` call that produces the `region` bitmap and before `region.Save(...)`, insert the masking block:
          ```csharp
          if (maskPixelRects != null && maskPixelRects.Length > 0)
          {
              using (var g = Graphics.FromImage(region))
              using (var brush = new SolidBrush(maskColour))
              {
                  foreach (var rect in maskPixelRects)
                  {
                      if (rect.Width > 0 && rect.Height > 0)
                          g.FillRectangle(brush, rect);
                  }
              }
          }
          ```
        - All existing GDI object disposal in `finally` is unchanged
        - XML `.remarks` on the new overload: "Mask pixel rectangles must be pre-computed by the caller in the coordinate space of the cropped bitmap (origin at the top-left of the capture region). Rectangles extending outside the bitmap bounds are clipped silently by GDI+. Pass an empty array or `null` for `maskPixelRects` to skip masking."
   2. [x] 4.2: Update `powershell-module/Tests/ScreenCaptureAPI.Tests.ps1`:
      - Add type verification: `CaptureWindowRegion` static method with 8 parameters exists (`IntPtr`, `double`, `double`, `double`, `double`, `string`, `System.Drawing.Rectangle[]`, `System.Drawing.Color`)
      - **Masking integration tests** using real bitmaps written to `TestDrive:\`:
        - Create a 100×100 white bitmap, save as `TestDrive:\source.png`. Pass it through `CaptureWindowRegion` indirectly by verifying the internal masking logic via a helper: create a 100×100 white `Bitmap`, call the new overload with `windowHandle = [IntPtr]::Zero` — this will fail parameter validation and return `$false`. Instead, test masking by calling `Invoke-CaptureWindowRegion` with mock (see Task 5.2) or by testing the C# logic via a dedicated test bitmap approach below.
        - **Direct bitmap masking test:** After confirming the new overload validates `maskPixelRects` and `maskColour` are accepted, verify paint logic by creating a 200×200 all-white PNG in `TestDrive:\`, then loading it as a `Bitmap`, applying `Graphics.FillRectangle` manually with a known `SolidBrush`, and asserting pixel colour at known coordinates — this validates the System.Drawing APIs behave as expected on this machine (infrastructure smoke test)
        - **Parameter validation for new overload** (no real HWND needed — validation fires before P/Invoke):
          - `maskPixelRects = $null` with valid other params → returns `$false` (invalid window handle fires first; confirm `$false` is returned)
          - `maskPixelRects = @()` (empty array) → same early-exit behaviour (validation still fails on `IntPtr.Zero`)
          - Note: the masking paint path can only be exercised with a real HWND; these tests verify the method accepts the parameter types correctly and that validation behaviour is unaffected
      - Run full Pester suite; confirm count increases

5. [x] Update `Invoke-CaptureWindowRegion.ps1`
   1. [x] 5.1: Update `powershell-module/Private/Invoke-CaptureWindowRegion.ps1`:
      - Add two optional parameters after the existing `$OutputPath` parameter:
        ```powershell
        [System.Drawing.Rectangle[]]$MaskPixelRects = @(),
        [System.Drawing.Color]$MaskColour = [System.Drawing.Color]::Black
        ```
      - Update the function body from the existing one-liner to pass the two new parameters through to the C# overload:
        ```powershell
        return [LastWarAutoScreenshot.ScreenCaptureAPI]::CaptureWindowRegion(
            $WindowHandle, $RelativeX, $RelativeY, $RelativeWidth, $RelativeHeight,
            $OutputPath, $MaskPixelRects, $MaskColour)
        ```
      - Existing callers that omit the new parameters continue to work — the defaults (`@()` and `Color.Black`) match the behaviour of the original 6-parameter C# overload
      - Update comment-based help: add `.PARAMETER MaskPixelRects` and `.PARAMETER MaskColour` entries
   2. [x] 5.2: Update `powershell-module/Tests/ScreenCaptureAPI.Tests.ps1` (the existing smoke-test section from Phase 5 task 2.3.3):
      - Add assertion: `Invoke-CaptureWindowRegion` command has `MaskPixelRects` and `MaskColour` parameters (use `(Get-Command Invoke-CaptureWindowRegion).Parameters` inside `InModuleScope`)
      - Add assertion: calling `Invoke-CaptureWindowRegion` with the two new optional parameters omitted does not throw (mock `[LastWarAutoScreenshot.ScreenCaptureAPI]::CaptureWindowRegion` static call is not possible with Pester — test via module function signature only)
      - Run full Pester suite; confirm count increases

6. [x] Update `Invoke-CaptureScreenRegion.ps1` — overlap computation and mask application
   1. [x] 6.1: Update `powershell-module/Private/Invoke-CaptureScreenRegion.ps1`:
      - Add `System.Drawing.Common` is already loaded by the module at import time (via `psm1`) — no additional `Add-Type` call needed here
      - After validating the screenshot action and before calling `Invoke-CaptureWindowRegion`, add the mask preparation block:
        ```powershell
        # Compute pixel-space mask rectangles from window-relative maskRegions
        $maskPixelRects = [System.Drawing.Rectangle[]]@()
        $maskColour     = [System.Drawing.Color]::Black

        if ($action.maskRegions -and $action.maskRegions.Count -gt 0) {
            $resolvedColour = Resolve-MaskColour -ColourString $config.Screenshots.MaskColour
            if ($null -eq $resolvedColour) {
                Write-Warning "MaskColour '$($config.Screenshots.MaskColour)' could not be parsed — using black."
                $resolvedColour = [System.Drawing.Color]::Black
            }
            $maskColour = $resolvedColour

            $windowBounds = Get-WindowBounds -WindowHandle $WindowHandle
            $ssLeft   = $action.region.topLeft.relativeX
            $ssTop    = $action.region.topLeft.relativeY
            $ssRight  = $action.region.bottomRight.relativeX
            $ssBottom = $action.region.bottomRight.relativeY
            $ssWidth  = $ssRight  - $ssLeft
            $ssHeight = $ssBottom - $ssTop
            $bmpWidth  = [int]($ssWidth  * $windowBounds.Width)
            $bmpHeight = [int]($ssHeight * $windowBounds.Height)

            $rectList = [System.Collections.Generic.List[System.Drawing.Rectangle]]::new()
            foreach ($maskRegion in $action.maskRegions) {
                $mLeft   = $maskRegion.topLeft.relativeX
                $mTop    = $maskRegion.topLeft.relativeY
                $mRight  = $maskRegion.bottomRight.relativeX
                $mBottom = $maskRegion.bottomRight.relativeY

                $overlapLeft   = [Math]::Max($ssLeft,   $mLeft)
                $overlapTop    = [Math]::Max($ssTop,    $mTop)
                $overlapRight  = [Math]::Min($ssRight,  $mRight)
                $overlapBottom = [Math]::Min($ssBottom, $mBottom)

                if ($overlapLeft -ge $overlapRight -or $overlapTop -ge $overlapBottom) {
                    Write-Verbose "Mask region has no overlap with screenshot region — skipping."
                    continue
                }

                $pixelX = [int](($overlapLeft   - $ssLeft) / $ssWidth  * $bmpWidth)
                $pixelY = [int](($overlapTop    - $ssTop)  / $ssHeight * $bmpHeight)
                $pixelW = [int](($overlapRight  - $overlapLeft) / $ssWidth  * $bmpWidth)
                $pixelH = [int](($overlapBottom - $overlapTop)  / $ssHeight * $bmpHeight)

                if ($pixelW -gt 0 -and $pixelH -gt 0) {
                    $rectList.Add([System.Drawing.Rectangle]::new($pixelX, $pixelY, $pixelW, $pixelH))
                }
            }
            $maskPixelRects = $rectList.ToArray()
        }
        ```
      - Update the `Invoke-CaptureWindowRegion` call to pass `$maskPixelRects` and `$maskColour`:
        ```powershell
        $captureSuccess = Invoke-CaptureWindowRegion `
            -WindowHandle   $WindowHandle `
            -RelativeX      $relativeX `
            -RelativeY      $relativeY `
            -RelativeWidth  $relativeWidth `
            -RelativeHeight $relativeHeight `
            -OutputPath     $outputPath `
            -MaskPixelRects $maskPixelRects `
            -MaskColour     $maskColour
        ```
      - No changes to the similarity detection, storage guard, filename resolution, or any other existing logic
   2. [x] 6.2: Update `powershell-module/Tests/Invoke-CaptureScreenRegion.Tests.ps1`:
      - Add `BeforeEach` mock for `Get-WindowBounds` returning a fixed-size bounds object (e.g. Width=1000, Height=2000) for mask-related tests
      - Add `BeforeEach` mock for `Resolve-MaskColour` returning a fixed `[System.Drawing.Color]::Red` for mask-related tests
      - Add `BeforeEach` mock for `Invoke-CaptureWindowRegion` capturing its arguments for assertion
      - **Mask rectangle computation tests:**
        - Screenshot region `(0.1, 0.1) → (0.9, 0.9)` with one mask region `(0.2, 0.2) → (0.5, 0.5)` (fully inside screenshot): assert `Invoke-CaptureWindowRegion` is called with one `Rectangle` at the correct pixel coordinates (verify `X`, `Y`, `Width`, `Height` against manually computed expected values)
        - Mask region identical to screenshot region: assert one rectangle covering the full bitmap (X=0, Y=0, Width=bmpWidth, Height=bmpHeight)
        - Mask region partially overlapping (extends outside screenshot boundary on right and bottom): assert rectangle is clipped to the overlapping portion only
        - Mask region entirely outside screenshot region: assert `Invoke-CaptureWindowRegion` is called with zero rectangles (empty array)
        - Two mask regions both valid: assert `Invoke-CaptureWindowRegion` is called with two `Rectangle` objects
        - Screenshot action with no `maskRegions` property: assert `Invoke-CaptureWindowRegion` is called with an empty `Rectangle` array
        - Screenshot action with `maskRegions = @()` (empty): assert `Invoke-CaptureWindowRegion` is called with an empty `Rectangle` array
      - **Colour resolution tests:**
        - `config.Screenshots.MaskColour = '255,0,0'` → `Resolve-MaskColour` called with `'255,0,0'`; `Invoke-CaptureWindowRegion` called with the returned `Color`
        - `Resolve-MaskColour` returns `$null` (simulating unparseable config value) → `Invoke-CaptureWindowRegion` called with `[System.Drawing.Color]::Black` (fallback); warning emitted
      - Run full Pester suite; confirm count increases

7. [x] Update `Show-RecordMacroScreen.ps1` — mask region recording flow and display
   1. [x] 7.1: Update the Screenshot action recording branch in `powershell-module/Private/ConsoleApp/Show-RecordMacroScreen.ps1`:
      - After the screenshot region bottom-right is accepted (the existing two-point capture with validation), add the mask recording loop:
        ```powershell
        $maskRegions = [System.Collections.Generic.List[object]]::new()
        $addMask = Invoke-YesNoPrompt -Console $Console -Message 'Add a black-out region to this screenshot?'
        while ($addMask) {
            # Capture mask top-left
            $Console.Write([Spectre.Console.Markup]::new('[grey]Move mouse to the top-left corner of the black-out region, then press Enter.[/]'))
            $maskTopLeft = Invoke-CaptureMousePosition -Console $Console -WindowHandle $WindowHandle
            if ($null -eq $maskTopLeft) { break }  # user cancelled

            # Capture mask bottom-right
            $Console.Write([Spectre.Console.Markup]::new('[grey]Move mouse to the bottom-right corner of the black-out region, then press Enter.[/]'))
            $maskBottomRight = Invoke-CaptureMousePosition -Console $Console -WindowHandle $WindowHandle
            if ($null -eq $maskBottomRight) { break }  # user cancelled

            # Validate mask region (bottom-right must be strictly below and to the right of top-left)
            if ($maskBottomRight.RelativeX -le $maskTopLeft.RelativeX -or
                $maskBottomRight.RelativeY -le $maskTopLeft.RelativeY) {
                $Console.Write([Spectre.Console.Markup]::new('[red]Bottom-right corner must be below and to the right of the top-left corner. Black-out region not added.[/]'))
            } else {
                # Check for overlap with screenshot region and warn if none
                $overlapExists = ($maskTopLeft.RelativeX  -lt $screenshotBottomRight.RelativeX) -and
                                 ($maskBottomRight.RelativeX -gt $screenshotTopLeft.RelativeX)  -and
                                 ($maskTopLeft.RelativeY  -lt $screenshotBottomRight.RelativeY) -and
                                 ($maskBottomRight.RelativeY -gt $screenshotTopLeft.RelativeY)
                if (-not $overlapExists) {
                    $Console.Write([Spectre.Console.Markup]::new('[yellow]Warning: this black-out region does not overlap the screenshot region and will have no visible effect.[/]'))
                }
                $maskRegions.Add([PSCustomObject]@{
                    topLeft     = [PSCustomObject]@{ relativeX = $maskTopLeft.RelativeX;     relativeY = $maskTopLeft.RelativeY }
                    bottomRight = [PSCustomObject]@{ relativeX = $maskBottomRight.RelativeX; relativeY = $maskBottomRight.RelativeY }
                })
            }

            $addMask = Invoke-YesNoPrompt -Console $Console -Message 'Add another black-out region?'
        }
        ```
      - Construct the Screenshot action object: if `$maskRegions.Count -gt 0`, include the `maskRegions` property; otherwise omit it (keeping the JSON clean for steps without masks):
        ```powershell
        $action = [PSCustomObject]@{ type = 'Screenshot'; region = $region }
        if ($maskRegions.Count -gt 0) {
            $action | Add-Member -NotePropertyName maskRegions -NotePropertyValue $maskRegions.ToArray()
        }
        ```
      - Note: `Invoke-YesNoPrompt` is assumed to be an existing or new private helper that displays a yes/no selection prompt via `CreateSelectionPrompt` and returns `$true` / `$false`. If it does not already exist, create it as a private function `Invoke-YesNoPrompt -Console [IAnsiConsole] -Message [string]` using `ConsoleAppBridge::CreateSelectionPrompt` with choices `@('Yes', 'No')` and returning `$true` for `'Yes'`.
   2. [x] 7.2: Update the step detail rendering in `Show-RecordMacroScreen.ps1` for Screenshot actions in the step table:
      - Locate the existing logic that formats Screenshot action details for the step list display
      - If the action has `maskRegions` with `Count -gt 0`, append `" | $($action.maskRegions.Count) mask(s)"` to the region coordinate string
      - Example final display: `"0.10,0.15 → 0.90,0.85 | 2 mask(s)"` vs. `"0.10,0.15 → 0.90,0.85"` (no masks)
   3. [x] 7.3: Update `powershell-module/Tests/ConsoleApp/Show-RecordMacroScreen.Tests.ps1`:
      - Add test: when user responds `'No'` to `"Add a black-out region?"`, the resulting Screenshot action has no `maskRegions` property
      - Add test: when user adds one mask region and responds `'No'` to `"Add another black-out region?"`, the resulting action has `maskRegions` with one element containing the correct coordinates
      - Add test: when user adds two mask regions, the action has `maskRegions` with two elements
      - Add test: when user cancels (`$null` returned from `Invoke-CaptureMousePosition`) during mask top-left capture, no mask region is added and the loop exits cleanly
      - Add test: when captured mask region has `bottomRight.relativeX <= topLeft.relativeX`, a warning markup is written and no mask region is added
      - Add test: when mask region has no overlap with screenshot region, the no-overlap warning markup is written but the mask region IS still added to the action
      - Add test: step detail for a Screenshot action with two mask regions contains `"2 mask(s)"`
      - Add test: step detail for a Screenshot action with no `maskRegions` property does not contain `"mask"`
      - Run full Pester suite; confirm count increases

8. [x] Update `Show-ScreenshotConfigScreen.ps1` — `MaskColour` setting
   1. [x] 8.1: Update `powershell-module/Private/ConsoleApp/Show-ScreenshotConfigScreen.ps1`:
      - Add a `MaskColour` menu entry to the screenshot configuration options list (position: after the `FilenamePattern` entry, before any `SimilarityCheck` entries, consistent with config key order)
      - When the user selects `MaskColour`:
        - Display the current value (e.g. `"Current mask colour: 0,0,0"`)
        - Prompt for a new value using a `TextPrompt` (free-text entry) with the current value as the default suggestion
        - On input, call `Resolve-MaskColour -ColourString $input` to validate
        - If `Resolve-MaskColour` returns `$null`, display an error panel: `"Invalid colour: '$input'. Enter a named colour (e.g. 'red', 'dark blue', 'light green'), an RGB triplet (e.g. '255,0,0'), or a 6-character hex code (e.g. 'FF0000')."` — do not update the config
        - If `Resolve-MaskColour` returns a valid `[System.Drawing.Color]`, display a confirmation: `"Colour resolved: RGB($($colour.R), $($colour.G), $($colour.B))"` — save the raw input string (not the resolved RGB) to `config.Screenshots.MaskColour`, then persist via `Save-ModuleConfiguration`
      - The confirmation display shows the resolved RGB so the user can verify the result matches their intent (especially useful for named colours and hex inputs)
   2. [x] 8.2: Update `powershell-module/Tests/ConsoleApp/Show-ScreenshotConfigScreen.Tests.ps1`:
      - Add test: `MaskColour` option appears in the configuration menu
      - Add test: selecting `MaskColour` and entering `'red'` → `Resolve-MaskColour` is called with `'red'`; resolved confirmation markup is written; `Save-ModuleConfiguration` is called with `MaskColour = 'red'`
      - Add test: selecting `MaskColour` and entering an invalid string → error panel markup is written; `Save-ModuleConfiguration` is NOT called
      - Add test: entering a valid hex code `'FFAA55'` → confirmation shows `"RGB(255, 170, 85)"`; config is saved with `MaskColour = 'FFAA55'`
      - Run full Pester suite; confirm count increases

9. [x] Update documentation
   1. [x] 9.1: Update `powershell-module/Docs/MacroFormat.md`:
      - Add `maskRegions` to the Screenshot action type documentation:
        - Show the updated JSON example (matching the schema extension section above) with one mask region
        - Document the optional `maskRegions` array: purpose, coordinate space, maximum count (10), validation rules
        - Note that `maskRegions` coordinates are in the same window-relative space as all other coordinates in the macro
        - Note that the fill colour is controlled by `Screenshots.MaskColour` in module configuration
      - Update the action type reference table to show `maskRegions` as an optional property of `Screenshot`
   2. [x] 9.2: Update `powershell-module/Docs/Configuration.md`:
      - Add `Screenshots.MaskColour` to the `Screenshots` section:
        - Default value: `"0,0,0"`
        - Accepted formats: named colour, RGB triplet, 6-char hex (reference the named colour table)
        - Where configured: `Show-ScreenshotConfigScreen` → `MaskColour` option

## Phase 6: Configuration & Scheduling

### Architecture decisions (future reference)

- **LWAS noun prefix for public functions:** All exported (public) functions gain the `LWAS` prefix
  on the noun portion of the `Verb-Noun` name, e.g. `Stop-EmergencyStopMonitor` →
  `Stop-LWASEmergencyStopMonitor`. This follows PowerShell module best practice for preventing
  name collisions in the global scope. No backwards-compatibility aliases are created (the module
  is not yet in production use). Every rename requires: file rename, function declaration rename,
  all internal callers updated, all test files updated, and `FunctionsToExport` updated in
  `LastWarAutoScreenshot.psd1` — all in the same task.

- **`Start-EmergencyStopMonitor` rename is a distinct sub-task:** Several console screens call
  `Start-EmergencyStopMonitor` internally. All callers must be updated in the same sub-task as
  the rename — not as an afterthought — to keep the suite green between sub-tasks.

- **Scheduled task format — Option B (launcher `.ps1` scripts):**
  `Register-LWASScheduledTask` generates a dedicated launcher `.ps1` file (e.g.
  `$env:APPDATA\LastWarAutoScreenshot\Schedulers\LWAS_<macroName>.ps1`) and creates a Windows
  Scheduled Task whose action runs `pwsh.exe -NonInteractive -File <launcherPath>`. The launcher
  script contains the module import and the `Get-LWASTargetWindow | Start-LWASAutomationSequence`
  pipeline invocation. `Unregister-LWASScheduledTask` removes both the task entry and its
  launcher script. Alternative (Option A — embedding the full command directly in the task action)
  is rejected: task action arguments have a ~2,000-character limit, are unreadable and
  undebuggable. Option B is the industry-standard approach for complex PowerShell scheduled tasks
  and the cleanup requirement is straightforward to implement.

- **`Get-LWASTargetWindow` return behaviour:** Returns all windows matching the specified
  filter(s) by default. An optional `-First` switch caps the output to the single best match
  (the first result in the order returned by `Get-EnumeratedWindows`). `-First` is the expected
  usage for scheduled tasks where exactly one game window is anticipated. Without `-First` all
  matches are piped to `Start-LWASAutomationSequence`, which runs the macro against each in turn.
  If no windows match, `Write-Error` is called (non-terminating) and nothing is written to the
  pipeline. If a matched window is minimised, `Write-Warning` is emitted but the object is
  **still written to the pipeline** — `Start-LWASAutomationSequence` is the function that handles
  restoration.

- **Window restoration:** `Start-LWASAutomationSequence` detects a minimised window using the
  existing `[LastWarAutoScreenshot.WindowEnumerationAPI]::IsIconic()` and restores it with
  `ShowWindow(SW_RESTORE = 9)`. The constant `SW_RESTORE = 9` is added to the existing C#
  constants in `WindowEnumerationAPI.cs`. `Set-WindowState` (`Private/Set-WindowState.ps1`) is
  extended to accept `'Restore'` as a valid `-State` value alongside the existing `'Minimise'`
  and `'Maximise'`. Extending the existing function is preferred over creating a new helper
  because it keeps all `ShowWindow` logic in one place; the Phase 1 constraint ("only min/max")
  was a scope constraint, not an architectural one. After calling `ShowWindow(SW_RESTORE)` a
  configurable delay is applied before the macro starts (`MacroExecution.WindowRestoreDelayMs`,
  default `500`). This is stored in the module configuration (not hard-coded) so it can be tuned
  for slow machines or time-sensitive macros without a code change. A console config UI for the
  `MacroExecution` section is deferred to Phase 10; for Phase 6 the value is set via the
  config JSON or `Get-ModuleConfiguration` / `Save-ModuleConfiguration` at the command line.

- **Scheduled task execution context:** Tasks are created with `-RunLevel Limited`
  (non-elevated) and run as the currently logged-on user. The task only runs when the user is
  logged on, which is required for window interaction. Running as SYSTEM is not supported because
  the game window belongs to the interactive user session.

- **`Register-LWASScheduledTask` is the single source of truth for task creation:**
  `Show-ScheduleScreen` collects user input interactively and delegates entirely to
  `Register-LWASScheduledTask`. This matches the established project pattern — every console
  screen calls the underlying cmdlet, it does not duplicate the logic.

- **Emergency stop monitor in scheduled/unattended execution:** `Start-LWASAutomationSequence`
  reads `EmergencyStop.AutoStart` from config and starts the monitor if `$true`, consistent with
  the original `Start-AutomationSequence` behaviour. For scheduled unattended runs the hotkey
  monitor runs but is rarely triggered; users who prefer to disable it for automated runs can set
  `EmergencyStop.AutoStart = $false` in module configuration.

- **`Show-StorageInfoScreen` moved to top-level main menu:** The screen moves from
  Configure Module → Storage & log file info to a dedicated top-level menu option `'Storage info'`
  (identifier `'StorageInfo'`). `Show-ConfigMenuScreen` loses its `'Storage & log file info'`
  option. No changes to `Show-StorageInfoScreen` itself are required.

### Phase 6 scope (what is and is not included)

**Included:** LWAS noun-prefix rename for all five existing public functions, with all callers
and tests updated in the same sub-task; `Start-LWASEmergencyStopMonitor` rename called out as an
explicit sub-task with caller audit; `FunctionsToExport` updated in every rename sub-task; `CLAUDE.md`
updated to reflect `Start-LWASConsole` as the new entry point; `Show-StorageInfoScreen` moved to
the top-level main menu; `Get-LWASTargetWindow` (new public, pipeline-compatible, emits warning
for minimised windows); `Get-LWASMacro` (new public, optional `-Name` filter, full macro data
returned including complete `Sequence` array, `Write-Error` (non-terminating) on name not found);
`Start-LWASAutomationSequence` (new public, pipeline input from `Get-LWASTargetWindow`,
minimised-window restoration via `Set-WindowState -State Restore`); `SW_RESTORE` Win32 constant
and `Set-WindowState 'Restore'` state; `Register-LWASScheduledTask`, `Unregister-LWASScheduledTask`,
`Get-LWASScheduledTask` (new public cmdlets); `New-LWASLauncherScript` (new private helper);
`Show-ScheduleScreen` (new console screen integrated into main menu); launcher script generation
and cleanup on unregister; full Pester coverage for all new and renamed functions.

**Explicitly out of scope:** Multi-user or service-account scheduled execution; GUI-based
schedule management outside the console app; YAML export of macro schedules; per-task logging
configuration (tasks use the module's default log settings); task history archival in module
config; notifications (email/toast) on task failure.

### Windows Scheduled Task naming convention

All tasks created by this module use the task name `LWAS_<macroName>`, e.g. `LWAS_get-vs-scores`.
Task names are unique per macro name. Re-registering a task for an existing macro name overwrites
the previous registration via `-Force` on `Register-ScheduledTask`. The corresponding launcher
script lives at `$env:APPDATA\LastWarAutoScreenshot\Schedulers\LWAS_<macroName>.ps1`.

---

### Tasks

1. [x] Rename public functions to LWAS noun prefix and update all references

   **(1) Rename `Start-LastWarAutoScreenshot` → `Start-LWASConsole`**
   - [x] 1.1.1: Rename `powershell-module/Public/Start-LastWarAutoScreenshot.ps1` to
     `Start-LWASConsole.ps1`; update the function declaration from
     `function Start-LastWarAutoScreenshot` to `function Start-LWASConsole`
   - [x] 1.1.2: Search all `.ps1` files for `Start-LastWarAutoScreenshot`; update every call site
   - [x] 1.1.3: Rename `Tests/ConsoleApp/Start-LastWarAutoScreenshot.Tests.ps1` to
     `Start-LWASConsole.Tests.ps1`; replace every reference to `Start-LastWarAutoScreenshot`
     with `Start-LWASConsole`
   - [x] 1.1.4: Update `FunctionsToExport` in `LastWarAutoScreenshot.psd1`: replace
     `'Start-LastWarAutoScreenshot'` with `'Start-LWASConsole'`
   - [x] 1.1.5: Update `CLAUDE.md`: replace `Start-LastWarAutoScreenshot` with `Start-LWASConsole`
     in the entry-point documentation and example commands; update **Current status** line to
     `Phase 6 (Configuration & Scheduling)`
   - [x] 1.1.6: Run full Pester suite; confirm 0 failures and count meets or exceeds pre-task baseline

   **(2) Rename `Start-EmergencyStopMonitor` → `Start-LWASEmergencyStopMonitor`**
   - [x] 1.2.1: Rename `powershell-module/Public/Start-EmergencyStopMonitor.ps1` to
     `Start-LWASEmergencyStopMonitor.ps1`; update the function declaration
   - [x] 1.2.2: Audit all callers — search the entire `Private/` tree (including
     `Private/ConsoleApp/`) for `Start-EmergencyStopMonitor`; update every call site (likely
     callers include `Private/ConsoleApp/Show-EmergencyStopConfigScreen.ps1` and the macro
     execution pipeline)
   - [x] 1.2.3: Update every test file that references `Start-EmergencyStopMonitor` directly
     (mocks, `Should -Invoke`, `InModuleScope` calls); check `Tests/EmergencyStop.Tests.ps1` and
     all `Tests/ConsoleApp/` files
   - [x] 1.2.4: Update `FunctionsToExport` in `LastWarAutoScreenshot.psd1`
   - [x] 1.2.5: Run full Pester suite; confirm 0 failures

   **(3) Rename `Stop-EmergencyStopMonitor` → `Stop-LWASEmergencyStopMonitor`**
   - [x] 1.3.1: Rename `powershell-module/Public/Stop-EmergencyStopMonitor.ps1` to
     `Stop-LWASEmergencyStopMonitor.ps1`; update the function declaration
   - [x] 1.3.2: Audit all callers — search all `.ps1` files for `Stop-EmergencyStopMonitor`;
     update every call site
   - [x] 1.3.3: Update all test files referencing `Stop-EmergencyStopMonitor`
   - [x] 1.3.4: Update `FunctionsToExport` in `LastWarAutoScreenshot.psd1`
   - [x] 1.3.5: Run full Pester suite; confirm 0 failures

   **(4) Rename `Get-MonitorProcess` → `Get-LWASMonitorProcess`**
   - [x] 1.4.1: Rename `powershell-module/Public/Get-MonitorProcess.ps1` to
     `Get-LWASMonitorProcess.ps1`; update the function declaration
   - [x] 1.4.2: Search all files for `Get-MonitorProcess`; update every call site
   - [x] 1.4.3: Update all test files referencing `Get-MonitorProcess`
   - [x] 1.4.4: Update `FunctionsToExport` in `LastWarAutoScreenshot.psd1`
   - [x] 1.4.5: Run full Pester suite; confirm 0 failures

   **(5) Rename `Install-LastWarAutoScreenshot` → `Install-LWASModule`**
   - [x] 1.5.1: Rename `powershell-module/Public/Install-LastWarAutoScreenshot.ps1` to
     `Install-LWASModule.ps1`; update the function declaration
   - [x] 1.5.2: Search all files for `Install-LastWarAutoScreenshot`; update every call site
     and any documentation references
   - [x] 1.5.3: Update all test files referencing `Install-LastWarAutoScreenshot`
   - [x] 1.5.4: Update `FunctionsToExport` in `LastWarAutoScreenshot.psd1`
   - [x] 1.5.5: Run full Pester suite; confirm 0 failures

   **(6) Verify final manifest state after all renames**
   - [x] 1.6.1: Confirm `FunctionsToExport` in `LastWarAutoScreenshot.psd1` now contains exactly:
     `'Start-LWASConsole'`, `'Start-LWASEmergencyStopMonitor'`, `'Stop-LWASEmergencyStopMonitor'`,
     `'Get-LWASMonitorProcess'`, `'Install-LWASModule'` (new functions are added in tasks 3–7)
   - [x] 1.6.2: Run `Import-Module .\powershell-module\LastWarAutoScreenshot.psd1 -Force`;
     verify `Get-Command -Module LastWarAutoScreenshot` lists only the new names, not the old ones
   - [x] 1.6.3: Run the full Pester suite; confirm 0 failures and count meets or exceeds the
     pre-task-1 baseline

2. [x] Move `Show-StorageInfoScreen` from config sub-menu to top-level main menu

   - [x] 2.1: Update `powershell-module/Private/ConsoleApp/Show-MainMenu.ps1`:
     - Add `'Storage info'` as a selectable option (position: after `'Manage macros'`, before
       `'Exit'`)
     - Return the identifier `'StorageInfo'` when selected
     - Update comment-based help (`.SYNOPSIS`, `.DESCRIPTION`) to list the new option
   - [x] 2.2: Update `powershell-module/Public/Start-LWASConsole.ps1` (renamed in task 1):
     - Add `'StorageInfo'` case to the `switch` block; dispatch to
       `Show-StorageInfoScreen -Console $Console` wrapped in `RunInAlternateScreen`
   - [x] 2.3: Update `powershell-module/Private/ConsoleApp/Show-ConfigMenuScreen.ps1`:
     - Remove the `'Storage & log file info'` choice from the `SelectionPrompt`
     - Remove the corresponding dispatch call to `Show-StorageInfoScreen` from the switch body
     - Update comment-based help
   - [x] 2.4: Update `powershell-module/Tests/ConsoleApp/Show-MainMenu.Tests.ps1`:
     - Add test: `'Storage info'` option appears in the menu output
     - Add test: selecting `'Storage info'` returns the identifier `'StorageInfo'`
   - [x] 2.5: Update `powershell-module/Tests/ConsoleApp/Start-LWASConsole.Tests.ps1` (renamed
     in task 1):
     - Add test: mock `Show-StorageInfoScreen`; mock `Show-MainMenu` returning `'StorageInfo'`
       once then `'Exit'`; verify `Show-StorageInfoScreen` called exactly once
   - [x] 2.6: Update `powershell-module/Tests/ConsoleApp/Show-ConfigMenuScreen.Tests.ps1`:
     - Remove or update any test that asserts `'Storage & log file info'` is a choice in the
       config menu (it has been removed)
   - [x] 2.7: Run full Pester suite; confirm 0 failures

3. [x] Implement `Get-LWASTargetWindow` public function

   - [x] 3.1: Create `powershell-module/Public/Get-LWASTargetWindow.ps1`:
     - `[CmdletBinding()]` with the following parameters:
       - `-ProcessName [string]` — optional; matches against `WindowObject.ProcessName`
         (case-insensitive)
       - `-WindowTitle [string]` — optional; matches against `WindowObject.WindowTitle`
         (case-insensitive wildcard: `-ilike "*$WindowTitle*"`)
       - `-First [switch]` — optional; if present, write only the first matching window to the
         pipeline and stop; intended for scheduled-task use where exactly one instance of the
         game is expected
     - Explicit validation at the top of the function body: if both `-ProcessName` and
       `-WindowTitle` are `$null` or empty, `Write-Error "At least one of -ProcessName or
       -WindowTitle must be specified."` and `return` (non-terminating)
     - Calls `Get-EnumeratedWindows` with no filter parameters (enumerate all windows)
     - Applies filter: if `-ProcessName` provided, keep entries where
       `$w.ProcessName -ilike $ProcessName`; if `-WindowTitle` also provided, further filter by
       `$w.WindowTitle -ilike "*$WindowTitle*"`
     - If filtered result is empty: `Write-Error "No window found matching the specified
       criteria."` (non-terminating); return without writing to pipeline
     - If `-First` is present, take only the first element of the filtered list before the
       warning/output loop
     - For each window object to emit: if `$w.WindowState -eq 'Minimised'`, emit
       `Write-Warning "Window '$($w.WindowTitle)' (PID $($w.PID)) is minimised. It will be
       restored automatically when the macro runs."` — the object is still written to the pipeline
     - Writes each selected window object to the pipeline via `Write-Output $w`
     - Full comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER ProcessName`,
       `.PARAMETER WindowTitle`, `.PARAMETER First`, `.OUTPUTS`, `.EXAMPLE`) — examples must
       include the full pipeline pattern with `-First` for scheduled-task use and without `-First`
       for interactive/multi-instance use

   - [x] 3.2: Update `FunctionsToExport` in `LastWarAutoScreenshot.psd1`: add
     `'Get-LWASTargetWindow'`

   - [x] 3.3: Create `powershell-module/Tests/Get-LWASTargetWindow.Tests.ps1`:
     - Import module in `BeforeAll`; all tests inside `InModuleScope LastWarAutoScreenshot`
     - In `BeforeAll`, define a helper `New-MockWindowList` that returns a fixed array of 3
       objects: `@{ProcessName='lastwar.exe'; WindowTitle='Last War'; WindowState='Normal'; PID=100; WindowHandle=1}`, `@{ProcessName='lastwar.exe'; WindowTitle='Last War (2)'; WindowState='Minimised'; PID=101; WindowHandle=2}`, `@{ProcessName='notepad.exe'; WindowTitle='Notepad'; WindowState='Normal'; PID=200; WindowHandle=3}`
     - In each test, mock `Get-EnumeratedWindows` to return `New-MockWindowList`
     - Test: `-ProcessName 'lastwar.exe'` → 2 objects returned; both have `ProcessName =
       'lastwar.exe'`; `Write-Warning` called once (for the minimised window)
     - Test: `-ProcessName 'notepad.exe'` → 1 object returned; `Write-Warning` not called
     - Test: `-ProcessName 'chrome.exe'` (no match) → `Write-Error` called; 0 objects in output
     - Test: `-WindowTitle '*War*'` → 2 objects returned (both lastwar windows)
     - Test: `-ProcessName 'lastwar.exe' -WindowTitle '*(2)*'` → 1 object returned (the second
       lastwar window)
     - Test: neither `-ProcessName` nor `-WindowTitle` provided → `Write-Error` called; 0 objects;
       `Get-EnumeratedWindows` not called
     - Test: case-insensitive match — `-ProcessName 'LASTWAR.EXE'` matches `'lastwar.exe'` entries
     - Test: `-First` with multiple matches → exactly 1 object returned (the first in list order)
     - Test: `-First` with a single match → 1 object returned (no change from normal behaviour)
     - Test: `-First` with no matches → `Write-Error` called; 0 objects returned (same as without
       `-First`)
     - Test: without `-First` and multiple matches → all matching objects returned
     - Run full Pester suite; confirm count increases

4. [ ] Promote `Get-MacroFileList` to `Get-LWASMacro` (rename, extend, make public)

   **Rationale:** `Get-MacroFileList` already contains the core logic (scans the Macros folder,
   calls `Get-MacroFile` per file, returns structured objects). Creating a separate
   `Get-LWASMacro` alongside it would duplicate this logic and cause confusion. The correct
   approach is to rename `Get-MacroFileList` → `Get-LWASMacro`, promote it to public, add the
   `-Name` filter, and extend the returned objects to include `Metadata` and `Sequence` (currently
   only summary data is returned). The new return shape is a **superset** of the old one, so all
   existing internal callers are updated by name only — no API breakage. `Get-MacroFile` remains
   private and is still called internally by `Get-LWASMacro`.

   **Current return shape of `Get-MacroFileList`:**
   `FileName`, `FilePath`, `Name`, `CreatedUtc`, `DisplayDate`, `ActionCount`, `Valid`

   **New return shape of `Get-LWASMacro`** (adds `Metadata` and `Sequence`):
   `FileName`, `FilePath`, `Name`, `CreatedUtc`, `DisplayDate`, `ActionCount`, `Valid`,
   `Metadata`, `Sequence`

   - [x] 4.1: Move `powershell-module/Private/Get-MacroFileList.ps1` to
     `powershell-module/Public/Get-LWASMacro.ps1`; rename the function declaration from
     `function Get-MacroFileList` to `function Get-LWASMacro`

   - [x] 4.2: Add `-Name [string[]]` parameter support to `Get-LWASMacro`:
     - Parameter: `-Name [string[]]` — optional;
       `[Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]`; a single
       comma-separated string is split on `','` with each token trimmed (supports
       `Get-LWASMacro -Name 'macro-1, macro-2'`)
     - Restructure the function body to use `begin`/`process`/`end` blocks:
       - `begin`: initialise
         `$nameList = [System.Collections.Generic.List[string]]::new()`; if `-Name` is bound,
         split/trim/add all tokens
       - `process`: add any pipeline-supplied name tokens to `$nameList`
       - `end`: run the existing scan logic; after building the `$results` list, apply the name
         filter — if `$nameList.Count -gt 0`, keep only entries where
         `$entry.Name -in $nameList`; for each name in `$nameList` that has no match in results,
         call `Write-Error "No macro named '$name' found."` (non-terminating)

   - [x] 4.3: Extend the returned object in `Get-LWASMacro` to include `Metadata` and `Sequence`:
     - In the existing `foreach ($file in $jsonFiles)` loop, the `$macroResult` object from
       `Get-MacroFile` already contains `$macroResult.Data.metadata` and
       `$macroResult.Data.sequence`
     - Add `Metadata = $macroResult.Data.metadata` and
       `Sequence  = if ($null -ne $macroResult.Data.sequence) { @($macroResult.Data.sequence) } else { @() }`
       to the `[PSCustomObject]` constructed in the loop — positioned after the existing
       `Valid` property
     - `ActionCount` remains as-is (derived from `Sequence.Count`; now redundant but kept for
       backwards compatibility with console screens that use it for display)

   - [x] 4.4: Update all internal callers of `Get-MacroFileList` — search the entire codebase
     for `Get-MacroFileList`; rename each call site to `Get-LWASMacro`; confirm no references
     to `Get-MacroFileList` remain (likely callers: `Show-RunMacroScreen.ps1`,
     `Show-ManageMacrosScreen.ps1`, `Show-MainMenu.ps1`, `Show-ScheduleScreen.ps1` (added in
     task 8))

   - [x] 4.5: Update `FunctionsToExport` in `LastWarAutoScreenshot.psd1`: add `'Get-LWASMacro'`

   - [x] 4.6: Rename `powershell-module/Tests/Get-MacroFileList.Tests.ps1` (if it exists) to
     `Get-LWASMacro.Tests.ps1`; replace every reference to `Get-MacroFileList` with
     `Get-LWASMacro`; add new test cases covering the new behaviour:
     - Test: no `-Name` → returns all macros (existing behaviour, now via `Get-LWASMacro`)
     - Test: `-Name 'macro-1'` → returns exactly 1 object with `Name = 'macro-1'`
     - Test: `-Name @('macro-1', 'macro-2')` → returns 2 objects
     - Test: `-Name 'macro-1, macro-2'` (comma-separated string) → returns 2 objects
     - Test: `-Name 'nonexistent'` → `Write-Error` called containing `'nonexistent'`; 0 objects
       returned
     - Test: `-Name @('macro-1', 'nonexistent')` → `Write-Error` for `'nonexistent'`; 1 object
       returned for `'macro-1'`
     - Test: pipeline input `'macro-1','macro-2' | Get-LWASMacro` → returns 2 objects
     - Test: returned object has a `Sequence` property that is an array (not `$null`)
     - Test: returned object has a `Metadata` property (not `$null`)
     - Test: `Sequence` array elements have a `type` property (confirms full data, not summary)
     - Run full Pester suite; confirm count increases and no existing tests regress

5. [x] Add `SW_RESTORE` window state support

   - [x] 5.1: Update the C# file that defines `ShowWindow` constants (in
     `powershell-module/src/WindowEnumerationAPI.cs` or whichever file holds the existing
     `SW_MINIMIZE`/`SW_MAXIMIZE` constants):
     - Add `public const int SW_RESTORE = 9;` alongside the existing constants
     - Add XML doc comment:
       ```csharp
       /// <summary>Restores the window to its original size and position.
       /// Reverses SW_SHOWMINIMIZED (2) or SW_SHOWMAXIMIZED (3).</summary>
       ```
   - [x] 5.2: Update `powershell-module/Private/Set-WindowState.ps1`:
     - Extend the `-State` parameter's `[ValidateSet(...)]` attribute to include `'Restore'`
       alongside the existing valid values
     - Add a `'Restore'` branch in the function body that calls `ShowWindow($handle, SW_RESTORE)`
     - Update `.PARAMETER State` in comment-based help to document `'Restore'`; add a `.EXAMPLE`
       showing restore usage

   - [x] 5.3: Update the test file for `Set-WindowState` (find via Grep; likely
     `Tests/WindowManagement.Tests.ps1` or similar):
     - Add test: `Set-WindowState -State 'Restore'` calls `ShowWindow` with value `9`
     - Add test: `Set-WindowState -State 'Restore'` on an invalid handle → logs error and returns
       `$false`

   - [x] 5.4: Run full Pester suite; confirm 0 failures

6. [x] Implement `Start-LWASAutomationSequence` public function

   - [x] 6.1: Add `MacroExecution` section to `powershell-module/Private/Get-DefaultModuleSettings.ps1`:
     - Add a new `MacroExecution` hashtable in the defaults object:
       ```powershell
       MacroExecution = @{
           WindowRestoreDelayMs = 500
       }
       ```
     - Add `'MacroExecution.WindowRestoreDelayMs'` to `$script:ConfigValidationSchema`:
       - `Type = 'int'`, `Min = 0`, `Max = 10000`
       - `Description = 'Milliseconds to wait after restoring a minimised window before starting
         macro execution. Increase on slower machines if the first action fires before the window
         has fully rendered. Default: 500'`
     - `Get-ModuleConfiguration` will inject the `MacroExecution` key automatically via the
       existing `foreach ($key in $defaults.<Section>.PSObject.Properties.Name)` pattern — no
       code change required there, but verify the section is handled correctly

   - [x] 6.2: Update `powershell-module/Tests/ModuleConfiguration.Tests.ps1`:
     - Add round-trip save/load test for `MacroExecution.WindowRestoreDelayMs` with a non-default
       value (e.g. `1000`)
     - Add default-injection test: load a config file whose JSON does not contain a
       `MacroExecution` section; verify `WindowRestoreDelayMs` is injected as `500`
     - Run full Pester suite; confirm count increases

   - [x] 6.3: Create `powershell-module/Public/Start-LWASAutomationSequence.ps1`:
     - `[CmdletBinding()]` with the following parameters:
       - `-WindowObject [PSCustomObject]` — mandatory;
         `[Parameter(Mandatory, ValueFromPipeline)]`; the window object as returned by
         `Get-LWASTargetWindow` (must have `WindowHandle`, `ProcessName`, `WindowTitle`,
         `WindowState` properties)
       - `-MacroName [string]` — mandatory
     - `process` block (executes once per piped window object):
       1. **Validate window handle:** call `Test-WindowHandleValid -WindowHandle
          $WindowObject.WindowHandle`; if `$false`, `Write-Error "Window '$($WindowObject.WindowTitle)'
          is no longer valid."` (non-terminating); `continue`
       2. **Read config** via `Get-ModuleConfiguration`; store in `$config` (read once at the
          top of the process block, before any conditional branches, so all subsequent steps
          share the same config object)
       3. **Restore if minimised:** call
          `[LastWarAutoScreenshot.WindowEnumerationAPI]::IsIconic($WindowObject.WindowHandle)`;
          if `$true`, call `Set-WindowState -WindowHandle $WindowObject.WindowHandle -State 'Restore'`;
          log `Info "Restored minimised window '$($WindowObject.WindowTitle)' before macro
          execution."` via `Write-LastWarLog`; `Start-Sleep -Milliseconds
          $config.MacroExecution.WindowRestoreDelayMs` to allow the OS to complete the restore
          animation
       4. **Load macro:** call `Get-LWASMacro -Name $MacroName`; assign result to `$macro`; if
          `$macro` is `$null` or empty, `Write-Error "Macro '$MacroName' could not be loaded."`
          (non-terminating); `continue`
       5. **Start emergency stop monitor** if `$config.EmergencyStop.AutoStart -eq $true`: call
          `Start-LWASEmergencyStopMonitor`
       6. **Execute macro** inside `try`: call
          `Invoke-MacroSequence -WindowHandle $WindowObject.WindowHandle -Macro $macro`; catch
          exceptions, call `Write-Error` with exception message, set `$success = $false`
       7. **Cleanup** in `finally`: call `Stop-LWASEmergencyStopMonitor`
       8. Write result to pipeline:
          ```powershell
          [PSCustomObject]@{
              Success      = $success
              MacroName    = $MacroName
              WindowTitle  = $WindowObject.WindowTitle
              Message      = $message
          }
          ```
     - Full comment-based help; `.EXAMPLE` showing the pipeline pattern with `Get-LWASTargetWindow`

   - [x] 6.4: Update `FunctionsToExport` in `LastWarAutoScreenshot.psd1`: add
     `'Start-LWASAutomationSequence'`

   - [x] 6.5: Create `powershell-module/Tests/Start-LWASAutomationSequence.Tests.ps1`:
     - Import module in `BeforeAll`; all tests inside `InModuleScope LastWarAutoScreenshot`
     - Define `New-MockWindowObject` helper in `BeforeAll` returning a fixed window PSCustomObject
     - Mock `Test-WindowHandleValid`, `Get-LWASMacro`, `Invoke-MacroSequence`,
       `Start-LWASEmergencyStopMonitor`, `Stop-LWASEmergencyStopMonitor`, `Set-WindowState`,
       `Get-ModuleConfiguration`, `Write-LastWarLog`, `Start-Sleep`; mock
       `[LastWarAutoScreenshot.WindowEnumerationAPI]::IsIconic` via a scriptblock parameter
       approach or by mocking a thin wrapper function
     - Test: valid window, valid macro → `Invoke-MacroSequence` called once; result
       `Success = $true`; result `MacroName` equals the supplied name
     - Test: `Test-WindowHandleValid` returns `$false` → `Write-Error` called;
       `Invoke-MacroSequence` NOT called; result `Success = $false`
     - Test: `IsIconic` returns `$true` (minimised window) → `Set-WindowState -State 'Restore'`
       called; `Start-Sleep` called with `-Milliseconds` matching the value from
       `MacroExecution.WindowRestoreDelayMs` in the mocked config; `Invoke-MacroSequence` called
     - Test: `MacroExecution.WindowRestoreDelayMs = 0` in mocked config → `Start-Sleep` called
       with `-Milliseconds 0` (or not called at all if the implementation skips a zero-delay sleep)
     - Test: `IsIconic` returns `$false` (non-minimised) → `Set-WindowState` NOT called
     - Test: `Get-LWASMacro` returns `$null` → `Invoke-MacroSequence` NOT called; result
       `Success = $false`
     - Test: `Invoke-MacroSequence` throws → `Stop-LWASEmergencyStopMonitor` still called
       (finally block); result `Success = $false`
     - Test: `EmergencyStop.AutoStart = $true` in config → `Start-LWASEmergencyStopMonitor` called
     - Test: `EmergencyStop.AutoStart = $false` in config →
       `Start-LWASEmergencyStopMonitor` NOT called
     - Test: pipeline input of 2 window objects → `Invoke-MacroSequence` called twice; 2 result
       objects emitted
     - Test: `Write-LastWarLog` called with level `'Info'` when window is restored from minimised
     - Run full Pester suite; confirm count increases

7. [x] Implement Windows Task Scheduler integration cmdlets

   **(A) Private helper: `New-LWASLauncherScript`**
   - [x] 7.1.1: Create `powershell-module/Private/New-LWASLauncherScript.ps1`:
     - `[CmdletBinding()]` parameters: `-TaskName [string]` (mandatory), `-MacroName [string]`
       (mandatory), `-ProcessName [string]` (mandatory), `-ModulePath [string]` (mandatory)
     - Computes launcher path:
       `$launcherPath = Join-Path $env:APPDATA "LastWarAutoScreenshot\Schedulers\$TaskName.ps1"`
     - Creates the `Schedulers` directory if it does not exist:
       `New-Item -ItemType Directory -Path (Split-Path $launcherPath) -Force | Out-Null`
     - Generates launcher script content as a here-string:
       ```powershell
       # LWAS Launcher — auto-generated by Register-LWASScheduledTask — do not edit manually
       # Task    : <TaskName>
       # Macro   : <MacroName>
       # Generated: <UTC ISO-8601 timestamp>
       $ErrorActionPreference = 'Stop'
       Import-Module '<ModulePath>' -ErrorAction Stop
       Get-LWASTargetWindow -ProcessName '<ProcessName>' |
           Start-LWASAutomationSequence -MacroName '<MacroName>'
       ```
     - Writes file with `Set-Content -Path $launcherPath -Value $content -Encoding UTF8`
     - Returns the full launcher path string
     - Full comment-based help; `.NOTES` states the file must be deleted by
       `Unregister-LWASScheduledTask` when the task is removed

   **(B) `Register-LWASScheduledTask` (public)**
   - [x] 7.2.1: Create `powershell-module/Public/Register-LWASScheduledTask.ps1`:
     - `[CmdletBinding(SupportsShouldProcess)]` with parameters:
       - `-MacroName [string]` — mandatory; macro is validated to exist via
         `Get-LWASMacro -Name $MacroName`; if not found, `throw` with a message containing the
         macro name (registration without a valid macro is always an error)
       - `-ProcessName [string]` — mandatory; the target process name (e.g. `'lastwar.exe'`)
       - `-StartAt [datetime]` — mandatory; the first trigger date and time
       - `-RepeatEvery [timespan]` — optional; default `[TimeSpan]::FromHours(6)`; the repeat
         interval
       - `-RepeatFor [timespan]` — optional; default `[TimeSpan]::MaxValue` (interpreted by
         Windows Scheduler as indefinite); the total repeat duration
       - `-RandomDelayMinutes [int]` — optional; default `0`; validated range 0–120
       - `-ExpiresAt [datetime]` — optional; if provided, sets an expiry on the trigger
       - `-Force [switch]` — if present, overwrites an existing task without prompting
     - Internal logic:
       1. `$taskName = "LWAS_$MacroName"`
       2. Call `New-LWASLauncherScript -TaskName $taskName -MacroName $MacroName -ProcessName
          $ProcessName -ModulePath ((Get-Module LastWarAutoScreenshot).Path)`; store returned
          path in `$launcherPath`
       3. Build trigger: `$trigger = New-ScheduledTaskTrigger -Once -At $StartAt
          -RepetitionInterval $RepeatEvery`; if `-RepeatFor` is not `[TimeSpan]::MaxValue`, set
          `$trigger.RepetitionDuration = $RepeatFor`; if `-RandomDelayMinutes -gt 0`, set
          `$trigger.RandomDelay = [TimeSpan]::FromMinutes($RandomDelayMinutes)`; if `-ExpiresAt`
          provided, set `$trigger.EndBoundary = $ExpiresAt.ToUniversalTime().ToString('o')`
       4. Build action: `$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument
          "-NonInteractive -File ""$launcherPath"""`
       5. Build settings: `$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit
          ([TimeSpan]::FromHours(2)) -StopIfGoingOnBatteries:$false -StartWhenAvailable:$true`
       6. Check `$PSCmdlet.ShouldProcess($taskName, 'Register scheduled task')`; if confirmed:
          call `Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger
          -Settings $settings -RunLevel Limited -Force:($Force.IsPresent)` — pipe result to
          `Out-Null`
       7. Log Info via `Write-LastWarLog`
       8. Return `[PSCustomObject]@{TaskName=$taskName; MacroName=$MacroName;
          LauncherPath=$launcherPath; Success=$true}`
     - Full comment-based help with `.EXAMPLE` entries

   - [x] 7.2.2: Update `FunctionsToExport` in `LastWarAutoScreenshot.psd1`: add
     `'Register-LWASScheduledTask'`

   **(C) `Unregister-LWASScheduledTask` (public)**
   - [x] 7.3.1: Create `powershell-module/Public/Unregister-LWASScheduledTask.ps1`:
     - `[CmdletBinding(SupportsShouldProcess)]` with parameters:
       - `-MacroName [string]` — mandatory
       - `-Force [switch]` — skip confirmation
     - Internal logic:
       1. `$taskName = "LWAS_$MacroName"`
       2. Check task exists: `Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue`;
          if `$null`, `Write-Warning "No scheduled task found for macro '$MacroName'."` and `return`
       3. Compute launcher path:
          `$launcherPath = Join-Path $env:APPDATA "LastWarAutoScreenshot\Schedulers\$taskName.ps1"`
       4. Check `$PSCmdlet.ShouldProcess($taskName, 'Unregister scheduled task and delete launcher
          script')`; if confirmed:
          - `Unregister-ScheduledTask -TaskName $taskName -Confirm:$false`
          - If launcher script exists: `Remove-Item -Path $launcherPath -Force
            -ErrorAction SilentlyContinue`; log Info
          - Log Info via `Write-LastWarLog`
     - Full comment-based help; `.NOTES` explicitly states that the launcher `.ps1` is always
       deleted alongside the task to prevent orphaned scripts

   - [x] 7.3.2: Update `FunctionsToExport` in `LastWarAutoScreenshot.psd1`: add
     `'Unregister-LWASScheduledTask'`

   **(D) `Get-LWASScheduledTask` (public)**
   - [x] 7.4.1: Create `powershell-module/Public/Get-LWASScheduledTask.ps1`:
     - `[CmdletBinding()]` with optional parameter `-MacroName [string]`
     - Calls `Get-ScheduledTask -TaskName 'LWAS_*' -ErrorAction SilentlyContinue` to enumerate
       all LWAS tasks
     - If `-MacroName` provided, filters the list to `"LWAS_$MacroName"`; if not found after
       filtering, `Write-Error "No scheduled task found for macro '$MacroName'."` (non-terminating)
     - For each task, calls `Get-ScheduledTaskInfo -TaskName $task.TaskName
       -ErrorAction SilentlyContinue` to get next/last run info
     - Returns `[PSCustomObject]` per task with properties: `TaskName` (full task name including
       `LWAS_` prefix), `MacroName` (name with `LWAS_` prefix stripped), `State`, `NextRunTime`,
       `LastRunTime`, `LastTaskResult`, `LauncherPath` (derived as
       `Join-Path $env:APPDATA "LastWarAutoScreenshot\Schedulers\$($task.TaskName).ps1"`)
     - Full comment-based help

   - [x] 7.4.2: Update `FunctionsToExport` in `LastWarAutoScreenshot.psd1`: add
     `'Get-LWASScheduledTask'`

   **(E) Tests for scheduling cmdlets**
   - [x] 7.5.1: Create `powershell-module/Tests/New-LWASLauncherScript.Tests.ps1`:
     - All tests inside `InModuleScope LastWarAutoScreenshot`; use `TestDrive:\` for all file I/O
       (override `$env:APPDATA` via a mock or by testing the file-write logic with a patched path)
     - Mock `New-Item` and `Set-Content` or write to `TestDrive:\Schedulers\` directly
     - Test: launcher file is created at the expected path
     - Test: file content contains `Import-Module '<ModulePath>'` with the supplied module path
     - Test: file content contains `Get-LWASTargetWindow -ProcessName '<ProcessName>'` with the
       supplied process name
     - Test: file content contains `Start-LWASAutomationSequence -MacroName '<MacroName>'` with
       the supplied macro name
     - Test: file content contains the auto-generated header comment (task name and macro name)
     - Test: returned value is the expected launcher file path string
     - Run full Pester suite; confirm count increases

   - [x] 7.5.2: Create `powershell-module/Tests/Register-LWASScheduledTask.Tests.ps1`:
     - All tests inside `InModuleScope LastWarAutoScreenshot`
     - Mock `Get-LWASMacro` to return a valid macro for happy-path tests and `$null` for
       not-found tests
     - Mock `New-LWASLauncherScript` to return `'TestDrive:\Schedulers\LWAS_test.ps1'`
     - Mock `New-ScheduledTaskTrigger`, `New-ScheduledTaskAction`, `New-ScheduledTaskSettingsSet`,
       `Register-ScheduledTask`; capture the arguments passed to `Register-ScheduledTask` for
       assertion
     - Test: valid parameters → `Register-ScheduledTask` called with
       `TaskName = 'LWAS_my-macro'`; success result returned with correct `TaskName`,
       `MacroName`, and `LauncherPath` properties
     - Test: `-MacroName` not found (mock `Get-LWASMacro` returns nothing) → function throws
       with message containing the macro name
     - Test: `-RandomDelayMinutes 30` → the trigger object has `RandomDelay` set to
       `[TimeSpan]::FromMinutes(30)`
     - Test: `-ExpiresAt` provided → `trigger.EndBoundary` is set
     - Test: `-RepeatFor` with a specific timespan → `trigger.RepetitionDuration` is set to that
       timespan
     - Test: `-RepeatEvery` not specified → default of 6 hours is used
     - Test: `-WhatIf` → `Register-ScheduledTask` NOT called (ShouldProcess respected)
     - Run full Pester suite; confirm count increases

   - [x] 7.5.3: Create `powershell-module/Tests/Unregister-LWASScheduledTask.Tests.ps1`:
     - Mock `Get-ScheduledTask`, `Unregister-ScheduledTask`, `Remove-Item`, `Write-LastWarLog`
     - Test: task exists and launcher file exists → `Unregister-ScheduledTask` called;
       `Remove-Item` called with the expected launcher path
     - Test: task does not exist → `Write-Warning` called; `Unregister-ScheduledTask` NOT called
     - Test: task exists but launcher file is missing → `Remove-Item` called with
       `-ErrorAction SilentlyContinue`; no exception thrown
     - Test: `-WhatIf` → `Unregister-ScheduledTask` NOT called (ShouldProcess respected)
     - Run full Pester suite; confirm count increases

   - [x] 7.5.4: Create `powershell-module/Tests/Get-LWASScheduledTask.Tests.ps1`:
     - Mock `Get-ScheduledTask` returning 2 mock task objects with names `'LWAS_macro-1'` and
       `'LWAS_macro-2'`
     - Mock `Get-ScheduledTaskInfo` returning mock info objects with `NextRunTime` and
       `LastRunTime` set
     - Test: no `-MacroName` → returns 2 objects; both have the `LWAS_` prefix stripped from
       their `MacroName` property
     - Test: `-MacroName 'macro-1'` → returns 1 object with `MacroName = 'macro-1'`
     - Test: `-MacroName 'nonexistent'` → `Write-Error` called; 0 objects returned
     - Test: returned object has `NextRunTime`, `LastRunTime`, `LastTaskResult`, `LauncherPath`
       properties
     - Run full Pester suite; confirm count increases

8. [ ] Implement `Show-ScheduleScreen` console screen and wire up main menu

   - [x] 8.1: Update `powershell-module/Private/ConsoleApp/Show-MainMenu.ps1`:
     - Add `'Manage schedules'` as a selectable option (position: after `'Manage macros'`,
       before `'Storage info'`)
     - Return identifier `'ManageSchedules'` for this option
     - Update comment-based help

   - [x] 8.2: Update `powershell-module/Public/Start-LWASConsole.ps1`:
     - Add `'ManageSchedules'` case to the `switch` block; dispatch to
       `Show-ScheduleScreen -Console $Console` wrapped in `RunInAlternateScreen`

   - [x] 8.3: Create `powershell-module/Private/ConsoleApp/Show-ScheduleScreen.ps1`:
     - `Show-ScheduleScreen -Console [Spectre.Console.IAnsiConsole]`
     - **Task list:** call `Get-LWASScheduledTask`; if empty or error: display info `Panel`
       `"No schedules configured. Select 'Create new schedule' to add one."`; otherwise build a
       `Table` with columns `Task Name`, `Macro`, `Next Run`, `Last Run`, `Last Result` and write
       it to `$Console`
     - **Action selection:** `SelectionPrompt` with choices: `'Create new schedule'`,
       `'Remove a schedule'` (present but disabled/greyed-out via a different Spectre style when
       no tasks exist), `'[[Back to main menu]]'`
     - **Create new schedule flow:**
       1. Call `Get-LWASMacro`; if returns nothing, display error `Panel`
          `"No macros recorded yet. Record a macro first before creating a schedule."` and return
          to the action selection prompt
       2. `SelectionPrompt` `"Select macro:"` populated from macro names; include `'[[Back]]'`;
          if `'[[Back]]'` selected, return to action prompt
       3. `TextPrompt` `"Target process name (e.g. lastwar.exe):"` — validated non-empty;
          re-prompt if empty
       4. `TextPrompt` `"Start date and time (dd/MM/yyyy HH:mm):"` — parsed with
          `[datetime]::ParseExact($input, 'dd/MM/yyyy HH:mm', $null)`; display error in red and
          re-prompt on parse failure or if date is not in the future
       5. `SelectionPrompt` `"Repeat every:"` with choices: `'15 minutes'`, `'30 minutes'`,
          `'45 minutes'`, `'1 hour'`, `'2 hours'`, `'4 hours'`, `'6 hours'`, `'12 hours'`,
          `'24 hours'`, `'Custom'`; preset choices map directly to their `[TimeSpan]` equivalents;
          if `'Custom'`, present two `TextPrompt`s in sequence:
          - `"Hours (0 or more):"` — validated as a non-negative integer; re-prompt on invalid input
          - `"Minutes (0–59):"` — validated as an integer in range 0–59; re-prompt on invalid input
          - Combined duration must be at least 1 minute
            (`[TimeSpan]::FromMinutes($hours * 60 + $minutes) -ge [TimeSpan]::FromMinutes(1)`);
            if not, display error `"Interval must be at least 1 minute."` and re-prompt both fields
       6. `SelectionPrompt` `"Repeat duration:"` with choices: `'Indefinitely'`, `'Until a
          specific date'`; if `'Until a specific date'`, `TextPrompt` for expiry date
          `(dd/MM/yyyy)` — parsed and validated to be after the start date
       7. `TextPrompt` `"Random delay before start (0–120 minutes, 0 = no delay):"` default `'0'`;
          validated as integer in range 0–120 via `Test-ConfigValue`; re-prompt if invalid
       8. Display summary `Panel` showing all collected values; `SelectionPrompt`
          `"Confirm?"` with `'Yes – create schedule'`, `'No – go back'`; if `'No'`, return to
          action prompt
       9. Call `Register-LWASScheduledTask -MacroName $macroName -ProcessName $processName
          -StartAt $startAt -RepeatEvery $repeatEvery -RepeatFor $repeatFor
          -RandomDelayMinutes $randomDelay (-ExpiresAt $expiresAt if provided)`
       10. Display success `Panel` or error `Panel` based on the result; return to action prompt
     - **Remove schedule flow:**
       1. If no tasks exist, return to action prompt immediately
       2. `SelectionPrompt` populated with `Get-LWASScheduledTask` task names; include `'[[Back]]'`;
          if `'[[Back]]'` selected, return to action prompt
       3. `SelectionPrompt` confirmation: `"Remove schedule '<taskName>'?"` with
          `'Yes – remove'`, `'No – go back'`; if `'No'`, return to action prompt
       4. Call `Unregister-LWASScheduledTask -MacroName $macroName -Force`; display result panel
       5. Loop back to action selection
     - Loops back to action selection until `'[[Back to main menu]]'` is chosen
     - Full comment-based help; all error paths log via `Write-LastWarLog`

   - [x] 8.4: Update `powershell-module/Tests/ConsoleApp/Show-MainMenu.Tests.ps1`:
     - Add test: `'Manage schedules'` option appears in the menu output
     - Add test: selecting `'Manage schedules'` returns the identifier `'ManageSchedules'`

   - [x] 8.5: Update `powershell-module/Tests/ConsoleApp/Start-LWASConsole.Tests.ps1`:
     - Add test: mock `Show-ScheduleScreen`; mock `Show-MainMenu` returning `'ManageSchedules'`
       once then `'Exit'`; verify `Show-ScheduleScreen` called exactly once

   - [x] 8.6: Create `powershell-module/Tests/ConsoleApp/Show-ScheduleScreen.Tests.ps1`:
     - All tests use `TestConsole` injection and `InModuleScope LastWarAutoScreenshot`
     - Mock `Get-LWASScheduledTask`, `Get-LWASMacro`, `Register-LWASScheduledTask`,
       `Unregister-LWASScheduledTask`, `Write-LastWarLog`
     - Test: `Get-LWASScheduledTask` returns empty → info panel `"No schedules configured"`
       appears in `$testConsole.Output`; no task table rendered
     - Test: `Get-LWASScheduledTask` returns 2 tasks → task table rendered; output contains both
       task names
     - Test: select `'[[Back to main menu]]'` immediately → no scheduling action called; function
       returns
     - Test: create schedule — queue all valid inputs through the wizard; `Register-LWASScheduledTask`
       called once with correct `-MacroName`, `-ProcessName`, `-StartAt`, `-RepeatEvery`; success
       panel content appears in output
     - Test: create schedule — no macros available (`Get-LWASMacro` returns nothing) → error panel
       `"No macros recorded yet"` appears; `Register-LWASScheduledTask` NOT called
     - Test: create schedule — select `'[[Back]]'` at macro selection step → returns to action
       prompt; `Register-LWASScheduledTask` NOT called
     - Test: create schedule — invalid start date entered (non-parseable string) → error markup
       appears in output; prompt is re-displayed; correct date then accepted and flow continues
     - Test: create schedule — `'Custom'` selected → hours prompt and minutes prompt both rendered
       in output
     - Test: create schedule — `'Custom'` with hours `0` and minutes `0` → error `"Interval must
       be at least 1 minute"` shown; prompts re-displayed
     - Test: create schedule — `'Custom'` with hours `1` and minutes `30` →
       `Register-LWASScheduledTask` called with `-RepeatEvery ([TimeSpan]::FromMinutes(90))`
     - Test: create schedule — random delay `'150'` (out of range) → error shown; re-prompt
       rendered
     - Test: remove schedule — select task → confirmation prompt appears in output; queue `'Yes –
       remove'` → `Unregister-LWASScheduledTask` called with correct macro name
     - Test: remove schedule — select task → queue `'No – go back'` →
       `Unregister-LWASScheduledTask` NOT called
     - Run full Pester suite; confirm count increases

9. [ ] Final validation, documentation, and CLAUDE.md updates

   - [x] 9.1: Run the complete, unfiltered Pester suite (all files, no tag or name filters)
     - Record total test count; must meet or exceed the Phase 5b final baseline plus all new tests
       added throughout Phase 6 tasks
     - All tests must pass with 0 failures and 0 errors
     - If any previously-passing test now fails, halt and investigate; do not proceed
   - [x] 9.2: Manually smoke-test command-line macro execution in a real PowerShell 7 terminal:
     - `Import-Module .\powershell-module\LastWarAutoScreenshot.psd1 -Force`
     - `Get-LWASMacro` — verify all macros returned with full `Sequence` array data
     - `Get-LWASMacro -Name 'my-macro-1'` — verify single macro returned
     - `Get-LWASTargetWindow -ProcessName 'notepad.exe'` (with Notepad open) — verify window
       object returned; minimise Notepad and re-run, verify warning emitted but object still
       returned
     - `Get-LWASTargetWindow -ProcessName 'chrome.exe'` (not running) — verify non-terminating
       `Write-Error` emitted; no object in output
     - `Get-LWASTargetWindow -ProcessName 'notepad.exe' | Start-LWASAutomationSequence -MacroName
       'my-macro-1'` with Notepad minimised — verify Notepad is restored before macro runs
   - [x] 9.3: Manually smoke-test scheduling in a real PowerShell 7 terminal:
     - `Register-LWASScheduledTask -MacroName 'my-macro-1' -ProcessName 'lastwar.exe' -StartAt
       (Get-Date).AddMinutes(2) -RepeatEvery (New-TimeSpan -Hours 6)` — verify task created in
       Windows Task Scheduler and launcher `.ps1` exists at the expected path
     - `Get-LWASScheduledTask` — verify task appears with correct properties
     - `Unregister-LWASScheduledTask -MacroName 'my-macro-1'` — verify task removed from Task
       Scheduler and launcher `.ps1` deleted
     - Open `Start-LWASConsole`; navigate to `Manage schedules`; create and remove a schedule
       via the interactive UI
   - [x] 9.4: Update `CLAUDE.md`:
     - Verify `Start-LWASConsole` is documented as the entry point (completed in task 1.1.5);
       confirm no references to `Start-LastWarAutoScreenshot` remain
     - Add `Get-LWASTargetWindow`, `Get-LWASMacro`, `Start-LWASAutomationSequence` to the
       commands section with usage examples
     - Add scheduling cmdlets (`Register-LWASScheduledTask`, `Unregister-LWASScheduledTask`,
       `Get-LWASScheduledTask`) to the commands section
   - [x] 9.5: Update `powershell-module/Docs/Configuration.md`:
     - Add a note in the file paths section documenting the `Schedulers/` subdirectory
       (`$env:APPDATA\LastWarAutoScreenshot\Schedulers\`) and its contents (auto-generated
       launcher scripts); note that this directory is managed automatically and files should not
       be edited manually

---

### Design decisions (finalised)

All design questions have been resolved. The decisions below are recorded for reference.

1. **`Get-LWASTargetWindow` — `-First` switch added:**
   Returns all matching windows by default. The `-First` switch caps output to the first match.
   `-First` is the standard usage in launcher scripts and scheduled tasks where exactly one game
   instance is expected. Interactive and multi-instance scenarios omit `-First`.

2. **`Start-LWASAutomationSequence` restore delay — configurable via `MacroExecution.WindowRestoreDelayMs`:**
   Default `500` ms. Stored in module configuration so it can be tuned without a code change.
   A console config screen for the `MacroExecution` section is deferred to Phase 10.

3. **Scheduled task repeat interval presets — expanded:**
   `Show-ScheduleScreen` wizard presets: `15 minutes`, `30 minutes`, `45 minutes`, `1 hour`,
   `2 hours`, `4 hours`, `6 hours`, `12 hours`, `24 hours`, `Custom`. The `Custom` option
   prompts for hours and minutes separately; combined duration must be at least 1 minute.

4. **`Register-LWASScheduledTask` — current module path embedded in launcher script:**
   Accepted limitation. Documented in the function's comment-based help. If the module folder is
   moved after registration, existing launcher scripts must be re-registered.

## Phase 7: Module Installation & Versioning

### Architecture decisions (future reference)

- **Distribution channel — GitHub Releases (zip):** Module is distributed as a versioned zip archive
  attached to a GitHub Release (`LastWarAutoScreenshot-v{version}.zip`). No PowerShell Gallery
  publication in this phase. Zip structure mirrors the repo layout so bootstrap script path
  resolution works identically in both contexts:

  ```plaintext
  LastWarAutoScreenshot-v1.0.0.zip
  ├── scripts/
  │   ├── Install-LWAS.ps1
  │   └── Uninstall-LWAS.ps1
  ├── LastWarAutoScreenshot/          ← the module folder (Tests/ and lib/test/ excluded)
  └── LICENSE
  ```

- **`Install-LWAS` stays as a public function:** The canonical installation logic lives in
  `Public/Install-LWAS.ps1` (renamed from `Install-LWASModule`). A thin bootstrap script
  `scripts/Install-LWAS.ps1` self-elevates and delegates to the function, providing a
  double-click entry point for first-time users who have not yet imported the module.

- **`Uninstall-LWAS` is a standalone script, not a module function:** A module function cannot
  remove the module that exports it. `scripts/Uninstall-LWAS.ps1` is self-contained and requires
  no prior module import.

- **Versioned install directory:** Module is installed to
  `$HOME\Documents\PowerShell\Modules\LastWarAutoScreenshot\{version}\` following the PowerShell
  module versioning convention. This allows side-by-side versions and is what `Install-Module`
  uses. `$HOME\Documents\PowerShell` is the standard user-scope module root on PowerShell 7+
  (Windows).

- **`Tests/`, `lib/test/`, and `Docs/` excluded from installed copy:** These are development
  artefacts. Only runtime files are installed:
  `*.psm1`, `*.psd1`, `src/`, `lib/` (minus `lib/test/`), `Public/`, `Private/`, `Private/ConsoleApp/`.

- **`RequiredAssemblies` left empty with explanatory comment:** The psm1 already handles DLL
  loading via guarded `Add-Type` calls. Populating `RequiredAssemblies` with the bundled DLL paths
  would cause PowerShell to load them a second time before the psm1 guard runs, producing
  `Assembly already loaded` warnings. The comment in the psd1 documents this decision.

- **Event log source registered eagerly at install time:** Currently `Write-LastWarLog` registers
  the `LastWarAutoScreenshot` event log source lazily on first use, requiring elevation at that
  point. `Install-LWAS` pre-registers the source during installation (using the existing private
  `Add-EventLogSource` / `Test-EventLogSourceExists` helpers) so subsequent log writes never need
  elevation. The lazy fallback in `Write-LastWarLog` is retained as a safety net.

- **DLL download as repair/verification step:** The bundled DLLs are tracked in git and present
  in release zips. `Install-LWAS` checks their presence and offers to download from NuGet only
  if they are missing (i.e. as a repair step). It does not download them unconditionally.

- **`ModuleVersion` bumped to `1.0.0`:** Phase 7 is the first production-ready release. The
  `ModuleVersion` field in `LastWarAutoScreenshot.psd1` is updated from `0.0.1` to `1.0.0`.
  Subsequent bumps are manual: edit `ModuleVersion` and `ReleaseNotes` in the psd1, then run
  `scripts/New-LWASRelease.ps1 -Version x.y.z`.

- **`PowerShellVersion` lowered to `7.0`:** The module uses no features introduced after PS 7.0
  (`ForEach-Object -Parallel` is 7.0, all other constructs are compatible). Setting it to
  `7.5.4` (the developer's current runtime) is unnecessarily restrictive for users on older PS 7.x
  builds.

- **`New-LWASRelease.ps1` does not auto-tag git:** The script bumps the psd1, runs the test
  suite, and creates the release zip. It then prints a post-release checklist instructing the
  developer to commit the psd1 change, create the git tag (`git tag v{version}`), push, and
  upload the zip to GitHub Releases. Git operations are not automated to keep the script safe
  and auditable.

- **MIT licence:** A `LICENSE` file is added to the repository root. `LicenseUri` in the psd1
  PSData block points to the GitHub raw URL. `Copyright` in the psd1 is already present and
  consistent with the licence.

---

1. [x] Add MIT `LICENSE` file to repo root

   - [x] 1.1: Create `LICENSE` at the repository root (`C:\git\LastWarAutoScreenshot\LICENSE`) with
     the standard MIT licence text, year `2026`, name `Paul Kathro`. Full text:

     ```plaintext
     MIT License

     Copyright (c) 2026 Paul Kathro

     Permission is hereby granted, free of charge, to any person obtaining a copy
     of this software and associated documentation files (the "Software"), to deal
     in the Software without restriction, including without limitation the rights
     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
     copies of the Software, and to permit persons to whom the Software is
     furnished to do so, subject to the following conditions:

     The above copyright notice and this permission notice shall be included in all
     copies or substantial portions of the Software.

     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
     SOFTWARE.
     ```

2. [x] Update `LastWarAutoScreenshot.psd1` metadata

   - [x] 2.1: Set `ModuleVersion` from `'0.0.1'` to `'1.0.0'`.

   - [x] 2.2: Set `PowerShellVersion` from `'7.5.4'` to `'7.0'`. Rationale: no module code uses
     features introduced after PS 7.0; `7.5.4` is the developer's current runtime, not the minimum
     requirement.

   - [x] 2.3: Populate `Tags` in the `PSData` block:

     ```powershell
     Tags = @('automation', 'gaming', 'mouse-control', 'screenshot', 'last-war', 'macro', 'scheduled-task', 'windows')
     ```

   - [x] 2.4: Populate `LicenseUri` in the `PSData` block:

     ```powershell
     LicenseUri = 'https://github.com/berbology/LastWarAutoScreenshot/blob/main/LICENSE'
     ```

   - [x] 2.5: Populate `ReleaseNotes` in the `PSData` block with the v1.0.0 entry:

     ```powershell
     ReleaseNotes = 'v1.0.0 — Initial release. Phases 1–7: window management, mouse control, console UI, macro recording and playback, screenshot capture with similarity detection, configuration and scheduling, module installation.'
     ```

   - [x] 2.6: Add an explanatory comment to the `RequiredAssemblies` line to document why it is
     intentionally empty:

     ```powershell
     # RequiredAssemblies is intentionally empty. Spectre.Console.dll is loaded by the psm1 via
     # guarded Add-Type calls. Populating RequiredAssemblies would cause a double-load before the
     # guard runs, producing 'Assembly already loaded' warnings. See LastWarAutoScreenshot.psm1.
     # RequiredAssemblies = @()
     ```

   - [x] 2.7: Replace `'Install-LWASModule'` with `'Install-LWAS'` in `FunctionsToExport`.

3. [x] Rename and expand `Install-LWASModule` → `Install-LWAS`

   - [x] 3.1: Rename file `powershell-module/Public/Install-LWASModule.ps1` →
     `powershell-module/Public/Install-LWAS.ps1`.

   - [x] 3.2: Rename the function declaration from `Install-LWASModule` to `Install-LWAS` inside
     the file.

   - [x] 3.3: Add a `-Force` switch parameter. When present, overwrite an existing installation
     without prompting.

   - [x] 3.4: Add module copy logic as a new step after the admin check and .NET 9.0 verification:
     - Resolve source module root: `$moduleRoot = Split-Path -Parent $PSScriptRoot`
       (`$PSScriptRoot` is `Public/`; parent is the module root)
     - Read version from the psd1: `$version = (Import-PowerShellDataFile (Join-Path $moduleRoot 'LastWarAutoScreenshot.psd1')).ModuleVersion`
     - Resolve destination: `$installBase = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules\LastWarAutoScreenshot'`
       then `$installPath = Join-Path $installBase $version`
     - If `$installPath` already exists and `-Force` is not specified: prompt user
       `"An installation already exists at $installPath. Overwrite? [Y/N]"` — if `N`, write
       `'Installation cancelled.'` and return
     - Remove existing `$installPath` if present (so stale files from a previous install are not
       left behind)
     - Excluded items (do not copy): `Tests`, `lib\test`, `Docs` — use
       `Get-ChildItem -Path $moduleRoot -Exclude 'Tests','Docs' -Force` then recurse,
       filtering out `lib\test` by path during copy
     - Use `Copy-Item -Path $moduleRoot\* -Destination $installPath -Recurse -Force`
       followed by `Remove-Item -Path (Join-Path $installPath 'Tests') -Recurse -Force -ErrorAction SilentlyContinue`,
       `Remove-Item -Path (Join-Path $installPath 'Docs') -Recurse -Force -ErrorAction SilentlyContinue`, and
       `Remove-Item -Path (Join-Path $installPath 'lib\test') -Recurse -Force -ErrorAction SilentlyContinue`
     - Write `"Module installed to $installPath"` on success
     - On any error: `Write-Error` with the exception message; return

   - [x] 3.5: Add Windows Event Log source registration as a new step after module copy:
     - Call the module's existing private helpers (accessible because the module is loaded):
       `$sourceExists = Test-EventLogSourceExists -Source 'LastWarAutoScreenshot'`
     - If `$false`: call `Add-EventLogSource -Source 'LastWarAutoScreenshot' -LogName 'Application'`
       inside a `try/catch`; on success write `"Windows Event Log source registered."`; on error
       write a `Write-Warning` explaining the source was not registered and log writes will use
       the fallback lazy registration
     - If `$true`: write `"Windows Event Log source already registered, skipping."`

   - [x] 3.6: Add `$env:APPDATA\LastWarAutoScreenshot\` directory creation as a new step:
     - `$appDataPath = Join-Path $env:APPDATA 'LastWarAutoScreenshot'`
     - If it does not exist: `New-Item -Path $appDataPath -ItemType Directory -Force | Out-Null`;
       write `"Created config directory: $appDataPath"`
     - If it already exists: write `"Config directory already exists, skipping."`

   - [x] 3.7: Reframe the existing DLL download blocks (steps 4 and 5 in the original function)
     as repair/verification steps. Update the `Write-Output` messages to reflect this:
     - Change `"Downloading Spectre.Console $version from NuGet..."` →
       `"Spectre.Console.dll missing — downloading from NuGet as repair step..."`
     - Change `"Downloading Spectre.Console.Testing $version from NuGet..."` →
       `"Spectre.Console.Testing.dll missing — downloading from NuGet as repair step..."`
     - Add a heading `Write-Output ''` + `Write-Output '--- Dependency verification ---'` before
       the DLL checks so the output is clearly grouped

   - [x] 3.8: Update the success message (step 6 in the original function):
     - Replace the existing `Read-Host 'Press Enter to continue'` line with a clean summary panel:

       ```powershell
       Write-Output ''
       Write-Output 'Installation complete.'
       Write-Output "  Module path : $installPath"
       Write-Output "  Config path : $appDataPath"
       Write-Output ''
       Write-Output 'You can now use: Import-Module LastWarAutoScreenshot'
       ```

   - [x] 3.9: Update comment-based help:
     - `.SYNOPSIS`: `'Installs the LastWarAutoScreenshot module and its dependencies.'`
     - `.DESCRIPTION`: document all steps performed (copy to PSModulePath, event log registration,
       config directory, DLL repair check), note elevation requirement, note `-Force` behaviour
     - Add `.PARAMETER Force` entry
     - Update `.EXAMPLE` to show both plain and `-Force` invocations

4. [x] Create `scripts/Install-LWAS.ps1` bootstrap script

   - [x] 4.1: Create the `scripts/` directory at the repository root
     (`C:\git\LastWarAutoScreenshot\scripts\`).

   - [x] 4.2: Create `scripts/Install-LWAS.ps1` with the following behaviour:
     - Comment-based help at the top: `.SYNOPSIS 'Bootstrap installer for LastWarAutoScreenshot.'`
       and `.DESCRIPTION` documenting that it self-elevates and delegates to `Install-LWAS`
     - Self-elevation block: if the current principal is not Administrator, re-launch the script
       via `Start-Process pwsh -Verb RunAs -ArgumentList "-NonInteractive -File \`"$PSCommandPath\`""` and `exit`
     - Resolve the module manifest path relative to `$PSScriptRoot`:
       `$manifest = Join-Path $PSScriptRoot '..\LastWarAutoScreenshot\LastWarAutoScreenshot.psd1'`
       then `$manifest = (Resolve-Path $manifest).Path`
     - Validate the manifest exists; if not, write an error explaining the expected directory
       structure and exit with code 1
     - Import the module: `Import-Module $manifest -Force`
     - Call `Install-LWAS @args` (pass through any arguments, e.g. `-Force`)
     - No `[CmdletBinding()]` or `param()` block — this is a script, not a function; pass-through
       is handled by `@args`

5. [x] Create `scripts/Uninstall-LWAS.ps1`

   - [x] 5.1: Create `scripts/Uninstall-LWAS.ps1` with comment-based help:
     - `.SYNOPSIS`: `'Uninstalls the LastWarAutoScreenshot module.'`
     - `.DESCRIPTION`: documents the three removal steps (module directory, event log source,
       optional appdata) and notes elevation requirement
     - `.PARAMETER RemoveAppData`: switch; when present, also removes `$env:APPDATA\LastWarAutoScreenshot\`
       including all config files and generated scheduler scripts. Default is to prompt.

   - [x] 5.2: `[CmdletBinding(SupportsShouldProcess)]` and `param([switch]$RemoveAppData)` block.

   - [x] 5.3: Admin check — same pattern as `Install-LWAS`: check `WindowsPrincipal.IsInRole`; if
     not elevated write `Write-Warning` and `return`.

   - [x] 5.4: Check if the module is currently loaded in the session:
     `if (Get-Module -Name LastWarAutoScreenshot) { Write-Warning 'LastWarAutoScreenshot is currently imported in this session. Uninstalling while the module is loaded may leave assemblies in memory. Consider starting a new PowerShell session after uninstallation.' }`
     — do not abort; this is advisory only.

   - [x] 5.5: Locate all installed copies using `Get-Module -Name LastWarAutoScreenshot -ListAvailable`:
     - For each `ModuleBase` path found: remove the directory with
       `Remove-Item -Path $_.ModuleBase -Recurse -Force`; write `"Removed: $($_.ModuleBase)"`
     - If no copies found via `Get-Module -ListAvailable`: fall back to checking
       `$HOME\Documents\PowerShell\Modules\LastWarAutoScreenshot\` directly; remove if present
     - If still nothing found: write `"No installed module directories found in PSModulePath. Skipping module removal."` — do not error

   - [x] 5.6: Remove Windows Event Log source:
     - Check `[System.Diagnostics.EventLog]::SourceExists('LastWarAutoScreenshot')` in a
       `try/catch`
     - If exists: call `[System.Diagnostics.EventLog]::DeleteEventSource('LastWarAutoScreenshot')`
       in a `try/catch`; on success write `"Windows Event Log source removed."`; on error
       `Write-Warning` with the exception message
     - If not exists: write `"Windows Event Log source not found, skipping."`

   - [x] 5.7: Handle `$env:APPDATA\LastWarAutoScreenshot\` removal:
     - `$appDataPath = Join-Path $env:APPDATA 'LastWarAutoScreenshot'`
     - If the path does not exist: write `"Config directory not found, skipping."` and skip
     - If `-RemoveAppData` was passed: remove without prompting
     - Otherwise: prompt `"Remove config and scheduler files at $appDataPath? [Y/N]"` via
       `Read-Host`; remove only if user answers `Y`/`y`
     - Removal: `Remove-Item -Path $appDataPath -Recurse -Force`; on success write
       `"Removed config directory: $appDataPath"`; on error `Write-Warning`

   - [x] 5.8: Print a completion summary:

     ```powershell
     Write-Output ''
     Write-Output 'Uninstallation complete.'
     Write-Output 'Start a new PowerShell session to ensure no module assemblies remain in memory.'
     ```

6. [x] Create `scripts/New-LWASRelease.ps1`

   - [x] 6.1: Comment-based help:
     - `.SYNOPSIS`: `'Creates a versioned release zip for LastWarAutoScreenshot.'`
     - `.DESCRIPTION`: documents the steps — version bump in psd1, Pester run, zip creation,
       post-release checklist output
     - `.PARAMETER Version`: required string; must match semver pattern `^\d+\.\d+\.\d+$`
     - `.PARAMETER OutputDir`: optional string; default `$PSScriptRoot\..\releases`
     - `.PARAMETER ReleaseNotes`: optional string; if omitted, user is prompted interactively
     - `.PARAMETER SkipTests`: switch; skip the Pester run (intended for dry-run testing of the
       script itself only — document this clearly)
     - `.EXAMPLE`: `.\New-LWASRelease.ps1 -Version '1.1.0' -ReleaseNotes 'Bug fixes and performance improvements.'`

   - [x] 6.2: `[CmdletBinding()]` and `param` block matching the parameters above.

   - [x] 6.3: Validate `-Version` matches `^\d+\.\d+\.\d+$`; if not, `throw "Version must be in
     semver format (e.g. '1.2.3'). Got: $Version"`

   - [x] 6.4: Resolve paths:
     - `$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path`
     - `$moduleRoot = Join-Path $repoRoot 'LastWarAutoScreenshot'`

     > Note: inside a release zip the module folder is named `LastWarAutoScreenshot`; in the repo it
     > is `powershell-module`. The script therefore looks for the module at both locations in order:
     > `powershell-module` first (repo context), then `LastWarAutoScreenshot` (zip context).
     > Implementation: check `Test-Path (Join-Path $repoRoot 'powershell-module')` first;
     > if true, set `$moduleRoot = Join-Path $repoRoot 'powershell-module'`; else set
     > `$moduleRoot = Join-Path $repoRoot 'LastWarAutoScreenshot'`; if neither exists, `throw`.

   - [x] 6.5: Collect release notes if not supplied via parameter:
     - `if (-not $ReleaseNotes) { $ReleaseNotes = Read-Host "Enter release notes for v$Version" }`
     - Validate non-empty; re-prompt if blank.

   - [x] 6.6: Update `ModuleVersion` and `ReleaseNotes` in the psd1:
     - `$psd1Path = Join-Path $moduleRoot 'LastWarAutoScreenshot.psd1'`
     - Read the raw text: `$psd1Content = Get-Content $psd1Path -Raw`
     - Replace `ModuleVersion` line using a regex: `$psd1Content -replace "ModuleVersion\s*=\s*'[^']+'"`, `"ModuleVersion = '$Version'"`
     - Replace `ReleaseNotes` line using a regex: `$psd1Content -replace "ReleaseNotes\s*=\s*'[^']*'"`, `"ReleaseNotes = 'v$Version — $ReleaseNotes'"`
     - Write back: `Set-Content -Path $psd1Path -Value $psd1Content -Encoding UTF8 -NoNewline`
     - Write `"Updated psd1: ModuleVersion = $Version, ReleaseNotes updated."`

   - [x] 6.7: Run the full Pester suite (unless `-SkipTests`):
     - `$testsPath = Join-Path $moduleRoot 'Tests'`
     - `$result = Invoke-Pester -Path $testsPath -Output Minimal -PassThru`
     - If `$result.FailedCount -gt 0` or `$result.Result -ne 'Passed'`: `throw "Pester suite failed ($($result.FailedCount) failure(s)). Release zip not created. Fix all failures before releasing."`
     - Write `"Pester: $($result.PassedCount) tests passed. Suite is green."`

   - [x] 6.8: Create the output directory:
     - Resolve `$OutputDir` to an absolute path
     - `New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null`

   - [x] 6.9: Assemble the staging directory and create the zip:
     - `$stagingRoot = Join-Path $env:TEMP "LWAS_Release_v$Version"`
     - Remove staging dir if it already exists
     - Create `$stagingRoot\LastWarAutoScreenshot\` and copy module files into it, excluding
       `Tests`, `Docs`, and `lib\test`:
       - `Copy-Item -Path $moduleRoot\* -Destination (Join-Path $stagingRoot 'LastWarAutoScreenshot') -Recurse -Force`
       - Then prune: `Remove-Item (Join-Path $stagingRoot 'LastWarAutoScreenshot\Tests') -Recurse -Force -ErrorAction SilentlyContinue`
       - `Remove-Item (Join-Path $stagingRoot 'LastWarAutoScreenshot\Docs') -Recurse -Force -ErrorAction SilentlyContinue`
       - `Remove-Item (Join-Path $stagingRoot 'LastWarAutoScreenshot\lib\test') -Recurse -Force -ErrorAction SilentlyContinue`
     - Copy `scripts\` folder: `Copy-Item -Path (Join-Path $repoRoot 'scripts') -Destination (Join-Path $stagingRoot 'scripts') -Recurse -Force`
     - Copy `LICENSE`: `Copy-Item -Path (Join-Path $repoRoot 'LICENSE') -Destination $stagingRoot -Force`
     - `$zipPath = Join-Path $OutputDir "LastWarAutoScreenshot-v$Version.zip"`
     - Remove existing zip if present
     - `Compress-Archive -Path "$stagingRoot\*" -DestinationPath $zipPath`
     - Remove staging dir
     - Write `"Release zip created: $zipPath"`

   - [x] 6.10: Print post-release checklist:

     ```powershell
     Write-Output ''
     Write-Output '=== Post-release checklist ==='
     Write-Output "  1. Review and commit psd1 changes: git add powershell-module/LastWarAutoScreenshot.psd1 && git commit -m 'chore(release): bump version to $Version'"
     Write-Output "  2. Tag the release:                git tag v$Version"
     Write-Output "  3. Push tag and branch:            git push && git push origin v$Version"
     Write-Output "  4. Upload release zip to GitHub:   $zipPath"
     Write-Output '  5. Create GitHub Release, paste release notes, attach zip.'
     Write-Output '==============================='
     ```

7. [x] Create `powershell-module/Tests/Install-LWAS.Tests.ps1`

   - [x] 7.1: `BeforeAll` block — import module via manifest path; do NOT load
     `Spectre.Console.Testing.dll` (not needed for these tests).

   - [x] 7.2: For all tests: mock the following to prevent side effects:
     - `Test-Path` (scoped to avoid breaking module loading)
     - `Copy-Item`
     - `Remove-Item`
     - `New-Item`
     - `Import-PowerShellDataFile` (return a hashtable with `ModuleVersion = '1.0.0'`)
     - `Test-EventLogSourceExists`
     - `Add-EventLogSource`
     - `Invoke-WebRequest`
     - `Expand-Archive`

   - [x] 7.3: Test: not elevated → `Write-Warning` called; function returns without calling
     `Copy-Item`. Mock `[Security.Principal.WindowsPrincipal]` role check to return `$false`.
     Use `InModuleScope LastWarAutoScreenshot` to access the function.

   - [x] 7.4: Test: elevated + .NET 9.0 present → `dotnet --list-runtimes` mock returns a string
     containing `'Microsoft.NETCore.App 9.'`; confirm no winget call (mock `Start-Process`
     and assert it is not called with id `Microsoft.DotNet.Runtime.9`).

   - [x] 7.5: Test: elevated + .NET 9.0 missing + user answers `'N'` → function returns early;
     `Copy-Item` not called.

   - [x] 7.6: Test: install path does not exist → `Copy-Item` called with destination containing
     the version subfolder `'1.0.0'`.

   - [x] 7.7: Test: install path already exists + user answers `'N'` to overwrite → `Copy-Item`
     not called; `Write-Output` includes `'Installation cancelled.'`

   - [x] 7.8: Test: install path already exists + `-Force` switch → `Copy-Item` called without
     prompting.

   - [x] 7.9: Test: event log source does not exist → `Add-EventLogSource` called with
     `-Source 'LastWarAutoScreenshot'` and `-LogName 'Application'`.

   - [x] 7.10: Test: event log source already exists → `Add-EventLogSource` not called.

   - [x] 7.11: Test: appdata directory does not exist → `New-Item` called with the appdata path.

   - [x] 7.12: Test: appdata directory already exists → `New-Item` not called; output contains
     `'already exists'`.

   - [x] 7.13: Test: both DLLs present → `Invoke-WebRequest` not called; output contains
     `'already present'` for both.

   - [x] 7.14: Test: `Spectre.Console.dll` missing → `Invoke-WebRequest` called with a URL
     matching `'Spectre.Console'` (not `'Spectre.Console.Testing'`).

   - [x] 7.15: Run full Pester suite; confirm count increases from Phase 6 final baseline.

8. [x] Update `powershell-module/Docs/Developer.md` with installation and release documentation

   - [x] 8.1: Add an **Installation** section documenting both install paths:
     - **From a GitHub Release zip:** extract the zip; run `scripts/Install-LWAS.ps1` (self-elevates
       automatically); then use `Import-Module LastWarAutoScreenshot` from any session
     - **From the repo (development):** `Import-Module .\powershell-module\LastWarAutoScreenshot.psd1 -Force`;
       optionally run `Install-LWAS` to register to PSModulePath
     - Document the installed path convention (`$HOME\Documents\PowerShell\Modules\LastWarAutoScreenshot\{version}\`)
     - Document the `-Force` flag for overwriting an existing install

   - [x] 8.2: Add an **Uninstallation** section:
     - Show `scripts/Uninstall-LWAS.ps1` and `scripts/Uninstall-LWAS.ps1 -RemoveAppData`
     - Note that a new session is recommended after uninstall

   - [x] 8.3: Add a **Creating a Release** section:
     - Pre-requisites: all Pester tests passing, psd1 metadata reviewed
     - Command: `scripts/New-LWASRelease.ps1 -Version 'x.y.z' -ReleaseNotes 'Description of changes.'`
     - Output location and post-release checklist steps

   - [x] 8.4: Update `CLAUDE.md` commands section:
     - Add `Install-LWAS` with example (replacing `Install-LWASModule`)
     - Add note about `scripts/Install-LWAS.ps1` for bootstrap use

9. [x] Final validation

   - [x] 9.1: Run the complete, unfiltered Pester suite:
     - Record total test count; must meet or exceed the Phase 6 final baseline plus all new Phase 7
       tests added in task 7
     - 0 failures, 0 errors
     - If any previously-passing test now fails, halt and investigate; do not proceed

   - [x] 9.2: Manually smoke-test `Install-LWAS` in an elevated PowerShell 7 terminal:
     - `Import-Module .\powershell-module\LastWarAutoScreenshot.psd1 -Force`
     - `Install-LWAS`
     - Verify the versioned folder exists at `$HOME\Documents\PowerShell\Modules\LastWarAutoScreenshot\1.0.0\`
     - Verify `Tests\`, `Docs\`, and `lib\test\` are absent from the installed copy
     - Verify `[System.Diagnostics.EventLog]::SourceExists('LastWarAutoScreenshot')` returns `$true`
     - Verify `$env:APPDATA\LastWarAutoScreenshot\` exists
     - Open a new PowerShell session and verify `Import-Module LastWarAutoScreenshot` succeeds
       without specifying a path

   - [x] 9.3: Manually smoke-test `scripts/Install-LWAS.ps1` in a *non-elevated* terminal:
     - Verify it relaunches itself elevated (UAC prompt appears)
     - Verify post-elevation execution completes successfully

   - [x] 9.4: Manually smoke-test `scripts/Uninstall-LWAS.ps1`:
     - Run without `-RemoveAppData`; verify module directories removed from PSModulePath;
       verify event log source removed; verify `$env:APPDATA\LastWarAutoScreenshot\` still exists
     - Run again with `-RemoveAppData`; verify appdata directory removed
     - Run `Get-Module -Name LastWarAutoScreenshot -ListAvailable` in a new session; verify
       nothing returned

   - [x] 9.5: Manually smoke-test `scripts/New-LWASRelease.ps1 -Version '1.0.0' -SkipTests`:
     - Verify psd1 `ModuleVersion` updated to `'1.0.0'`
     - Verify zip created at `releases\LastWarAutoScreenshot-v1.0.0.zip`
     - Inspect zip contents: confirm `LastWarAutoScreenshot\` module folder present;
       `Tests\`, `Docs\`, `lib\test\` absent; `scripts\Install-LWAS.ps1` and
       `scripts\Uninstall-LWAS.ps1` present; `LICENSE` present
     - Revert psd1 change (the real version bump will happen at actual release time)

## Phase 8: Documentation & Examples

1. [ ] Create example configuration files with inline comments
2. [ ] Document window-relative coordinate system
3. [ ] Provide quick start guide with simple working example
4. [ ] Document all exported PowerShell functions as they are created

## Phase 9: Azure Integration (Future)

1. [ ] Prepare for future Azure Blob upload integration:

- Design extensible screenshot saving logic
- SAS token-based authentication
- Exponential backoff with jitter for upload retry logic
- Configurable retry attempts
- Upload failure handling with same retry logic as other operations

## Phase 10: Improvements

10.1 [ ] Inject functions for improved testability

- Investigate improving testability by injecting private functions rather than mocking in every test file
  - All existing config screens call Get-ModuleConfiguration internally.
  - Injecting a $StorageInfo parameter would allow tests to avoid mocking Get-StorageInfo
  - Established project pattern is mock-based injection via InModuleScope rather than parameter injection for internal data.
  - Would it simplify testing to do this?
  - What are the pros and cons of each approach?
  - Which files would need the change?

10.2 [ ] Fix wordwrap workaround in tests

- Many console app tests use workarounds for matching text that wraps onto next line
- This is messy, find a way to resolve this cleanly

10.3 [ ] Spectre.Console screen layout - module configuration

- Put all configuration options on one screen
  - Currently separate screens for each category of config options, overkill. Have all config on one page under category headings
    - Have page 1, page 2 if required - press [F1] previous page, [F2] next page
  - Don't iterate through all options for each category as we currently do, select a single config option on main config page to set it
  - Show user key names not codes for configuration requiring key presses
  -
