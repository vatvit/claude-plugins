---
name: session-storage
description: Use this skill when you need to store, retrieve, or clear session-scoped key-value data. Activate when the user asks to "store value", "save session data", "clear storage", "get session key", or similar. Also use proactively when you need to persist data within a session (e.g., tracking state across context resets).
version: 1.0.0
---

# Session Storage

Store and retrieve key-value data scoped to the current Claude Code session. Data is session-specific — other sessions cannot see or modify it. All data auto-cleans when the session ends.

## How It Works

The SessionStart hook injects your `session_id` into context. Use the storage script to manage keys:

```bash
# Store a value
bash <PLUGIN_ROOT>/scripts/storage.sh set <session_id> <key> <value>

# Retrieve a value
bash <PLUGIN_ROOT>/scripts/storage.sh get <session_id> <key>

# Clear a specific key
bash <PLUGIN_ROOT>/scripts/storage.sh clear <session_id> <key>

# Clear all keys for this session
bash <PLUGIN_ROOT>/scripts/storage.sh clear <session_id>

# List all keys for this session
bash <PLUGIN_ROOT>/scripts/storage.sh list <session_id>
```

Replace `<PLUGIN_ROOT>` with the actual plugin path and `<session_id>` with the session ID injected by the SessionStart hook.

## When to Use

- **Tracking context**: Store any key-value pair relevant to the session (task ID, branch name, debug target, etc.)
- **Persisting across context resets**: Data survives `/compact` and context compression
- **Session end**: All keys auto-clear via SessionEnd hook, no manual cleanup needed

## Guidelines

- Use descriptive key names
- Don't store sensitive data — storage is plain text in `/tmp`

## Storage

Keys are stored as plain text files in `/tmp/claude-session-storage/{session_id}/{key}`. Files are:
- Created on `storage.sh set`
- Deleted on `storage.sh clear` or session end
- Auto-cleaned after 24 hours (stale session cleanup in SessionEnd hook)
