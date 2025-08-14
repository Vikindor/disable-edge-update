@echo off
:: =========================================================
:: RUN_disable_edgeupdate.bat
:: Run disable_edgeupdate.ps1 with elevation and correct host
:: =========================================================

setlocal
set "SCRIPT=%~dp0disable_edgeupdate.ps1"

:: 1) Check for admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -NoProfile -WindowStyle Hidden -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: 2) Detect PowerShell Core (pwsh) or Windows PowerShell
where pwsh >nul 2>&1
if %errorLevel% equ 0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
)

endlocal
