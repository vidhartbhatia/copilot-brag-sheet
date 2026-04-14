import {
  openSync,
  closeSync,
  writeFileSync,
  unlinkSync,
  statSync,
  readFileSync,
} from "node:fs";

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function isProcessAlive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) {
    return false;
  }

  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    return error?.code === "EPERM";
  }
}

function cleanupStaleLock(lockPath, staleMs) {
  let stats;

  try {
    stats = statSync(lockPath);
  } catch (error) {
    if (error?.code === "ENOENT") {
      return true;
    }

    throw error;
  }

  if (Date.now() - stats.mtimeMs <= staleMs) {
    return false;
  }

  let pid;

  try {
    pid = Number.parseInt(readFileSync(lockPath, "utf8").trim(), 10);
  } catch (error) {
    if (error?.code === "ENOENT") {
      return true;
    }

    throw error;
  }

  if (isProcessAlive(pid)) {
    return false;
  }

  try {
    unlinkSync(lockPath);
    return true;
  } catch (error) {
    if (error?.code === "ENOENT") {
      return true;
    }

    throw error;
  }
}

function createLock(lockPath) {
  const fd = openSync(lockPath, "wx");

  try {
    writeFileSync(fd, `${process.pid}`);
  } catch (error) {
    try {
      closeSync(fd);
    } catch {
      // Best effort cleanup.
    }

    try {
      unlinkSync(lockPath);
    } catch {
      // Best effort cleanup.
    }

    throw error;
  }

  closeSync(fd);
}

export async function withFileLock(lockPath, fn, options = {}) {
  const timeoutMs = options.timeoutMs ?? 5000;
  const retryMs = options.retryMs ?? 100;
  const staleMs = options.staleMs ?? 30000;
  const deadline = Date.now() + timeoutMs;

  while (true) {
    try {
      createLock(lockPath);
      break;
    } catch (error) {
      if (error?.code !== "EEXIST") {
        throw error;
      }

      cleanupStaleLock(lockPath, staleMs);

      if (Date.now() >= deadline) {
        throw new Error(`Timed out acquiring file lock: ${lockPath}`);
      }

      await sleep(Math.min(retryMs, Math.max(1, deadline - Date.now())));
    }
  }

  try {
    return await fn();
  } finally {
    try {
      unlinkSync(lockPath);
    } catch (error) {
      if (error?.code !== "ENOENT") {
        throw error;
      }
    }
  }
}
