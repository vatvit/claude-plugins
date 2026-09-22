#!/usr/bin/env bash
# Maintain the session's `active-tasks` list.
#
# Usage: session-active.sh <tasksDir> <prefix> <get|add|set|remove> [id] [--force]
#   get             Print the current list (empty line when there is none)
#   add <id>        Append the id, and its parent epic, to the list
#   set <id>        Replace the list with that id and its parent epic
#   remove <id>     Drop the id. A parent epic is never removed this way.
#   --force         With add: append even when another, unrelated task is active
#
# Environment — both must be set, or this is a silent no-op:
#   TASK_STORAGE_BIN   executable implementing:  <bin> get|set|clear <session> <key> [value]
#   TASK_SESSION_ID    the session id to scope the value to
#
# This plugin never depends on the storage helper existing: without it every
# call prints `status=unavailable` and exits 0, which is the state most
# installs are in. The caller passes the path in; nothing here knows or names
# which plugin provides it.
#
# Output (key=value):
#   status=added|present|conflict|removed|cleared|unavailable|noop
#   active=<comma separated list after the call>
#   conflict=<ids>     with status=conflict — the caller must ask the user
#                      whether to append, switch or cancel, and re-run with
#                      --force (append) or `set` (switch)
#   epic=<id>          when the parent epic was added alongside
#
# No dependencies — pure bash + awk.
set -euo pipefail

if [ "${1:-}" = "--help" ]; then
    sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; $d'
    exit 0
fi

TASKS_DIR="${1:?Usage: session-active.sh <tasksDir> <prefix> <get|add|set|remove> [id]}"
PREFIX="${2:?}"
ACTION="${3:?}"
ID="${4:-}"
FORCE=0
for a in "$@"; do [ "$a" = "--force" ] && FORCE=1; done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KEY="active-tasks"

BIN="${TASK_STORAGE_BIN:-}"
SID="${TASK_SESSION_ID:-}"
if [ -z "$BIN" ] || [ -z "$SID" ] || [ ! -x "$BIN" ]; then
    echo "status=unavailable"
    exit 0
fi

# --- current list ---------------------------------------------------------
# A helper that has no value prints something human ("(no value set …)"), so
# only well-formed id lists are accepted as a value.
raw=$("$BIN" get "$SID" "$KEY" 2>/dev/null || true)
CURRENT=""
if printf '%s' "$raw" | grep -qE '^[A-Za-z]+-[0-9]+(,[A-Za-z]+-[0-9]+)*$'; then
    CURRENT="$raw"
fi

contains() { # contains <list> <id>
    case ",$1," in *",$2,"*) return 0 ;; esac
    return 1
}

parent_epic_id() { # parent_epic_id <id> -> epic task id, or empty
    local out ename
    out=$("$SCRIPT_DIR/resolve-task.sh" "$TASKS_DIR" "$PREFIX" "$1" 2>/dev/null) || return 0
    ename=$(printf '%s\n' "$out" | grep '^epic=' | head -1 | cut -d= -f2- || true)
    [ -n "$ename" ] || return 0
    "$SCRIPT_DIR/resolve-epic.sh" "$TASKS_DIR" "$PREFIX" "$ename" 2>/dev/null \
      | grep '^id=' | head -1 | cut -d= -f2- || true
}

store() { # store <list>
    if [ -z "$1" ]; then "$BIN" clear "$SID" "$KEY" >/dev/null 2>&1 || true
    else "$BIN" set "$SID" "$KEY" "$1" >/dev/null 2>&1 || true; fi
}

case "$ACTION" in
    get)
        echo "status=ok"
        echo "active=$CURRENT"
        ;;

    add|set)
        [ -n "$ID" ] || { echo "ERROR: $ACTION needs a task id" >&2; exit 1; }
        EPIC=$(parent_epic_id "$ID")

        if [ "$ACTION" = "set" ]; then
            new="$ID"
            [ -n "$EPIC" ] && [ "$EPIC" != "$ID" ] && new="$EPIC,$ID"
            store "$new"
            echo "status=added"
            [ -n "$EPIC" ] && [ "$EPIC" != "$ID" ] && echo "epic=$EPIC"
            echo "active=$new"
            exit 0
        fi

        if contains "$CURRENT" "$ID"; then
            echo "status=present"
            echo "active=$CURRENT"
            exit 0
        fi

        # Starting a sub-task under an epic that is already active is not a
        # conflict — it is the normal shape of working inside an epic.
        others=""
        saved="$IFS"; IFS=','
        for t in $CURRENT; do
            [ -n "$t" ] || continue
            [ "$t" = "$EPIC" ] && continue
            others="${others:+$others,}$t"
        done
        IFS="$saved"

        if [ -n "$others" ] && [ "$FORCE" -eq 0 ]; then
            echo "status=conflict"
            echo "conflict=$others"
            echo "active=$CURRENT"
            exit 0
        fi

        new="$CURRENT"
        if [ -n "$EPIC" ] && [ "$EPIC" != "$ID" ] && ! contains "$new" "$EPIC"; then
            new="${new:+$new,}$EPIC"
        fi
        new="${new:+$new,}$ID"
        store "$new"
        echo "status=added"
        [ -n "$EPIC" ] && [ "$EPIC" != "$ID" ] && echo "epic=$EPIC"
        echo "active=$new"
        ;;

    remove)
        [ -n "$ID" ] || { echo "ERROR: remove needs a task id" >&2; exit 1; }
        new=""
        saved="$IFS"; IFS=','
        for t in $CURRENT; do
            [ -n "$t" ] || continue
            [ "$t" = "$ID" ] && continue
            new="${new:+$new,}$t"
        done
        IFS="$saved"
        store "$new"
        echo "status=$([ -z "$new" ] && echo cleared || echo removed)"
        echo "active=$new"
        ;;

    *)
        echo "ERROR: unknown action: $ACTION" >&2
        exit 1
        ;;
esac
