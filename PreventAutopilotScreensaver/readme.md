This project is intended to prevent  Windows from locking the user session during the user part of Intune Autopilot (Erollment Status Page). 
The end goal is to allow for a complete passwordless experience, which is often intervened by security baseline policies being applied during Autopilot.

I had this idea in my head and after checking in with /r/intune ([link to my post here](https://www.reddit.com/r/Intune/comments/18o9ue5/lock_screen_screen_saver_during_autopilot/)) I decided to go ahead with my mad plans and of course want to share this on GitHub in case others don't want to invent the wheel.

This PowerShell Application Deployment Toolkit project does the following:

1. Exits if OOBE is not running
2. Downloads and installs the latest x64 installer of Microsoft PowerToys 
   - Via Microsoft GitHub repository
   - (we want the Awake tool from PowerToys)
3. Copy files to Program Files project folder
   - cleanup script, run-awake-as-user script, powertoys uninstaller
4. Creates a scheduled task to run Awake as user once the Autopilot process enters the user part of the ESP 
   - Awake must run as user to work properly
   - This task is triggered by Event ID 358 in the User Device Registration Event Log and utilizes PSADT
5. Creates a scheduled task to perform cleanup once ESP is complete (when WHfB has been configured)
   - For safety purposes this task has multiple triggers (WHfB Event ID 300 and 324, on Startup and also after 24h)
   - The cleanup script uninstalls PowerToys, unregisters the scheduled tasks and deletes the files copied to Program Files.
  
How to implement:
1. Download the project.
2. Make adjustments to Deploy-Application.ps1 script if desired (for example appVendor is used when registering the Scheduled Tasks, and you might want to modify the cleanup start/end boundary)
3. Create an Intune Win32 App with the Microsoft Win32 Content Prep Tool and create/upload the app in intune
4. Make a custom requirement rule and use the Requirement-InOOBE.ps1 script!
   - This is important as this will prevent the script from assigning on devices where OOBE is complete!
   - The Requirement-InOOBE.ps1 script returns either 'Eligible' or 'Not eligible'
5. For detection check the existence of the folder %ProgramFiles%\Prevent-Screensaver-During-Autopilot
6. Assign as required to your target devices (NOT User!)
7. Make sure the assignment is in the list of Blocking Apps on you ESP Properties ("Block device use until required apps are installed if they are assigned to the user/device")
8. Et Voilà. Give it a test!
