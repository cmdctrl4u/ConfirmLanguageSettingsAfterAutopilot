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
. "$ScriptRoot\Files\GlobalVariables.ps1"

##================================================
## MARK: Variables
##================================================

$adtSession = @{
    # App variables.
    AppVendor                   = $GVCompanyname
    AppName                     = $GVAppName
    AppVersion                  = '1.0'
    AppArch                     = ''
    AppLang                     = 'EN'
    AppRevision                 = '01'
    AppSuccessExitCodes         = @(0)
    AppRebootExitCodes          = @(1641, 3010)
    AppScriptVersion            = '1.0.0'
    AppScriptDate               = '2025-07-10'
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
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Starting the installation of $($adtSession.AppVendor) - $($adtSession.AppName)"

    ####################################################################################################
    ## Variables and additional information
    ####################################################################################################

    # Time settings
    $hours = $GVhours  # Time frame, starting from installation date, within this script should run. 
    $installDate = (Get-Item -Path "$envProgramFilesX86\Microsoft Intune Management Extension").CreationTimeUtc # Get the installation date of Microsoft Intune Management Extension
    $Now = Get-Date # Get the current date
    $TimeDifference = $Now - $installDate # Calculate the time difference in hours since installation
    $TimeDifference = [math]::Round($TimeDifference.TotalHours, 2) # Calculate the time difference in hours and round it to 2 decimal places
    
    #For  testing. !! DO NOT FORGET to set $GVTestMode to 'False' before using this script in production
    if($GVTestMode -eq $True) {
        $TimeDifference = 1 # Set to 1 hour for testing purposes
    }
    else {
        $TimeDifference = $TimeDifference # Use the actual time difference in production
    }
    
    # Set the path to the script and folder where the script will be installed
    $RootPath = "$envProgramData\$($adtSession.AppVendor)" # Path to the folder where the script will be installed
    $scriptPath = $RootPath + "\" + $adtSession.AppName # Path to the folder where the script will be installed
    $folderName = "Install" # Name of the folder where the script will be installed. Should match with the name of the folder in the PSAppDeployToolkit\Files folder.

    # Scheduled task variables
    $taskFolder = $($adtSession.AppVendor) # Name of the scheduled task folder
    $taskname = "$($adtSession.AppName) - $foldername" # Name of the scheduled task
    $script_execution_path = "$scriptPath\$folderName\Invoke-AppDeployToolkit.exe"


    # Check if Powershell is running in 64-bit mode and OS is 64-bit
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Is 64bit PowerShell: $([Environment]::Is64BitProcess)"
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Is 64bit OS: $([Environment]::Is64BitOperatingSystem)"

    # Check if the script is running in a 32-bit PowerShell process on a 64-bit OS
    if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Running in 32-bit Powershell, starting 64-bit..."
        if ($myInvocation.Line) {
            # Restart the script in 64-bit PowerShell using sysnative redirection
            &"$envWINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile $myInvocation.Line
        }
        else {
            # Restart the script in 64-bit PowerShell and pass the script file along with its arguments
            &"$envWINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile -file "$($myInvocation.InvocationName)" $args
        }
            
        # Exit the current (32-bit) process with the last exit code
        exit $lastexitcode
    }
    
    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress -StatusMessage "Initializing installation of $($adtSession.AppVendor) - $($adtSession.AppName)"

    ##================================================
    ## MARK: Install
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    # Log the Autopilot enrollment age
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Autopilot enrollment age: $timeDifference hours" 

    if ($timeDifference -ge $hours) { 
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Time since enrollment > $hours hours, so nothing to do here...." 
    }
    else {
        
        # Clean up old files
        if (Test-Path -Path $scriptPath) {
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Remove old folder - PathToFolder: $scriptPath" 
            Remove-ADTFolder -Path $scriptPath 
        }
        
        # Create necessary directories
        
        if( -not (Test-Path -Path $RootPath)) {
            Write-ADTLogEntry -Source $adtSession.InstallPhase -Message "Folder $RootPath not existing. Folder will be created" -LogType 'CMTrace'
            New-ADTFolder -path $RootPath
        }
        
        if ( -not (Test-Path -Path $scriptPath)) {
            Write-ADTLogEntry -Source $adtSession.InstallPhase -Message "Folder $scriptPath not existing. Folder will be created" -LogType 'CMTrace'
            New-ADTFolder -path $scriptPath
        }
        


        # Create scheduled task folder
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Creating scheduled task folder" 
        
        $scheduleObject = New-Object -ComObject Schedule.Service
        $scheduleObject.Connect()
        $rootFolder = $scheduleObject.GetFolder('\')
        try { 
            $rootFolder.CreateFolder($taskFolder) | Out-Null 
        }
        catch { 
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Scheduled task folder named $taskFolder already exists" 
        }

        # Copy the script files to the destination folder
        $RootPath = $scriptPath
        Copy-ADTFile -Path "$($adtSession.DirFiles)\*" -Destination $RootPath -Recurse

        # Create scheduled task
        $moduleName = "ScheduledTasks"
        $maxRetries = 5
        $retryCount = 0
        $taskExists = $null

        # Check if the module is installed, and if not, try to install it
        if (-not (Get-Module -Name $moduleName -ListAvailable)) {
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "The module '$moduleName' is not installed. Attempting to install..."
            try {
                Install-Module -Name $moduleName -Force -Scope CurrentUser -ErrorAction Stop
            }
            catch {
                Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Failed to install module '$moduleName'. Exiting script."
                Close-ADTSession -ExitCode 0
            }
        }

        # Import the module
        Import-Module -Name $moduleName -ErrorAction SilentlyContinue

        # Try to create the scheduled task, which will install the Confirm language settings GUI - and the SetLanguageSettings script.
        do {
            try {
                # Check if the scheduled task exists
                Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Checking if scheduled task $taskName already exists..." 
                $taskExists = Get-ScheduledTask | Where-Object { $_.TaskName -like $taskName }
                
                # If the query is successful (regardless of whether the task exists), everything is fine
                if ($null -ne $taskExists -or $null -eq $taskExists) {
                    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Check successful. Task exists or was not found."
                    break
                }
            }
            catch {
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
            Close-ADTSession -ExitCode 0 # = 0, so Autopilot can proceed
        }

        if ($taskExists) {
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Task already exists. Nothing to do here. Exiting script." 
            Close-ADTSession -ExitCode 0 
        }
        else {
            Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "The scheduled task $taskname did not exist..." 

            # Start creating scheduled task
            $User = 'Nt Authority\System'
            $action = New-ScheduledTaskAction -Execute $script_execution_path -Argument ' -DeploymentType "Install" -DeployMode "Silent"'
            $triggerLogOn = New-ScheduledTaskTrigger -AtLogOn
            $triggerInterval = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1)
    
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit '00:00:00' -MultipleInstances IgnoreNew
                
            Register-ScheduledTask -TaskName $taskname -TaskPath $taskFolder -Trigger $triggerLogOn, $triggerInterval -Settings $settings -User $User -Action $action -RunLevel Highest -Force -ErrorAction SilentlyContinue
        }

    }

    ##================================================
    ## MARK: Post-Install
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Installation tasks here>

    ############################################################################### Create tag file, so Intune knows if AutopilotBranding is already installed ##############################

    if (-not (Test-Path "$envProgramData\Microsoft\Autopilot")) {
        New-Item -path "$envProgramData\Microsoft\Autopilot" -ItemType Directory
    }
    Set-Content -Path "$envProgramData\Microsoft\Autopilot\SetLanguageSettings.ps1.tag" -Value "Installed"

    ## Display a message at the end of the install.
    
}

function Uninstall-ADTDeployment {
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

function Repair-ADTDeployment {
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

