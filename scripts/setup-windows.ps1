# OllamaFile first-time setup for Windows.
#
# Lifecycle: routine — first-time install, but safe to re-run; idempotent.
#
# Verifies Docker is present and running, starts both containers, downloads the
# language model, then sanity-checks that the web app and the model both respond.
# Designed to be read out loud by a screen reader, so messages are full sentences
# and one step is announced before the work for that step begins.
#
# Paired thin launcher: setup-windows.cmd.

$ErrorActionPreference = "Stop"

# Run from the repo root regardless of where this script was launched from.
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$model = if ($env:OLLAMA_MODEL) { $env:OLLAMA_MODEL } else { "llama3.2:1b" }
$totalSteps = 6

function Write-Step {
    param([int]$Number, [string]$Message)
    Write-Host ""
    Write-Host ("Step {0} of {1}. {2}" -f $Number, $totalSteps, $Message)
}

function Fail {
    param([string]$Message)
    Write-Host ""
    Write-Host "Setup did not complete."
    Write-Host $Message
    exit 1
}

Write-Host ""
Write-Host "OllamaFile first-time setup."
Write-Host "This script checks Docker, builds the OllamaFile app, downloads the language model, and confirms everything works."
Write-Host "The slow part is the model download. Allow several minutes on a typical home connection."

# --- Step 1: Docker CLI is installed ----------------------------------------
Write-Step 1 "Checking that Docker is installed."
$dockerVersion = $null
try { $dockerVersion = & docker --version 2>$null } catch {}
if (-not $dockerVersion) {
    Fail "Docker is not installed, or the docker command is not on the PATH. Install Docker Desktop from https://www.docker.com/products/docker-desktop, reboot, then run this script again."
}
Write-Host "Docker is installed. Version: $dockerVersion."

# --- Step 2: Docker Desktop daemon is running -------------------------------
Write-Step 2 "Checking that Docker Desktop is running."
& docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Fail "Docker Desktop does not appear to be running. Open the Start menu, type Docker Desktop, press Enter, wait until it says it is running, then run this script again."
}
Write-Host "Docker Desktop is running."

# --- Step 3: build images + start containers --------------------------------
Write-Step 3 "Building the OllamaFile container and starting both services."
Write-Host "This downloads the Ollama image and builds the OllamaFile app. The first run takes a few minutes."
& docker compose up -d --build
if ($LASTEXITCODE -ne 0) {
    Fail "Docker compose failed. Read the messages above for the cause. A common one is port 5000 already being used by another program."
}
Write-Host "Both containers are running."

# --- Step 4: pre-pull the language model ------------------------------------
Write-Step 4 "Downloading the language model: $model."
Write-Host "This is the slow step. The default model is about 1.3 gigabytes."
& docker compose exec -T ollama ollama pull $model
if ($LASTEXITCODE -ne 0) {
    Fail "Model download failed. Check your internet connection and run this script again. Docker remembers what it already downloaded, so it will pick up where it left off."
}
Write-Host "Model download complete."

# --- Step 5: web app responds on port 5000 ----------------------------------
Write-Step 5 "Checking that the web app is responding on port 5000."
$webOk = $false
for ($i = 1; $i -le 30; $i++) {
    try {
        $resp = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:5000/" -TimeoutSec 2
        if ($resp.StatusCode -eq 200) { $webOk = $true; break }
    } catch {
        Start-Sleep -Seconds 1
    }
}
if (-not $webOk) {
    Fail "The web app did not respond within 30 seconds. Run 'docker compose logs app' from the ollamafile folder to see what went wrong."
}
Write-Host "Web app responded with HTTP 200."

# --- Step 6: model end-to-end probe -----------------------------------------
Write-Step 6 "Asking the model a tiny test question to confirm it responds."
$probeBody = @{
    model = $model
    prompt = "Reply with the single word: ready."
    stream = $false
} | ConvertTo-Json -Compress
try {
    $probe = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:11434/api/generate" -Method POST -Body $probeBody -ContentType "application/json" -TimeoutSec 120
    if ($probe.StatusCode -ne 200) { throw "non-200" }
    Write-Host "Model responded successfully."
} catch {
    Fail "The model did not respond. The containers are running but something is off. Run 'docker compose logs ollama' for clues."
}

# --- Create a desktop shortcut ----------------------------------------------
Write-Host ""
Write-Host "Creating a desktop shortcut called Start OllamaFile."
try {
    $desktop = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktop "Start OllamaFile.lnk"
    $startCmd = Join-Path $PSScriptRoot "start-windows.cmd"
    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($shortcutPath)
    $sc.TargetPath = $startCmd
    $sc.WorkingDirectory = $repoRoot
    $sc.Description = "Start OllamaFile and open it in your browser."
    $sc.Save()
    Write-Host "Desktop shortcut created at: $shortcutPath."
} catch {
    Write-Host "Could not create the desktop shortcut. This is not fatal - you can still start OllamaFile by running scripts\start-windows.cmd."
}

# --- Done -------------------------------------------------------------------
Write-Host ""
Write-Host "Setup complete."
Write-Host "OllamaFile is now running at http://localhost:5000."
Write-Host "Opening that address in your default browser now."
Start-Process "http://localhost:5000/" | Out-Null

Write-Host ""
Write-Host "Day-to-day:"
Write-Host "  Start:  press Enter on the Start OllamaFile shortcut on your desktop, or run scripts\start-windows.cmd."
Write-Host "  Stop:   run scripts\stop-windows.cmd from this folder."
