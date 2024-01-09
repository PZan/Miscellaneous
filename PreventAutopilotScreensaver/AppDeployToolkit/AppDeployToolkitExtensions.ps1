<#
.SYNOPSIS

PSAppDeployToolkit - Provides the ability to extend and customise the toolkit by adding your own functions that can be re-used.

.DESCRIPTION

This script is a template that allows you to extend the toolkit with your own custom functions.

This script is dot-sourced by the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.

PSApppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2023 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham and Muhammad Mashwani).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.EXAMPLE

powershell.exe -File .\AppDeployToolkitHelp.ps1

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

.LINK

https://psappdeploytoolkit.com
#>


[CmdletBinding()]
Param (
)

##*===============================================
##* VARIABLE DECLARATION
##*===============================================

# Variables: Script
[string]$appDeployToolkitExtName = 'PSAppDeployToolkitExt'
[string]$appDeployExtScriptFriendlyName = 'App Deploy Toolkit Extensions'
[version]$appDeployExtScriptVersion = [version]'3.9.3'
[string]$appDeployExtScriptDate = '02/05/2023'
[hashtable]$appDeployExtScriptParameters = $PSBoundParameters

##*===============================================
##* FUNCTION LISTINGS
##*===============================================

# <Your custom functions go here>
function Test-OOBEComplete {
    [CmdletBinding()]
    Param ()

    [String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    $TypeDef = @"     
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
    
namespace Api
{
    public class Kernel32
    {
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern int OOBEComplete(ref int bIsOOBEComplete);
    }
}
"@   
    
    Add-Type -TypeDefinition $TypeDef -Language CSharp
    # Check if OOBE / ESP is running [credit Michael Niehaus]
 
    $IsOOBEComplete = $false
    $null = [Api.Kernel32]::OOBEComplete([ref] $IsOOBEComplete)
    switch ( $IsOOBEComplete -eq 1 ) {
        $true   { 
            Write-Log -Message "OOBE is complete" -Source ${CmdletName}
            Write-Output -InputObject $true  
        } 
        default {
            Write-Log -Message "OOBE is not complete" -Source ${CmdletName}
            Write-Output -InputObject $false 
        }
    }
    
}

function Save-LatestPowerToysSetup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [ValidateSet('Machine-x64','Machine-ARM64','User-x64','User-ARM64')]
        [string]
        $InstallerType = 'Machine-x64',

        [Parameter(Mandatory=$false)]
        [String]
        $DestinationDirectory = $env:TEMP
    )

    # Disable Progress Bar (speeds up IWR / IRM).
    $ProgressPreferenceOrig = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    [String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

    Write-Log -Message "Downloading PowerToys installer type: [$InstallerType]" -Source ${CmdletName}

    # Obtain URL to assets from latest PowerToys release
    $URL = "https://api.github.com/repos/microsoft/powertoys/releases/latest"
    $AssetsURL = ((Invoke-WebRequest $URL -UseBasicParsing | ConvertFrom-Json)[0]).assets_url
    
    # Set search string based on string parameter value
    switch ( $InstallerType ) {
        'Machine-x64'   { [string]$SearchString = "PowerToysSetup-*-x64.exe" }
        'Machine-ARM64' { [string]$SearchString = "PowerToysSetup-*-arm64.exe" }
        'User-x64'      { [string]$SearchString = "PowerToysUserSetup-*-x64.exe" }
        'User-ARM64'    { [string]$SearchString = "PowerToysUserSetup-*-arm64.exe" }
    }

    # Obtain PowerToys from github
    try {
        
        $PowerToysSetup = (Invoke-WebRequest $AssetsURL -UseBasicParsing -ErrorAction Stop | ConvertFrom-Json) | Where-Object { $_.name -like $SearchString }
        $DownloadURL = $PowerToysSetup.browser_download_url
        $DownloadDst = Join-Path -Path $DestinationDirectory -ChildPath "$($PowerToysSetup.name)"
        Write-Log -Message "Source file name: [$($PowerToysSetup.name)]" -Source ${CmdletName}
        Write-Log -Message "Source URL: [$DownloadURL]" -Source ${CmdletName}
        Write-Log -Message "Destination: [$DownloadDst]" -Source ${CmdletName}
    }
    catch {
        Write-Log -Message "Failed to obtain download link from github`r`n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
    }

    # Invoke download
    try {
        Invoke-RestMethod -Uri $DownloadURL -OutFile $DownloadDst -ErrorAction Stop
        [hashtable]$Results = @{}
        Add-Member -InputObject $Results -MemberType NoteProperty -Name "ShortName" -Value $($PowerToysSetup.name) -Force
        Add-Member -InputObject $Results -MemberType NoteProperty -Name "FullName" -Value $($DownloadDst) -Force
    }
    catch {
        Write-Log -Message "Download failed with message:`r`n[$(Resolve-Error)]" -Severity 3 -Source ${CmdletName}
    }
    
    # Enable Progress Bar
    $ProgressPreference = $ProgressPreferenceOrig

    # Return results
    if ( $Results ) {
        Write-Log -Message "Function finished successfully." -Source ${CmdletName}
        return $Results
    } 
    else {
        Write-Log -Message "Function finished with errors." -Severity 3 -Source ${CmdletName}
        return $null
    }
}

##*===============================================
##* END FUNCTION LISTINGS
##*===============================================

##*===============================================
##* SCRIPT BODY
##*===============================================

If ($scriptParentPath) {
    Write-Log -Message "Script [$($MyInvocation.MyCommand.Definition)] dot-source invoked by [$(((Get-Variable -Name MyInvocation).Value).ScriptName)]" -Source $appDeployToolkitExtName
}
Else {
    Write-Log -Message "Script [$($MyInvocation.MyCommand.Definition)] invoked directly" -Source $appDeployToolkitExtName
}

##*===============================================
##* END SCRIPT BODY
##*===============================================
