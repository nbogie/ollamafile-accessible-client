# Install an SSH public key for password-less login.
#
# Lifecycle: one-shot per trusted person, per machine. Re-running with the
# same key is harmless (the script deduplicates).
#
# Companion to install-openssh-server.ps1. After OpenSSH Server is running,
# this script installs a single SSH public key so the owner of the matching
# private key can log in without a password.
#
# The key being installed is embedded below in $PublicKey. To trust someone
# else, edit that one line and re-run.
#
# Windows gotcha handled automatically: when the local user is in the
# Administrators group (which Chad is on his own laptop), Windows OpenSSH
# IGNORES the per-user file %USERPROFILE%\.ssh\authorized_keys. Keys for
# admins must live in C:\ProgramData\ssh\administrators_authorized_keys
# with strict ACLs (only NT AUTHORITY\SYSTEM and BUILTIN\Administrators).
# This script writes to the right file and sets the right ACLs for you.
#
# How to run this script:
#
#   1. Open PowerShell as Administrator (Start menu, type PowerShell,
#      right-click "Windows PowerShell", choose "Run as administrator").
#   2. cd to the folder where you saved this script.
#   3. Allow scripts in this session only:
#          Set-ExecutionPolicy -Scope Process Bypass -Force
#   4. Run it:
#          .\install-authorized-key.ps1
#
# Reads cleanly under JAWS or NVDA: full-sentence prompts, one step
# announced before its work begins.

$ErrorActionPreference = "Stop"

# --- The key to install -----------------------------------------------------
# This is Neill's public key. The private half stays on his Mac and never
# leaves it. A public key is safe to share; it only grants login access,
# never the ability to read or change the matching private key.
$PublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPKM1fWlkvUPYFVN47lGCx7rTaDSWZBlnbMgMkkZsdsz neillbogie@googlemail.com"

# --- Helpers ----------------------------------------------------------------
$totalSteps = 5

function Write-Step {
    param([int]$Number, [string]$Message)
    Write-Host ""
    Write-Host ("Step {0} of {1}. {2}" -f $Number, $totalSteps, $Message)
}

function Fail {
    param([string]$Message)
    Write-Host ""
    Write-Host "Key install did not complete."
    Write-Host $Message
    exit 1
}

Write-Host ""
Write-Host "Install an SSH public key for password-less login."
Write-Host "This installs Neill's public key so he can log in to this Windows machine over SSH without you sharing your Windows password."

# --- Step 1: admin check ----------------------------------------------------
Write-Step 1 "Checking that this PowerShell window is running as Administrator."
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Fail "This PowerShell window is not running as Administrator. Close it, open a new one with Run as administrator, then run this script again."
}
Write-Host "PowerShell is running as Administrator."

# --- Step 2: decide which authorized_keys file to use ----------------------
Write-Step 2 "Choosing the correct authorized keys file based on whether your account is an Administrator."
$isCurrentUserAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isCurrentUserAdmin) {
    $authKeysPath = "C:\ProgramData\ssh\administrators_authorized_keys"
    $authKeysDir = "C:\ProgramData\ssh"
    Write-Host ("Your account is in the Administrators group. The authorized keys file for admin users is: {0}." -f $authKeysPath)
} else {
    $authKeysDir = Join-Path $env:USERPROFILE ".ssh"
    $authKeysPath = Join-Path $authKeysDir "authorized_keys"
    Write-Host ("Your account is a standard user. The authorized keys file is: {0}." -f $authKeysPath)
}

# Make sure the directory exists.
if (-not (Test-Path $authKeysDir)) {
    New-Item -ItemType Directory -Path $authKeysDir -Force | Out-Null
}

# --- Step 3: append the key, avoiding duplicates ---------------------------
Write-Step 3 "Appending the public key, unless it is already present."
$keyAlreadyPresent = $false
if (Test-Path $authKeysPath) {
    $existing = Get-Content -Path $authKeysPath -Raw -ErrorAction SilentlyContinue
    if ($existing -and $existing.Contains($PublicKey.Trim())) {
        $keyAlreadyPresent = $true
    }
}
if ($keyAlreadyPresent) {
    Write-Host "The key is already in the authorized keys file. Nothing to do."
} else {
    # Append with a newline. Use UTF-8 without BOM — sshd is picky.
    Add-Content -Path $authKeysPath -Value $PublicKey -Encoding utf8
    Write-Host "Key appended."
}

# --- Step 4: set strict ACLs (admin file only) -----------------------------
Write-Step 4 "Setting strict file permissions so that only Administrators and the SYSTEM account can read or change the keys file."
if ($isCurrentUserAdmin) {
    # Microsoft's documented ACL recipe for administrators_authorized_keys.
    icacls.exe $authKeysPath /inheritance:r | Out-Null
    icacls.exe $authKeysPath /remove "BUILTIN\Users" | Out-Null
    icacls.exe $authKeysPath /remove "Authenticated Users" | Out-Null
    icacls.exe $authKeysPath /grant "Administrators:F" | Out-Null
    icacls.exe $authKeysPath /grant "SYSTEM:F" | Out-Null
    Write-Host "Permissions set: SYSTEM and Administrators have full control. No one else has access."
} else {
    Write-Host "Standard user. No special ACL changes required."
}

# --- Step 5: summary -------------------------------------------------------
Write-Step 5 "Summary."
$svc = Get-Service sshd -ErrorAction SilentlyContinue
Write-Host ("Authorized keys file: {0}." -f $authKeysPath)
Write-Host ("Number of keys in that file: {0}." -f (Get-Content $authKeysPath | Where-Object { $_ -match '\S' }).Count)
if ($svc) {
    Write-Host ("sshd service status: {0}." -f $svc.Status)
}
Write-Host ("Your Windows user name: {0}." -f $env:USERNAME)
Write-Host ("Your computer's host name: {0}." -f $env:COMPUTERNAME)
Write-Host ""
Write-Host "The key is installed. Tell Neill your Windows user name and your computer's host name. He will try to connect with a command like ssh $env:USERNAME@$env:COMPUTERNAME and it should not ask for a password."
