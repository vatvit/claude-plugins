#!/usr/bin/env bash
# Read task frontmatter for a whole tasks directory.
#
# Usage: read-tasks.sh <tasksDir> <prefix> [options]
#   --all              Include every task, whatever its status
#   --status=X,Y       Include only tasks whose status is one of X,Y
#   --id=<full-id>     Read one task file only (PREFIX-NNN)
#   --records          Emit TSV records instead of JSON
#   --help             This text
#   Default: excludes completed and rejected tasks
#
# Output, JSON (default):
#   [{"id":"TASK-001","title":"...","status":"...",...},...]
#
# Output, --records — one line per frontmatter field, tab separated:
#   TASK-001<TAB>id<TAB>TASK-001
#   TASK-001<TAB>title<TAB>Implement auth
#   TASK-001<TAB>status<TAB>proposed
# Every task gets an `id` record first, so a task with empty frontmatter is
# still visible to the consumer. Field order is the order in the file.
#
# This is the plugin's only bulk frontmatter reader: list-tasks.sh,
# resolve-task.sh, resolve-epic.sh and update-epic-index.sh all go through it
# rather than carrying a parser each.
#
# No dependencies — pure bash + awk.
set -euo pipefail

if [ "${1:-}" = "--help" ]; then
    sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; $d'
    exit 0
fi

TASKS_DIR="${1:?Usage: read-tasks.sh <tasksDir> <prefix> [--all|--status=X,Y] [--id=ID] [--records]}"
PREFIX="${2:?Usage: read-tasks.sh <tasksDir> <prefix> [--all|--status=X,Y] [--id=ID] [--records]}"
shift 2

FILTER_MODE="default"   # default | all | custom
STATUSES=""
MODE="json"
ONLY_ID=""

for arg in "$@"; do
    case "$arg" in
        --all)      FILTER_MODE="all" ;;
        --status=*) FILTER_MODE="custom"; STATUSES="${arg#--status=}" ;;
        --records)  MODE="records" ;;
        --id=*)     ONLY_ID="${arg#--id=}" ;;
    esac
done

# Collect the files to read. A missing file or an empty directory is not an
# error: an empty list is a legitimate answer (empty JSON array, no records).
# An indexed array, not xargs: xargs may split a long list across several awk
# runs, which would emit several JSON arrays instead of one.
declare -a files
files=()
if [ -n "$ONLY_ID" ]; then
    [ -f "$TASKS_DIR/$ONLY_ID.md" ] && files=("$TASKS_DIR/$ONLY_ID.md")
else
    for f in "$TASKS_DIR"/"$PREFIX"-*.md; do
        [ -f "$f" ] || continue
        files[${#files[@]}]="$f"
    done
fi

if [ ${#files[@]} -eq 0 ]; then
    [ "$MODE" = "json" ] && printf '[]\n'
    exit 0
fi

awk -v mode="$MODE" -v filtermode="$FILTER_MODE" -v statuses="$STATUSES" '
function emit(   i, v) {
    if (cur == "") return
    if (filtermode == "all")         ok = 1
    else if (filtermode == "custom") ok = (st in allow)
    else                             ok = (st != "completed" && st != "rejected")
    if (!ok) return
    if (mode == "records") {
        print cur "\t" "id" "\t" cur
        for (i = 1; i <= nk; i++) print cur "\t" kk[i] "\t" vv[i]
    } else {
        printf "%s{\"id\":\"%s\"", (nout ? "," : ""), cur
        for (i = 1; i <= nk; i++) {
            v = vv[i]
            gsub(/\\/, "\\\\", v); gsub(/"/, "\\\"", v)
            printf ",\"%s\":\"%s\"", kk[i], v
        }
        printf "}"
        nout++
    }
}
BEGIN {
    if (statuses != "") { n = split(statuses, sa, ","); for (i = 1; i <= n; i++) allow[sa[i]] = 1 }
    if (mode != "records") printf "["
}
FNR == 1 {
    emit()
    nk = 0; st = ""; infm = 0; fmdone = 0
    cur = FILENAME; sub(/.*\//, "", cur); sub(/\.md$/, "", cur)
}
fmdone { next }
/^---[ \t]*$/ { if (infm) { fmdone = 1 } else { infm = 1 } next }
infm && /:/ {
    key = $0; val = $0
    sub(/:.*/, "", key)
    sub(/^[^:]*:[ \t]*/, "", val)
    gsub(/^[ \t]+|[ \t]+$/, "", key)
    gsub(/^[ \t]+|[ \t]+$/, "", val)
    if (length(val) > 1 && substr(val, 1, 1) == "\"" && substr(val, length(val), 1) == "\"")
        val = substr(val, 2, length(val) - 2)
    if (key != "" && val != "") {
        nk++; kk[nk] = key; vv[nk] = val
        if (key == "status") st = val
    }
}
FNR > 25 { fmdone = 1 }
END {
    emit()
    if (mode != "records") printf "]\n"
}
' "${files[@]}"
