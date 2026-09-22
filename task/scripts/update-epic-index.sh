#!/usr/bin/env bash
# Rebuild the epic-name → task-ID index.
# Usage: update-epic-index.sh <tasksDir> <prefix>
# Writes: {tasksDir}/_epic-index.json
#   e.g. {"auth":"TASK-010","rigging":"TASK-320"}
# Idempotent — full rebuild each time, and diff-guarded so an unchanged index
# keeps its mtime.
# Pure bash + awk, no dependencies.
set -euo pipefail

TASKS_DIR="${1:?Usage: update-epic-index.sh <tasksDir> <prefix>}"
PREFIX="${2:?Usage: update-epic-index.sh <tasksDir> <prefix>}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INDEX_FILE="$TASKS_DIR/_epic-index.json"
TMP="$INDEX_FILE.$$"

# Frontmatter parsing lives in read-tasks.sh; this only picks the epics out.
# --all matters: a completed epic still owns its name.
"$SCRIPT_DIR/read-tasks.sh" "$TASKS_DIR" "$PREFIX" --all --records \
  | awk -F'\t' '
    { if ($1 != cur) { flush(); cur = $1; type = ""; ename = "" }
      if ($2 == "type") type = $3
      if ($2 == "epic-name") ename = $3 }
    function flush() {
        if (cur != "" && type == "epic" && ename != "") {
            printf "%s\"%s\":\"%s\"", (n++ ? "," : ""), ename, cur
        }
    }
    BEGIN { printf "{" }
    END { flush(); printf "}\n" }
  ' > "$TMP"

if [ -f "$INDEX_FILE" ] && cmp -s "$TMP" "$INDEX_FILE"; then
    rm -f "$TMP"
else
    mv "$TMP" "$INDEX_FILE"
fi
