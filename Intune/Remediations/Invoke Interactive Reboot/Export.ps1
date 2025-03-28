# Import PSAppDeployToolkit module
if ( $null -eq (Get-Module PSAppDeployToolkit) ) {
    try {
        Import-Module -Name "PSAppDeployToolkit" -ErrorAction Stop   
    }
    catch {
        Write-Output "Failed to import module. Cannot continue."
        Exit 1
    }
}

Initialize-ADTModule
$AdtEnvironment = Get-ADTEnvironment

# Im based in Norway, so message will be presented in Norwegian or English. Customize to your needs.
switch ( $AdtEnvironment.currentUILanguage ) {
    "NB" {
        $Splat = @{
            Title = "Omstart kreves"
            Subtitle = "Vennligst start på nytt"
            Message = "Ta kontakt med Brukerstøtte for mer informasjon om hvorfor du får denne meldingen." 
            ButtonRightText = "Start på nytt nå"
            ButtonLeftText = "Kanskje senere" 
        }
    }
    default {
        $Splat = @{
            Title = "Restart required"
            Subtitle = "Please restart your computer"
            Message = "Contact support for more information on why you recieve this message." 
            ButtonRightText = "Restart now"
            ButtonLeftText = "Maybe later" 
        }
    }
}
#*==========================================================================================
#* Present the message. 
#* 
#* Note: I allow the user to cancel, which for many might not be desired.
#* Review the various prompts available in the PSAppDeployToolkit module and make adjustments.
#* Others might be more suitable in many cases.
#*==========================================================================================
$Result = Show-ADTInstallationPrompt @Splat

# Evaluate results
if ( ($Result -eq "Start på nytt nå") -or ($Result -eq "Restart now") ) {
    Restart-Computer -Force
}