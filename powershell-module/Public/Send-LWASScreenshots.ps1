function Send-LWASScreenshots {
    <#
    .SYNOPSIS
        Uploads local screenshot files to Azure Blob Storage.

    .DESCRIPTION
        Enumerates files in the specified folder (or the configured screenshots
        StoragePath) and uploads each one via the named upload profile. Displays
        a progress bar during upload.

        After uploading, optionally deletes successfully uploaded files
        (DeleteLocalAfterUpload) and removes files older than a threshold
        (DeleteLocalAfterDays), both controlled by the profile settings.

        Supports -WhatIf: no files are uploaded or deleted when -WhatIf is active.

    .PARAMETER UploadProfileName
        Name of the upload profile to use.

    .PARAMETER FolderPath
        Folder containing the screenshots to upload. Defaults to the Screenshots
        StoragePath from the module configuration when not supplied.

    .PARAMETER Filter
        File name filter passed to Get-ChildItem. Defaults to '*.png'.

    .OUTPUTS
        None

    .EXAMPLE
        Send-LWASScreenshots -UploadProfileName 'azure-1'

    .EXAMPLE
        Send-LWASScreenshots -UploadProfileName 'azure-1' -FolderPath 'C:\Screenshots' `
            -Filter '*.png' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$UploadProfileName,

        [Parameter()]
        [string]$FolderPath,

        [Parameter()]
        [string]$Filter = '*.png'
    )

    # Load profile
    $uploadProfile = Get-UploadProfile -Name $UploadProfileName
    if ($null -eq $uploadProfile) {
        Write-Error "Upload profile '$UploadProfileName' not found."
        return
    }

    # Resolve FolderPath
    if (-not $PSBoundParameters.ContainsKey('FolderPath')) {
        $FolderPath = (Get-ModuleConfiguration).Screenshots.StoragePath
    }
    if ([string]::IsNullOrWhiteSpace($FolderPath)) {
        Write-Error "No folder path supplied and Screenshots StoragePath is not configured in the module settings."
        return
    }
    if (-not (Test-Path -LiteralPath $FolderPath)) {
        Write-Warning "Folder '$FolderPath' does not exist."
        return
    }

    # Resolve SAS token — check Process, User, then Machine scope.
    $sasEnvVarName = $uploadProfile.sasTokenEnvVar
    $sasToken = [Environment]::GetEnvironmentVariable($sasEnvVarName) `
        ?? [Environment]::GetEnvironmentVariable($sasEnvVarName, [EnvironmentVariableTarget]::User) `
        ?? [Environment]::GetEnvironmentVariable($sasEnvVarName, [EnvironmentVariableTarget]::Machine)
    if ([string]::IsNullOrEmpty($sasToken)) {
        Write-Error "Environment variable '$($uploadProfile.sasTokenEnvVar)' is not set. Set it to the SAS token before running an upload."
        return
    }

    # Enumerate files
    $files = @(Get-ChildItem -Path $FolderPath -Filter $Filter -File -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) {
        Write-Verbose "No files matching '$Filter' found in '$FolderPath'."
    }

    $totalCount   = $files.Count
    $successCount = 0
    $failureCount = 0

    for ($i = 0; $i -lt $files.Count; $i++) {
        $file           = $files[$i]
        $percentComplete = [int](($i / $totalCount) * 100)
        Write-Progress -Activity 'Uploading screenshots' -Status $file.Name -PercentComplete $percentComplete

        if ($PSCmdlet.ShouldProcess($file.FullName, "Upload to profile '$UploadProfileName'")) {
            $blobPath = Resolve-BlobPath `
                -BlobPathPattern $uploadProfile.blobPathPattern `
                -MacroName       $UploadProfileName `
                -Filename        $file.Name

            $uploadResult = Invoke-AzureBlobUpload `
                -FilePath         $file.FullName `
                -AccountName      $uploadProfile.accountName `
                -ContainerName    $uploadProfile.containerName `
                -BlobPath         $blobPath `
                -SasToken         $sasToken `
                -MaxRetryAttempts $uploadProfile.maxRetryAttempts `
                -RetryBaseDelayMs $uploadProfile.retryBaseDelayMs

            if ($uploadResult.Success -eq $true) {
                $successCount++
                if ($uploadProfile.deleteLocalAfterUpload -eq $true) {
                    Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                }
            } else {
                $failureCount++
                Write-LastWarLog -Level Warning -FunctionName 'Send-LWASScreenshots' `
                    -Message "Failed to upload '$($file.Name)': $($uploadResult.Message)"
            }
        }
    }

    Write-Progress -Activity 'Uploading screenshots' -Completed

    # DeleteLocalAfterDays cleanup
    $storePath = (Get-ModuleConfiguration).Screenshots.StoragePath
    if (-not [string]::IsNullOrWhiteSpace($storePath) -and (Test-Path -LiteralPath $storePath)) {
        $cutoff  = (Get-Date).AddDays(-$uploadProfile.deleteLocalAfterDays)
        $oldFiles = @(Get-ChildItem -Path $storePath -File -ErrorAction SilentlyContinue |
                      Where-Object { $_.LastWriteTime -lt $cutoff })
        foreach ($oldFile in $oldFiles) {
            Remove-Item -LiteralPath $oldFile.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    # Summary
    Write-Verbose "Uploaded $successCount of $totalCount files."
    if ($failureCount -gt 0) {
        Write-Warning "Failed to upload $failureCount file(s). Check the log for details."
    }
}
