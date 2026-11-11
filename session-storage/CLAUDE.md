# CLAUDE.md

This file provides guidance to Claude Code when working on the session-storage plugin.

## What This Is

A Claude Code plugin providing session-scoped key-value storage. Each session gets isolated storage that auto-cleans on session end.

## Architecture

Pure shell-based Claude Code plugin — no build step, no npm, no compiled code.

### Plugin Structure

- `.claude-plugin/plugin.json` — Plugin manifest (name: `session-storage`)
- `hooks/hooks.json` — Declares `SessionStart` and `SessionEnd` lifecycle hooks
- `scripts/` — All executable logic:
  - `storage.sh` — Core CLI with subcommands: `set <session_id> <key> <value>`, `get`, `clear`, `list`, `cleanup`
  - `capture-session.sh` — SessionStart hook: captures `session_id`, creates session dir, injects storage instructions into Claude's context via `hookSpecificOutput.additionalContext`
  - `cleanup-session.sh` — SessionEnd hook: removes session directory, prunes stale sessions >24h
  - `lib.sh` — sourced by all three: the storage root, `ss_safe_name` (the one check a session id or key passes before it touches a path), `ss_json_session_id` (the hook input, no jq), `ss_mtime`
- `skills/session-storage/SKILL.md` — Skill definition for proactive key-value storage use

### Data Flow

1. **SessionStart** hook → `capture-session.sh` reads JSON from stdin, extracts `session_id`, creates `/tmp/claude-session-storage/{session_id}/` dir, returns JSON with `additionalContext` injecting the session_id and storage commands into Claude's context
2. **Claude stores data** → runs `storage.sh set <session_id> <key> <value>` → writes plain text to `/tmp/claude-session-storage/{session_id}/{key}`
3. **Claude reads data** → runs `storage.sh get <session_id> <key>`
4. **SessionEnd** hook → `cleanup-session.sh` removes the session directory

### Storage Layout

```
$CLAUDE_CODE_TMPDIR/claude-session-storage/   (falls back to /tmp/ if unset)
├── .current_session          ← last-known session_id (fallback)
├── {session_id_1}/
│   ├── task-id               ← any arbitrary keys
│   └── branch
└── {session_id_2}/
    └── ...
```

## Key Conventions

- Hook scripts receive JSON on stdin and output JSON on stdout
- `${CLAUDE_PLUGIN_ROOT}` in `hooks.json` is resolved by Claude Code at runtime
- No jq: the hooks read `session_id` with grep + sed (`ss_json_session_id`); the repo is pure bash + awk
- **A session id or key is a path part only after `ss_safe_name`.** Unchecked, `clear ../claude-session-storage` or a SessionEnd input naming it removed every session (PLUG-132). Hooks given a bad id exit 0 and say so on stderr
- File mtime via `ss_mtime`: `stat -c %Y` first, then `stat -f %m` (root CLAUDE.md, *File mtime*)

## Testing Changes

```bash
bash scripts/test/storage.test.sh                                            # host
docker run --rm -v "$PWD":/w -w /w bash:5 bash scripts/test/storage.test.sh  # container
```

34 cases: the set/get/clear/list round trip, HOME unset (the plugin keeps nothing in HOME), an
unwritable storage dir (`set` fails plainly, never prints "Stored"; PLUG-122), session ids and keys that
would escape the storage dir, both hooks without jq (a fake `jq` that fails is first on PATH), hostile
ids in the hook input, and `list` with a GNU-like `stat` (PLUG-132). Manual checks:

```bash
# Test multi-key storage
bash scripts/storage.sh set test-session task-id "TASK-450"
bash scripts/storage.sh set test-session branch "feature/retarget"
bash scripts/storage.sh get test-session task-id
bash scripts/storage.sh get test-session branch
bash scripts/storage.sh list test-session
bash scripts/storage.sh list
bash scripts/storage.sh clear test-session task-id
bash scripts/storage.sh clear test-session

# Test hooks
echo '{"session_id":"test-123"}' | bash scripts/capture-session.sh
echo '{"session_id":"test-123"}' | bash scripts/cleanup-session.sh
```

## Loading as a Plugin

```bash
claude --plugin-dir /path/to/claude-plugins/session-storage
```
