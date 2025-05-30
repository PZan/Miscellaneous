# Determine if in OOBE
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
# 0 means we're in OOBE
switch ($IsOOBEComplete -eq 0) {
    $true {
        $inOOBE = $true
    }
    $false {
        $inOOBE = $false
    }
}
Write-Output $inOOBE