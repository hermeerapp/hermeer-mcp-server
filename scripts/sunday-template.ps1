# sunday — weekly field reading
# Drafts the weekly reflection: cards, interference, transits, projection. Zero approvals.

$DepthProject = if ($env:DEPTH_PROJECT) { $env:DEPTH_PROJECT } else { "$HOME\depth-practice" }
$HermeerBase = if ($env:HERMEER_BASE) { $env:HERMEER_BASE } else {
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

# Run transit watcher if it exists
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
  "Sunday evening weekly field reading. Do these steps:

0. SHARED CONTEXT: Read $DepthProject\scripts\command-context.md first — it contains birth data, rules, and common procedures that apply to all commands. Follow everything in that file.
1. Read HermeerSync/state/current-state.md (at $HermeerBase\state\current-state.md)
2. Read ALL entries from the past 7 days — every tarot pull, dream, journal entry, session, and synchronicity in $HermeerBase\tarot\, dreams\, journal\, sessions\, synchronicities\
3. Read any existing interpretations for this week's entries from $HermeerBase\depth\
4. Read the previous weekly reflection(s) from $DepthProject\learnings\weekly-reflections.md if it exists — know the format and the arc
5. Read today's transit watch if it exists: $DepthProject\logs\transit-watch-today.md
6. Draft the weekly field reading in this structure:

   **The Cards**
   The week's pull sequence. Major/Minor count. Reversal rate. Absent suits. Recurring cards. The arc — what story do the cards tell across the week?

   **The Interference**
   Where did card material cross waking life? Where did dreams echo daytime events? Where did transits manifest in actual experience? This is the synchronicity section.

   **The Transits**
   What planetary pressures shaped the week? Connect to the natal chart and to what actually happened.

   **Infrastructure**
   Any sync gaps noticed this week. Operational anomalies from daily briefings. Keep it brief — one paragraph or a short list.

   **Looking Ahead**
   1-2 sentences reading the field forward. Not prediction — projection. What wants to happen next week based on what's in motion?

7. Write the reflection to $DepthProject\learnings\weekly-reflections.md (append with ## header for the week)
8. Interpret any uninterpreted entries from the past 7 days while you're here.
9. THREAD FRESHNESS CHECK: Per command-context.md. Scan all thread files, compare practice narrative against actual counts, regenerate stale threads.
10. THREAD NOTE RESPONSES: Per command-context.md.
11. WEEKLY SYNTHESIS: Per command-context.md. Write the depth-level synthesis for the closing week (Monday through today).
12. WEEKLY FORECAST: Per command-context.md. Write the depth-level forecast for the coming week (tomorrow's Monday through next Sunday). Use the transit watcher data for real planetary positions.
13. Present the field reading to the practitioner. Use their name from command-context.md — never 'user.'
14. SAVE THE BRIEFING: Write the full field reading to $BriefingDir\$today-sunday.md. Frontmatter:
---
date: $today
command: sunday
tags: [briefing, weekly]
---
Include the ## Operations section per command-context.md. Add: weekly reflection written, threads refreshed, synthesis/forecast written.

The weekly reading is panoramic — the widest lens in the practice. See the whole field. Name the interference patterns. Be bold in the projection."
