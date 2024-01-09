# Check if OOBE / ESP is running [credit Michael Niehaus]
$TypeDef = @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
namespace Api
{
    public class Kernel32
    {
        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern int OOBEComplete(ref int bIsOOBEComplete);
    }
}
"@
Add-Type -TypeDefinition $TypeDef -Language CSharp
$IsOOBEComplete = $false
$null = [Api.Kernel32]::OOBEComplete([ref] $IsOOBEComplete)
switch ( $IsOOBEComplete -eq 1 ) {
    $true   { Write-Output -InputObject "Not Eligible"  } 
    default { Write-Output -InputObject "Eligible" }
}