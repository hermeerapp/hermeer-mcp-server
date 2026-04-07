# morning — one-command daily depth briefing
# Reads today's entries, interprets them, writes all depth content. Zero approvals.
# On Sundays: adds weekly synthesis, forecast, and thread refresh.
# On the 1st: adds monthly synthesis and forecast.

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
  "Morning briefing. Do these steps:

0. SHARED CONTEXT: Read $DepthProject\scripts\command-context.md first — it contains birth data, rules, and common procedures that apply to all commands. Follow everything in that file.

1. READ THE FIELD:
   - Read HermeerSync/state/current-state.md (at $HermeerBase\state\current-state.md)
   - Read the transit watch report at $DepthProject\logs\transit-watch-today.md if it exists — precise ephemeris transit data. Use this for transit connections rather than the app's simpler transit list. Pay special attention to exact transits (within 1 degree).

2. FIND AND READ ENTRIES:
   - Check $HermeerBase\tarot\, $HermeerBase\dreams\, $HermeerBase\journal\, $HermeerBase\sessions\, and $HermeerBase\synchronicities\ for files starting with today's date.
   - Run the iCloud Sync Check per command-context.md — cross-reference directory results against the state file. Flag any entries that haven't synced.
   - Read every new entry file.

3. INTERPRET:
   - For any entry WITHOUT an existing interpretation in $HermeerBase\depth\: interpret it fully per the Interpretation Depth rules in command-context.md. Write each interpretation to the appropriate subdirectory under $HermeerBase\depth\ (tarot\, dreams\, journal\, sessions\, synchronicities\, transits\, charts\).
   - CATCH-UP SWEEP: 7-day window per command-context.md.

4. PROCESS REQUESTS:
   - INTERPRETATION REQUESTS: Per command-context.md. Check $HermeerBase\requests\ for pending requests.

5. FIELD READING: Per command-context.md. Write to $HermeerBase\depth\field\.

6. RESPOND TO NOTES:
   - THREAD NOTE RESPONSES: Per command-context.md. Scan $HermeerBase\depth\thread-notes\.
   - MOON NOTE RESPONSES: Per command-context.md. Scan $HermeerBase\depth\moon-notes\.
   - INTERPRETATION NOTE RESPONSES: Per command-context.md. Scan $HermeerBase\depth\interpretation-notes\ for unanswered notes. For each: read the corresponding interpretation, read the note, respond using the ## [Date] — Depth Companion heading format. If a factual error is flagged, correct the source interpretation too. Report count in Operations.

7. MONTHLY WORK (1st of the month only):
   - If today is the 1st, write the monthly synthesis per command-context.md.
   - If today is the 1st, write a monthly forecast to $HermeerBase\depth\forecasts\monthly-YYYY-MM.md where YYYY-MM is the current month. Same frontmatter pattern as weekly forecast but with type: monthly-forecast. Content: the month ahead — real transit data, active threads, what's building, what's completing, questions for the month.

8. SUNDAY WEEKLY WORK (Sundays only):
   - If today is Sunday:
   a. THREAD FRESHNESS CHECK: Per command-context.md.
   b. WEEKLY SYNTHESIS: Per command-context.md.
   c. WEEKLY FORECAST: Per command-context.md.
   d. Report all Sunday work in the Operations section.

9. ARCS: If a thematic arc has developed over multiple days or weeks — a transit passage, a recurring card, a dream sequence, a thread reaching a turning point — write a narrative arc to $HermeerBase\depth\arcs\. Frontmatter:
---
type: narrative-arc
arc_type: [transit | card-sequence | dream-arc | thread-arc | season]
title: `"[descriptive title]`"
period: `"[start] through [end]`"
generated: `"[ISO timestamp]`"
themes: [2-5 canonical themes]
---
Content: the arc's story — what opened it, what sustained it, where it is now, what it's becoming. Only write an arc when the material genuinely warrants it — not every day. Check $HermeerBase\depth\arcs\ for existing arcs and update rather than duplicate.

10. SESSION FLAG: Assess whether any thread has reached a point that exceeds what daily interpretation can hold. Signs: a card appearing 5+ times, a dream that breaks a pattern, a transit hitting exact, a thread resurfacing in the cards, something the practitioner is circling without naming directly. If so, end the briefing with: 'This thread needs a live session: [thread name] — [why]'.

11. BRIEFING:
    Give the practitioner the morning briefing: the interpretation(s), what's alive today, what threads are active, what's worth sitting with. Use the practitioner's name from command-context.md — never 'user.'

12. SAVE THE BRIEFING:
    Write the briefing to TWO locations:
    a. $BriefingDir\$today-morning.md (local archive — read by evening command)
    b. $AppBriefingDir\$today-morning.md (app-visible — appears in Hermeer)
    Both files must have this frontmatter:
---
type: briefing
command: morning
date: $today
generated: `"[ISO timestamp]`"
provider: `"depth-companion`"
---
    If today is Sunday, add a landing field with a one-sentence snippet for the app's landing screen:
    landing: `"[One sentence — the week's essential signal. Under 120 characters.]`"
    Include the ## Operations section per command-context.md. If today is Sunday, include weekly synthesis/forecast/thread refresh results. If today is the 1st, include monthly synthesis/forecast results.

Morning is the first reading of the day. The field is fresh. Name what's alive. Be concise but let it breathe when the material demands it."
