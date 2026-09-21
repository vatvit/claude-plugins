#!/usr/bin/env bash
# Read task frontmatter and output as JSON to stdout.
# Usage: read-tasks.sh <tasksDir> <prefix> [options]
#   --all              Include all tasks (no status filtering)
#   --status=X,Y       Only include tasks with these statuses
#   Default: excludes completed and rejected tasks
# Claude calls this instead of reading individual files.
# No dependencies — pure bash + awk.
set -euo pipefail

TASKS_DIR="${1:?Usage: read-tasks.sh <tasksDir> <prefix> [--all|--status=X,Y]}"
PREFIX="${2:?Usage: read-tasks.sh <tasksDir> <prefix> [--all|--status=X,Y]}"
shift 2

# Parse options
FILTER_MODE="default"  # default | all | custom
CUSTOM_STATUSES=""

for arg in "$@"; do
    case "$arg" in
        --all)
            FILTER_MODE="all"
            ;;
        --status=*)
            FILTER_MODE="custom"
            CUSTOM_STATUSES="${arg#--status=}"
            ;;
    esac
done

# Build status filter for awk
if [ "$FILTER_MODE" = "all" ]; then
    AWK_FILTER=""
elif [ "$FILTER_MODE" = "custom" ]; then
    AWK_FILTER="BEGIN { split(\"${CUSTOM_STATUSES}\",a,\",\"); for(i in a) allowed[a[i]]=1 } "
    AWK_FILTER+='END { if (!(status in allowed)) exit 1 }'
else
    # Default: exclude completed and rejected
    AWK_FILTER='END { if (status == "completed" || status == "rejected") exit 1 }'
fi

first=true
printf '['

for f in "$TASKS_DIR"/"$PREFIX"-*.md; do
    [ -f "$f" ] || continue

    # Extract frontmatter as JSON fragment; awk exits non-zero if filtered out
    json_fragment=$(awk '
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
        gsub(/\\/, "\\\\", val)
        gsub(/"/, "\\\"", val)
        if (key != "" && val != "") {
            printf ",\"%s\":\"%s\"", key, val
            if (key == "status") status = val
        }
    }
    NR > 15 { exit }
    '"$AWK_FILTER"'
    ' "$f" 2>/dev/null) || continue

    if [ "$first" = true ]; then
        first=false
    else
        printf ','
    fi

    id=$(basename "$f" .md)
    printf '{"id":"%s"%s}' "$id" "$json_fragment"
done

printf ']\n'
