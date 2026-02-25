#!/usr/bin/env bash
# Captures session_id from SessionStart hook input and injects it into Claude's context.
# This allows Claude to discover its own session_id and use it for session-specific notation.

NOTATION_DIR="/tmp/claude-notations"
mkdir -p "$NOTATION_DIR"

input=$(cat)

session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)

if [ -z "$session_id" ]; then
  exit 0
fi

# Write a "last session" file as fallback discovery mechanism
echo "$session_id" > "${NOTATION_DIR}/.current_session"

# Determine the directory where this script lives (plugin root/scripts/)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Inject session_id and usage instructions into Claude's context
cat <<EOF
{
  "hookSpecificOutput": {
    "additionalContext": "SESSION NOTATION PLUGIN: Your session_id is: ${session_id}. You can set a status line notation by running: bash ${PLUGIN_ROOT}/scripts/notation.sh set ${session_id} YOUR_TEXT_HERE — and clear it with: bash ${PLUGIN_ROOT}/scripts/notation.sh clear ${session_id}"
  }
}
EOF

exit 0
