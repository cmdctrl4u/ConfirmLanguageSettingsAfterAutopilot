<#
Changeable variables in this script

$hours = 4380               > Modify this value if you want to define a different run period. This value should match with value in all scripts: Install_SetTimeZone, SetTimeZone-GUI, App_SetTimeZone
$timeDifference = 1         > Uncomment in script for testing. !! DO NOT FORGET to comment again before using this script in production

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


##================================================
## MARK: Variables
##================================================

$adtSession = @{
    # App variables.
    AppVendor = 'CompanyName'
    AppName = 'Install "Set language settings"'
    AppVersion = ''
    AppArch = ''
    AppLang = 'EN'
    AppRevision = '01'
    AppSuccessExitCodes = @(0)
    AppRebootExitCodes = @(1641, 3010)
    AppScriptVersion = '1.0.0'
    AppScriptDate = '2025-01-29'
    AppScriptAuthor = 'M. Langenhoff'

    # Install Titles (Only set here to override defaults set by the toolkit).
    InstallName = ''
    InstallTitle = ''

    # Script variables.
    DeployAppScriptFriendlyName = $MyInvocation.MyCommand.Name
    DeployAppScriptVersion = '4.0.5'
    DeployAppScriptParameters = $PSBoundParameters
}

function Install-ADTDeployment
{
    ##================================================
    ## MARK: Pre-Install
    ##================================================

    # Log installation start
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Start logging..." 

    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    Write-Host "Is 64bit PowerShell: $([Environment]::Is64BitProcess)"
    Write-Host "Is 64bit OS: $([Environment]::Is64BitOperatingSystem)"

    if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
        
            write-warning "Running in 32-bit Powershell, starting 64-bit..."
        if ($myInvocation.Line) {
            &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile $myInvocation.Line
        }else{
            &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile -file "$($myInvocation.InvocationName)" $args
        }
            
        exit $lastexitcode
}

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress -StatusMessage "Initializing installation of $($adtSession.AppVendor) - $($adtSession.AppName)"

    ## <Perform Pre-Installation tasks here>

    Function RemoveScheduledTask($TaskName) {
        try {
            # Log the attempt to remove the scheduled task
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "About to delete scheduled task: $TaskName" 
           
            # Remove the scheduled task without confirmation and suppress output
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop | Out-Null

            # Log success message
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Succeeded to remove scheduled task: $TaskName" 
            return $true
            }
       
       catch {
            # Log failure message
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Failed to delete scheduled task: $TaskName" 
            return $false
            }   
       }

       # Retrieve the currently logged-on console user
       $localUserFull = Get-CimInstance -ClassName Win32_ComputerSystem | select-object -ExpandProperty UserName


       #-----------------------------------------------------------------------------------------------------------------------------------------------------------------------#
       # Pre-check if Enrollment Status Page (ESP) is still active or not.
       #-----------------------------------------------------------------------------------------------------------------------------------------------------------------------#

        # Make sure Hide Systray ist NOT set to 1 !!
        # HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray\HideSystray = 1

        # get the "Windows Security notification icon" process, as this process is first started when 
        # the explorer.exe processes the startup of the logged on user.

        
        $proc = Get-Process -Name SecurityHealthSystray -ErrorAction SilentlyContinue

        # Process not found, so ESP is not running
        if ($null -ne $proc) {
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "ESP-not-active. Will continue the script."
        } 
        else {
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "ESP-active. Exiting script."
            Close-ADTSession -ExitCode 0
        }


    ##================================================
    ## MARK: Install
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## <Perform Installation tasks here>

    $hours = 4380  ## Modify this value if you want to define a different run period. This value should match with value in Script SetTimeZone-GUI

    # Get the installation date of Microsoft Intune Management Extension
    $installDate = (Get-Item -Path "$envProgramFilesX86\Microsoft Intune Management Extension").CreationTimeUtc
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Install date: $installDate" 
    
    # Get the current date
    $Now = Get-Date
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Current date: $Now" 

    # Calculate the time difference in hours since installation
    $timeDifference = $Now - $installDate
    $TimeDifference = [math]::Round($TimeDifference.TotalHours, 2)
    #Uncomment below line during testing
    #$timeDifference = 1
    
    # Log the Autopilot enrollment age
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Autopilot enrollment age: $timeDifference hours" 

    # Define the scheduled task name
    $taskName = "SetTimeZone"
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Checking if scheduled task $taskName already exists..."   
    
    # Check if scheduled task already exists
    $taskExists = Get-ScheduledTask | Where-Object {$_.TaskName -like $taskName }
        
    if($taskExists) {
        # Log that the scheduled task already exists
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Info: the scheduled task $taskname already exists, will not recreate it." 

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# This section will do a cleanup if the enrollment is more than 182,5 days ago.
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------#

        # If the time difference is greater than 182.5 days (4380 hours), remove old scheduled tasks
        if ($timeDifference -ge $hours) { 
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Time since enrollment > 182,5 days, deleting old scheduled tasks" 
            RemoveScheduledTask $taskName

            # Check for scheduled task "SyncTime based on EventID" and remove it if it exists

            $taskNames = @(
            "SyncTime based on EventId",
            "SetGlobalLanguageSettings based on EventId",
            "Install_SetTimeZone",
            "SetTimeZone"
            )

            foreach ($taskName in $taskNames) {
                Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Checking if scheduled task $taskName already exists..."
                
                if (Get-ScheduledTask | Where-Object { $_.TaskName -like $taskName }) {
                    RemoveScheduledTask $taskName
                }
            }
                        
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Remove folder - PathToFolder: "
            Remove-ADTFolder -Path "$envProgramData\CompanyName\SetTimeZone" #-Recurse

            # Exit script
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Exiting script." 
            Close-ADTSession -ExitCode 0
            }

              } 
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# End of cleanup section              
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------#
    else {
            # Log that the scheduled task does not exist    
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "The scheduled task $taskname did not exist..." 

            # If time since enrollment is less than 182.5 days, proceed with scheduled task creation
            if ($timeDifference -le $hours){  
                Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Time difference is less 182,5 days. The logged on user is: $localUserFull" 
    
                # Check again
                $localUserFull = Get-CimInstance -ClassName Win32_ComputerSystem | select-object -ExpandProperty UserName
                # Ensure the logged-in user is not 'defaultuser0'
                if (-Not ($localUserFull -match 'defaultuser0')){
     
                    # Create scheduled task folder
                    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Creating scheduled task folder" 
                    $taskFolder = 'CompanyName'
                    $scheduleObject = New-Object -ComObject Schedule.Service
                    $scheduleObject.Connect()
                    $rootFolder = $scheduleObject.GetFolder('\')
                    try { $rootFolder.CreateFolder($taskFolder) | Out-Null }
                    catch   { 
                                Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Scheduled task folder named $taskFolder already exists" 
                            }
            
                    ## Set variables with the script paths
                    $scriptPath_SetTimeZone = "%programdata%\CompanyName\SetTimeZone\SetTimeZone-Gui\Invoke-AppDeployToolkit.exe"
                    $scriptPath_SetGlobalLanguageSettings = "%programdata%\CompanyName\SetTimeZone\SetGlobalLanguageSettings\Invoke-AppDeployToolkit.exe"
                    $scriptPath_SyncTime = "%programdata%\CompanyName\SetTimeZone\Install_SyncTime.vbs"
                                      
                    #-----------------------------------------------------------------------------------------------------------------------------------------------------------------------#
                    # Create scheduled task "SetTimeZone"
                    #-----------------------------------------------------------------------------------------------------------------------------------------------------------------------#
                    
                    ## Create the scheduled task
                    $taskname = "SetTimeZone"
                    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Create scheduled task for $taskname" 
                    
                    $action = New-ScheduledTaskAction -Execute $scriptPath_SetTimeZone -Argument ' -DeploymentType "Install" -DeployMode "Silent"'
                    

                    # Define triggers for the new scheduled task
                    $triggers = @()
                    $triggers += New-ScheduledTaskTrigger -AtLogOn
                    $triggers += New-ScheduledTaskTrigger -At (Get-Date).AddMinutes(5) -Once

                    # Create a TaskEventTrigger to monitor specific event log entries
                    $CIMTriggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger
                    $trigger = New-CimInstance -CimClass $CIMTriggerClass -ClientOnly
                    $trigger.Subscription = 
@"
<QueryList><Query Id="0" Path="Application"><Select Path="Application">*[System[Provider[@Name='Set-TimeZone'] and EventID=1202]]</Select></Query></QueryList>
"@
                    $trigger.Enabled = $True 
                    $triggers += $trigger        

                    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit '00:00:00' -MultipleInstances IgnoreNew
                    $principal = New-ScheduledTaskPrincipal -UserId $localUserFull

                    if($taskExists) {
                        # Log that the scheduled task already exists and will not be recreated
                        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Info: the scheduled task already exists, will not recreate it."
                    } 
                    else 
                    {
                        # Log that the scheduled task does not exist and will be created
                        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "The scheduled task did not exist. Will create it now"

                        # Register a new scheduled task with the specified settings
                        $task = Register-ScheduledTask -Action $action -Trigger $triggers -TaskName $taskName -TaskPath $taskFolder -Settings $settings -Principal $principal -ErrorAction SilentlyContinue
                        
                        # Set task expiration time to 7 days from now
                        $run = (Get-Date).AddMinutes(1);
                        $task = (Get-ScheduledTask -TaskName $taskName)
                        $task.Triggers[0].EndBoundary = $run.AddDays(1095).ToString('s')
                        $task.Settings.DeleteExpiredTaskAfter = "P7D"
                        $task.Triggers[1].EndBoundary = $run.AddDays(7).ToString('s')
                        $task.Settings.DeleteExpiredTaskAfter = "P7D"

                        # Log task details
                        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "DEBUG: task=$task taskName=$taskName run=$run"
                        
                        # Apply scheduled task settings
                        $result = Set-ScheduledTask -InputObject $task -User $localUserFull
                        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "DEBUG: settings the scheduled task settings=$result" 

                    #-----------------------------------------------------------------------------------------------------------------------------------------------------------------------#
                    # End of creation of scheduled task "SetTimeZone"
                    #-----------------------------------------------------------------------------------------------------------------------------------------------------------------------#
                    
                        # Create an Event Log source if it does not exist
                        $source = "Set-TimeZone"
                        $LogName = "Application"
                        if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
                        New-EventLog -LogName $LogName -Source $source
                        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Creating eventLog $LogName with the source $source."
                        }
                        else {
                            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "EventLog $LogName with the source $source already exists"
                            }

                    #-----------------------------------------------------------------------------------------------------------------------------------------------------------------------#
                    # Create scheduled task "SyncTime based on EventId"
                    #-----------------------------------------------------------------------------------------------------------------------------------------------------------------------#        
                        
                        # Create scheduled task for "SyncTime based on EventId""
                        $taskname = "SyncTime based on EventId"
                        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message  "Creating scheduled task for SyncTime"
                        $localUserFull = "SYSTEM"
                        $principal = New-ScheduledTaskPrincipal -UserId $localUserFull
            
                        # Define triggers for the new scheduled task
                        $triggers = @()
                        $triggers += New-ScheduledTaskTrigger -AtLogOn

                        # Create a TaskEventTrigger to monitor specific event log entries
                        $CIMTriggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger
                        $trigger = New-CimInstance -CimClass $CIMTriggerClass -ClientOnly
                        $trigger.Subscription = 
@"
<QueryList><Query Id="0" Path="Application"><Select Path="Application">*[System[Provider[@Name='Set-TimeZone'] and EventID=1002]]</Select></Query></QueryList>
"@
                        $trigger.Enabled = $True 
                        $triggers += $trigger

                        # Define task action
                        $User='Nt Authority\System'
                        $Action=New-ScheduledTaskAction -Execute "C:\Windows\system32\wscript.exe" -Argument "$scriptPath_SyncTime"
                    
                        # Check if SyncTime scheduled task already exists
                        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Checking if scheduled task $taskName already exists..."    
                        $taskExists = Get-ScheduledTask | Where-Object {$_.TaskName -like $taskName }
                    
                        if($taskExists) {
                            # Log that the SyncTime task already exists
                            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Info: the scheduled task $taskname already exists, will not recreate it."
                        } 
                        else {
                        
                            # Log that the SyncTime task does not exist and will be created
                            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "The scheduled task $taskname did not exist. Will create it now"
                        
                            # Register the new SyncTime scheduled task
                            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit '00:00:00' -MultipleInstances IgnoreNew
                            
                            Register-ScheduledTask -TaskName $taskname -TaskPath $taskFolder -Trigger $triggers -Settings $settings -User $User -Action $Action -RunLevel Highest -Force -ErrorAction SilentlyContinue
                        
                            # Set task expiration times
                            $run = (Get-Date).AddMinutes(1);
                            $task = (Get-ScheduledTask -TaskName $taskName)
                            $task.Triggers[0].EndBoundary = $run.AddDays(1095).ToString('s')
                            $task.Settings.DeleteExpiredTaskAfter = "P7D"
                            $task.Triggers[1].EndBoundary = $run.AddDays(7).ToString('s')
                            $task.Settings.DeleteExpiredTaskAfter = "P7D"

                            # Log task details
                            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "DEBUG: task=$task taskName=$taskName run=$run"

                            # Apply scheduled task settings
                            $result = Set-ScheduledTask -InputObject $task -User $localUserFull
                            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "DEBUG: settings the scheduled task settings=$result"    
                            }

                    #-----------------------------------------------------------------------------------------------------------------------------------------------------------------------#
                    # End of creation of scheduled task "SyncTime based on EventId"
                    #-----------------------------------------------------------------------------------------------------------------------------------------------------------------------#

                    # Write an event log entry for SyncTime, so the task will be executed
                    Write-EventLog -LogName $LogName -Source $source -EventID 1002 -EntryType Information -Message "Created the SyncTime scheduled task" -Category 1 -RawData 10,20


                    #-----------------------------------------------------------------------------------------------------------------------------------------------------------------------#
                    # Create scheduled task "SetGlobalLanguageSettings based on EventId"
                    #-----------------------------------------------------------------------------------------------------------------------------------------------------------------------#

                        # Create scheduled task for "SetGlobalLanguageSettings based on EventId""
                        $taskname = "SetGlobalLanguageSettings based on EventId"
                        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message  "Creating scheduled task for $taskname"

                        $localUserFull = "SYSTEM"
                        $principal = New-ScheduledTaskPrincipal -UserId $localUserFull
            
                        # Define triggers for the new scheduled task
                        $triggers = @()

                        # Create a TaskEventTrigger to monitor specific event log entries
                        $CIMTriggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger
                        $trigger = New-CimInstance -CimClass $CIMTriggerClass -ClientOnly
                        $trigger.Subscription = 
@"
<QueryList><Query Id="0" Path="Application"><Select Path="Application">*[System[Provider[@Name='Set-TimeZone'] and EventID=1102]]</Select></Query></QueryList>
"@
                        $trigger.Enabled = $True 
                        $triggers += $trigger

                        # Define task action
                        $ServiceUIPath = "%programdata%\CompanyName\SetTimeZone\SetGlobalLanguageSettings\ServiceUI_x64.exe"
                        $User='Nt Authority\System'
                        $Action=New-ScheduledTaskAction -Execute $ServiceUIPath -Argument " -Process:explorer.exe $scriptPath_SetGlobalLanguageSettings -DeploymentType `"Install`""
                        
                        # Check if SyncTime scheduled task already exists
                        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Checking if scheduled task $taskName already exists..."    
                        $taskExists = Get-ScheduledTask | Where-Object {$_.TaskName -like $taskName }
                    
                        if($taskExists) {
                            # Log that the SyncTime task already exists
                            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Info: the scheduled task $taskname already exists, will not recreate it."

                        } 
                        else {
                            # Log that the SyncTime task does not exist and will be created
                            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "The scheduled task $taskname did not exist. Will create it now"
                            
                            # Register the new SyncTime scheduled task
                            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit '00:00:00' -MultipleInstances IgnoreNew

                            Register-ScheduledTask -TaskName $taskname -TaskPath $taskFolder -Trigger $triggers -Settings $settings -User $User -Action $Action -RunLevel Highest -Force -ErrorAction SilentlyContinue
                        
                            # Set task expiration times
                            $run = (Get-Date).AddMinutes(1);
                            $task = (Get-ScheduledTask -TaskName $taskName)
                            $task.Triggers[0].EndBoundary = $run.AddDays(1095).ToString('s')
                            $task.Settings.DeleteExpiredTaskAfter = "P7D"
                            $task.Triggers[0].EndBoundary = $run.AddDays(7).ToString('s')
                            $task.Settings.DeleteExpiredTaskAfter = "P7D"

                            # Log task details
                            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "DEBUG: task=$task taskName=$taskName run=$run"

                            
                        }

                    #-----------------------------------------------------------------------------------------------------------------------------------------------------------------------#
                    # End of creation of scheduled task "SetGlobalLanguageSettings based on EventId"
                    #-----------------------------------------------------------------------------------------------------------------------------------------------------------------------#

                       # Create an Event Log source if it does not exist
                       $source = "Set-TimeZone"
                       $LogName = "Application"
                       if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
                       New-EventLog -LogName $LogName -Source $source
                       Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Creating eventLog $LogName with the source $source."
                       }
                       else {
                           Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "EventLog $LogName with the source $source already exists"
                           }



                        # Write an event log entry for SetTimeZone, so the task will be executed
                        Write-EventLog -LogName $LogName -Source $source -EventID 1202 -EntryType Information -Message "Created the SyncTime scheduled task" -Category 1 -RawData 10,20

                    }

                    # Cleanup initial deployment task

                    $taskname = "Install_SetTimeZone"

                    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Checking if scheduled task $taskName already exists..."
                
                    if (Get-ScheduledTask | Where-Object { $_.TaskName -like $taskName }) {
                        RemoveScheduledTask $taskName
                    }
                        
                    # Log script completion
                    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Script - ENDING"

                }
    
            }
        }
    


    ##================================================
    ## MARK: Post-Install
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Installation tasks here>


    ## Display a message at the end of the install.

}

function Uninstall-ADTDeployment
{
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
    if ($adtSession.UseDefaultMsi)
    {
        $ExecuteDefaultMSISplat = @{ Action = $adtSession.DeploymentType; FilePath = $adtSession.DefaultMsiFile }
        if ($adtSession.DefaultMstFile)
        {
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

function Repair-ADTDeployment
{
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
    if ($adtSession.UseDefaultMsi)
    {
        $ExecuteDefaultMSISplat = @{ Action = $adtSession.DeploymentType; FilePath = $adtSession.DefaultMsiFile }
        if ($adtSession.DefaultMstFile)
        {
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
try
{
    $moduleName = if ([System.IO.File]::Exists("$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"))
    {
        Get-ChildItem -LiteralPath $PSScriptRoot\PSAppDeployToolkit -Recurse -File | Unblock-File -ErrorAction Ignore
        "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"
    }
    else
    {
        'PSAppDeployToolkit'
    }
    Import-Module -FullyQualifiedName @{ ModuleName = $moduleName; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.0.5' } -Force
    try
    {
        $iadtParams = Get-ADTBoundParametersAndDefaultValues -Invocation $MyInvocation
        $adtSession = Open-ADTSession -SessionState $ExecutionContext.SessionState @adtSession @iadtParams -PassThru
    }
    catch
    {
        Remove-Module -Name PSAppDeployToolkit* -Force
        throw
    }
}
catch
{
    $Host.UI.WriteErrorLine((Out-String -InputObject $_ -Width ([System.Int32]::MaxValue)))
    exit 60008
}


##================================================
## MARK: Invocation
##================================================

try
{
    Get-Item -Path $PSScriptRoot\PSAppDeployToolkit.* | & {
        process
        {
            Get-ChildItem -LiteralPath $_.FullName -Recurse -File | Unblock-File -ErrorAction Ignore
            Import-Module -Name $_.FullName -Force
        }
    }
    & "$($adtSession.DeploymentType)-ADTDeployment"
    Close-ADTSession
}
catch
{
    Write-ADTLogEntry -Message ($mainErrorMessage = Resolve-ADTErrorRecord -ErrorRecord $_) -Severity 3
    Show-ADTDialogBox -Text $mainErrorMessage -Icon Stop | Out-Null
    Close-ADTSession -ExitCode 60001
}
finally
{
    Remove-Module -Name PSAppDeployToolkit* -Force
}

