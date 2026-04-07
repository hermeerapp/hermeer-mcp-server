#!/bin/bash
# evening — evening pull interpretation
# Reads tonight's pull, interprets it, writes interpretation. Zero approvals.

DEPTH_PROJECT="${DEPTH_PROJECT:-$HOME/depth-practice}"
HERMEER_BASE="${HERMEER_BASE:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/HermeerSync}"
BRIEFING_DIR="$DEPTH_PROJECT/logs/briefings"

cd "$DEPTH_PROJECT"

# Create briefing directory if it doesn't exist
mkdir -p "$BRIEFING_DIR"

# Update transit watch for evening positions if transit watcher exists
if [ -f "$DEPTH_PROJECT/scripts/transit_watcher.py" ]; then
  python3 "$DEPTH_PROJECT/scripts/transit_watcher.py" 2>/dev/null
fi

claude -p \
  --add-dir "$HERMEER_BASE" \
  --allowedTools "Read,Write,Edit,Glob,Grep" \
  --effort high \
  --model opus \
  "Evening pull interpretation. Do these steps:

0. SHARED CONTEXT: Read $DEPTH_PROJECT/scripts/command-context.md first — it contains birth data, rules, and common procedures that apply to all commands. Follow everything in that file.
0b. Read the morning briefing at $BRIEFING_DIR/\$(date +%Y-%m-%d)-morning.md if it exists. You hold the full day now. Build on its work — the evening reading should complete the arc, not start over.
1. Read HermeerSync/state/current-state.md (at $HERMEER_BASE/state/current-state.md)
1b. Read the transit watch report at $DEPTH_PROJECT/logs/transit-watch-today.md if it exists — precise ephemeris-calculated transit data.
2. Find ALL of today's entries — check $HERMEER_BASE/tarot/, $HERMEER_BASE/dreams/, $HERMEER_BASE/journal/, $HERMEER_BASE/sessions/, and $HERMEER_BASE/synchronicities/ for files starting with today's date. Read every entry file from today.
2b. Run the iCloud Sync Check per command-context.md.
3. Identify the evening pull — the evening tarot entry (if there are multiple tarot pulls, it's the later one)
4. Check which entries already have interpretations in $HERMEER_BASE/depth/
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
10. SUNDAY FALLBACK: Check what day of the week it is. If today is Sunday AND no weekly synthesis exists for this week (check $HERMEER_BASE/depth/synthesis/ for a file covering this week), do the Sunday weekly work that morning missed:
   a. THREAD FRESHNESS CHECK: Per command-context.md.
   b. WEEKLY SYNTHESIS: Per command-context.md.
   c. WEEKLY FORECAST: Per command-context.md.
   d. Report all Sunday work in the Operations section.
11. Give the practitioner the evening reading: the interpretation(s), the day's arc, what wants to be carried into sleep, what the card might be seeding for dreams. Mention any catch-up interpretations written. Use the practitioner's name from command-context.md — never 'user.'
12. SAVE THE BRIEFING: Write the full evening reading to $BRIEFING_DIR/\$(date +%Y-%m-%d)-evening.md. Frontmatter:
---
date: [today]
command: evening
tags: [briefing, daily]
---
This completes the day's briefing arc.
Include the ## Operations section per command-context.md.

The evening pull is liminal — the threshold between day and night, conscious and unconscious. Treat it that way."
