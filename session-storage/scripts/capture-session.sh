#!/usr/bin/env bash
# Captures session_id from SessionStart hook input and injects it into Claude's context.
# This allows Claude to discover its own session_id and use it for session-specific storage.

BASE_TMP="${CLAUDE_CODE_TMPDIR:-/tmp}"
STORAGE_DIR="${BASE_TMP}/claude-session-storage"
mkdir -p "$STORAGE_DIR"

input=$(cat)

session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)

if [ -z "$session_id" ]; then
  exit 0
fi

# Create session directory
mkdir -p "${STORAGE_DIR}/${session_id}"

# Write a "last session" file as fallback discovery mechanism
echo "$session_id" > "${STORAGE_DIR}/.current_session"

# Determine the directory where this script lives (plugin root/scripts/)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Inject session_id and usage instructions into Claude's context
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "SESSION STORAGE PLUGIN: Your session_id is: ${session_id}. You can store key-value data scoped to this session by running: bash ${PLUGIN_ROOT}/scripts/storage.sh set ${session_id} <key> <value> — retrieve with: bash ${PLUGIN_ROOT}/scripts/storage.sh get ${session_id} <key> — clear with: bash ${PLUGIN_ROOT}/scripts/storage.sh clear ${session_id} [key] — list keys: bash ${PLUGIN_ROOT}/scripts/storage.sh list ${session_id}"
  }
}
EOF

exit 0
