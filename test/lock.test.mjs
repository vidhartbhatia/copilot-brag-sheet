import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, mkdirSync, readFileSync, statSync, utimesSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { mkdtempSync } from "node:fs";
import { withFileLock } from "../lib/lock.mjs";

function makeTempDir() {
  return mkdtempSync(join(tmpdir(), "copilot-brag-sheet-lock-"));
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

test("withFileLock acquires and releases lock file", async () => {
  const tempDir = makeTempDir();
  const lockPath = join(tempDir, "tracker.lock");

  await withFileLock(lockPath, async () => {
    assert.equal(existsSync(lockPath), true);
    const stats = statSync(lockPath);
    assert.equal(stats.isFile(), true);
  });

  assert.equal(existsSync(lockPath), false);
});

test("withFileLock writes the current pid to the lock file", async () => {
  const tempDir = makeTempDir();
  const lockPath = join(tempDir, "tracker.lock");

  await withFileLock(lockPath, async () => {
    assert.equal(readFileSync(lockPath, "utf8"), `${process.pid}`);
  });
});

test("withFileLock throws on timeout and does not run the callback", async () => {
  const tempDir = makeTempDir();
  const lockPath = join(tempDir, "tracker.lock");
  let ran = false;

  writeFileSync(lockPath, `${process.pid}`);

  await assert.rejects(
    () =>
      withFileLock(
        lockPath,
        async () => {
          ran = true;
        },
        { timeoutMs: 200, retryMs: 25, staleMs: 10_000 },
      ),
    /Timed out acquiring file lock/,
  );

  assert.equal(ran, false);
  assert.equal(existsSync(lockPath), true);
});

test("withFileLock recovers stale dead-process locks", async () => {
  const tempDir = makeTempDir();
  const lockPath = join(tempDir, "tracker.lock");

  writeFileSync(lockPath, "999999");
  mkdirSync(join(tempDir, "touch"), { recursive: true });

  const staleDate = new Date(Date.now() - 60_000);
  utimesSync(lockPath, staleDate, staleDate);

  const result = await withFileLock(
    lockPath,
    async () => {
      assert.equal(readFileSync(lockPath, "utf8"), `${process.pid}`);
      return "recovered";
    },
    { timeoutMs: 500, retryMs: 25, staleMs: 100 },
  );

  assert.equal(result, "recovered");
  assert.equal(existsSync(lockPath), false);
});

test("withFileLock serializes concurrent access", async () => {
  const tempDir = makeTempDir();
  const lockPath = join(tempDir, "tracker.lock");
  let active = 0;
  let maxActive = 0;
  const order = [];
  let releaseFirstEnter;
  const firstEntered = new Promise((resolve) => {
    releaseFirstEnter = resolve;
  });

  const first = withFileLock(lockPath, async () => {
    order.push("first-start");
    active += 1;
    maxActive = Math.max(maxActive, active);
    releaseFirstEnter();
    await sleep(150);
    active -= 1;
    order.push("first-end");
  });

  await firstEntered;

  const second = withFileLock(lockPath, async () => {
    order.push("second-start");
    active += 1;
    maxActive = Math.max(maxActive, active);
    await sleep(25);
    active -= 1;
    order.push("second-end");
  });

  await Promise.all([first, second]);

  assert.equal(maxActive, 1);
  assert.deepEqual(order, ["first-start", "first-end", "second-start", "second-end"]);
  assert.equal(existsSync(lockPath), false);
});

test("withFileLock returns the callback return value", async () => {
  const tempDir = makeTempDir();
  const lockPath = join(tempDir, "tracker.lock");

  const result = await withFileLock(lockPath, async () => ({ ok: true }));

  assert.deepEqual(result, { ok: true });
});

test("withFileLock propagates callback errors and still releases the lock", async () => {
  const tempDir = makeTempDir();
  const lockPath = join(tempDir, "tracker.lock");

  await assert.rejects(
    () =>
      withFileLock(lockPath, async () => {
        throw new Error("boom");
      }),
    /boom/,
  );

  assert.equal(existsSync(lockPath), false);
});
