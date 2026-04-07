import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import {
  atomicWrite,
  exists,
  readFileSafe,
  buildFrontmatter,
  slugify,
  toolSuccess,
  toolError,
  nowISO,
  todayDate,
  nextRevisitNumber,
  readFrontmatterValue,
  join,
} from "./utils.js";

const ENTRY_TYPE_DIRS: Record<string, string> = {
  tarot: "depth/tarot",
  dream: "depth/dreams",
  session: "depth/sessions",
  journal: "depth/journal",
  synchronicity: "depth/synchronicities",
  transit: "depth/transits",
};

const NOTE_TYPE_DIRS: Record<string, string> = {
  "thread-note": "depth/thread-notes",
  "interpretation-note": "depth/interpretation-notes",
  "moon-note": "depth/moon-notes",
};

export function registerWriteTools(server: McpServer, base: string): void {
  // 1. write_interpretation
  server.tool(
    "write_interpretation",
    "Writes a depth interpretation file with proper frontmatter.",
    {
      entry_type: z
        .enum(["tarot", "dream", "session", "journal", "synchronicity", "transit"])
        .describe("The entry type"),
      sync_filename: z.string().describe("Target filename, e.g. tarot-2026-03-22-2123.md"),
      content: z.string().describe("The interpretation text (body only, no frontmatter)"),
      themes: z
        .array(z.string())
        .min(2)
        .max(5)
        .describe("2-5 canonical theme strings from theme-vocabulary.md"),
      entry_id: z
        .string()
        .optional()
        .describe("The entry ID. Required for all types except transit."),
      is_compound: z.boolean().optional().describe("For transits: marks compound configurations"),
      compound_label: z.string().optional().describe("For transits: human-readable compound label"),
    },
    async ({ entry_type, sync_filename, content, themes, entry_id, is_compound, compound_label }) => {
      // Validate entry_id for non-transit types
      if (entry_type !== "transit" && !entry_id) {
        return toolError(
          `entry_id is required for type "${entry_type}".`,
          "Provide the entry ID from the source entry file.",
        );
      }

      const dir = join(base, ENTRY_TYPE_DIRS[entry_type]);
      let targetPath = join(dir, sync_filename);
      let relativePath = `${ENTRY_TYPE_DIRS[entry_type]}/${sync_filename}`;

      // Handle existing files: depth/MCP supersedes API interpretations, same-tier creates revisits
      if (await exists(targetPath)) {
        const existing = await readFileSafe(targetPath);
        const existingSource = existing ? readFrontmatterValue(existing, "source") : null;

        // Higher tier supersedes lower tier — overwrite instead of revisit
        const lowerTierSources = ["live-companion", "paste"];
        if (existingSource && lowerTierSources.includes(existingSource)) {
          // Overwrite — depth/MCP supersedes API/paste interpretation
          // targetPath stays the same
        } else {
          // Same or higher tier — create revisit file
          const stem = sync_filename.replace(/\.md$/, "");
          const n = await nextRevisitNumber(dir, stem);
          const revisitName = `${stem}-revisit-${n}.md`;
          targetPath = join(dir, revisitName);
          relativePath = `${ENTRY_TYPE_DIRS[entry_type]}/${revisitName}`;
        }
      }

      // Build frontmatter
      const fm: Record<string, unknown> = {
        source: "mcp-companion",
      };
      if (entry_type !== "transit" && entry_id) {
        fm.entry = entry_id;
      }
      fm.themes = themes;
      if (entry_type === "transit" && is_compound) {
        fm.is_compound = true;
        if (compound_label) fm.compound_label = compound_label;
      }

      const fileContent = buildFrontmatter(fm) + "\n\n" + content.trim() + "\n";
      await atomicWrite(targetPath, fileContent);

      return toolSuccess(relativePath, "Interpretation written successfully.");
    },
  );

  // 2. write_field_reading
  server.tool(
    "write_field_reading",
    "Writes a field reading (atmospheric prose about the current psychic weather).",
    {
      content: z.string().describe("3-5 sentences of atmospheric prose"),
      reading_type: z
        .enum(["daily", "midday", "weekly"])
        .default("daily")
        .describe("Type of field reading"),
      date: z.string().optional().describe("ISO date (YYYY-MM-DD). Defaults to today."),
    },
    async ({ content, reading_type, date }) => {
      const d = date ?? todayDate();

      let filename: string;
      if (reading_type === "daily") {
        filename = `${d}.md`;
      } else {
        filename = `${d}-${reading_type}.md`;
      }

      const targetPath = join(base, "depth", "field", filename);
      const relativePath = `depth/field/${filename}`;

      if (await exists(targetPath)) {
        return toolError(
          `Field reading already exists for this date and type.`,
          `A ${reading_type} reading for ${d} already exists at ${relativePath}. Not overwriting.`,
        );
      }

      const fm = buildFrontmatter({
        type: "field-reading",
        reading_type,
        date: d,
      });

      const fileContent = fm + "\n\n" + content.trim() + "\n";
      await atomicWrite(targetPath, fileContent);

      return toolSuccess(relativePath, "Field reading written.");
    },
  );

  // 3. write_thread_note (also handles interpretation-note and moon-note)
  server.tool(
    "write_thread_note",
    "Appends a depth companion response to an existing note file (thread note, interpretation note, or moon note).",
    {
      thread_filename: z.string().describe('The note filename, e.g. "the-emperor.md"'),
      content: z.string().describe("The response text"),
      date: z.string().optional().describe("ISO date for the heading. Defaults to today."),
      note_type: z
        .enum(["thread-note", "interpretation-note", "moon-note"])
        .default("thread-note")
        .describe("Type of note to append to"),
    },
    async ({ thread_filename, content, date, note_type }) => {
      const dir = NOTE_TYPE_DIRS[note_type];
      const filePath = join(base, dir, thread_filename);
      const relativePath = `${dir}/${thread_filename}`;

      const existing = await readFileSafe(filePath);
      if (existing === null) {
        return toolError(
          `Note file not found: ${thread_filename}`,
          `${note_type} files are created by the user in the app. The MCP server only appends to existing ones.`,
        );
      }

      const d = date ?? todayDate();
      const section = `\n\n## ${d} \u2014 Depth Companion\n\n${content.trim()}\n`;

      const newContent = existing.trimEnd() + section;
      await atomicWrite(filePath, newContent);

      return toolSuccess(relativePath, `Response appended to ${note_type.replace("-", " ")}.`);
    },
  );

  // 4. write_arc
  server.tool(
    "write_arc",
    "Writes a narrative arc file.",
    {
      title: z.string().describe("Human-readable arc title"),
      scale: z.enum(["day", "week", "transit", "season"]).describe("Arc scale"),
      date_start: z.string().describe("ISO date for arc start"),
      date_end: z.string().describe("ISO date for arc end"),
      content: z.string().describe("Narrative arc text"),
      themes: z
        .array(z.string())
        .min(2)
        .max(5)
        .describe("2-5 canonical themes"),
      parent_arc: z.string().optional().describe("Filename stem of parent arc (without .md)"),
    },
    async ({ title, scale, date_start, date_end, content, themes, parent_arc }) => {
      if (date_start > date_end) {
        return toolError(
          "date_start must be <= date_end.",
          `Got start=${date_start}, end=${date_end}.`,
        );
      }

      const slug = slugify(title);
      const filename = `${date_start}-${slug}.md`;
      const targetPath = join(base, "depth", "arcs", filename);
      const relativePath = `depth/arcs/${filename}`;

      if (await exists(targetPath)) {
        return toolError(
          `Arc already exists at ${relativePath}.`,
          "Use a different title or check for an existing arc.",
        );
      }

      const fm: Record<string, unknown> = {
        source: "mcp-companion",
        title,
        scale,
        date_start,
        date_end,
        themes,
      };
      if (parent_arc) fm.parent_arc = parent_arc;

      const fileContent = buildFrontmatter(fm) + "\n\n" + content.trim() + "\n";
      await atomicWrite(targetPath, fileContent);

      return toolSuccess(relativePath, "Arc written.");
    },
  );

  // 5. write_synthesis
  server.tool(
    "write_synthesis",
    "Writes a weekly or monthly synthesis file.",
    {
      synthesis_type: z.enum(["weekly", "monthly"]).describe("Synthesis type"),
      period: z.string().describe('Human-readable period, e.g. "March 17 through March 23, 2026"'),
      content: z.string().describe("Synthesis text"),
      themes: z
        .array(z.string())
        .min(2)
        .max(5)
        .describe("2-5 canonical themes"),
      period_date: z
        .string()
        .describe("For weekly: Monday date (YYYY-MM-DD). For monthly: year-month (YYYY-MM)."),
    },
    async ({ synthesis_type, period, content, themes, period_date }) => {
      const filename =
        synthesis_type === "weekly"
          ? `weekly-${period_date}.md`
          : `monthly-${period_date}.md`;

      const targetPath = join(base, "depth", "synthesis", filename);
      const relativePath = `depth/synthesis/${filename}`;

      // Check for existing file
      const existing = await readFileSafe(targetPath);
      if (existing !== null) {
        const depthLevel = readFrontmatterValue(existing, "depth_level");
        if (depthLevel === "2") {
          return toolError(
            `A depth-level synthesis already exists at ${relativePath}.`,
            "Not overwriting an existing depth-level synthesis.",
          );
        }
        // depth_level "1" (API-generated) — overwrite is allowed
      }

      const typeValue =
        synthesis_type === "weekly" ? "weekly-synthesis" : "monthly-synthesis";

      const fm = buildFrontmatter({
        type: typeValue,
        period,
        generated: nowISO(),
        provider: "depth-companion",
        depth_level: "2",
        source: "mcp-companion",
        themes,
      });

      const fileContent = fm + "\n\n" + content.trim() + "\n";
      await atomicWrite(targetPath, fileContent);

      return toolSuccess(relativePath, `${synthesis_type === "weekly" ? "Weekly" : "Monthly"} synthesis written.`);
    },
  );

  // 6. write_briefing
  server.tool(
    "write_briefing",
    "Writes a companion briefing (morning, evening, Sunday, or custom prose). Briefings are cross-session — evening can reference what morning said.",
    {
      command: z
        .enum(["morning", "evening", "sunday", "custom"])
        .describe("Which command produced this briefing"),
      content: z.string().describe("The briefing prose (body only, no frontmatter)"),
      landing: z.string().optional().describe("One sentence (max 200 chars) for the app's landing screen. The first thing the practitioner sees when they open the app. Make it count."),
      date: z.string().optional().describe("ISO date (YYYY-MM-DD). Defaults to today."),
      custom_label: z.string().optional().describe("Label for custom commands, e.g. 'midday-checkin'"),
    },
    async ({ command, content, landing, date, custom_label }) => {
      const d = date ?? todayDate();
      const suffix = command === "custom" && custom_label ? slugify(custom_label) : command;
      const filename = `${d}-${suffix}.md`;
      const targetPath = join(base, "depth", "briefings", filename);
      const relativePath = `depth/briefings/${filename}`;

      const fmData: Record<string, unknown> = {
        type: "briefing",
        command,
        date: d,
        generated: nowISO(),
        source: "mcp-companion",
      };
      if (landing) fmData.landing = landing;

      const fm = buildFrontmatter(fmData);

      const fileContent = fm + "\n\n" + content.trim() + "\n";
      await atomicWrite(targetPath, fileContent);

      return toolSuccess(relativePath, `${command} briefing written.`);
    },
  );

  // 7. write_forecast
  server.tool(
    "write_forecast",
    "Writes a weekly forecast file.",
    {
      period: z.string().describe('Human-readable period, e.g. "March 24 through March 30, 2026"'),
      content: z.string().describe("Forecast text"),
      themes: z
        .array(z.string())
        .min(2)
        .max(5)
        .describe("2-5 canonical themes"),
      period_date: z.string().describe("Monday date of the forecast week (YYYY-MM-DD)"),
    },
    async ({ period, content, themes, period_date }) => {
      const filename = `weekly-${period_date}.md`;
      const targetPath = join(base, "depth", "forecasts", filename);
      const relativePath = `depth/forecasts/${filename}`;

      // Check for existing file
      const existing = await readFileSafe(targetPath);
      if (existing !== null) {
        const depthLevel = readFrontmatterValue(existing, "depth_level");
        if (depthLevel === "2") {
          return toolError(
            `A depth-level forecast already exists at ${relativePath}.`,
            "Not overwriting an existing depth-level forecast.",
          );
        }
      }

      const fm = buildFrontmatter({
        type: "weekly-forecast",
        period,
        generated: nowISO(),
        provider: "depth-companion",
        depth_level: "2",
        source: "mcp-companion",
        themes,
      });

      const fileContent = fm + "\n\n" + content.trim() + "\n";
      await atomicWrite(targetPath, fileContent);

      return toolSuccess(relativePath, "Weekly forecast written.");
    },
  );
}
