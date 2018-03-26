<#
.Synopsis
   Sets default Web Browser on Windows 10 on systems where there's an AppAssoc xml file defined.
.DESCRIPTION
   Sets default Web Browser on Windows 10 on systems where there's an AppAssoc XML file defined (commonly via GPO). The function searches for web browser related file types and protocols in the xml file and replaces it with the any of the predefined choices of Iexplore, Edge, Chrome Firefox.
   https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/dism-default-application-association-servicing-command-line-options
.EXAMPLE
   Set-DefaultWebBrowser -WebBrowser Chrome
.EXAMPLE
   Set-DefaultWebBrowser -WebBrowser Chrome -Path '\\client1\C$\ProgramData\AppAssoc.xml'
#>
[CmdletBinding(
    SupportsShouldProcess = $true,
    ConfirmImpact = 'High'
)]
Param (
    # Choose one of the four defined web browsers Iexplore, Edge, Chrome or Firefox
    [Parameter(Mandatory=$true,Position=0)]
    [ValidateSet('InternetExplorer','Edge','Chrome','Firefox')]
    [string]$WebBrowser,
    # Path to the XML file where default application associations are stored. Default is collected from registry.
    [Parameter(Mandatory=$false,Position=1)]
    [string]$Path = $(Get-ItemProperty -LiteralPath "REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System" -Name DefaultAssociationsConfiguration -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DefaultAssociationsConfiguration)
)
Begin {
    # Prompt for confirmation if path is UNC and confirm is not set to $false.
    if($Path -like "\\*" -and $ConfirmPreference.value__ -gt 0) {
        Write-Warning -Message "It appears that the path to the default application associations xml file is located on a network share ($Path). Changes to this file can potentially affect multiple systems. Please confirm before proceeding."
        # Prompt to confirm
        [int]$Confirm = 0
        [string]$prompt = Read-Host "Type [Y]es to accept the changes. Any other input will stop the execution of this script."
        switch ( $prompt.ToUpper() ) {
            "YES" { $Confirm = 1; break }
            "Y"   { $Confirm = 1; break }
        }
            
        if ( $Confirm -eq 0 ) {
            Write-Warning "Process stopped by user"
            ## Exit the script, returning the exit code 1602 (ERROR_INSTALL_USEREXIT)
            If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1602; Exit } Else { Exit 1602 }
        }
    }
    # Construct a valid path. This is necessary specifically when the policy defined includes system variables.
    [string]$XMLFilePath = ""
    $Path.Split("%") | ForEach-Object {
        Switch ($_) {
            SystemDrive {$XMLFilePath += $($env:SystemDrive)}
            ALLUSERSPROFILE {$XMLFilePath += $($env:ALLUSERSPROFILE)}
            CommonProgramFiles {$XMLFilePath += $($env:CommonProgramFiles)}
            "COMMONPROGRAMFILES(x86)"	 {$XMLFilePath += $(${env:CommonProgramFiles(x86)})}
            ProgramData {$XMLFilePath += $($env:ProgramData)}
            ProgramFiles {$XMLFilePath += $($env:ProgramFiles)}
            "ProgramFiles(x86)" {$XMLFilePath += $(${env:ProgramFiles(x86)})}
            SYSTEMROOT {$XMLFilePath += $($env:SystemRoot)}
            TEMP {$XMLFilePath += $($env:TEMP)}
            WINDIR {$XMLFilePath += $($env:windir)}
            default {$XMLFilePath += $_}
        }
    }
    if ( ! ( Test-Path -LiteralPath $XMLFilePath -PathType Leaf ) ) {
        Write-Warning "File not found in path $Path"
        If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 }
    }
}
Process {
    Switch ( $WebBrowser ) {
        InternetExplorer {
            [array]$FileTypeHTM = @("htmlfile","Internet Explorer")
            [array]$FileTypeHTML = @("htmlfile","Internet Explorer")
            [array]$FileTypeURL = @("IE.AssocFile.URL","Internet Explorer")
            [array]$FileTypeWebsite = @("IE.AssocFile.WEBSITE","Internet Explorer")
            [array]$ProtocolHTTP = @("IE.HTTP","Internet Explorer")
            [array]$ProtocolHTTPS = @("IE.HTTPS","Internet Explorer")       
        }
        Edge {
            [array]$FileTypeHTM = @("AppXvepbp3z66accmsd0x877zbbxjctkpr6t","Microsoft Edge")
            [array]$FileTypeHTML = @("AppXvepbp3z66accmsd0x877zbbxjctkpr6t","Microsoft Edge")
            [array]$FileTypeURL = @("AppXvepbp3z66accmsd0x877zbbxjctkpr6t","Microsoft Edge")
            [array]$FileTypeWebsite = @("AppXvepbp3z66accmsd0x877zbbxjctkpr6t","Microsoft Edge")
            [array]$ProtocolHTTP = @("AppXvepbp3z66accmsd0x877zbbxjctkpr6t","Microsoft Edge")
            [array]$ProtocolHTTPS = @("AppXvepbp3z66accmsd0x877zbbxjctkpr6t","Microsoft Edge") 
        }
        Chrome {
            [array]$FileTypeHTM = @("ChromeHTML","Google Chrome")
            [array]$FileTypeHTML = @("ChromeHTML","Google Chrome")
            [array]$FileTypeURL = @("ChromeHTML","Google Chrome")
            [array]$FileTypeWebsite = @("ChromeHTML","Google Chrome")
            [array]$ProtocolHTTP = @("ChromeHTML","Google Chrome")
            [array]$ProtocolHTTPS = @("ChromeHTML","Google Chrome")
        }
        Firefox {
            [array]$FileTypeHTM = @("FirefoxHTML","Mozilla Firefox")
            [array]$FileTypeHTML = @("FirefoxHTML","Mozilla Firefox")
            [array]$FileTypeURL = @("FirefoxHTML","Mozilla Firefox")
            [array]$FileTypeWebsite = @("FirefoxHTML","Mozilla Firefox")
            [array]$ProtocolHTTP = @("FirefoxHTML","Mozilla Firefox")
            [array]$ProtocolHTTPS = @("FirefoxHTML","Mozilla Firefox")
        }
    }
    try {
        # Expect no changes to the xml file.
        [bool]$hasChanged = $false
        [array]$WebTypes = ".htm",".html",".url",".website","http","https"
        # Load XML file
        [Xml.XmlDocument]$DefaultAssociationsXMLFile = Get-Content -LiteralPath $XMLFilePath
        # Get all DefaultAssociations node
        [Xml.XmlElement]$XMLElementDefaultAssociations = $DefaultAssociationsXMLFile.DefaultAssociations 
        # Get Associations node under DefaultAssociations node
        $FileTypeAssociations = $XMLElementDefaultAssociations.Association
        # Add Attribute if not found in list of default apps xml file.
        foreach ($WebType in $WebTypes) {
            if ($WebType -notin $FileTypeAssociations.Identifier ) {
                # The type was not found in the xml file. Let's add it.
                switch ($WebType) {
                    .htm { $ProgId = $FileTypeHTM[0]; $AppName = $FileTypeHTM[1]; }
                    .html { $ProgId = $FileTypeHTML[0]; $AppName = $FileTypeHTML[1]; }
                    .url { $ProgId = $FileTypeURL[0]; $AppName = $FileTypeURL[1];  }
                    .website { $ProgId = $FileTypeWebsite[0]; $AppName = $FileTypeWebsite[1]; }
                    http { $ProgId = $ProtocolHTTP[0]; $AppName = $ProtocolHTTP[1]; }
                    https { $ProgId = $ProtocolHTTPS[0]; $AppName = $ProtocolHTTPS[1]; }
                }
                $newAssociation = $DefaultAssociationsXMLFile.CreateElement("Association")
                $newAssociation.SetAttribute("Identifier","$WebType")
                $newAssociation.SetAttribute("ProgId","$ProgId")
                $newAssociation.SetAttribute("ApplicationName","$AppName")
                $XMLElementDefaultAssociations.AppendChild($newAssociation) | Out-Null
                [bool]$hasChanged = $true
            }
        }
        # Process existing file type and protocol associations, and match web related file types and protocols.
        $FileTypeAssociations | ForEach-Object { 
            if ( $_.Identifier -eq ".htm" ) {
                if( $_.ApplicationName -ne $FileTypeHTM[1] ) {
                    $_.SetAttribute("ProgId","$($FileTypeHTM[0])")
                    $_.SetAttribute("ApplicationName","$($FileTypeHTM[1])")
                    $hasChanged = $true
                    Write-Verbose "Setting file type association ($($_.Identifier)) to $WebBrowser"
                }
            } elseif ( $_.Identifier -eq ".html" ) {
                if( $_.ApplicationName -ne $FileTypeHTML[1] ) {
                    $_.SetAttribute("ProgId","$($FileTypeHTML[0])")
                    $_.SetAttribute("ApplicationName","$($FileTypeHTML[1])")
                    $hasChanged = $true
                    Write-Verbose "Setting file type association ($($_.Identifier)) to $WebBrowser"
                }
            } elseif ( $_.Identifier -eq ".url" ) {
                if( $_.ApplicationName -ne $FileTypeURL[1] ) {
                    $_.SetAttribute("ProgId","$($FileTypeURL[0])")
                    $_.SetAttribute("ApplicationName","$($FileTypeURL[1])")
                    $hasChanged = $true
                    Write-Verbose "Setting file type association ($($_.Identifier)) to $WebBrowser"
                }
            } elseif ( $_.Identifier -eq ".website" ) {
                if( $_.ApplicationName -ne $FileTypeWebsite[1] ) {
                    $_.SetAttribute("ProgId","$($FileTypeWebsite[0])")
                    $_.SetAttribute("ApplicationName","$($FileTypeWebsite[1])")
                    $hasChanged = $true
                    Write-Verbose "Setting file type association ($($_.Identifier)) to $WebBrowser"
                }
            } elseif ( $_.Identifier -eq "http" ) {
                if( $_.ApplicationName -ne $ProtocolHTTP[1] ) {
                    $_.SetAttribute("ProgId","$($ProtocolHTTP[0])")
                    $_.SetAttribute("ApplicationName","$($ProtocolHTTP[1])")
                    Write-Verbose "Setting protocol association ($($_.Identifier)) to $WebBrowser"
                }
            } elseif ( $_.Identifier -eq "https" ) {
                if( $_.ApplicationName -ne $ProtocolHTTPS[1] ) {
                    $_.SetAttribute("ProgId","$($ProtocolHTTPS[0])")
                    $_.SetAttribute("ApplicationName","$($ProtocolHTTPS[1])")
                    $hasChanged = $true
                    Write-Verbose "Setting protocol association ($($_.Identifier)) to $WebBrowser"
                }
            }
        }
        # Update XML file if changes were made.
        if( $hasChanged ) {
            $DefaultAssociationsXMLFile.Save($XMLFilePath)
            Write-Verbose "Successfully updated xml file in path $XMLFilePath!"
        }
    } catch {
        Write-Error "An error occured while updating file type and protocol associations."
        If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = 1603; Exit } Else { Exit 1603 }
    }
}
End {
    if ( $hasChanged ) {
        Write-Host "File type and/or protocol associations has been updated. Log off / log on is required for the changes to take place."
        return $true
    } else {
        Write-Host "No changes were made to the file."
    }
}