[CmdletBinding()]
Param(
    # Supply path to a csv file. See https://learn.microsoft.com/en-us/mem/intune/enrollment/corporate-identifiers-add#step-1-create-csv-file for details on format.
    [Parameter(Mandatory=$false)]
    [ValidateScript({
        $FilePath = $_
        try {
            $isCsv = $((Get-Item $_ -ErrorAction Stop).Extension) -eq '.csv'
        } catch [System.Exception] {
            throw $_.Exception.Message
        }
        switch ( $isCsv ) {
            $true { return $true }
            default { throw "The file [$FilePath] is not a csv" }
        }
    })]
    [string]
    $CsvFilePath,

    # Supply delimiter string from set.
    [Parameter(Mandatory=$false)]
    [ValidateSet('semicolon','comma')]
    [string]
    $Delimiter = 'comma'
)
begin {
    # connect to Graph
    $shouldConnect = $null -eq (Get-MgContext)
    if ( $shouldConnect ) {
        Write-Verbose "Connecting to graph"
        $GraphConnection = Connect-MgGraph -NoWelcome
        if ( $null -eq $GraphConnection ) {
            throw "Failed to connect to graph."
        }
    }

    # define uri and body
    $Uri = "https://graph.microsoft.com/beta/deviceManagement/importedDeviceIdentities/importDeviceIdentityList"
    $Body = @{
        importedDeviceIdentities = New-Object 'System.Collections.Generic.List[System.Object]'
        overwriteImportedDeviceIdentities = $true
    }
}
process {
    # get contents of csv and convert to object
    try { 
        $Splat = @{
            InputObject = Get-Content $CsvFilePath -ErrorAction Stop
            Delimiter = $(
                switch ( $Delimiter ) {
                    "semicolon" { ";"  }
                    "comma"     { "," }
                }
            )
            Header = 'Manufacturer', 'Model', 'Serialnumber'
            ErrorAction = "Stop"
        }
        $DeviceIdentifiers = ConvertFrom-Csv @Splat   
        Write-Verbose "Successfully loaded Device Identifiers from csv"
    }
    catch [System.Exception] {
        throw "failed to load device identifiers from csv with message: [$($_.Exception.Message)]"
    }
    
    # process each device from csv
    foreach ( $Device in $DeviceIdentifiers ) {    
        #manipulate values to accepted input 
        $Manufacturer = ($Device.Manufacturer) -replace '^([a-zA-Z]{1,50}).*' , '$1'
        $Model = ($Device.Model) -replace '[^a-zA-Z0-9]' , ''
        $Serial = ($Device.Serialnumber) -replace '[^a-zA-Z0-9]' , ''
        
        # add this device to importedDeviceIdentities object in body hashtable.
        $Body.importedDeviceIdentities.Add(@{
            "@odata.type" = "#microsoft.graph.importedDeviceIdentity"; 
            importedDeviceIdentifier="$Manufacturer,$Model,$Serial";
            importedDeviceIdentityType="manufacturerModelSerial"; 
            description="Added via Graph"
        })
    }
    
    try {
        $Splat = @{
            Method = "POST"
            Uri = $Uri
            Body = $Body | ConvertTo-Json
        }
        $Response = Invoke-MgGraphRequest @Splat
        Write-Output "Successfully imported device identities to Corporate Identifiers list."
    }
    catch [System.Exception] {
        throw "failed to import device identities to Intune with message: [$($_.Exception.Message)]"
    }
}
end {
    if ( $shouldConnect ){
        $null = Disconnect-MgGraph
    }

    Write-Output $Response
}