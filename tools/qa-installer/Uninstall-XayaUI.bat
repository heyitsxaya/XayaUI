@echo off
rem Removes the folder links Install-XayaUI.bat made. Real folders, other addons, and your settings are never touched.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-XayaUI.ps1" -Remove %*
echo.
pause
