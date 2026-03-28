function Rename-LWASUploadProfile {
    <#
    .SYNOPSIS
        Renames an existing upload profile file without modifying its contents or SAS token.

    .DESCRIPTION
        Renames the JSON file that backs a named upload profile by removing the old file and
        writing a new one under the new name. The profile's internal 'name' field is updated
        to match. No other fields — including sasTokenEnvVar — are altered.

        This is intentionally narrower than Remove-LWASUploadProfile: the SAS token is never
        touched, because the profile is being renamed, not deleted. If the old name equals the
        new name the function returns immediately without writing anything.

        Supports -WhatIf: the old file is not removed and the new file is not written when
        -WhatIf is active.

    .PARAMETER Name
        The current name of the upload profile to rename.

    .PARAMETER NewName
        The new name to assign to the upload profile. Must not already be in use by another
        profile.

    .PARAMETER ProfileDirectory
        Directory that contains the profile JSON files. Defaults to
        $env:APPDATA\LastWarAutoScreenshot\UploadProfiles.

    .OUTPUTS
        None

    .EXAMPLE
        Rename-LWASUploadProfile -Name 'azure-1' -NewName 'azure-prod'

    .EXAMPLE
        Rename-LWASUploadProfile -Name 'azure-1' -NewName 'azure-prod' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$NewName,

        [Parameter()]
        [string]$ProfileDirectory = (Join-Path $env:APPDATA 'LastWarAutoScreenshot\UploadProfiles')
    )

    if ($Name -eq $NewName) {
        return
    }

    $existingProfile = Get-UploadProfile -Name $Name -ProfileDirectory $ProfileDirectory
    if ($null -eq $existingProfile) {
        Write-Error "Upload profile '$Name' not found."
        return
    }

    $conflictingProfile = Get-UploadProfile -Name $NewName -ProfileDirectory $ProfileDirectory
    if ($null -ne $conflictingProfile) {
        Write-Error "An upload profile named '$NewName' already exists."
        return
    }

    if ($PSCmdlet.ShouldProcess("'$Name' -> '$NewName'", 'Rename upload profile')) {
        $oldFilePath = Join-Path $ProfileDirectory "$Name.json"
        Remove-Item -LiteralPath $oldFilePath -Force -ErrorAction SilentlyContinue

        $existingProfile.name = $NewName
        Save-UploadProfileFile -UploadProfile $existingProfile -ProfileDirectory $ProfileDirectory

        Write-LastWarLog -Level Info `
            -Message "Upload profile renamed from '$Name' to '$NewName'." `
            -FunctionName 'Rename-LWASUploadProfile'
    }
}
