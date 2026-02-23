function Show-StorageInfoScreen {
    <#
    .SYNOPSIS
        Stub for the Storage and log file info screen. To be implemented in Phase 6, task 6.3.

    .DESCRIPTION
        Will display a Spectre.Console BreakdownChart showing used vs free screenshot
        storage, current storage configuration values in a Table, and prompts to update
        StoragePath and MaxStorageGB.  A warning panel is shown when storage usage exceeds
        90% of the configured limit.

        Data is sourced from Get-StorageInfo (to be implemented in Phase 6, task 6.2).
        Save/discard options follow the same pattern as Show-LoggingConfigScreen.

        Not yet implemented - displays a "Not yet available" panel when called.

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for rendering and input.

    .OUTPUTS
        None

    .EXAMPLE
        $console = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        Show-StorageInfoScreen -Console $console

    .NOTES
        Implementation scheduled for Phase 6, task 6.3.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    $stubPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel(
        'Storage and log file information is not yet available. This screen will be implemented in Phase 6, task 6.3.',
        'Storage & Log File Info'
    )
    $Console.Write($stubPanel)
}

