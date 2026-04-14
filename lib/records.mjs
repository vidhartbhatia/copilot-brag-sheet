import path from "node:path";
import { randomUUID } from "node:crypto";

const RESERVED_MARKERS = ["WEEKLY_ENTRIES_START", "WEEKLY_ENTRIES_END"];
const SESSION_STATE_SEGMENT = ".copilot/session-state";

export function createSessionRecord(sessionId, cwd) {
  validateSessionId(sessionId);

  return {
    id: sessionId,
    type: "session",
    source: "copilot-cli",
    timestamp: new Date().toISOString(),
    endTime: null,
    repo: null,
    repoFull: null,
    branch: null,
    cwd: cwd || process.cwd(),
    filesEdited: [],
    filesCreated: [],
    prsCreated: [],
    significantActions: [],
    summary: null,
    taskDescription: null,
    category: null,
    tags: [],
    impact: null,
    status: "active",
    pid: process.pid
  };
}

export function createEntryRecord(args = {}) {
  return {
    id: randomUUID(),
    type: "entry",
    source: "manual",
    timestamp: new Date().toISOString(),
    summary: sanitize(args.summary),
    category: args.category || null,
    tags: Array.isArray(args.tags) ? [...args.tags] : [],
    impact: args.impact ? sanitize(args.impact) : null,
    repo: args.repo || null,
    branch: args.branch || null,
    sessionId: args.sessionId || null
  };
}

export function sanitize(text) {
  if (text === null || text === undefined) {
    return "";
  }

  let value = String(text);
  value = value.replace(/\r?\n/g, " ");

  for (const marker of RESERVED_MARKERS) {
    value = value.replaceAll(marker, "");
  }

  value = value.replace(/^\s*#+\s*/u, "");
  value = value.replace(/\|/g, "\\|");
  value = value.trim();

  if (value.length > 500) {
    value = value.slice(0, 500).trim();
  }

  return value;
}

export function validateSessionId(id) {
  if (!/^[\w-]+$/u.test(id)) {
    throw new Error("Invalid session ID");
  }

  return true;
}

export function validateCategory(category, validIds) {
  return Array.isArray(validIds) && validIds.includes(category);
}

export function dedupeArray(arr) {
  return [...new Set(Array.isArray(arr) ? arr : [])];
}

export function addFileToRecord(record, toolName, filePath, repoRoot) {
  if (!record || !filePath) {
    return record;
  }

  const absolutePath = path.resolve(filePath);
  const normalizedAbsolute = normalizePath(absolutePath).toLowerCase();
  if (normalizedAbsolute.includes(SESSION_STATE_SEGMENT)) {
    return record;
  }

  const targetKey = String(toolName || "").toLowerCase().includes("create")
    ? "filesCreated"
    : "filesEdited";

  const normalizedRepoRoot = repoRoot ? path.resolve(repoRoot) : null;
  let finalPath = absolutePath;

  if (normalizedRepoRoot) {
    const relativePath = path.relative(normalizedRepoRoot, absolutePath);
    if (relativePath && !relativePath.startsWith("..") && !path.isAbsolute(relativePath)) {
      finalPath = relativePath;
    }
  }

  record[targetKey] = dedupeArray([...(record[targetKey] || []), normalizePath(finalPath)]);
  return record;
}

function normalizePath(filePath) {
  return String(filePath).replace(/[\\/]+/g, "/");
}
