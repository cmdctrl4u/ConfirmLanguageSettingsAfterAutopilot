<#
Niall Brady 2021/12/13
#>
Function LogWrite
{
   Param ([string]$logstring)
   $a = Get-Date
   $logstring = $a,$logstring
   Try
{
    Add-content $Logfile -value $logstring  -ErrorAction silentlycontinue
}
Catch
{
    $logstring="Invalid data encountered"
    Add-content $Logfile -value $logstring
}
   write-host $logstring
}

Function Cleanup
{# del the scheduled task so this won't run again...
#$TaskName = "SetTimeZone"
#$Delete = RemoveScheduledTask $TaskName
#LogWrite "Was the scheduled task removed: $Delete"
LogWrite "Exiting script."
break}

Function RemoveScheduledTask {
 
 try {
    LogWrite "About to remove scheduled task: $TaskName..."
    Unregister-ScheduledTask -TaskName $TaskName -TaskPath "\CompanyName\" -Confirm:$false -ErrorAction Stop | Out-Null
    LogWrite "Successfully removed the scheduled task"
    return $true
    }

catch {
LogWrite "Couldn't remove scheduled task, please see the reason why in the debug line below this one."
$ErrorMessage = $_.Exception.Message  # Catch the error
LogWrite "DEBUG: $ErrorMessage"
    return $false
    }
    
   
}

function Set-SystemTime {

    LogWrite "Time resync forced"
    $ServiceName = 'W32time'
    $arrService = Get-Service -Name $ServiceName

while ($arrService.Status -ne 'Running')
{

    Start-Service $ServiceName
    LogWrite $arrService.status
    LogWrite 'Service starting'
    Start-Sleep -seconds 15
    $arrService.Refresh()
    if ($arrService.Status -eq 'Running')
    {
        LogWrite 'Service is now Running'
    }

}


    $whoami= & whoami
    LogWrite "DEBUG: whoami = $whoami"
    $timeOutput = & 'w32tm' '/resync', '/force'
    
    # get last sync time and other info
    $cmdOutput = & {w32tm /query /status}
    LogWrite "DEBUG: Here is the last sync time and other info from w32tm = $cmdOutput"

    # now let's try to sync time...
    
    LogWrite "DEBUG: w32tm /resync /force = $timeOutput"
    foreach ($line in $timeOutput) {
        LogWrite  "Time resync status: $line"
        $syncSuccess = ($line.contains('completed successfully'))
        LogWrite "TimeOutPut: $timeOutput"
    }
    
    # get last stync time and other info
    $cmdOutput = & {w32tm /query /status}
    LogWrite "DEBUG: Here is the last sync time and other info from w32tm = $cmdOutput"
    return $syncSuccess
}

function Set-NTPServer {
    param
    (
        [Parameter(Mandatory=$true)]$Server
    )

    LogWrite "Setting $Server as NTP server"
    $output = & 'w32tm' '/config', '/syncfromflags:manual', "/manualpeerlist:$Server"
    LogWrite "Time resync status: $output"
    $output = & 'w32tm' '/config', '/update'
    LogWrite "Time resync status: $output"
    $output = & 'w32tm' '/resync'
    LogWrite "Time resync status: $output"
}


######################################################################################################################

# Script starts here...
$Logfile = "$env:temp\win.ap.SyncTime.log"
LogWrite "Starting the oobe synctime script..."
LogWrite "Verifying if the time service is started..."

$serviceName = 'W32Time'
$service = Get-Service -Name $serviceName
    while ($service.Status -ne 'Running') {
        Start-Service -Name $serviceName
        LogWrite "$($service.DisplayName) service is: $($service.Status)"
        LogWrite "Starting $($service.DisplayName) service - Sleeping 15 seconds"
        Start-Sleep -Seconds 15
        $service.Refresh()
        if ($service.Status -eq 'Running') {
            LogWrite "$($service.DisplayName) service is: $($service.Status)"
        }
    }

 
    if ($service.Status -eq 'Running') {
       LogWrite "The time service is running!"
        # Get active network connection
        $defaultRouteNic = Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Sort-Object -Property RouteMetric | Select-Object -ExpandProperty ifIndex
        $ipv4 = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $defaultRouteNic | Select-Object -ExpandProperty IPAddress
        LogWrite "Local IP: $ipv4"

        # set vars...
        $ZscalerDetected = $false
        $CompanyNetworkDetected = $false
        $InternetDetected = $false
        $ips = $null
        $fqdn = "contoso.com"
        
        # let's see are we on Zscaler...
        LogWrite "Checking type of network access"    
        

        # are we on Zscaler private access ?
        try {$ips = [System.Net.Dns]::GetHostAddresses("$fqdn")
                #$ips.IPAddressToString
                    if ($ips.IPAddressToString.StartsWith("10.168.")){
                        $ZscalerDetected = $true}
            }
        catch {LogWrite "Error getting FQDN for $fqdn, not connected to Zscaler private access"
        }
        LogWrite "on Zscaler: $ZscalerDetected "

        # are we on the CompanyName LAN ?
        LogWrite "Checking if on Companyname network access"
        try {$ips = [System.Net.Dns]::GetHostAddresses("$fqdn")
        
            if ($ips.IPAddressToString.StartsWith("192.168.")){
                $CompanyNetworkDetected = $true}
        }
        catch {LogWrite "Error getting FQDN for $fqdn, not on CompanyName wired LAN network"
        }
        LogWrite "on CompanyName wired LAN: $CompanyNetworkDetected "

        # if we are on CompanyName LAN, let's determine the datacenter location...
        if ($CompanyNetworkDetected -or $ZscalerDetected){
        LogWrite "CompanyName LAN was detected, checking which datacenter now..."
         try {$ips = [System.Net.Dns]::GetHostAddresses("$fqdn")
                LogWrite  "$fqdn ip address:  $ips.IPAddressToString"
                if  ($ips.IPAddressToString -eq "192.168." -or "10.168"){
                $DataCenter = "Datacentername"
                $NTPServer = "ntp.CompanyName.local,ntp2.CompanyName.local,time.windows.com"}
                
            }
        catch { LogWrite "Error getting FQDN for $fqdn, could not determine Datacenter location"
        }
         LogWrite "dataCenter: $DataCenter "}
        
        #if ($ipv4.StartsWith('192.') -or $ZscalerDetected) {Set-NTPServer -Server 'time.CompanyName.com'
        if ($CompanyNetworkDetected -or $ZscalerDetected) {
        
        Set-NTPServer -Server $NTPServer
            LogWrite "Looks like we are on a CompanyName network so setting '$NTPServer'"
            if (Set-SystemTime) { cleanup }
            }
            else {Set-NTPServer 'time.windows.com'
            LogWrite "we could NOT resolve 'ntp.CompanyName.local' so we are setting NTP to 'time.windows.com'"
            if (Set-SystemTime) { cleanup }
            }
}
            
LogWrite "SyncTime script completed."