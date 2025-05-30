# WSL2 Install Script
This PSAppDeployToolkit v4 script prepares the Windows operating system for Windows Subsystem For Linux by doing the following:
 - Enables the optional feature WindowsVirtualPlatform and Windows-Subsystem-For-Linux
 - Downloads and installs the latest x64 [WSL installer from GitHub](https://github.com/microsoft/WSL) using [PowerShellForGitHub](https://github.com/microsoft/PowerShellForGitHub).
 - Additionally the script prepares the installation of [Microsoft Defender for Endpoint plug-in for WSL](https://learn.microsoft.com/en-us/defender-endpoint/mde-plugin-wsl), if the MSI file is present in SupportFiles (`.\SupportFiles\wsl-defenderplugin-x64\defenderplugin-x64.msi`). This requires you to download the correspondning MSI file from your [Defender for Endpoint portal](https://security.microsoft.com/).

# How to install using Intune
Create your .intunewin file using [Microsoft Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool) and deploy following your preferred routine
 - Install Microsoft Win32 Content Prep Tool using WinGet:
   `winget install --id Microsoft.Win32ContentPrepTool`
 - Create a package standing in the root folder of this project:
   `intunewinapputil.exe -c '.\PSADT 4.0.6' -s Invoke-ServiceUI.ps1 -o .\ -q`

## Notes on the detection script (Detection.ps1)
 - At the time of writing the latest WSL release is version 2.5.7.
 - The detection script expects version 2.5.7 or higher

## Non-interactive command line

### Install
`Invoke-AppDeployToolkit.exe Install Silent`

### Uninstall
`Invoke-AppDeployToolkit.exe Uninstall Silent`

## Interactive command line:
 - Requires ServiceUI_x64.exe and ServiceUI_x86.exe in the root of the PSADT 4.0.6 folder
 - ServiceUI is made available in the [Microsoft Deployment Toolkit](https://www.microsoft.com/en-us/download/details.aspx?id=54259)
 - Script source: [Invoke-ServiceUI.ps1 (PSAppDeployToolkit)](https://github.com/PSAppDeployToolkit/PSAppDeployToolkit/tree/79684ff4fe1c19ead59086c941f449d82501df18/examples/ServiceUI)

### Install
`%SystemRoot%\System32\WindowsPowerShell\v1.0\PowerShell.exe -ExecutionPolicy Bypass -NoProfile -File Invoke-ServiceUI.ps1 -DeploymentType Install -AllowRebootPassThru`

### Uninstall:
`%SystemRoot%\System32\WindowsPowerShell\v1.0\PowerShell.exe -ExecutionPolicy Bypass -NoProfile -File Invoke-ServiceUI.ps1 -DeploymentType Uninstall -AllowRebootPassThru`
