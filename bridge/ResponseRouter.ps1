. "$PSScriptRoot\SessionManager.ps1"
Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue

function Send-KeystrokeToSession($SessionId, $Key) {
    $session = Get-SessionById -SessionId $SessionId
    if (-not $session) {
        Write-Host "Session not found: $SessionId" -ForegroundColor Red
        return $false
    }
    
    $process = Get-Process -Id $session.pid -ErrorAction SilentlyContinue
    if (-not $process) {
        Write-Host "Process dead: $SessionId" -ForegroundColor Red
        return $false
    }
    
    try {
        [Microsoft.VisualBasic.Interaction]::AppActivate($session.pid)
        Start-Sleep -Milliseconds 300
    } catch {}
    
    $sendKeys = $Key
    if ($sendKeys.Length -le 2) { $sendKeys += "{ENTER}" }
    
    try {
        $wshell = New-Object -ComObject WScript.Shell
        $wshell.SendKeys($sendKeys)
        Write-Host "Sent '$Key' to $SessionId" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "Failed to send keystroke" -ForegroundColor Red
        return $false
    }
}

function Start-ResponseListener($Config) {
    $server = $Config.ntfy.server
    $topic = "$($Config.ntfy.topic)-response"
    $url = "$server/$topic/sse"
    
    Write-Host "Connecting to: $url" -ForegroundColor Yellow
    
    while ($true) {
        try {
            $web = New-Object System.Net.WebClient
            $web.Headers.Add("Accept", "text/event-stream")
            $stream = $web.OpenRead($url)
            $reader = New-Object System.IO.StreamReader($stream)
            
            Write-Host "Connected!" -ForegroundColor Green
            
            while (-not $reader.EndOfStream) {
                $line = $reader.ReadLine()
                if ($line -match "^data:\s*(.+)$") {
                    try {
                        $event = $Matches[1] | ConvertFrom-Json
                        if ($event.message) {
                            $data = $event.message | ConvertFrom-Json
                            if ($data.session_id -and $data.key) {
                                Write-Host "Response: $($data.session_id) -> $($data.key)" -ForegroundColor Cyan
                                Send-KeystrokeToSession -SessionId $data.session_id -Key $data.key
                            }
                        }
                    } catch {}
                }
            }
        } catch {
            Write-Host "Connection lost, reconnecting..." -ForegroundColor Red
        }
        Start-Sleep -Seconds 5
    }
}
