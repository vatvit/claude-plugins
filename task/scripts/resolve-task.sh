#!/usr/bin/env bash
# Resolve a task ID and extract metadata + workflow state.
# Usage: resolve-task.sh <tasksDir> <prefix> <id>
#   id: number (4 or 004), full ID (TASK-004) or an epic-name (auth)
# Output (key=value, one per line):
#   id=TASK-004
#   file=/path/to/TASK-004.md
#   <all frontmatter fields: title, status, type, priority, epic, ...>
#   current_step=Assessment        (if workflow table exists)
#   current_step_num=30
#   current_step_status=—
#   current_step_key=assessment    (lowercase kebab for file lookup)
#   step_file=/path/to/step.md     (if definition file found)
# Exit 1 if task file not found.
set -euo pipefail

TASKS_DIR="${1:?Usage: resolve-task.sh <tasksDir> <prefix> <id>}"
PREFIX="${2:?}"
RAW_ID="${3:?}"

# --- Resolve full ID ---
# Anything that is neither PREFIX-NNN nor a number is an epic-name. Its lookup
# (index, then scan) lives in resolve-epic.sh, which comes back here with the id.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
if ! FULL_ID=$(task_canonical_id "$PREFIX" "$RAW_ID"); then
    "$SCRIPT_DIR/resolve-epic.sh" "$TASKS_DIR" "$PREFIX" "$RAW_ID"
    exit $?
fi

FILE="$TASKS_DIR/$FULL_ID.md"
if [ ! -f "$FILE" ]; then
    echo "ERROR: Task file not found: $FILE" >&2
    exit 1
fi

echo "id=$FULL_ID"
echo "file=$FILE"

# --- Extract frontmatter ---
# Parsing lives in read-tasks.sh; this script adds id resolution and the
# workflow table on top. `id` is dropped because it was printed above.
"$SCRIPT_DIR/read-tasks.sh" "$TASKS_DIR" "$PREFIX" --all --records --id="$FULL_ID" \
  | awk -F'\t' '$2 != "id" { print $2 "=" $3 }'

# --- Parse workflow table for current step ---
# Only looks inside ## Workflow section. Current step = first row with status NOT done/skipped.
step_info=$(awk '
/^## Workflow/ { in_wf = 1; next }
in_wf && /^## / { exit }
!in_wf { next }
/^\|[[:space:]]*#[[:space:]]*\|/ { next }
/^\|[-[:space:]+|]+\|$/ { next }
/^\|[[:space:]]*[0-9]+[[:space:]]*\|/ {
    n = split($0, cols, "|")
    if (n >= 5) {
        num = cols[2]; gsub(/^[ \t]+|[ \t]+$/, "", num)
        step = cols[3]; gsub(/^[ \t]+|[ \t]+$/, "", step)
        st = cols[4]; gsub(/^[ \t]+|[ \t]+$/, "", st)
        if (st != "done" && st != "skipped") {
            step_key = tolower(step)
            gsub(/[ \t]+/, "-", step_key)
            print "current_step=" step
            print "current_step_num=" num
            print "current_step_status=" st
            print "current_step_key=" step_key
            exit
        }
    }
}
' "$FILE")

if [ -n "$step_info" ]; then
    echo "$step_info"

    # --- Resolve step definition file ---
    step_key=$(echo "$step_info" | grep '^current_step_key=' | cut -d= -f2)
    if [ -n "$step_key" ]; then
        project_step="$TASKS_DIR/_workflow/steps/${step_key}.md"
        global_step=$(task_global_file "_workflow/steps/${step_key}.md")
        if [ -f "$project_step" ]; then
            echo "step_file=$project_step"
        elif [ -n "$global_step" ]; then
            echo "step_file=$global_step"
        fi
    fi
fi
