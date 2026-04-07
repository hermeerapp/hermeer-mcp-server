import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import {
  readFileSafe,
  extractDateFromFilename,
  typeToDirectory,
  extractTypePrefix,
  listMdFiles,
  toolError,
  atomicWrite,
  join,
  readFile,
} from "./utils.js";

const ENTRY_TYPES = ["tarot", "dreams", "sessions", "journal", "synchronicities"];

function stateFileTool(
  server: McpServer,
  base: string,
  name: string,
  description: string,
  filename: string,
) {
  server.tool(name, description, {}, async () => {
    const path = join(base, "state", filename);
    const content = await readFileSafe(path);
    if (content === null) {
      return toolError(
        `${filename} not found. The app may not have synced yet.`,
        "Check that HERMEER_BASE is configured correctly.",
      );
    }
    return { content: [{ type: "text" as const, text: content }] };
  });
}

export function registerReadTools(server: McpServer, base: string): void {
  // 1. read_current_state
  stateFileTool(
    server,
    base,
    "read_current_state",
    "Returns the orient-me file. Read this first at the start of every session.",
    "current-state.md",
  );

  // 2. read_recent_entries
  server.tool(
    "read_recent_entries",
    "Returns entry files from the last N days across all five channels.",
    { days: z.number().int().positive().default(7).describe("Number of days to look back") },
    async ({ days }) => {
      const cutoff = new Date();
      cutoff.setDate(cutoff.getDate() - days);
      const cutoffStr = cutoff.toISOString().slice(0, 10);

      const results: { filename: string; type: string; date: string; content: string }[] = [];

      for (const dir of ENTRY_TYPES) {
        const dirPath = join(base, dir);
        const files = await listMdFiles(dirPath);
        for (const filename of files) {
          const date = extractDateFromFilename(filename);
          if (date && date >= cutoffStr) {
            try {
              const content = await readFile(join(dirPath, filename), "utf-8");
              results.push({ filename, type: dir, date, content });
            } catch {
              // skip unreadable files
            }
          }
        }
      }

      results.sort((a, b) => b.date.localeCompare(a.date));

      return {
        content: [{ type: "text" as const, text: JSON.stringify(results, null, 2) }],
      };
    },
  );

  // 3. read_entry
  server.tool(
    "read_entry",
    "Returns a specific entry file by its sync filename.",
    { filename: z.string().describe('The sync filename, e.g. "tarot-2026-03-22-2123.md"') },
    async ({ filename }) => {
      // Try the expected directory first
      const prefix = extractTypePrefix(filename);
      const dir = typeToDirectory(prefix);
      const primaryPath = join(base, dir, filename);
      let content = await readFileSafe(primaryPath);

      // Fallback: scan all entry directories
      if (content === null) {
        for (const d of ENTRY_TYPES) {
          content = await readFileSafe(join(base, d, filename));
          if (content !== null) break;
        }
      }

      // Also check depth directories
      if (content === null) {
        const depthDirs = [
          "depth/tarot", "depth/dreams", "depth/sessions",
          "depth/journal", "depth/synchronicities", "depth/charts",
          "depth/transits", "depth/field", "depth/arcs",
          "depth/synthesis", "depth/forecasts",
        ];
        for (const d of depthDirs) {
          content = await readFileSafe(join(base, d, filename));
          if (content !== null) break;
        }
      }

      if (content === null) {
        return toolError(
          `File not found: ${filename}`,
          `Searched entry directories and depth directories under HERMEER_BASE.`,
        );
      }

      return { content: [{ type: "text" as const, text: content }] };
    },
  );

  // 4. read_briefings
  server.tool(
    "read_briefings",
    "Returns recent briefing files from depth/briefings/. Use this so evening knows what morning said.",
    {
      days: z.number().int().positive().default(3).describe("Number of days to look back"),
      command: z.string().optional().describe("Filter by command type (morning, evening, sunday, custom)"),
    },
    async ({ days, command }) => {
      const briefingsDir = join(base, "depth", "briefings");
      const files = await listMdFiles(briefingsDir);

      const cutoff = new Date();
      cutoff.setDate(cutoff.getDate() - days);
      const cutoffStr = cutoff.toISOString().slice(0, 10);

      const results: { filename: string; date: string; command: string; content: string }[] = [];

      for (const filename of files) {
        const date = extractDateFromFilename(filename);
        if (!date || date < cutoffStr) continue;

        // Filter by command if specified
        if (command) {
          const lowerName = filename.toLowerCase();
          if (!lowerName.includes(command.toLowerCase())) continue;
        }

        try {
          const content = await readFile(join(briefingsDir, filename), "utf-8");
          const cmd = filename.replace(/^\d{4}-\d{2}-\d{2}-/, "").replace(/\.md$/, "");
          results.push({ filename, date, command: cmd, content });
        } catch {
          // skip unreadable
        }
      }

      results.sort((a, b) => b.date.localeCompare(a.date));

      if (results.length === 0) {
        return { content: [{ type: "text" as const, text: "No briefings found in the last " + days + " days." }] };
      }

      return {
        content: [{ type: "text" as const, text: JSON.stringify(results, null, 2) }],
      };
    },
  );

  // 5. complete_request
  server.tool(
    "complete_request",
    "Marks an interpretation request as completed. Updates the request file's status from 'pending' to 'completed'.",
    {
      sync_filename: z.string().describe("The sync filename of the entry whose request to complete"),
    },
    async ({ sync_filename }) => {
      const stem = sync_filename.replace(/\.md$/, "");
      const requestFilename = `${stem}-request.md`;
      const requestPath = join(base, "requests", requestFilename);

      const content = await readFileSafe(requestPath);
      if (content === null) {
        return toolError(
          `Request file not found: ${requestFilename}`,
          "No pending request exists for this entry.",
        );
      }

      // Replace status: pending with status: completed in frontmatter
      const updated = content.replace(/^status:\s*pending$/m, "status: completed");
      if (updated === content) {
        // Already completed or no status field found
        return { content: [{ type: "text" as const, text: `Request ${requestFilename} is already completed or has no pending status.` }] };
      }

      await atomicWrite(requestPath, updated);
      return { content: [{ type: "text" as const, text: `Request ${requestFilename} marked as completed.` }] };
    },
  );

  // 6-11. State file tools
  stateFileTool(server, base, "read_threads", "Returns the threads state file.", "threads.md");
  stateFileTool(server, base, "read_pending", "Returns entries awaiting interpretation.", "pending-interpretations.md");
  stateFileTool(server, base, "read_patterns", "Returns extended pattern data (suit arcs, orientation trends, body zones).", "patterns-extended.md");
  stateFileTool(server, base, "read_full_entries", "Returns complete text of recent entries (3-day window).", "full-entries.md");
  stateFileTool(server, base, "read_temporal_context", "Returns current temporal context: time of day, moon phase, session proximity, practice streaks.", "temporal-context.md");
  stateFileTool(server, base, "read_cross_references", "Returns pre-built linkage map between entries.", "cross-references.md");
}
