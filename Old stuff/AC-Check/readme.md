# About AC-check
AC-Check is a modified PowerShell Application Deployment Toolkit package inteded to be used with a SCCM Task Sequence.

The script will only reach completion (exitcode 0) if it can successfully detect a connected power adapter. If an active user session is detected it will present a text for the user asking them to plugin the power. If no user is logged in and the device is running on battery, the script will return exitcode 1603 (failure).

This is a rather quick fix (I'm sure there's lots of room for improvement) in order to get the user to perform necessary actions before starting a process such as Driver/BIOS/Firmware maintenance and it will result in a failed TS attempt on devices where the user is AFK for too long time. But it saves you the trouble of having devices run out of battery while writing firmware changes to hardware and so on.

*You may want to make changes in Deploy-Application.ps1 (naming), AppDeployToolkitConfig.xml (translation) and AppDeployToolkitMain.ps1 (positioning of items).*

# How to implement
1. Create a New Package and distribute.
2. In your Task Sequence, create a Run Command Line step
 - **Command line:** ServiceUI.exe "Deploy-Application.exe"
 - **Package:** AC Check 1.0
 
 *ServiceUI is required to make the process interactive*
