@echo off
rem XayaUI QA installer: links the addon folders of this checkout into World of Warcraft\_retail_\Interface\AddOns.
rem Safe to run again. Extra options pass through, for example:  Install-XayaUI.bat -DryRun
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-XayaUI.ps1" %*
echo.
pause
