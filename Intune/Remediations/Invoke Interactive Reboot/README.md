## Invoke Interactive Reboot
This Remediation determines if the system has been rebooted within the last 7 days and perfoms an user interactive remediation if the device has a pending reboot, prompting the user to restart Windows.

The script utilizes PSAppDeployToolkit (v4) and ServiceUI (x64). ServiceUI is an application used for making hidden system services visible to the active user session. It is made available in the [Microsoft Deployment Toolkit (MDT)](https://www.microsoft.com/en-us/download/details.aspx?id=54259). If you do not trust that this script is using an original copy of ServiceUI in the base64 string you may download and install MDT in order to make a base64 string copy of ServiceUI yourself.

**This remediation requires**:
- [The PSAppDeployToolkit module installed](../PSAppDeployToolkit%20v4%20Enablement/) in AllUsers  Scope

**How to customize the restart prompt:**
- Customize [Export.ps1](./Export.ps1) to your needs
- Convert the file contents to a base64 string (see section below)
- Replace the value of the `$RestartPrompt` variable in [Remediation.ps1](./Remediation.ps1) with your base64 string

**How to convert file contents to Base64 string**
``` PowerShell
$fileContent = Get-Content -Path '.\Export.ps1' -Encoding Byte
[System.Convert]::ToBase64String($fileContent) | Set-Clipboard
```

**How to convert Base64 strings to file content**
``` PowerShell
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($MyBase64String)) | Set-Content -Path "C:\MyDestination\MyFile.fte" -Encoding UTF8
# OR
[IO.File]::WriteAllBytes('C:\MyDestination\MyFile.fte', [Convert]::FromBase64String($MyBase64String))
```