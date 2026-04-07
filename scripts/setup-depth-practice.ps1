# setup-depth-practice.ps1 — Interactive setup for the depth practice command pipeline (Windows)
# Creates project structure, fills templates, sets up PowerShell functions.

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=== Depth Practice Setup ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will create your depth practice project directory and set up"
Write-Host "daily commands (morning, evening, sunday) that read your entries"
Write-Host "from the Hermeer app, interpret them, and track your practice."
Write-Host ""

# --- Project Location ---
$defaultDir = "$HOME\depth-practice"
$projectDir = Read-Host "Project directory [$defaultDir]"
if ([string]::IsNullOrWhiteSpace($projectDir)) { $projectDir = $defaultDir }

if (Test-Path $projectDir) {
    Write-Host ""
    Write-Host "Directory $projectDir already exists."
    $continue = Read-Host "Continue and fill in any missing pieces? (y/n)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        Write-Host "Aborted."
        exit 0
    }
}

# --- Practitioner Name ---
Write-Host ""
$practitionerName = Read-Host "Your first name (used in briefings instead of 'user')"
if ([string]::IsNullOrWhiteSpace($practitionerName)) {
    Write-Host "A name is required. Exiting."
    exit 1
}

# --- Birth Data ---
Write-Host ""
Write-Host "Birth data is used for natal chart interpretation and transit tracking."
Write-Host "You can enter 'unknown' for any field and fill it in later."
Write-Host ""
$birthDate = Read-Host "Birth date (e.g., March 15, 1985)"
$birthTime = Read-Host "Birth time (e.g., 2:30 PM EST, or 'unknown')"
$birthLocation = Read-Host "Birth location (e.g., Portland, Oregon)"

# --- Practice Description ---
Write-Host ""
Write-Host "Describe your practice in a few sentences. What kind of inner work"
Write-Host "are you doing? (therapy, analysis, meditation, journaling, etc.)"
Write-Host "What are your active themes or questions?"
Write-Host ""
Write-Host "Type your description, then press Enter on an empty line to finish:"
$practiceDesc = ""
while ($true) {
    $line = Read-Host
    if ([string]::IsNullOrWhiteSpace($line) -and -not [string]::IsNullOrWhiteSpace($practiceDesc)) {
        break
    }
    if (-not [string]::IsNullOrWhiteSpace($practiceDesc)) {
        $practiceDesc += "`n"
    }
    $practiceDesc += $line
}

# --- HermeerSync Base ---
Write-Host ""
# Auto-detect common Windows sync locations
$icloudPath = "$env:USERPROFILE\iCloudDrive\HermeerSync"
$onedrivePath = "$env:USERPROFILE\OneDrive\HermeerSync"
$googledrivePath = "G:\My Drive\HermeerSync"

if (Test-Path $icloudPath) { $defaultSync = $icloudPath }
elseif (Test-Path $onedrivePath) { $defaultSync = $onedrivePath }
elseif (Test-Path $googledrivePath) { $defaultSync = $googledrivePath }
else { $defaultSync = "$env:USERPROFILE\HermeerSync" }

$hermeerBase = Read-Host "HermeerSync path [$defaultSync]"
if ([string]::IsNullOrWhiteSpace($hermeerBase)) { $hermeerBase = $defaultSync }

# --- Create Directory Structure ---
Write-Host ""
Write-Host "Creating project structure at $projectDir..."

New-Item -ItemType Directory -Force -Path "$projectDir\scripts" | Out-Null
New-Item -ItemType Directory -Force -Path "$projectDir\learnings" | Out-Null
New-Item -ItemType Directory -Force -Path "$projectDir\logs" | Out-Null
New-Item -ItemType Directory -Force -Path "$projectDir\logs\briefings" | Out-Null

# --- Copy Command Scripts ---
Write-Host "Copying command scripts..."

# Determine where the templates are (same directory as this script, or downloaded alongside)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = Get-Location }

# Check if templates exist locally (cloned repo), otherwise download them
$templateSource = "$scriptDir"
if (-not (Test-Path "$templateSource\morning-template.ps1")) {
    # Download from GitHub
    Write-Host "Downloading command templates..."
    $baseUrl = "https://raw.githubusercontent.com/hermeerapp/hermeer-mcp-server/main/scripts"
    Invoke-WebRequest -Uri "$baseUrl/morning-template.ps1" -OutFile "$projectDir\scripts\morning.ps1"
    Invoke-WebRequest -Uri "$baseUrl/evening-template.ps1" -OutFile "$projectDir\scripts\evening.ps1"
    Invoke-WebRequest -Uri "$baseUrl/sunday-template.ps1" -OutFile "$projectDir\scripts\sunday.ps1"
    Invoke-WebRequest -Uri "$baseUrl/command-context-template.md" -OutFile "$projectDir\scripts\command-context.md"
} else {
    Copy-Item "$templateSource\morning-template.ps1" "$projectDir\scripts\morning.ps1"
    Copy-Item "$templateSource\evening-template.ps1" "$projectDir\scripts\evening.ps1"
    Copy-Item "$templateSource\sunday-template.ps1" "$projectDir\scripts\sunday.ps1"
    Copy-Item "$templateSource\command-context-template.md" "$projectDir\scripts\command-context.md"
}

# --- Fill command-context.md ---
Write-Host "Writing command-context.md..."

$contextFile = "$projectDir\scripts\command-context.md"
$content = Get-Content $contextFile -Raw

# Replace birth data placeholders
$content = $content -replace '\[Your date — e\.g\., March 15, 1985\]', $birthDate
$content = $content -replace '\[Your time — e\.g\., 2:30 PM EST, or "unknown"\]', $birthTime
$content = $content -replace '\[Your city, state/country\]', $birthLocation

# Replace practice context section
$practiceSection = @"

## Active Practice Context

$practiceDesc

[Update this section periodically — monthly or when major threads shift. The commands that read this file depend on it being accurate.]
"@

$content = $content -replace '(?s)## Active Practice Context.*', $practiceSection.Trim()

# Replace practitioner name reference
$content = $content -replace "Use the practitioner's name", "Use $practitionerName's name"

Set-Content $contextFile -Value $content -NoNewline

# --- Write learnings files ---
Write-Host "Creating learnings files..."

$today = Get-Date -Format "yyyy-MM-dd"

if (-not (Test-Path "$projectDir\learnings\conversation-log.md")) {
    @"
# Conversation Log

Newest entries at top.

---

## Session 0 — Setup ($today)

### What Happened
- Set up the depth practice project directory and command pipeline.
- Birth data: $birthDate, $birthTime, $birthLocation

### What's Next
- Run ``morning`` after logging a tarot pull or journal entry in the app.
"@ | Set-Content "$projectDir\learnings\conversation-log.md"
}

if (-not (Test-Path "$projectDir\learnings\decisions.md")) {
    @"
# Decisions

Newest at top. Format: **Decision** — Rationale.

---

**Set up depth practice command pipeline ($today)** — Three daily commands (morning, evening, sunday) read entries from the Hermeer app, interpret them with full natal chart and transit context, and track patterns over time.
"@ | Set-Content "$projectDir\learnings\decisions.md"
}

if (-not (Test-Path "$projectDir\learnings\weekly-reflections.md")) {
    @"
# Weekly Reflections

Written by the sunday command. Newest at top.

---
"@ | Set-Content "$projectDir\learnings\weekly-reflections.md"
}

# --- Write CLAUDE.md ---
Write-Host "Writing CLAUDE.md..."

if (-not (Test-Path "$projectDir\CLAUDE.md")) {
    $projectName = Split-Path $projectDir -Leaf
    @"
# Depth Practice

## Current Status
- **Session:** 0 (setup)
- **Active:** Setting up practice infrastructure
- **Next:** First morning briefing after logging entries in the app

## About the Practitioner

**Name:** $practitionerName
**Birth Date:** $birthDate | **Time:** $birthTime | **Location:** $birthLocation

## Commands

- ``morning`` — Morning briefing. Reads all new entries, interprets them, writes field reading.
- ``evening`` — Evening pull interpretation. Completes the day's arc.
- ``sunday`` — Weekly field reading. Panoramic review of the week's cards, transits, dreams.

## File Map

``````
$projectName/
+-- CLAUDE.md                    # Project reference
+-- scripts/
|   +-- command-context.md       # Shared config — birth data, rules, procedures
|   +-- morning.ps1              # Morning briefing command
|   +-- evening.ps1              # Evening briefing command
|   +-- sunday.ps1               # Weekly field reading command
+-- learnings/
|   +-- conversation-log.md      # Session journal
|   +-- decisions.md             # Decisions + rationale
|   +-- weekly-reflections.md    # Sunday reflections
+-- logs/
    +-- briefings/               # Saved briefing output
    +-- transit-watch-today.md   # Transit report (if transit watcher installed)
``````
"@ | Set-Content "$projectDir\CLAUDE.md"
}

# --- Set up PowerShell functions ---
Write-Host ""
Write-Host "Setting up PowerShell commands..."

# Create or update PowerShell profile
$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
}

$functionBlock = @"

# Depth practice commands
`$env:DEPTH_PROJECT = "$projectDir"
function morning { powershell -ExecutionPolicy Bypass -File "`$env:DEPTH_PROJECT\scripts\morning.ps1" }
function evening { powershell -ExecutionPolicy Bypass -File "`$env:DEPTH_PROJECT\scripts\evening.ps1" }
function sunday { powershell -ExecutionPolicy Bypass -File "`$env:DEPTH_PROJECT\scripts\sunday.ps1" }
"@

# Check if functions already exist in profile
if (Test-Path $PROFILE) {
    $profileContent = Get-Content $PROFILE -Raw
    if ($profileContent -match "# Depth practice commands") {
        Write-Host "Commands already exist in PowerShell profile — skipping."
    } else {
        Add-Content $PROFILE -Value $functionBlock
        Write-Host "Added commands to PowerShell profile at $PROFILE"
    }
} else {
    Set-Content $PROFILE -Value $functionBlock
    Write-Host "Created PowerShell profile at $PROFILE with commands"
}

# --- Done ---
Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Project created at: $projectDir"
Write-Host ""
Write-Host "Getting Started:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. Open the Hermeer app and log a tarot pull or journal entry."
Write-Host ""
Write-Host "  2. Close and reopen PowerShell (so the new commands are available),"
Write-Host "     then run your first morning briefing:"
Write-Host "       morning" -ForegroundColor Yellow
Write-Host ""
Write-Host "  3. The morning command will:"
Write-Host "     - Read your entries from the app"
Write-Host "     - Interpret them using your natal chart and active transits"
Write-Host "     - Write a field reading (atmospheric prose about the day's psychic weather)"
Write-Host "     - Flag threads that need a live session"
Write-Host "     - Save the briefing to logs\briefings\"
Write-Host ""
Write-Host "  4. In the evening after your evening pull, run:"
Write-Host "       evening" -ForegroundColor Yellow
Write-Host ""
Write-Host "  5. On Sunday evenings, run the weekly panoramic reading:"
Write-Host "       sunday" -ForegroundColor Yellow
Write-Host ""
Write-Host "  6. To customize the practice voice, interpretation style, or add natal"
Write-Host "     chart placements, edit: $projectDir\scripts\command-context.md"
Write-Host ""
Write-Host "  Prerequisites:"
Write-Host "     - Claude Code CLI (claude) installed and authenticated"
Write-Host "     - Hermeer app syncing to iCloud, OneDrive, or another cloud folder"
Write-Host "     - Optional: pyswisseph for precise transit tracking"
Write-Host ""
