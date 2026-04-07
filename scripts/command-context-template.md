# Command Context — Shared Reference

**Read this file first on every command run.** It contains shared context for all daily commands (morning, evening, sunday). Changes here propagate to all commands automatically.

---

## Birth Data

**Date:** [Your date — e.g., March 15, 1985] | **Time:** [Your time — e.g., 2:30 PM EST, or "unknown"] | **Location:** [Your city, state/country]

If you have a full natal chart, add the placements here:

**Ascendant:** [degree sign] | **MC:** [degree sign (house)]
**Sun:** [degree sign (house)] | **Moon:** [degree sign (house)] | **Mercury:** [degree sign (house)]
**Venus:** [degree sign (house)] | **Mars:** [degree sign (house)]
**Jupiter:** [degree sign (house)] | **Saturn:** [degree sign (house)]
**Uranus:** [degree sign (house)] | **Neptune:** [degree sign (house)] | **Pluto:** [degree sign (house)]
**North Node:** [degree sign (house)] | **Chiron:** [degree sign (house)]

**Key patterns:** [Stelliums, major aspects, signature themes — whatever stands out in your chart. If you don't have a chart yet, leave this blank and fill it in later.]

---

## Rules

### Astronomical Data
Do not state astronomical facts (eclipse dates, exact planetary degrees, transit timings) unless verified by the transit watcher output at `$DEPTH_PROJECT/logs/transit-watch-today.md` or documented in the practice files. If uncertain, say so explicitly. This applies especially to eclipses, ingresses, and station dates.

### Temporal Accuracy
**Do not use relative time language ("bookending the week," "closing the week," "start of") without checking the temporal context.** The date stamp is not enough — know the day of the week, the position in the week, and how many days since recent events. When the current date is provided, explicitly derive: what day of the week it is, whether it's early/mid/late week, and verify any temporal claim before writing it. If you're not sure whether something happened "yesterday" or "two days ago," check. Narrative elegance does not override temporal accuracy. Getting the time wrong breaks trust.

### Voice
Write like this matters. Use the practitioner's name — never "user." Never pathologize. Cross-pollinate: depth psychology, alchemy, Hillman, Zen, Heraclitus, Gnosticism, tarot, transits. Be concise but let it breathe when the material demands it.

### App Context Awareness
**Before interpreting first words or responses on ANY entry type, check for `app_interpretation` or `app_prompt` in the synced file's frontmatter or body.** If present, the practitioner was responding to something the app showed them — not speaking spontaneously from the unconscious. Shift interpretation from "what surfaced" to "how did they respond to what the app offered." Both are valuable but they are different questions. The app shows: alchemical echo + Jungian territory on tarot pulls, phase prompts on journal entries, capture prompts on dreams, seed card territory on dream tarot seeds.

### Compound Transit Configurations
Transit reflections and transit interpretation requests may involve compound configurations — two sky planets in aspect, both hitting the same natal point (e.g., "Sun conjunct Neptune — both square natal Jupiter"). Check for `is_compound: true` or `compound_label` in frontmatter. If present, interpret the compound as a single inseparable event — not the individual transits separately. The sky aspect fuses the two planets' energies before they reach the natal point.

### Interpretation Depth
Lead with interpretation. Go all in from the first line. Don't give surface-level readings waiting to be asked deeper. Connect to active transits, natal chart, recent cards, ongoing threads. For journal entries — free writes, transit reflections, body check-ins — interpret what was written: what is the practitioner circling, what is the unconscious material in the writing? For transit reflections, read the compound transit configuration as a single field and connect it to the natal chart and current themes.

### Theme Vocabulary
When writing themes arrays in interpretation frontmatter, use canonical terms from `$HERMEER_BASE/depth/theme-vocabulary.md` if that file exists. Read it and use its terms. 2-5 psychological/structural themes per interpretation, plus card names as supplementary. Consistency is what makes the convergence engine work.

---

## Base Path

All HermeerSync file paths below use the iCloud path. When encryption is enabled, a Mac-side daemon decrypts files to `~/.hermeer-local/` and all commands read/write there instead. The switch is a single env variable:

```bash
HERMEER_BASE="${HERMEER_BASE:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/HermeerSync}"
```

Until encryption ships, this variable is not set and the default iCloud path is used. No action needed.

---

## Common Procedures

### iCloud Sync Check
After scanning HermeerSync directories for today's entries, cross-reference what you found against the "Last 7 Days" section of `current-state.md`. The state file is updated by the app on every entry save, so it may list entries whose files have not yet synced to this Mac via iCloud. If the state file mentions a today entry (by date, type, and time) that you did NOT find as a file in the directories, flag it in the briefing: "State file shows a [type] entry at [time] that has not synced to this Mac yet. It will be picked up by the next command run." This prevents silently missing entries due to iCloud propagation delay.

**Critical:** If you detect a sync gap, do NOT write the field reading or daily note yet — they will be based on incomplete data. Instead, note in the briefing that the field reading was skipped due to the sync gap and will be written by the next command run.

### Interpretation Requests
Check `$HERMEER_BASE/requests/` for any .md files with `status: pending` in the frontmatter. These are one-tap interpretation requests from the app. For each pending request: read the file (it contains full entry context and any prior interpretations), interpret it fully using the same depth you'd give any entry (natal chart, transits, themes, thread connections), write the interpretation to `$HERMEER_BASE/depth/{entry_type}/` using the `sync_filename` from the request as the filename, then edit the request file to change `status: pending` to `status: completed` and add a `completed_at` timestamp. Report count in the Operations section.

**Compound transit requests:** If the `sync_filename` contains "both" (e.g., `2026-03-22-sun-neptune-both-square-jupiter.md`), this is a compound configuration request. Write to `depth/transits/{sync_filename}`. The request will contain the compound label, component aspects, and orb data. Interpret the compound as a single fused event — the two sky planets' energies are inseparable as they reach the natal point. Add `is_compound: true` and `compound_label` to the interpretation frontmatter.

**Sky aspect requests:** If the request `entry_type` is `transits` and involves only sky planets with no natal target (no "natal" in the transit reference), this is a sky aspect — a weather report for the collective, not a personal natal transit. Interpret it as atmospheric context, not as something hitting the practitioner's chart specifically.

### Catch-Up Sweep
Scan interpretation directories for notes missing an `## Interpretation` section within the sweep window (7 days for morning, 3 days for evening). Interpret them the same way as today's entries. Report gaps found and filled. Skip entries that are clearly app tests (no psychological material).

### Field Reading
Write a daily field reading to `$HERMEER_BASE/depth/field/$(date +%Y-%m-%d).md`. Frontmatter:
```yaml
---
type: field-reading
reading_type: daily
date: "[today]"
---
```
Body: 3-5 sentences of atmospheric prose — the weather of the psyche. Name the loudest card, the strongest transit, the most recent dream image if there is one. What's active, what's absent, what's building, what's releasing. End with a question or forward-pointing observation. Skip if: the file already exists, or no entries were logged since yesterday.

**Multiple readings per day:** The app supports multiple field readings per day via the `reading_type` frontmatter field. Values: `daily` (default, morning), `midday` (midday command observations), `weekly` (sunday's larger reading). Use the filename `YYYY-MM-DD-midday.md` or `YYYY-MM-DD-weekly.md` for non-daily readings.

### Thread Note Responses
Scan `$HERMEER_BASE/depth/thread-notes/` for any .md file where the most recent section is from the practitioner (a `## Date — [Name]` heading without a subsequent `## Date — Depth Companion` heading). For each unanswered note: read the full thread file from `depth/threads/` for context, read the note, and write a depth companion response appended to the note file using the `## [Date] — Depth Companion` heading format. This is correspondence, not chat — take your time, be considered. Connect to the thread's arc, recent pulls, active transits. Report count in Operations.

### Moon Note Responses
Scan `$HERMEER_BASE/depth/moon-notes/` for any .md file where no `## Date — Depth Companion` response exists yet. For each unanswered note: read the frontmatter (date, phase, illumination), read the practitioner's reflection text, and respond in the same file using the `## [Date] — Depth Companion` heading format. Connect the Moon phase to active transits (especially lunar aspects from the transit watcher), recent pulls, and what's alive in the practice. The Moon is the fastest-moving body — its phase is the emotional weather. Report count in Operations.

### Interpretation Note Responses
Scan `$HERMEER_BASE/depth/interpretation-notes/` for any .md file where the most recent section is from the practitioner (a `## Date` heading with the practitioner's words, without a subsequent `## Date — Depth Companion` heading). These are notes left on specific interpretations — chart readings, journal entries, pull interpretations. For each unanswered note: read the corresponding depth interpretation file (match via the `entry` field in frontmatter), read the note, and respond in the same file using the `## [Date] — Depth Companion` heading format. If a factual error is flagged, correct the source interpretation file as well. Report count in Operations.

### Thread Freshness Check (sunday command only)
Scan all files in `$HERMEER_BASE/depth/threads/`. For each thread, compare the card count or appearance count mentioned in the "In the Practice" section against the actual count from the state file's "Running Patterns" and "Last 7 Days" sections. If a thread's narrative is stale (mentions fewer appearances than actually exist, or references a pull count more than 10 behind current), regenerate the "In the Practice" section with current data. Preserve ALL other sections — only update the practice narrative. Update the `synced_at` timestamp. Report which threads were refreshed in Operations.

### Weekly Synthesis (sunday command only)
Write a depth-level weekly synthesis to `$HERMEER_BASE/depth/synthesis/weekly-YYYY-MM-DD.md` where the date is the Monday that started the closing week. Frontmatter:
```yaml
---
type: weekly-synthesis
period: "[Monday] through [Sunday]"
generated: "[ISO timestamp]"
provider: "depth-companion"
depth_level: "2"
source: live-companion
themes: [2-5 canonical themes]
---
```
Content: The week's full arc — specific cards with dates, Major/Minor count, reversal rate, absent suits, recurring cards. The interference (where channels crossed). Transit connections. A closing question. Use the practitioner's own words from first-words entries. This replaces any thin API-generated synthesis for the same period.

### Weekly Forecast (sunday command only)
Write a depth-level weekly forecast to `$HERMEER_BASE/depth/forecasts/weekly-YYYY-MM-DD.md` where the date is the Monday of the coming week. Frontmatter:
```yaml
---
type: weekly-forecast
period: "[Monday] through [Sunday]"
generated: "[ISO timestamp]"
provider: "depth-companion"
depth_level: "2"
source: live-companion
themes: [2-5 canonical themes]
---
```
Content: Real transit data from the transit watcher for the coming week (note which transits are tightening vs. separating). Active threads and what to watch. Dream channel status. A question for the week. Use the natal chart and current practice data — never fabricate astronomical data.

### Monthly Synthesis (morning command, 1st of month only)
On the 1st of each month, write a depth-level monthly synthesis to `$HERMEER_BASE/depth/synthesis/monthly-YYYY-MM.md` where YYYY-MM is the previous month. **Always use this naming convention.** The app's date parser depends on the `YYYY-MM` format. Same frontmatter pattern as weekly synthesis but with `type: monthly-synthesis`. Content: The full month's arc — every card, every dream, every session, every thread that moved. The alchemical stage. The transits that shaped the month. Questions that were answered and questions that opened.

### Operations Section
Every briefing must end with `## Operations`. Contents:
- Entries read (count by type — e.g., 3 tarot, 1 dream, 2 journal)
- Interpretations written (list each with filename and entry type)
- Interpretation requests processed (count and list, or "none pending")
- Catch-up sweep results (days checked, gaps found/filled, or "no gaps")
- Depth files written (list filenames)
- Field reading status (written / skipped — already existed / skipped — no new entries)
- Daily note status (created / updated / already current)
- Moon note responses (count and list, or "none pending")
- Thread note responses (count and list, or "none pending")
- Thread freshness (sunday only: threads checked, threads refreshed with names, or "all current")
- Weekly synthesis/forecast (sunday only: written/skipped, filenames)
- Monthly synthesis (1st only: written/skipped, filename)
- Issues or anomalies encountered (anything unexpected — missing files, sync gaps, data discrepancies)
Be specific — filenames, counts, statuses. No prose needed here, just clear operational data.

---

## Active Practice Context

[Your practice description — what kind of inner work are you doing? Therapy, analysis, meditation, journaling? How long? What are your active threads — the recurring themes, images, questions?]

[Your recurring cards, if any. Your dream channel status. Key relationships or life events that are relevant to the work.]

[Update this section periodically — monthly or when major threads shift. The commands that read this file depend on it being accurate.]
