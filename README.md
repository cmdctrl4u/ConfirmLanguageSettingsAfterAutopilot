**Update July 2025:** The package now includes a file to modify different settings (AppName, CompanyName, NTP settings, Zscaler and Network IPs etc.) to your needs on a central place. You can also activate and deactivate the test mode in this file.

Confirm language settings after Autopilot\source\Files\**GlobalVariables.ps1**

At the root path I also added information regarding Intune and the makeapp.cmd to create the intune-file.

**Original:**

Confirm or modify timezone, OS language and/or keyboard layout after Autopilot

I got the idea from Niall Brady’s great script “Prompting standard users to confirm or change Regional, Time Zone, and Country settings after Windows Autopilot enrollment is complete.”

Thank you, Niall, for this outstanding solution! Here is the link to the original post:

https://www.niallbrady.com/2021/12/15/prompting-standard-users-to-confirm-or-change-regional-time-zone-and-country-settings-after-windows-autopilot-enrollment-is-complete/

Objective: After the Autopilot process, the user is presented with a prompt displaying the currently configured time zone, operating system language, and keyboard layout. The user can either confirm or adjust these settings.

Check out my blog for more information about the modified solution:

https://cmdctrl4u.wordpress.com/2025/03/14/confirm-timezone-language-and-keyboard-layout-after-autopilot/
