#!/usr/bin/env bash
# Resolve an epic reference to a task ID and extract metadata.
# Usage: resolve-epic.sh <tasksDir> <prefix> <epic-ref>
#   epic-ref can be:
#     - Numeric ID: 459 → delegates to resolve-task.sh, verifies type=epic
#     - Full ID: TASK-459 → delegates to resolve-task.sh, verifies type=epic
#     - Epic-name: 2d-char-anim → looks up _epic-index.json, falls back to scan
# Output: same key=value format as resolve-task.sh
# Exit 1 if not found or not an epic.
set -euo pipefail

TASKS_DIR="${1:?Usage: resolve-epic.sh <tasksDir> <prefix> <epic-ref>}"
PREFIX="${2:?}"
EPIC_REF="${3:?}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INDEX_FILE="$TASKS_DIR/_epic-index.json"

# --- Helper: resolve by task ID and verify epic ---
resolve_by_id() {
    local raw_id="$1"
    local output
    output=$("$SCRIPT_DIR/resolve-task.sh" "$TASKS_DIR" "$PREFIX" "$raw_id") || exit 1

    # Check type=epic in output
    local type_val
    type_val=$(echo "$output" | grep '^type=' | head -1 | cut -d= -f2)
    if [ "$type_val" != "epic" ]; then
        local resolved_id
        resolved_id=$(echo "$output" | grep '^id=' | head -1 | cut -d= -f2)
        echo "ERROR: ${resolved_id:-$raw_id} is not an epic (type=${type_val:-unset})" >&2
        exit 1
    fi

    echo "$output"
}

# --- Detect reference type ---

# Full or numeric ID
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
if task_canonical_id "$PREFIX" "$EPIC_REF" >/dev/null; then
    resolve_by_id "$EPIC_REF"
    exit 0
fi

# --- Epic-name: look up index ---

# Try index file first
if [ -f "$INDEX_FILE" ]; then
    task_id=$(awk -v name="$EPIC_REF" '
    BEGIN { FS=""; found="" }
    {
        # Simple JSON key lookup: find "name":"VALUE"
        line = $0
        target = "\"" name "\":"
        idx = index(line, target)
        if (idx > 0) {
            rest = substr(line, idx + length(target))
            # Skip opening quote
            if (substr(rest, 1, 1) == "\"") {
                rest = substr(rest, 2)
                val = rest
                sub(/".*/, "", val)
                print val
            }
        }
    }
    ' "$INDEX_FILE")

    if [ -n "$task_id" ]; then
        resolve_by_id "$task_id"
        exit 0
    fi
fi

# --- Fallback: scan all task files ---
if [ -f "$INDEX_FILE" ]; then
    echo "WARN: epic-name '$EPIC_REF' not in index; falling back to scan" >&2
else
    echo "WARN: _epic-index.json missing; falling back to scan" >&2
fi

# Frontmatter parsing lives in read-tasks.sh — this only looks for the epic
# whose epic-name matches. --all because a completed epic still owns its name.
task_id=$("$SCRIPT_DIR/read-tasks.sh" "$TASKS_DIR" "$PREFIX" --all --records \
  | awk -F'\t' -v target="$EPIC_REF" '
    # No early exit: closing the pipe early would SIGPIPE read-tasks.sh, and
    # pipefail turns that into a failure of this script.
    function flush() { if (found == "" && cur != "" && type == "epic" && ename == target) { found = cur; print cur } }
    { if ($1 != cur) { flush(); cur = $1; type = ""; ename = "" }
      if ($2 == "type") type = $3
      if ($2 == "epic-name") ename = $3 }
    END { flush() }
  ')

if [ -n "$task_id" ]; then
    resolve_by_id "$task_id"

    # Rebuild index in background for next time
    "$SCRIPT_DIR/update-epic-index.sh" "$TASKS_DIR" "$PREFIX" 2>/dev/null &
    exit 0
fi

echo "ERROR: No epic found with name '$EPIC_REF'" >&2
exit 1
