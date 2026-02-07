<#
.SYNOPSIS
    Claude Session Bridge - Multi-session monitoring daemon
.DESCRIPTION
    Monitors multiple Claude Code sessions and manages notifications/responses
.PARAMETER Test
    Run in test mode (single iteration, then exit)
.PARAMETER EnableRouter
    Enable response router to listen for mobile responses
#>

param(
    [switch]$Test,
    [switch]$EnableRouter
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "Claude Session Bridge"

# Load dependencies
. "$PSScriptRoot\SessionManager.ps1"
. "$PSScriptRoot\ResponseRouter.ps1"

$script:Running = $true
$script:DiscoveryInterval = 5  # seconds
$script:Config = $null
$script:RouterJob = $null

function Show-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host "     ____ _                 _        ____       _     _            " -ForegroundColor Magenta
    Write-Host "    / ___| | __ _ _   _  __| | ___  | __ ) _ __(_) __| | __ _  ___ " -ForegroundColor Magenta
    Write-Host "   | |   | |/ _' | | | |/ _' |/ _ \ |  _ \| '__| |/ _' |/ _' |/ _ \" -ForegroundColor Magenta
    Write-Host "   | |___| | (_| | |_| | (_| |  __/ | |_) | |  | | (_| | (_| |  __/" -ForegroundColor Magenta
    Write-Host "    \____|_|\__,_|\__,_|\__,_|\___| |____/|_|  |_|\__,_|\__, |\___|" -ForegroundColor Magenta
    Write-Host "                                                        |___/      " -ForegroundColor Magenta
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Multi-Session Remote Control for Claude Code" -ForegroundColor White
    Write-Host ""
}

function Show-SessionsTable {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Registry
    )

    if (-not $Registry.sessions) {
        Write-Host "  No active sessions detected." -ForegroundColor Yellow
        return
    }

    $sessionCount = ($Registry.sessions.PSObject.Properties | Measure-Object).Count

    if ($sessionCount -eq 0) {
        Write-Host "  No active sessions detected." -ForegroundColor Yellow
        return
    }

    Write-Host "  Active Sessions: $sessionCount" -ForegroundColor Green
    Write-Host "  $('-' * 80)" -ForegroundColor DarkGray
    Write-Host "  $("{0,-20} {1,-10} {2,-15} {3,-30}" -f "Session ID", "PID", "Project", "Status")" -ForegroundColor White
    Write-Host "  $('-' * 80)" -ForegroundColor DarkGray

    $Registry.sessions.PSObject.Properties | ForEach-Object {
        $session = $_.Value
        $statusColor = switch ($session.status) {
            "active" { "Green" }
            "waiting" { "Yellow" }
            default { "Gray" }
        }

        Write-Host "  $("{0,-20} {1,-10} {2,-15} {3,-30}" -f `
            $session.session_id, `
            $session.pid, `
            $session.project_name, `
            $session.status)" -ForegroundColor $statusColor
    }

    Write-Host "  $('-' * 80)" -ForegroundColor DarkGray
    Write-Host ""
}

function Start-DiscoveryLoop {
    <#
    .SYNOPSIS
        Main discovery loop - continuously scan for sessions
    #>
    Show-Header

    Write-Host "  Starting session discovery..." -ForegroundColor Yellow
    Write-Host "  Scanning every $script:DiscoveryInterval seconds" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Press Ctrl+C to stop" -ForegroundColor DarkGray
    Write-Host ""

    $iteration = 0

    while ($script:Running) {
        try {
            # Discover sessions
            $sessions = Discover-ClaudeSessions

            # Update registry
            $registry = Update-SessionRegistry -Sessions $sessions

            # Display
            $timestamp = Get-Date -Format "HH:mm:ss"

            if ($iteration % 6 -eq 0) {  # Refresh display every ~30 seconds
                Show-Header
                Write-Host "  Last scan: $timestamp" -ForegroundColor Gray
                Write-Host ""
                Show-SessionsTable -Registry $registry
                Write-Host "  Monitoring... Press Ctrl+C to stop" -ForegroundColor DarkGray
                Write-Host ""
            }
            else {
                # Just update timestamp on same line
                Write-Host "`r  Last scan: $timestamp | Active sessions: $(Get-SessionCount)   " -NoNewline -ForegroundColor Gray
            }

            $iteration++

            # Test mode - exit after one iteration
            if ($Test) {
                Write-Host ""
                Write-Host "  Test mode - exiting after one scan" -ForegroundColor Yellow
                break
            }

            # Wait before next scan
            Start-Sleep -Seconds $script:DiscoveryInterval
        }
        catch {
            Write-Host ""
            Write-Host "  Error during discovery: $_" -ForegroundColor Red
            Start-Sleep -Seconds $script:DiscoveryInterval
        }
    }
}

function Stop-Bridge {
    Write-Host ""
    Write-Host "  Stopping Claude Session Bridge..." -ForegroundColor Yellow
    $script:Running = $false
}

# Handle Ctrl+C gracefully
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Stop-Bridge
}

# Load configuration
$configPath = "$PSScriptRoot\config.json"
if (Test-Path $configPath) {
    try {
        $json = Get-Content $configPath -Raw
        $script:Config = $json | ConvertFrom-Json
    }
    catch {
        Write-Warning "Failed to load config.json"
    }
}

# Initialize
Initialize-SessionRegistry

# Start response router if enabled
if ($EnableRouter -and $script:Config) {
    Write-Host ""
    Write-Host "  Starting response router..." -ForegroundColor Yellow

    # Start router in background runspace
    $routerScript = {
        param($ConfigPath, $ScriptRoot)

        # Load dependencies in background runspace
        . "$ScriptRoot\SessionManager.ps1"
        . "$ScriptRoot\ResponseRouter.ps1"

        # Load config
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

        # Start listener
        Start-ResponseListener -Config $config
    }

    $script:RouterJob = Start-Job -ScriptBlock $routerScript -ArgumentList $configPath, $PSScriptRoot

    Write-Host "  Response router started (Job ID: $($script:RouterJob.Id))" -ForegroundColor Green
    Start-Sleep -Seconds 2
}

# Start monitoring
try {
    Start-DiscoveryLoop
}
finally {
    # Stop router job if running
    if ($script:RouterJob) {
        Write-Host "  Stopping response router..." -ForegroundColor Yellow
        Stop-Job -Job $script:RouterJob
        Remove-Job -Job $script:RouterJob
    }

    Write-Host ""
    Write-Host "  Bridge stopped." -ForegroundColor Cyan
    Write-Host ""
}
