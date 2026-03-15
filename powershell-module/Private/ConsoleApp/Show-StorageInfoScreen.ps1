function Show-StorageInfoScreen {
    <#
    .SYNOPSIS
        Displays screenshot storage status and log file usage in two distinct sections.

    .DESCRIPTION
        Uses Get-StorageInfo and Get-ModuleConfiguration to retrieve current storage and
        logging state.  The screen is divided into two sections:

        Section 1 — Screenshot Storage and Section 2 — Log Files are displayed
        side-by-side using a Spectre.Console Columns layout (falls back to stacked when
        the terminal is too narrow).

        Section 1 — Screenshot Storage:
          Not configured (IsConfigured = $false):
            - Displays an information panel titled 'Screenshot Storage' prompting the user
              to configure a storage path via Configure Module → Screenshot settings.
          Configured (IsConfigured = $true):
            - If storage usage is at or above 90 % of the configured maximum, a full-width
              yellow warning panel is shown before the columns.
            - A Table titled 'Screenshot Storage' summarises Used GB, Max GB, % Used, and
              the number of screenshot files with their date range.
            - If disk free space is below 5 GB (and DriveInfo did not fail), a full-width
              low disk space warning panel is shown after the columns.

        Section 2 — Log Files:
          When Logging.Backend contains 'File' (i.e. File or File,EventLog):
            - A table titled 'Log Files' shows Log Files GB and Disk space (GB free / GB total).
          When Logging.Backend is 'EventLog' only:
            - An info panel titled 'Log Files' states that no log files are written to disk.

        After the columns, a BreakdownChart visualises used vs free storage proportionally
        (only shown when IsConfigured = $true).

        Navigation:
          '[[Back]]'                           -> returns to the calling screen.
          'Open log folder in Explorer'        -> launches Explorer at the module root log
                                                 folder (only shown when Logging.Backend
                                                 includes 'File').
          'Open screenshot folder in Explorer' -> launches Explorer at the storage path
                                                 (only shown when IsConfigured = $true).

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for all rendering and input.
        Pass [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole() for production use,
        or a [Spectre.Console.Testing.TestConsole]::new() instance in Pester tests.

    .OUTPUTS
        None

    .EXAMPLE
        $console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        Show-StorageInfoScreen -Console $console

    .NOTES
        The $Console parameter is the testability injection point.  All rendering and input
        is routed through this interface so Pester tests can inject a TestConsole and assert
        on its Output property without requiring a live terminal.

        BreakdownChart is available in Spectre.Console 0.40 and later.  This module bundles
        Spectre.Console 0.54.0 (see lib/VERSIONS.txt), so BreakdownChart is always available.
        Items are added via [Spectre.Console.BreakdownChartExtensions]::AddItem, which is the
        same static extension-method calling pattern used for TableExtensions.AddRow throughout
        this module.

        The low disk space warning is suppressed when DiskFreeGB is exactly 0.0 (which
        indicates that DriveInfo failed, e.g. for a UNC path) to avoid false positives.
        It is only shown when 0.0 < DiskFreeGB < 5.0.

        Date formatting for screenshot date range uses 'dd/MM/yy HH:mm' in UTC, consistent
        with the DisplayDate format used elsewhere in the module.

        Navigation uses '[[Back]]' (double brackets for Spectre display) but the switch
        default branch handles the returned single-bracket value '[Back]' — no explicit
        string comparison against '[Back]' is needed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    # ── Load current configuration and live storage info ──────────────────────
    $config      = Get-ModuleConfiguration
    $storageInfo = Get-StorageInfo

    # ── Section 1: Screenshot Storage — build renderable ──────────────────────
    $screenshotRenderable = $null

    if (-not $storageInfo.IsConfigured) {
        $screenshotRenderable = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
            'Screenshot storage path is not yet configured. Set it in Configure Module -> Screenshot settings.',
            'Screenshot Storage'
        )
    }
    else {
        # If storage is almost full, show a prominent full-width warning first
        if ($storageInfo.UsedPercent -ge 90.0) {
            $warningPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'Screenshot storage is over 90% full. Consider increasing the limit or clearing old screenshots.',
                '[yellow]Warning: Storage Almost Full[/]'
            )
            $Console.Write($warningPanel)
        }

        # Summary table of live usage metrics
        $usedGB     = $storageInfo.UsedGB
        $usageTable = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(@('Metric', 'Value'))
        $usageTable.Title = [Spectre.Console.TableTitle]::new('Screenshot Storage')

        [Spectre.Console.TableExtensions]::AddRow(
            $usageTable,
            [string[]]@('Used GB', [Spectre.Console.Markup]::Escape("$([math]::Round($usedGB, 3))"))
        ) | Out-Null
        [Spectre.Console.TableExtensions]::AddRow(
            $usageTable,
            [string[]]@('Max GB', [Spectre.Console.Markup]::Escape("$($storageInfo.MaxGB)"))
        ) | Out-Null
        [Spectre.Console.TableExtensions]::AddRow(
            $usageTable,
            [string[]]@('% Used', [Spectre.Console.Markup]::Escape("$([math]::Round($storageInfo.UsedPercent, 1)) %"))
        ) | Out-Null

        $screenshotRowValue = "$($storageInfo.ScreenshotCount) file(s)"
        if ($storageInfo.ScreenshotCount -gt 0) {
            $oldestStr           = $storageInfo.OldestScreenshotDate.ToString('dd/MM/yy HH:mm')
            $newestStr           = $storageInfo.NewestScreenshotDate.ToString('dd/MM/yy HH:mm')
            $screenshotRowValue += " - oldest: $oldestStr UTC, newest: $newestStr UTC"
        }
        [Spectre.Console.TableExtensions]::AddRow(
            $usageTable,
            [string[]]@('Screenshots', [Spectre.Console.Markup]::Escape($screenshotRowValue))
        ) | Out-Null

        $screenshotRenderable = $usageTable
    }

    # ── Section 2: Log Files — build renderable ───────────────────────────────
    $loggingBackend = $config.Logging.Backend
    $logRenderable  = $null

    if ($loggingBackend -like '*File*') {
        $logTable = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(@('Metric', 'Value'))
        $logTable.Title = [Spectre.Console.TableTitle]::new('Log Files')

        [Spectre.Console.TableExtensions]::AddRow(
            $logTable,
            [string[]]@('Log Files GB', [Spectre.Console.Markup]::Escape("$([math]::Round($storageInfo.LogFileSizeGB, 3))"))
        ) | Out-Null
        [Spectre.Console.TableExtensions]::AddRow(
            $logTable,
            [string[]]@('Disk space', [Spectre.Console.Markup]::Escape("$($storageInfo.DiskFreeGB) GB free of $($storageInfo.DiskTotalGB) GB total"))
        ) | Out-Null

        $logRenderable = $logTable
    }
    else {
        $logRenderable = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
            'Event log backend is active - no log files are written to disk.',
            'Log Files'
        )
    }

    # ── Render both sections side-by-side ─────────────────────────────────────
    $sideBySection = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateColumns($screenshotRenderable, $logRenderable)
    $Console.Write($sideBySection)
    

    # Low disk space warning (full-width, only when DriveInfo succeeded and free space is critically low)
    if ($storageInfo.IsConfigured -and $storageInfo.DiskFreeGB -lt 5.0 -and $storageInfo.DiskFreeGB -gt 0.0) {
        $lowDiskPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
            "Disk is running low: $($storageInfo.DiskFreeGB) GB free remaining. Consider clearing old screenshots or moving the storage path.",
            '[yellow]Warning: Low Disk Space[/]'
        )
        $Console.Write($lowDiskPanel)
    }

    # ── BreakdownChart: proportional visualisation of used vs free storage ────
    if ($storageInfo.IsConfigured) {
        $usedGB = $storageInfo.UsedGB
        $freeGB = [math]::Max(0.0, $storageInfo.MaxGB - $usedGB)

        $chart = [Spectre.Console.BreakdownChart]::new()

        if ($usedGB -gt 0.0) {
            [Spectre.Console.BreakdownChartExtensions]::AddItem(
                $chart,
                "Used ($([math]::Round($usedGB, 2)) GB)",
                $usedGB,
                [Spectre.Console.Color]::Red
            ) | Out-Null
        }

        [Spectre.Console.BreakdownChartExtensions]::AddItem(
            $chart,
            "Free ($([math]::Round($freeGB, 2)) GB)",
            [math]::Max($freeGB, 0.001),
            [Spectre.Console.Color]::Green
        ) | Out-Null

        [LastWarAutoScreenshot.ConsoleAppBridge]::WriteBlankLine($Console)
        $Console.Write($chart)
        [LastWarAutoScreenshot.ConsoleAppBridge]::WriteBlankLine($Console)
    }

    # ── Navigation ────────────────────────────────────────────────────────────
    $storePath  = $config.Screenshots.StoragePath

    $navChoices = [System.Collections.Generic.List[string]]::new()
    $navChoices.Add('[[Back]]')
    if ($loggingBackend -like '*File*') {
        $navChoices.Add('Open log folder in Explorer')
    }
    if ($storageInfo.IsConfigured) {
        $navChoices.Add('Open screenshot folder in Explorer')
    }

    $navPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
        'Choose an option:',
        $navChoices.ToArray()
    )
    $navChoice = $navPrompt.Show($Console)

    switch ($navChoice) {
        'Open log folder in Explorer' {
            Start-Process -FilePath 'explorer.exe' -ArgumentList $script:ModuleRootPath
            $Console.Write([Spectre.Console.Markup]::new("[green]Opening log folder in Explorer...`n[/]"))
        }
        'Open screenshot folder in Explorer' {
            Start-Process -FilePath 'explorer.exe' -ArgumentList $storePath
            $Console.Write([Spectre.Console.Markup]::new("[green]Opening screenshot folder in Explorer...`n[/]"))
        }
        default {
            # '[Back]' - return to calling screen
            return
        }
    }
}

