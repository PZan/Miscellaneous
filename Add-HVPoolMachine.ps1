<#
.Synopsis
Increases the maximum number of provisioned machines in a VMware Horizon pool.

.DESCRIPTION
Increases the maximum number of provisioned machines in a VMware Horizon pool. Default is to increase pool size by one. 
The script requires the modules VMware.VimAutomation.HorizonView, VMware.VimAutomation.Cis.Core and VMware.Hv.Helper.

.Link
https://github.com/PZan
https://github.com/vmware/PowerCLI-Example-Scripts
https://www.powershellgallery.com/packages/VMware.VimAutomation.HorizonView/7.5.0.8827468

.EXAMPLE
Add-HVPoolMachine -HVServer "MyHVServer" -PoolName "My HVPool"

.EXAMPLE
$MyCreds = Get-Credential
Add-HVPoolMachine -HVServer "MyHVServer" -PoolName "My HVPool" -Number 5 -Credential $MyCreds -Confirm:$false

.Notes
THIS CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR
FITNESS FOR A PARTICULAR PURPOSE.
#>
[CmdletBinding(
    SupportsShouldProcess = $true, ConfirmImpact = 'High'
)]
Param (
    # Define name of Horizon View Server
    [Parameter(Mandatory=$true,Position=0,HelpMessage="Please supply a Horizon View Server name (example: horizon.mydomain.com)")]
    [ValidateNotNullOrEmpty()]
    [string]$HVServer,
    # Define name (Unique ID) of the Horizon View Pool
    [Parameter(Mandatory=$true,Position=1,HelpMessage="Please supply a name (Unique ID) of the Horizon View Pool (example: MyPool)")]
    [ValidateNotNullOrEmpty()]
    [string]$PoolName,
    # Provide valid user credentials
    [Parameter(Mandatory=$false,Position=2)]
    [ValidateNotNullOrEmpty()]
    [pscredential]$Credential = $(Get-Credential),
    # Define the size of the Horizon View Pool
    [Parameter(Mandatory=$false,Position=3,DontShow)]
    [ValidateNotNullOrEmpty()]
    [ValidateRange(0,[int]::MaxValue)]
    [int]$Number=1
)
Begin{
    # User will have to confirm the changes if $confirm is $true.
    if ( $ConfirmPreference -eq "High" ) {
        Write-Warning -Message "You are about to increase the maximum number of machines with $Number machine/s in the pool $PoolName. Please confirm before proceeding (supply -Confirm:`$false to bypass)."
        [string]$Prompt = Read-Host -Prompt "Type [Y]es to accept the changes. Any other input will stop the execution of this script"
        switch -Exact ( $Prompt.ToUpper() ) {
            "YES" { <#do_nothing#> }
            "Y"   { <#do_nothing#> }
            Default {
                Write-Warning -Message "Process stopped by user."
                ## Exit the script, returning the exit code 1602 (ERROR_INSTALL_USEREXIT)
                If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1602; Exit } Else { Exit 1602 }
             }
        }
    }

    # Import modules
    try {
        Import-Module -Name VMware.VimAutomation.HorizonView,VMware.VimAutomation.Cis.Core,VMware.Hv.Helper -Verbose:$false -ErrorAction Stop
    } catch {
        Write-Error -Message "An error occurred while importing modules. Please verify that you have installed VMware.VimAutomation.HorizonView, VMware.VimAutomation.Cis.Core and VMware.Hv.Helper"
        If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 }
    }
}
Process{
    # Connect HVServer
    try {
        [VMware.VimAutomation.HorizonView.Impl.V1.ViewObjectImpl]$HVConnection = Connect-HVServer -Server $HVServer -Credential $Credential -ErrorAction Stop
        Write-Verbose -Message "Successfully connected to the Horizon Server ($HVServer)"
    } catch {
        Write-Error -Message "An error occured during the establishment of connection to HVServer ($HVServer)."
        If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 }
    }

    # Fetch pool data
    Write-Verbose -Message "Fetching pool data ($PoolName)."
    [System.Object]$HVPool = Get-HVPool -PoolName $PoolName
    if( $HVPool ) {
        [int]$CurrentPoolSize = $HVPool.AutomatedDesktopData.VmNamingSettings.PatternNamingSettings.MaxNumberOfMachines
    } else {
        Write-Error -Message "An error while fetching the pool data ($PoolName). Verify that you have supplied a valid pool name."
        $HVConnection = Disconnect-HVServer -Server $HVServer -Confirm:$false -WhatIf:$false -Force
        If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 }       
    }

    # Fetch current pool size and increase with $Number
    [int]$CurrentPoolSize = $HVPool.AutomatedDesktopData.VmNamingSettings.PatternNamingSettings.MaxNumberOfMachines
    Write-Verbose -Message "Current pool size is: $CurrentPoolSize."
    [int]$NewPoolSize = $CurrentPoolSize + $Number
   
    # Set the pool size
    try {
        if ( $WhatIfPreference ) {
            Write-Host -Object "What if: Would increase pool size from $CurrentPoolSize to: $NewPoolSize on pool $PoolName"
        } else {
            Write-Verbose -Message "Setting pool size to: $NewPoolSize."
            Set-HVPool -PoolName $PoolName -Key "automatedDesktopData.vmNamingSettings.patternNamingSettings.maxNumberOfMachines" -Value $NewPoolSize -ErrorAction Stop
        }
    } catch {
        Write-Error -Message "Failed to set the pool size."
        $HVConnection = Disconnect-HVServer -Server $HVServer -Confirm:$false -WhatIf:$false -Force
        If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 }
    }

    # Check if provisioning is enabled. Warn if disabled.
    if ( -not ($HVPool.AutomatedDesktopData.VirtualCenterProvisioningSettings.EnableProvisioning) ) {
        Write-Warning -Message "Provisioning is disabled for the supplied pool (nothing will happen)."
    } else {
        Write-Verbose -Message "Provisioning is enabled and your new machine/s should be available soon. You can monitor the cloning/configuration process closer in vCenter."
    }
}
End{
    # Disconnect from HVServer
    $HVConnection = Disconnect-HVServer -Server $HVServer -Confirm:$false -WhatIf:$false -Force
    # Write success message and exit script
    Write-Host -Object "Successfully set the pool size of $PoolName to: $NewPoolSize."
    If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 0; Exit } Else { Exit 0 }
}