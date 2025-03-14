' niall brady 2021/12/13
Dim objShell,objFSO,objFile

Set objShell=CreateObject("WScript.Shell")
Set objFSO=CreateObject("Scripting.FileSystemObject")

'enter the path for your PowerShell Script
Set objNetwork = CreateObject("Wscript.Network")
'Wscript.Echo "The current user is " & objNetwork.UserName
 'strPath="C:\Users\" + objNetwork.UserName +"\Appdata\Local\Temp\SyncTime.ps1"
strPath="C:\ProgramData\CompanyName\SetTimeZone\SyncTime.ps1"
'wscript.quit(0)
'verify file exists
 If objFSO.FileExists(strPath) Then
   'return short path name
   set objFile=objFSO.GetFile(strPath)
   strCMD="powershell -executionpolicy bypass -nologo -command " & Chr(34) & "&{" &_
    objFile.ShortPath & "}" & Chr(34)
   'Uncomment next line for debugging
   'WScript.Echo strCMD

  'use 0 to hide window
   objShell.Run strCMD,0

Else

  'Display error message
   WScript.Echo "Failed to find " & strPath
   WScript.Quit

End If