<#
.Synopsis
Gets VMware Horizon pool size.

.DESCRIPTION
Gets VMware Horizon pool size. Requires Horizon Server name, Pool name and valid user credentials.

.EXAMPLE
Get-HVPoolSize -HVServer "MyHVServer" -PoolName "My HVPool"

.EXAMPLE
$MyCreds = Get-Credential
Get-HVPoolSize -HVServer "MyHVServer" -PoolName "My HVPool" -Credential $MyCreds

.Notes
THIS CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR
FITNESS FOR A PARTICULAR PURPOSE. 
#>
[CmdletBinding(
    SupportsShouldProcess = $true
)]
Param (
    # Define fully qualified domain name of Horizon View Server
    [Parameter(Mandatory=$true,Position=0)]
    [ValidateNotNullOrEmpty()]
    [string]$HVServer,
    # Define name of the Horizon View Pool
    [Parameter(Mandatory=$true,Position=1)]
    [ValidateNotNullOrEmpty()]
    [string]$PoolName,
    # Provide valid user credentials
    [Parameter(Mandatory=$false,Position=3)]
    [ValidateNotNullOrEmpty()]
    [pscredential]$Credential = $(Get-Credential)
)
Begin {
    # Import modules
    try {
        Import-Module -Name VMware.VimAutomation.HorizonView -Verbose:$false -ErrorAction Stop
        Import-Module -Name VMware.VimAutomation.Cis.Core -Verbose:$false -ErrorAction Stop
        Import-Module -Name VMware.Hv.Helper -Verbose:$false -ErrorAction Stop
    } catch {
        Write-Error -Message "An error occurred while importing modules. Please verify that you have installed VMware.VimAutomation.HorizonView, VMware.VimAutomation.Cis.Core and VMware.Hv.Helper"
        If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 }
    }
}
Process {
    # Connect HVServer
    try {
        [VMware.VimAutomation.HorizonView.Impl.V1.ViewObjectImpl]$HVConnection = Connect-HVServer -Server $HVServer -Credential $Credential -ErrorAction Stop
        Write-Verbose -Message "Successfully connected to HVServer ($HVServer)"
    } catch {
        Write-Error -Message "An error occured during establishment of connection to HVServer ($HVServer)"
        If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 }
    }

    # Fetch pool data
    Write-Verbose -Message "Fetching pool data ($PoolName)"
    [System.Object]$HVPool = Get-HVPool -PoolName $PoolName
    if( $HVPool ) {
        [int]$CurrentPoolSize = $HVPool.AutomatedDesktopData.VmNamingSettings.PatternNamingSettings.MaxNumberOfMachines
    } else {
        Write-Error -Message "An error while fetching the pool data ($PoolName). Verify that you have supplied a valid pool name."
        $HVConnection = Disconnect-HVServer -Server $HVServer -Confirm:$false
        If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 }       
    }
}
End {
    # Disconnect from HVServer
    $HVConnection = Disconnect-HVServer -Server $HVServer -Confirm:$false
    # Write success message and exit script
    Write-Verbose -Message  "$PoolName size is: $CurrentPoolSize"
    Return $CurrentPoolSize
    If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 0; Exit } Else { Exit 0 }
}