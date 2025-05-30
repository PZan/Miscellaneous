[CmdletBinding()]
Param()

# Install Prereq
Write-Output -InputObject "Installing wsl-defenderplugin-x64.msi..."
[string]$MSIExec = Join-Path -Path $env:windir -ChildPath "System32\msiexec.exe"
[string]$InstallFile = Join-Path -Path $env:windir -ChildPath "SystemTemp\wsl-defenderplugin-x64\defenderplugin-x64.msi"
[string]$LogFilePath = Join-Path -Path $env:windir -ChildPath "Logs\Software\wsl-defenderplugin-x64.log"
Start-Process -FilePath $MSIExec -ArgumentList "/I`"$InstallFile`" /qn /l*v `"$LogFilePath`"" -Wait:$true

# Perform Clean-Up
Write-Output -InputObject "Performing cleanup..."

# Create a command to be executed independently so we don't lock any files for removal
[scriptblock]$Command = {
    # Remove Scheduled Tasks
    $null = Unregister-ScheduledTask -TaskName "wsl-defenderplugin-x64" -Confirm:$false -ErrorAction SilentlyContinue
    
    # Remove Temp Folder
    [string]$Folder = Join-Path -Path $env:windir -ChildPath "SystemTemp\wsl-defenderplugin-x64"
    $null = Remove-Item -Path $Folder -Recurse -Force
}

# Create Encoded command and execute from temp
$Bytes = [System.Text.Encoding]::Unicode.GetBytes($Command)
$EncodedCommand = [Convert]::ToBase64String($Bytes)
$null = Start-Process -FilePath "$PSHOME\powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -EncodedCommand $EncodedCommand" -WorkingDirectory $env:TEMP -WindowStyle Hidden -Wait:$false
Write-Output -InputObject "Complete."