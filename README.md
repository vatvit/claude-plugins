# Session Notation Plugin for Claude Code

A Claude Code plugin that enables session-specific custom notations in the status line. Claude can set a label (task name, debug context, feature area) that's visible only in the current session and auto-cleans when the session ends.

## What It Does

```
📁 ~/project   🌿 main   +42 -10   📋 TASK-450   🏷️ Debugging texture pipeline   ctx: 15%
                                                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                                   This is the session notation
```

- **Session-scoped**: Each session has its own notation, invisible to other sessions
- **Auto-cleanup**: Notation is removed when the session ends
- **Stale protection**: Files older than 24h are auto-purged
- **Proactive**: Claude sets notations automatically when starting focused work

## Installation

### Option 1: Test directly

```bash
claude --plugin-dir ~/projects/vatvit/claude-plugin-session-storage
```

### Option 2: Install permanently

```bash
# Not yet published to a marketplace — use plugin-dir for now
```

## Status Line Integration

This plugin provides the notation **storage and hooks** but does NOT override your status line. You need to add the notation segment to your existing status line script.

### Add to your existing `statusline-command.sh`

Add these lines to your status line script (after parsing `input`):

```bash
# Session notation (from session-notation plugin)
session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)
if [ -n "$session_id" ]; then
  notation_file="/tmp/claude-notations/${session_id}"
  if [ -f "$notation_file" ]; then
    notation=$(cat "$notation_file" 2>/dev/null)
    if [ -n "$notation" ]; then
      out+="$(printf "   \033[1m🏷️  %s\033[0m" "$notation")"
    fi
  fi
fi
```

### Or use the standalone segment

```bash
# Pipe the same JSON input to the segment script
notation=$(echo "$input" | bash /path/to/plugin/scripts/statusline-segment.sh)
[ -n "$notation" ] && out+="   $notation"
```

## Components

### Hooks

| Event | Script | Purpose |
|-------|--------|---------|
| `SessionStart` | `scripts/capture-session.sh` | Captures `session_id`, injects into Claude's context |
| `SessionEnd` | `scripts/cleanup-session.sh` | Removes notation file, cleans stale files |

### Command

`/notation [set <text> | clear | get]` — Manual control over the notation.

### Skill

The `session-notation` skill activates automatically when Claude starts focused work, sets appropriate notations, and updates them as context shifts.

### Scripts

| Script | Purpose |
|--------|---------|
| `scripts/notation.sh` | Core CLI: set/clear/get/list/cleanup |
| `scripts/capture-session.sh` | SessionStart hook handler |
| `scripts/cleanup-session.sh` | SessionEnd hook handler |
| `scripts/statusline-segment.sh` | Status line segment (standalone or embeddable) |

## How It Works

```
┌─────────────────┐
│  Session Start   │
│  (hook fires)    │
└────────┬────────┘
         │ captures session_id
         │ injects into Claude's context
         ▼
┌─────────────────┐
│  Claude works    │──→ bash notation.sh set <id> "Task: TASK-450"
│  sets notation   │         │
└────────┬────────┘         ▼
         │         ┌─────────────────────┐
         │         │ /tmp/claude-notations│
         │         │   └── {session_id}   │ ← plain text file
         │         └──────────┬──────────┘
         │                    │
         ▼                    ▼
┌─────────────────┐  ┌──────────────────┐
│  Status line     │←─│ Reads notation   │
│  displays 🏷️     │  │ for session_id   │
└─────────────────┘  └──────────────────┘
         │
         ▼
┌─────────────────┐
│  Session End     │
│  (hook fires)    │──→ removes /tmp/claude-notations/{session_id}
└─────────────────┘
```

## Storage

- **Location**: `/tmp/claude-notations/`
- **Format**: One file per session, named by `session_id`, containing plain text
- **Hidden files**: `.current_session` stores the last session_id (fallback discovery)
- **Cleanup**: SessionEnd removes the file; stale files (>24h) auto-purge

## Requirements

- Claude Code with hooks support
- `jq` (for JSON parsing in hook scripts)
- `bash` (POSIX-compatible shell)

## License

MIT
