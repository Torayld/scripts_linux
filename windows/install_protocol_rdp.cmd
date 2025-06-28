@ECHO OFF
ECHO *************************
ECHO *  Install RDP Protocol *
ECHO *  Date : 2025-06-26    *
ECHO *  Version : 1.5        *
ECHO *  Auteur : Torayld     *
ECHO *************************
ECHO Generation du fichier de commande
ECHO @ECHO off > c:\windows\system32\mstsc.cmd
ECHO ECHO ************************* >> c:\windows\system32\mstsc.cmd
ECHO ECHO *  RDP Protocol Wrapper * >> c:\windows\system32\mstsc.cmd
ECHO ECHO *  Date : 2023-10-02    * >> c:\windows\system32\mstsc.cmd
ECHO ECHO *  Version : 1.4        * >> c:\windows\system32\mstsc.cmd
ECHO ECHO *  Auteur : Torayld     * >> c:\windows\system32\mstsc.cmd
ECHO ECHO ************************* >> c:\windows\system32\mstsc.cmd
ECHO SET host=%%1 >> c:\windows\system32\mstsc.cmd
ECHO ECHO Connection on %%host:~6,-2%% >> c:\windows\system32\mstsc.cmd
ECHO start /B c:\windows\system32\mstsc.exe /prompt /v:%%host:~6,-2%% >> c:\windows\system32\mstsc.cmd
ECHO exit >> c:\windows\system32\mstsc.cmd

ECHO Registering RDP protocol...
reg add HKEY_CLASSES_ROOT\rdp /t REG_SZ /d "URL:RDP Protocol" /f
reg add HKEY_CLASSES_ROOT\rdp /v "URL Protocol" /t REG_SZ /f
reg add HKEY_CLASSES_ROOT\rdp\shell\open\command /t REG_SZ /d "C:\windows\system32\mstsc.cmd %%1" /f
ECHO Installation done