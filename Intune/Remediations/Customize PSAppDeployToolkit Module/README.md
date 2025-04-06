# About this remediation
This remediation customizes the assets (png files) in the current latest version of  PSAppDeployToolkit  module in the AllUsers scope.

The detection script matches the file hash of the assets and the remediation script replaces the files with your custom files, stored as base64 strings in the script.

## How to implement customized assets?
1. Make your custom AppIcon.png and Banner.Classic.png
2. Get the file hash of each file and replace the variables `$ExpectedAppIconHash` and `$ExpectedBannerClassicHash` in your detection script
 - `(Get-FileHash .\AppIcon.png).Hash | Set-Clipboard`
3. Convert your file contents to base64 strings and replace the variables `$AppIconBase64` and `$BannerClassicBase64`
 - `[system.Convert]::ToBase64String($(Get-Content .\AppIcon.png -Encoding byte)) | Set-Clipboard`