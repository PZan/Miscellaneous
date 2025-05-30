# Define minimum required version
$DisplayName = "Windows Subsystem for Linux"
$ExpectedVersion = "2.5.7.0"

# Process each key in Uninstall registry path and detect if application is installed, or if a newer version exists that should be superseeded
$UninstallKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
$UninstallKeys = Get-ChildItem -Path $UninstallKeyPath
foreach ($UninstallKey in $UninstallKeys) {
    $CurrentUninstallKey = Get-ItemProperty -Path $UninstallKey.PSPath -ErrorAction "SilentlyContinue"
    if ($CurrentUninstallKey.DisplayName -like $DisplayName) {
        $CurrentUninstallKey.Display
        $CurrentUninstallKey.PSPath
        $InstalledVersion = $CurrentUninstallKey.DisplayVersion
    }
}

switch ($InstalledVersion -ge $ExpectedVersion) {
    $true { 
        Write-Output "Installed"
        Exit 0
    }
    $false {
        Write-Output "Not installed"
        Exit 1
    }
}