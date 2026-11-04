@echo off
setlocal EnableExtensions EnableDelayedExpansion
rem ---------------------------------------------------------------------------------------------------------------------------
rem Link-XayaUI.bat : the simple installer (no PowerShell). Links each XayaUI addon folder of this GitHub Desktop checkout into
rem World of Warcraft\_retail_\Interface\AddOns with a Windows folder link (junction), so a GitHub Desktop pull or branch switch
rem changes what the game loads. Works from the checkout's top folder or from tools\qa-installer\ on any branch.
rem   Right-click > Run as administrator (the game folder is under Program Files).
rem   Another AddOns folder:  Link-XayaUI.bat "D:\Games\World of Warcraft\_retail_\Interface\AddOns"
rem Real folders in the way are MOVED to Interface\XayaUI-backup-<number>, never deleted. Settings (WTF) are never touched.
rem XayaUI_GameDump is left alone on purpose (your local copy may be newer than the repository's).
rem ---------------------------------------------------------------------------------------------------------------------------

set "REPO=%~dp0"
if not exist "%REPO%XayaUI\XayaUI.toc" set "REPO=%~dp0..\..\"
if not exist "%REPO%XayaUI\XayaUI.toc" (
    echo STOPPED: cannot find the XayaUI folder next to this file or two folders up.
    goto :end
)
for %%I in ("%REPO%.") do set "REPO=%%~fI"

set "ADDONS=%~1"
if "%ADDONS%"=="" set "ADDONS=C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns"
if not exist "%ADDONS%\" (
    echo STOPPED: this AddOns folder does not exist: %ADDONS%
    echo Run it again with your AddOns folder in quotes after the file name.
    goto :end
)
for %%I in ("%ADDONS%\..") do set "IFACE=%%~fI"

rem The game may stay open: a /reload in game picks up the new folders, as with any addon install.

echo.
echo Checkout : %REPO%
echo AddOns   : %ADDONS%
echo.

set "BACKUP=%IFACE%\XayaUI-backup-%RANDOM%"
set "BAD=0"
for %%F in (XayaUI XayaUI_Bonus XayaUI_Chat XayaUI_Media XayaUI_Options XayaUI_QoL XayaUI_Reskin) do (
    if exist "%REPO%\%%F\%%F.toc" (
        set "LINKED="
        rem an existing link (junction) is removed and made again; only the link goes, never the files it points to
        dir /AL /B "%ADDONS%" 2>nul | findstr /I /X /C:"%%F" >nul && (
            rmdir "%ADDONS%\%%F"
            set "LINKED=1"
        )
        rem a real folder in the way is moved to the backup folder
        if not defined LINKED if exist "%ADDONS%\%%F\" (
            if not exist "!BACKUP!\" mkdir "!BACKUP!"
            move "%ADDONS%\%%F" "!BACKUP!\%%F" >nul && echo   moved old %%F to !BACKUP!
        )
        mklink /J "%ADDONS%\%%F" "%REPO%\%%F" >nul 2>&1
        if exist "%ADDONS%\%%F\%%F.toc" (
            echo   OK    %%F
        ) else (
            echo   FAIL  %%F   ^(right-click this file and choose "Run as administrator"^)
            set /a BAD+=1
        )
    )
)

echo.
if "%BAD%"=="0" (
    echo Done. Start the game; new folders need a full restart, not just /reload.
    echo XayaUI_GameDump was not touched.
) else (
    echo %BAD% folder^(s^) did not link. Send a screenshot of this window.
)

:end
echo.
pause
