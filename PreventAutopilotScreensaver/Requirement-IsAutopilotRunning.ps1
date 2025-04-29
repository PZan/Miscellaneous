$isAutopilotRunning = $false
$WWAHostRunning = $null -ne (Get-Process -Name "WWAHost" -ErrorAction SilentlyContinue)
if ($WWAHostRunning) {
    $FirstSyncPath = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Enrollments" -Recurse | Where-Object { $_.PSChildName -contains "FirstSync" }
    if ( $FirstSyncPath ) {
        switch ((Get-ItemProperty -Path $FirstSyncPath.PSPath -Name "IsSyncDone" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty IsSyncDone) -ne '1') {
            $true {
                $isAutopilotRunning = $true
            }
        }
    }
}
Write-Output $isAutopilotRunning
Exit 0