@echo off
where /q pwsh >nul 2>&1
if %errorlevel%==0 (
    pwsh -File "%~dp0update.ps1" %*
) else (
    powershell -File "%~dp0update.ps1" %*
)
