@echo off
setlocal
cd /d "%~dp0.."

echo Stopping OllamaFile.

docker compose down
if errorlevel 1 (
    echo.
    echo docker compose down reported an error. See the messages above.
    echo Press any key to close this window.
    pause >nul
    endlocal
    exit /b 1
)

echo OllamaFile is stopped.
echo Press any key to close this window.
pause >nul
endlocal
