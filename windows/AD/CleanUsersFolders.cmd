@ECHO OFF
ECHO **********************************************************
ECHO *  Clean Users Temp Files                                *
ECHO *  Removes the Recycle Bin from user redirected folders  *
ECHO *  and cleans up Chrome and Teams cache.                 *
ECHO *  Date : 2025-06-26                                     *
ECHO *  Version : 1.1                                         *
ECHO *  Auteur : Torayld                                      *
ECHO **********************************************************

:SAISIE
ECHO Root Users folder:
SET /P ROOT_FOLDER=

IF "%ROOT_FOLDER%"=="" (
ECHO The folder cannot be empty.
GOTO SAISIE
)

IF NOT EXIST "%ROOT_FOLDER%" (
    ECHO The folder "%ROOT_FOLDER%" does not exist.
    GOTO SAISIE
)

:CONFIRME
ECHO "%ROOT_FOLDER%", confirme Y/N ?
SET /P CONFIRMER=

IF "%CONFIRMER%"=="" (
GOTO CONFIRME
)

IF "%CONFIRMER%"=="N" (
GOTO END
)

IF NOT "%CONFIRMER%"=="Y" (
GOTO CONFIRME
)


for /d %%i in ("%ROOT_FOLDER%\*") do (
    if exist "%%i\Desktop\$RECYCLE.BIN" (
        ECHO Removing RecycleBin from %%i\Desktop
        rmdir /S /Q "%%i\Desktop\$RECYCLE.BIN"
    )
    if exist "%%i\Documents\$RECYCLE.BIN" (
        ECHO Removing RecycleBin from %%i\Documents
        rmdir /S /Q "%%i\Documents\$RECYCLE.BIN"
    )
    if exist "%%i\Favorites\$RECYCLE.BIN" (
        ECHO Removing RecycleBin from %%i\Favorites
        rmdir /S /Q "%%i\Favorites\$RECYCLE.BIN"
    )
    if exist "%%i\Downloads\$RECYCLE.BIN" (
        ECHO Removing RecycleBin from %%i\Downloads
        rmdir /S /Q "%%i\Downloads\$RECYCLE.BIN"
    )
    if exist "%%i\Videos\$RECYCLE.BIN" (
        ECHO Removing RecycleBin from %%i\Videos
        rmdir /S /Q "%%i\Videos\$RECYCLE.BIN"
    )
    if exist "%%i\Pictures\$RECYCLE.BIN" (
        ECHO Removing RecycleBin from %%i\Pictures
        rmdir /S /Q "%%i\Pictures\$RECYCLE.BIN"
    )
    if exist "%%i\Music\$RECYCLE.BIN" (
        ECHO Removing RecycleBin from %%i\Music
        rmdir /S /Q "%%i\Music\$RECYCLE.BIN"
    )
    if exist "%%i\Saved Games\$RECYCLE.BIN" (
        ECHO Removing RecycleBin from %%i\Saved Games
        rmdir /S /Q "%%i\Saved Games\$RECYCLE.BIN"
    )
    if exist "%%i\Searches\$RECYCLE.BIN" (
        ECHO Removing RecycleBin from %%i\Searches
        rmdir /S /Q "%%i\Searches\$RECYCLE.BIN"
    )
    if exist "%%i\Links\$RECYCLE.BIN" (
        ECHO Removing RecycleBin from %%i\Links
        rmdir /S /Q "%%i\Links\$RECYCLE.BIN"
    )
    if exist "%%i\Start Menu\$RECYCLE.BIN" (
        ECHO Removing RecycleBin from %%i\Start Menu
        rmdir /S /Q "%%i\Start Menu\$RECYCLE.BIN"
    )
    if exist "%%i\Contacts\$RECYCLE.BIN" (
        ECHO Removing RecycleBin from %%i\Contacts
        rmdir /S /Q "%%i\Contacts\$RECYCLE.BIN"
    )
    if exist "%%i\AppData\Roaming\$RECYCLE.BIN" (
        ECHO Removing RecycleBin from %%i\AppData\Roaming
        rmdir /S /Q "%%i\AppData\Roaming\$RECYCLE.BIN"
    )
    rmdir /S /Q "%%i\AppData\Roaming\Google\Chrome\UserData\Default\Code Cache"
    rmdir /S /Q "%%i\AppData\Roaming\Google\Chrome\UserData\Default\Service Worker\CacheStorage"
    rmdir /S /Q "%%i\AppData\Roaming\Google\Chrome\UserData\Default\IndexedDB"
    rmdir /S /Q "%%i\AppData\Roaming\Google\Chrome\UserData\Default\Cache"
    rmdir /S /Q "%%i\AppData\Roaming\Microsoft\Teams\Service Worker\CacheStorage"
)