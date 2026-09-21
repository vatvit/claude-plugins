#!/usr/bin/env bash
# Resolve a task ID and extract metadata + workflow state.
# Usage: resolve-task.sh <tasksDir> <prefix> <id>
#   id: number (4 or 004) or full ID (TASK-004)
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
if echo "$RAW_ID" | grep -qE '^[A-Z]+-[0-9]+$'; then
    FULL_ID="$RAW_ID"
else
    NUM=$(echo "$RAW_ID" | sed 's/^0*//')
    : "${NUM:=0}"
    FULL_ID=$(printf "%s-%03d" "$PREFIX" "$NUM")
fi

FILE="$TASKS_DIR/$FULL_ID.md"
if [ ! -f "$FILE" ]; then
    echo "ERROR: Task file not found: $FILE" >&2
    exit 1
fi

echo "id=$FULL_ID"
echo "file=$FILE"

# --- Extract frontmatter ---
awk '
/^---$/ {
    if (in_fm) exit
    in_fm = 1
    next
}
in_fm && /:/ {
    key = $0; val = $0
    sub(/:.*/, "", key)
    sub(/^[^:]*:[ \t]*/, "", val)
    gsub(/^[ \t]+|[ \t]+$/, "", key)
    gsub(/^[ \t]+|[ \t]+$/, "", val)
    # Strip surrounding YAML quotes
    if (substr(val,1,1) == "\"" && substr(val,length(val),1) == "\"") {
        val = substr(val, 2, length(val)-2)
    }
    if (key != "" && val != "") print key "=" val
}
NR > 25 { exit }
' "$FILE"

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
        global_step="$HOME/.claude/project-tasks/_workflow/steps/${step_key}.md"
        if [ -f "$project_step" ]; then
            echo "step_file=$project_step"
        elif [ -f "$global_step" ]; then
            echo "step_file=$global_step"
        fi
    fi
fi
