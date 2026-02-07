param()
$ErrorActionPreference = "SilentlyContinue"

# Get base directory (parent of hooks folder)
$baseDir = Split-Path $PSScriptRoot -Parent

# Log to file for debugging
"Hook triggered at $(Get-Date)" | Out-File "$baseDir\hook_log.txt" -Append

$inputJson = [Console]::In.ReadToEnd()
$hookData = $inputJson | ConvertFrom-Json

# Load configuration
$configPath = Join-Path $baseDir "bridge\config.json"
$config = Get-Content $configPath -Raw | ConvertFrom-Json
$server = $config.ntfy.server
$topic = $config.ntfy.topic

$toolName = if ($hookData.tool_name) { $hookData.tool_name } else { "Tool" }

# Get current session ID from registry (the key name IS the session_id)
$registryPath = Join-Path $baseDir "bridge\session_registry.json"
$sessionId = "unknown"
if (Test-Path $registryPath) {
    $registry = Get-Content $registryPath -Raw | ConvertFrom-Json
    $vscodeKey = $registry.sessions.PSObject.Properties.Name | Where-Object { $_ -like "vscode-*" } | Select-Object -First 1
    if ($vscodeKey) {
        $sessionId = $vscodeKey
    }
}

$notification = @{
    topic = $topic
    title = "Claude: $toolName"
    message = "Session: $sessionId"
    priority = 4
    tags = @("lock", "robot")
    actions = @(
        @{ action="http"; label="Allow"; url="$server/$topic-response"; method="POST"; body="{`"session_id`":`"$sessionId`",`"key`":`"y`"}" }
        @{ action="http"; label="Deny"; url="$server/$topic-response"; method="POST"; body="{`"session_id`":`"$sessionId`",`"key`":`"n`"}" }
    )
}

$json = $notification | ConvertTo-Json -Depth 10 -Compress
$body = [System.Text.Encoding]::UTF8.GetBytes($json)
Invoke-RestMethod -Uri $server -Method Post -Body $body -ContentType "application/json; charset=utf-8" | Out-Null

"Hook completed sending notification" | Out-File "$baseDir\hook_log.txt" -Append

@{ continue = $true } | ConvertTo-Json
exit 0
