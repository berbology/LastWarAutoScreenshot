function Get-LWASTargetWindow {
    <#
    .SYNOPSIS
        Finds and returns window objects matching the specified process name and/or window title.

    .DESCRIPTION
        Enumerates all top-level windows via Get-EnumeratedWindows and filters the results by
        the supplied criteria. At least one of -ProcessName or -WindowTitle must be provided.

        If a matching window is minimised, a warning is emitted but the window object is still
        written to the pipeline — the macro runner will restore it automatically at execution time.

        Use -First to restrict output to the first matching window. This is the recommended
        pattern for scheduled-task use where exactly one instance of the game is expected.

    .PARAMETER ProcessName
        Optional. The process name to match against (case-insensitive exact match, e.g. 'lastwar.exe').
        If omitted, all process names are considered.

    .PARAMETER WindowTitle
        Optional. A substring to match against the window title (case-insensitive wildcard,
        equivalent to -ilike "*<value>*"). If omitted, all window titles are considered.

    .PARAMETER First
        Optional switch. When present, only the first matching window object is written to the
        pipeline. Intended for scheduled-task use where exactly one game instance is expected.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One or more window objects with properties: ProcessName, WindowTitle, WindowHandle, PID,
        WindowState.

    .EXAMPLE
        # Scheduled-task use: find exactly one instance of the game
        $window = Get-LWASTargetWindow -ProcessName 'lastwar.exe' -First
        $window | Start-LWASAutomationSequence -MacroName 'DailyLogin'

    .EXAMPLE
        # Interactive/multi-instance use: inspect all matching windows
        Get-LWASTargetWindow -ProcessName 'lastwar.exe'

    .EXAMPLE
        # Filter by title substring
        Get-LWASTargetWindow -WindowTitle 'Last War'
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter()]
        [string]$ProcessName,

        [Parameter()]
        [string]$WindowTitle,

        [Parameter()]
        [switch]$First
    )

    # Validate: at least one filter must be supplied
    if ([string]::IsNullOrEmpty($ProcessName) -and [string]::IsNullOrEmpty($WindowTitle)) {
        Write-Error 'At least one of -ProcessName or -WindowTitle must be specified.'
        return
    }

    # Enumerate all windows, then apply filters
    $allWindows = @(Get-EnumeratedWindows)

    $filtered = $allWindows

    if (-not [string]::IsNullOrEmpty($ProcessName)) {
        # Normalise away any .exe suffix so that 'Notepad.exe' matches a ProcessName of 'Notepad'
        # (Get-Process strips .exe from ProcessName; callers may or may not include it)
        $normalizedFilter = $ProcessName -replace '\.exe$', ''
        $filtered = @($filtered | Where-Object { ($_.ProcessName -replace '\.exe$', '') -ilike $normalizedFilter })
    }

    if (-not [string]::IsNullOrEmpty($WindowTitle)) {
        $filtered = @($filtered | Where-Object { $_.WindowTitle -ilike "*$WindowTitle*" })
    }

    if ($filtered.Count -eq 0) {
        Write-Error 'No window found matching the specified criteria.'
        return
    }

    # Restrict to first match when -First is supplied
    if ($First) {
        $filtered = @($filtered[0])
    }

    foreach ($w in $filtered) {
        if ($w.WindowState -eq 'Minimised') {
            Write-Warning "Window '$($w.WindowTitle)' (PID $($w.PID)) is minimised. It will be restored automatically when the macro runs."
        }
        Write-Output $w
    }
}
