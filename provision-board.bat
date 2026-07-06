@echo off
setlocal
echo Provisioning your PyKit Explorer board from GitHub...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0provision-board.ps1" %*
