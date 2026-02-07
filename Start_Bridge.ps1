$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "Claude Session Bridge"

# Run the bridge
& "$PSScriptRoot\bridge\ClaudeSessionBridge.ps1"
