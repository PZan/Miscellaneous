<#
.SYNOPSIS
    List, approve or decline drivers in Intune Windows Update for Business.
.DESCRIPTION
    List, approve or deckube drivers in Intune Windows Update for Business.
    
    Required modules (will be installed if missing):
        Microsoft.Graph.Authentication
        Microsoft.Graph.Beta.DeviceManagement.Actions
    
    Required Graph Scopes:
        DeviceManagementConfiguration.ReadWrite.All
    
.PARAMETER DriverClass
    Supply 'All' or a specific driver class to target.
.PARAMETER Action
    Determine what bulk action to be made (default is Show).
.PARAMETER Category
    Determines which categories to scope: all, recommended or others. If not supplied only recommended drivers will be handled.
.PARAMETER FilterByName
    Filter drivers by name (wildcard)
.PARAMETER ProfileName
    Supply value if you want to target a specific driver profile. Ommit if you want to target all profiles.
.EXAMPLE
    .\DriverProfilesBulkAction.ps1 -DriverClass Firmware -Action Approve -ProfileName PilotProfile
#>
[CmdletBinding()]
param (
    [Parameter(
        Mandatory=$true,
        HelpMessage = "Supply 'All' or a specific driver class to target."
    )]
    [string]
    [ValidateSet('All','Firmware','Networking','OtherHardware','SoftwareComponent','System','Monitor','Bluetooth','Video')]
    $DriverClass='All',

    [Parameter(
        Mandatory=$true,
        HelpMessage = "Determine what bulk action to be made (default is Show)."
    )]
    [string]
    [ValidateSet('Approve','Decline','Show')]
    $Action='Show',

    [Parameter(
        Mandatory=$false,
        HelpMessage="Determines which categories to scope: all, recommended or others. If not supplied only recommended drivers will be handled."
    )]
    [string]
    [ValidateSet('All','Recommended','Other')]
    $Category,
    
    [Parameter(
        Mandatory=$false,
        HelpMessage = "Filter drivers by name (wildcard)"
    )]
    [string]
    $FilterByName,

    [Parameter(
        Mandatory=$false,
        HelpMessage="Supply value if you want to target a specific driver profile. Ommit if you want to target all profiles"
    )]
    [string]
    $ProfileName,

    [Parameter(
        Mandatory=$false,
        DontShow=$true
    )]
    [switch]
    $NoDisconnect
)

if (-not (Get-Module Microsoft.Graph.Authentication -ListAvailable)) {
    Install-Module Microsoft.Graph.Authentication
}

if (-not (Get-Module Microsoft.Graph.Beta.DeviceManagement.Actions -ListAvailable)) {
    Install-Module Microsoft.Graph.Beta.DeviceManagement.Actions
}
    
# Import the necessary module
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Beta.DeviceManagement.Actions
    
# Authenticate with an MFA enabled account
$null = Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All" -NoWelcome

#get all the profile ids
# Define the initial URL for the query  
$url = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles/"

# Use Invoke-MgGraphRequest to send a GET request to the specified URL and get the response  
$response = Invoke-MgGraphRequest -Uri $url -Method GET

if ( $ProfileName ) {
    $ResponseObj = $response.value | Where-Object { $_.displayName -eq $ProfileName }

    if ( ($ResponseObj | Measure-Object).Count -lt 1 ) {
        Write-Warning "No Driver Profiles found using filter [$ProfileName]."
    }

} else {
    $ResponseObj = $response.value
}

$OutputObject = New-Object System.Collections.Generic.List[object]
if ($null -eq $Category ) { $Category = "Recommended" }
Write-Host "Performing action: [$Action]"
Write-Host "Category: [$Category]"
Write-Host "Filter by name: [$($null -ne $FilterByName)]"

switch ( $Category ) {
    'Other' {
        $FilterString = "category+eq+'other'"
    }
    'All' {
        $FilterString = "(category+eq+'recommended'+or+category+eq+'other')"
    }
    Default {
        $FilterString = "category+eq+'recommended'"
    }
}

if ( $DriverClass -ne 'All' ) {
    $FilterString += "+and+driverClass+eq+'$($DriverClass)'"
}

if ( $FilterByName ) {
    $FilterString += "+and+contains(name,'$($FilterByName)')"
}

$FilterString += "+and+approvalstatus+eq+'needsreview'"

foreach ($driverprofile in $ResponseObj ) {
    Write-Host "Current Drivers Profile: [$($driverprofile.displayName)]"
    Write-Host "Profile Id: [$($driverprofile.id)]"
    Write-Host "Filter: [$FilterString]" 
    # Get the id for the current item
    $driverprofileid = $driverprofile.id 

    # Define the initial URL for the query
    $url = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles/$driverprofileid/driverInventories?`$filter=$($FilterString)"
    Write-Host "URL: [$url]"
    do {
        
        # Use Invoke-MgGraphRequest to send a GET request to the specified URL and get the response
        $Drivers = Invoke-MgGraphRequest -Uri $url -Method GET        

        # Loop through each item in the 'value' property of the response
        foreach ($item in $Drivers.value) {
            $OutputObject.Add($item)
            switch ( $Action ) {
                'Approve' {
                    $params = @{
                        actionName     = 'Approve'
                        driverIds      = @(
                            $($item.id)
                        )
                        #deploymentDate = [System.DateTime]::Parse("2023-11-30T23:00:00.000Z")  
                        deploymentDate = Get-Date
                    }
                    Write-Host "Performing Action [$($params.actionName)] on driver (id: [$($item.id)], name: [$($item.name)])"
                    # Invoke the command with the specified parameters
                    $null = Invoke-MgBetaExecuteDeviceManagementWindowsDriverUpdateProfileAction -WindowsDriverUpdateProfileId $driverprofileid -BodyParameter $params
                }
                'Decline' {
                    # Define the parameters for the Invoke-MgBetaExecuteDeviceManagementWindowsDriverUpdateProfileAction command
                    $params = @{
                        actionName     = 'Decline'
                        driverIds      = @(
                            $($item.id)
                        )
                    }
                    Write-Output "Performing Action [$($params.actionName)] on driver (id: [$($item.id)], name: [$($item.name)])"
                    # Invoke the command with the specified parameters
                    $null = Invoke-MgBetaExecuteDeviceManagementWindowsDriverUpdateProfileAction -WindowsDriverUpdateProfileId $driverprofileid -BodyParameter $params
                }
            }
            
            
        }  

        # Get the next page link
        $url = $response2.'@odata.nextLink'
    } while (
        # Continue as long as there's a next page link
        $null -ne $url
    )

}

Write-Output $OutputObject

#Disconnect Graph 
if ( $PSBoundParameters.ContainsKey('NoDisconnect') ) {
    Write-Host "Keeping connection to Graph"
} else {
    $null = Disconnect-Graph
}