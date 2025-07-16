<#
Changeable variables in this script

$hours = 4380           > Modify this value if you want to define a different run period. This value should match with value in all scripts: Install_SetTimeZone, SetTimeZone-GUI, App_SetTimeZone
$hoursDetected = "1"    > Uncomment in script for testing. !! DO NOT FORGET to comment again before using this script in production

#>
# Check if Powershell is running in 32-bit or 64-bit. If 32-bit switch further execution to 64-bit.

[CmdletBinding()]
param
(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [System.String]$DeploymentType = 'Install',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [System.String]$DeployMode = 'Interactive',

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$AllowRebootPassThru,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$TerminalServerMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$DisableLogging
)

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ParentPath = Split-Path -Parent $ScriptRoot
. "$ParentPath\GlobalVariables.ps1"

##================================================
## MARK: Variables
##================================================

$adtSession = @{
    # App variables.
    AppVendor                   = $GVCompanyname
    AppName                     = $GVAppName +' - GUI'
    AppVersion                  = ''
    AppArch                     = ''
    AppLang                     = 'EN'
    AppRevision                 = '01'
    AppSuccessExitCodes         = @(0)
    AppRebootExitCodes          = @(1641, 3010)
    AppScriptVersion            = '1.0.0'
    AppScriptDate               = '2025-01-29'
    AppScriptAuthor             = 'M. Langenhoff'

    # Install Titles (Only set here to override defaults set by the toolkit).
    InstallName                 = ''
    InstallTitle                = ''

    # Script variables.
    DeployAppScriptFriendlyName = $MyInvocation.MyCommand.Name
    DeployAppScriptVersion      = '4.0.5'
    DeployAppScriptParameters   = $PSBoundParameters
}

function Install-ADTDeployment {
    ##================================================
    ## MARK: Pre-Install
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    # Log installation start
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Start logging..."
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Starting the pre-installation of $($adtSession.AppVendor) - $($adtSession.AppName)" 

    ####################################################################################################
    ## Variables and additional information
    ####################################################################################################

    $hours = $GVhours  # Time frame, starting from installation date, within this script should run. 
    $EnrollDateTime = (Get-Item -Path "$envProgramFilesX86\Microsoft Intune Management Extension").CreationTimeUtc # Get the installation date of Microsoft Intune Management Extension
    $TimeNow = Get-Date # Get the current date
    $TimeDifference = $TimeNow - $EnrollDateTime # Calculate the time difference in hours since installation
    $hoursDetected = [math]::Round($TimeDifference.TotalHours, 2) # Calculate the time difference in hours and round it to 2 decimal places
    
    #For  testing. !! DO NOT FORGET to set $GVTestMode to 'False' before using this script in production
    if($GVTestMode -eq $True) {
        $TimeDifference = 1 # Set to 1 hour for testing purposes
    }
    else {
        $TimeDifference = $TimeDifference # Use the actual time difference in production
    }
    
   
    $registrypath = "HKCU:\Software\WOW6432Node\$($adtSession.AppVendor)\ComputerManagement\Autopilot"
    $regKey = 'Autopilot'
    $csvZoneMapping = "$envProgramData\$($adtSession.AppVendor)\$GVAppName\GUI\Files\zonemapping.csv"
    $csvGeoIDs = "$envProgramData\$($adtSession.AppVendor)\$GVAppName\GUI\Files\GeoIDs.csv"
    $csvWindowsLCID = "$envProgramData\$($adtSession.AppVendor)\$GVAppName\GUI\Files\WindowsLCID.csv"
    $csvTimeZones = "$envProgramData\$($adtSession.AppVendor)\$GVAppName\GUI\Files\TimeZones.csv" 
    $CsvResults = "$envProgramData\$($adtSession.AppVendor)\$GVAppName\GUI\Files\results.csv"


    Write-Host "Is 64bit PowerShell: $([Environment]::Is64BitProcess)"
    Write-Host "Is 64bit OS: $([Environment]::Is64BitOperatingSystem)"

    if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
        
        write-warning "Running in 32-bit Powershell, starting 64-bit..."
        if ($myInvocation.Line) {
            &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile $myInvocation.Line
        }
        else {
            &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile -file "$($myInvocation.InvocationName)" $args
        }
                
        exit $lastexitcode
    }

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress -StatusMessage "Initializing installation of $($adtSession.AppVendor) - $($adtSession.AppName)"

    ## <Perform Pre-Installation tasks here>

    Function RemoveScheduledTask {
 
        try {
            Show-ADTInstallationProgress -StatusMessage "About to remove scheduled task: $TaskName..."
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop | Out-Null
            Show-ADTInstallationProgress -StatusMessage "Successfully removed the scheduled task"
            return $true
        }
       
        catch {
            Show-ADTInstallationProgress -StatusMessage "Couldn't remove scheduled task, please see the reason why in the debug line below this one."
            $ErrorMessage = $_.Exception.Message  # Catch the error
            Show-ADTInstallationProgress -StatusMessage "DEBUG: $ErrorMessage"
            return $false
        }   
    }

    Function Cleanup {
        # Delete the scheduled task so this won't run again...
        #$TaskName = "SetTimeZone"
        #$Delete = RemoveScheduledTask $TaskName
        #Show-ADTInstallationProgress -StatusMessage "Was the scheduled task removed: $Delete"
        Show-ADTInstallationProgress -StatusMessage "Exiting script."
        Close-ADTSession -ExitCode 0
    }

    function Test-RegistryKey {

        param (
        
            [parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]$Path
        )
        
        try {
            Get-ItemProperty -Path $Path -ErrorAction Stop | Out-Null
            return $true
        }
        
        catch {
            return $false
        }
    }

    Function CheckEnrollmentDate {
        # Sets $EnrollmentDateOK = $True if enrolled date is within the last $hours hours...

        Show-ADTInstallationProgress -StatusMessage "Current date/time = $TimeNow, computer install date/time = $EnrollDateTime"
  
        if ($hoursDetected -gt $hours) {
            Show-ADTInstallationProgress -StatusMessage "Oops, the enroll date [$EnrollDateTime] was created more than $hours hours ago, will not do anything..."
            Show-ADTInstallationProgress -StatusMessage "Hours since enrollment: $hoursDetected" 
            $EnrollmentDateOK = $False
            return $EnrollmentDateOK
        }
        Else {
            Show-ADTInstallationProgress -StatusMessage "Enroll date [$EnrollDateTime] created within the last $hours hours..."
            Show-ADTInstallationProgress -StatusMessage "Hours since enrollment: $hoursDetected" 
            $EnrollmentDateOK = $True
            return $EnrollmentDateOK
        }
    }
   
    ##================================================
    ## MARK: Install
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## <Perform Installation tasks here>

    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Start $adtSession.InstallPhase phase of $($adtSession.AppVendor) - $($adtSession.AppName) script."
    
    # Retrieve the currently logged-on console user
    $localUserFull = Get-CimInstance -ClassName Win32_ComputerSystem | select-object -ExpandProperty UserName
    
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Starting initial checks to determine if we can show the popup or exit from the script if not..."

    
    # check key exists, if not, create it
    $ValidateRegKey = Test-Registrykey $registrypath
    If ($ValidateRegKey -eq $false) {
        # create reg key as it doesn't exist
        New-Item -Path $registrypath -Force
    }
    else
    {}

    # Get Registry SID of logged in user
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Getting Registry SID of logged in user"
    $principalUser = New-Object System.Security.Principal.NTAccount($localUserFull)
    $sid = $principalUser.Translate([System.Security.Principal.SecurityIdentifier]).Value
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Logged in user: $localUserFull"
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Logged in user SID: $sid" 
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Checking for HKCU registry key using logged on users SID"

    # Read TimeZoneSet registry value from the logged in users HKCU. If key exists, script has already run, so script execution will be stopped
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "checking if the first version of this script was previously run, if so, exit"
    New-PSDrive -Name 'HKU' -PSProvider 'Registry' -Root 'HKEY_USERS' | Out-Null
    
    $TZSvalue = $null
    try {
        $TZSvalue = Get-ADTRegistryKey -Key $registrypath -Name $regKey

    }
    catch {}
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "TZSvalue: $TZSValue"
    
    If ($TZSvalue) {
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "HKCU Registry value found, exiting script: $TZSvalue"
        Remove-PSDrive -Name 'HKU' -ErrorAction SilentlyContinue
        Cleanup
    }
    else {
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "HKCU Registry value NOT found, continuing script: $TZSvalue"
    }

    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "removing mounted PSDrive..."
    Remove-PSDrive -Name 'HKU' -ErrorAction SilentlyContinue

    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Checking if computer was enrolled within the defined timelimit..."
    $EnrollmentDateOK = CheckEnrollmentDate
    

    if ($EnrollmentDateOK -eq $True) {
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "EnrollDateOK = $EnrollmentDateOK, let's do stuff..." 

        # Retrieve system locale and regional settings
        $CountryNow = $(get-winhomelocation).HomeLocation
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Country identified as '$CountryNow'"
        $GeoIDNow = $(get-winhomelocation).GeoId
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "GeoID identified as '$GeoIDNow'"
        
        # Retrieve current time zone information
        $TimeZoneNow = get-timezone
        $TimeZoneId = $TimeZoneNow.Id
        $TimeZoneStandardName = $TimeZoneNow.StandardName
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "TimeZoneNow identified as '$TimeZoneNow'"
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "TimeZoneId = $TimeZoneId"
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "TimeZoneStandardName = $TimeZoneStandardName"

        # Retrieve current keyboard and region settings
        $OSLanguageNow = $(get-culture).Name
        $KeyboardNow = (Get-WinUserLanguageList).InputMethodTips
        $DateFormatNow = (get-culture).DateTimeFormat.ShortDatePattern
        $RegionFormatNow = (get-culture).DisplayName
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "OSLanguageNow identified as '$OSLanguageNow'"
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "KeyboardNow identified as '$KeyboardNow'"
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "DateFormatNow identified as '$DateFormatNow'"
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "RegionFormatNow identified as '$RegionFormatNow'"

        # Read location mapping from CSV file
        $csv = Import-CSV -Path $csvGeoIDs -Delimiter ';' -Header 'GEOID', 'Location'
        $loc = $csv | Where-Object { $_.GEOID -eq $GeoIDNow } | Select-object Location
        $locLocation = $loc.Location
	
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Location identified as '$locLocation'"

        # Windows forms stuff starts here
        # Minimize all windows before opening the GUI
        $shell = New-Object -ComObject "Shell.Application"
        $shell.minimizeall()

        # Load Windows Forms library
        Add-Type -AssemblyName System.Windows.forms

        # Create the main form
        $appTitle = "Please confirm or change your Time Zone"
        $form = New-Object System.Windows.Forms.Form
        $form.StartPosition = "CenterScreen"
        $form.Width = 600 # Width of main window
        $form.Height = 450 # Height of main window
        $form.FormBorderStyle = 'Fixed3D' # Fixes the windows in height and width
        $form.MaximizeBox = $false
        $form.Text = $appTitle

        # Create label with instructions
        $label1 = New-Object System.Windows.Forms.Label
        $label1.Text = "We have identified the following settings. If they are correct click Confirm. If you would like to change a setting, select the appropriate option from the drop down menu and then click Change (Client will restart)."
        $label1.Location = '20,17' # Position x from left border and y from upper border of the formula
        $label1.Width = 540 # Width of label
        $label1.Height = 40 # Height of label (40 = 2 lines)
        $label1.Font = [System.Drawing.Font]::new("Segoe UI Variable", 9, [System.Drawing.FontStyle]::Regular)
        $form.Controls.Add($label1)

        # Define label positions
        [int]$locationx = 25 # Position from left border
        [int]$locationy = 80 # Position from upper boarder. First label starts here

        # Labels for settings
        $labels = @("Time Zone", "Language", "Keyboard")
        $yOffset = 60 # Offset between labels

        foreach ($text in $labels) {
            $label = New-Object System.Windows.Forms.Label
            $label.Text = $text
            $label.Location = "$locationx,$locationy"
            $label.Width = 200 # Width of label
            $label.Height = 20 # Height of label (40 = 2 lines)
            $label.Font = [System.Drawing.Font]::new("Segoe UI Variable", 9, [System.Drawing.FontStyle]::Regular)
            $form.Controls.Add($label)
            $locationy += $yOffset
        }

        # Create Confirm Button
        $locationy += 60 # Defines y location of buttons in the form
        $buttonConfirm = New-Object System.Windows.Forms.Button
        $buttonConfirm.Location = "$locationx,$locationy"
        $buttonConfirm.Width = 200
        $buttonConfirm.Height = 35
        $buttonConfirm.Text = 'Confirm'
        $buttonConfirm.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Controls.Add($buttonConfirm)
        

        # Create Change Button (initially disabled)
        $buttonChange = New-Object System.Windows.Forms.Button
        $buttonChange.Location = "$($locationx+300),$locationy"
        $buttonChange.Width = 200
        $buttonChange.Height = 35
        $buttonChange.Text = 'Change'
        $buttonChange.Enabled = $false
        $buttonChange.DialogResult = [System.Windows.Forms.DialogResult]::CANCEL
        $form.Controls.Add($buttonChange)

        # Create optical line around the textboxes
        $AdditionalOptionsBox = New-Object System.Windows.Forms.Label
        $locationx = 18 # Position x from left border 
        $locationy = 65 # Position y from upper border
        $AdditionalOptionsBox.Location = "$locationx,$locationy"
        $AdditionalOptionsBox.Width = 540 # Width of border
        $AdditionalOptionsBox.Height = 185 # Height of border
        $AdditionalOptionsBox.Font = [System.Drawing.Font]::new("SYSTEM", 9, [System.Drawing.FontStyle]::Regular)
        $AdditionalOptionsBox.ForeColor = "Black" # color
        $AdditionalOptionsBox.name = "AdditionalOptionsBox"
        $AdditionalOptionsBox.BorderStyle = 1 

        ############################################
        ## Create dropdown for time zone selection #
        ############################################

        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Start building 1st dropdown box..."

        # Extract Time Zone values from CSV files
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "DEBUG: ######################## Start extract Time Zone settings ########################"
        $TimeZoneString = $(select-string -Path $csvZoneMapping -Pattern $locLocation)
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "DEBUG: TimeZoneString identified as '$TimeZoneString'"    
        $TimeZoneNow = $($TimeZoneString -split ',')[2]
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "DEBUG: TimeZone currently identified as '$TimeZoneNow'"
        $TimeZoneDropDownitem = $($TimeZoneString -split ':')[2]
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "DEBUG: TimeZoneDropDownitem = '$TimeZoneDropDownitem'"     
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "DEBUG: ######################## End extract Time Zone settings ########################"
        
        # Create dropdown for time zone selection
        
        $DropDownBox = New-Object System.Windows.Forms.ComboBox
        $DropDownBox.Location = "25,105" # Position x from left border and y from upper border of the formula
        $DropDownBox.Size = New-Object System.Drawing.Size(520, 25) # Width and Height of drop-down
        $DropDownBox.DropDownHeight = 220 # Height when drop-down is dropped ;-)
        $Form.Controls.Add($DropDownBox) 
        
        # Enable Change button when dropdown is clicked
        $DropDownBox.Add_Click(
            {
                $buttonChange.Enabled = $true
                $buttonConfirm.Enabled = $false
            })

        # Populate dropdown with time zone options from CSV
        [array]$DropDownArray = (Get-Content $csvZoneMapping)
        foreach ($item in $DropDownArray) {
            [void]$DropDownBox.Items.Add($item)
        } 
        
        #set default to whatever we detected in the beginning 
        $DropDownBox.TEXT = $TimeZoneNow # was $TimeZone
        $DropDownBox.SelectedItem = $DropDownBox.Items[$TimeZoneDropDownitem - 1]  


        ############################################
        ## Create dropdown for language selection #
        ############################################

        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Start building 2nd dropdown box..."

        # Extract Language values from CSV file
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "DEBUG: ######################## Start extract Language settings ########################"

        # Datei einlesen und nur die erste Spalte (Language) extrahieren
        $CSVFile = $csvWindowsLCID
        $CSVContent = Get-Content $CSVFile | ForEach-Object { ($_ -split ',')[0] }

        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "DEBUG: Extracted languages: $($CSVContent -join ', ')"

        # Ermitteln der aktuellen Sprache basierend auf $OSLanguageNow
        $LanguageString = Select-String -Path $CSVFile -Pattern $OSLanguageNow | ForEach-Object { $_.Line }
        $LanguageNow = if ($LanguageString) { ($LanguageString -split ',')[0] } else { "Language can not be identified" }

        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "DEBUG: Language currently identified as '$LanguageNow'"

        # Create dropdown for language selection
        $DropDownBox2 = New-Object System.Windows.Forms.ComboBox
        $DropDownBox2.Location = "25,165" # Position x from left border and y from upper border of the formula
        $DropDownBox2.Size = New-Object System.Drawing.Size(520, 25) # Width and Height of drop-down
        $DropDownBox2.DropDownHeight = 220 # Height when drop-down is dropped
        $Form.Controls.Add($DropDownBox2) 

        # Enable Change button when dropdown is clicked
        $DropDownBox2.Add_Click({
                $buttonChange.Enabled = $true
                $buttonConfirm.Enabled = $false
            })

        # Populate dropdown with extracted language names
        foreach ($item in $CSVContent) {
            [void]$DropDownBox2.Items.Add($item)
        } 

        # Set default value
        $DropDownBox2.Text = $LanguageNow
        $DropDownBox2.SelectedItem = $LanguageNow


        ############################################
        ## Create dropdown for keyboard selection #
        ############################################

        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Start building 3rd dropdown box..."

        # Extract Language values from CSV file
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Start extract keyboard settings"

        # Read file and extract first column
        $CSVFile = $csvWindowsLCID
        $CSVContent = Get-Content $CSVFile | ForEach-Object { ($_ -split ',')[0] }

        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Extracted keyboards: $($CSVContent -join ', ')"

        # Check current language dependent on $OSLanguageNow

        # Check if $KeyboardNow empty. If so initialize it.
        if ([string]::IsNullOrEmpty($KeyboardNow)) {
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Info: `\$KeyboardNow` is empty. Initializing with default '0409:00000409' (en-us)."
            $KeyboardNow = "0409:00000409"
        }

        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "KeyboardNow: $KeyboardNow"
        $KeyboardString = Select-String -Path $CSVFile -Pattern $KeyboardNow | ForEach-Object { $_.Line }
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "KeyboardString: $KeyboardString"
        $KeyboardCur = if ($KeyboardString) { ($KeyboardString -split ',')[0] } else { "Keyboard can not be identified" }
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "KeyboardCur: $KeyboardCur"

        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Keyboard currently identified as '$KeyboardCur'"

        # Create dropdown for language selection
        $DropDownBox3 = New-Object System.Windows.Forms.ComboBox
        $DropDownBox3.Location = "25,225" # Position x from left border and y from upper border of the formula
        $DropDownBox3.Size = New-Object System.Drawing.Size(520, 25) # Width and Height of drop-down
        $DropDownBox3.DropDownHeight = 220 # Height when drop-down is dropped
        $Form.Controls.Add($DropDownBox3) 

        # Enable Change button when dropdown is clicked
        $DropDownBox3.Add_Click({
                $buttonChange.Enabled = $true
                $buttonConfirm.Enabled = $false
            })

        # Populate dropdown with extracted language names
        foreach ($item in $CSVContent) {
            [void]$DropDownBox3.Items.Add($item)
        } 

        # Set default value
        $DropDownBox3.Text = $KeyboardCur
        $DropDownBox3.SelectedItem = $KeyboardCur



        ################################################################################

        # Add click events for buttons
        $buttonConfirm.Add_Click(
            {    
                Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "The user clicked the Confirm button [OK]"
                $form.Hide()
            }
        )
        $buttonChange.Add_Click(
            {   
                Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "The user clicked the Change button [CANCEL]"
                $form.Hide()
            }
        )

        #$Form.Dispose()        

        $result = $form.ShowDialog()

        if ($result -eq 'OK') {
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Result: $result. Nothing changed. Set eventIDTrigger=false"
            $eventIDTrigger = $false
            Set-Content -Path "$envProgramData\LanguageSettingsConfirmed.ps1.tag" -Value "Confirmed"     

        }
        else {
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Result: $result. Something changed. Set eventIDTrigger=true"
            $eventIDTrigger = $true
        }


        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Result: $result"
        

        
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Starting to change the timezone settings for the current user."
            

        $x = $DropDownBox.SelectedItem
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Chosen timezone: $x"

        $SetTimeZone = $($DropDownBox.SelectedItem -split ',')[2]
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "SetTimeZone based on dropdown = '$SetTimezone'"

        $TimeZoneString = $(select-string -Path $csvZoneMapping -Pattern $locLocation)
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "TimeZoneString identified as '$TimeZoneString'"
        $TimeZoneNow = $($TimeZoneString -split ',')[2]
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "TimeZone currently identified as '$TimeZoneNow'"

        # export list of available timezones on this computer..
        Get-TimeZone -listavailable | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $csvTimeZones -Encoding utf8 
        $TimeZones = $(select-string -Path $csvTimeZones -Pattern $SetTimezone)
            
        if (-not $TimeZones) {
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Severity 2 -Message "WARNING: No entry for '$SetTimezone' found. "
            $TimeZoneStandardName = "Unknown"
        }
        else {
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "TimeZones = $TimeZones"

            $TimeZoneStandardName = $($TimeZones -split '","')[2]
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "TimeZoneStandardName identified as '$TimeZoneStandardName'"
    
            $SetTimezone = $TimeZoneStandardName
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "SetTimeZone (after new logic)  = '$SetTimezone'"
    
            try {
                Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Setting the TimeZone to '$SetTimeZone'"
                Set-TimeZone -Name $SetTimeZone -ErrorAction silentlycontinue
                Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Successfully set TimeZone to '$SetTimeZone'"
            }
            catch {
                $message = $_
                Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "FAILED to set TimeZone to '$SetTimeZone' the error was: $message"
            }
        }
            


        
        ######### Start setting display language
       
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Starting to change the language settings for the current user."
            

        $y = $DropDownBox2.SelectedItem
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Chosen language: $y"

        $languageline = Select-String -Path $csvWindowsLCID -Pattern "$y" | ForEach-Object { $_.Line }

        # Check, if something is found
        if ($languageLine) {
            # Seperate by comma
            $fields = $languageLine -split ','

            # Extract language code and keyboard layout
            $languageCode = $fields[1]
                

            # Debugging
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Language Code: $languageCode"
               
            Set-WinUILanguageOverride -Language $languageCode

        }
        else {
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "No item found for '$y'!"
            $y = $null
        }
        
        ######### Start setting keyboard layout
        
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Starting to change the keyboard settings for the current user."
            

        $z = $DropDownBox3.SelectedItem
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Chosen keyboard: $z"

        $languageline = Select-String -Path $csvWindowsLCID -Pattern "$z" | ForEach-Object { $_.Line }

        # Check, if something is found
        if ($languageLine) {
            # Seperate by comma
            $fields = $languageLine -split ','

            # Extract language code and keyboard layout
            $languageCode = $fields[1] # e.g. de-DE
            $keyboardLayout = $fields[3] # e.g. 0407:00000407

            # Debugging
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Language Code: $languageCode"
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Keyboard Layout: $keyboardLayout"

            $LangList = New-WinUserLanguageList "$languageCode"
            $LangList[0].InputMethodTips.Add("$keyboardLayout")

            $HKCU = "Registry::HKEY_CURRENT_USER"
            function Set-RegistryValue {
                param (
                    [string]$Path,
                    [string]$Name,
                    [string]$Type,
                    [string]$Value
                )
                    
                if (-not (Test-Path $Path)) {
                    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Registry key $Path does not exist. Creating key."
                    New-Item -Path $Path -Force | Out-Null
                }
                
                try {
                    $currentValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name
                    if ($currentValue -ne $Value) {
                        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "$Name is not set to $Value. Updating $Name."
                        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
                        $RebootRequired = $true
                    }
                    else {
                        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "$Name is already set to $Value."
                    }
                }
                catch {
                    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "$Name does not exist. Creating and setting it to $Value."
                    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
                    $RebootRequired = $true
                }
            }

            Set-RegistryValue -Path "$HKCU\Control Panel\International\User Profile" -Name "InputMethodOverride" -Type "String" -Value $keyboardLayout
            Set-RegistryValue -Path "$HKCU\Control Panel\International\User Profile System Backup" -Name "InputMethodOverride" -Type "String" -Value $keyboardLayout
            Set-WinUserLanguageList $LangList -Force

        }
        else {
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "No item found for '$z'!"
        }
        
        $Data = [PSCustomObject]@{
            languagecode   = $languageCode
            KeyboardLayout = $keyboardLayout
        }

        $Data | ConvertTo-Csv -NoTypeInformation -Delimiter "," | ForEach-Object { $_ -replace '"', '' } | Set-Content -Path $CsvResults -Encoding UTF8

                   
        
        ## Additional information: -Type: DWord, String, Binary
        
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Set registry key: -Path: HKCU:\Software\WOW6432Node\$($adtSession.AppVendor)\ComputerManagement\Autopilot - Name: Autopilot - Type: String - Value: "
        Set-ADTRegistryKey -Key $registrypath -Name 'Autopilot' -Type 'String' -Value 'TimeZoneSet'
        


        if ($eventIDTrigger -eq $true) {
            Write-EventLog -LogName "Application" -Source $GVAppName -EventID 1102 -EntryType Information -Message "A localization setting was modified. Trigger scheduled task to set language settings" -Category 1 -RawData 10, 20
        }
        else {
            Write-EventLog -LogName "Application" -Source $GVAppName -EventID 1102 -EntryType Information -Message "No settings were modified. Trigger scheduled task to run the cleanup" -Category 1 -RawData 10, 20
        }
        
          
    }
    else {
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "EnrollDateOK = $EnrollmentDateOK , will NOT do anything...let's exit"
    } 

    ##================================================
    ## MARK: Post-Install
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Installation tasks here>


    ## Display a message at the end of the install.

}

function Uninstall-ADTDeployment {
    ##================================================
    ## MARK: Pre-Uninstall
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing.
    Show-ADTInstallationWelcome -CloseProcesses iexplore -CloseProcessesCountdown 60

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Uninstallation tasks here>


    ##================================================
    ## MARK: Uninstall
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## Handle Zero-Config MSI uninstallations.
    if ($adtSession.UseDefaultMsi) {
        $ExecuteDefaultMSISplat = @{ Action = $adtSession.DeploymentType; FilePath = $adtSession.DefaultMsiFile }
        if ($adtSession.DefaultMstFile) {
            $ExecuteDefaultMSISplat.Add('Transform', $adtSession.DefaultMstFile)
        }
        Start-ADTMsiProcess @ExecuteDefaultMSISplat
    }

    ## <Perform Uninstallation tasks here>


    ##================================================
    ## MARK: Post-Uninstallation
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Uninstallation tasks here>
}

function Repair-ADTDeployment {
    ##================================================
    ## MARK: Pre-Repair
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing.
    Show-ADTInstallationWelcome -CloseProcesses iexplore -CloseProcessesCountdown 60

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Repair tasks here>


    ##================================================
    ## MARK: Repair
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## Handle Zero-Config MSI repairs.
    if ($adtSession.UseDefaultMsi) {
        $ExecuteDefaultMSISplat = @{ Action = $adtSession.DeploymentType; FilePath = $adtSession.DefaultMsiFile }
        if ($adtSession.DefaultMstFile) {
            $ExecuteDefaultMSISplat.Add('Transform', $adtSession.DefaultMstFile)
        }
        Start-ADTMsiProcess @ExecuteDefaultMSISplat
    }

    ## <Perform Repair tasks here>


    ##================================================
    ## MARK: Post-Repair
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Repair tasks here>
}


##================================================
## MARK: Initialization
##================================================

# Set strict error handling across entire operation.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
Set-StrictMode -Version 1

# Import the module and instantiate a new session.
try {
    $moduleName = if ([System.IO.File]::Exists("$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1")) {
        Get-ChildItem -LiteralPath $PSScriptRoot\PSAppDeployToolkit -Recurse -File | Unblock-File -ErrorAction Ignore
        "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"
    }
    else {
        'PSAppDeployToolkit'
    }
    Import-Module -FullyQualifiedName @{ ModuleName = $moduleName; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.0.5' } -Force
    try {
        $iadtParams = Get-ADTBoundParametersAndDefaultValues -Invocation $MyInvocation
        $adtSession = Open-ADTSession -SessionState $ExecutionContext.SessionState @adtSession @iadtParams -PassThru
    }
    catch {
        Remove-Module -Name PSAppDeployToolkit* -Force
        throw
    }
}
catch {
    $Host.UI.WriteErrorLine((Out-String -InputObject $_ -Width ([System.Int32]::MaxValue)))
    exit 60008
}


##================================================
## MARK: Invocation
##================================================

try {
    Get-Item -Path $PSScriptRoot\PSAppDeployToolkit.* | & {
        process {
            Get-ChildItem -LiteralPath $_.FullName -Recurse -File | Unblock-File -ErrorAction Ignore
            Import-Module -Name $_.FullName -Force
        }
    }
    & "$($adtSession.DeploymentType)-ADTDeployment"
    Close-ADTSession
}
catch {
    Write-ADTLogEntry -Message ($mainErrorMessage = Resolve-ADTErrorRecord -ErrorRecord $_) -Severity 3
    Show-ADTDialogBox -Text $mainErrorMessage -Icon Stop | Out-Null
    Close-ADTSession -ExitCode 60001
}
finally {
    Remove-Module -Name PSAppDeployToolkit* -Force
}

