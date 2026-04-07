# midday — optional midday check-in
# Catches entries logged since morning, interprets them, responds to notes. Lighter touch.

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

$today = Get-Date -Format "yyyy-MM-dd"

claude -p `
  --add-dir "$HermeerBase" `
  --allowedTools "Read,Write,Edit,Glob,Grep" `
  --effort high `
  --model opus `
  "Midday check-in. Do these steps:

0. SHARED CONTEXT: Read $DepthProject\scripts\command-context.md first.

1. READ THE FIELD:
   - Read HermeerSync/state/current-state.md (at $HermeerBase\state\current-state.md)
   - Read the morning briefing at $BriefingDir\$today-morning.md if it exists. Build on the morning's observations.

2. FIND NEW ENTRIES:
   - Check all entry directories for files starting with today's date.
   - Compare against what the morning briefing already interpreted (listed in its Operations section). Focus on entries logged SINCE the morning command ran.

3. INTERPRET:
   - For any new entry WITHOUT an existing interpretation in $HermeerBase\depth\: interpret it fully per command-context.md.

4. PROCESS REQUESTS:
   - INTERPRETATION REQUESTS: Per command-context.md. Check $HermeerBase\requests\ for pending requests.

5. FIELD READING: Write a midday field reading to $HermeerBase\depth\field\$today-midday.md with reading_type: midday. Only if new entries were found since morning.

6. RESPOND TO NOTES:
   - THREAD NOTE RESPONSES: Per command-context.md.
   - MOON NOTE RESPONSES: Per command-context.md.
   - INTERPRETATION NOTE RESPONSES: Per command-context.md.

7. BRIEFING:
   Give the practitioner a brief midday update: what's new since morning, any new interpretations, what the midday field looks like. Keep it concise — this is a check-in, not a full reading. Use the practitioner's name from command-context.md — never 'user.'

8. SAVE THE BRIEFING:
   Write to TWO locations:
   a. $BriefingDir\$today-midday.md (local archive)
   b. $AppBriefingDir\$today-midday.md (app-visible — appears in Hermeer)
   Both files must have this frontmatter:
---
type: briefing
command: midday
date: $today
generated: `"[ISO timestamp]`"
provider: `"depth-companion`"
---
   Include the ## Operations section per command-context.md.

Midday is the lightest touch. Only what's new. If nothing happened since morning, say so briefly and move on."
