[System.String]$ModuleName = "PSAppDeployToolkit"

# Obtain latest version from gallery
try {
    $LatestModule = Find-Module -Name $ModuleName -Repository PSGallery
}
catch {
    Write-Output "Could not obtain latest version of [$ModuleName] in PSGallery. Cannot continue."
    Exit 0
}

# Obtain installed version
try {
    $InstalledModule = Get-InstalledModule $ModuleName -ErrorAction Stop
}
catch {
    Write-Output "Remediating (module [$ModuleName] not installed)"
    Exit 1
}


[System.Version]$LatestVersion = $LatestModule.Version
[System.Version]$InstalledVersion = $InstalledModule.Version

switch ( $LatestVersion -gt $InstalledVersion ) {
    $true {
        Write-Output "Remediating (new version found for module [$ModuleName])"
        Exit 1
    }
    $false {
        Write-Output "Compliant (no new version found for module [$ModuleName])"
        Exit 0
    }
}