#!/usr/bin/env bash
# Rebuild the epic-name → task-ID index.
# Usage: update-epic-index.sh <tasksDir> <prefix>
# Writes: {tasksDir}/_epic-index.json
#   e.g. {"auth":"TASK-010","rigging":"TASK-320"}
# Idempotent — full rebuild each time.
# Pure bash + awk, no dependencies.
set -euo pipefail

TASKS_DIR="${1:?Usage: update-epic-index.sh <tasksDir> <prefix>}"
PREFIX="${2:?Usage: update-epic-index.sh <tasksDir> <prefix>}"

INDEX_FILE="$TASKS_DIR/_epic-index.json"

# Scan all task files for type=epic + epic-name
first=true
printf '{' > "$INDEX_FILE"

for f in "$TASKS_DIR"/"$PREFIX"-*.md; do
    [ -f "$f" ] || continue

    # Extract type and epic-name from frontmatter
    pair=$(awk '
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
        if (substr(val,1,1) == "\"" && substr(val,length(val),1) == "\"") {
            val = substr(val, 2, length(val)-2)
        }
        if (key == "type") type = val
        if (key == "epic-name") ename = val
    }
    NR > 20 { exit }
    END {
        if (type == "epic" && ename != "") print ename
    }
    ' "$f") || continue

    [ -z "$pair" ] && continue

    id=$(basename "$f" .md)

    if [ "$first" = true ]; then
        first=false
    else
        printf ',' >> "$INDEX_FILE"
    fi
    printf '"%s":"%s"' "$pair" "$id" >> "$INDEX_FILE"
done

printf '}\n' >> "$INDEX_FILE"
