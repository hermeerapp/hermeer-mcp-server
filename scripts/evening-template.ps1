# evening — evening pull interpretation
# Reads tonight's pull, interprets it, writes interpretation. Zero approvals.

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

# Update transit watch for evening positions if transit watcher exists
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
  "Evening pull interpretation. Do these steps:

0. SHARED CONTEXT: Read $DepthProject\scripts\command-context.md first — it contains birth data, rules, and common procedures that apply to all commands. Follow everything in that file.
0b. Read the morning briefing at $BriefingDir\$today-morning.md if it exists. You hold the full day now. Build on its work — the evening reading should complete the arc, not start over.
1. Read HermeerSync/state/current-state.md (at $HermeerBase\state\current-state.md)
1b. Read the transit watch report at $DepthProject\logs\transit-watch-today.md if it exists — precise ephemeris-calculated transit data.
2. Find ALL of today's entries — check $HermeerBase\tarot\, $HermeerBase\dreams\, $HermeerBase\journal\, $HermeerBase\sessions\, and $HermeerBase\synchronicities\ for files starting with today's date. Read every entry file from today.
2b. Run the iCloud Sync Check per command-context.md.
3. Identify the evening pull — the evening tarot entry (if there are multiple tarot pulls, it's the later one)
4. Check which entries already have interpretations in $HermeerBase\depth\
5. For any entry from today WITHOUT an existing interpretation: interpret it fully per command-context.md. This includes journal entries, dreams, session reflections, synchronicities — not just the evening pull.
6. CATCH-UP: 3-day window per command-context.md.
7. INTERPRETATION REQUESTS: Per command-context.md.
8. FIELD READING: Per command-context.md (skip if already exists for today).
8b. THREAD NOTE RESPONSES: Per command-context.md.
8c. MOON NOTE RESPONSES: Per command-context.md.
9. Interpret the evening pull specifically as the evening card — what came through at the threshold of sleep. Connect to:
   - The morning pull (the day's arc from morning card to evening card)
   - Active transits, the natal chart
   - Recent cards and ongoing threads
   - Everything else logged today — the day is one field; the evening pull is its closing statement
10. Give the practitioner the evening reading: the interpretation(s), the day's arc, what wants to be carried into sleep, what the card might be seeding for dreams. Mention any catch-up interpretations written. Use the practitioner's name from command-context.md — never 'user.'
11. SAVE THE BRIEFING: Write the full evening reading to $BriefingDir\$today-evening.md. Frontmatter:
---
date: $today
command: evening
tags: [briefing, daily]
---
This completes the day's briefing arc.
Include the ## Operations section per command-context.md.

The evening pull is liminal — the threshold between day and night, conscious and unconscious. Treat it that way."
