<#
.SYNOPSIS
Creates GPT-based disk and partitions layout, in accordance with Microsoft recommendations for Windows 10.

.DESCRIPTION
Creates GPT-based disk and partitions layout, in accordance with Microsoft recommendations for Windows 10 as described here:
https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/configure-uefigpt-based-hard-drive-partitions

The script is intended to be used in the starting phase of a MDT/SCCM based Task Sequence and must therefore be available in Windows PE to function in an OSD scenario.
It utilizes the Storage Module (WinPE-StorageWMI component) which also must be added to your WinPE boot image.

.EXAMPLE
New-GPTDiskDefaultLayout.ps1

In this example the script runs with default parameter values. The default values are:
DiskNumber: 0 and create partition layout with default sizes.
EFI Partition Size: 100MB
MSR Partition Size: 16MB
Recovery Partition Size: 1024MB

The user will be required to confirm the changes before the procedure continues
    
.EXAMPLE
New-GPTDiskDefaultLayout.ps1 -DiskNumber 0 -EFIPartitionSize 512MB -MSRPartitionSize 128MB -RecoveryPartitionSize 640MB -Confirm:$false

In this example every parameter is set to custom values and confirmation is supplied in the command line (silent mode).

.NOTES
Version 0.1
#>
[CmdletBinding(
    SupportsShouldProcess = $true,
    ConfirmImpact = 'High'
)]
Param (
    [Parameter(Mandatory=$false,Position=0)]
    [int]$DiskNumber = 0,
	[Parameter( Mandatory=$false,Position=1)]
	[uint64]$EFIPartitionSize  = 100MB,
	[Parameter(Mandatory=$false,Position=2)]
	[uint64]$MSRPartitionSize  = 16MB,
	[Parameter(Mandatory=$false,Position=3)]
	[uint64]$RecoveryPartitionSize  = 1024MB
)

Begin {
    # Make user confirm unless ConfirmPreference already lowered in command line
    if ( $ConfirmPreference.value__ -gt 1 ) {
        Write-Warning -Message "This procedure will clear the disk (disk number $($DiskNumber)). All data will be erased. You are required to confirm the changes before the procedure continues."
        # Prompt to confirm
        [int]$Confirm = 0
        [string]$prompt = Read-Host "Type [Y]es to accept the changes and to clear the disk and create GPT-based partition layout. Any other input will stop the execution of this script."
        switch ( $prompt.ToUpper() ) {
            "YES" { $Confirm = 1; break }
            "Y"   { $Confirm = 1; break }
        }
    }
    if ( $Confirm -eq 0 ) {
        Write-Host "Process stopped by user"
        break
    }
}
Process {
    try {
        # Import the Storage module
        Import-Module Storage

        # Get total disk size
        [uint64]$TotalDiskSize = (Get-Disk -Number $DiskNumber | Select-Object -ExpandProperty Size)

        # Calculate size of Windows partition (not sure why the extra 2MB are necessary, but the recovery disk would end up as 1022 MB otherwise)
        [uint64]$WindowsPartitionSize  = $TotalDiskSize - ($EFIPartitionSize + $MSRPartitionSize + $RecoveryPartitionSize + 2MB)

        # Clear disk and initialize
        Clear-Disk -Number $DiskNumber -RemoveData -RemoveOEM -Confirm:$false
        Initialize-Disk -Number $DiskNumber

        # Set Partition Style to GPT
        Set-Disk -Number $DiskNumber -PartitionStyle GPT

        # Create and format EFI Partition/volume
        New-Partition -DiskNumber $DiskNumber -Size $EFIPartitionSize -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' -IsHidden:$false -IsActive:$false -DriveLetter T
        Format-Volume -DriveLetter T -FileSystem FAT32 -NewFileSystemLabel "System"

        #Remove T(emporary) drive letter from EFI Partition
        Get-Disk -Number $DiskNumber | Get-Partition | Where-Object {$_.DriveLetter -eq "T" } | Remove-PartitionAccessPath -AccessPath "T:\"

        # Create MSR Partition
        New-Partition -DiskNumber $DiskNumber -Size $MSRPartitionSize -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}' -IsHidden:$true -IsActive:$false -AssignDriveLetter:$false

        # Create and format Windows Partition
        New-Partition -DiskNumber $DiskNumber -Size $WindowsPartitionSize -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}' -IsHidden:$false -DriveLetter C
        Format-Volume -DriveLetter C -FileSystem NTFS -NewFileSystemLabel "Windows"
        
        # Create and format Recovery Partition
        New-Partition -DiskNumber $DiskNumber -UseMaximumSize -GptType '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}' -IsHidden:$false -IsActive:$false -DriveLetter T
        Format-Volume -DriveLetter T -FileSystem NTFS -NewFileSystemLabel "Recovery"

        #Remove T(emporary) drive letter from Recovery Partition
        Get-Disk -Number $DiskNumber | Get-Partition | Where-Object {$_.DriveLetter -eq "T" } | Remove-PartitionAccessPath -AccessPath "T:\"

        # Set TS Variable OSDisk to C
        $TSEnvironment.Value("OSDisk") = "C:"
    }
    catch {
        throw $($_.Exception | Select-Object -ExpandProperty Message)
    }
}
End {
    
}