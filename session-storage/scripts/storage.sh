#!/usr/bin/env bash
# storage.sh — Session-scoped key-value storage for Claude Code
#
# Usage:
#   storage.sh set <session_id> <key> <value>     — Store a value
#   storage.sh get <session_id> <key>              — Retrieve a value
#   storage.sh clear <session_id> [key]            — Clear one key or all keys for session
#   storage.sh list [session_id]                   — List sessions, or keys for a session
#   storage.sh cleanup [max_age_hours]             — Remove stale sessions (default: 24h)

BASE_TMP="${CLAUDE_CODE_TMPDIR:-/tmp}"
STORAGE_DIR="${BASE_TMP}/claude-session-storage"
mkdir -p "$STORAGE_DIR"

case "${1:-}" in
  set)
    session_id="$2"
    key="$3"
    shift 3
    value="$*"
    if [ -z "$session_id" ] || [ -z "$key" ] || [ -z "$value" ]; then
      echo "Usage: storage.sh set <session_id> <key> <value>" >&2
      exit 1
    fi
    mkdir -p "${STORAGE_DIR}/${session_id}"
    echo "$value" > "${STORAGE_DIR}/${session_id}/${key}"
    echo "Stored [${key}]: ${value}"
    ;;

  get)
    session_id="$2"
    key="$3"
    if [ -z "$session_id" ] || [ -z "$key" ]; then
      echo "Usage: storage.sh get <session_id> <key>" >&2
      exit 1
    fi
    file="${STORAGE_DIR}/${session_id}/${key}"
    if [ -f "$file" ]; then
      cat "$file"
    else
      echo "(no value set for key: ${key})"
    fi
    ;;

  clear)
    session_id="$2"
    key="${3:-}"
    if [ -z "$session_id" ]; then
      echo "Usage: storage.sh clear <session_id> [key]" >&2
      exit 1
    fi
    if [ -n "$key" ]; then
      rm -f "${STORAGE_DIR}/${session_id}/${key}"
      # Remove session dir if empty
      rmdir "${STORAGE_DIR}/${session_id}" 2>/dev/null
      echo "Cleared key: ${key}"
    else
      rm -rf "${STORAGE_DIR}/${session_id}"
      echo "Cleared all keys for session"
    fi
    ;;

  cleanup)
    max_age_hours="${2:-24}"
    find "$STORAGE_DIR" -mindepth 1 -maxdepth 1 -type d -not -name ".*" -mmin +$((max_age_hours * 60)) -exec rm -rf {} + 2>/dev/null
    remaining=$(find "$STORAGE_DIR" -mindepth 1 -maxdepth 1 -type d -not -name ".*" 2>/dev/null | wc -l | tr -d ' ')
    echo "Cleanup done. ${remaining} active session(s) remaining."
    ;;

  list)
    session_id="${2:-}"
    if [ -n "$session_id" ]; then
      # List keys for a specific session
      session_dir="${STORAGE_DIR}/${session_id}"
      if [ ! -d "$session_dir" ]; then
        echo "No storage for session: ${session_id}"
        exit 0
      fi
      files=$(find "$session_dir" -type f -not -name ".*" 2>/dev/null)
      if [ -z "$files" ]; then
        echo "No keys stored for session: ${session_id}"
      else
        echo "$files" | while read -r f; do
          key=$(basename "$f")
          value=$(cat "$f")
          echo "  ${key}: ${value}"
        done
      fi
    else
      # List all sessions
      dirs=$(find "$STORAGE_DIR" -mindepth 1 -maxdepth 1 -type d -not -name ".*" 2>/dev/null)
      if [ -z "$dirs" ]; then
        echo "No active sessions"
      else
        echo "$dirs" | while read -r d; do
          session=$(basename "$d")
          key_count=$(find "$d" -type f -not -name ".*" 2>/dev/null | wc -l | tr -d ' ')
          # macOS stat format
          if stat -f %m "$d" >/dev/null 2>&1; then
            age_min=$(( ($(date +%s) - $(stat -f %m "$d")) / 60 ))
          else
            # Linux stat format
            age_min=$(( ($(date +%s) - $(stat -c %Y "$d")) / 60 ))
          fi
          echo "  ${session}: ${key_count} key(s)  (${age_min}m ago)"
        done
      fi
    fi
    ;;

  *)
    echo "Usage: storage.sh {set|get|clear|list|cleanup}" >&2
    echo "" >&2
    echo "Commands:" >&2
    echo "  set <session_id> <key> <value>   Store a value" >&2
    echo "  get <session_id> <key>            Retrieve a value" >&2
    echo "  clear <session_id> [key]          Clear one key or all keys" >&2
    echo "  list [session_id]                 List sessions or keys" >&2
    echo "  cleanup [hours]                   Remove stale sessions (default: 24h)" >&2
    exit 1
    ;;
esac
