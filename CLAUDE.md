# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Claude Code plugin that enables session-specific custom notations in the status line. Each Claude session can set a label (task name, debug context, feature area) that only that session sees. Notations auto-clean when the session ends.

## Architecture

This is a **pure shell-based** Claude Code plugin — no build step, no npm, no compiled code. All logic is in bash scripts.

### Plugin Structure

- `.claude-plugin/plugin.json` — Plugin manifest (name, version, metadata)
- `hooks/hooks.json` — Declares `SessionStart` and `SessionEnd` lifecycle hooks
- `scripts/` — All executable logic:
  - `capture-session.sh` — SessionStart hook: captures `session_id` from stdin JSON, writes fallback file, injects `session_id` + usage instructions into Claude's context via `hookSpecificOutput.additionalContext`
  - `cleanup-session.sh` — SessionEnd hook: removes the session's notation file, prunes stale files >24h
  - `notation.sh` — Core CLI with subcommands: `set`, `clear`, `get`, `list`, `cleanup`
  - `statusline-segment.sh` — Reads session_id from stdin JSON, outputs formatted notation text for status line integration
- `skills/session-notation/SKILL.md` — Skill definition that tells Claude when/how to set notations proactively
- `commands/notation.md` — `/notation` command definition for manual control

### Data Flow

1. **SessionStart** hook fires → `capture-session.sh` reads JSON from stdin, extracts `session_id`, writes it to `/tmp/claude-notations/.current_session`, returns JSON with `additionalContext` that injects the session_id into Claude's context
2. **Claude sets notation** → runs `notation.sh set <session_id> <text>` → writes plain text to `/tmp/claude-notations/{session_id}`
3. **Status line reads** → `statusline-segment.sh` reads session_id from stdin JSON, reads the notation file, outputs formatted text
4. **SessionEnd** hook fires → `cleanup-session.sh` removes the notation file and prunes stale files

### Storage

All notation data lives in `/tmp/claude-notations/` as plain text files named by session_id. The `.current_session` hidden file stores the last-known session_id as a fallback.

## Key Conventions

- Hook scripts receive JSON on stdin (from Claude Code) and output JSON on stdout (back to Claude Code)
- The `${CLAUDE_PLUGIN_ROOT}` variable in `hooks.json` is resolved by Claude Code at runtime to the plugin's install directory
- Scripts use `jq` for JSON parsing — it's a required dependency
- Cross-platform: `stat` usage in `notation.sh list` handles both macOS (`-f %m`) and Linux (`-c %Y`) formats

## Testing Changes

No test framework. To test manually:

```bash
# Test notation CLI directly
bash scripts/notation.sh set test-session "Hello world"
bash scripts/notation.sh get test-session
bash scripts/notation.sh list
bash scripts/notation.sh clear test-session

# Test capture-session hook (simulate SessionStart input)
echo '{"session_id":"test-123"}' | bash scripts/capture-session.sh

# Test cleanup hook (simulate SessionEnd input)
echo '{"session_id":"test-123"}' | bash scripts/cleanup-session.sh

# Test statusline segment
echo '{"session_id":"test-123"}' | bash scripts/statusline-segment.sh
```

## Loading as a Plugin

```bash
claude --plugin-dir /path/to/this/repo
```
