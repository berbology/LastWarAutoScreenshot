function Assert-LWASAzStorageModule {
    <#
    .SYNOPSIS
        Ensures the Az.Storage PowerShell module is installed and imported.

    .DESCRIPTION
        Checks whether Az.Storage is available on the system. If not installed,
        prompts the user to install it (interactive) or emits an error (non-interactive).
        If installed but not yet imported into the current session, imports it.

        Returns $true when Az.Storage is ready to use; returns $false (after writing
        a Write-Error) in every failure path. Callers should guard with:

            if (-not (Assert-LWASAzStorageModule)) { return $false }

        This is the single point of entry for Az.Storage readiness. Every function
        that invokes an Az.Storage cmdlet must call this first.

    .OUTPUTS
        System.Boolean
        $true when Az.Storage is installed and imported; $false on any failure.

    .EXAMPLE
        if (-not (Assert-LWASAzStorageModule)) { return $false }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Step 1: Check whether Az.Storage is installed
    $available = Get-Module -Name Az.Storage -ListAvailable
    if (-not $available) {
        # Not installed — prompt user for consent
        $choice = Invoke-AzStorageInstallPrompt
        if ($choice -ne 0) {
            # User chose No (or host is non-interactive and returned the safe default)
            Write-Error 'Az.Storage is not installed. Run: Install-Module Az.Storage -Scope CurrentUser'
            return $false
        }

        # User chose Yes — attempt installation
        try {
            Invoke-InstallAzStorageModule
        } catch {
            Write-Error "Az.Storage installation failed: $($_.Exception.Message)"
            return $false
        }
    }

    # Step 3: Check whether Az.Storage is already imported in the current session
    $imported = Get-Module -Name Az.Storage
    if (-not $imported) {
        try {
            Import-Module -Name Az.Storage -ErrorAction Stop
        } catch {
            Write-Error "Az.Storage could not be imported: $($_.Exception.Message)"
            return $false
        }
    }

    return $true
}

function Invoke-InstallAzStorageModule {
    <#
    .SYNOPSIS
        Installs the Az.Storage module for the current user.

    .DESCRIPTION
        Wraps Install-Module so that Assert-LWASAzStorageModule can be tested
        without PowerShellGet being available in the module scope.
    #>
    [CmdletBinding()]
    param()
    Install-Module -Name Az.Storage -Scope CurrentUser -Force -AllowClobber
}

function Invoke-AzStorageInstallPrompt {
    <#
    .SYNOPSIS
        Prompts the user to consent to installing Az.Storage.

    .DESCRIPTION
        Wraps $Host.UI.PromptForChoice so that Assert-LWASAzStorageModule can be
        tested without requiring an interactive host. Returns 0 for Yes, 1 for No.

    .OUTPUTS
        System.Int32
        0 = Yes (install); 1 = No (do not install).
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param()

    $caption = 'Az.Storage module required'
    $message = 'The Az.Storage PowerShell module is required for SAS token management but is not installed. Install it now for the current user?'
    $choices = @(
        [System.Management.Automation.Host.ChoiceDescription]::new('&Yes'),
        [System.Management.Automation.Host.ChoiceDescription]::new('&No')
    )
    return $Host.UI.PromptForChoice($caption, $message, $choices, 1)
}

function Invoke-GetAzContext {
    <#
    .SYNOPSIS
        Returns the current Azure context, or $null if not authenticated.

    .DESCRIPTION
        Wraps Get-AzContext so that Assert-LWASAzureSession can be tested without
        an active Azure session. Returns $null when no context is available.

    .OUTPUTS
        PSObject or $null
    #>
    [CmdletBinding()]
    param()
    return Get-AzContext -ErrorAction SilentlyContinue
}

function Invoke-ConnectAzAccount {
    <#
    .SYNOPSIS
        Opens an interactive Azure login prompt.

    .DESCRIPTION
        Wraps Connect-AzAccount so that Assert-LWASAzureSession can be tested
        without triggering a real browser login flow.
    #>
    [CmdletBinding()]
    param()
    Connect-AzAccount
}

function Assert-LWASAzureSession {
    <#
    .SYNOPSIS
        Ensures there is an active Azure session, calling Connect-AzAccount if needed.

    .DESCRIPTION
        Checks for an active Azure context via Get-AzContext. If no context is found,
        calls Connect-AzAccount interactively. Returns $true when a session is active;
        $false (after writing a Write-Error) if login fails or is not possible.

        Callers should guard with:

            if (-not (Assert-LWASAzureSession)) { return $false }

    .OUTPUTS
        System.Boolean
        $true when an active Azure session exists; $false on any failure.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $context = Invoke-GetAzContext
    if ($null -ne $context) {
        return $true
    }

    Write-Verbose 'No active Azure session found. Calling Connect-AzAccount...'
    try {
        Invoke-ConnectAzAccount
    } catch {
        Write-Error "Azure login failed: $($_.Exception.Message)"
        return $false
    }

    $context = Invoke-GetAzContext
    if ($null -eq $context) {
        Write-Error 'Azure login did not result in an active session. Please run Connect-AzAccount manually and retry.'
        return $false
    }

    return $true
}
