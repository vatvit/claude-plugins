---
name: session-notation
description: Use this skill when you need to set, update, or clear a custom notation in the Claude Code status line. Activate when starting focused work on a task, switching context, or when the user asks to "set notation", "update status", "mark session", "label session", or "clear notation". Also activate proactively at session start when a task is identified.
version: 1.0.0
---

# Session Notation

Set a custom label in the Claude Code status line that is visible for the duration of this session. The notation is session-specific — other sessions cannot see or modify it.

## How It Works

The SessionStart hook injects your `session_id` into context. Use the notation script to set/clear text:

```bash
# Set notation (appears as 🏷️ in the status line)
bash <PLUGIN_ROOT>/scripts/notation.sh set <session_id> "Your text here"

# Clear notation
bash <PLUGIN_ROOT>/scripts/notation.sh clear <session_id>

# Check current notation
bash <PLUGIN_ROOT>/scripts/notation.sh get <session_id>
```

Replace `<PLUGIN_ROOT>` with the actual plugin path and `<session_id>` with the session ID injected by the SessionStart hook.

## When to Set Notation

- **Starting a task**: Set the task ID or title (e.g., "TASK-450: Retarget fix")
- **Focused debugging**: Set the area being investigated (e.g., "Debug: texture pipeline")
- **Context switch**: Update when moving to a different area of work
- **Session end**: The notation auto-clears via SessionEnd hook, no manual cleanup needed

## Guidelines

- Keep notations short (under 40 characters) — they share space with other status line segments
- Use descriptive text: task IDs, feature names, or activity labels
- Update the notation when focus shifts significantly
- Don't set notation for trivial/quick interactions

## Status Line Integration

The notation appears as a `🏷️` segment in the status line. Users must integrate the `statusline-segment.sh` into their existing status line script. See README.md for integration instructions.

## Storage

Notations are stored as plain text files in `/tmp/claude-notations/{session_id}`. Files are:
- Created on `notation.sh set`
- Deleted on `notation.sh clear` or session end
- Auto-cleaned after 24 hours (stale file cleanup in SessionEnd hook)
