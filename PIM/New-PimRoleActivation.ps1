<#
    .SYNOPSIS
    Activates one or more PIM Roles.

    .DESCRIPTION
    Activates one or more PIM Roles.

    Required Modules: 
        Microsoft.Graph.Identity.Governance, 
        Microsoft.Graph.Authentication
    
    Required Graph Scopes: 
        RoleEligibilitySchedule.Read.Directory,
        RoleEligibilitySchedule.ReadWrite.Directory,
        RoleManagement.ReadWrite.Directory,
        RoleManagement.Read.Directory,
        RoleManagement.Read.All
    Note: If there's an active graph connection, the script will validate the scopes. If the required scopes are missing a reconnection will be attempted.

    .PARAMETER InputObject
    Use Get-MgRoleManagementDirectoryRoleEligibilitySchedule to retrieve valid input objects.

    .PARAMETER Duration
    Create a (sensible) TimeSpan object (New-TimeSpan) to determine for how long the role shall be activated. Exceeding the PIM roles configured maximum duration will result in an error.

    .PARAMETER Justification
    Supply a custom justification that will be added to your request. This is optional. If not supplied a predefined justification will be used.

    .EXAMPLE
    PS C:\> Enable-PimRoleActivation.ps1 -InputObject $MyPimRole -Duration (New-TimeSpan -Hours 1 -Minutes 30)

    .EXAMPLE
    PS C:\> $MyTimeSpan = New-TimeSpan -Hours 1
    PS C:\> $MyPimRoles = .\Get-MyPimRoles.ps1
    PS C:\> $MyJustification = "Activating this role for a very important operation."
    PS C:\> Enable-PimRoleActivation.ps1 -InputObject $MyPimRoles[0] -Duration $MyTimeSpan

    .PARAMETER NoDisconnect
    Hidden paramter to allow for keeping the active graph connection in the console.
#>
[CmdletBinding(DefaultParameterSetName="InputObject")]
param (
    [Parameter(
        Mandatory,
        ParameterSetName = "InputObject",
        ValueFromPipeline,
        Position = 0,
        HelpMessage = "Use Get-MgRoleManagementDirectoryRoleEligibilitySchedule to retrieve valid input objects."
    )]
    [System.Object[]]
    $InputObject,

    [Parameter(
        Mandatory,
        ParameterSetName = "InputObject",
        Position = 1,
        HelpMessage = "Use New-TimeSpan to define a (sensible) duration. Exceeding the PIM roles configured maximum duration will result in an error."
    )]
    [timespan]
    $Duration,

    [Parameter(
        Mandatory=$false,
        Position = 2,
        HelpMessage = "Supply a custom justification that will be added to your request."
    )]
    [string]
    $Justification,

    [Parameter(
        ParameterSetName = "InputObject",
        Mandatory=$false,
        DontShow=$true,
        Position = 3
    )]
    [switch]
    $NoDisconnect
)
begin {

    function Convert-Duration {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory,ValueFromPipeline,Position = 0)]
            [ValidateScript({
                if ($_.GetType().Name -eq 'TimeSpan' -or $_ -match '^P((?<Years>[\d\.,]+)Y)?((?<Months>[\d\.,]+)M)?((?<Weeks>[\d\.,]+)W)?((?<Days>[\d\.,]+)D)?(?<Time>T((?<Hours>[\d\.,]+)H)?((?<Minutes>[\d\.,]+)M)?((?<Seconds>[\d\.,]+)S)?)?$') {
                    $true
                }
                else {
                    throw "Input object was neither a valid ISO8601 format string or a TimeSpan object."
                }
            })]
            [Object]
            $Duration,
            [Parameter(Position = 1)]
            [ValidateSet('TimeSpan','ISO8601','Hashtable','TotalSeconds')]
            [String]
            $Output = 'TimeSpan'
        )
        Begin {
            $validKeys = @('Years','Months','Weeks','Days','Hours','Minutes','Seconds')
        }
        Process {
            switch ($Duration.GetType().Name) {
                String {
                    if ($Duration -match '^P((?<Years>[\d\.,]+)Y)?((?<Months>[\d\.,]+)M)?((?<Weeks>[\d\.,]+)W)?((?<Days>[\d\.,]+)D)?(?<Time>T((?<Hours>[\d\.,]+)H)?((?<Minutes>[\d\.,]+)M)?((?<Seconds>[\d\.,]+)S)?)?$') {
                        if ($Output -eq 'ISO8601') {
                            $Duration
                        }
                        else {
                            $final = @{}
                            $d = Get-Date
                            switch ($Output) {
                                TotalSeconds {
                                    $seconds = 0
                                    foreach ($key in $Matches.Keys | Where-Object {$_ -in $validKeys}) {
                                        Write-Verbose "Matched key '$key' with value '$($Matches[$key])'"
                                        $multiplier = switch ($key) {
                                            Years {
                                                ($d.AddYears(1) - $d).TotalSeconds
                                            }
                                            Months {
                                                ($d.AddMonths(1) - $d).TotalSeconds
                                            }
                                            Weeks {
                                                ($d.AddDays(7) - $d).TotalSeconds
                                            }
                                            Days {
                                                ($d.AddDays(1) - $d).TotalSeconds
                                            }
                                            Hours {
                                                3600
                                            }
                                            Minutes {
                                                60
                                            }
                                            Seconds {
                                                1
                                            }
                                        }
                                        $seconds += ($multiplier * [int]($Matches[$key]))
                                    }
                                    $seconds
                                }
                                TimeSpan {
                                    foreach ($key in $Matches.Keys | Where-Object {$_ -in $validKeys}) {
                                        Write-Verbose "Matched key '$key' with value '$($Matches[$key])'"
                                        if (-not $final.ContainsKey('Days')) {
                                            $final['Days'] = 0
                                        }
                                        switch ($key) {
                                            Years {
                                                $final['Days'] += (($d.AddYears(1) - $d).TotalDays * [int]($Matches[$key]))
                                            }
                                            Months {
                                                $final['Days'] += (($d.AddMonths(1) - $d).TotalDays * [int]($Matches[$key]))
                                            }
                                            Weeks {
                                                $final['Days'] += (7 * [int]($Matches[$key]))
                                            }
                                            Days {
                                                $final['Days'] += [int]($Matches[$key])
                                            }
                                            default {
                                                $final[$key] = [int]($Matches[$key])
                                            }
                                        }
                                        $final['Seconds'] += ($multiplier * [int]($Matches[$key]))
                                    }
                                    New-TimeSpan @final
                                }
                                Hashtable {
                                    foreach ($key in $Matches.Keys | Where-Object {$_ -in $validKeys}) {
                                        Write-Verbose "Matched key '$key' with value '$($Matches[$key])'"
                                        $final[$key] = [int]($Matches[$key])
                                    }
                                    $final
                                }
                            }
                        }
                    }
                    else {
                        Write-Error "Input string was not a valid ISO8601 format! Please reference the Duration section on the Wikipedia page for ISO8601 for syntax: https://en.wikipedia.org/wiki/ISO_8601#Durations"
                    }
                }
                TimeSpan {
                    if ($Output -eq 'TimeSpan') {
                        $Duration
                    }
                    else {
                        $final = @{}
                        $d = Get-Date
                        switch ($Output) {
                            TotalSeconds {
                                $Duration.TotalSeconds
                            }
                            Hashtable {
                                foreach ($key in $validKeys) {
                                    if ($Duration.$key) {
                                        $final[$key] = $Duration.$key
                                    }
                                }
                                $final
                            }
                            ISO8601 {
                                $pt = 'P'
                                if ($Duration.Days) {
                                    $pt += ("{0}D" -f $Duration.Days)
                                }
                                if ($Duration.Hours + $Duration.Minutes + $Duration.Seconds) {
                                    $pt += 'T'
                                    if ($Duration.Hours) {
                                        $pt += ("{0}H" -f $Duration.Hours)
                                    }
                                    if ($Duration.Minutes) {
                                        $pt += ("{0}M" -f $Duration.Minutes)
                                    }
                                    if ($Duration.Seconds) {
                                        $pt += ("{0}S" -f $Duration.Seconds)
                                    }
                                }
                                $pt
                            }
                        }
                    }
                }
            }
        }
    }

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
}
process {
    if ( $InputObject ) {
        $RoleName = $InputObject.RoleDefinition.DisplayName
        if ( ($null -eq $RoleName) -or ($RoleName -eq "") ) {
            Write-Warning "Failed to determine role name. Skipping..."
            return
        } else {
            if ( -not $Justification ) {
                $Justification = "Activating the role [$RoleName] using Graph."
            }
            $params = @{
                Action = "selfActivate"
                PrincipalId = $InputObject.PrincipalId
                RoleDefinitionId = $InputObject.RoleDefinitionId
                DirectoryScopeId = $InputObject.DirectoryScopeId
                Justification = $Justification
                ScheduleInfo = @{
                    StartDateTime = Get-Date
                    Expiration = @{
                        Type = "AfterDuration"
                        Duration = "$(Convert-Duration -Duration $Duration -Output ISO8601)"
                    }
                }
            }
        }
    }
    Write-Verbose "Will attempt to activate role [$RoleName] for a duration of [$Duration]."
    try {
        $null = New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $params -ErrorAction Stop
        Write-Host "Assigned the role [$RoleName] for duration [$Duration]"
    }
    catch [System.Exception] {
        Write-Warning -Message "Role assignment failed with message: [$($_.Exception.Message)]"
    }
}
end {
    #Disconnect Graph 
    if ( $PSBoundParameters.ContainsKey('NoDisconnect') ) {
        Write-Verbose "Keeping connection to Graph"
    } else {
        $null = Disconnect-Graph
    }
}