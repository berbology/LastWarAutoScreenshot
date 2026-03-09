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
            IsConfigured         ([bool])     : $true when StoragePath is set and readable
            UsedGB               ([double])   : Total screenshot folder size in gigabytes
            MaxGB                ([double])   : Configured maximum storage limit in gigabytes
            UsedPercent          ([double])   : Percentage of MaxGB currently used (0.0 - 100.0+)
            LogFileSizeGB        ([double])   : Combined size of all log files in gigabytes
            DiskFreeGB           ([double])   : Available free space on the storage drive in gigabytes (rounded to 2dp). 0.0 if DriveInfo throws.
            DiskTotalGB          ([double])   : Total size of the storage drive in gigabytes (rounded to 2dp). 0.0 if DriveInfo throws.
            ScreenshotCount      ([int])      : Number of PNG/JPG/JPEG files found recursively under StoragePath. 0 if not configured.
            OldestScreenshotDate ([datetime]) : LastWriteTimeUtc of the oldest screenshot file, or $null when ScreenshotCount is 0.
            NewestScreenshotDate ([datetime]) : LastWriteTimeUtc of the newest screenshot file, or $null when ScreenshotCount is 0.

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
        IsConfigured         = $false
        UsedGB               = 0.0
        MaxGB                = 0.0
        UsedPercent          = 0.0
        LogFileSizeGB        = 0.0
        DiskFreeGB           = 0.0
        DiskTotalGB          = 0.0
        ScreenshotCount      = 0
        OldestScreenshotDate = $null
        NewestScreenshotDate = $null
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
        $allFiles     = @(Get-ChildItem -Path $storagePath -Recurse -File -ErrorAction SilentlyContinue)
        $storageBytes = ($allFiles | Measure-Object -Property Length -Sum).Sum

        $usedGB      = if ($null -ne $storageBytes) { [double]($storageBytes / 1GB) } else { 0.0 }
        $usedPercent = if ($maxStorageGB -gt 0.0) { [double]($usedGB / $maxStorageGB * 100.0) } else { 0.0 }

        # Screenshot files (PNG / JPG / JPEG) - derived from the cached file list to avoid a second Get-ChildItem call
        $screenshotFiles = @($allFiles | Where-Object { $_.Extension -iin @('.png', '.jpg', '.jpeg') })
        $screenshotCount = $screenshotFiles.Count
        $oldestDate      = if ($screenshotCount -gt 0) {
            ($screenshotFiles | Sort-Object LastWriteTimeUtc | Select-Object -First 1).LastWriteTimeUtc
        } else { $null }
        $newestDate      = if ($screenshotCount -gt 0) {
            ($screenshotFiles | Sort-Object LastWriteTimeUtc | Select-Object -Last 1).LastWriteTimeUtc
        } else { $null }

        # Disk space information from the drive hosting the storage path
        $diskFreeGB  = 0.0
        $diskTotalGB = 0.0
        try {
            $driveInfo   = [System.IO.DriveInfo]::new($storagePath.Substring(0, 1))
            $diskFreeGB  = [math]::Round($driveInfo.AvailableFreeSpace / 1GB, 2)
            $diskTotalGB = [math]::Round($driveInfo.TotalSize / 1GB, 2)
        } catch {
            Write-Verbose "Get-StorageInfo: Could not retrieve drive info: $_"
        }

        Write-Verbose "Get-StorageInfo: UsedGB=$usedGB, MaxGB=$maxStorageGB, UsedPercent=$usedPercent, LogFileSizeGB=$logFileSizeGB, DiskFreeGB=$diskFreeGB, DiskTotalGB=$diskTotalGB, ScreenshotCount=$screenshotCount"

        return [PSCustomObject]@{
            IsConfigured         = $true
            UsedGB               = $usedGB
            MaxGB                = $maxStorageGB
            UsedPercent          = $usedPercent
            LogFileSizeGB        = $logFileSizeGB
            DiskFreeGB           = $diskFreeGB
            DiskTotalGB          = $diskTotalGB
            ScreenshotCount      = $screenshotCount
            OldestScreenshotDate = $oldestDate
            NewestScreenshotDate = $newestDate
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
