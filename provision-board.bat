@echo off
setlocal
echo Provisioning your PyKit Explorer board from Bitbucket...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0provision-board.ps1" %*
