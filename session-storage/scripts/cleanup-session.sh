#!/usr/bin/env bash
# SessionEnd hook: removes this session's storage, then sessions idle for over 24 hours.
# Always exits 0; reports on stderr.

# shellcheck source=lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
STORAGE_DIR="$SS_STORAGE_DIR"

session_id=$(ss_json_session_id)
if [ -n "$session_id" ]; then
  if ss_safe_name "$session_id"; then
    rm -rf "${STORAGE_DIR:?}/${session_id}"
  else
    echo "session-storage: invalid session id in the SessionEnd input; nothing removed for it" >&2
  fi
fi

# Also clean up stale session directories older than 24 hours
find "$STORAGE_DIR" -mindepth 1 -maxdepth 1 -type d -not -name ".*" -mmin +1440 -exec rm -rf {} + 2>/dev/null

exit 0
