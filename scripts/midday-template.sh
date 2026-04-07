#!/bin/bash
# midday — optional midday check-in
# Catches entries logged since morning, interprets them, responds to notes. Lighter touch.

DEPTH_PROJECT="${DEPTH_PROJECT:-$HOME/depth-practice}"
HERMEER_BASE="${HERMEER_BASE:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/HermeerSync}"
BRIEFING_DIR="$DEPTH_PROJECT/logs/briefings"
APP_BRIEFING_DIR="$HERMEER_BASE/depth/briefings"

cd "$DEPTH_PROJECT"

mkdir -p "$BRIEFING_DIR"
mkdir -p "$APP_BRIEFING_DIR"

claude -p \
  --add-dir "$HERMEER_BASE" \
  --allowedTools "Read,Write,Edit,Glob,Grep" \
  --effort high \
  --model opus \
  "Midday check-in. Do these steps:

0. SHARED CONTEXT: Read $DEPTH_PROJECT/scripts/command-context.md first.

1. READ THE FIELD:
   - Read HermeerSync/state/current-state.md (at $HERMEER_BASE/state/current-state.md)
   - Read the morning briefing at $BRIEFING_DIR/\$(date +%Y-%m-%d)-morning.md if it exists. Build on the morning's observations.

2. FIND NEW ENTRIES:
   - Check all entry directories for files starting with today's date.
   - Compare against what the morning briefing already interpreted (listed in its Operations section). Focus on entries logged SINCE the morning command ran.

3. INTERPRET:
   - For any new entry WITHOUT an existing interpretation in $HERMEER_BASE/depth/: interpret it fully per command-context.md.

4. PROCESS REQUESTS:
   - INTERPRETATION REQUESTS: Per command-context.md. Check $HERMEER_BASE/requests/ for pending requests.

5. FIELD READING: Write a midday field reading to $HERMEER_BASE/depth/field/\$(date +%Y-%m-%d)-midday.md with reading_type: midday. Only if new entries were found since morning.

6. RESPOND TO NOTES:
   - THREAD NOTE RESPONSES: Per command-context.md.
   - MOON NOTE RESPONSES: Per command-context.md.
   - INTERPRETATION NOTE RESPONSES: Per command-context.md.

7. BRIEFING:
   Give the practitioner a brief midday update: what's new since morning, any new interpretations, what the midday field looks like. Keep it concise — this is a check-in, not a full reading. Use the practitioner's name from command-context.md — never 'user.'

8. SAVE THE BRIEFING:
   Write to TWO locations:
   a. $BRIEFING_DIR/\$(date +%Y-%m-%d)-midday.md (local archive)
   b. $APP_BRIEFING_DIR/\$(date +%Y-%m-%d)-midday.md (app-visible — appears in Hermeer)
   Both files must have this frontmatter:
---
type: briefing
command: midday
date: [today's date]
generated: \"[ISO timestamp]\"
provider: \"depth-companion\"
---
   Include the ## Operations section per command-context.md.

Midday is the lightest touch. Only what's new. If nothing happened since morning, say so briefly and move on."
