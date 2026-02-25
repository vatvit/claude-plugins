# Session Storage Plugin for Claude Code

A Claude Code plugin that provides session-scoped key-value storage. Store and retrieve data tied to individual sessions — it auto-cleans when the session ends.

## Features

- **Session-scoped**: Each session has isolated key-value storage
- **Multi-key**: Store multiple values per session
- **Auto-cleanup**: All keys removed when the session ends
- **Stale protection**: Session directories older than 24h are auto-purged

## Installation

### Option 1: Test directly

```bash
claude --plugin-dir ~/projects/vatvit/claude-plugin-session-storage
```

### Option 2: Install permanently

```bash
# Not yet published to a marketplace — use plugin-dir for now
```

## CLI Usage

```bash
# Store a value
bash scripts/storage.sh set <session_id> <key> <value>

# Retrieve a value
bash scripts/storage.sh get <session_id> <key>

# Clear a specific key
bash scripts/storage.sh clear <session_id> <key>

# Clear all keys for a session
bash scripts/storage.sh clear <session_id>

# List keys for a session
bash scripts/storage.sh list <session_id>

# List all active sessions
bash scripts/storage.sh list

# Remove stale sessions (default: 24h)
bash scripts/storage.sh cleanup [hours]
```

## Components

### Hooks

| Event | Script | Purpose |
|-------|--------|---------|
| `SessionStart` | `scripts/capture-session.sh` | Captures `session_id`, creates session directory, injects storage instructions into Claude's context |
| `SessionEnd` | `scripts/cleanup-session.sh` | Removes session directory, cleans stale sessions |

### Skill

The `session-storage` skill tells Claude how and when to use key-value storage within a session.

### Scripts

| Script | Purpose |
|--------|---------|
| `scripts/storage.sh` | Core CLI: set/get/clear/list/cleanup for key-value storage |
| `scripts/capture-session.sh` | SessionStart hook handler |
| `scripts/cleanup-session.sh` | SessionEnd hook handler |

## How It Works

```
┌─────────────────┐
│  Session Start   │
│  (hook fires)    │
└────────┬────────┘
         │ captures session_id
         │ creates session dir
         │ injects storage instructions into context
         ▼
┌─────────────────┐
│  Claude works    │──→ bash storage.sh set <id> task-id "TASK-450"
│  stores values   │──→ bash storage.sh set <id> branch "feature/retarget"
│  reads values    │──→ bash storage.sh get <id> task-id
└────────┬────────┘         │
         │         ┌────────────────────────────┐
         │         │ /tmp/claude-session-storage │
         │         │   └── {session_id}/         │
         │         │       ├── task-id           │ ← plain text files
         │         │       └── branch            │
         │         └────────────────────────────┘
         │
         ▼
┌─────────────────┐
│  Session End     │
│  (hook fires)    │──→ removes /tmp/claude-session-storage/{session_id}/
└─────────────────┘
```

## Storage

- **Location**: `$CLAUDE_CODE_TMPDIR/claude-session-storage/` (falls back to `/tmp/claude-session-storage/` if unset)
- **Format**: One directory per session (named by `session_id`), one file per key containing plain text
- **Hidden files**: `.current_session` stores the last session_id (fallback discovery)
- **Cleanup**: SessionEnd removes the session directory; stale sessions (>24h) auto-purge

## Environment Variables

| Variable | Description |
|----------|-------------|
| `CLAUDE_CODE_TMPDIR` | Override the base temp directory (default: `/tmp`). Storage goes to `$CLAUDE_CODE_TMPDIR/claude-session-storage/`. |

## Requirements

- Claude Code with hooks support
- `jq` (for JSON parsing in hook scripts)
- `bash` (POSIX-compatible shell)

## License

MIT
