# One-off update script for Chad's OllamaFile install on Windows.
#
# Lifecycle: ONE-SHOT. Once the install has been updated past the auto-pull
# change to docker-compose.yml, this script and its .cmd launcher can be
# deleted. Future updates use update-windows.{cmd,ps1}.
#
# Applies the auto-pull-model fix. After this runs, the model is pulled
# automatically by Docker every time `docker compose up` is called, so no
# one has to remember to run `ollama pull` by hand.
#
# What it does:
#   1. Checks Docker Desktop is running.
#   2. Pulls the latest source from GitHub via WSL (no Git for Windows needed).
#   3. Stops the existing containers (volumes preserved - your model stays).
#   4. Rebuilds the app image and starts everything.
#   5. Waits for the web app to respond on port 5000.
#   6. Opens the page in your default browser.
#
# Why WSL git instead of native git: the original install was a `git clone`
# inside WSL, so the Windows-side update-windows.ps1 (which uses Git for
# Windows) can't pull. This bridges that gap once.
#
# Safe to run more than once. Assumes the repo lives at
# C:\Users\Chad\Desktop\Duke - edit $repoPath below if it is elsewhere.
#
# Paired thin launcher: apply-auto-pull-update.cmd.

$ErrorActionPreference = "Stop"

$repoPath = "C:\Users\Chad\Desktop\Duke"
$wslRepoPath = "/mnt/c/Users/Chad/Desktop/Duke"

function Fail([string]$msg) {
    Write-Host ""
    Write-Host "Update did not finish."
    Write-Host $msg
    exit 1
}

Write-Host ""
Write-Host "OllamaFile one-off update."
Write-Host "This pulls the latest version, restarts the containers, and verifies the web app is responding."
Write-Host "If the model needs to be downloaded for the first time, the rebuild step takes several minutes."
Write-Host ""

if (-not (Test-Path $repoPath)) {
    Fail "Repo folder not found at $repoPath. Open this script in Notepad and change the path on the line that starts with `$repoPath`, then run again."
}

Set-Location $repoPath

# --- Step 1: Docker Desktop running ----------------------------------------
Write-Host "Step 1 of 5. Checking that Docker Desktop is running."
& docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Fail "Docker Desktop is not running. Open the Start menu, type Docker Desktop, press Enter, wait until it says it is running, then run this script again."
}
Write-Host "Docker Desktop is running."

# --- Step 2: pull latest source via WSL ------------------------------------
Write-Host ""
Write-Host "Step 2 of 5. Pulling the latest source from GitHub."
& wsl bash -c "cd '$wslRepoPath' && git pull --ff-only"
if ($LASTEXITCODE -ne 0) {
    Fail "git pull failed. The messages above usually point at the cause. If you have not edited any files on purpose, ask Neill for help."
}
Write-Host "Source updated."

# --- Step 3: stop existing containers --------------------------------------
Write-Host ""
Write-Host "Step 3 of 5. Stopping existing containers. Your Ollama model stays cached."
& docker compose down
if ($LASTEXITCODE -ne 0) {
    Fail "docker compose down failed. See the messages above."
}
Write-Host "Containers stopped."

# --- Step 4: rebuild and start ---------------------------------------------
Write-Host ""
Write-Host "Step 4 of 5. Rebuilding the app and starting all containers."
Write-Host "If the model is not yet downloaded, this step takes a few minutes."
& docker compose up -d --build
if ($LASTEXITCODE -ne 0) {
    Fail "docker compose up failed. See the messages above."
}
Write-Host "Containers are starting."

# --- Step 5: wait for the web app on port 5000 -----------------------------
Write-Host ""
Write-Host "Step 5 of 5. Waiting for the web app to respond on port 5000."
Write-Host "The app does not start until the model is pulled, so this may take a while on the first run."
$webOk = $false
for ($i = 1; $i -le 900; $i++) {
    try {
        $resp = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:5000/" -TimeoutSec 2
        if ($resp.StatusCode -eq 200) { $webOk = $true; break }
    } catch {
        Start-Sleep -Seconds 1
    }
}
if (-not $webOk) {
    Fail "The web app did not respond within 15 minutes. The model pull may have failed. From PowerShell in $repoPath, run 'docker compose logs ollama-init' to see what went wrong."
}
Write-Host "Web app responded with HTTP 200."

# --- Done ------------------------------------------------------------------
Write-Host ""
Write-Host "Update complete."
Write-Host "OllamaFile is running at http://localhost:5000."
Write-Host "Opening that address in your default browser now."
Start-Process "http://localhost:5000/" | Out-Null
