#!/usr/bin/env node

/**
 * Setup script for copilot-brag-sheet.
 * Run with: npx copilot-brag-sheet
 *
 * Copies the extension into the Copilot CLI extensions directory.
 */

import { existsSync, mkdirSync, cpSync, writeFileSync, readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { homedir, platform } from "node:os";
import { fileURLToPath } from "node:url";
import { createInterface } from "node:readline";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PACKAGE_ROOT = join(__dirname, "..");
const EXT_NAME = "copilot-brag-sheet";

// Resolve Copilot extensions directory
const copilotHome = process.env.COPILOT_HOME || join(homedir(), ".copilot");
const targetDir = join(copilotHome, "extensions", EXT_NAME);

function ask(question) {
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

function getDataDir() {
  if (process.env.WORK_TRACKER_DIR) return process.env.WORK_TRACKER_DIR;
  const p = platform();
  if (p === "win32") {
    return join(process.env.LOCALAPPDATA || join(homedir(), "AppData", "Local"), EXT_NAME);
  }
  if (p === "darwin") {
    return join(homedir(), "Library", "Application Support", EXT_NAME);
  }
  return join(process.env.XDG_DATA_HOME || join(homedir(), ".local", "share"), EXT_NAME);
}

async function main() {
  console.log(`\nInstalling ${EXT_NAME}...\n`);

  // Verify we have the source files
  if (!existsSync(join(PACKAGE_ROOT, "extension.mjs"))) {
    console.error("Error: extension.mjs not found. Is the package intact?");
    process.exit(1);
  }

  // Clean previous install
  if (existsSync(targetDir)) {
    console.log("Removing previous installation...");
    // Use recursive rm via cpSync overwrite
    const { rmSync } = await import("node:fs");
    rmSync(targetDir, { recursive: true, force: true });
  }

  // Copy extension files
  mkdirSync(join(targetDir, "lib"), { recursive: true });

  const filesToCopy = [
    "extension.mjs",
    "package.json",
  ];

  for (const file of filesToCopy) {
    const src = join(PACKAGE_ROOT, file);
    if (existsSync(src)) {
      cpSync(src, join(targetDir, file));
    }
  }

  // Copy lib modules
  const libDir = join(PACKAGE_ROOT, "lib");
  if (existsSync(libDir)) {
    cpSync(libDir, join(targetDir, "lib"), { recursive: true });
  }

  console.log(`✅ Installed to: ${targetDir}\n`);

  // Optional Microsoft preset
  if (process.stdin.isTTY) {
    const response = await ask("Are you a Microsoft employee? (enables Connect review formatting) [y/N] ");
    if (/^[Yy]$/.test(response)) {
      const dataDir = getDataDir();
      mkdirSync(dataDir, { recursive: true });
      const configPath = join(dataDir, "config.json");

      // Merge with existing config if present
      let existing = {};
      if (existsSync(configPath)) {
        try { existing = JSON.parse(readFileSync(configPath, "utf8")); } catch { /* ignore */ }
      }
      existing.preset = "microsoft";
      writeFileSync(configPath, JSON.stringify(existing, null, 2));
      console.log(`  ✅ Microsoft preset enabled (${configPath})\n`);
    }
  }

  console.log("Next steps:");
  console.log("  1. Run /clear in the Copilot CLI or restart it");
  console.log('  2. Start a session — you\'ll see "📊 Work logger active"');
  console.log("");
  console.log(`To uninstall: rm -rf "${targetDir}"`);
}

main().catch((err) => {
  console.error(`Setup failed: ${err.message}`);
  process.exit(1);
});
