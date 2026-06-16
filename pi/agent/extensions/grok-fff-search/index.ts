/**
 * Grok + FFF search bridge
 *
 * Grok Composer models call Cursor-style `Grep` and `Glob`. pi-grok-cli registers
 * those with ripgrep/fd. This extension registers the same names earlier and
 * delegates to @ff-labs/pi-fff (FFF) so grok-cli tool scope still activates
 * Grep/Glob while execution uses ffgrep/fffind.
 *
 * This extension also loads pi-grok-cli itself so Grep/Glob can be replaced
 * inside one extension without tripping pi's cross-extension tool conflict check.
 * Keep npm:pi-grok-cli out of settings packages; install this directory's npm deps.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import registerGrokCli from "pi-grok-cli";
import { Text } from "@earendil-works/pi-tui";
import type { GrepMode, GrepResult, SearchResult } from "@ff-labs/fff-node";
import { FileFinder } from "@ff-labs/fff-node";
import { Type } from "@sinclair/typebox";
import nodePath from "node:path";

interface FormattedFind {
  output: string;
  weak: boolean;
  shownCount: number;
}

function fffFileAnnotation(item: {
  gitStatus?: string;
  totalFrecencyScore?: number;
  accessFrecencyScore?: number;
}): string {
  const git = item.gitStatus;
  if (git && git !== "clean" && git !== "unknown" && git !== "") {
    return `  [${git} in git]`;
  }
  const frecency = item.totalFrecencyScore ?? item.accessFrecencyScore ?? 0;
  if (frecency >= 25) return "  [VERY often touched file]";
  if (frecency >= 20) return "  [often touched file]";
  return "";
}

// pi-fff-compatible output formatting
const DEFAULT_GREP_LIMIT = 20;
const DEFAULT_FIND_LIMIT = 30;
const GREP_MAX_LINE_LENGTH = 500;
const FIND_WEAK_SAMPLE_SIZE = 5;

// Vendored from @ff-labs/pi-fff/src/query.ts so this bridge does not rely on
// that package's private source path for module resolution.
function normalizePathConstraint(pathConstraint: string, cwd = process.cwd()): string | null {
  let trimmed = pathConstraint.trim();
  if (!trimmed) return trimmed;

  if (nodePath.isAbsolute(trimmed)) {
    const relative = nodePath.relative(cwd, trimmed).replaceAll(nodePath.sep, "/");
    if (relative === "") return null;
    if (relative.startsWith("../") || relative === ".." || nodePath.isAbsolute(relative)) {
      throw new Error(`Path constraint must be relative to the workspace: ${pathConstraint}`);
    }
    trimmed = relative;
  }

  if (trimmed === "." || trimmed === "./") return null;
  if (trimmed.startsWith("./")) trimmed = trimmed.slice(2);

  const recursiveDir = trimmed.match(/^(.*)\/\*\*(?:\/\*)?$/);
  if (recursiveDir) {
    const dir = recursiveDir[1];
    if (dir && !/[*?[{]/.test(dir)) return `${dir}/`;
  }

  if (trimmed.startsWith("/") || trimmed.endsWith("/")) return trimmed;
  if (/[*?[{]/.test(trimmed)) return trimmed;

  const lastSegment = trimmed.split("/").pop() ?? "";
  if (/\.[a-zA-Z][a-zA-Z0-9]{0,9}$/.test(lastSegment)) return trimmed;

  return `${trimmed}/`;
}

function normalizeExcludes(
  exclude: string | string[] | undefined,
  cwd = process.cwd(),
): string[] {
  if (!exclude) return [];
  const list = Array.isArray(exclude) ? exclude : [exclude];
  const out: string[] = [];
  for (const raw of list) {
    const parts = raw
      .split(/[,\s]+/)
      .map((s) => s.trim())
      .filter(Boolean);
    for (const p of parts) {
      const stripped = p.startsWith("!") ? p.slice(1) : p;
      const normalized = normalizePathConstraint(stripped, cwd);
      if (normalized) out.push(`!${normalized}`);
    }
  }
  return out;
}

function buildQuery(
  path: string | undefined,
  pattern: string,
  exclude?: string | string[],
  cwd = process.cwd(),
): string {
  const parts: string[] = [];
  if (path) {
    const pathConstraint = normalizePathConstraint(path, cwd);
    if (pathConstraint) parts.push(pathConstraint);
  }
  parts.push(...normalizeExcludes(exclude, cwd));
  parts.push(pattern);
  return parts.join(" ");
}

function truncateLine(line: string, max = GREP_MAX_LINE_LENGTH): string {
  const trimmed = line.trim();
  return trimmed.length <= max ? trimmed : `${trimmed.slice(0, max)}...`;
}

function weakScoreThreshold(pattern: string): number {
  const perfect = pattern.length * 12;
  return Math.floor((perfect * 50) / 100);
}

function formatGrepOutput(result: GrepResult): string {
  if (result.items.length === 0) return "No matches found";

  const lines: string[] = [];
  let currentFile = "";

  for (const match of result.items) {
    if (match.relativePath !== currentFile) {
      if (lines.length > 0) lines.push("");
      currentFile = match.relativePath;
      lines.push(`${currentFile}${fffFileAnnotation(match)}`);
    }

    match.contextBefore?.forEach((line: string, i: number) => {
      const lineNum = match.lineNumber - match.contextBefore!.length + i;
      lines.push(` ${lineNum}- ${truncateLine(line)}`);
    });

    lines.push(` ${match.lineNumber}: ${truncateLine(match.lineContent)}`);

    match.contextAfter?.forEach((line: string, i: number) => {
      const lineNum = match.lineNumber + 1 + i;
      lines.push(` ${lineNum}- ${truncateLine(line)}`);
    });
  }

  return lines.join("\n");
}

function formatFindOutput(
  result: SearchResult,
  limit: number,
  pattern: string,
): FormattedFind {
  if (result.items.length === 0) {
    return { output: "No files found matching pattern", weak: false, shownCount: 0 };
  }

  const topScore = result.scores[0]?.total ?? 0;
  const weak = topScore < weakScoreThreshold(pattern);
  const effective = weak ? Math.min(FIND_WEAK_SAMPLE_SIZE, limit) : limit;
  const shown = result.items.slice(0, effective);

  return {
    output: shown
      .map((item) => `${item.relativePath}${fffFileAnnotation(item)}`)
      .join("\n"),
    weak,
    shownCount: shown.length,
  };
}

const cursorCache = new Map<string, import("@ff-labs/fff-node").GrepCursor>();
let cursorCounter = 0;

function storeCursor(cursor: import("@ff-labs/fff-node").GrepCursor): string {
  const id = `fff_c${++cursorCounter}`;
  cursorCache.set(id, cursor);
  if (cursorCache.size > 200) {
    const first = cursorCache.keys().next().value;
    if (first) cursorCache.delete(first);
  }
  return id;
}

function getCursor(id: string) {
  return cursorCache.get(id);
}

interface FindCursor {
  query: string;
  pattern: string;
  pageSize: number;
  nextPageIndex: number;
}

const findCursorCache = new Map<string, FindCursor>();
let findCursorCounter = 0;

function storeFindCursor(cursor: FindCursor): string {
  const id = `${++findCursorCounter}`;
  findCursorCache.set(id, cursor);
  return id;
}

function getFindCursor(id: string) {
  return findCursorCache.get(id);
}

/** Map Grok Grep/Glob args to FFF path constraints */
function grepPathConstraint(path?: string, include?: string): string | undefined {
  const p = path?.trim();
  const inc = include?.trim();
  if (inc && (!p || p === ".")) return inc;
  if (inc && p) return `${p.replace(/\/?$/, "/")}${inc.startsWith("**") ? inc : `**/${inc}`}`;
  if (p && p !== ".") return p;
  return undefined;
}

function globPatternFromGrok(pattern: string, glob_pattern?: string): string {
  return (pattern?.trim() || glob_pattern?.trim() || "**/*") as string;
}

export default function grokFffSearchBridge(pi: ExtensionAPI) {
  registerGrokCli(pi);

  let finder: FileFinder | null = null;
  let finderCwd: string | null = null;
  let finderPromise: Promise<FileFinder> | null = null;
  let activeCwd = process.cwd();

  const frecencyDbPath = process.env.FFF_FRECENCY_DB;
  const historyDbPath = process.env.FFF_HISTORY_DB;

  function ensureFinder(cwd: string): Promise<FileFinder> {
    if (finder && !finder.isDestroyed && finderCwd === cwd) return Promise.resolve(finder);
    if (finderPromise) return finderPromise;

    finderPromise = (async () => {
      if (finder && !finder.isDestroyed) {
        finder.destroy();
        finder = null;
        finderCwd = null;
      }

      const result = FileFinder.create({
        basePath: cwd,
        frecencyDbPath,
        historyDbPath,
        aiMode: true,
      });

      if (!result.ok) throw new Error(`FFF init failed: ${result.error}`);

      finder = result.value;
      finderCwd = cwd;
      await finder.waitForScan(15000);
      return finder;
    })().finally(() => {
      finderPromise = null;
    });

    return finderPromise;
  }

  pi.on("session_start", async (_event, ctx) => {
    activeCwd = ctx.cwd;
    try {
      await ensureFinder(activeCwd);
    } catch (e: unknown) {
      ctx.ui.notify(
        `grok-fff-search: FFF init failed (${e instanceof Error ? e.message : String(e)}). Install npm:@ff-labs/pi-fff.`,
        "warning",
      );
    }
  });

  pi.on("session_shutdown", () => {
    if (finder && !finder.isDestroyed) {
      finder.destroy();
      finder = null;
      finderCwd = null;
    }
  });

  const GrepParams = Type.Object({
    pattern: Type.String({ description: "Regex pattern to search for in file contents" }),
    path: Type.Optional(
      Type.String({
        description: "Directory or file to search. Defaults to current working directory.",
      }),
    ),
    include: Type.Optional(
      Type.String({
        description: "Glob pattern to filter which files are searched (e.g. *.ts, **/*.md)",
      }),
    ),
    glob_filter: Type.Optional(Type.String({ description: "Alias for include (Grok/Cursor)" })),
    limit: Type.Optional(Type.Number()),
    cursor: Type.Optional(Type.String()),
  });

  pi.registerTool({
    name: "Grep",
    label: "Grep",
    description:
      "Search for a regex pattern in file contents (FFF-powered). Returns matching lines with file path and line number.",
    parameters: GrepParams,

    prepareArguments(args) {
      const a = args as Record<string, unknown>;
      const pattern = String(a.pattern ?? "");
      const include =
        (a.include as string | undefined) ?? (a.glob_filter as string | undefined);
      return {
        pattern,
        path: a.path as string | undefined,
        include,
        glob_filter: a.glob_filter as string | undefined,
        limit: a.limit as number | undefined,
        cursor: a.cursor as string | undefined,
      };
    },

    async execute(_id, params, signal) {
      if (signal?.aborted) throw new Error("Operation aborted");

      const f = await ensureFinder(activeCwd);
      const effectiveLimit = Math.max(1, params.limit ?? DEFAULT_GREP_LIMIT);
      const pathConstraint = grepPathConstraint(params.path, params.include);
      const query = buildQuery(pathConstraint, params.pattern, undefined, activeCwd);

      const hasRegexSyntax =
        params.pattern !== params.pattern.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      let mode: GrepMode = hasRegexSyntax ? "regex" : "plain";
      if (mode === "regex") {
        try {
          new RegExp(params.pattern);
        } catch {
          mode = "plain";
        }
      }

      const grepResult = f.grep(query, {
        mode,
        smartCase: true,
        maxMatchesPerFile: Math.min(effectiveLimit, 50),
        cursor: (params.cursor ? getCursor(params.cursor) : null) ?? null,
        beforeContext: 0,
        afterContext: 0,
        classifyDefinitions: true,
      });

      if (!grepResult.ok) throw new Error(grepResult.error);

      let result = grepResult.value;
      let fuzzyNotice: string | null = null;

      if (result.items.length === 0 && !params.cursor && mode !== "regex") {
        const fuzzy = f.grep(params.pattern, {
          mode: "fuzzy",
          smartCase: true,
          maxMatchesPerFile: Math.min(effectiveLimit, 50),
          cursor: null,
          beforeContext: 0,
          afterContext: 0,
          classifyDefinitions: true,
        });
        if (fuzzy.ok && fuzzy.value.items.length > 0) {
          fuzzyNotice = "0 exact matches. Maybe you meant this?";
          result = fuzzy.value;
        }
      }

      let output = formatGrepOutput(result);
      const notices: string[] = [];
      if (result.nextCursor) {
        notices.push(`Continue with cursor="${storeCursor(result.nextCursor)}"`);
      }
      if (notices.length > 0) output += `\n\n[${notices.join(". ")}]`;
      if (fuzzyNotice) output = `[${fuzzyNotice}]\n${output}`;

      return {
        content: [{ type: "text", text: output }],
        details: { matchCount: result.totalMatched, engine: "fff" },
      };
    },

    renderCall(args, theme) {
      const text = new Text("", 0, 0);
      const path = args.path ? theme.fg("muted", ` in ${args.path}`) : "";
      const include = args.include ? theme.fg("dim", ` [${args.include}]`) : "";
      text.setText(
        theme.fg("toolTitle", theme.bold("Grep ")) +
          theme.fg("accent", `"${args.pattern}"`) +
          path +
          include +
          theme.fg("dim", " (fff)"),
      );
      return text;
    },
  });

  const GlobParams = Type.Object({
    pattern: Type.String({
      description: "Glob pattern to match files (e.g. **/*.ts, src/**/*.json)",
    }),
    path: Type.Optional(
      Type.String({
        description: "Directory to search within. Defaults to current working directory.",
      }),
    ),
    glob_pattern: Type.Optional(Type.String({ description: "Alias for pattern (Grok/Cursor)" })),
    limit: Type.Optional(Type.Number()),
    cursor: Type.Optional(Type.String()),
  });

  pi.registerTool({
    name: "Glob",
    label: "Glob",
    description:
      "Find files matching a glob pattern (FFF-powered). Frecency-ranked paths.",
    parameters: GlobParams,

    prepareArguments(args) {
      const a = args as Record<string, unknown>;
      const pattern = globPatternFromGrok(
        a.pattern as string,
        a.glob_pattern as string | undefined,
      );
      return { ...a, pattern };
    },

    async execute(_id, params, signal) {
      if (signal?.aborted) throw new Error("Operation aborted");

      const f = await ensureFinder(activeCwd);
      const resumed = params.cursor ? getFindCursor(params.cursor) : undefined;
      const effectiveLimit = resumed
        ? resumed.pageSize
        : Math.max(1, params.limit ?? DEFAULT_FIND_LIMIT);
      const pattern = resumed ? resumed.pattern : params.pattern;
      const pathConstraint =
        resumed?.query !== undefined
          ? undefined
          : params.path && params.path !== "."
            ? params.path
            : undefined;

      const query = resumed
        ? resumed.query
        : buildQuery(pathConstraint, pattern, undefined, activeCwd);
      const pageIndex = resumed?.nextPageIndex ?? 0;

      const searchResult = f.fileSearch(query, {
        pageIndex,
        pageSize: effectiveLimit,
      });
      if (!searchResult.ok) throw new Error(searchResult.error);

      const result = searchResult.value;
      const formatted = formatFindOutput(result, effectiveLimit, pattern);
      let output = formatted.output;

      const shownSoFar = pageIndex * effectiveLimit + result.items.length;
      const hasMore =
        result.items.length >= effectiveLimit && result.totalMatched > shownSoFar;

      const notices: string[] = [];
      if (formatted.weak && formatted.shownCount > 0) {
        notices.push(
          `Query "${pattern}" produced only weak fuzzy matches. Output capped at ${formatted.shownCount}/${result.totalMatched}.`,
        );
      }
      if (!formatted.weak && hasMore) {
        const remaining = result.totalMatched - shownSoFar;
        const cursorId = storeFindCursor({
          query,
          pattern,
          pageSize: effectiveLimit,
          nextPageIndex: pageIndex + 1,
        });
        notices.push(
          `${remaining} more match${remaining === 1 ? "" : "es"} available. cursor="${cursorId}" to continue`,
        );
      }
      if (notices.length > 0) output += `\n\n[${notices.join(". ")}]`;

      return {
        content: [{ type: "text", text: output }],
        details: { fileCount: result.items.length, engine: "fff" },
      };
    },

    renderCall(args, theme) {
      const text = new Text("", 0, 0);
      const path = args.path ? theme.fg("muted", ` in ${args.path}`) : "";
      text.setText(
        theme.fg("toolTitle", theme.bold("Glob ")) +
          theme.fg("accent", args.pattern) +
          path +
          theme.fg("dim", " (fff)"),
      );
      return text;
    },
  });
}