# morning — one-command daily depth briefing
# Reads today's entries, interprets them, writes interpretations. Zero approvals.

$DepthProject = if ($env:DEPTH_PROJECT) { $env:DEPTH_PROJECT } else { "$HOME\depth-practice" }
$HermeerBase = if ($env:HERMEER_BASE) { $env:HERMEER_BASE } else {
    # Try common Windows sync locations in order
    $icloud = "$env:USERPROFILE\iCloudDrive\HermeerSync"
    $onedrive = "$env:USERPROFILE\OneDrive\HermeerSync"
    $googledrive = "G:\My Drive\HermeerSync"
    if (Test-Path $icloud) { $icloud }
    elseif (Test-Path $onedrive) { $onedrive }
    elseif (Test-Path $googledrive) { $googledrive }
    else { "$env:USERPROFILE\HermeerSync" }
}
$BriefingDir = "$DepthProject\logs\briefings"

Set-Location $DepthProject

# Create briefing directory if it doesn't exist
New-Item -ItemType Directory -Force -Path $BriefingDir | Out-Null

# Run transit watcher first if it exists
$transitWatcher = "$DepthProject\scripts\transit_watcher.py"
if (Test-Path $transitWatcher) {
    python3 $transitWatcher 2>$null
}

$today = Get-Date -Format "yyyy-MM-dd"

claude -p `
  --add-dir "$HermeerBase" `
  --allowedTools "Read,Write,Edit,Glob,Grep" `
  --effort high `
  --model opus `
  "Morning briefing. Do these steps:

0. SHARED CONTEXT: Read $DepthProject\scripts\command-context.md first — it contains birth data, rules, and common procedures that apply to all commands. Follow everything in that file.
1. Read HermeerSync/state/current-state.md (at $HermeerBase\state\current-state.md)
1b. Read the transit watch report at $DepthProject\logs\transit-watch-today.md if it exists — this has precise current transit data calculated from a real ephemeris. Use this for transit connections in interpretations rather than the app's simpler transit list. Pay special attention to exact transits (within 1 degree) and any day-over-day changes.
2. Find today's entries — check $HermeerBase\tarot\, $HermeerBase\dreams\, $HermeerBase\journal\, $HermeerBase\sessions\, and $HermeerBase\synchronicities\ for files starting with today's date
2b. Run the iCloud Sync Check per command-context.md — cross-reference directory results against the state file's 'Last 7 Days' section. Flag any entries the state file shows that haven't synced.
3. Read every new entry file
4. For any entry WITHOUT an existing interpretation in $HermeerBase\depth\: interpret it fully per the Interpretation Depth rules in command-context.md. Write each interpretation to the appropriate subdirectory under $HermeerBase\depth\ (tarot\, dreams\, journal\, sessions\, synchronicities\).
5. CATCH-UP SWEEP: 7-day window per command-context.md.
6. INTERPRETATION REQUESTS: Per command-context.md.
7. FIELD READING: Per command-context.md.
7b. THREAD NOTE RESPONSES: Per command-context.md.
7c. MOON NOTE RESPONSES: Per command-context.md.
7d. MONTHLY SYNTHESIS: If today is the 1st of the month, write the monthly synthesis per command-context.md.
8. Give the practitioner the morning briefing: the interpretation(s), what's alive today, what threads are active, what's worth sitting with. Use the practitioner's name from command-context.md — never 'user.'
9. SESSION FLAG: After the briefing, assess whether any thread has reached a point that exceeds what daily interpretation can hold. Signs: a card appearing 5+ times, a dream that breaks a pattern, a transit hitting exact, a thread resurfacing in the cards, something the practitioner is circling without naming directly. If so, end the briefing with: 'This thread needs a live session: [thread name] — [why]'.
10. SAVE THE BRIEFING: Write the full briefing text to $BriefingDir\$today-morning.md. Frontmatter:
---
date: $today
command: morning
tags: [briefing, daily]
---
This file will be read by the evening command so it can build on what you observed. Write it the same way you'd speak it — this is the morning's reading of the field.
Include the ## Operations section per command-context.md.

Morning is the first reading of the day. The field is fresh. Name what's alive. Be concise but let it breathe when the material demands it."
