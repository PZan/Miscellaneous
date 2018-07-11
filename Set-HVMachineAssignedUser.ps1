<#
.Synopsis
Assigns a user to a VMware Horizon pool virtual machine and adds the user to an entitled active directory group.

.DESCRIPTION
Assigns a user to a VMware Horizon pool virtual machine and adds the user to an entitled active directory group.
By defualt the script attempts to pick the first unassigned machine in the supplied pool, as well as the first found entitled AD-group.
As an option you can supply machine name and ad group identity with params (hidden from tab completion).
Please do always use verbose and whatif to safely follow along when the script runs.

The script requires the modules VMware.VimAutomation.HorizonView, VMware.VimAutomation.Cis.Core, VMware.Hv.Helper and ActiveDirectory (optional)

.Link
https://github.com/PZan
https://github.com/vmware/PowerCLI-Example-Scripts
https://www.powershellgallery.com/packages/VMware.VimAutomation.HorizonView/7.5.0.8827468
https://www.microsoft.com/en-us/download/details.aspx?id=45520

.EXAMPLE
Set-HVMachineAssignedUser -HVServer MyHvServer -PoolName MyPool -UserName User01

.EXAMPLE
$MyCreds = Get-Credential
Set-HVMachineAssignedUser -HVServer "MyHvServer" -PoolName "MyPool" -MachineName "VDI001" -UserName "User01" -ADGroupIdentity "VDI Users" -Credential $MyCreds -Confirm:$false

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
    # Provide name of an unassigned VM in the pool
    [Parameter(Mandatory=$false,Position=2,DontShow)]
    [string]$MachineName=$null,
    # Provide user name to be assigned to machine
    [Parameter(Mandatory=$true,Position=3,HelpMessage="Please provide the username you wish to assign to the machine (example: JohnDoe01)")]
    [ValidateNotNullOrEmpty()]
    [string]$UserName,
    # Provide domain name
    [Parameter(Mandatory=$true,Position=4,HelpMessage="Please provide the user domain (example: mydomain.com)")]
    [ValidateNotNullOrEmpty()]
    [string]$UserDomain,
    # Provide name of an unassigned VM in the pool
    [Parameter(Mandatory=$false,Position=5,DontShow)]
    [ValidateNotNullOrEmpty()]
    [string]$ADGroupIdentity,
    # Provide valid user credentials
    [Parameter(Mandatory=$false,Position=6)]
    [ValidateNotNullOrEmpty()]
    [pscredential]$Credential = $(Get-Credential)
)
Begin{
    # User will have to confirm the changes if $confirm is $true.
    if ( $ConfirmPreference -eq "High" ) {
        if ( ! $MachineName ) {
            Write-Warning -Message "You are about to assign user $UserName to the first available machine in the pool $PoolName. Please confirm before proceeding (supply -Confirm:`$false to bypass)."
        } else {
            Write-Warning -Message "You are about to assign user $UserName to the machine $MachineName in the pool $PoolName. Please confirm before proceeding (supply -Confirm:`$false to bypass)."
        }
        
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
        Import-Module -Name VMware.VimAutomation.HorizonView,VMware.VimAutomation.Cis.Core,VMware.Hv.Helper,ActiveDirectory -Verbose:$false -ErrorAction Stop
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

    # Verify pool exist
    Write-Verbose -Message "Verifying pool ($PoolName) exists."
    [Object[]]$PoolSummary = Get-HVPoolSummary -PoolName $PoolName
    if ( -not $PoolSummary ) {
        Write-Warning -Message "Could not fetch summary of pool ($PoolName). Verify pool exist. Exiting script."
        $HVConnection = Disconnect-HVServer -Server $HVServer -Confirm:$false -WhatIf:$false -Force
        If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 }    
    } else { Write-Verbose -Message "Successfully verified pool existence."}

    # Verify user is not already assigned to a machine
    Write-Verbose -Message "Verifying user is not already assigned to a machine in the pool."
    [Object[]]$PoolMachineSummary = Get-HVMachineSummary -PoolName $PoolName
    if (-not $PoolMachineSummary){
        Write-Warning -Message "Could not fetch machine summary of pool ($PoolName). Verify pool exist and is populated. Exiting script."
        $HVConnection = Disconnect-HVServer -Server $HVServer -Confirm:$false -WhatIf:$false -Force
        If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 }   
    } else {
        # Verify pool has more than 0 machines
        [Int32]$PoolMachineCount = $PoolMachineSummary | Measure-Object | Select-Object -ExpandProperty Count
        if ( $PoolMachineCount -gt 0) {
            # Verify user is not assigned to any machines
            [Object[]]$NamesData = $PoolMachineSummary | Select-Object -ExpandProperty NamesData
            [Object[]]$AllAssignedUsers = $NamesData | Select-Object -ExpandProperty UserName
            
            foreach ( $AssignedUser in $AllAssignedUsers ) {
                if ( $AssignedUser -like "*\*" ) {
                    [string]$AssignedUser = ($AssignedUser.Split("\")[1]).ToUpper()
                } elseif ($AssignedUser -like "*@*"){
                    [string]$AssignedUser = ($AssignedUser.Split("@")[0])
                }
                if ( $UserName.ToUpper() -eq $AssignedUser.ToUpper() ) {
                    Write-Warning -Message "User is already assigned to a machine in the pool. Exiting script."
                    $HVConnection = Disconnect-HVServer -Server $HVServer -Confirm:$false -WhatIf:$false -Force
                    If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 } 
                }
            }
            Write-Verbose -Message "Successfully verified user not assigned to any machines in the pool."
        }
    }

    # If $MachineName is not set, figure out first unassigned machine available
    if ( -not $MachineName ) {
        # Get pool summary
        Write-Verbose -Message "Fetching machine summary of the pool $PoolName"
        [Object[]]$PoolMachineSummary = Get-HVMachineSummary -PoolName $PoolName
        if (-not $PoolMachineSummary){
            Write-Warning -Message "Could not fetch machine summary of pool ($PoolName). Verify pool exist and is populated. Exiting script."
            $HVConnection = Disconnect-HVServer -Server $HVServer -Confirm:$false -WhatIf:$false -Force
            If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 }   
        } else {
            # Fetch first unassigned machines
            Write-Verbose -Message "Finding machines available for assignment."
            [Object[]]$AllAvailableMachines = $PoolMachineSummary | Select-Object -Property @{L='MachineName';E={$_.Base.Name}},@{L='UserName';E={$_.NamesData.UserName}} | Where-Object {$_.UserName -eq $null} | Sort-Object MachineName
            if ( $AllAvailableMachines -eq $null ) {
                Write-Warning  -Message "No available machines in pool ($PoolName). Exiting script."
                $HVConnection = Disconnect-HVServer -Server $HVServer -Confirm:$false -WhatIf:$false -Force
                If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 } 
            } else {
                [string]$AllAvailableMachinesString = ($AllAvailableMachines | Select-Object -ExpandProperty MachineName) -join ', '
                Write-Verbose -Message "Found the following unassigned machines in pool $($PoolName): $AllAvailableMachinesString."
                $MachineName = $AllAvailableMachines | Select-Object -ExpandProperty MachineName -First 1
                Write-Verbose -Message "Will use machine: $MachineName."
            }
        }
    } else {
        # Verify supplied machine exists in pool
        Write-Verbose -Message "Verifying supplied machine name ($MachineName) exists in pool ($PoolName)."
        [System.Object]$MachineExist = Get-HVMachine -PoolName $PoolName -MachineName $MachineName
        if ( -not $MachineExist ) {
            Write-Warning  -Message "No available machines in pool ($PoolName). Exiting script."
            $HVConnection = Disconnect-HVServer -Server $HVServer -Confirm:$false -WhatIf:$false -Force
            If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 }
        } else {
            Write-Verbose -Message "Found supplied machine in pool."
        }
    }

    # If groupname is not set, script will fetch first entitled group in supplied pool.
    if ( -not $ADGroupIdentity ) {
        Write-Verbose -Message "Ad group identity was not supplied in script parameter. Will fetch first available entitled group in the pool."
        $ADGroupIdentity = Get-HVEntitlement -ResourceType Desktop -ResourceName $PoolName -ErrorAction Stop | Where-Object {$_.Base.Group -eq $true} | Select-Object -First 1 -ExpandProperty Base | Select-Object -ExpandProperty SID
        Write-Verbose -Message "Successfully fetched first found group SID ($ADGroupIdentity)."
        if ( -not $ADGroupIdentity ){
            Write-Error -Message "Failed to get any entitled AD groups in the pool ($PoolName)."
            $HVConnection = Disconnect-HVServer -Server $HVServer -Confirm:$false -WhatIf:$false -Force
            If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 }
        }
    } else {
        Write-Verbose -Message "AD group identity was supplied in script parameter ($ADGroupIdentity). Will verify supplied group is entitled to the pool."
        # Fetch pool entitlements
        [System.Object]$Entitlements = Get-HVEntitlement -ResourceType Desktop -ResourceName $PoolName -ErrorAction Stop    
        if( -not $Entitlements ){
            Write-Error -Message "Failed to get pool entitlements. Verify you have supplied a valid pool ($PoolName)."
            $HVConnection = Disconnect-HVServer -Server $HVServer -Confirm:$false -WhatIf:$false -Force
            If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 }
        } else {
            # Fetch AD group
            try {
                [Microsoft.ActiveDirectory.Management.ADPrincipal]$ADGroup = Get-ADGroup -Identity $ADGroupIdentity -Credential $Credential -ErrorAction Stop
                Write-Verbose -Message "Successfully fetched group from AD ($ADGroupIdentity)"
            }
            catch {
                Write-Error -Message "Failed to find group in active directory (identity: $ADGroupIdentity). Verify group is existent."
                $HVConnection = Disconnect-HVServer -Server $HVServer -Confirm:$false -WhatIf:$false -Force
                If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 }    
            }

            # match AD group SID with the once found in Pool Entitlements
            if ( ( $($ADGroup | Select-Object -ExpandProperty SID) -notin ($Entitlements | Select-Object -ExpandProperty Base | Select-Object -ExpandProperty SID) ) ) {
                Write-Error -Message "Failed to match AD group SID with entitled group/s SID."
                $HVConnection = Disconnect-HVServer -Server $HVServer -Confirm:$false -WhatIf:$false -Force
                If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 }    
            } else {
                Write-Verbose -Message "AD group is entitled to the pool."
            }           
        }
    }
        
    # Fetch AD group if not already fetched
    if( -not $ADGroup ) {
        try {
            [Microsoft.ActiveDirectory.Management.ADPrincipal]$ADGroup = Get-ADGroup -Identity $ADGroupIdentity -Credential $Credential -ErrorAction Stop   
        }
        catch {
            Write-Error -Message "Failed to find group in active directory (identity: $ADGroupIdentity). Verify group is existent."
            If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 }
        }
    }

    # Fetch group name 
    if ( $ADGroup ) {
        [string]$ADGroupName = $ADGroup | Select-Object -ExpandProperty Name
    } else {
        [string]$ADGroupName = $ADGroupIdentity
    }

    # Verify supplied user is member of ad group
    try {
        Write-Verbose "Fetching members of ad group (identity: $ADGroupIdentity)."
        [array]$ADGroupMembers = Get-ADGroupMember -Identity $ADGroup -Credential $Credential -ErrorAction Stop
    }
    catch {
        Write-Error -Message "An error occurred while fetching ad group members. Please verify that you have supplied a valid AD group name."
        If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 }
    }

    if ( $UserName -in [array]$($ADGroupMembers | Select-Object -ExpandProperty SamAccountName ) ) {
        Write-Verbose -Message "User is a member of the ad group ($ADGroupName)."
    } else {
        # Add user to ad group
        Write-Verbose -Message "User is not member of the ad group ($ADGroupName). Will add."
        try {
            $ADGroup | Add-ADGroupMember -Members $UserName -ErrorAction Stop -Credential $Credential
        }
        catch {
            Write-Error -Message "Failed to add user to the ad group."
            If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 }
        }
    }

    # Assign user to machine
    Write-Verbose -Message "Assigning user to the machine."
    try {
        [string]$FullUserName = "$UserDomain\$UserName"
        if ( $WhatIfPreference ) {
            Write-Host -Object "What if: Would assign user $FullUserName to the machine $MachineName in the pool $PoolName."
        } else {
            Set-HVMachine -MachineName $MachineName -User $FullUserName -ErrorAction Stop
        }
    } catch {
        Write-Error -Message "Failed to assign user."
        $HVConnection = Disconnect-HVServer -Server $HVServer -Confirm:$false -WhatIf:$false -Force
        If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 }
    }
}
End{
    # Disconnect from HVServer
    $HVConnection = Disconnect-HVServer -Server $HVServer -Confirm:$false -WhatIf:$false -Force
    # Write success message and exit script
    Write-Host -Object "Successfully assigned the user $UserName to the machine $MachineName."
    If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 0; Exit } Else { Exit 0 }
}