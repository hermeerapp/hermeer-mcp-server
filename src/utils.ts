import { homedir, platform } from "node:os";
import { join } from "node:path";
import {
  readFile,
  writeFile,
  rename,
  mkdir,
  readdir,
  stat,
  access,
} from "node:fs/promises";

/** Resolve HERMEER_BASE from env or platform default. */
export function resolveBase(): string {
  if (process.env.HERMEER_BASE) {
    return process.env.HERMEER_BASE;
  }
  const home = homedir();
  if (platform() === "win32") {
    return join(home, "iCloudDrive", "HermeerSync");
  }
  return join(
    home,
    "Library",
    "Mobile Documents",
    "com~apple~CloudDocs",
    "HermeerSync",
  );
}

/** Read a file and return its contents, or null if it doesn't exist. */
export async function readFileSafe(path: string): Promise<string | null> {
  try {
    return await readFile(path, "utf-8");
  } catch {
    return null;
  }
}

/** Check if a path exists. */
export async function exists(path: string): Promise<boolean> {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

/** Atomic write: write to .tmp then rename. */
export async function atomicWrite(
  filePath: string,
  content: string,
): Promise<void> {
  const dir = filePath.substring(0, filePath.lastIndexOf("/"));
  await mkdir(dir, { recursive: true });
  const tmp = filePath + ".tmp";
  await writeFile(tmp, content, "utf-8");
  await rename(tmp, filePath);
}

/** List .md files in a directory. Returns filenames (not full paths). */
export async function listMdFiles(dir: string): Promise<string[]> {
  try {
    const entries = await readdir(dir);
    return entries.filter((f) => f.endsWith(".md"));
  } catch {
    return [];
  }
}

/** Extract date from a sync filename like "tarot-2026-03-22-2123.md". */
export function extractDateFromFilename(filename: string): string | null {
  const match = filename.match(/(\d{4}-\d{2}-\d{2})/);
  return match ? match[1] : null;
}

/** Map entry type prefix to directory name. */
export function typeToDirectory(prefix: string): string {
  const map: Record<string, string> = {
    tarot: "tarot",
    dream: "dreams",
    session: "sessions",
    journal: "journal",
    synchronicity: "synchronicities",
  };
  return map[prefix] ?? prefix;
}

/** Extract the type prefix from a sync filename. */
export function extractTypePrefix(filename: string): string {
  const match = filename.match(/^([a-z]+)-\d{4}/);
  return match ? match[1] : "";
}

/** Generate a slug from a title. */
export function slugify(title: string): string {
  return title
    .toLowerCase()
    .replace(/\s+/g, "-")
    .replace(/[^a-z0-9-]/g, "")
    .replace(/-{2,}/g, "-")
    .replace(/^-|-$/g, "");
}

/** Build YAML frontmatter from key-value pairs. */
export function buildFrontmatter(fields: Record<string, unknown>): string {
  const lines = ["---"];
  for (const [key, value] of Object.entries(fields)) {
    if (value === undefined || value === null) continue;
    if (Array.isArray(value)) {
      lines.push(`${key}: [${value.map((v) => `"${v}"`).join(", ")}]`);
    } else if (typeof value === "boolean") {
      lines.push(`${key}: ${value}`);
    } else {
      lines.push(`${key}: "${value}"`);
    }
  }
  lines.push("---");
  return lines.join("\n");
}

/** Format a CallToolResult success. */
export function toolSuccess(
  path: string,
  message: string,
): { content: { type: "text"; text: string }[] } {
  return {
    content: [
      {
        type: "text" as const,
        text: JSON.stringify({ success: true, path, message }),
      },
    ],
  };
}

/** Format a CallToolResult error. */
export function toolError(
  error: string,
  suggestion?: string,
): { content: { type: "text"; text: string }[]; isError: true } {
  return {
    content: [
      {
        type: "text" as const,
        text: JSON.stringify({ success: false, error, suggestion }),
      },
    ],
    isError: true as const,
  };
}

/** Get current ISO 8601 timestamp with timezone. */
export function nowISO(): string {
  const now = new Date();
  const offset = -now.getTimezoneOffset();
  const sign = offset >= 0 ? "+" : "-";
  const h = String(Math.floor(Math.abs(offset) / 60)).padStart(2, "0");
  const m = String(Math.abs(offset) % 60).padStart(2, "0");
  return now.toISOString().replace("Z", `${sign}${h}:${m}`);
}

/** Get today's date as YYYY-MM-DD. */
export function todayDate(): string {
  return new Date().toISOString().slice(0, 10);
}

/** Find the next available revisit number in a directory. */
export async function nextRevisitNumber(
  dir: string,
  stem: string,
): Promise<number> {
  const files = await listMdFiles(dir);
  let max = 0;
  const pattern = new RegExp(`^${escapeRegExp(stem)}-revisit-(\\d+)\\.md$`);
  for (const f of files) {
    const m = f.match(pattern);
    if (m) {
      max = Math.max(max, parseInt(m[1], 10));
    }
  }
  return max + 1;
}

function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** Read frontmatter value from file content. */
export function readFrontmatterValue(
  content: string,
  key: string,
): string | null {
  const match = content.match(
    new RegExp(`^${key}:\\s*"?([^"\\n]+)"?`, "m"),
  );
  return match ? match[1].trim() : null;
}

export { readFile, writeFile, rename, mkdir, readdir, stat, join };
