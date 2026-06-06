@echo off
rem Thin launcher for update-windows.ps1. See that file for the description
rem of what this script does, the steps it performs, and its lifecycle.
setlocal
cd /d "%~dp0.."

echo Updating OllamaFile.
echo If Windows asks about running a script, choose Yes.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update-windows.ps1"
set RC=%ERRORLEVEL%

echo.
if "%RC%"=="0" (
    echo Update finished successfully.
) else (
    echo Update did not finish. See the messages above.
)

echo Press any key to close this window.
pause >nul
endlocal
exit /b %RC%
