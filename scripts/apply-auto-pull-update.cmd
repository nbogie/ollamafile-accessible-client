@echo off
rem Thin launcher for apply-auto-pull-update.ps1. See that file for the
rem description of what this script does and its lifecycle (one-shot).
setlocal
cd /d "%~dp0.."

echo Running the OllamaFile one-off update.
echo If Windows asks about running a script, choose Yes.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0apply-auto-pull-update.ps1"
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
