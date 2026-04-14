# Migration Guide: v1 → v2

## What changed

| | v1 | v2 |
|--|---|---|
| Package | `work-tracker` | `copilot-brag-sheet` |
| Install | Manual copy to `~/.copilot/extensions/` | `copilot plugin install vidhartbhatia/copilot-brag-sheet` |
| Data dir | `~/OneDrive*/Documents/work-tracker/` | OS app-data dir (configurable) |
| Storage | Flat `sessions/*.json` | Sharded `sessions/YYYY/MM/*.json` + `entries/YYYY/MM/*.json` |
| Markdown | Inline-edited `work-log.md` | Generated on-demand |
| Git backup | External repo copy | Data dir is the git repo |

## Migration Steps

### 1. Archive v1

```bash
# Rename the old extension (don't delete yet)
mv ~/.copilot/extensions/work-tracker ~/.copilot/extensions/work-tracker-v1-archived
```

Windows:
```powershell
Rename-Item "$env:USERPROFILE\.copilot\extensions\work-tracker" "work-tracker-v1-archived"
```

### 2. Install v2

```bash
copilot plugin install vidhartbhatia/copilot-brag-sheet
```

### 3. Point to your existing data (optional)

If you want to keep using your OneDrive location:

```bash
# Set in your shell profile (.bashrc, .zshrc, $PROFILE)
export WORK_TRACKER_DIR="$HOME/OneDrive - Microsoft/Documents/work-tracker"
```

Windows:
```powershell
# Add to $PROFILE
$env:WORK_TRACKER_DIR = "$env:USERPROFILE\OneDrive - Microsoft\Documents\work-tracker"
```

v2 will read your existing session JSONs — the session record format is backward-compatible.

### 4. Backfill entries from v1 sessions

v1 only had session records. v2 has a separate `entries/` for brag sheet items. To backfill:

```
Scan my old work-tracker sessions and create brag sheet entries for the significant ones.
Sessions are in ~/OneDrive - Microsoft/Documents/work-tracker/sessions/
```

### 5. Verify

Start a new Copilot CLI session. You should see:
```
📊 Work logger active
```

### 6. Clean up

Once confident v2 is working:
```bash
rm -rf ~/.copilot/extensions/work-tracker-v1-archived
```

## Data Format Compatibility

v2's `readRecords()` reads any JSON file with a `timestamp` field, so v1 session files work as-is. The only differences:

- v1 used `startTime` instead of `timestamp` — v2's orphan recovery handles both
- v1 stored sessions flat (`sessions/*.json`) — v2 uses sharded dirs (`sessions/YYYY/MM/`)
- v1 had no `entries/` directory — that's new in v2

To fully migrate v1 sessions into the v2 shard structure, you can ask the AI:
```
Move my old flat session files into the v2 sharded directory structure.
```
