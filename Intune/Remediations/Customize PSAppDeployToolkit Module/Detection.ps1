# Sha256 hash value of my custom AppIcon.png
$ExpectedAppIconHash = "936AE349896E9F85D9EEAB05340F5D03C4A875D5052B81E321FCE839D8988775"

# Sha256 hash value of my custom Banner.Classic.png
$ExpectedBannerClassicHash = "BD36ECE01B62680606019A1C2CE6E9D1B69AD5D655BE58CA635FF6B05B6B3020"

# Get latest installed psappdeploytoolkit version
try {
    $LatestInstalledModule = Get-Module PSAppDeployToolkit -ListAvailable -ErrorAction Stop | Sort-Object Version -Descending | Select-Object -First 1
}
catch {
    Write-Output "Failed to obtain installed module. Cannot continue."
    Exit 0
}

# Determine if latest installed module version has our custom assets
if ( $LatestInstalledModule ) {
    $ModuleDir = $LatestInstalledModule.Path | Split-Path -Parent
    $AppIconPath = Join-Path -Path $ModuleDir -ChildPath "Assets\AppIcon.png"
    $FoundAppIconHash = Get-FileHash $AppIconPath
    $BannerClassicPath = Join-Path -Path $ModuleDir -ChildPath "Assets\Banner.Classic.png"
    $FoundBannerClassicHash = Get-FileHash $BannerClassicPath

    if ( ($FoundAppIconHash.Hash -eq $ExpectedAppIconHash) -and ($FoundBannerClassicHash.Hash -eq $ExpectedBannerClassicHash) ) {
        Write-Output "Compliant!"
        Exit 0
    } else {
        Write-Output "Not compliant!"
        Exit 1
    }

} else {
    Write-Output "PSAppDeployToolkit module does not appear to be installed. Cannot continue."
    Exit 0
}

