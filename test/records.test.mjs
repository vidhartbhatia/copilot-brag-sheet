import test from "node:test";
import assert from "node:assert/strict";

import {
  addFileToRecord,
  createEntryRecord,
  createSessionRecord,
  dedupeArray,
  sanitize,
  validateCategory,
  validateSessionId
} from "../lib/records.mjs";

test("createSessionRecord returns expected defaults", () => {
  const record = createSessionRecord("session-123", "C:\\repo");

  assert.equal(record.id, "session-123");
  assert.equal(record.type, "session");
  assert.equal(record.source, "copilot-cli");
  assert.equal(record.endTime, null);
  assert.equal(record.repo, null);
  assert.equal(record.repoFull, null);
  assert.equal(record.branch, null);
  assert.equal(record.cwd, "C:\\repo");
  assert.deepEqual(record.filesEdited, []);
  assert.deepEqual(record.filesCreated, []);
  assert.deepEqual(record.prsCreated, []);
  assert.deepEqual(record.significantActions, []);
  assert.equal(record.summary, null);
  assert.equal(record.taskDescription, null);
  assert.equal(record.category, null);
  assert.deepEqual(record.tags, []);
  assert.equal(record.impact, null);
  assert.equal(record.status, "active");
  assert.equal(record.pid, process.pid);
  assert.match(record.timestamp, /^\d{4}-\d{2}-\d{2}T/);
});

test("createEntryRecord generates UUID and sanitizes text", () => {
  const record = createEntryRecord({
    summary: "# shipped\nfeature | today",
    category: "pr",
    tags: ["release"],
    impact: "impact\nline",
    repo: "copilot-brag-sheet",
    branch: "main",
    sessionId: "session-123"
  });

  assert.equal(record.type, "entry");
  assert.equal(record.source, "manual");
  assert.match(record.id, /^[0-9a-f-]{36}$/i);
  assert.equal(record.summary, "shipped feature \\| today");
  assert.equal(record.category, "pr");
  assert.deepEqual(record.tags, ["release"]);
  assert.equal(record.impact, "impact line");
  assert.equal(record.repo, "copilot-brag-sheet");
  assert.equal(record.branch, "main");
  assert.equal(record.sessionId, "session-123");
  assert.match(record.timestamp, /^\d{4}-\d{2}-\d{2}T/);
});

test("sanitize handles nullish, pipes, newlines, headings, reserved markers, truncation, and unicode", () => {
  assert.equal(sanitize(null), "");
  assert.equal(sanitize(undefined), "");
  assert.equal(sanitize("# Heading"), "Heading");
  assert.equal(sanitize("hello\r\nworld"), "hello world");
  assert.equal(sanitize("a|b"), "a\\|b");
  assert.equal(sanitize("WEEKLY_ENTRIES_START hello WEEKLY_ENTRIES_END"), "hello");
  assert.equal(sanitize("🚀 café"), "🚀 café");

  const longValue = `# ${"x".repeat(600)}`;
  assert.equal(sanitize(longValue).length, 500);
});

test("validateSessionId accepts safe IDs and rejects traversal", () => {
  assert.equal(validateSessionId("session_123-abc"), true);
  assert.throws(() => validateSessionId("../escape"), /Invalid session ID/);
  assert.throws(() => validateSessionId("space bad"), /Invalid session ID/);
});

test("validateCategory checks membership", () => {
  assert.equal(validateCategory("pr", ["pr", "bugfix"]), true);
  assert.equal(validateCategory("design", ["pr", "bugfix"]), false);
});

test("dedupeArray removes duplicates", () => {
  assert.deepEqual(dedupeArray(["a", "b", "a"]), ["a", "b"]);
});

test("addFileToRecord stores relative paths, dedupes, skips .copilot state, and normalizes separators", () => {
  const isWin = process.platform === "win32";
  const repoRoot = isWin ? "C:\\repo" : "/home/user/repo";
  const srcFile = isWin ? "C:\\repo\\src\\index.mjs" : "/home/user/repo/src/index.mjs";
  const testFile = isWin ? "C:\\repo\\test\\new.test.mjs" : "/home/user/repo/test/new.test.mjs";
  const copilotFile = isWin
    ? "C:\\Users\\testuser\\.copilot\\session-state\\abc\\plan.md"
    : "/home/user/.copilot/session-state/abc/plan.md";

  const record = createSessionRecord("session-456", repoRoot);

  addFileToRecord(record, "edit", srcFile, repoRoot);
  addFileToRecord(record, "edit", srcFile, repoRoot);
  addFileToRecord(record, "create", testFile, repoRoot);
  addFileToRecord(record, "edit", copilotFile, repoRoot);

  assert.deepEqual(record.filesEdited, ["src/index.mjs"]);
  assert.deepEqual(record.filesCreated, ["test/new.test.mjs"]);
});

test("addFileToRecord preserves absolute paths outside repo root", () => {
  const isWin = process.platform === "win32";
  const repoRoot = isWin ? "C:\\repo" : "/home/user/repo";
  const outsideFile = isWin ? "D:\\other\\file.txt" : "/tmp/other/file.txt";
  const expectedPath = isWin ? "D:/other/file.txt" : "/tmp/other/file.txt";

  const record = createSessionRecord("session-789", repoRoot);

  addFileToRecord(record, "edit", outsideFile, repoRoot);

  assert.deepEqual(record.filesEdited, [expectedPath]);
});
