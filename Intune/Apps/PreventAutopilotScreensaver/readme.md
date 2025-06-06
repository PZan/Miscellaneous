# Prevent Screensaver during Autopilot
This project is intended to prevent  Windows from locking the user session during the user part of Intune Autopilot (Erollment Status Page). 
The end goal is to allow for a complete passwordless experience, which is often intervened by security baseline policies being applied during Autopilot.

I had this idea in my head and after checking in with /r/intune ([link to my post here](https://www.reddit.com/r/Intune/comments/18o9ue5/lock_screen_screen_saver_during_autopilot/)) I decided to go ahead with my mad plans and of course want to share this on GitHub in case others don't want to invent the wheel.

## This PowerShell Application Deployment Toolkit project does the following:

1. Exits if OOBE is not running
   - OOBE (Out-Of-Box-Experience) is the Device Configuration part of Autopilot ESP.
   - The script should be executed as early as possible during Autopilot, so that the screen doesn't lock before we get a chance to circumvent to issue. 
2. Downloads and installs the latest x64 installer of Microsoft PowerToys 
   - [Via Microsoft GitHub repository](https://github.com/microsoft/PowerToys)
   - (we want the Awake tool from PowerToys)
3. Copy files to Program Files project folder
   - cleanup script, run-awake-as-user script, powertoys installer (uninstaller)
4. Creates a scheduled task to run Awake as 'current user' once the Autopilot process enters the user part of the ESP 
   - Awake must run as user to work properly
   - This task is triggered by Event ID 358 in the User Device Registration Event Log
   - Utilizes PSADT and its Execute-ProcessAsUser cmdlet.
5. Creates a scheduled task to perform cleanup once ESP is complete (when WHfB has been configured)
   - For safety purposes this task has multiple triggers
     - WHfB [Event ID 300](https://learn.microsoft.com/en-us/troubleshoot/windows-client/user-profiles-and-logon/event-id-300-windows-hello-successfully-created-in-windows-10) and Event ID 324 (User Cancel)
     - On System Startup (performs cleanup on reboot)
     - After 24h
   - The cleanup script uninstalls PowerToys, unregisters the scheduled tasks and deletes the files copied to Program Files.
  
## How to implement:
1. Download the project.
2. Make adjustments to Deploy-Application.ps1 script if desired (for example appVendor is used when registering the Scheduled Tasks, and you might want to modify the cleanup start/end boundary)
3. Create an Intune Win32 App with the Microsoft Win32 Content Prep Tool and create/upload the app in intune
4. Make two custom requirement rules using the scripts Requirement-InOOBE.ps1 and Requirement-IsAutopilotRunning.ps1
   - This is important as this will prevent the package from assigning on devices where Autopilot is not running
   - Both scripts returns either true or false (yes or no in the Intune Admin Center Web GUI) and both rules must be set to True ('yes')
5. For detection check the existence of the folder %ProgramFiles%\Prevent-Screensaver-During-Autopilot
6. Assign as required to your target devices (NOT User!)
7. Make sure the assignment is in the list of Blocking Apps on you ESP Properties ("Block device use until required apps are installed if they are assigned to the user/device")
8. Et Voilà. Give it a test!
