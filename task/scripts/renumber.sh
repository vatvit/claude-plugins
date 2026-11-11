#!/usr/bin/env bash
# Move a task to a freshly allocated id: the fix for two tasks that ended up with
# one id (references/renumber.md).
#
# Usage: renumber.sh <project-dir> <OLD-ID> [--update <ID>...]
#
#   - the new id comes from allocate-id.sh, so it honours idSource (local or git)
#   - the task keeps its content and its created: date; its own mentions of OLD
#     become NEW, and it gains `renumbered-from: OLD`
#   - its artifacts folder <tasksDir>/<OLD>/ moves to <tasksDir>/<NEW>/
#   - mentions of OLD in the tasks named by --update become NEW; no other file is
#     touched, because after a clash a mention may mean either task. Every other
#     task still mentioning OLD is printed as `ref=<ID>:<line>` for the caller to judge
#   - an epic's index is rebuilt
#
# Output: old=<OLD>, new=<NEW>, path=<new file>, then ref= lines.
# Everything is validated before anything is allocated or changed. Ids are used
# as data only: checked against <PREFIX>-<digits> and the files on disk.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

usage() { echo "Usage: renumber.sh <project-dir> <OLD-ID> [--update <ID>...]" >&2; exit 1; }
[ $# -ge 2 ] || usage
PROJECT_DIR="$(task_project_dir "$1")"; RAW_OLD="$2"; shift 2

CONFIG=$("$SCRIPT_DIR/resolve-config.sh" "$PROJECT_DIR")
tasksDir=$(printf '%s\n' "$CONFIG" | sed -n 's/^tasksDir=//p')
prefix=$(printf '%s\n' "$CONFIG" | sed -n 's/^prefix=//p')
[ -n "$tasksDir" ] && [ -n "$prefix" ] || { echo "ERROR: config missing tasksDir/prefix" >&2; exit 1; }

# canon <raw> -> PREFIX-NNN for an existing task of this project, or exit 1.
canon() {
    local id
    id=$(task_canonical_id "$prefix" "$1") || { echo "ERROR: not a task id: '$1'" >&2; exit 1; }
    case "$id" in "$prefix"-*) ;; *) echo "ERROR: $id is not a $prefix task" >&2; exit 1 ;; esac
    [ -f "$tasksDir/$id.md" ] || { echo "ERROR: no task $id in $tasksDir" >&2; exit 1; }
    printf '%s\n' "$id"
}

OLD=$(canon "$RAW_OLD")
UPDATE=""
if [ $# -gt 0 ]; then
    [ "$1" = "--update" ] && [ $# -ge 2 ] || usage
    shift
    for raw in "$@"; do
        id=$(canon "$raw")
        [ "$id" != "$OLD" ] || { echo "ERROR: --update cannot name the task being moved" >&2; exit 1; }
        UPDATE="$UPDATE $id"
    done
fi

# --- Allocate: the old body with its own id as {{ID}} -------------------------
body=$(mktemp); trap 'rm -f "$body"' EXIT
cp "$tasksDir/$OLD.md" "$body"
task_id_replace "$body" "$OLD" "{{ID}}"
line=$("$SCRIPT_DIR/allocate-id.sh" "$PROJECT_DIR" --stdin < "$body")
NEW="${line%%=*}"; NEWPATH="${line#*=}"
[ -n "$NEW" ] && [ -f "$NEWPATH" ] || { echo "ERROR: allocation failed; nothing moved" >&2; exit 1; }

# --- Move ----------------------------------------------------------------------
task_fm_set "$NEWPATH" renumbered-from "$OLD"
if [ -d "$tasksDir/$OLD" ]; then
    if [ -e "$tasksDir/$NEW" ]; then
        echo "WARNING: $tasksDir/$NEW already exists; artifacts left in $tasksDir/$OLD" >&2
    else
        mv "$tasksDir/$OLD" "$tasksDir/$NEW"
    fi
fi
rm -f "$tasksDir/$OLD.md"
# idSource git: the old number is no longer this clone's to claim or to worry about.
if grep -q '^idSource=git$' <<EOC
$CONFIG
EOC
then
    # shellcheck source=id-git.sh
    . "$SCRIPT_DIR/id-git.sh"
    idgit_cache_forget "$tasksDir" "$prefix" "$((10#${OLD#"$prefix"-}))" || true
fi
for id in $UPDATE; do task_id_replace "$tasksDir/$id.md" "$OLD" "$NEW"; done
if grep -q '^type:[[:space:]]*epic[[:space:]]*$' "$NEWPATH"; then
    "$SCRIPT_DIR/update-epic-index.sh" "$tasksDir" "$prefix" >/dev/null
fi

printf 'old=%s\nnew=%s\npath=%s\n' "$OLD" "$NEW" "$NEWPATH"

# --- References left for the caller to judge -----------------------------------
for f in "$tasksDir/$prefix-"*.md; do
    [ -f "$f" ] || continue
    id=$(basename "$f" .md)
    [ "$id" != "$NEW" ] || continue
    for n in $(task_id_lines "$f" "$OLD"); do printf 'ref=%s:%s\n' "$id" "$n"; done
done
exit 0
