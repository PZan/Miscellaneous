# Powershell script to create disk layout based on MS recommendations (see link below)
# Intended to be executed in a SCCM/MDT Task Sequence
# https://docs.microsoft.com/de-de/windows-hardware/manufacture/desktop/configure-uefigpt-based-hard-drive-partitions#recommendedpartitionconfigurations
# Reddit thread:
# https://www.reddit.com/r/SCCM/comments/7eh3kk/fyi_update_your_ts_partition_steps
# Requires modifications to your Boot Image
# - PowerShell component
# - PowerShell Storage Module (WinPE-StorageWMI)

# Inject script in the Boot Image with Dism or with the procedure described on the following blog post (recommended):
# https://deploymentparts.wordpress.com/2015/08/14/permanently-inject-files-into-your-boot-images/

#Verify TS Environment is running.
try { $TSEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction Continue }
catch [System.Exception] { Write-Warning -Message "Unable to construct Microsoft.SMS.TSEnvironment object"; Exit 1603 }

# Partition GPT Volume with StorageWMI powershell module
Import-Module Storage

# Partition sizes in UINT64 format
[uint64]$DiskTotalSize = (Get-Disk -Number 0 | Select-Object -ExpandProperty Size)
[uint64]$PartitionEFI  = 512MB
[uint64]$PartitionMSR  = 16MB
[uint64]$PartitionRec  = 1024MB
# Calculate size of Windows partition (not sure why the extra 2MB are necessary, but the recovery disk would end up as 1022 MB otherwise)
[uint64]$PartitionWin  = $DiskTotalSize-($PartitionMSR + $PartitionEFI + $PartitionRec + 2MB)

# Clear disk and initialize
Clear-Disk -Number 0 -RemoveData -RemoveOEM -Confirm:$false
Initialize-Disk -Number 0

# Set Partition Style to GPT
Set-Disk -Number 0 -PartitionStyle GPT

# Create and format EFI Partition/volume
New-Partition -DiskNumber 0 -Size $PartitionEFI -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' -IsHidden:$false -IsActive:$false -DriveLetter T
Format-Volume -DriveLetter T -FileSystem FAT32 -NewFileSystemLabel "System"

#Remove T(emporary) drive letter from EFI Partition
Get-Disk 0 | Get-Partition | Where-Object {$_.DriveLetter -eq "T" } | Remove-PartitionAccessPath -AccessPath "T:\"

# Create MSR Partition
New-Partition -DiskNumber 0 -Size $PartitionMSR -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}' -IsHidden:$true -IsActive:$false -AssignDriveLetter:$false

# Create and format Windows Partition
New-Partition -DiskNumber 0 -Size $PartitionWin -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}' -IsHidden:$false -DriveLetter C
Format-Volume -DriveLetter C -FileSystem NTFS -NewFileSystemLabel "Windows"
 
# Create and format Recovery Partition
New-Partition -DiskNumber 0 -UseMaximumSize -GptType '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}' -IsHidden:$false -IsActive:$false -DriveLetter T
Format-Volume -DriveLetter T -FileSystem NTFS -NewFileSystemLabel "Recovery"

#Remove T(emporary) drive letter from Recovery Partition
Get-Disk 0 | Get-Partition | Where-Object {$_.DriveLetter -eq "T" } | Remove-PartitionAccessPath -AccessPath "T:\"

# Set TS Variable OSDisk to C
$TSEnvironment.Value("OSDisk") = "C:"
