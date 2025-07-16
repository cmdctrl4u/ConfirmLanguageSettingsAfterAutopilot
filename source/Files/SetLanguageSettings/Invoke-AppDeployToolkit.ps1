<#
Changeable variables in this script


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
    AppVendor = $GVCompanyname
    AppName = $GVAppName +' - Set'
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
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    $taskname_ConfirmLanguageSettings_GUI = $GVAppName + ' - GUI'
    $taskname_SyncTime = $GVAppName + ' - SyncTime'
    $taskname_SetLanguageSettings = $GVAppName + ' - Set Language Settings'
    $CsvPath = "$envProgramData\$($adtSession.AppVendor)\$GVAppName\GUI\Files\results.csv"


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

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress -StatusMessage "Initializing installation of $($adtSession.AppVendor) - $($adtSession.AppName)"

    ## <Perform Pre-Installation tasks here>

    ##------------------------------- Check if folder exists, otherwise create it ---------------------------##
    
    $folderpath = "$envProgramData\LanguageSettingsConfirmed.ps1.tag"
    
    If((Test-Path -Path $folderpath))
    {
        Write-ADTLogEntry -Source $adtSession.InstallPhase -Message "User confirmed settings. Will only run the cleanup" -LogType 'CMTrace'

        $TaskName = $taskname_ConfirmLanguageSettings_GUI
        $Delete = RemoveScheduledTask $TaskName
        Show-ADTInstallationProgress -StatusMessage "Was the scheduled task SetTimeZone removed: $Delete"

        $TaskName = $taskname_SetLanguageSettings
        $Delete = RemoveScheduledTask $TaskName
        Show-ADTInstallationProgress -StatusMessage "Was the scheduled task SetTimeZone removed: $Delete"

        $TaskName = $taskname_SyncTime
        $Delete = RemoveScheduledTask $TaskName
        Show-ADTInstallationProgress -StatusMessage "Was the scheduled task SetTimeZone removed: $Delete"
   
        ##---------------------------------------- Remove file ---------------------------------------##
        
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Remove file - PathToFile: $folderpath"
        Remove-ADTFile -Path $folderpath

        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Exiting script."
        Close-ADTSession -ExitCode 0
    }


    
    ##================================================
    ## MARK: Install
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## <Perform Installation tasks here>

    # Path to CSV-Datei
    

    # Read file and import 2nd line
    $lines = Get-Content -Path $CsvPath

    # Check if two lines exists
    if ($lines.Count -ge 2) {
        # Read second line and split with comma
        $values = $lines[1] -split ","

        # Save values in variables
        $language = $values[0].Trim()
        $keyboardLayout = $values[1].Trim()


        # Display variables
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Language: $language"
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Keyboard layout: $keyboardLayout"
    } else {
        Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "The file does not contain enough lines."
    }

    Install-Language -Language $Language -CopyToSettings
    
    Set-Culture $language
    Set-WinUserLanguageList -LanguageList $language -Force
    Set-WinSystemLocale -SystemLocale $language
    Set-SystemPreferredUILanguage -Language $language
    Set-WinUILanguageOverride -Language $language

    # Apply keyboard layout, regional settings to welcome page and new users.
    reg add "HKCU\Control Panel\International" /v "LocaleName" /t REG_SZ /d $language /f
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Nls\Language" /v "InstallLanguage" /t REG_SZ /d $language /f  
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Nls\Language" /v "Default" /t REG_SZ /d $language /f

# 2. Define language for new users
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\MUI\Settings" /v "PreferredUILanguages" /t REG_MULTI_SZ /d $language /f

# 3. Set language for lockscreen
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\MUI\UIFallback" /v "Default" /t REG_SZ /d $language /f

# 4. Check other keys

# Split $inputLanguageID

$keyboardpreload = $keyboardLayout.Split(':')[1]

try {
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Load DefaultUser-Registry..."
    $regLoad = Start-Process -FilePath "reg" -ArgumentList "load HKU\DefaultUser C:\Users\Default\NTUSER.DAT" -NoNewWindow -Wait -PassThru

    if ($regLoad.ExitCode -ne 0) {
        throw "Failure loading Registry-Hive."
    }

    # Set keyboard layout
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Set keyboard layout (HKU\DefaultUser\Keyboard Layout\Preload\1) to $keyboardpreload..."
    $regAdd1 = Start-Process -FilePath "reg" -ArgumentList "add `"HKU\DefaultUser\Keyboard Layout\Preload`" /v `"1`" /t REG_SZ /d `"$keyboardpreload`" /f" -NoNewWindow -Wait -PassThru

    if ($regAdd1.ExitCode -ne 0) {
        throw "Failure configuring keyboard layout (HKU\DefaultUser\Keyboard Layout\Preload\1)."
    }

    # Set InputMethodOverrid
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Set inputMethodOverride (HKU\DefaultUser\Control Panel\International\User Profile\InputMethodOverride) to $keyboardLayout..."
    $regAdd3 = Start-Process -FilePath "reg" -ArgumentList "add `"HKU\DefaultUser\Control Panel\International\User Profile`" /v `"InputMethodOverride`" /t REG_SZ /d `"$keyboardLayout`" /f" -NoNewWindow -Wait -PassThru

    if ($regAdd3.ExitCode -ne 0) {
        throw "Failure configuring inputMethodOverride (HKU\DefaultUser\Control Panel\International\User Profile\InputMethodOverride)."
    }

    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Set inputMethodOverride (HKU\DefaultUser\Control Panel\International\User Profile System Backup\InputMethodOverride) to $keyboardLayout..."
    $regAdd4 = Start-Process -FilePath "reg" -ArgumentList "add `"HKU\DefaultUser\Control Panel\International\User Profile System Backup`" /v `"InputMethodOverride`" /t REG_SZ /d `"$keyboardLayout`" /f" -NoNewWindow -Wait -PassThru

    if ($regAdd4.ExitCode -ne 0) {
        throw "Failure configuring inputMethodOverride (HKU\DefaultUser\Control Panel\International\User Profile System Backup\InputMethodOverride)."
    }

    # Set Keyboard Preload
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Set inputMethodOverride (HKU\DefaultUser\Keyboard Layout\Preload\1) to $keyboardpreload..."
    $regAdd5 = Start-Process -FilePath "reg" -ArgumentList "add `"HKU\DefaultUser\Keyboard Layout\Preload`" /v `"1`" /t REG_SZ /d `"$keyboardpreload`" /f" -NoNewWindow -Wait -PassThru

    if ($regAdd5.ExitCode -ne 0) {
        throw "Failure configuring inputMethodOverride (HKU\DefaultUser\Control Panel\International\User Profile System Backup\InputMethodOverride)."
    }

    # Set default region
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Set default language (HKU\DefaultUser\Control Panel\International\Locale) to $language..."
    $regAdd2 = Start-Process -FilePath "reg" -ArgumentList "add `"HKU\DefaultUser\Control Panel\International`" /v `"Locale`" /t REG_SZ /d `"$language`" /f" -NoNewWindow -Wait -PassThru

    if ($regAdd2.ExitCode -ne 0) {
        throw "Failure setting default language (HKU\DefaultUser\Control Panel\International\Locale)."
    }

    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Unload DefaultUser-Registry..."
    $regUnload = Start-Process -FilePath "reg" -ArgumentList "unload HKU\DefaultUser" -NoNewWindow -Wait -PassThru

    if ($regUnload.ExitCode -ne 0) {
        throw "Failure while unloading Registry-Hive."
    }

    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Settings deployed successfully!" -Severity 0
} catch {
    Write-ADTLogEntry -Source $adtSession.InstallPhase -LogType 'CMTrace' -Message "Failure: $_" -Severity 3
    
}




    Copy-UserInternationalSettingsToSystem -WelcomeScreen $True -NewUser $True

    Start-Sleep -Seconds 4

    $TaskName = $taskname_ConfirmLanguageSettings_GUI
        $Delete = RemoveScheduledTask $TaskName
        Show-ADTInstallationProgress -StatusMessage "Was the scheduled task SetTimeZone removed: $Delete"

    $TaskName = $taskname_SetLanguageSettings
        $Delete = RemoveScheduledTask $TaskName
        Show-ADTInstallationProgress -StatusMessage "Was the scheduled task SetTimeZone removed: $Delete"

        $TaskName = $taskname_SyncTime
        $Delete = RemoveScheduledTask $TaskName
        Show-ADTInstallationProgress -StatusMessage "Was the scheduled task SetTimeZone removed: $Delete"
   


        shutdown /r /t 60

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

