<#

.SYNOPSIS
PSAppDeployToolkit.Extensions - Provides the ability to extend and customize the toolkit by adding your own functions that can be re-used.

.DESCRIPTION
This module is a template that allows you to extend the toolkit with your own custom functions.

This module is imported by the Invoke-AppDeployToolkit.ps1 script which is used when installing or uninstalling an application.

PSAppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2024 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham, Muhammad Mashwani, Mitch Richters, Dan Gough).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.LINK
https://psappdeploytoolkit.com

#>

##*===============================================
##* MARK: MODULE GLOBAL SETUP
##*===============================================

# Set strict error handling across entire module.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
Set-StrictMode -Version 1


##*===============================================
##* MARK: FUNCTION LISTINGS
##*===============================================

    function Stop-ProcessesUsingDirectory {
        param (
            [Parameter(Mandatory = $true)]
            [string]$DirectoryPath,
            [Parameter(Mandatory = $true)]
            [string]$InstallPhase
        )

        function Get-ShortPath {
            param ([string]$longPath)
            try {
                $fso = New-Object -ComObject Scripting.FileSystemObject
                return $fso.GetFolder($longPath).ShortPath
            }
            catch {
                return $null
            }
        }
		
        $directoryPath = (Get-Item -Path $DirectoryPath).FullName
        $shortDirectoryPath = Get-ShortPath -longPath $directoryPath
        $lockingProcesses = @()
		
        # Severity > 0 = Success (green), 1 = Information (default), 2 = Warning (yellow), 3 = Error (red)
        Write-ADTLogEntry -Source $InstallPhase -LogType CMTrace -Severity 1 -Message "Path to Kill : $DirectoryPath, Full Path : $directoryPath, Short Path = $shortDirectoryPath"
		
        if ($directoryPath) {
            Get-Process | ForEach-Object {
                $process = $_
                try {
                    $mainModule = $_.MainModule
                    if ($mainModule -and $mainModule.FileName) {
                        $processPath = (Get-Item -Path $mainModule.FileName).FullName						
                        if ($processPath -like "$directoryPath*") {
                            $lockingProcesses += $process
                        }
						
                        if ($shortDirectoryPath) {							
                            $shortProcessPath = Get-ShortPath -longPath $processPath							
                            if ($shortProcessPath) {								
                                if ($shortProcessPath -like "$shortDirectoryPath*") {
                                    $lockingProcesses += $process
                                }
                            }
                        }
                    }
                }
                catch {
                    # Severity > 0 = Success (green), 1 = Information (default), 2 = Warning (yellow), 3 = Error (red)
                    Write-ADTLogEntry -Source $InstallPhase -LogType CMTrace -Severity 2 -Message "Failed to get process: $($process.Name) (ID: $($process.Id)). Error: $_"
                }
            }

            $lockingProcesses = $lockingProcesses | Sort-Object Id -Unique

            if ($lockingProcesses.Count -eq 0) {
                # Severity > 0 = Success (green), 1 = Information (default), 2 = Warning (yellow), 3 = Error (red)
                Write-ADTLogEntry -Source $InstallPhase -LogType CMTrace -Severity 1 -Message "No processes are using files in the directory or its subfolders."
            }
            else {
                foreach ($process in $lockingProcesses) {
                    try {
                        Stop-Process -Id $process.Id -Force
                        Wait-Process -Id $process.Id -ErrorAction SilentlyContinue
                        # Severity > 0 = Success (green), 1 = Information (default), 2 = Warning (yellow), 3 = Error (red)
                        Write-ADTLogEntry -Source $InstallPhase -LogType CMTrace -Severity 1 -Message "Stopped process: $($process.Name) (ID: $($process.Id))"                     
                    }
                    catch {
                        # Severity > 0 = Success (green), 1 = Information (default), 2 = Warning (yellow), 3 = Error (red)
                        Write-ADTLogEntry -Source $InstallPhase -LogType CMTrace -Severity 2 -Message "Failed to stop process: $($process.Name) (ID: $($process.Id)). Error: $_"
                    }
                }
                Start-Sleep -Seconds 10
            }
        }
        else {
            # Severity > 0 = Success (green), 1 = Information (default), 2 = Warning (yellow), 3 = Error (red)
            Write-ADTLogEntry -Source $InstallPhase -LogType CMTrace -Severity 1 -Message "Directory path $directoryPath not exist"
        }
    }
function New-ADTExampleFunction
{
    <#
    .SYNOPSIS
        Basis for a new PSAppDeployToolkit extension function.

    .DESCRIPTION
        This function serves as the basis for a new PSAppDeployToolkit extension function.

    .INPUTS
        None

        You cannot pipe objects to this function.

    .OUTPUTS
        None

        This function does not return any output.

    .EXAMPLE
        New-ADTExampleFunction

        Invokes the New-ADTExampleFunction function and returns any output.
    #>

    [CmdletBinding()]
    param
    (
    )

    begin
    {
        # Initialize function.
        Initialize-ADTFunction -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    }

    process
    {
        try
        {
            try
            {
            }
            catch
            {
                # Re-writing the ErrorRecord with Write-Error ensures the correct PositionMessage is used.
                Write-Error -ErrorRecord $_
            }
        }
        catch
        {
            # Process the caught error, log it and throw depending on the specified ErrorAction.
            Invoke-ADTFunctionErrorHandler -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState -ErrorRecord $_
        }
    }

    end
    {
        # Finalize function.
        Complete-ADTFunction -Cmdlet $PSCmdlet
    }
}




##*===============================================
##* MARK: SCRIPT BODY
##*===============================================

# Announce successful importation of module.
Write-ADTLogEntry -Message "Module [$($MyInvocation.MyCommand.ScriptBlock.Module.Name)] imported successfully." -ScriptSection Initialization
