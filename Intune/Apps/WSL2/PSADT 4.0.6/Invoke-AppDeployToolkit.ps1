<#

.SYNOPSIS
PSAppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION
- The script is provided as a template to perform an install, uninstall, or repair of an application(s).
- The script either performs an "Install", "Uninstall", or "Repair" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script imports the PSAppDeployToolkit module which contains the logic and functions required to install or uninstall an application.

PSAppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2024 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham, Muhammad Mashwani, Mitch Richters, Dan Gough).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.PARAMETER DeploymentType
The type of deployment to perform. Default is: Install.

.PARAMETER DeployMode
Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.

.PARAMETER AllowRebootPassThru
Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode
Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging
Disables logging to file for the script. Default is: $false.

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeployMode Silent

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -AllowRebootPassThru

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeploymentType Uninstall

.EXAMPLE
Invoke-AppDeployToolkit.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS
None. You cannot pipe objects to this script.

.OUTPUTS
None. This script does not generate any output.

.NOTES
Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Invoke-AppDeployToolkit.ps1, and Invoke-AppDeployToolkit.exe
- 69000 - 69999: Recommended for user customized exit codes in Invoke-AppDeployToolkit.ps1
- 70000 - 79999: Recommended for user customized exit codes in PSAppDeployToolkit.Extensions module.

.LINK
https://psappdeploytoolkit.com

#>

[CmdletBinding()]
param
(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [System.String]$DeploymentType = 'Install',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [System.String]$DeployMode = 'Interactive',

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$AllowRebootPassThru,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$TerminalServerMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$DisableLogging
)


##================================================
## MARK: Variables
##================================================

$adtSession = @{
    # App variables.
    AppVendor = 'Microsoft'
    AppName = 'WSL2'
    AppVersion = ''
    AppArch = ''
    AppLang = 'EN'
    AppRevision = '01'
    AppSuccessExitCodes = @(0)
    AppRebootExitCodes = @(1641, 3010)
    AppScriptVersion = '1.0.0'
    AppScriptDate = '2025.02.20'
    AppScriptAuthor = 'PZan'

    # Install Titles (Only set here to override defaults set by the toolkit).
    InstallName = ''
    InstallTitle = ''

    # Script variables.
    DeployAppScriptFriendlyName = $MyInvocation.MyCommand.Name
    DeployAppScriptVersion = '4.0.4'
    DeployAppScriptParameters = $PSBoundParameters
}

function Install-ADTDeployment
{
    ##================================================
    ## MARK: Pre-Install
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt.
    Show-ADTInstallationWelcome -AllowDefer:$false -CheckDiskSpace -PersistPrompt -NoMinimizeWindows

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Installation tasks here>
    $ProgressPreference = 'SilentlyContinue'
    
    ##================================================
    ## MARK: Install
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType
    
    $adtEnvironment = Get-ADTEnvironmentTable
    
    switch ($adtEnvironment.currentUILanguage) {
        "NB" { 
            $StatusMessage = "Aktiverer VirtualMachinePlatform" 
        }
        Default {
            $StatusMessage = "Enabling VirtualMachinePlatform"
        }
    } 
    Show-ADTInstallationProgress -StatusMessage $StatusMessage

    # Enable Virtual Machine Platform
    $ShouldEnableVMP = ($(Get-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform").State -ne "Enabled")
    if ( $ShouldEnableVMP ) {
        try {
                Write-ADTLogEntry -Message "Enabling VirtualMachinePlatform" -Source 'Enable-WindowsOptionalFeature'
                $Splat = @{
                    FeatureName = "VirtualMachinePlatform"
                    Online = $true
                    NoRestart = $true
                    ErrorAction = "Stop"
                }
                $null = Enable-WindowsOptionalFeature @Splat
        } catch [System.Exception] {
            Write-ADTLogEntry -Message "Failed to enable VirtualMachinePlatform" -Source 'Enable-WindowsOptionalFeature'
            Write-ADTLogEntry -Message (Resolve-ADTErrorRecord -ErrorRecord $_) -Severity 3 -Source 'Enable-WindowsOptionalFeature'
            Close-ADTSession -ExitCode 60000
        }
    } else{
        Write-ADTLogEntry -Message "VirtualMachinePlatform already enabled" -Source 'Enable-WindowsOptionalFeature'
    }

    # Enable WSL
    switch ($adtEnvironment.currentUILanguage) {
        "NB" { 
            $StatusMessage = "Aktiverer Microsoft-Windows-Subsystem-Linux" 
        }
        Default {
            $StatusMessage = "Enabling Microsoft-Windows-Subsystem-Linux"
        }
    } 
    Show-ADTInstallationProgress -StatusMessage $StatusMessage

    $ShouldEnableWSL = ($(Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux").State -ne "Enabled")
    if ( $ShouldEnableWSL ) {
        try {
            Write-ADTLogEntry -Message "Enabling Microsoft-Windows-Subsystem-Linux" -Source 'Enable-WindowsOptionalFeature'
            $Splat = @{
                FeatureName = "Microsoft-Windows-Subsystem-Linux"
                Online = $true
                NoRestart = $true
                ErrorAction = "Stop"
            }
            $null = Enable-WindowsOptionalFeature @Splat
        }
        catch [System.Exception] {
            Write-ADTLogEntry -Message "Failed to enable Microsoft-Windows-Subsystem-Linux" -Source 'Enable-WindowsOptionalFeature'
            Write-ADTLogEntry -Message (Resolve-ADTErrorRecord -ErrorRecord $_) -Severity 3 -Source 'Enable-WindowsOptionalFeature'
            Close-ADTSession -ExitCode 60001
        }
    }

    #*====================================================
    #*  Download latest WSL Installer from GitHub Releases
    #*====================================================

    # Download and install WSL
    switch ($adtEnvironment.currentUILanguage) {
        "NB" { 
            $StatusMessage = "Laster ned siste WSL release fra GitHub" 
        }
        Default {
            $StatusMessage = "Downloading latest WSL release from GitHub"
        }
    } 
    Show-ADTInstallationProgress -StatusMessage $StatusMessage

    # Import PowerShellForGitHub module
    $CustomModulePath = Join-Path $adtSession.dirSupportFiles -ChildPath "PowerShellForGitHub\0.17.0\PowerShellForGitHub.psd1"
    try {
        Import-Module $CustomModulePath -Force
    }
    catch {
        Write-ADTLogEntry -Message "Failed to PowerShellForGitHub"
        Close-ADTSession -ExitCode 60003
    }
    
    
    # Get latest release
    $null = Set-GitHubConfiguration -DisableTelemetry
    $WSLLatest = Get-GitHubRelease -OwnerName microsoft -RepositoryName WSL -Latest -ErrorAction SilentlyContinue
    $foundRelease = $null -ne $WSLLatest 

    if ( $foundRelease ) {
        # Get GitHub Asset
        $GitHubAsset = $WSLLatest | Get-GitHubReleaseAsset | Where-Object {$_.Name -like "*x64.msi" }
        $foundUniqueAsset = ($GitHubAsset | Measure-Object).Count -eq 1
        if ( $foundUniqueAsset ) {
            $AssetName = $GitHubAsset.Name
            $AssetUri = $GitHubAsset.browser_download_url
            $AssetDst = Join-Path -Path $adtEnvironment.envTemp -ChildPath $AssetName
            Write-ADTLogEntry "Downloading installer [$AssetName] from [$AssetUri] to [$AssetDst]"
            try {
                Invoke-RestMethod -Uri $AssetUri -OutFile $AssetDst -ErrorAction Stop
            }
            catch {
                Write-ADTLogEntry -Message "Failed to download installer from Github" -Severity 3
                Close-ADTSession -ExitCode 60004
            }
        } else {
            Write-ADTLogEntry -Message "Failed to find unique GitHub asset" -Severity 3
            Close-ADTSession -ExitCode 60005
        }
    } else {
        Write-ADTLogEntry -Message "Failed to find release in GitHub" -Severity 3
        Close-ADTSession -ExitCode 60006
    }

    # Ensure file was downloaded
    $installerExist = Test-Path $AssetDst

    if ( -not $installerExist ) {
        Write-ADTLogEntry -Message "Installer not found" -Severity 3
        Close-ADTSession -ExitCode 60007
    }

    # Perform installation
    switch ($adtEnvironment.currentUILanguage) {
        "NB" { 
            $StatusMessage = "Installerer oppdatering" 
        }
        Default {
            $StatusMessage = "Installing update"
        }
    } 
    Show-ADTInstallationProgress -StatusMessage $StatusMessage
    $null = Start-ADTMsiProcess -Action Install -FilePath $AssetDst -PassThru


    ##================================================
    ## MARK: Post-Install
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Installation tasks here>    

    #*=====================================
    #* Install Defender Plug-in on startup
    #*=====================================


    [string]$TaskName = "wsl-defenderplugin-x64"
    [string]$DefenderPluginInstallFileSource = Join-Path $adtSession.dirSupportFiles -ChildPath "wsl-defenderplugin-x64\defenderplugin-x64.msi"
    [string]$DefenderPluginHelperScriptSource = Join-Path $adtSession.dirSupportFiles -ChildPath "wsl-defenderplugin-x64\Install.ps1"

    if ( (Test-Path $DefenderPluginInstallFileSource) -and (Test-Path $DefenderPluginHelperScriptSource) ) {
        Write-ADTLogEntry -Message "Preparing the installation of Microsoft Defender for Endpoint plug-in for WSL" -Source "WSL Defender Plug-in"
        [string]$DestinationDir = Join-Path -Path $adtEnvironment.envTemp -ChildPath $TaskName
        [string]$ScriptPath = Join-Path -Path $DestinationDir -ChildPath "Install.ps1"
        
        
        Copy-ADTFile -Path $DefenderPluginInstallFileSource -Destination $DestinationDir
        Copy-ADTFile -Path $DefenderPluginHelperScriptSource -Destination $DestinationDir

        # Prepare scheduled task data
        [datetime]$Now = Get-Date
        [string]$strNow = $Now.ToString('yyyy-MM-ddTHH:mm:ss')
        [string]$PowershellExePath = Join-Path -Path $adtEnvironment.envWinDir -ChildPath "System32\WindowsPowerShell\v1.0\powershell.exe"

        # Import Template Task
        $SchedTaskTemplatePath = Join-Path -Path $($adtSession.dirSupportFiles) -ChildPath "WSLSchedTask.xml"
        $WSLSchedTask = Get-Content $SchedTaskTemplatePath
        $WSLSchedTaskXML = $WSLSchedTask.Replace('###DATENOW###',$strNow).Replace('###PSEXEPATH###',$PowershellExePath).Replace('###SCRIPTPATH###',$($ScriptPath)).Replace('###WORKINGDIRECTORY###', $($adtEnvironment.envTemp)) | Out-String

        # Register scheduled task
        try {
            $null = Register-ScheduledTask -TaskName $TaskName -Xml $WSLSchedTaskXML -Force -ErrorAction Stop
            Write-ADTLogEntry -Message "Successfully registered task [$TaskName]" -Source "Register-ScheduledTask"
        }
        catch {
            Write-ADTLogEntry -Message "Failed to register scheduled task [$TaskName]!`r`n$(Resolve-ADTErrorRecord -ErrorRecord $_)" -Severity 3 -Source "Register-ScheduledTask"
            Exit-Script -ExitCode 1
        }
    } else {
        Write-ADTLogEntry -Message "Source files are missing for Microsoft Defender for Endpoint plug-in for WSL" -Source "WSL Defender Plug-in"
    }

    ## Display a message at the end of the install.
    switch ($adtEnvironment.currentUILanguage) {
        "NB" { 
            $RestartTitle = "En restart er nødvendig"
            $RestartSubtitle = "Start på nytt for å fullføre" 
        }
        Default {
            $RestartTitle = "Reboot required"
            $RestartSubtitle = "Please reboot to complete" 
        }
    } 
    Show-ADTInstallationRestartPrompt -NoCountdown -Title $RestartTitle -Subtitle $RestartSubtitle   
}

function Uninstall-ADTDeployment
{
    ##================================================
    ## MARK: Pre-Uninstall
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    $adtEnvironment = Get-ADTEnvironmentTable

    ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing.
    Show-ADTInstallationWelcome -CloseProcesses iexplore -CloseProcessesCountdown 60

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Uninstallation tasks here>


    ##================================================
    ## MARK: Uninstall
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## <Perform Uninstallation tasks here>

    # Uninstall MSI
    Get-ADTApplication -Name "Windows Subsystem for Linux" -NameMatch Exact | Uninstall-ADTApplication 
    Get-ADTApplication -Name "Microsoft Defender for Endpoint plug-in for WSL" -NameMatch Exact | Uninstall-ADTApplication

    # Disable Virtual Machine Platform
    try {
        Write-ADTLogEntry -Message "Disabling VirtualMachinePlatform" -Source 'Disable-WindowsOptionalFeature'
        $Splat = @{
            FeatureName = "VirtualMachinePlatform"
            Online = $true
            NoRestart = $true
            ErrorAction = "Stop"
        }
        $null = Disable-WindowsOptionalFeature @Splat
    } catch [System.Exception] {
        Write-ADTLogEntry -Message "Failed to disable VirtualMachinePlatform" -Source 'Disable-WindowsOptionalFeature'
        Write-ADTLogEntry -Message (Resolve-ADTErrorRecord -ErrorRecord $_) -Severity 3 -Source 'Disable-WindowsOptionalFeature'
        Close-ADTSession -ExitCode 60007
    }

    # Disable WSL
    try {
        Write-ADTLogEntry -Message "Disabling Microsoft-Windows-Subsystem-Linux" -Source 'Disable-WindowsOptionalFeature'
        $Splat = @{
            FeatureName = "Microsoft-Windows-Subsystem-Linux"
            Online = $true
            NoRestart = $true
            ErrorAction = "Stop"
        }
        $null = Enable-WindowsOptionalFeature @Splat
    }
    catch [System.Exception] {
        Write-ADTLogEntry -Message "Failed to disable Microsoft-Windows-Subsystem-Linux" -Source 'Disable-WindowsOptionalFeature'
        Write-ADTLogEntry -Message (Resolve-ADTErrorRecord -ErrorRecord $_) -Severity 3 -Source 'Disable-WindowsOptionalFeature'
        Close-ADTSession -ExitCode 60008
    }

    ##================================================
    ## MARK: Post-Uninstallation
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Uninstallation tasks here>
    switch ($adtEnvironment.currentUILanguage) {
        "NB" { 
            $RestartTitle = "En restart er nødvendig"
            $RestartSubtitle = "Start på nytt for å fullføre" 
        }
        Default {
            $RestartTitle = "Reboot required"
            $RestartSubtitle = "Please reboot to complete" 
        }
    } 
    Show-ADTInstallationRestartPrompt -NoCountdown -Title $RestartTitle -Subtitle $RestartSubtitle
}

function Repair-ADTDeployment
{
    ##================================================
    ## MARK: Pre-Repair
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing.
    Show-ADTInstallationWelcome -CloseProcesses iexplore -CloseProcessesCountdown 60

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Repair tasks here>


    ##================================================
    ## MARK: Repair
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## Handle Zero-Config MSI repairs.
    if ($adtSession.UseDefaultMsi)
    {
        $ExecuteDefaultMSISplat = @{ Action = $adtSession.DeploymentType; FilePath = $adtSession.DefaultMsiFile }
        if ($adtSession.DefaultMstFile)
        {
            $ExecuteDefaultMSISplat.Add('Transform', $adtSession.DefaultMstFile)
        }
        Start-ADTMsiProcess @ExecuteDefaultMSISplat
    }

    ## <Perform Repair tasks here>


    ##================================================
    ## MARK: Post-Repair
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Repair tasks here>
}


##================================================
## MARK: Initialization
##================================================

# Set strict error handling across entire operation.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
Set-StrictMode -Version 1

# Import the module and instantiate a new session.
try
{
    $moduleName = if ([System.IO.File]::Exists("$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"))
    {
        Get-ChildItem -LiteralPath $PSScriptRoot\PSAppDeployToolkit -Recurse -File | Unblock-File -ErrorAction Ignore
        "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"
    }
    else
    {
        'PSAppDeployToolkit'
    }
    Import-Module -FullyQualifiedName @{ ModuleName = $moduleName; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.0.4' } -Force
    try
    {
        $adtSession = Open-ADTSession -SessionState $ExecutionContext.SessionState @adtSession @PSBoundParameters -PassThru
    }
    catch
    {
        Remove-Module -Name PSAppDeployToolkit* -Force
        throw
    }
}
catch
{
    $Host.UI.WriteErrorLine((Out-String -InputObject $_ -Width ([System.Int32]::MaxValue)))
    exit 60008
}


##================================================
## MARK: Invocation
##================================================

try
{
    Get-Item -Path $PSScriptRoot\PSAppDeployToolkit.* | & {
        process
        {
            Get-ChildItem -LiteralPath $_.FullName -Recurse -File | Unblock-File -ErrorAction Ignore
            Import-Module -Name $_.FullName -Force
        }
    }
    & "$($adtSession.DeploymentType)-ADTDeployment"
    Close-ADTSession -ExitCode 1641
}
catch
{
    Write-ADTLogEntry -Message ($mainErrorMessage = Resolve-ADTErrorRecord -ErrorRecord $_) -Severity 3
    Show-ADTDialogBox -Text $mainErrorMessage -Icon Stop | Out-Null
    Close-ADTSession -ExitCode 60001
}
finally
{
    Remove-Module -Name PSAppDeployToolkit* -Force
}
