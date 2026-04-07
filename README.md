# hermeer-mcp-server

MCP server for [Hermeer](https://hermeerapp.com) — connects Claude Desktop to your practice data.

Hermeer is an iOS app for tracking tarot pulls, dreams, therapy sessions, journal entries, synchronicities, and astrological transits. This MCP server lets Claude Desktop read your synced data and write depth interpretations back — they appear in the app automatically.

## Install

```bash
npm install -g hermeer-mcp-server
```

Requires Node.js 18+.

## Configure Claude Desktop

Add this to your Claude Desktop config file:

**Mac:** `~/Library/Application Support/Claude/claude_desktop_config.json`
**Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "hermeer": {
      "command": "hermeer-mcp-server"
    }
  }
}
```

The server automatically finds your HermeerSync folder. To override the location:

```json
{
  "mcpServers": {
    "hermeer": {
      "command": "hermeer-mcp-server",
      "env": {
        "HERMEER_BASE": "/path/to/your/HermeerSync"
      }
    }
  }
}
```

Common sync folder locations:
- **Mac + iCloud:** `~/Library/Mobile Documents/com~apple~CloudDocs/HermeerSync/`
- **Mac + OneDrive:** `~/Library/CloudStorage/OneDrive-Personal/HermeerSync/`
- **Windows + iCloud:** `C:\Users\{name}\iCloudDrive\HermeerSync\`
- **Windows + OneDrive:** `C:\Users\{name}\OneDrive\HermeerSync\`
- **Windows + Google Drive:** `G:\My Drive\HermeerSync\`
- **Encrypted setup:** `~/.hermeer-local/` (with decrypt daemon running)

Restart Claude Desktop after saving the config.

## Set up your Depth Work project

1. In Claude Desktop: **Projects > Create Project** and name it "Depth Work"
2. Click the project, then **Set project instructions**
3. Paste the companion template from the Hermeer app (Settings > Depth Companion > Copy Project Instructions)
4. Open a chat and say: "Read my current state and tell me what's alive."

Claude reads your data through the MCP server and writes interpretations back to your sync folder. Open Hermeer and they appear on your entries.

## Tools

### Read (11 tools)
| Tool | What it reads |
|------|--------------|
| `read_current_state` | Orient-me file — read this first every session |
| `read_recent_entries` | Entries from last N days across all channels |
| `read_entry` | Specific entry by filename |
| `read_threads` | Meaning threads with first-words |
| `read_pending` | Entries awaiting interpretation |
| `read_patterns` | Extended pattern data (suit arcs, body zones) |
| `read_full_entries` | Complete recent entry text (3-day window) |
| `read_temporal_context` | Time, moon phase, session proximity, streaks |
| `read_cross_references` | Linkage map between entries |
| `read_briefings` | Recent companion briefings (cross-session continuity) |
| `complete_request` | Mark an interpretation request as completed |

### Write (7 tools)
| Tool | What it writes |
|------|---------------|
| `write_interpretation` | Depth interpretation for any entry type |
| `write_field_reading` | Atmospheric prose about the psychic weather |
| `write_thread_note` | Response to a thread, interpretation, or moon note |
| `write_arc` | Narrative arc (day, week, transit, or season scale) |
| `write_synthesis` | Weekly or monthly synthesis |
| `write_forecast` | Weekly forecast |
| `write_briefing` | Companion prose (morning, evening, Sunday, custom) with optional landing screen snippet |

All writes use atomic file operations (write to temp, then rename) to prevent sync from picking up partial files.

## With encryption

If you've enabled encryption in the Hermeer app, synced files are `.hermeer.enc` (AES-256-GCM). The MCP server reads plaintext — it doesn't handle encryption directly. Instead:

1. Run the decrypt daemon on your computer (see Hermeer app > Settings > Encrypt Synced Files)
2. The daemon decrypts files to `~/.hermeer-local/`
3. Set `HERMEER_BASE` to `~/.hermeer-local/` in your Claude Desktop config
4. The daemon encrypts interpretations written by the MCP server back to the cloud folder

## Development

```bash
git clone https://github.com/hermeerapp/hermeer-mcp-server
cd hermeer-mcp-server
npm install
npm run build
```

To test locally without installing globally:
```bash
node dist/index.js
```

## License

MIT
