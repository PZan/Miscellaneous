# Import PSAppDeployToolkit module
if ( $null -eq (Get-Module PSAppDeployToolkit)){
    try {
        Import-Module -Name "PSAppDeployToolkit" -ErrorAction Stop   
    }
    catch {
        Write-Output "Failed to import module. Cannot continue."
        Exit 0
    }
}

# Number of days since last boot
$IntervalInDays = 7

# Get Pending Reboot object
$ADTPendingReboot = Get-ADTPendingReboot

# Determine if we should evaluate this system
$EligibleForRemediation = $ADTPendingReboot.LastBootUpTime -lt (Get-Date).AddDays(-$IntervalInDays)

if ( $EligibleForRemediation ) {
    if ( $ADTPendingReboot.IsSystemRebootPending ) {
        Remove-Module PSAppDeployToolkit
        Write-Output "Pending reboot detected. Remediating."
        Exit 1
    } else {
        Remove-Module PSAppDeployToolkit
        Write-Output "No pending reboot was detected. Compliant"
        Exit 0
    }
} else {
    # Less than x days since last boot
    Write-Output "Reboot was done within the last [$IntervalInDays] days. Compliant"
    Exit 0
}