# Cleanup helper: free ports 5000 and 11434.
#
# Lifecycle: situational — run only when `docker compose up` fails with
# "port already allocated" or similar. Not part of normal install/update.
#
# Stops and removes any Docker containers currently holding the OllamaFile
# ports. Useful when an old compose project (from a previous folder name)
# is still running and blocks a new `docker compose up`.
#
# Does NOT touch volumes - the Ollama model stays cached on disk and will
# be picked up by the next `docker compose up` only if that compose project
# uses the same volume name. If you renamed the folder, the new project
# will use a different volume name and you may need to re-download the
# model. See the longer-term fix in docker-compose.yml (pinning `name:`).

$ErrorActionPreference = "Stop"
$ports = @(5000, 11434)

Write-Host ""
Write-Host "Looking for containers using ports $($ports -join ' or ')..."

$matched = @()
$lines = & docker ps -a --format "{{.ID}}|{{.Names}}|{{.Image}}|{{.Ports}}|{{.Status}}" 2>$null
foreach ($line in $lines) {
    foreach ($port in $ports) {
        if ($line -match ":$port->") {
            $matched += $line
            break
        }
    }
}

if ($matched.Count -eq 0) {
    Write-Host "No containers are holding those ports. Nothing to do."
    exit 0
}

Write-Host ""
Write-Host "Found these containers:"
foreach ($m in $matched) {
    $parts = $m -split '\|'
    Write-Host ("  - {0}  (image: {1})  ports: {2}  [{3}]" -f $parts[1], $parts[2], $parts[3], $parts[4])
}

Write-Host ""
$confirm = Read-Host "Stop and remove these containers? Type yes to confirm"
if ($confirm -ne 'yes') {
    Write-Host "Cancelled. No changes made."
    exit 0
}

foreach ($m in $matched) {
    $parts = $m -split '\|'
    $id = $parts[0]
    $name = $parts[1]
    Write-Host "Stopping $name..."
    & docker stop $id *> $null
    Write-Host "Removing $name..."
    & docker rm $id *> $null
}

Write-Host ""
Write-Host "Done. Ports $($ports -join ' and ') should now be free."
Write-Host "Now run: docker compose up -d --build"
