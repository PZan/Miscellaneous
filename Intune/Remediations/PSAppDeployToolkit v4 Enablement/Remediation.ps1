[System.String]$ModuleName = "PSAppDeployToolkit"
$ProgressPreference = "SilentlyContinue"
$InstalledModule = Get-InstalledModule $ModuleName -ErrorAction SilentlyContinue
if ( $InstalledModule ) {
    Write-Output "Updating module [$ModuleName]"
    $null = Update-Module -Name $ModuleName -Force
} else {
    Write-Output "Installing module [$ModuleName]"
    $null = Install-Module $ModuleName -Repository PSGallery -Force 
}