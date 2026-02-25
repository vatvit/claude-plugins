#!/usr/bin/env bash
# Cleans up session-specific storage when a session ends.

BASE_TMP="${CLAUDE_CODE_TMPDIR:-/tmp}"
STORAGE_DIR="${BASE_TMP}/claude-session-storage"

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)

if [ -n "$session_id" ]; then
  rm -rf "${STORAGE_DIR}/${session_id}"
fi

# Also clean up stale session directories older than 24 hours
find "$STORAGE_DIR" -mindepth 1 -maxdepth 1 -type d -not -name ".*" -mmin +1440 -exec rm -rf {} + 2>/dev/null

exit 0
