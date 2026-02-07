<#
.SYNOPSIS
    Session discovery and tracking for Claude Code instances
.DESCRIPTION
    Discovers active Claude Code sessions (VSCode and CLI), tracks them in a registry,
    and manages session lifecycle
#>

. "$PSScriptRoot\WindowsAPI.ps1"

$script:RegistryPath = "$PSScriptRoot\session_registry.json"

function Initialize-SessionRegistry {
    <#
    .SYNOPSIS
        Create initial session registry if it doesn't exist
    #>
    if (-not (Test-Path $script:RegistryPath)) {
        $registry = @{
            sessions = @{}
            last_updated = (Get-Date).ToString("o")
        }
        $registry | ConvertTo-Json -Depth 10 | Set-Content $script:RegistryPath -Encoding UTF8
    }
}

function Get-SessionRegistry {
    <#
    .SYNOPSIS
        Load session registry from disk
    .RETURNS
        PSCustomObject representing the registry
    #>
    if (-not (Test-Path $script:RegistryPath)) {
        Initialize-SessionRegistry
    }

    try {
        $json = Get-Content $script:RegistryPath -Raw -ErrorAction Stop
        return $json | ConvertFrom-Json
    }
    catch {
        Write-Warning "Failed to load session registry, creating new one"
        Initialize-SessionRegistry
        return @{
            sessions = @{}
            last_updated = (Get-Date).ToString("o")
        }
    }
}

function Save-SessionRegistry {
    <#
    .SYNOPSIS
        Save session registry to disk
    .PARAMETER Registry
        The registry object to save
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Registry
    )

    $Registry.last_updated = (Get-Date).ToString("o")
    $Registry | ConvertTo-Json -Depth 10 | Set-Content $script:RegistryPath -Encoding UTF8
}

function Get-ProcessType {
    <#
    .SYNOPSIS
        Determine process type (vscode, terminal, cli)
    .PARAMETER Process
        Process object from Get-Process
    .RETURNS
        String: "vscode", "terminal", or "cli"
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Process
    )

    if ($Process.ProcessName -match "Code") {
        return "vscode"
    }
    elseif ($Process.ProcessName -match "WindowsTerminal") {
        return "terminal"
    }
    elseif ($Process.ProcessName -match "powershell|pwsh|cmd") {
        return "terminal"
    }
    else {
        return "cli"
    }
}

function Test-IsClaudeProcess {
    <#
    .SYNOPSIS
        Check if a process is running Claude Code
    .PARAMETER Process
        Process object from Get-Process
    .RETURNS
        Boolean indicating if this is a Claude Code process
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Process
    )

    # VSCode processes
    if ($Process.ProcessName -match "Code") {
        $windowTitle = Get-WindowTitle -ProcessId $Process.Id
        if ($windowTitle -and $windowTitle -match "Visual Studio Code") {
            return $true
        }
    }

    # Terminal processes - check command line or window title for "claude"
    if ($Process.ProcessName -match "powershell|pwsh|WindowsTerminal") {
        $windowTitle = Get-WindowTitle -ProcessId $Process.Id
        if ($windowTitle -and $windowTitle -match "claude") {
            return $true
        }

        # Try to check command line
        try {
            $commandLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($Process.Id)" -ErrorAction SilentlyContinue).CommandLine
            if ($commandLine -and $commandLine -match "claude") {
                return $true
            }
        }
        catch {
            # Can't determine, skip
        }
    }

    return $false
}

function New-SessionObject {
    <#
    .SYNOPSIS
        Create a new session object
    .PARAMETER Process
        Process object from Get-Process
    .RETURNS
        PSCustomObject representing a session
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Process
    )

    $processType = Get-ProcessType -Process $Process
    $sessionId = "$processType-$($Process.Id)"
    $windowTitle = Get-WindowTitle -ProcessId $Process.Id
    $projectName = Get-ProjectNameFromTitle -WindowTitle $windowTitle

    return [PSCustomObject]@{
        session_id = $sessionId
        pid = $Process.Id
        process_name = $Process.ProcessName
        window_title = if ($windowTitle) { $windowTitle } else { "" }
        project_name = $projectName
        last_seen = (Get-Date).ToString("o")
        status = "active"
    }
}

function Discover-ClaudeSessions {
    <#
    .SYNOPSIS
        Discover all active Claude Code sessions
    .RETURNS
        Array of session objects
    #>
    $sessions = @()

    # Find VSCode processes
    $vsCodeProcesses = Get-Process -Name "Code" -ErrorAction SilentlyContinue
    foreach ($proc in $vsCodeProcesses) {
        if ($proc.MainWindowHandle -ne 0 -and (Test-IsClaudeProcess -Process $proc)) {
            $session = New-SessionObject -Process $proc
            $sessions += $session
        }
    }

    # Find terminal processes
    $terminalNames = @("WindowsTerminal", "powershell", "pwsh")
    foreach ($name in $terminalNames) {
        $terminalProcesses = Get-Process -Name $name -ErrorAction SilentlyContinue
        foreach ($proc in $terminalProcesses) {
            if ($proc.MainWindowHandle -ne 0 -and (Test-IsClaudeProcess -Process $proc)) {
                $session = New-SessionObject -Process $proc
                $sessions += $session
            }
        }
    }

    return $sessions
}

function Update-SessionRegistry {
    <#
    .SYNOPSIS
        Update session registry with discovered sessions
    .PARAMETER Sessions
        Array of session objects from Discover-ClaudeSessions
    .RETURNS
        Updated registry object
    #>
    param(
        [Parameter(Mandatory = $true)]
        [Array]$Sessions
    )

    $registry = Get-SessionRegistry

    # Create hashtable for quick lookup
    $sessionDict = @{}
    if ($registry.sessions) {
        # Convert PSCustomObject properties to hashtable
        $registry.sessions.PSObject.Properties | ForEach-Object {
            $sessionDict[$_.Name] = $_.Value
        }
    }

    # Update existing sessions and add new ones
    foreach ($session in $Sessions) {
        $sessionDict[$session.session_id] = $session
    }

    # Remove sessions where process no longer exists
    $activePids = $Sessions | ForEach-Object { $_.pid }
    $toRemove = @()
    foreach ($sid in $sessionDict.Keys) {
        $session = $sessionDict[$sid]
        if ($session.pid -notin $activePids) {
            # Check if process still exists
            $proc = Get-Process -Id $session.pid -ErrorAction SilentlyContinue
            if (-not $proc) {
                $toRemove += $sid
            }
        }
    }

    foreach ($sid in $toRemove) {
        $sessionDict.Remove($sid)
    }

    # Convert back to PSCustomObject
    $registry.sessions = [PSCustomObject]$sessionDict
    Save-SessionRegistry -Registry $registry

    return $registry
}

function Get-SessionCount {
    <#
    .SYNOPSIS
        Get count of active sessions
    .RETURNS
        Integer count
    #>
    $registry = Get-SessionRegistry
    if ($registry.sessions) {
        return ($registry.sessions.PSObject.Properties | Measure-Object).Count
    }
    return 0
}

function Get-SessionById {
    <#
    .SYNOPSIS
        Get a specific session by ID
    .PARAMETER SessionId
        The session ID
    .RETURNS
        Session object or $null
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SessionId
    )

    $registry = Get-SessionRegistry
    if ($registry.sessions.$SessionId) {
        return $registry.sessions.$SessionId
    }
    return $null
}

# Functions are available via dot-sourcing, no module export needed
