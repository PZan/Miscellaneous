[CmdletBinding()]
param ()

$RequiredScopes = "RoleEligibilitySchedule.Read.Directory","RoleEligibilitySchedule.ReadWrite.Directory","RoleManagement.ReadWrite.Directory","RoleManagement.Read.Directory","RoleManagement.Read.All"
$RequiredScopesString =  $RequiredScopes -join ","
$MgContext = Get-MgContext

# Make sure we have a connection with appropriate scopes
if ( $MgContext ) {
    
    $CurrentScopes = $MgContext.Scopes
    foreach ( $Permission in $RequiredScopes ) {
        if ( -not ($Permission -in $CurrentScopes) ) {
            Write-Verbose "Missing permission [$Permission]. Reconnecting to graph."
            $null = Disconnect-MgGraph
            $null = Connect-MgGraph -Scopes $RequiredScopesString
            break
        }
    }
    Write-Verbose "All required permissions confirmed available in context."
}
else {
    Write-Verbose "Connecting to graph."
    Connect-MgGraph -Scopes $RequiredScopesString
}

$currentUser = (Get-MgUser -UserId $MgContext.Account).Id

$myRoles = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -ExpandProperty RoleDefinition -All -Filter "principalId eq '$currentuser'"

return $myRoles