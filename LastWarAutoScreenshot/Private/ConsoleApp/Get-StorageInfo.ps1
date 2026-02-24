function Get-StorageInfo {
    <#
    .SYNOPSIS
        Retrieves current storage usage information for screenshots and log files.

    .DESCRIPTION
        Reads the configured screenshot storage path and maximum storage limit from the
        module configuration.  Returns an object describing whether storage is configured,
        how much space has been used, and the size of current log files.

        If Screenshots.StoragePath is empty, $null, or the path does not exist on disk,
        returns an IsConfigured=$false object with all numeric properties set to 0.0.

        When the path is accessible, recursively sums all files within it to compute used
        storage in GB and the percentage of the user-configured maximum.  The log file
        size is computed separately by collecting all 'LastWarAutoScreenshot.log*' files
        from the module root directory (where the FileLogBackend writes by convention).

        If the storage folder exists but cannot be read (e.g. access is denied), the
        function logs an Error entry via Write-LastWarLog and returns IsConfigured=$false.

    .OUTPUTS
        PSCustomObject with the following properties:
            IsConfigured  ([bool])   : $true when StoragePath is set and readable
            UsedGB        ([double]) : Total screenshot folder size in gigabytes
            MaxGB         ([double]) : Configured maximum storage limit in gigabytes
            UsedPercent   ([double]) : Percentage of MaxGB currently used (0.0 - 100.0+)
            LogFileSizeGB ([double]) : Combined size of all log files in gigabytes

    .EXAMPLE
        $info = Get-StorageInfo
        if ($info.IsConfigured) {
            Write-Host "Storage: $([math]::Round($info.UsedPercent, 1))% used of $($info.MaxGB) GB"
        } else {
            Write-Host 'Screenshot storage is not yet configured.'
        }

    .NOTES
        Pure PowerShell - no Add-Type or P/Invoke required.

        StoragePath is sourced from Screenshots.StoragePath in the module configuration.
        MaxStorageGB is sourced from Screenshots.MaxStorageGB.

        Log file size is computed from all files matching 'LastWarAutoScreenshot.log*' in
        $script:ModuleRootPath (the folder containing LastWarAutoScreenshot.psm1).  This
        covers both the active log file and any size/age rollover archives produced by
        FileLogBackend.

        UsedPercent may exceed 100.0 when actual usage surpasses the configured limit.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $emptyResult = [PSCustomObject]@{
        IsConfigured  = $false
        UsedGB        = 0.0
        MaxGB         = 0.0
        UsedPercent   = 0.0
        LogFileSizeGB = 0.0
    }

    $config       = Get-ModuleConfiguration
    $storagePath  = $config.Screenshots.StoragePath
    $maxStorageGB = [double]$config.Screenshots.MaxStorageGB

    # Defensive null/empty check - StoragePath is '' when not yet configured; $null is treated the same
    if ([string]::IsNullOrWhiteSpace($storagePath)) {
        Write-Verbose 'Get-StorageInfo: Screenshots.StoragePath is not configured - returning empty result.'
        return $emptyResult
    }

    # Directory must exist before we attempt to measure it
    if (-not (Test-Path -Path $storagePath -PathType Container)) {
        Write-Verbose "Get-StorageInfo: Storage path '$storagePath' does not exist on disk - returning empty result."
        return $emptyResult
    }

    # Compute log file folder size from module root
    # Covers: LastWarAutoScreenshot.log  +  LastWarAutoScreenshot.log.<timestamp> rollover archives
    $logFileSizeGB = 0.0
    try {
        $logBytes = (Get-ChildItem -Path $script:ModuleRootPath -Filter 'LastWarAutoScreenshot.log*' -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
        if ($null -ne $logBytes) {
            $logFileSizeGB = [double]($logBytes / 1GB)
        }
    }
    catch {
        Write-Verbose "Get-StorageInfo: Could not calculate log file size: $_"
    }

    # Compute screenshot storage usage - any read failure is caught below
    try {
        $storageBytes = (Get-ChildItem -Path $storagePath -Recurse -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum

        $usedGB      = if ($null -ne $storageBytes) { [double]($storageBytes / 1GB) } else { 0.0 }
        $usedPercent = if ($maxStorageGB -gt 0.0) { [double]($usedGB / $maxStorageGB * 100.0) } else { 0.0 }

        Write-Verbose "Get-StorageInfo: UsedGB=$usedGB, MaxGB=$maxStorageGB, UsedPercent=$usedPercent, LogFileSizeGB=$logFileSizeGB"

        return [PSCustomObject]@{
            IsConfigured  = $true
            UsedGB        = $usedGB
            MaxGB         = $maxStorageGB
            UsedPercent   = $usedPercent
            LogFileSizeGB = $logFileSizeGB
        }
    }
    catch {
        Write-LastWarLog -Level Error `
            -Message "Failed to read screenshot storage path '$storagePath': $_" `
            -FunctionName 'Get-StorageInfo' `
            -Context "Path: $storagePath"
        return $emptyResult
    }
}
