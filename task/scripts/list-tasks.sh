#!/usr/bin/env bash
# Render the /task list output.
#
# Usage: list-tasks.sh <tasksDir> <prefix> [args...]
#   <id>              An epic reference (bare number or PREFIX-NNN): render that
#                     epic's group. Repeatable — the no-argument /task list form
#                     passes one per active epic.
#   <field>=<v1,v2>   Exact match, OR within the field, AND across fields
#   <field>~<s1,s2>   Case-insensitive substring match
#   <field>=_         The field is not set
#   "a, b"            A double-quoted value keeps its commas: tags="tech debt"
#   tags=<t1,t2>      A task with any of these tags (case ignored); repeat
#                     tags= to require several (a repeated field is AND)
#   all               Include completed and rejected tasks
#   summary           Counts + ids per group instead of a table
#   digest[=N]        One block per task instead of a table: id, status, type,
#                     priority, epic, tags, title and the start of its summary
#                     (about N characters, default 160) — enough to judge a task
#                     by without opening it. Same filters; never collapsed.
#   group=<field>     Group by that field (auto: status, when >15 tasks)
#   sort=<field>      Sort within groups (default: priority, then id)
#   --strict-epic     Do not add the implicit `,_` to an `epic=` filter
#   --active=A,B      Mark these ids with a `*`
#   --help            This text
#
# Prints the finished table on stdout. Everything the /task list prose used to
# specify by hand lives here: the `epic=` smart default, grouping, sorting,
# the >5 collapse, the closed-sub-task collapse in epic views, the Epic column
# and its id lookup, and dropping columns no task populates.
#
# Exit 1 only when an epic reference cannot be resolved; an empty result is a
# successful empty listing.
#
# No dependencies — pure bash + awk.
set -euo pipefail

if [ "${1:-}" = "--help" ]; then
    sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; $d'
    exit 0
fi

TASKS_DIR="${1:?Usage: list-tasks.sh <tasksDir> <prefix> [args...]}"
PREFIX="${2:?Usage: list-tasks.sh <tasksDir> <prefix> [args...]}"
shift 2

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
IN="$WORK/input.tsv"
: > "$IN"

MODE="list"          # list | summary | digest
DIGEST=160
GROUP=""
SORT=""
WANT_ALL=0
STRICT_EPIC=0
ACTIVE=""
HAS_STATUS_FILTER=0
EPIC_REFS=""
EPIC_FILTER_NAMES=""

# --- Parse arguments ------------------------------------------------------
for arg in "$@"; do
    case "$arg" in
        --help)         exec "$0" --help ;;
        --strict-epic)  STRICT_EPIC=1 ;;
        --active=*)     ACTIVE="${arg#--active=}" ;;
        all)            WANT_ALL=1 ;;
        summary)        MODE="summary" ;;
        digest)         MODE="digest" ;;
        digest=*)       MODE="digest"; DIGEST="${arg#digest=}"
                        case "$DIGEST" in ''|*[!0-9]*) echo "ERROR: digest= needs a number" >&2; exit 1 ;; esac ;;
        group=*)        GROUP="${arg#group=}" ;;
        sort=*)         SORT="${arg#sort=}" ;;
        [0-9]*)         EPIC_REFS="$EPIC_REFS $arg" ;;
        *~*)
            field="${arg%%~*}"; vals="${arg#*~}"
            printf '#F\t%s\t~\t%s\n' "$field" "$vals" >> "$IN" ;;
        *=*)
            field="${arg%%=*}"; vals="${arg#*=}"
            case "$field" in
                status) HAS_STATUS_FILTER=1 ;;
                epic)
                    EPIC_FILTER_NAMES="$vals"
                    # Smart default: an epic filter also shows the tasks without an epic,
                    # unless the caller asked for the epic alone.
                    case "$vals" in *_*) ;; *) [ "$STRICT_EPIC" -eq 1 ] || vals="$vals,_" ;; esac ;;
            esac
            printf '#F\t%s\t=\t%s\n' "$field" "$vals" >> "$IN" ;;
        *)
            # A full id (PREFIX-NNN) is an epic reference, anything else is junk.
            if printf '%s' "$arg" | grep -qE '^[A-Za-z]+-[0-9]+$'; then
                EPIC_REFS="$EPIC_REFS $arg"
            else
                echo "ERROR: unrecognised argument: $arg" >&2
                exit 1
            fi ;;
    esac
done

# --- Epic index: epic-name -> task id -------------------------------------
INDEX_FILE="$TASKS_DIR/_epic-index.json"
[ -f "$INDEX_FILE" ] || "$SCRIPT_DIR/update-epic-index.sh" "$TASKS_DIR" "$PREFIX" 2>/dev/null || true
if [ -f "$INDEX_FILE" ]; then
    tr ',' '\n' < "$INDEX_FILE" \
      | sed -n 's/^[{ ]*"\([^"]*\)":"\([^"]*\)".*/#E\t\1\t\2/p' >> "$IN"
fi

# --- Epic views: one group per referenced epic ----------------------------
for ref in $EPIC_REFS; do
    out=$("$SCRIPT_DIR/resolve-epic.sh" "$TASKS_DIR" "$PREFIX" "$ref") || exit 1
    ename=$(printf '%s\n' "$out" | grep '^epic-name=' | head -1 | cut -d= -f2- || true)
    eid=$(printf '%s\n' "$out" | grep '^id=' | head -1 | cut -d= -f2- || true)
    printf '#V\t%s\t%s\n' "$ename" "$eid" >> "$IN"
done
# An `epic=` filter renders as epic groups too, so the two forms share one path.
if [ -z "$EPIC_REFS" ] && [ -n "$EPIC_FILTER_NAMES" ]; then
    saved_ifs="$IFS"; IFS=','
    for ename in $EPIC_FILTER_NAMES; do
        [ "$ename" = "_" ] && continue
        eid=$(awk -F'\t' -v n="$ename" '$1=="#E" && $2==n { print $3 }' "$IN" | head -1)
        printf '#V\t%s\t%s\n' "$ename" "$eid" >> "$IN"
    done
    IFS="$saved_ifs"
fi

# --- Config + records -----------------------------------------------------
{
    printf '#C\tmode\t%s\n'        "$MODE"
    printf '#C\tgroup\t%s\n'       "$GROUP"
    printf '#C\tsort\t%s\n'        "$SORT"
    printf '#C\tall\t%s\n'         "$WANT_ALL"
    printf '#C\tstatusfilter\t%s\n' "$HAS_STATUS_FILTER"
    printf '#C\tstrictepic\t%s\n'  "$STRICT_EPIC"
    # A bare epic id asks about one epic and gets only that epic. An `epic=`
    # filter is the smart-default form, so it also gets the tasks without an epic.
    if [ -z "$EPIC_REFS" ] && [ -n "$EPIC_FILTER_NAMES" ] && [ "$STRICT_EPIC" -eq 0 ]; then
        printf '#C\tnoepic\t1\n'
    fi
    printf '#C\tactive\t%s\n'      "$ACTIVE"
} >> "$IN"

# Always read everything: which statuses are shown is a rendering decision,
# and epic views need the closed tasks in order to count them.
if [ "$MODE" = "digest" ]; then
    "$SCRIPT_DIR/read-tasks.sh" "$TASKS_DIR" "$PREFIX" --all --records --excerpt="$DIGEST" >> "$IN"
else
    "$SCRIPT_DIR/read-tasks.sh" "$TASKS_DIR" "$PREFIX" --all --records >> "$IN"
fi

awk -f "$SCRIPT_DIR/list-render.awk" "$IN"
