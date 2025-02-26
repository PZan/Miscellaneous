<#
    .SYNOPSIS
    Obtains all PIM roles for current user.

    .DESCRIPTION
    Obtains all PIM roles (eligible role assignment schedule) available to current graph connected user.

    Required Modules: 
        Microsoft.Graph.Identity.Governance, 
        Microsoft.Graph.Authentication
    
    Required Graph Scopes: 
        RoleEligibilitySchedule.Read.Directory,
        RoleManagement.Read.Directory,
        RoleManagement.Read.All
    Note: If there's an active graph connection, the script will validate the scopes. If the required scopes are missing a reconnection will be attempted.

    .PARAMETER NoDisconnect
    Hidden paramter to allow for keeping the active graph connection in the console.

    .EXAMPLE
    PS C:\> $MyPimRoles = .\Get-MyPimRoles.ps1

    .EXAMPLE
    PS C:\> $MyPimRoles = .\Get-MyPimRoles.ps1 -NoDisconnect -Verbose
    
#>
[CmdletBinding()]
param (
    [Parameter(
        Mandatory=$false,
        DontShow=$true,
        Position = 0
    )]
    [switch]
    $NoDisconnect
)
begin {
    $RequiredScopes = "RoleEligibilitySchedule.Read.Directory","RoleManagement.Read.Directory","RoleManagement.Read.All"
    $RequiredScopesString =  $RequiredScopes -join ","
    $MgContext = Get-MgContext

    # Make sure we have a connection with appropriate scopes
    if ( $MgContext ) {
        $CurrentScopes = $MgContext.Scopes
        foreach ( $Permission in $RequiredScopes ) {
            if ( -not ($Permission -in $CurrentScopes) ) {
                Write-Verbose "Missing permission [$Permission]. Reconnecting to graph."
                $null = Disconnect-MgGraph
                $null = Connect-MgGraph -Scopes $RequiredScopesString -NoWelcome
                break
            }
        }
        Write-Verbose "All required permissions confirmed available in context."
    }
    else {
        Write-Verbose "Connecting to graph."
        $null = Connect-MgGraph -Scopes $RequiredScopesString -NoWelcome
    }    
}
process {
    $MgContext = Get-MgContext
    $UserName = $MgContext.Account
    $CurrentUser = Get-MgUser -UserId $UserName
    $UserId = $CurrentUser.Id
    Write-Host "Obtaining Eligible (PIM) Roles for user [$UserName] (ID: [$UserId])"
    $myRoles = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -ExpandProperty RoleDefinition -All -Filter "principalId eq '$UserId'"
}
end {
    #Disconnect Graph 
    if ( $PSBoundParameters.ContainsKey('NoDisconnect') ) {
        Write-Verbose "Keeping connection to Graph"
    } else {
        $null = Disconnect-Graph
    }
    Write-Verbose "Returning roles found"
    Write-Output $myRoles
}