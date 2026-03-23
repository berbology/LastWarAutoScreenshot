function Remove-LWASUploadProfile {
    <#
    .SYNOPSIS
        Removes a saved upload profile.

    .DESCRIPTION
        Looks up the named profile and, after optional confirmation, deletes it from
        the profiles directory. Use -Force to skip the interactive prompt.

        Supports -WhatIf: the profile file is not deleted when -WhatIf is active.

    .PARAMETER Name
        Name of the upload profile to remove.

    .PARAMETER Force
        Skips the interactive confirmation prompt.

    .OUTPUTS
        None

    .EXAMPLE
        Remove-LWASUploadProfile -Name 'azure-1'

    .EXAMPLE
        Remove-LWASUploadProfile -Name 'azure-1' -Force

    .EXAMPLE
        Remove-LWASUploadProfile -Name 'azure-1' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [switch]$Force
    )

    $uploadProfile = Get-UploadProfile -Name $Name
    if ($null -eq $uploadProfile) {
        Write-Error "Upload profile '$Name' not found."
        return
    }

    if (-not $Force) {
        $confirmation = Read-Host "Remove upload profile '$Name'? This cannot be undone. [Y/N]"
        if ($confirmation -notin @('Y', 'y')) {
            return
        }
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Remove upload profile')) {
        Remove-UploadProfileFile -Name $Name
        Write-Verbose "Upload profile '$Name' removed."
    }
}
