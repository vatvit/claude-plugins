#!/usr/bin/env bash
# Atomically allocate task ID(s) and reserve the task file(s).
#
# Prevents two concurrent sessions from allocating the same ID. Never trust a
# remembered nextId — always call this script at the moment of creation.
#
# Usage:
#   allocate-id.sh <project-dir> [--count N]   Reserve N ids, create empty files
#   allocate-id.sh <project-dir> --stdin       Reserve 1 id, write stdin as the
#                                              file body ({{ID}} is substituted)
#
# Output (one line per allocated id):
#   TASK-205=/abs/path/to/tasks/TASK-205.md
#
# Safety properties:
#   1. Lock       — mkdir-based mutex serialises concurrent allocations.
#   2. Self-heal  — candidate = max(config nextId, highest existing file + 1),
#                   so a lost increment or a hand-created file cannot cause reuse.
#   3. O_EXCL     — files are created with noclobber; an existing task file is
#                   never overwritten, the allocator skips to the next free id.
#   4. Persisted  — nextId is written back to config before the lock is released.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
# A linked worktree allocates from the main tree's sequence, under its lock.
PROJECT_DIR="$(task_project_dir "${1:-$(pwd)}")"; shift || true

COUNT=1
FROM_STDIN=0
while [ $# -gt 0 ]; do
    case "$1" in
        --count) COUNT="$2"; shift 2 ;;
        --count=*) COUNT="${1#*=}"; shift ;;
        --stdin) FROM_STDIN=1; shift ;;
        *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
    esac
done

case "$COUNT" in ''|*[!0-9]*) echo "ERROR: --count must be a positive integer" >&2; exit 1 ;; esac
[ "$COUNT" -ge 1 ] || { echo "ERROR: --count must be >= 1" >&2; exit 1; }
[ "$FROM_STDIN" -eq 1 ] && [ "$COUNT" -ne 1 ] && { echo "ERROR: --stdin allocates exactly one id" >&2; exit 1; }

# --- Resolve config -----------------------------------------------------------
CONFIG=$("$SCRIPT_DIR/resolve-config.sh" "$PROJECT_DIR")
tasksDir=$(printf '%s\n' "$CONFIG" | sed -n 's/^tasksDir=//p')
prefix=$(printf '%s\n' "$CONFIG" | sed -n 's/^prefix=//p')
nextId=$(printf '%s\n' "$CONFIG" | sed -n 's/^nextId=//p')
configFile=$(printf '%s\n' "$CONFIG" | sed -n 's/^configFile=//p')
configScope=$(printf '%s\n' "$CONFIG" | sed -n 's/^configScope=//p')

[ -n "$tasksDir" ] && [ -n "$prefix" ] || { echo "ERROR: config missing tasksDir/prefix" >&2; exit 1; }
case "$nextId" in ''|*[!0-9]*) nextId=1 ;; esac
mkdir -p "$tasksDir"

# --- Acquire lock -------------------------------------------------------------
LOCK="$tasksDir/.id-alloc.lock"
STALE_AFTER=120   # seconds
acquired=0
for _ in $(seq 1 100); do
    if mkdir "$LOCK" 2>/dev/null; then acquired=1; break; fi
    # Break a lock left behind by a crashed process.
    if [ -d "$LOCK" ]; then
        age=$(( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || stat -c %Y "$LOCK" 2>/dev/null || echo 0) ))
        [ "$age" -gt "$STALE_AFTER" ] && rm -rf "$LOCK"
    fi
    sleep 0.1
done
[ "$acquired" -eq 1 ] || { echo "ERROR: could not acquire id lock: $LOCK" >&2; exit 1; }
trap 'rm -rf "$LOCK"' EXIT
printf 'pid=%s\n' "$$" > "$LOCK/owner"

# --- Self-healing candidate ---------------------------------------------------
# Highest id already on disk wins over a stale/never-incremented counter.
maxExisting=0
for f in "$tasksDir/$prefix-"*.md; do
    [ -e "$f" ] || continue
    n=$(basename "$f" .md); n="${n#"$prefix"-}"
    case "$n" in ''|*[!0-9]*) continue ;; esac
    n=$((10#$n))
    [ "$n" -gt "$maxExisting" ] && maxExisting=$n
done
candidate=$nextId
[ $((maxExisting + 1)) -gt "$candidate" ] && candidate=$((maxExisting + 1))

# --- Reserve files ------------------------------------------------------------
allocated=0
while [ "$allocated" -lt "$COUNT" ]; do
    id=$(printf '%s-%03d' "$prefix" "$candidate")
    path="$tasksDir/$id.md"
    # noclobber: atomic create-or-fail. Never clobbers an existing task file.
    if ( set -o noclobber; : > "$path" ) 2>/dev/null; then
        if [ "$FROM_STDIN" -eq 1 ]; then
            sed "s/{{ID}}/$id/g" > "$path"
        fi
        printf '%s=%s\n' "$id" "$path"
        allocated=$((allocated + 1))
    fi
    candidate=$((candidate + 1))
done

# --- Persist nextId -----------------------------------------------------------
if [ -n "$configFile" ] && [ -f "$configFile" ]; then
    tmp="$configFile.tmp.$$"
    if [ "$configScope" = "local" ]; then
        awk -v v="$candidate" '
            /"nextId"[ \t]*:/ && !done { sub(/:[ \t]*[0-9]+/, ": " v); done = 1 }
            { print }
        ' "$configFile" > "$tmp"
    else
        awk -v proj="$PROJECT_DIR" -v v="$candidate" '
            !found && index($0, "\"" proj "\"") > 0 { found = 1 }
            found && !done && /"nextId"[ \t]*:/ { sub(/:[ \t]*[0-9]+/, ": " v); done = 1 }
            found && !done && /^[ \t]*}/ { found = 0 }
            { print }
        ' "$configFile" > "$tmp"
    fi
    if [ -s "$tmp" ]; then mv "$tmp" "$configFile"; else rm -f "$tmp"; fi
fi
