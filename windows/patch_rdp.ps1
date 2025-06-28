#####################################################################################
# Patch RDP to allow multiple connections
# This script patches the termsrv.dll file to allow multiple RDP connections
# It stops the RDP services, takes ownership of the termsrv.dll file,
# grants full control to the current user, and applies the patch.
# It also logs the actions taken to a shared folder.
# Usage: Run this script as an administrator on the target machine.
# Version: 1.3 
# Date: 2025-06-27
# Author: Torayld
#####################################################################################
Write-Output "****************************"
Write-Output "**  RDP Patch             **"
Write-Output "**  Date    : 2025-06-27  **"
Write-Output "**  Version : 1.3         **"
Write-Output "**  Author  : Torayld     **"
Write-Output "****************************"

$SharedFolderLog = "\\nas-archives\software_log\"+$env:COMPUTERNAME+"_RDP.log"
$Message = '';
Set-Location c:

#   Get status of the two services UmRdpService and TermService...
$svc_UmRdpService_status = (get-service UmRdpService).status
$svc_TermService_status  = (get-service TermService).status

#   ... display them ...
Write-Output "Status of service UmRdpService: $svc_TermService_status"
Write-Output "Status of service TermService:  $svc_TermService_status"

#   ... before stopping them ...
try{
	Write-Output "Desactivating startup services"
    Set-Service -Name UmRdpService -StartupType Disabled
    Set-Service -Name TermService -StartupType Disabled
	
	Write-Output "Stopping services"
    Stop-Service -Name UmRdpService -Force -ErrorAction Stop
    Stop-Service -Name TermService  -Force -ErrorAction Stop
    Start-Sleep -Seconds 5  # Wait 5 seconds

	# Check if stopped
    $svc = Get-Service -Name TermService
    if ($svc.Status -ne 'Stopped') {
        throw "Service is always running."
    }
}catch{
    # If stop failed kill them all
	Write-Output "Kill them all"
    Get-Process | Where-Object { $_.Name -eq 'UmRdpService' -or $_.Name -eq 'TermService' } | Stop-Process -Force -ErrorAction SilentlyContinue

}

#   Save ACL and owner of termsrv.dll:
$termsrv_dll_acl   = get-acl c:\windows\system32\termsrv.dll
$termsrv_dll_owner = $termsrv_dll_acl.owner
Write-Output "Owner of termsrv.dll:           $termsrv_dll_owner"

#   Take ownership of the DLL...
takeown /f c:\windows\system32\termsrv.dll
$new_termsrv_dll_owner = (Get-Acl c:\windows\system32\termsrv.dll).owner
Write-Output "New Owner of termsrv.dll:           $new_termsrv_dll_owner"

#    ... and grant (/G) full control (:F) to Everyone" (S-1-1-0)
#Start-Process icacls @'
#c:\windows\system32\termsrv.dll /grant "Tout le monde":F /C
#'@
Start-Process icacls -ArgumentList @(
    'C:\Windows\System32\termsrv.dll',
    '/grant *S-1-1-0:F',
    '/C'
) -Wait

# search for a pattern in termsrv.dll file
$dll_as_bytes = Get-Content c:\windows\system32\termsrv.dll -Raw -Encoding byte
$dll_as_text = $dll_as_bytes.forEach('ToString', 'X2') -join ' '
$patternregex = ([regex]'39 81 3C 06 00 00(\s\S\S){6}')
$patch = 'B8 00 01 00 00 89 81 38 06 00 00 90'
$checkPattern=Select-String -Pattern $patternregex -InputObject $dll_as_text
If ($checkPattern -ne $null) {
    $dll_as_text_replaced = $dll_as_text -replace $patternregex, $patch
    Write-Output "Patch needed, backup old file"
    Copy-Item c:\windows\system32\termsrv.dll c:\windows\system32\termsrv.dll.backup -Force
	Write-Output "patching termsrv.dll"
	[byte[]] $dll_as_bytes_replaced = -split $dll_as_text_replaced -replace '^', '0x'
	Set-Content c:\windows\system32\termsrv.dll.patched -Encoding Byte -Value $dll_as_bytes_replaced

	# comparing two files
	Write-Output "Comparaison :"
	fc.exe /b c:\windows\system32\termsrv.dll.patched c:\windows\system32\termsrv.dll
	try{
		Copy-Item c:\windows\system32\termsrv.dll.patched c:\windows\system32\termsrv.dll -Force
		Write-Output "replacing the original termsrv.dll file Success"
		"$(Get-Date) : Patch reussi v1.3" | Out-file -FilePath $SharedFolderLog -Append 
	}catch{
		Write-Output "replacing the original termsrv.dll file FAILED"
		"$(Get-Date) : Patch echoue v1.3" | Out-file -FilePath $SharedFolderLog -Append 
	}
}
Elseif (Select-String -Pattern $patch -InputObject $dll_as_text) {
    Write-Output 'The termsrv.dll file is already patch, exitting'
    "$(Get-Date) : Patch deja present" | Out-file -FilePath $SharedFolderLog -Append 
}
else {
    Write-Output "Pattern not found"
    "$(Get-Date) : Patch non reussi (pattern error)" | Out-file -FilePath $SharedFolderLog -Append
}

Write-Output "Restore ACL"
Set-Acl c:\windows\system32\termsrv.dll $termsrv_dll_acl

Write-Output "Reactivating startup service"
Set-Service -Name UmRdpService -StartupType Automatic 
Set-Service -Name TermService -StartupType Automatic 

Write-Output "Restart service"
Start-Service -Name UmRdpService
Start-Service -Name TermService