#!/usr/bin/env bash
# Gather epic sub-task data for the Epic Dashboard.
# Usage: epic-dashboard.sh <tasksDir> <prefix> <epic-id>
#   epic-id: number (10) or full ID (TASK-010)
# Output: JSON object with epic info + sub-task statuses + recommendation
# {
#   "id":"TASK-010","title":"...","status":"...","priority":"...",
#   "goal":"first line of Goal section",
#   "subtasks":[
#     {"id":"TASK-011","title":"...","status":"...","priority":"..."},
#     ...
#   ],
#   "recommend":"TASK-012","recommend_reason":"in-progress"
# }
# recommend_reason values: in-progress, blocked, approved, proposed, all-done
# Exit 1 if file not found or not an epic.
set -euo pipefail

TASKS_DIR="${1:?Usage: epic-dashboard.sh <tasksDir> <prefix> <epic-id>}"
PREFIX="${2:?}"
RAW_ID="${3:?}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Resolve the epic, via the shared resolver ---
epic_out=$("$SCRIPT_DIR/resolve-task.sh" "$TASKS_DIR" "$PREFIX" "$RAW_ID") || exit 1

epic_title="" epic_status="" epic_priority="" epic_type="" FULL_ID="" EPIC_FILE=""
while IFS='=' read -r key val; do
    case "$key" in
        id) FULL_ID="$val" ;;
        file) EPIC_FILE="$val" ;;
        title) epic_title="$val" ;;
        status) epic_status="$val" ;;
        priority) epic_priority="$val" ;;
        type) epic_type="$val" ;;
    esac
done <<EOF
$epic_out
EOF

if [ "$epic_type" != "epic" ]; then
    echo "ERROR: $FULL_ID is not an epic (type=${epic_type:-unset})" >&2
    exit 1
fi

# --- Extract goal (first non-empty line after ## Goal) ---
epic_goal=$(awk '
/^## Goal/ { in_goal=1; next }
in_goal && /^##/ { exit }
in_goal && /[^ \t]/ {
    gsub(/\\/, "\\\\")
    gsub(/"/, "\\\"")
    print
    exit
}
' "$EPIC_FILE")

# --- Extract sub-task IDs from ## Sub-tasks section ---
#
# Only ENTRIES name a sub-task: a bullet item ("- TASK-011: ..."), a numbered
# item ("1. TASK-011 ...") or a table row ("| TASK-011 | ... |"). Prose in this
# section is commentary — a sentence like "TASK-011's scope shipped under
# TASK-012's banner" names tasks without listing them.
#
# This used to print every line, so such a sentence registered as membership and
# the epic reported phantom sub-tasks. It failed silently and plausibly: a
# duplicated row reads as a sloppy list rather than a parser bug, so the wrong
# count went uninvestigated.
#
# Note "[-*+] " requires the space — that is what distinguishes a bullet from
# **bold** prose, which is how most such sentences begin.
#
# Ids are also de-duplicated: one task listed twice is still one sub-task.
subtask_ids=()
seen_ids=" "
while IFS= read -r line; do
    id=$(echo "$line" | grep -oE '[A-Z]+-[0-9]+' | head -1 || true)
    [ -n "$id" ] || continue
    case "$seen_ids" in *" $id "*) continue ;; esac
    seen_ids="$seen_ids$id "
    subtask_ids+=("$id")
done < <(awk '
    /^## Sub-tasks/ { found=1; next }
    found && /^## [^#]/ { exit }
    found && /^[[:space:]]*([-*+][[:space:]]|[0-9]+\.[[:space:]]|\|)/ { print }
' "$EPIC_FILE")

# --- Read each sub-task's frontmatter ---
# JSON string escaping — one home for both the epic and its sub-tasks.
json_escape() { printf %s "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# Priority rank for recommendation sorting
prio_rank() {
    case "$1" in
        critical) echo 1 ;; high) echo 2 ;; medium) echo 3 ;; low) echo 4 ;; *) echo 5 ;;
    esac
}

best_ip_rank=99 best_ip_id=""
best_bl_rank=99 best_bl_id=""
best_ap_rank=99 best_ap_id=""
best_pr_rank=99 best_pr_id=""
all_done=true
has_subtasks=false

subtasks_json=""
first=true

for sid in ${subtask_ids[@]+"${subtask_ids[@]}"}; do
    sfile="$TASKS_DIR/$sid.md"
    [ -f "$sfile" ] || continue
    has_subtasks=true

    stitle="" sstatus="" spriority=""
    while IFS='=' read -r key val; do
        case "$key" in
            title) stitle="$val" ;;
            status) sstatus="$val" ;;
            priority) spriority="$val" ;;
        esac
    done <<EOF
$("$SCRIPT_DIR/resolve-task.sh" "$TASKS_DIR" "$PREFIX" "$sid")
EOF
    stitle=$(json_escape "$stitle")

    [ -z "$sstatus" ] && sstatus="proposed"

    # Build JSON entry
    entry=$(printf '{"id":"%s","title":"%s","status":"%s"' "$sid" "$stitle" "$sstatus")
    [ -n "$spriority" ] && entry=$(printf '%s,"priority":"%s"' "$entry" "$spriority")
    entry="$entry}"

    if [ "$first" = true ]; then
        subtasks_json="$entry"
        first=false
    else
        subtasks_json="$subtasks_json,$entry"
    fi

    # Recommendation tracking
    rank=$(prio_rank "$spriority")
    case "$sstatus" in
        completed|rejected) ;;
        in-progress)
            all_done=false
            if [ "$rank" -lt "$best_ip_rank" ] || { [ "$rank" -eq "$best_ip_rank" ] && [[ "$sid" < "$best_ip_id" || -z "$best_ip_id" ]]; }; then
                best_ip_rank=$rank; best_ip_id=$sid
            fi ;;
        blocked)
            all_done=false
            if [ "$rank" -lt "$best_bl_rank" ] || { [ "$rank" -eq "$best_bl_rank" ] && [[ "$sid" < "$best_bl_id" || -z "$best_bl_id" ]]; }; then
                best_bl_rank=$rank; best_bl_id=$sid
            fi ;;
        approved)
            all_done=false
            if [ "$rank" -lt "$best_ap_rank" ] || { [ "$rank" -eq "$best_ap_rank" ] && [[ "$sid" < "$best_ap_id" || -z "$best_ap_id" ]]; }; then
                best_ap_rank=$rank; best_ap_id=$sid
            fi ;;
        *)  # proposed or other
            all_done=false
            if [ "$rank" -lt "$best_pr_rank" ] || { [ "$rank" -eq "$best_pr_rank" ] && [[ "$sid" < "$best_pr_id" || -z "$best_pr_id" ]]; }; then
                best_pr_rank=$rank; best_pr_id=$sid
            fi ;;
    esac
done

# --- Determine recommendation ---
recommend_id="" recommend_reason=""
if [ -n "$best_ip_id" ]; then
    recommend_id="$best_ip_id"; recommend_reason="in-progress"
elif [ -n "$best_bl_id" ]; then
    recommend_id="$best_bl_id"; recommend_reason="blocked"
elif [ -n "$best_ap_id" ]; then
    recommend_id="$best_ap_id"; recommend_reason="approved"
elif [ -n "$best_pr_id" ]; then
    recommend_id="$best_pr_id"; recommend_reason="proposed"
elif [ "$all_done" = true ] && [ "$has_subtasks" = true ]; then
    recommend_reason="all-done"
fi

# --- Output JSON ---
esc_title=$(json_escape "$epic_title")

printf '{"id":"%s","title":"%s","status":"%s"' "$FULL_ID" "$esc_title" "$epic_status"
[ -n "$epic_priority" ] && printf ',"priority":"%s"' "$epic_priority"
[ -n "$epic_goal" ] && printf ',"goal":"%s"' "$epic_goal"
printf ',"subtasks":[%s]' "$subtasks_json"
[ -n "$recommend_id" ] && printf ',"recommend":"%s"' "$recommend_id"
[ -n "$recommend_reason" ] && printf ',"recommend_reason":"%s"' "$recommend_reason"
printf '}\n'
