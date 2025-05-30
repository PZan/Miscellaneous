[scriptblock]$Command = {
    $SourceFolder = Join-Path -Path $env:ProgramFiles -ChildPath "Prevent-Screensaver-During-Autopilot"
    $CleanUpTaskTaskName = "Prevent-Screensaver-During-Autopilot-CleanUpTask"
    $LaunchAsUserTaskName = "Launch-Awake-As-User"

    # Stop All PowerToys processes
    Get-Process PowerToys* | Stop-Process -Force -ErrorAction SilentlyContinue

    # Uninstall PowerToys
    $PowerToysInstallerSrc = Join-Path -Path $SourceFolder -ChildPath "PowerToysSetup.exe"    
    Copy-Item -Path $PowerToysInstallerSrc -Destination $env:TEMP
    Start-Process -FilePath "$($env:TEMP)\PowerToysSetup.exe" -ArgumentList "/uninstall /quiet"
    
    # Remove Scheduled Tasks
    $null = Unregister-ScheduledTask -TaskName $CleanUpTaskTaskName -Confirm:$false -ErrorAction SilentlyContinue
    $null = Unregister-ScheduledTask -TaskName $LaunchAsUserTaskName -Confirm:$false -ErrorAction SilentlyContinue

    # Remove Script Folder
    Set-Location "$($env:SystemDrive)\"
    $null = Remove-Item -Path $SourceFolder -Recurse -Force -ErrorAction SilentlyContinue
}

# Create Encoded command and execute from temp
$Bytes = [System.Text.Encoding]::Unicode.GetBytes($Command)
$EncodedCommand = [Convert]::ToBase64String($Bytes)
Start-Process -FilePath "$PSHOME\powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -EncodedCommand $EncodedCommand" -WorkingDirectory $env:TEMP -Wait:$false