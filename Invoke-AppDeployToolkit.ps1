<#
Changeable variables in this script

$hours = 4380               > Modify this value if you want to define a different run period. This value should match with value in all scripts: Install_SetTimeZone, SetTimeZone-GUI, App_SetTimeZone
$timeDifference = 1         > Uncomment in script for testing. !! DO NOT FORGET to comment again before using this script in production


Origin author: Niall Brady
Origin URL: https://www.niallbrady.com/2021/12/15/prompting-standard-users-to-confirm-or-change-regional-time-zone-and-country-settings-after-windows-autopilot-enrollment-is-complete/
Modified by: Matthias Langenhoff
URL: https://cmdctrl4u.wordpress.com
GitHub: https://github.com/cmdctrl4u
Date: 2025-11-03
Version: 1.0

#>

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
    AppName = 'Deploy "Set language settings"'
    AppVersion = ''
    AppArch = ''
    AppLang = 'EN'
    AppRevision = '01'
    AppSuccessExitCodes = @(0)
    AppRebootExitCodes = @(1641, 3010)
    AppScriptVersion = '1.0.0'
    AppScriptDate = '2025-02-11'
    AppScriptAuthor = 'Matthias Langenhoff'

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
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

 	# Log installation start
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Start logging..." 

	# Check if Powershell is running in 64-bit mode and OS is 64-bit
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Is 64bit PowerShell: $([Environment]::Is64BitProcess)"
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Is 64bit OS: $([Environment]::Is64BitOperatingSystem)"

	# Check if the script is running in a 32-bit PowerShell process on a 64-bit OS
	if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") 
    {
                    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Running in 32-bit Powershell, starting 64-bit..."
        if ($myInvocation.Line) 
        {
			# Restart the script in 64-bit PowerShell using sysnative redirection
            &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile $myInvocation.Line
        }
        else
        {
			# Restart the script in 64-bit PowerShell and pass the script file along with its arguments
            &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile -file "$($myInvocation.InvocationName)" $args
        }
            
		# Exit the current (32-bit) process with the last exit code
        exit $lastexitcode
    }

    
    ## Show Progress Message (with the default message).
     Show-ADTInstallationProgress -StatusMessage "Initializing installation of $($adtSession.AppVendor) - $($adtSession.AppName)"

    ## <Perform Pre-Installation tasks here>


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

    if ($timeDifference -ge $hours) 
    { 
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Time since enrollment > 182,5 days, nothing to do here...." 
    }
    else 
    {
        # Create necessary directories
        $folderpath1 = "$envProgramData\CompanyName"
        New-ADTFolder -path $folderpath1
        Write-ADTLogEntry -Source $adtSession.InstallPhase -Message "Folder $folderpath1 not existing. Folder will be created" -LogType 'CMTrace'
                             
        $folderpath2 = "$envProgramData\CompanyName\SetTimeZone"
        New-ADTFolder -path $folderpath2
        Write-ADTLogEntry -Source $adtSession.InstallPhase -Message "Folder $folderpath2 not existing. Folder will be created" -LogType 'CMTrace'


        # Create scheduled task folder
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Creating scheduled task folder" 
        $taskFolder = 'CompanyName'
        $scheduleObject = New-Object -ComObject Schedule.Service
        $scheduleObject.Connect()
        $rootFolder = $scheduleObject.GetFolder('\')
        try { 
            $rootFolder.CreateFolder($taskFolder) | Out-Null 
        }
        catch { 
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Scheduled task folder named $taskFolder already exists" 
        }

        ## Copy dependencies/files for scheduled task
        $scriptPath = "$envProgramData\CompanyName\SetTimeZone\"
        Copy-ADTFile -Path "$($adtSession.DirFiles)\*" -Destination $scriptPath -Recurse

        # Create scheduled task
        $moduleName = "ScheduledTasks"
        $taskName = "Install_SetTimeZone"
        $maxRetries = 5
        $retryCount = 0
        $taskExists = $null

        # Check if the module is installed, and if not, try to install it
        if (-not (Get-Module -Name $moduleName -ListAvailable)) {
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "The module '$moduleName' is not installed. Attempting to install..."
            try {
                Install-Module -Name $moduleName -Force -Scope CurrentUser -ErrorAction Stop
            } catch {
                Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Failed to install module '$moduleName'. Exiting script."
                Close-ADTSession -ExitCode 0
            }
        }

        # Import the module
        Import-Module -Name $moduleName -ErrorAction SilentlyContinue

        do {
            try {
                # Check if the scheduled task exists
                $taskExists = Get-ScheduledTask | Where-Object { $_.TaskName -like $taskName }
                
                # If the query is successful (regardless of whether the task exists), everything is fine
                if ($null -ne $taskExists -or $taskExists -eq $null) {
                    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Check successful. Task exists or was not found."
                    break
                }
            } catch {
                Write-Host "Error retrieving scheduled task. Retrying ($($retryCount+1)/$maxRetries)..."
                
                # Attempt to re-import the module
                Import-Module -Name $moduleName -ErrorAction SilentlyContinue
                $retryCount++
                Start-Sleep -Seconds 2  # Short wait before retrying
            }
        } while ($retryCount -lt $maxRetries)

        # If all retries fail, exit with code 0
        if ($retryCount -eq $maxRetries) {
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Maximum number of retries reached. Exiting script with error code 0."
            Close-ADTSession -ExitCode 0
        }


            if($taskExists){
                Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Task already exists. Nothing to do here. Exiting script." 
                Close-ADTSession -ExitCode 0 
            }
            else {
                Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "The scheduled task $taskname did not exist..." 

                # Start creating scheduled task
                $scriptPath_Install_SetTimeZone = "%programdata%\CompanyName\SetTimeZone\Install_SetTimeZone\Invoke-AppDeployToolkit.exe"
                $User='Nt Authority\System'
                $action = New-ScheduledTaskAction -Execute $scriptPath_Install_SetTimeZone -Argument ' -DeploymentType "Install" -DeployMode "Silent"'
                $triggerLogOn = New-ScheduledTaskTrigger -AtLogOn
                $triggerInterval = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1)
    
                $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit '00:00:00' -MultipleInstances IgnoreNew
                
                Register-ScheduledTask -TaskName $taskname -TaskPath $taskFolder -Trigger $triggerLogOn,$triggerInterval -Settings $settings -User $User -Action $Action -RunLevel Highest -Force -ErrorAction SilentlyContinue
            }

    }

    ##================================================
    ## MARK: Post-Install
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Installation tasks here>

	############################################################################### CompanyName - Create tag file, so Intune knows if AutopilotBranding is already installed ##############################

        if (-not (Test-Path "$envProgramData\Microsoft\Autopilot"))
        {
            New-Item -path "$envProgramData\Microsoft\Autopilot" -ItemType Directory
        }
        Set-Content -Path "$envProgramData\Microsoft\Autopilot\SetLanguageSettings.ps1.tag" -Value "Installed"

    ## Display a message at the end of the install.
    
}

function Uninstall-ADTDeployment
{
    ##================================================
    ## MARK: Pre-Uninstall
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Uninstallation tasks here>


    ##================================================
    ## MARK: Uninstall
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## Handle Zero-Config MSI uninstallations.
   

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

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Repair tasks here>


    ##================================================
    ## MARK: Repair
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

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

