<#
.SYNOPSIS

PSApppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION

- The script is provided as a template to perform an install or uninstall of an application(s).
- The script either performs an "Install" deployment type or an "Uninstall" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.

PSApppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2023 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham and Muhammad Mashwani).

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

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"

.EXAMPLE

Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
- 69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
- 70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1

.LINK

https://psappdeploytoolkit.com
#>


[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [String]$DeploymentType = 'Install',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [String]$DeployMode = 'Interactive',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false
)

Try {
    ## Set the script execution policy for this process
    Try {
        Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop'
    }
    Catch {
    }

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [String]$appVendor = 'pleplepleplepleple'
    [String]$appName = 'Prevent-Screensaver-During-Autopilot'
    [String]$appVersion = ''
    [String]$appArch = ''
    [String]$appLang = 'EN'
    [String]$appRevision = '01'
    [String]$appScriptVersion = '1.1.0'
    [String]$appScriptDate = '09.01.2024'
    [String]$appScriptAuthor = 'pleplepleplepleple'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [String]$installName = ''
    [String]$installTitle = ''

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [Int32]$mainExitCode = 0

    ## Variables: Script
    [String]$deployAppScriptFriendlyName = 'Deploy Application'
    [Version]$deployAppScriptVersion = [Version]'3.9.3'
    [String]$deployAppScriptDate = '02/05/2023'
    [Hashtable]$deployAppScriptParameters = $PsBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') {
        $InvocationInfo = $HostInvocation
    }
    Else {
        $InvocationInfo = $MyInvocation
    }
    [String]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [String]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) {
            Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]."
        }
        If ($DisableLogging) {
            . $moduleAppDeployToolkitMain -DisableLogging
        }
        Else {
            . $moduleAppDeployToolkitMain
        }
    }
    Catch {
        If ($mainExitCode -eq 0) {
            [Int32]$mainExitCode = 60008
        }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') {
            $script:ExitCode = $mainExitCode; Exit
        }
        Else {
            Exit $mainExitCode
        }
    }

    #endregion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Installation'

        ## <Perform Pre-Installation tasks here>
        [bool]$OOBEComplete = Test-OOBEComplete
        if ( $OOBEComplete ) {
            Write-Log -Message "Process is not in OOBE. This script is intended for use in OOBE. Exiting." -Severity 3 -Source "Test-OOBEComplete"
            Exit-Script -ExitCode 1
        }

        # Download latest PowerToys from GitHub
        $PowerToysResults = Save-LatestPowerToysSetup -InstallerType "Machine-x64" -DestinationDirectory $envTEMP

        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'

        ## <Perform Installation tasks here>
        
        # Install PowerToys
        if ( $PowerToysResults ) {
            $Splat = @{
                Path = $PowerToysResults.FullName
                Parameters = "/install /quiet"
            }
            Execute-Process @Splat
        }
        else {
            Write-Log -Message "PowerToys download failed. Verify internet connectivity and try again." -Severity 3 -Source "Install PowerToys"
        }
        
        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'

        ## <Perform Post-Installation tasks here>

        # Stop All PowerToys Processes
        try {
            Get-Process PowerToys* -ErrorAction Stop | Stop-Process -Force -ErrorAction Stop
            Write-Log -Message "Stopped all PowerToys processes" -Source "Stop-Process"
        }
        catch {
            Write-Log -Message "Failed to stop PowerToys" -Severity 3 -Source "Stop-Process"
        }

        # Start Awake "indefinitely"
        $Splat = @{
            Path = Join-Path -Path $envProgramFiles -ChildPath "PowerToys\PowerToys.Awake.exe"
            Parameters = "--display-on true"
            WindowStyle = "Hidden"
            NoWait = $true
        }
        Execute-Process @Splat
        
        #*===========================================
        #* Create Scheduled Tasks
        #*===========================================

        [string]$TaskName = "Prevent-Screensaver-During-Autopilot-CleanUpTask"
        
        # Prepare self destruct destination folder
        [string]$SelfDestructDestinationDir = Join-Path -Path $envProgramFiles -ChildPath $appName
        Remove-Folder -Path $SelfDestructDestinationDir
        New-Folder -Path $SelfDestructDestinationDir

        #* Configure a Scheduled Task to launch Awake as user, when a user account is available

        # ###TASKNAME###
        [string]$LaunchAwakeAsUserTaskName = "Launch-Awake-As-User"

        # ###DATENOW###
        [datetime]$Now = Get-Date
        [string]$strNow = $Now.ToString('yyyy-MM-ddTHH:mm:ss')
        
        # ###EXEPATH###
        [string]$LaunchAwakeAsUserDestination = Join-Path -Path $envProgramFiles -ChildPath "$appName\$LaunchAwakeAsUserTaskName"
        [string]$LaunchAwakeAsUserExePath = Join-Path -Path $LaunchAwakeAsUserDestination -ChildPath "Deploy-Application.exe"
        
        # Import XML and modify pre-defined variables
        [string]$SchedTaskTemplatePath = Join-Path -Path $dirSupportFiles -ChildPath "LaunchAsUserSchedTask.xml"
        $SchedTaskTemplate = Get-Content $SchedTaskTemplatePath
        $LaunchAsUserTaskXML = $SchedTaskTemplate.Replace('###DATENOW###',$strNow).Replace('###AUTHOR###',$appVendor).Replace('###TASKNAME###',$LaunchAwakeAsUserTaskName).Replace('###EXEPATH###',$LaunchAwakeAsUserExePath) | Out-String

        # Copy PSADT Script to target dir
        $LaunchAwakeAsUserPath = Join-Path -Path $dirFiles -ChildPath $LaunchAwakeAsUserTaskName
        Copy-File -Path $LaunchAwakeAsUserPath\* -Destination $LaunchAwakeAsUserDestination -Recurse

        # Register the launch as user task
        try {
            $null = Register-ScheduledTask -TaskName $LaunchAwakeAsUserTaskName -Xml $LaunchAsUserTaskXML -Force -ErrorAction Stop
            Write-Log -Message "Successfully registered task [$LaunchAwakeAsUserTaskName]" -Source "Register-ScheduledTask"
        }
        catch {
            Write-Log -Message "Failed to register scheduled task [$LaunchAwakeAsUserTaskName]!´r´n$(Resolve-Error)" -Severity 3 -Source "Register-ScheduledTask"
            Write-Log -Message "Stopping and removing PowerToys!!!" -Severity 3 -Source "Register-ScheduledTask"
            Get-Process PowerToys* | Stop-Process -Force -ErrorAction SilentlyContinue
            Execute-Process -Path "$($PowerToysResults.FullName)" -Parameters "/uninstall /quiet"
            Remove-MSIApplications -Name 'PowerToys (Preview)'
            Exit-Script -ExitCode 1
        }
        

        #*===========================================
        #* Configure Scheduled Task to quit+uninstall
        #* PowerToys after WHfB is configured or if
        #* expiration time reached
        #*===========================================

        # Copy PowerToys Installer and self destruct script to destination
        Copy-File -Path "$($PowerToysResults.FullName)" -Destination "$SelfDestructDestinationDir\PowerToysSetup.exe"
        Copy-File -Path "$dirFiles\SelfDestruct.ps1" -Destination "$SelfDestructDestinationDir\SelfDestruct.ps1"

        # Define Task Schedule
        [datetime]$Now = Get-Date
        [string]$strNow = $Now.ToString('yyyy-MM-ddTHH:mm:ss')

        # The XML in SupportFiles has other triggers (EventID + startup) that should initiate before this one.
        # Becuase of this, the trigger startboundary can safely be set to a bunch of hours in the future (it's a failsafe trigger).
        [datetime]$StartBoundary = $Now.AddHours(24)
        [string]$strStartBoundary = $StartBoundary.ToString('yyyy-MM-ddTHH:mm:ss.fffffff')

        [datetime]$ExpireTime = $StartBoundary.AddMinutes(5)
        [string]$strExpireTime = ($ExpireTime).ToString('yyyy-MM-ddTHH:mm:ss.fffffff')

        # Define Command details
        [string]$PowershellExePath = Join-Path -Path $envWinDir -ChildPath "System32\WindowsPowerShell\v1.0\powershell.exe"
        [string]$SelfDestructScriptPath = Join-Path -Path $SelfDestructDestinationDir -ChildPath "SelfDestruct.ps1"

        # Import Scheduled Task Template
        [string]$SchedTaskTemplatePath = Join-Path -Path $dirSupportFiles -ChildPath "ScheduledTaskTemplate.xml"
        $SchedTaskTemplate = Get-Content $SchedTaskTemplatePath
        $ImportXML = $SchedTaskTemplate.Replace('###DATENOW###',$strNow).Replace('###AUTHOR###',$appVendor).Replace('###TASKNAME###',$TaskName).Replace('###STARTBOUNDARY###', $strStartBoundary).Replace('###ENDBOUNDARY###', $strExpireTime).Replace('###PSEXEPATH###',$PowershellExePath).Replace('###SCRIPTPATH###',$($SelfDestructScriptPath)).Replace('###WORKINGDIRECTORY###', $envTEMP) | Out-String
        
        try {
            $null = Register-ScheduledTask -TaskName $TaskName -Xml $ImportXML -Force -ErrorAction Stop
            Write-Log -Message "Successfully registered task [$TaskName]" -Source "Register-ScheduledTask"
        }
        catch {
            Write-Log -Message "Failed to register scheduled task [$TaskName]!´r´n$(Resolve-Error)" -Severity 3 -Source "Register-ScheduledTask"
            Write-Log -Message "Stopping and removing PowerToys!!!" -Severity 3 -Source "Register-ScheduledTask"
            Get-Process PowerToys* | Stop-Process -Force -ErrorAction SilentlyContinue
            Execute-Process -Path "$($PowerToysResults.FullName)" -Parameters "/uninstall /quiet"
            Remove-MSIApplications -Name 'PowerToys (Preview)'
            Exit-Script -ExitCode 1
        }
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Uninstallation tasks here>

        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'

        ## Handle Zero-Config MSI Uninstallations

        ## <Perform Uninstallation tasks here>


        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'

        ## <Perform Post-Uninstallation tasks here>


    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [String]$installPhase = 'Pre-Repair'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        #Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Repair tasks here>

        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [String]$installPhase = 'Repair'

        ## <Perform Repair tasks here>

        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [String]$installPhase = 'Post-Repair'

        ## <Perform Post-Repair tasks here>


    }
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [Int32]$mainExitCode = 60001
    [String]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
