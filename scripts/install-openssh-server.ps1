# Install Windows OpenSSH Server.
#
# Lifecycle: one-shot. Once OpenSSH Server is installed, started, and set
# to auto-start, this script has done its job. It is safe to re-run though;
# every step is idempotent.
#
# What it does:
#   1. Verifies this PowerShell is running as Administrator.
#   2. Installs the OpenSSH Server Windows capability.
#   3. Starts the sshd service and sets it to start automatically on boot.
#   4. Verifies (or creates) the inbound firewall rule for TCP port 22.
#   5. Sets Windows PowerShell as the default shell for incoming SSH logins,
#      so a remote login lands in PowerShell, not the legacy cmd.exe.
#   6. Prints a summary, including the Windows user name and host name needed
#      for the first connection.
#
# How to run this script:
#
#   1. Open PowerShell as Administrator (Start menu, type PowerShell,
#      right-click "Windows PowerShell", choose "Run as administrator").
#   2. Change to the folder where you saved this script. For example, if
#      you saved it to your Downloads folder:
#          cd $env:USERPROFILE\Downloads
#   3. Allow this script to run in just this PowerShell window:
#          Set-ExecutionPolicy -Scope Process Bypass -Force
#   4. Run it:
#          .\install-openssh-server.ps1
#
# Designed to read out loud cleanly under JAWS or NVDA: full-sentence
# prompts, one step announced before the work for that step begins.

$ErrorActionPreference = "Stop"
$totalSteps = 6

function Write-Step {
    param([int]$Number, [string]$Message)
    Write-Host ""
    Write-Host ("Step {0} of {1}. {2}" -f $Number, $totalSteps, $Message)
}

function Fail {
    param([string]$Message)
    Write-Host ""
    Write-Host "OpenSSH Server setup did not complete."
    Write-Host $Message
    exit 1
}

Write-Host ""
Write-Host "Install Windows OpenSSH Server."
Write-Host "This script installs the OpenSSH Server capability, starts the sshd service, makes it start automatically on every boot, verifies the firewall rule for port 22, and configures PowerShell as the default shell for remote logins."

# --- Step 1: admin check -----------------------------------------------------
Write-Step 1 "Checking that this PowerShell window is running as Administrator."
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Fail "This PowerShell window is not running as Administrator. Close it, open a new one with Run as administrator, then run this script again from there."
}
Write-Host "PowerShell is running as Administrator."

# --- Step 2: install the capability -----------------------------------------
Write-Step 2 "Installing the OpenSSH Server Windows capability."
Write-Host "If it is already installed this step is harmless."
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
Write-Host "OpenSSH Server capability is installed."

# --- Step 3: service --------------------------------------------------------
Write-Step 3 "Starting the sshd service and setting it to start automatically on boot."
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic
$svc = Get-Service sshd
Write-Host ("sshd service status: {0}. Start type: {1}." -f $svc.Status, $svc.StartType)

# --- Step 4: firewall -------------------------------------------------------
Write-Step 4 "Checking the inbound firewall rule for SSH on TCP port 22."
$rule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
if (-not $rule) {
    Write-Host "The firewall rule was not created automatically. Creating it now."
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' `
        -DisplayName 'OpenSSH Server (sshd)' `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
} elseif (-not $rule.Enabled) {
    Write-Host "The firewall rule exists but is disabled. Enabling it now."
    Set-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -Enabled True
}
Write-Host "Firewall rule for incoming SSH is in place and enabled."

# --- Step 5: default shell --------------------------------------------------
Write-Step 5 "Setting Windows PowerShell as the default shell for incoming SSH connections."
Write-Host "Without this, a remote login would land in the old cmd.exe, which is awkward for development tools."
New-Item -Path "HKLM:\SOFTWARE\OpenSSH" -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty `
    -Path "HKLM:\SOFTWARE\OpenSSH" `
    -Name DefaultShell `
    -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -PropertyType String -Force | Out-Null
Write-Host "Default shell for SSH is now Windows PowerShell."

# --- Step 6: summary --------------------------------------------------------
Write-Step 6 "Summary."
$svc = Get-Service sshd
$rule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
Write-Host ("sshd service status: {0}." -f $svc.Status)
Write-Host ("sshd start type: {0}." -f $svc.StartType)
Write-Host ("Firewall rule enabled: {0}." -f $rule.Enabled)
Write-Host ("Your Windows user name: {0}." -f $env:USERNAME)
Write-Host ("Your computer's host name: {0}." -f $env:COMPUTERNAME)

Write-Host ""
Write-Host "OpenSSH Server is installed and running."
Write-Host ""
Write-Host "Next step: tell Neill your Windows user name and your computer's host name, both printed above. He will try to connect from his Mac with a command like ssh $env:USERNAME@$env:COMPUTERNAME from the same local network. Password authentication is enabled. SSH key authentication will be a separate step after the first password login works."
