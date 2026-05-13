@echo off
setlocal
cd /d "%~dp0.."

echo Running OllamaFile first-time setup.
echo If Windows asks about running a script, choose Yes.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-windows.ps1"
set RC=%ERRORLEVEL%

echo.
if "%RC%"=="0" (
    echo Setup finished successfully.
) else (
    echo Setup did not finish. See the messages above.
)

echo Press any key to close this window.
pause >nul
endlocal
exit /b %RC%
