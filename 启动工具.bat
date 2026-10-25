@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0GameSpeedTool.ps1"
if errorlevel 1 pause
exit /b