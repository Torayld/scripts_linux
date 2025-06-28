@ECHO OFF
ECHO ***************************
ECHO *  Instal CallTo Protocol *
ECHO *  Date : 2023-07-07      *
ECHO *  Version : 1.0          *
ECHO *  Auteur : Torayld       *
ECHO ***************************
SET EXE_PATH=C:\Program Files (x86)\MaX UC\ui\MaX UC.exe
ECHO Registering callto protocol...
reg add HKEY_CLASSES_ROOT\callto /t REG_SZ /d "URL:RDP Protocol" /f
reg add HKEY_CLASSES_ROOT\callto /v "URL Protocol" /t REG_SZ /f
reg add HKEY_CLASSES_ROOT\callto\shell\open\command /t REG_SZ /d "\"%EXE_PATH%\" \"%%1\"" /f
ECHO Install done
exit 0