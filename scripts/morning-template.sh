#!/bin/bash
# morning — one-command daily depth briefing
# Reads today's entries, interprets them, writes interpretations. Zero approvals.

DEPTH_PROJECT="${DEPTH_PROJECT:-$HOME/depth-practice}"
HERMEER_BASE="${HERMEER_BASE:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/HermeerSync}"
BRIEFING_DIR="$DEPTH_PROJECT/logs/briefings"

cd "$DEPTH_PROJECT"

# Create briefing directory if it doesn't exist
mkdir -p "$BRIEFING_DIR"

# Run transit watcher first if it exists — generates logs/transit-watch-today.md
if [ -f "$DEPTH_PROJECT/scripts/transit_watcher.py" ]; then
  python3 "$DEPTH_PROJECT/scripts/transit_watcher.py" 2>/dev/null
fi

claude -p \
  --add-dir "$HERMEER_BASE" \
  --allowedTools "Read,Write,Edit,Glob,Grep" \
  --effort high \
  --model opus \
  "Morning briefing. Do these steps:

0. SHARED CONTEXT: Read $DEPTH_PROJECT/scripts/command-context.md first — it contains birth data, rules, and common procedures that apply to all commands. Follow everything in that file.
1. Read HermeerSync/state/current-state.md (at $HERMEER_BASE/state/current-state.md)
1b. Read the transit watch report at $DEPTH_PROJECT/logs/transit-watch-today.md if it exists — this has precise current transit data calculated from a real ephemeris. Use this for transit connections in interpretations rather than the app's simpler transit list. Pay special attention to exact transits (within 1 degree) and any day-over-day changes.
2. Find today's entries — check $HERMEER_BASE/tarot/, $HERMEER_BASE/dreams/, $HERMEER_BASE/journal/, $HERMEER_BASE/sessions/, and $HERMEER_BASE/synchronicities/ for files starting with today's date
2b. Run the iCloud Sync Check per command-context.md — cross-reference directory results against the state file's 'Last 7 Days' section. Flag any entries the state file shows that haven't synced.
3. Read every new entry file
4. For any entry WITHOUT an existing interpretation in $HERMEER_BASE/depth/: interpret it fully per the Interpretation Depth rules in command-context.md. Write each interpretation to the appropriate subdirectory under $HERMEER_BASE/depth/ (tarot/, dreams/, journal/, sessions/, synchronicities/).
5. CATCH-UP SWEEP: 7-day window per command-context.md.
6. INTERPRETATION REQUESTS: Per command-context.md.
7. FIELD READING: Per command-context.md.
7b. THREAD NOTE RESPONSES: Per command-context.md.
7c. MOON NOTE RESPONSES: Per command-context.md.
7d. MONTHLY SYNTHESIS: If today is the 1st of the month, write the monthly synthesis per command-context.md.
8. Give the practitioner the morning briefing: the interpretation(s), what's alive today, what threads are active, what's worth sitting with. Use the practitioner's name from command-context.md — never 'user.'
9. SUNDAY WEEKLY WORK: Check what day of the week it is. If today is Sunday, also do these steps:
   a. THREAD FRESHNESS CHECK: Per command-context.md. Scan all thread files, compare practice narrative against actual counts, regenerate stale threads.
   b. WEEKLY SYNTHESIS: Per command-context.md. Write the depth-level synthesis for the closing week (Monday through today).
   c. WEEKLY FORECAST: Per command-context.md. Write the depth-level forecast for the coming week (tomorrow's Monday through next Sunday). Use the transit watcher data for real planetary positions.
   d. Report all Sunday work in the Operations section.
10. SESSION FLAG: After the briefing, assess whether any thread has reached a point that exceeds what daily interpretation can hold. Signs: a card appearing 5+ times, a dream that breaks a pattern, a transit hitting exact, a thread resurfacing in the cards, something the practitioner is circling without naming directly. If so, end the briefing with: 'This thread needs a live session: [thread name] — [why]'.
11. SAVE THE BRIEFING: Write the full briefing text to $BRIEFING_DIR/\$(date +%Y-%m-%d)-morning.md. Frontmatter:
---
date: [today]
command: morning
tags: [briefing, daily]
---
This file will be read by the evening command so it can build on what you observed. Write it the same way you'd speak it — this is the morning's reading of the field.
Include the ## Operations section per command-context.md. If today is Sunday, include the weekly synthesis/forecast/thread refresh results.

Morning is the first reading of the day. The field is fresh. Name what's alive. Be concise but let it breathe when the material demands it."
