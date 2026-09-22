#!/usr/bin/env bash
# Change a task's status.
#
# Usage: set-status.sh <tasksDir> <prefix> <id> <status>
#   status: proposed | approved | in-progress | blocked | completed | rejected
#
# Does the three things a status change always implies, in one call:
#   1. rewrites the `status:` line in the task's frontmatter (atomic, via a
#      temp file and mv; unchanged files are left untouched)
#   2. cascades to the parent epic — a sub-task going in-progress puts its
#      epic in-progress too, if it is not already
#   3. updates the session's active-tasks list through session-active.sh,
#      which is a silent no-op when no storage helper is configured
#
# Deciding *whether* the status should change is not this script's business:
# that needs the user's say-so and stays in the skill's prose.
#
# Output (key=value):
#   id=TASK-012  old=proposed  new=in-progress
#   epic_id=TASK-010  epic_old=proposed  epic_new=in-progress   (only if cascaded)
#   active=...  active_status=...                               (from session-active.sh)
#
# Exit 1 on an unknown task or an invalid status.
# No dependencies — pure bash + awk.
set -euo pipefail

if [ "${1:-}" = "--help" ]; then
    sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; $d'
    exit 0
fi

TASKS_DIR="${1:?Usage: set-status.sh <tasksDir> <prefix> <id> <status>}"
PREFIX="${2:?}"
RAW_ID="${3:?}"
NEW="${4:?}"

case "$NEW" in
    proposed|approved|in-progress|blocked|completed|rejected) ;;
    *) echo "ERROR: invalid status: $NEW (proposed, approved, in-progress, blocked, completed, rejected)" >&2
       exit 1 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

meta=$("$SCRIPT_DIR/resolve-task.sh" "$TASKS_DIR" "$PREFIX" "$RAW_ID") || exit 1
ID=$(printf '%s\n' "$meta"   | grep '^id='     | head -1 | cut -d= -f2- || true)
FILE=$(printf '%s\n' "$meta" | grep '^file='   | head -1 | cut -d= -f2- || true)
OLD=$(printf '%s\n' "$meta"  | grep '^status=' | head -1 | cut -d= -f2- || true)
ENAME=$(printf '%s\n' "$meta" | grep '^epic='  | head -1 | cut -d= -f2- || true)

# --- write the frontmatter ------------------------------------------------
# Only inside the frontmatter block, and written through a temp file: an
# in-place edit flag is spelled one way on BSD and another on GNU.
# bare `-i` is GNU-only.
write_status() { # write_status <file> <new-status>
    local f="$1" s="$2" tmp="$1.$$"
    awk -v s="$s" '
    NR == 1 && /^---[ \t]*$/ { infm = 1; print; next }
    infm && /^---[ \t]*$/    { infm = 0; print; next }
    infm && /^status:/       { print "status: " s; done = 1; next }
    { print }
    END { if (!done) exit 3 }
    ' "$f" > "$tmp" || { rm -f "$tmp"; return 3; }
    if cmp -s "$tmp" "$f"; then rm -f "$tmp"; else mv "$tmp" "$f"; fi
    return 0
}

if [ "$OLD" != "$NEW" ]; then
    if ! write_status "$FILE" "$NEW"; then
        echo "ERROR: $ID has no status field in its frontmatter" >&2
        exit 1
    fi
fi

echo "id=$ID"
echo "old=$OLD"
echo "new=$NEW"

# --- parent epic cascade --------------------------------------------------
if [ "$NEW" = "in-progress" ] && [ -n "$ENAME" ]; then
    epic_meta=$("$SCRIPT_DIR/resolve-epic.sh" "$TASKS_DIR" "$PREFIX" "$ENAME" 2>/dev/null) || epic_meta=""
    if [ -n "$epic_meta" ]; then
        EID=$(printf '%s\n' "$epic_meta"    | grep '^id='     | head -1 | cut -d= -f2- || true)
        EFILE=$(printf '%s\n' "$epic_meta"  | grep '^file='   | head -1 | cut -d= -f2- || true)
        EOLD=$(printf '%s\n' "$epic_meta"   | grep '^status=' | head -1 | cut -d= -f2- || true)
        if [ -n "$EID" ] && [ "$EOLD" != "in-progress" ]; then
            if write_status "$EFILE" "in-progress"; then
                echo "epic_id=$EID"
                echo "epic_old=$EOLD"
                echo "epic_new=in-progress"
            fi
        fi
    fi
fi

# --- session storage ------------------------------------------------------
if [ "$NEW" = "in-progress" ]; then
    sa=$("$SCRIPT_DIR/session-active.sh" "$TASKS_DIR" "$PREFIX" add "$ID")
elif [ "$OLD" = "in-progress" ]; then
    sa=$("$SCRIPT_DIR/session-active.sh" "$TASKS_DIR" "$PREFIX" remove "$ID")
else
    sa=""
fi
if [ -n "$sa" ]; then
    printf '%s\n' "$sa" | sed 's/^status=/active_status=/; s/^epic=/active_epic=/'
fi
