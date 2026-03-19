function Get-LWASMonitorProcess {
    <#
    .SYNOPSIS
        Returns the System.Diagnostics.Process object for a running process by ID.

    .DESCRIPTION
        Wraps [System.Diagnostics.Process]::GetProcessById to retrieve a process
        for use in window and process monitoring. Returns $null and logs a warning
        if the process cannot be found (e.g. it has exited since the ID was captured).

    .PARAMETER ProcessId
        The numeric process ID to retrieve.

    .OUTPUTS
        System.Diagnostics.Process
        The process object if found, or $null if the process does not exist or
        an error occurs.

    .EXAMPLE
        $process = Get-LWASMonitorProcess -ProcessId 12345
        if ($null -eq $process) {
            Write-Warning 'Process no longer running.'
        }

    .EXAMPLE
        $window = Get-LWASTargetWindow -ProcessName 'LastWar' -First
        $process = Get-LWASMonitorProcess -ProcessId $window.ProcessId
    #>
    [CmdletBinding()]
    param(
        [int]$ProcessId
    )
    try {
        return [System.Diagnostics.Process]::GetProcessById($ProcessId)
    } catch {
        Write-LastWarLog -Message "Failed to get process for monitoring: $_" -Level Warning -FunctionName 'Start-WindowAndProcessMonitor' -Context "ProcessId: $ProcessId"
        return $null
    }
}

