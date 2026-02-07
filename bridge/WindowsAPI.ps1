<#
.SYNOPSIS
    Windows API helpers for window management
.DESCRIPTION
    Provides Win32 API wrappers for window title extraction and manipulation
#>

# Add Win32 API types if not already loaded
if (-not ([System.Management.Automation.PSTypeName]'Win32.User32').Type) {
    Add-Type @"
        using System;
        using System.Runtime.InteropServices;
        using System.Text;

        namespace Win32 {
            public class User32 {
                [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
                public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

                [DllImport("user32.dll", SetLastError = true)]
                public static extern IntPtr GetWindowThreadProcessId(IntPtr hWnd, out int lpdwProcessId);
            }
        }
"@
}

function Get-WindowTitle {
    <#
    .SYNOPSIS
        Get window title for a process
    .PARAMETER ProcessId
        The PID of the process
    .RETURNS
        Window title string, or $null if not found
    #>
    param(
        [Parameter(Mandatory = $true)]
        [int]$ProcessId
    )

    try {
        $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        if (-not $process) {
            return $null
        }

        if ($process.MainWindowHandle -eq 0) {
            return $null
        }

        $title = New-Object System.Text.StringBuilder 256
        $length = [Win32.User32]::GetWindowText($process.MainWindowHandle, $title, $title.Capacity)

        if ($length -gt 0) {
            return $title.ToString()
        }

        return $null
    }
    catch {
        return $null
    }
}

function Get-ProjectNameFromTitle {
    <#
    .SYNOPSIS
        Extract project name from window title
    .PARAMETER WindowTitle
        The window title string
    .RETURNS
        Project name or "Unknown"
    #>
    param(
        [Parameter(Mandatory = $false)]
        [string]$WindowTitle
    )

    if ([string]::IsNullOrWhiteSpace($WindowTitle)) {
        return "Unknown"
    }

    # VSCode pattern: "ProjectName - Visual Studio Code"
    if ($WindowTitle -match "^(.+?)\s*-\s*Visual Studio Code") {
        return $Matches[1].Trim()
    }

    # Terminal with project directory pattern: "PowerShell - path\to\project"
    if ($WindowTitle -match "PowerShell.*\\([^\\]+)$") {
        return $Matches[1].Trim()
    }

    # Terminal with claude command: "claude - ProjectName" or similar
    if ($WindowTitle -match "claude.*?[-:]?\s*(.+)$") {
        return $Matches[1].Trim()
    }

    # Generic pattern: take first part before dash
    if ($WindowTitle -match "^([^-]+)") {
        $name = $Matches[1].Trim()
        if ($name.Length -gt 0 -and $name -ne "PowerShell" -and $name -ne "Administrator") {
            return $name
        }
    }

    return "Unknown"
}

# Functions are available via dot-sourcing, no module export needed
