# Claude Remote Control

Control multiple Claude Code sessions from your phone using push notifications.

**⚡ TL;DR Setup:** Install ntfy app → Clone repo → Edit config.json → Run one PowerShell command → Restart VSCode → Double-click 2 bat files → Done! ([Jump to Quick Start](#-quick-start))

---

## Overview

This system allows you to:
- Monitor multiple Claude Code sessions (VSCode + Terminal) from your phone
- Receive push notifications when Claude requests permissions
- Approve/Deny permissions directly from your phone with a single tap
- Automatically route responses back to the correct session

Perfect for working remotely or monitoring long-running Claude tasks while away from your desk.

## How It Works

```
┌─────────────────┐         ┌──────────────┐         ┌─────────────┐
│  VSCode/Claude  │         │ Session      │         │   ntfy.sh   │
│                 │────────▶│ Bridge       │────────▶│  (Push)     │
│  Terminal/Claude│         │              │         │             │
└─────────────────┘         └──────────────┘         └──────┬──────┘
                                                            │
                            ┌───────────────────────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │  Your Phone  │
                     │   (ntfy app) │
                     └──────┬───────┘
                            │
                            │ (Tap Allow/Deny)
                            │
                            ▼
┌─────────────────┐   ┌──────────────┐
│  VSCode/Claude  │◀──│  Response    │
│                 │   │  Router      │
│  Terminal/Claude│   │              │
└─────────────────┘   └──────────────┘
```

1. **Session Bridge** monitors running Claude Code sessions
2. **Permission Hook** sends notifications to ntfy.sh when Claude requests permissions
3. **Your Phone** receives instant push notification with Allow/Deny buttons
4. **Response Router** listens for your response and routes it to the correct session
5. **Keystroke injection** automatically clicks Allow/Deny in the session window

## 🚀 Quick Start

### First Computer Setup (5 minutes)

1. **Install ntfy app** on your phone ([Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy) | [iOS](https://apps.apple.com/us/app/ntfy/id1625396347))
   - Open app → Click "+" → Create topic: `claude-yourname-x7k9` (use random chars for security)

2. **Clone this repo**
   ```bash
   git clone <repo-url> ClaudeRemote
   cd ClaudeRemote
   ```

3. **Configure your ntfy topic**
   - Edit `bridge/config.json`
   - Change `"topic": "claude-varun-x7k9"` to YOUR topic from step 1

4. **Install the hook** (run this PowerShell command):
   ```powershell
   $hookPath = "$(Get-Location)\hooks\permission_request.ps1"
   $settings = @{ hooks = @{ PermissionRequest = @(@{ hooks = @(@{ command = "powershell -ExecutionPolicy Bypass -File `"$hookPath`""; type = "command" }) }) } }
   $settings | ConvertTo-Json -Depth 10 | Set-Content "$env:USERPROFILE\.claude\settings.json" -Encoding UTF8
   Write-Host "✓ Hook installed!" -ForegroundColor Green
   ```

5. **Restart VSCode completely** (close and reopen, not just reload)

6. **Run the monitoring services** (keep both windows open):
   - Double-click `Start_Bridge.bat`
   - Double-click `Start_Router.bat`

7. **Test it!** In VSCode, ask Claude to create a file. You'll get a notification on your phone!

### Additional Computers (2 minutes)

1. **Copy the ClaudeRemote folder** to the new computer
2. **Install the hook** (same PowerShell command from step 4 above)
3. **Restart VSCode**
4. **Run the bat files** (`Start_Bridge.bat` + `Start_Router.bat`)
5. **Done!** Same phone controls all computers

> **Note:** Use the **same ntfy topic** across all computers - your phone will receive notifications from all of them!

## Prerequisites

- Windows 10/11
- PowerShell 5.1 or later
- Claude Code (VSCode extension or CLI)
- Mobile phone with [ntfy app](https://ntfy.sh/) installed
  - Android: [Google Play](https://play.google.com/store/apps/details?id=io.heckel.ntfy)
  - iOS: [App Store](https://apps.apple.com/us/app/ntfy/id1625396347)

## First-Time Setup

### Step 1: Install ntfy App on Your Phone

1. Download and install ntfy from your app store
2. Open the app
3. Click "+" to create a new subscription
4. Choose a unique topic name (e.g., `claude-yourname-x7k9`)
   - Must be unique across all ntfy users
   - Use random characters for security
5. Save the topic name - you'll need it in Step 3

### Step 2: Clone/Download This Repository

```bash
# Clone to your desired location
git clone <repo-url> ClaudeRemote
cd ClaudeRemote
```

Or download and extract the ZIP file.

### Step 3: Configure ntfy Topic

Edit [`bridge/config.json`](bridge/config.json):

```json
{
  "version": "1.0.0",
  "ntfy": {
    "server": "https://ntfy.sh",
    "topic": "claude-yourname-x7k9",  ← Change this to YOUR topic
    "priority": {
      "permission": 4,
      "notification": 3
    }
  },
  "bridge": {
    "discovery_interval_seconds": 5,
    "session_timeout_seconds": 300,
    "registry_path": "./session_registry.json"
  }
}
```

**Important:** Replace `claude-yourname-x7k9` with the topic you created in Step 1.

### Step 4: Install Claude Code Hook

Run this PowerShell command (as Administrator or with appropriate permissions):

```powershell
# Navigate to the ClaudeRemote directory
cd F:\Work\ClaudeRemote  # ← Change to your actual path

# Update the hook path in the permission_request.ps1 file if needed
# The hook will auto-detect paths using $PSScriptRoot

# Add hook to Claude Code settings
$settingsPath = "$env:USERPROFILE\.claude\settings.json"

# Read existing settings or create new
if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
} else {
    $settings = @{}
}

# Add hook configuration
$hookPath = "$(Get-Location)\hooks\permission_request.ps1"
$settings.hooks = @{
    PermissionRequest = @(
        @{
            hooks = @(
                @{
                    command = "powershell -ExecutionPolicy Bypass -File `"$hookPath`""
                    type = "command"
                }
            )
        }
    )
}

# Save settings
$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
Write-Host "Hook installed successfully!" -ForegroundColor Green
Write-Host "Path: $hookPath" -ForegroundColor Cyan
```

**IMPORTANT:** After installing the hook, **restart VSCode completely** (not just reload window).

### Step 5: Start the Monitoring Services

You need to run **two** terminal windows:

#### Terminal 1: Session Bridge
```batch
# Double-click Start_Bridge.bat
# Or run manually:
powershell -ExecutionPolicy Bypass -File Start_Bridge.ps1
```

This monitors your Claude Code sessions and updates the session registry.

#### Terminal 2: Response Router
```batch
# Double-click Start_Router.bat
# Or run manually:
powershell -ExecutionPolicy Bypass -File Start_Router.ps1
```

This listens for responses from your phone and routes them to the correct session.

**Keep both windows running** while using Claude Code remotely.

### Step 6: Test the System

1. Make sure both terminals are running
2. In VSCode with Claude Code, trigger a permission request (e.g., ask Claude to create a file)
3. You should receive a notification on your phone within seconds
4. Tap "Allow" or "Deny"
5. Watch the Response Router terminal - it should show the session receiving the keystroke
6. The permission in VSCode should be automatically approved/denied

## Setup on Additional Computers (e.g., Work Computer)

**TL;DR:** Copy folder → Install hook → Restart VSCode → Run bat files → Done!

See the [Quick Start - Additional Computers](#-quick-start) section above for the 2-minute setup process.

### Important Notes

- **Use the same ntfy topic** - Don't change `bridge/config.json`, keep your existing topic
- **Same phone, multiple computers** - Your phone receives notifications from all computers
- **Portable paths** - The hook uses `$PSScriptRoot`, so it works anywhere you put the folder
- **Different paths OK** - Just update the path in the hook installation command to match your actual location

## Usage

### Daily Workflow

1. **Start monitoring** (run both .bat files):
   - `Start_Bridge.bat` - Monitors sessions
   - `Start_Router.bat` - Routes responses

2. **Use Claude Code** normally in VSCode or terminal

3. **When Claude requests permission:**
   - Phone vibrates with notification
   - Notification shows: tool name and session ID
   - Tap "Allow" or "Deny"
   - Permission automatically applied

4. **Stop monitoring** when done:
   - Press `Ctrl+C` in both terminal windows

### Running on Startup (Optional)

To auto-start the monitoring services:

1. Press `Win+R`, type `shell:startup`, press Enter
2. Create shortcuts to `Start_Bridge.bat` and `Start_Router.bat`
3. Set shortcuts to run minimized (Right-click → Properties → Run: Minimized)

## Project Structure

```
ClaudeRemote/
├── README.md                      ← This file
├── Start_Bridge.bat              ← Launch session monitor
├── Start_Bridge.ps1
├── Start_Router.bat              ← Launch response router
├── Start_Router.ps1
├── hook_log.txt                  ← Debug log (auto-generated)
│
├── bridge/
│   ├── config.json               ← YOUR NTFY TOPIC HERE
│   ├── session_registry.json     ← Auto-generated session list
│   ├── ClaudeSessionBridge.ps1   ← Session discovery engine
│   ├── SessionManager.ps1        ← Session management
│   ├── ResponseRouter.ps1        ← Phone response handler
│   └── WindowsAPI.ps1            ← Win32 window utilities
│
└── hooks/
    └── permission_request.ps1    ← Claude Code hook script
```

## Troubleshooting

### "No notification on my phone"

1. **Check ntfy app subscription:**
   - Open ntfy app
   - Verify your topic is subscribed
   - Topic must match exactly in `bridge/config.json`

2. **Check hook is installed:**
   ```powershell
   cat $env:USERPROFILE\.claude\settings.json
   # Should show PermissionRequest hook pointing to permission_request.ps1
   ```

3. **Check hook log:**
   ```powershell
   cat .\hook_log.txt
   # Should show "Hook triggered" entries when permissions requested
   ```

4. **Did you restart VSCode?**
   - VSCode must be fully restarted after installing/updating hooks
   - Reload window is NOT enough - close and reopen VSCode

### "Session not found" in Response Router

1. **Check Session Bridge is running:**
   - Session Bridge window should show your active sessions
   - Session ID should match the one in the notification

2. **Check session_registry.json:**
   ```powershell
   cat .\bridge\session_registry.json
   # Should show vscode-{PID} session
   ```

3. **VSCode PID changed:**
   - If you restarted VSCode, the session ID changed
   - Old notifications have the old session ID
   - Wait for a new permission request to get fresh notification

### "Permission not applied" after clicking Allow/Deny

1. **Check Response Router received it:**
   - Router window should show "Response: vscode-XXXXX -> y"

2. **Check keystroke was sent:**
   - Router should show "Sent 'y' to vscode-XXXXX" in green

3. **VSCode window focus:**
   - VSCode must be running and not minimized
   - Windows can't send keystrokes to minimized windows

4. **Try clicking in VSCode first:**
   - Click the permission dialog in VSCode
   - Then tap Allow/Deny on phone
   - This ensures VSCode has focus

### "Hook error" or notifications not sending

1. **Check hook path in settings.json:**
   ```powershell
   cat $env:USERPROFILE\.claude\settings.json
   # Path should be absolute and point to permission_request.ps1
   ```

2. **Check hook can read config.json:**
   ```powershell
   # Test manually:
   echo '{"tool_name":"Write","message":"test"}' | powershell -ExecutionPolicy Bypass -File .\hooks\permission_request.ps1
   # Should output: {"continue": true}
   # Check hook_log.txt for errors
   ```

3. **Check ntfy.sh is reachable:**
   ```powershell
   Invoke-RestMethod -Uri "https://ntfy.sh" -Method Get
   # Should return ntfy website HTML
   ```

## Security Notes

- **ntfy topics are public by default** - anyone who knows your topic name can subscribe
- Use a unique, random topic name with random characters (e.g., `claude-yourname-x7k9m2p`)
- Don't share your topic name publicly
- For production use, consider [self-hosting ntfy](https://docs.ntfy.sh/install/) with authentication

## Credits

Built for controlling Claude Code sessions remotely. Uses:
- [ntfy.sh](https://ntfy.sh/) for push notifications (free, open-source)
- PowerShell for Windows automation
- Claude Code hooks system for interception

## License

MIT License - See LICENSE file for details

---

**Need help?** Check the troubleshooting section or open an issue on GitHub.
