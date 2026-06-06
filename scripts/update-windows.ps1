# OllamaFile update script for Windows.
#
# Lifecycle: routine — run any time to fetch the latest version. Idempotent.
#
# Pulls the latest source from GitHub, rebuilds the OllamaFile app container,
# and starts everything. Designed to be safe to run repeatedly: a no-op if
# you already have the latest version and the containers are already running.
# Mirrors the screen-reader-friendly style of setup-windows.ps1.
#
# Requires: Git for Windows (uses `git pull` directly). If the install is
# WSL-only, use apply-auto-pull-update.{cmd,ps1} once to bootstrap.
#
# Paired thin launcher: update-windows.cmd.

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$totalSteps = 6

function Write-Step {
    param([int]$Number, [string]$Message)
    Write-Host ""
    Write-Host ("Step {0} of {1}. {2}" -f $Number, $totalSteps, $Message)
}

function Fail {
    param([string]$Message)
    Write-Host ""
    Write-Host "Update did not complete."
    Write-Host $Message
    exit 1
}

Write-Host ""
Write-Host "OllamaFile update."
Write-Host "This script downloads the latest version of OllamaFile, rebuilds the app, and starts it."

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

# --- Step 3: Git is installed and this folder is a git clone ----------------
Write-Step 3 "Checking that Git is installed."
$gitVersion = $null
try { $gitVersion = & git --version 2>$null } catch {}
if (-not $gitVersion) {
    Fail "Git is not installed, or the git command is not on the PATH. Install Git for Windows from https://git-scm.com/download/win, accept the defaults, then run this script again."
}
Write-Host "Git is installed. Version: $gitVersion."

if (-not (Test-Path (Join-Path $repoRoot ".git"))) {
    Fail "This folder is not a git clone, so it cannot be updated with git pull. The most likely cause is that OllamaFile was installed from the zip download. To switch to the update-friendly setup, ask Neill for help, or open Command Prompt in your home folder and run: git clone https://github.com/nbogie/ollamafile-accessible-client.git ollamafile"
}

# --- Step 4: pull latest source ---------------------------------------------
Write-Step 4 "Downloading the latest changes."
& git pull --ff-only
if ($LASTEXITCODE -ne 0) {
    Fail "git pull failed. The most common cause is local changes to the files in this folder. If you have not edited anything on purpose, ask Neill for help; the messages above usually point at the cause."
}
Write-Host "Latest changes downloaded."

# --- Step 5: rebuild and start the containers -------------------------------
Write-Step 5 "Rebuilding the OllamaFile app and starting both containers."
Write-Host "If the app was already running, Docker will replace it with the new version."
& docker compose up -d --build
if ($LASTEXITCODE -ne 0) {
    Fail "Docker compose failed. Read the messages above for the cause."
}
Write-Host "Both containers are running."

# --- Step 6: web app responds on port 5000 ----------------------------------
Write-Step 6 "Checking that the web app is responding on port 5000."
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

# --- Create a desktop shortcut (idempotent) ---------------------------------
try {
    $desktop = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktop "Update OllamaFile.lnk"
    if (-not (Test-Path $shortcutPath)) {
        Write-Host ""
        Write-Host "Creating a desktop shortcut called Update OllamaFile."
        $updateCmd = Join-Path $PSScriptRoot "update-windows.cmd"
        $wsh = New-Object -ComObject WScript.Shell
        $sc = $wsh.CreateShortcut($shortcutPath)
        $sc.TargetPath = $updateCmd
        $sc.WorkingDirectory = $repoRoot
        $sc.Description = "Download the latest OllamaFile and restart it."
        $sc.Save()
        Write-Host "Desktop shortcut created at: $shortcutPath."
    }
} catch {
    Write-Host "Could not create the desktop shortcut. This is not fatal - you can still update OllamaFile by running scripts\update-windows.cmd."
}

# --- Done -------------------------------------------------------------------
Write-Host ""
Write-Host "Update complete."
Write-Host "OllamaFile is running at http://localhost:5000."
Write-Host "Opening that address in your default browser now."
Start-Process "http://localhost:5000/" | Out-Null
