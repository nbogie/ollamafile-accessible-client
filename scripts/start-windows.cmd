@echo off
setlocal
cd /d "%~dp0.."

echo Starting OllamaFile.

docker compose up -d
if errorlevel 1 (
    echo.
    echo Could not start the containers.
    echo Is Docker Desktop running? Open the Start menu, type Docker Desktop, press Enter, wait until it says it is running, then try again.
    echo Press any key to close this window.
    pause >nul
    endlocal
    exit /b 1
)

echo Containers are running.
echo Opening http://localhost:5000 in your default browser.
start "" "http://localhost:5000/"

endlocal
