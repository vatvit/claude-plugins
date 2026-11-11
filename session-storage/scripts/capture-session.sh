#!/usr/bin/env bash
# SessionStart hook: captures session_id from the hook's JSON on stdin and injects it, with
# the storage commands, into Claude's context. Always exits 0; reports on stderr.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
STORAGE_DIR="$SS_STORAGE_DIR"

session_id=$(ss_json_session_id)
[ -n "$session_id" ] || exit 0
if ! ss_safe_name "$session_id"; then
  echo "session-storage: invalid session id in the SessionStart input; no storage for this session" >&2
  exit 0
fi

mkdir -p "${STORAGE_DIR}/${session_id}" 2>/dev/null || {
  echo "session-storage: cannot write ${STORAGE_DIR}; no storage for this session" >&2; exit 0; }

# A "last session" file as fallback discovery mechanism
echo "$session_id" > "${STORAGE_DIR}/.current_session"

STORAGE="${SCRIPT_DIR}/storage.sh"
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "SESSION STORAGE PLUGIN: Your session_id is: ${session_id}. You can store key-value data scoped to this session by running: bash ${STORAGE} set ${session_id} <key> <value> — retrieve with: bash ${STORAGE} get ${session_id} <key> — clear with: bash ${STORAGE} clear ${session_id} [key] — list keys: bash ${STORAGE} list ${session_id}"
  }
}
EOF

exit 0
