#!/usr/bin/env bash
# Cleans up session-specific notation file when a session ends.

NOTATION_DIR="/tmp/claude-notations"

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)

if [ -n "$session_id" ]; then
  rm -f "${NOTATION_DIR}/${session_id}"
fi

# Also clean up stale notation files older than 24 hours
find "$NOTATION_DIR" -type f -not -name ".*" -mmin +1440 -delete 2>/dev/null

exit 0
