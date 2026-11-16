#!/usr/bin/env bash
# Who a task is for (PLUG-138). Opt-in per project: the config key `assignees`
# (off | unassigned | self) is off by default, and then this script only
# switches it on.
#
# Usage:
#   assign.sh <project-dir> <id> [<who>|me|_] [--claim]
#       Set a task's assignee: an id (an email or any name), `me` (the default:
#       the user's id from resolve-config.sh) or `_` (unassigned).
#       --claim: write only when the task is unassigned; prints
#       claim=claimed|mine|other — what /task do uses. Never takes over a task.
#   assign.sh <project-dir> --me <id>
#       Remember the user's own id for this project, outside version control:
#       <git-common-dir>/task/me, or <project>/.task/me without git. When that
#       cannot be written, prints `scope=session — <dir> not writable` (exit 0):
#       the id then lives only as long as the session that keeps it.
#   assign.sh <project-dir> --mode off|unassigned|self
#       Write the project's assignee mode into .task-config.json (off removes the
#       key). A project configured in the global registry is refused: edit it there.
#   The two settings are flags, so any task id or epic-name (even `me` or `mode`) is a task.
#
# Output (key=value): id= old= new= [claim=]; me= file= [scope=]; assignees=.
# Exit 1 on bad input, mode off (for set/claim) or an unknown task; exit 3 when
# `me` is needed and unknown (the skill asks the user, then retries).
# Params are data: a fixed set of verbs, values quoted, nothing executed.
# No dependencies — pure bash + awk.
set -euo pipefail

if [ "${1:-}" = "--help" ]; then
    sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; $d'
    exit 0
fi

USAGE="Usage: assign.sh <project-dir> <id> [<who>|me|_] [--claim] | --me <id> | --mode off|unassigned|self"
PROJ_ARG="${1:?$USAGE}"
VERB="${2:?$USAGE}"
shift 2

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

cfg=$("$SCRIPT_DIR/resolve-config.sh" "$PROJ_ARG") || exit 1
val() { task_kv "$cfg" "$1"; }
PROJECT_DIR=$(val projectDir)
TASKS_DIR=$(val tasksDir)
PREFIX=$(val prefix)
MODE=$(val assignees); MODE="${MODE:-off}"
ME=$(val me)

case "$VERB" in
    --mode)
        new="${1:?$USAGE}"
        case "$new" in off|unassigned|self) ;; *) echo "ERROR: mode is off, unassigned or self, not: $new" >&2; exit 1 ;; esac
        if [ "$(val configScope)" != "local" ]; then
            echo "ERROR: this project is configured in $(val configFile); set \"assignees\": \"$new\" in its entry there" >&2
            exit 1
        fi
        f=$(val configFile)
        if [ "$new" = "off" ]; then task_config_edit "$f" del assignees
        else task_config_edit "$f" set assignees "$new"; fi
        echo "assignees=$new"
        ;;

    --me)
        raw="${1:-}"
        id=$(task_assignee_norm "$raw" --store) || { echo "ERROR: not a usable id: \"$raw\" (no comma, quote or newline; not me, all or _)" >&2; exit 1; }
        f=$(task_me_file "$PROJECT_DIR")
        d="${f%/*}"
        echo "me=$id"
        if mkdir -p "$d" 2>/dev/null && printf '%s\n' "$id" > "$f.tmp.$$" 2>/dev/null; then
            if cmp -s "$f.tmp.$$" "$f" 2>/dev/null; then rm -f "$f.tmp.$$"; else mv "$f.tmp.$$" "$f"; fi
            echo "file=$f"
        else
            rm -f "$f.tmp.$$" 2>/dev/null || true
            echo "scope=session — $d not writable"
        fi
        ;;

    -*) echo "$USAGE" >&2; exit 1 ;;

    *)
        RAW_ID="$VERB"; WHO="me"; CLAIM=0
        for a in "$@"; do
            case "$a" in
                --claim) CLAIM=1 ;;
                *) WHO="$a" ;;
            esac
        done
        if [ "$MODE" = "off" ]; then
            echo "ERROR: assignees are off in this project; turn them on with: assign.sh <project-dir> --mode unassigned|self" >&2
            exit 1
        fi
        case "$WHO" in
            me) [ -n "$ME" ] || { echo "ERROR: assigning to me needs your id (assign.sh <project-dir> --me <id>, or TASK_ME)" >&2; exit 3; }
                NEW="$ME" ;;
            _)  NEW="" ;;
            *)  NEW=$(task_assignee_norm "$WHO" --store) || { echo "ERROR: not a usable id: \"$WHO\"" >&2; exit 1; } ;;
        esac
        [ "$CLAIM" -eq 0 ] || [ -n "$NEW" ] || { echo "ERROR: --claim needs someone to assign to" >&2; exit 1; }

        meta=$("$SCRIPT_DIR/resolve-task.sh" "$TASKS_DIR" "$PREFIX" "$RAW_ID") || exit 1
        ID=$(task_kv "$meta" id); FILE=$(task_kv "$meta" file); OLD=$(task_kv "$meta" assignee)
        oldn=$(task_assignee_norm "$OLD" || printf '%s' "$OLD")

        if [ "$CLAIM" -eq 1 ]; then
            if [ -n "$oldn" ] && [ "$oldn" = "$NEW" ]; then claim=mine; NEW="$OLD"
            elif [ -n "$oldn" ]; then claim=other; NEW="$OLD"
            else claim=claimed; fi
        fi
        [ "$NEW" = "$OLD" ] || task_fm_set "$FILE" assignee "$NEW"
        echo "id=$ID"
        echo "old=$OLD"
        echo "new=$NEW"
        [ "$CLAIM" -eq 0 ] || echo "claim=$claim"
        ;;
esac
