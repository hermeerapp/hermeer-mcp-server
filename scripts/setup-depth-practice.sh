#!/bin/bash
# setup-depth-practice.sh — Interactive setup for the depth practice command pipeline
# Creates project structure, fills templates, sets up shell aliases.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "=== Depth Practice Setup ==="
echo ""
echo "This will create your depth practice project directory and set up"
echo "daily commands (morning, evening, sunday) that read your entries"
echo "from the Hermeer app, interpret them, and track your practice."
echo ""

# --- Project Location ---
read -p "Project directory [~/depth-practice]: " PROJECT_DIR
PROJECT_DIR="${PROJECT_DIR:-$HOME/depth-practice}"
# Expand tilde
PROJECT_DIR="${PROJECT_DIR/#\~/$HOME}"

if [ -d "$PROJECT_DIR" ]; then
  echo ""
  echo "Directory $PROJECT_DIR already exists."
  read -p "Continue and fill in any missing pieces? (y/n): " CONTINUE
  if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
    echo "Aborted."
    exit 0
  fi
fi

# --- Practitioner Name ---
echo ""
read -p "Your first name (used in briefings instead of 'user'): " PRACTITIONER_NAME
if [ -z "$PRACTITIONER_NAME" ]; then
  echo "A name is required. Exiting."
  exit 1
fi

# --- Birth Data ---
echo ""
echo "Birth data is used for natal chart interpretation and transit tracking."
echo "You can enter 'unknown' for any field and fill it in later."
echo ""
read -p "Birth date (e.g., March 15, 1985): " BIRTH_DATE
read -p "Birth time (e.g., 2:30 PM EST, or 'unknown'): " BIRTH_TIME
read -p "Birth location (e.g., Portland, Oregon): " BIRTH_LOCATION

# --- Practice Description ---
echo ""
echo "Describe your practice in a few sentences. What kind of inner work"
echo "are you doing? (therapy, analysis, meditation, journaling, etc.)"
echo "What are your active themes or questions?"
echo ""
echo "Type your description, then press Enter twice to finish:"
PRACTICE_DESC=""
EMPTY_LINES=0
while IFS= read -r line; do
  if [ -z "$line" ]; then
    EMPTY_LINES=$((EMPTY_LINES + 1))
    if [ $EMPTY_LINES -ge 1 ] && [ -n "$PRACTICE_DESC" ]; then
      break
    fi
  else
    EMPTY_LINES=0
  fi
  if [ -n "$PRACTICE_DESC" ]; then
    PRACTICE_DESC="$PRACTICE_DESC
$line"
  else
    PRACTICE_DESC="$line"
  fi
done

# --- HermeerSync Base ---
echo ""
HERMEER_DEFAULT="$HOME/Library/Mobile Documents/com~apple~CloudDocs/HermeerSync"
read -p "HermeerSync path [$HERMEER_DEFAULT]: " HERMEER_BASE
HERMEER_BASE="${HERMEER_BASE:-$HERMEER_DEFAULT}"
HERMEER_BASE="${HERMEER_BASE/#\~/$HOME}"

# --- Create Directory Structure ---
echo ""
echo "Creating project structure at $PROJECT_DIR..."

mkdir -p "$PROJECT_DIR/scripts"
mkdir -p "$PROJECT_DIR/learnings"
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/logs/briefings"

# --- Copy Command Scripts ---
echo "Copying command scripts..."

cp "$SCRIPT_DIR/morning-template.sh" "$PROJECT_DIR/scripts/morning.sh"
cp "$SCRIPT_DIR/evening-template.sh" "$PROJECT_DIR/scripts/evening.sh"
cp "$SCRIPT_DIR/sunday-template.sh" "$PROJECT_DIR/scripts/sunday.sh"

chmod +x "$PROJECT_DIR/scripts/morning.sh"
chmod +x "$PROJECT_DIR/scripts/evening.sh"
chmod +x "$PROJECT_DIR/scripts/sunday.sh"

# --- Fill command-context.md ---
echo "Writing command-context.md..."

# Start with the template
cp "$SCRIPT_DIR/command-context-template.md" "$PROJECT_DIR/scripts/command-context.md"

# Replace birth data placeholders
sed -i '' "s|\[Your date — e.g., March 15, 1985\]|${BIRTH_DATE}|g" "$PROJECT_DIR/scripts/command-context.md"
sed -i '' "s|\[Your time — e.g., 2:30 PM EST, or \"unknown\"\]|${BIRTH_TIME}|g" "$PROJECT_DIR/scripts/command-context.md"
sed -i '' "s|\[Your city, state/country\]|${BIRTH_LOCATION}|g" "$PROJECT_DIR/scripts/command-context.md"

# Replace practice context placeholder
# Use a temp file approach for multi-line replacement
PRACTICE_ESCAPED=$(echo "$PRACTICE_DESC" | sed 's/[&/\]/\\&/g')
cat > /tmp/depth-practice-context.txt << CTXEOF

## Active Practice Context

$PRACTICE_DESC

[Update this section periodically — monthly or when major threads shift. The commands that read this file depend on it being accurate.]
CTXEOF

# Find the Active Practice Context section and replace it
python3 -c "
import re
with open('$PROJECT_DIR/scripts/command-context.md', 'r') as f:
    content = f.read()
with open('/tmp/depth-practice-context.txt', 'r') as f:
    replacement = f.read()
# Replace from '## Active Practice Context' to end of file
content = re.sub(r'## Active Practice Context.*', replacement.strip(), content, flags=re.DOTALL)
with open('$PROJECT_DIR/scripts/command-context.md', 'w') as f:
    f.write(content)
"
rm /tmp/depth-practice-context.txt

# Replace 'the practitioner' with the actual name in command-context.md voice rule
sed -i '' "s|Use the practitioner's name|Use $PRACTITIONER_NAME's name|g" "$PROJECT_DIR/scripts/command-context.md"

# --- Write learnings files ---
echo "Creating learnings files..."

if [ ! -f "$PROJECT_DIR/learnings/conversation-log.md" ]; then
  cat > "$PROJECT_DIR/learnings/conversation-log.md" << EOF
# Conversation Log

Newest entries at top.

---

## Session 0 — Setup ($(date +%Y-%m-%d))

### What Happened
- Set up the depth practice project directory and command pipeline.
- Birth data: $BIRTH_DATE, $BIRTH_TIME, $BIRTH_LOCATION

### What's Next
- Run \`morning\` after logging a tarot pull or journal entry in the app.
EOF
fi

if [ ! -f "$PROJECT_DIR/learnings/decisions.md" ]; then
  cat > "$PROJECT_DIR/learnings/decisions.md" << EOF
# Decisions

Newest at top. Format: **Decision** — Rationale.

---

**Set up depth practice command pipeline ($(date +%Y-%m-%d))** — Three daily commands (morning, evening, sunday) read entries from the Hermeer app, interpret them with full natal chart and transit context, and track patterns over time.
EOF
fi

if [ ! -f "$PROJECT_DIR/learnings/weekly-reflections.md" ]; then
  cat > "$PROJECT_DIR/learnings/weekly-reflections.md" << EOF
# Weekly Reflections

Written by the sunday command. Newest at top.

---
EOF
fi

# --- Write CLAUDE.md ---
echo "Writing CLAUDE.md..."

if [ ! -f "$PROJECT_DIR/CLAUDE.md" ]; then
  cat > "$PROJECT_DIR/CLAUDE.md" << EOF
# Depth Practice

## Current Status
- **Session:** 0 (setup)
- **Active:** Setting up practice infrastructure
- **Next:** First morning briefing after logging entries in the app

## About the Practitioner

**Name:** $PRACTITIONER_NAME
**Birth Date:** $BIRTH_DATE | **Time:** $BIRTH_TIME | **Location:** $BIRTH_LOCATION

## Commands

- \`morning\` — Morning briefing. Reads all new entries, interprets them, writes field reading.
- \`evening\` — Evening pull interpretation. Completes the day's arc.
- \`sunday\` — Weekly field reading. Panoramic review of the week's cards, transits, dreams.

## File Map

\`\`\`
$(basename "$PROJECT_DIR")/
+-- CLAUDE.md                    # Project reference
+-- scripts/
|   +-- command-context.md       # Shared config — birth data, rules, procedures
|   +-- morning.sh               # Morning briefing command
|   +-- evening.sh               # Evening briefing command
|   +-- sunday.sh                # Weekly field reading command
+-- learnings/
|   +-- conversation-log.md      # Session journal
|   +-- decisions.md             # Decisions + rationale
|   +-- weekly-reflections.md    # Sunday reflections
+-- logs/
    +-- briefings/               # Saved briefing output
    +-- transit-watch-today.md   # Transit report (if transit watcher installed)
\`\`\`
EOF
fi

# --- Set up shell aliases ---
echo ""
echo "Setting up shell aliases..."

# Detect shell config file
if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
  SHELL_RC="$HOME/.zshrc"
else
  SHELL_RC="$HOME/.bashrc"
fi

ALIAS_BLOCK="
# Depth practice commands
export DEPTH_PROJECT=\"$PROJECT_DIR\"
alias morning=\"bash \$DEPTH_PROJECT/scripts/morning.sh\"
alias evening=\"bash \$DEPTH_PROJECT/scripts/evening.sh\"
alias sunday=\"bash \$DEPTH_PROJECT/scripts/sunday.sh\""

# Check if aliases already exist
if grep -q "# Depth practice commands" "$SHELL_RC" 2>/dev/null; then
  echo "Aliases already exist in $SHELL_RC — skipping."
else
  echo "$ALIAS_BLOCK" >> "$SHELL_RC"
  echo "Added aliases to $SHELL_RC"
fi

# --- Done ---
echo ""
echo "=== Setup Complete ==="
echo ""
echo "Project created at: $PROJECT_DIR"
echo ""
echo "Getting Started:"
echo ""
echo "  1. Open the Hermeer app and log a tarot pull or journal entry."
echo ""
echo "  2. Run your first morning briefing:"
echo "       source $SHELL_RC"
echo "       morning"
echo ""
echo "  3. The morning command will:"
echo "     - Read your entries from the app"
echo "     - Interpret them using your natal chart and active transits"
echo "     - Write a field reading (atmospheric prose about the day's psychic weather)"
echo "     - Flag threads that need a live session"
echo "     - Save the briefing to logs/briefings/"
echo ""
echo "  4. In the evening after your evening pull, run:"
echo "       evening"
echo ""
echo "  5. On Sunday evenings, run the weekly panoramic reading:"
echo "       sunday"
echo ""
echo "  6. To customize the practice voice, interpretation style, or add natal"
echo "     chart placements, edit: $PROJECT_DIR/scripts/command-context.md"
echo ""
echo "  Prerequisites:"
echo "     - Claude Code CLI (claude) installed and authenticated"
echo "     - Hermeer app syncing to iCloud"
echo "     - Optional: pyswisseph for precise transit tracking"
echo ""
