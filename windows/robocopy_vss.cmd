@ECHO OFF
ECHO ***********************************
ECHO *     Robocopy VSS                *
ECHO *  Perform a frozen backup using  *
ECHO *  VSS snapshots and Robocopy     *
ECHO *  Date: 2025-06-18               *
ECHO *  Version: 1.1                   *
ECHO *  Author: Torayld                *
ECHO ***********************************
SETlocal ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION
chcp 65001 >nul

:: === HELP ===
if "%~1"=="/?" goto :HELP
if "%~1"=="-h" goto :HELP
if "%~1"=="/h" goto :HELP

where vssadmin >nul 2>&1
if errorlevel 1 (
    ECHO [X] VSSADMIN not found. The VSS service might not be installed.
    goto :END
) else (
    ECHO [OK] The vssadmin utility is available.
)

sc query VSS | findstr /I "STATE" >nul
if errorlevel 1 (
    ECHO [X] The VSS service is missing or inaccessible.
    goto :END
) else (
    ECHO [OK] The VSS service is installed.
)

:: === POSITIONAL PARAMETER PARSING ===
if "%~1"=="" (
    ECHO [X] Error: source path is missing.
    goto :HELP
)

if "%~2"=="" (
    ECHO [X] Error: destination path is missing.
    goto :HELP
)

SET "SRC_FOLDER=%~1"
SET "DEST_FOLDER=%~2"

:: === PARAMETER VALIDATION ===
if not defined SRC_FOLDER (
    ECHO [X] Error: Source path is required with -s=
    goto :HELP
)
if not defined DEST_FOLDER (
    ECHO [X] Error: Destination path is required with -d=
    goto :HELP
)

:: === EXTRACT OR DEDUCE DRIVE LETTER ===
SET "SRC_DRIVE="
SET "SRC_ABS_PATH=%SRC_FOLDER%"

:: Check if source path starts with a drive letter
ECHO %SRC_FOLDER% | findstr /R "^[A-Za-z]:\\.*" >nul
if !errorlevel! EQU 0 (
    :: full path, extract the drive letter
    for /f "tokens=1 delims=:" %%D in ("%SRC_FOLDER%") do (
        SET "SRC_DRIVE=%%D:"
    )
) else (
    :: relative path, use current path
    for %%C in ("%CD%") do (
        SET "SRC_DRIVE=%%~dC"
        SET "SRC_ABS_PATH=%%C%SRC_FOLDER%"
    )
)

:: Final check
if not defined SRC_DRIVE (
    ECHO [X] Error: Could not determine the source drive letter.
    goto :HELP
)

SET "SYMLINK_DIR=%SRC_DRIVE%\temp"

:: === ROBOCOPY OPTIONS ===
SET "ROBOCOPY_OPTIONS=/MIR /Z /COPYALL /R:3 /W:5 /XD "$RECYCLE.BIN" /NP /xj /unilog:%SRC_DRIVE%\robocopy.log"
GOTO :START

:HELP
ECHO.
ECHO === HELP ===
ECHO Usage: %~nx0 ^<source_folder^> ^<destination_folder^>
ECHO.
ECHO Example:
ECHO    %~nx0 -M:\dfs\a \\10.101.254.44\ArchivesMails
ECHO.
ECHO This script:
ECHO - Creates a VSS snapshot of the specified drive
ECHO - Mounts a temporary symlink
ECHO - Uses Robocopy to perform a frozen backup
ECHO - Cleans up the symlink and deletes the snapshot after copy
ECHO.
ECHO Note: Requires administrator privileges.
pause
exit /b

:START
:: === CREATE SHADOW COPY ===
ECHO [*] Creating snapshot for %SRC_DRIVE%...
SET "SHADOW_VOLUME="
SET "SHADOW_ID="

for /f "tokens=* delims=" %%i in ('vssadmin create shadow /for^=%SRC_DRIVE% 2^>nul') do (
    ECHO %%i

    ECHO %%i | findstr "Shadow Copy Volume Name" >nul
    if !errorlevel! EQU 0 (
		SET "SHADOW_VOLUME=%%i"
		SET "SHADOW_VOLUME=!SHADOW_VOLUME:Shadow Copy Volume Name: =!"
		SET "SHADOW_VOLUME=!SHADOW_VOLUME: =!"
    )

    ECHO %%i | findstr "ID" >nul
    if !errorlevel! EQU 0 (
		SET "SHADOW_ID=%%i"
		SET "SHADOW_ID=!SHADOW_ID:Shadow Copy ID: =!"
		SET "SHADOW_ID=!SHADOW_ID: =!"
		if "!SHADOW_ID:~-1!"=="." (
			SET "SHADOW_ID=!SHADOW_ID:~0,-1!"
		)
    )
)
:: Snapshot volume extraction
ECHO [*] Detected shadow volume: !SHADOW_VOLUME!
ECHO [*] Shadow ID: !SHADOW_ID!
REM ECHO [*] New source: "%SYMLINK_DIR%!SRC_FOLDER:*:=!"

:: Check if path is valid
if not defined SHADOW_VOLUME (
    ECHO [X] ERROR: Could not extract shadow volume path.
    goto :CLEANUP
)

if not defined SHADOW_ID (
    ECHO [X] ERROR: Could not extract shadow ID.
    goto :CLEANUP
)

:: === CREATE SYMBOLIC LINK ===
if exist "%SYMLINK_DIR%" (
    ECHO [!] Deleting previous symlink %SYMLINK_DIR%...
    rmdir "%SYMLINK_DIR%" >nul 2>&1
)
mklink /d "%SYMLINK_DIR%" "%SHADOW_VOLUME%" >nul
if not exist "%SYMLINK_DIR%" (
    ECHO [X] ERROR: Failed to create symbolic link.
    goto :CLEANUP
)

:: === COPY WITH ROBOCOPY ===
ECHO [*] Starting Robocopy...
robocopy "%SYMLINK_DIR%!SRC_FOLDER:*:=!" %DEST_FOLDER% %ROBOCOPY_OPTIONS%

:CLEANUP
ECHO Cleaning up...

:: === UNMOUNT VOLUME ===
if exist "%SYMLINK_DIR%" (
    ECHO [*] Removing temporary symlink...
	rmdir "%SYMLINK_DIR%" 2>&1
	if !errorlevel! NEQ 0 (
		ECHO [X] ERROR: Failed to remove symlink %SYMLINK_DIR%.
	) else (
		ECHO [OK] Symlink %SYMLINK_DIR% was successfully removed.
	)
)

:: === DELETE SHADOW COPY ===
if defined SHADOW_ID (
    ECHO Deleting snapshot ID %SHADOW_ID%...
	for /f "delims=" %%l in ('vssadmin delete shadows /Shadow^=%SHADOW_ID% /quiet 2^>nul') do (
		ECHO %%l
		ECHO %%l | findstr /I "was deleted successfully" >nul
		if !errorlevel! == 0 (
			SET "SHADOW_DELETE_STATUS=OK"
		)
	)

	if "!SHADOW_DELETE_STATUS!"=="OK" (
		ECHO [OK] Snapshot successfully deleted.
	) else (
		ECHO [X] ERROR: Snapshot deletion failed or uncertain result.
	)
)

:END
ECHO Operation completed.
endlocal
