# evening — evening pull interpretation and day-arc completion
# Reads tonight's pull, interprets it, completes the day. Zero approvals.
# Falls back on Sunday weekly work and 1st-of-month work if morning missed it.

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
$AppBriefingDir = "$HermeerBase\depth\briefings"

Set-Location $DepthProject

New-Item -ItemType Directory -Force -Path $BriefingDir | Out-Null
New-Item -ItemType Directory -Force -Path $AppBriefingDir | Out-Null

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

1. READ THE FIELD:
   - Read the morning briefing at $BriefingDir\$today-morning.md if it exists. You hold the full day now. Build on its work — the evening reading should complete the arc, not start over.
   - Read HermeerSync/state/current-state.md (at $HermeerBase\state\current-state.md)
   - Read the transit watch report at $DepthProject\logs\transit-watch-today.md if it exists.

2. FIND AND READ ENTRIES:
   - Find ALL of today's entries — check $HermeerBase\tarot\, $HermeerBase\dreams\, $HermeerBase\journal\, $HermeerBase\sessions\, and $HermeerBase\synchronicities\ for files starting with today's date. Read every entry file from today.
   - Run the iCloud Sync Check per command-context.md.

3. INTERPRET:
   - For any entry from today WITHOUT an existing interpretation: interpret it fully per command-context.md. This includes journal entries, dreams, session reflections, synchronicities — not just the evening pull.
   - CATCH-UP: 3-day window per command-context.md.

4. PROCESS REQUESTS:
   - INTERPRETATION REQUESTS: Per command-context.md. Check $HermeerBase\requests\ for pending requests.

5. FIELD READING: Per command-context.md (skip if already exists for today).

6. RESPOND TO NOTES:
   - THREAD NOTE RESPONSES: Per command-context.md. Scan $HermeerBase\depth\thread-notes\.
   - MOON NOTE RESPONSES: Per command-context.md. Scan $HermeerBase\depth\moon-notes\.
   - INTERPRETATION NOTE RESPONSES: Per command-context.md. Scan $HermeerBase\depth\interpretation-notes\ for unanswered notes. Respond using the ## [Date] — Depth Companion heading format. Report count in Operations.

7. MONTHLY FALLBACK (1st of the month only):
   - If today is the 1st AND no monthly synthesis exists for the current month in $HermeerBase\depth\synthesis\ (morning was skipped): write the monthly synthesis per command-context.md.
   - If today is the 1st AND no monthly forecast exists in $HermeerBase\depth\forecasts\: write the monthly forecast. Same format as weekly forecast but type: monthly-forecast.

8. SUNDAY FALLBACK (Sundays only):
   - If today is Sunday AND no weekly synthesis exists for this week in $HermeerBase\depth\synthesis\ (morning was skipped):
   a. THREAD FRESHNESS CHECK: Per command-context.md.
   b. WEEKLY SYNTHESIS: Per command-context.md.
   c. WEEKLY FORECAST: Per command-context.md.
   d. Report all Sunday fallback work in the Operations section.

9. EVENING PULL INTERPRETATION:
   - Identify the evening pull — the evening tarot entry (if there are multiple tarot pulls, it's the later one).
   - Interpret the evening pull specifically as the evening card — what came through at the threshold of sleep. Connect to:
     * The morning pull (the day's arc from morning card to evening card)
     * Active transits, the natal chart
     * Recent cards and ongoing threads
     * Everything else logged today — the day is one field; the evening pull is its closing statement

10. ARCS: If a thematic arc has developed or progressed today — a transit passage, a recurring card, a dream sequence, a thread reaching a turning point — write or update a narrative arc at $HermeerBase\depth\arcs\. Frontmatter:
---
type: narrative-arc
arc_type: [transit | card-sequence | dream-arc | thread-arc | season]
title: `"[descriptive title]`"
period: `"[start] through [end]`"
generated: `"[ISO timestamp]`"
themes: [2-5 canonical themes]
---
Only write an arc when the material genuinely warrants it. Check existing arcs first — update rather than duplicate.

11. BRIEFING:
    Give the practitioner the evening reading: the interpretation(s), the day's arc, what wants to be carried into sleep, what the card might be seeding for dreams. Mention any catch-up interpretations written. Use the practitioner's name from command-context.md — never 'user.'

12. SAVE THE BRIEFING:
    Write the briefing to TWO locations:
    a. $BriefingDir\$today-evening.md (local archive)
    b. $AppBriefingDir\$today-evening.md (app-visible — appears in Hermeer)
    Both files must have this frontmatter:
---
type: briefing
command: evening
date: $today
generated: `"[ISO timestamp]`"
provider: `"depth-companion`"
---
    Include the ## Operations section per command-context.md.

The evening pull is liminal — the threshold between day and night, conscious and unconscious. Treat it that way."
