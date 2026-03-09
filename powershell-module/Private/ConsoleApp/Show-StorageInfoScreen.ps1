function Show-StorageInfoScreen {
    <#
    .SYNOPSIS
        Displays current screenshot storage and log file usage information, and provides
        navigation to related screens.

    .DESCRIPTION
        Uses Get-StorageInfo to retrieve the current storage state.  The screen behaves
        differently depending on whether storage has already been configured:

        Not configured (IsConfigured = $false):
          - Displays an information panel prompting the user to configure a storage path.

        Configured (IsConfigured = $true):
          - If storage usage is at or above 90 % of the configured maximum, a yellow
            warning panel is shown first.
          - A BreakdownChart visualises used vs free storage proportionally.
          - A Table summarises Used GB, Max GB, % Used, Log Files GB, Disk space, and
            the number of screenshot files with their date range.
          - If disk free space is below 5 GB (and DriveInfo did not fail), a low disk
            space warning panel is shown.

        Always: a SelectionPrompt offers navigation choices:
          '[[Back]]'                           -> returns to the calling screen.
          'Configure screenshot settings'      -> navigates to Show-ScreenshotConfigScreen.
          'Open storage folder in Explorer'    -> launches Explorer at the storage path
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
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    # ── Load current configuration and live storage info ──────────────────────
    $config      = Get-ModuleConfiguration
    $storageInfo = Get-StorageInfo

    # ── Step 1: Storage status - chart/table or not-configured panel ──────────
    if (-not $storageInfo.IsConfigured) {
        $infoPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
            'Screenshot storage path is not yet configured. Set it in the Screenshots section below.',
            'Storage & Log File Info'
        )
        $Console.Write($infoPanel)
    }
    else {
        # If storage is almost full, show a prominent warning before anything else
        if ($storageInfo.UsedPercent -ge 90.0) {
            $warningPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                'Screenshot storage is over 90% full. Consider increasing the limit or clearing old screenshots.',
                '[yellow]Warning: Storage Almost Full[/]'
            )
            $Console.Write($warningPanel)
        }

        # BreakdownChart: proportional visualisation of used vs free storage
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

        $Console.Write($chart)

        # Summary table of live usage metrics
        $usageTable = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(@('Metric', 'Value'))

        [Spectre.Console.TableExtensions]::AddRow(
            $usageTable,
            [string[]]@('Used GB',      [Spectre.Console.Markup]::Escape("$([math]::Round($usedGB, 3))"))
        ) | Out-Null
        [Spectre.Console.TableExtensions]::AddRow(
            $usageTable,
            [string[]]@('Max GB',       [Spectre.Console.Markup]::Escape("$($storageInfo.MaxGB)"))
        ) | Out-Null
        [Spectre.Console.TableExtensions]::AddRow(
            $usageTable,
            [string[]]@('% Used',       [Spectre.Console.Markup]::Escape("$([math]::Round($storageInfo.UsedPercent, 1)) %"))
        ) | Out-Null
        [Spectre.Console.TableExtensions]::AddRow(
            $usageTable,
            [string[]]@('Log Files GB', [Spectre.Console.Markup]::Escape("$([math]::Round($storageInfo.LogFileSizeGB, 3))"))
        ) | Out-Null
        [Spectre.Console.TableExtensions]::AddRow(
            $usageTable,
            [string[]]@('Disk space',   [Spectre.Console.Markup]::Escape("$($storageInfo.DiskFreeGB) GB free of $($storageInfo.DiskTotalGB) GB total"))
        ) | Out-Null

        $screenshotRowValue = "$($storageInfo.ScreenshotCount) file(s)"
        if ($storageInfo.ScreenshotCount -gt 0) {
            $oldestStr           = $storageInfo.OldestScreenshotDate.ToString('dd/MM/yy HH:mm')
            $newestStr           = $storageInfo.NewestScreenshotDate.ToString('dd/MM/yy HH:mm')
            $screenshotRowValue += " — oldest: $oldestStr UTC, newest: $newestStr UTC"
        }
        [Spectre.Console.TableExtensions]::AddRow(
            $usageTable,
            [string[]]@('Screenshots',  [Spectre.Console.Markup]::Escape($screenshotRowValue))
        ) | Out-Null

        $Console.Write($usageTable)

        # Low disk space warning (only when DriveInfo succeeded and free space is critically low)
        if ($storageInfo.DiskFreeGB -lt 5.0 -and $storageInfo.DiskFreeGB -gt 0.0) {
            $lowDiskPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
                "Disk is running low: $($storageInfo.DiskFreeGB) GB free remaining. Consider clearing old screenshots or moving the storage path.",
                '[yellow]Warning: Low Disk Space[/]'
            )
            $Console.Write($lowDiskPanel)
        }
    }

    # ── Navigation ────────────────────────────────────────────────────────────
    $storePath  = $config.Screenshots.StoragePath

    $navChoices = [System.Collections.Generic.List[string]]::new()
    $navChoices.Add('[[Back]]')
    $navChoices.Add('Configure screenshot settings')
    if ($storageInfo.IsConfigured) {
        $navChoices.Add('Open storage folder in Explorer')
    }

    $navPrompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
        'Choose an option:',
        $navChoices.ToArray()
    )
    $navChoice = $navPrompt.Show($Console)

    switch ($navChoice) {
        'Configure screenshot settings' {
            Show-ScreenshotConfigScreen -Console $Console
        }
        'Open storage folder in Explorer' {
            Start-Process -FilePath 'explorer.exe' -ArgumentList $storePath
            $Console.Write([Spectre.Console.Markup]::new("[green]Opening storage folder in Explorer...`n[/]"))
        }
        default {
            # '[Back]' - return to calling screen
            return
        }
    }
}
