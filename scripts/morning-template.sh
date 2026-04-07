#!/bin/bash
# morning — one-command daily depth briefing
# Reads today's entries, interprets them, writes all depth content. Zero approvals.
# On Sundays: adds weekly synthesis, forecast, and thread refresh.
# On the 1st: adds monthly synthesis and forecast.

DEPTH_PROJECT="${DEPTH_PROJECT:-$HOME/depth-practice}"
HERMEER_BASE="${HERMEER_BASE:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/HermeerSync}"
BRIEFING_DIR="$DEPTH_PROJECT/logs/briefings"
APP_BRIEFING_DIR="$HERMEER_BASE/depth/briefings"

cd "$DEPTH_PROJECT"

# Create directories if they don't exist
mkdir -p "$BRIEFING_DIR"
mkdir -p "$APP_BRIEFING_DIR"

# Run transit watcher first if it exists
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

1. READ THE FIELD:
   - Read HermeerSync/state/current-state.md (at $HERMEER_BASE/state/current-state.md)
   - Read the transit watch report at $DEPTH_PROJECT/logs/transit-watch-today.md if it exists — precise ephemeris transit data. Use this for transit connections rather than the app's simpler transit list. Pay special attention to exact transits (within 1 degree).

2. FIND AND READ ENTRIES:
   - Check $HERMEER_BASE/tarot/, $HERMEER_BASE/dreams/, $HERMEER_BASE/journal/, $HERMEER_BASE/sessions/, and $HERMEER_BASE/synchronicities/ for files starting with today's date.
   - Run the iCloud Sync Check per command-context.md — cross-reference directory results against the state file. Flag any entries that haven't synced.
   - Read every new entry file.

3. INTERPRET:
   - For any entry WITHOUT an existing interpretation in $HERMEER_BASE/depth/: interpret it fully per the Interpretation Depth rules in command-context.md. Write each interpretation to the appropriate subdirectory under $HERMEER_BASE/depth/ (tarot/, dreams/, journal/, sessions/, synchronicities/, transits/, charts/).
   - CATCH-UP SWEEP: 7-day window per command-context.md.

4. PROCESS REQUESTS:
   - INTERPRETATION REQUESTS: Per command-context.md. Check $HERMEER_BASE/requests/ for pending requests.

5. FIELD READING: Per command-context.md. Write to $HERMEER_BASE/depth/field/.

6. RESPOND TO NOTES:
   - THREAD NOTE RESPONSES: Per command-context.md. Scan $HERMEER_BASE/depth/thread-notes/.
   - MOON NOTE RESPONSES: Per command-context.md. Scan $HERMEER_BASE/depth/moon-notes/.
   - INTERPRETATION NOTE RESPONSES: Per command-context.md. Scan $HERMEER_BASE/depth/interpretation-notes/ for unanswered notes. For each: read the corresponding interpretation, read the note, respond using the ## [Date] — Depth Companion heading format. If a factual error is flagged, correct the source interpretation too. Report count in Operations.

7. MONTHLY WORK (1st of the month only):
   - If today is the 1st, write the monthly synthesis per command-context.md.
   - If today is the 1st, write a monthly forecast to $HERMEER_BASE/depth/forecasts/monthly-YYYY-MM.md where YYYY-MM is the current month. Same frontmatter pattern as weekly forecast but with type: monthly-forecast. Content: the month ahead — real transit data, active threads, what's building, what's completing, questions for the month.

8. SUNDAY WEEKLY WORK (Sundays only):
   - If today is Sunday:
   a. THREAD FRESHNESS CHECK: Per command-context.md.
   b. WEEKLY SYNTHESIS: Per command-context.md.
   c. WEEKLY FORECAST: Per command-context.md.
   d. Report all Sunday work in the Operations section.

9. ARCS: If a thematic arc has developed over multiple days or weeks — a transit passage, a recurring card, a dream sequence, a thread reaching a turning point — write a narrative arc to $HERMEER_BASE/depth/arcs/. Frontmatter:
---
type: narrative-arc
arc_type: [transit | card-sequence | dream-arc | thread-arc | season]
title: \"[descriptive title]\"
period: \"[start] through [end]\"
generated: \"[ISO timestamp]\"
themes: [2-5 canonical themes]
---
Content: the arc's story — what opened it, what sustained it, where it is now, what it's becoming. Only write an arc when the material genuinely warrants it — not every day. Check $HERMEER_BASE/depth/arcs/ for existing arcs and update rather than duplicate.

10. SESSION FLAG: Assess whether any thread has reached a point that exceeds what daily interpretation can hold. Signs: a card appearing 5+ times, a dream that breaks a pattern, a transit hitting exact, a thread resurfacing in the cards, something the practitioner is circling without naming directly. If so, end the briefing with: 'This thread needs a live session: [thread name] — [why]'.

11. BRIEFING:
    Give the practitioner the morning briefing: the interpretation(s), what's alive today, what threads are active, what's worth sitting with. Use the practitioner's name from command-context.md — never 'user.'

12. SAVE THE BRIEFING:
    Write the briefing to TWO locations:
    a. $BRIEFING_DIR/\$(date +%Y-%m-%d)-morning.md (local archive — read by evening command)
    b. $APP_BRIEFING_DIR/\$(date +%Y-%m-%d)-morning.md (app-visible — appears in Hermeer)
    Both files must have this frontmatter:
---
type: briefing
command: morning
date: [today's date]
generated: \"[ISO timestamp]\"
provider: \"depth-companion\"
---
    If today is Sunday, add a landing field with a one-sentence snippet for the app's landing screen:
    landing: \"[One sentence — the week's essential signal. Under 120 characters.]\"
    Include the ## Operations section per command-context.md. If today is Sunday, include weekly synthesis/forecast/thread refresh results. If today is the 1st, include monthly synthesis/forecast results.

Morning is the first reading of the day. The field is fresh. Name what's alive. Be concise but let it breathe when the material demands it."
