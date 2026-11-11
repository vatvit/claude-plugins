#!/usr/bin/env bash
# Shared by storage.sh and the two hooks. Source it, don't execute it.

# The storage root: per-session dirs live under it, one file per key.
SS_STORAGE_DIR="${CLAUDE_CODE_TMPDIR:-/tmp}/claude-session-storage"

# ss_safe_name <s> -> 0 when <s> is usable as one path part: letters, digits, `.`, `_`, `-`,
# no leading dot (so never `.` or `..`, and never a hidden file `list` skips), at most 128
# characters. Session ids and keys are both checked with it before they touch a path: an
# unchecked `../claude-session-storage` turns `clear` into removing every session (PLUG-132).
ss_safe_name() {
    case "$1" in ''|.*|*[!A-Za-z0-9._-]*) return 1 ;; esac
    [ "${#1}" -le 128 ]
}

# ss_json_session_id -> the "session_id" string of the hook's JSON on stdin, or nothing.
# Plain grep + sed, no jq: a host without jq used to get no session id at all.
ss_json_session_id() {
    tr '\n\r' '  ' | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 \
        | sed 's/.*:[[:space:]]*"//; s/"$//' || true
}

# ss_mtime <path> -> its mtime in epoch seconds. GNU/busybox `stat -c` first: their
# `stat -f` is filesystem status and does not fail cleanly (root CLAUDE.md, File mtime).
ss_mtime() {
    stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}
