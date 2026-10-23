#!/usr/bin/env bash
# Gather epic sub-task data for the Epic Dashboard and the epic work flow.
# Usage: epic-dashboard.sh <tasksDir> <prefix> <epic-ref>
#   epic-ref: number (10), full ID (TASK-010) or epic-name (auth)
# Output: JSON object with epic info + sub-task statuses + work queue + recommendation
# {
#   "id":"TASK-010","title":"...","status":"...","priority":"...",
#   "epic-name":"auth","goal":"first line of Goal section",
#   "subtasks":[
#     {"id":"TASK-011","title":"...","status":"...","priority":"..."},
#     ...
#   ],
#   "queue":["TASK-012","TASK-013"],
#   "recommend":"TASK-012","recommend_reason":"in-progress"
# }
# subtasks: every member, in work order (closed ones last).
# queue:    the members still to work, in work order — in-progress, approved,
#           proposed, then priority, then id. Blocked and closed are left out.
# recommend_reason values: in-progress, approved, proposed, blocked (queue is
#   empty but something is blocked), all-done; absent when there are no sub-tasks.
# Exit 1 if the epic is not found or the task is not an epic.
#
# Membership is the sub-task's `epic: <epic-name>` field and nothing else. An
# epic's `## Sub-tasks` section, where older epics have one, is prose: listing
# the ids there as well stored one fact twice, and the dashboard read the list
# while `/task list` read the field, so the two views of one epic could disagree.
set -euo pipefail

TASKS_DIR="${1:?Usage: epic-dashboard.sh <tasksDir> <prefix> <epic-ref>}"
PREFIX="${2:?}"
EPIC_REF="${3:?}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Resolve the epic: id, number or name, one resolver for all three ---
epic_out=$("$SCRIPT_DIR/resolve-epic.sh" "$TASKS_DIR" "$PREFIX" "$EPIC_REF") || exit 1

epic_title="" epic_status="" epic_priority="" epic_name="" FULL_ID="" EPIC_FILE=""
while IFS='=' read -r key val; do
    case "$key" in
        id) FULL_ID="$val" ;;
        file) EPIC_FILE="$val" ;;
        title) epic_title="$val" ;;
        status) epic_status="$val" ;;
        priority) epic_priority="$val" ;;
        epic-name) epic_name="$val" ;;
    esac
done <<EOF
$epic_out
EOF

# JSON string escaping — one home for every string this script prints.
json_escape() { printf %s "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# --- Goal: first non-empty line after ## Goal ---
epic_goal=$(awk '
/^## Goal/ { in_goal=1; next }
in_goal && /^##/ { exit }
in_goal && /[^ \t]/ { print; exit }
' "$EPIC_FILE")

# --- Members, in work order ---
# awk emits one row per member: rank, priority rank, id number, id, title
# (JSON-escaped), status, priority; one sort orders them. An epic with no
# epic-name (the legacy `EPIC:` title form) has no members: an empty name
# would otherwise match every task without an epic.
rows=""
if [ -n "$epic_name" ]; then
    rows=$("$SCRIPT_DIR/read-tasks.sh" "$TASKS_DIR" "$PREFIX" --all --records \
      | awk -F'\t' -v ename="$epic_name" -v self="$FULL_ID" '
        # A character loop, not gsub: busybox reads a backslash in a gsub
        # replacement differently from gawk and BSD awk.
        function esc(s,  o, c, i) {
            o = ""
            for (i = 1; i <= length(s); i++) {
                c = substr(s, i, 1)
                if (c == "\\" || c == "\"") o = o "\\"
                o = o c
            }
            return o
        }
        function flush(  r, p, n) {
            if (cur == "" || cur == self || ep != ename) return
            if (st == "") st = "proposed"
            r = (st == "in-progress") ? 1 : (st == "approved") ? 2 : (st == "blocked") ? 4 \
              : (st == "completed" || st == "rejected") ? 5 : 3
            p = (pr == "critical") ? 1 : (pr == "high") ? 2 : (pr == "medium") ? 3 : (pr == "low") ? 4 : 5
            n = cur; sub(/.*-/, "", n)
            printf "%d\t%d\t%d\t%s\t%s\t%s\t%s\n", r, p, n + 0, cur, esc(ti), st, pr
        }
        { if ($1 != cur) { flush(); cur = $1; ep = ""; ti = ""; st = ""; pr = "" }
          if ($2 == "epic") ep = $3
          else if ($2 == "title") ti = $3
          else if ($2 == "status") st = $3
          else if ($2 == "priority") pr = $3 }
        END { flush() }
      ' | sort -t "$(printf '\t')" -k1,1n -k2,2n -k3,3n || true)
fi

subtasks_json="" queue_json="" recommend_id="" recommend_reason="" first_blocked=""
while IFS=$'\t' read -r rank _prio _num sid stitle sstatus spriority; do
    [ -n "$sid" ] || continue
    entry=$(printf '{"id":"%s","title":"%s","status":"%s"' "$sid" "$stitle" "$sstatus")
    [ -n "$spriority" ] && entry=$(printf '%s,"priority":"%s"' "$entry" "$spriority")
    subtasks_json="${subtasks_json:+$subtasks_json,}$entry}"
    case "$rank" in
        1|2|3)
            queue_json="${queue_json:+$queue_json,}\"$sid\""
            if [ -z "$recommend_id" ]; then
                recommend_id="$sid"; recommend_reason="$sstatus"
                case "$sstatus" in in-progress|approved) ;; *) recommend_reason="proposed" ;; esac
            fi ;;
        4)  [ -n "$first_blocked" ] || first_blocked="$sid" ;;
    esac
done <<EOF
$rows
EOF

if [ -z "$recommend_id" ] && [ -n "$first_blocked" ]; then
    recommend_id="$first_blocked"; recommend_reason="blocked"
elif [ -z "$recommend_id" ] && [ -n "$subtasks_json" ]; then
    recommend_reason="all-done"
fi

# --- Output JSON ---
printf '{"id":"%s","title":"%s","status":"%s"' "$FULL_ID" "$(json_escape "$epic_title")" "$epic_status"
[ -n "$epic_priority" ] && printf ',"priority":"%s"' "$epic_priority"
[ -n "$epic_name" ] && printf ',"epic-name":"%s"' "$(json_escape "$epic_name")"
[ -n "$epic_goal" ] && printf ',"goal":"%s"' "$(json_escape "$epic_goal")"
printf ',"subtasks":[%s],"queue":[%s]' "$subtasks_json" "$queue_json"
[ -n "$recommend_id" ] && printf ',"recommend":"%s"' "$recommend_id"
[ -n "$recommend_reason" ] && printf ',"recommend_reason":"%s"' "$recommend_reason"
printf '}\n'
