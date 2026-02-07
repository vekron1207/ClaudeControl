$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "Claude Response Router"

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Claude Response Router" -ForegroundColor Magenta
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Load dependencies
. "$PSScriptRoot\bridge\SessionManager.ps1"
. "$PSScriptRoot\bridge\ResponseRouter.ps1"

# Load config
$configPath = "$PSScriptRoot\bridge\config.json"
if (-not (Test-Path $configPath)) {
    Write-Host "  Error: config.json not found!" -ForegroundColor Red
    Write-Host "  Please create bridge/config.json with your ntfy topic" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json

Write-Host "  Topic: $($config.ntfy.topic)" -ForegroundColor White
Write-Host "  Server: $($config.ntfy.server)" -ForegroundColor Gray
Write-Host ""

# Start listener
try {
    Start-ResponseListener -Config $config
}
catch {
    Write-Host ""
    Write-Host "  Error: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
}
