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
# Every file gets `created: YYYY-MM-DD HH:MM` (local time) in its frontmatter,
# unless the body already has a `created:` line. This is the only writer of that
# date. TASK_CREATED_NOW overrides the clock for tests; it is read as a date
# value and must match that format, never executed.
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
#
# With `idSource: git` (id-git.sh, set up by id-source.sh) the numbers are first
# reserved by pushing the remote counter branch, so clones of one repo never
# share an id; nextId then lives in the clone's cache, not in the config. When the
# remote cannot be used, allocation stays local and warns that it is not synced.
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

# --- Creation date ------------------------------------------------------------
CREATED="${TASK_CREATED_NOW:-$(date '+%Y-%m-%d %H:%M')}"
case "$CREATED" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\ [0-9][0-9]:[0-9][0-9]) ;;
    *) echo "ERROR: TASK_CREATED_NOW must look like 'YYYY-MM-DD HH:MM'" >&2; exit 1 ;;
esac

# stamp_created: stdin -> stdout, `created:` added before the frontmatter's closing
# `---` unless it has one. Text without frontmatter passes through unchanged.
stamp_created() {
    awk -v created="$CREATED" '
        NR == 1 { fm = ($0 ~ /^---[ \t]*$/); print; next }
        fm == 1 && /^created[ \t]*:/ { has = 1 }
        fm == 1 && /^---[ \t]*$/ { if (!has) print "created: " created; fm = 2 }
        { print }
    '
}

# --- Resolve config -----------------------------------------------------------
CONFIG=$("$SCRIPT_DIR/resolve-config.sh" "$PROJECT_DIR")
tasksDir=$(printf '%s\n' "$CONFIG" | sed -n 's/^tasksDir=//p')
prefix=$(printf '%s\n' "$CONFIG" | sed -n 's/^prefix=//p')
nextId=$(printf '%s\n' "$CONFIG" | sed -n 's/^nextId=//p')
configFile=$(printf '%s\n' "$CONFIG" | sed -n 's/^configFile=//p')
configScope=$(printf '%s\n' "$CONFIG" | sed -n 's/^configScope=//p')

idSource=$(printf '%s\n' "$CONFIG" | sed -n 's/^idSource=//p')
idRemote=$(printf '%s\n' "$CONFIG" | sed -n 's/^idRemote=//p')
idBranch=$(printf '%s\n' "$CONFIG" | sed -n 's/^idBranch=//p')

[ -n "$tasksDir" ] && [ -n "$prefix" ] || { echo "ERROR: config missing tasksDir/prefix" >&2; exit 1; }
case "${idSource:-local}" in
    local|git) ;;
    *) echo "ERROR: unknown idSource '$idSource' (allowed: local, git)" >&2; exit 1 ;;
esac
case "$nextId" in ''|*[!0-9]*) nextId=1 ;; esac
mkdir -p "$tasksDir"

# --- Id source ----------------------------------------------------------------
# MODE is how this run allocates: local (as always), git (reserve on the remote
# counter branch), or gitlocal (idSource is git but the remote cannot be used:
# allocate locally, keep the clone's cache, warn that the ids are not synced).
MODE=local
if [ "$idSource" = git ]; then
    # shellcheck source=id-git.sh
    . "$SCRIPT_DIR/id-git.sh"
    idRemote="${idRemote:-$IDGIT_DEFAULT_REMOTE}"; idBranch="${idBranch:-$IDGIT_DEFAULT_BRANCH}"
    idgit_validate "$idRemote" "$idBranch" "$prefix" || exit 1
    why=""
    if ! repo=$(idgit_repo "$tasksDir"); then
        why="the tasks dir is not in a git repo"
    else
        case "$(idgit_probe "$repo" "$idRemote" "$idBranch")" in
            ok) MODE=git ;;
            noremote) why="the repo has no remote '$idRemote'" ;;
            unreachable) why="the remote '$idRemote' cannot be reached" ;;
            nobranch)
                echo "ERROR: idSource is git, but the remote '$idRemote' has no branch '$idBranch'." >&2
                echo "Set it up once with: $SCRIPT_DIR/id-source.sh $PROJECT_DIR git" >&2
                exit 1 ;;
        esac
    fi
    [ "$MODE" = git ] || {
        MODE=gitlocal
        if [ -n "${repo:-}" ]; then
            echo "WARNING: idSource is git, but $why: allocated locally, not synced with the remote yet. It is recorded as pending: the next allocation that reaches the remote claims it (or: id-source.sh <project-dir> sync)." >&2
        else
            echo "WARNING: idSource is git, but $why: allocated locally, not synced with the remote." >&2
        fi
    }
fi

# --- Acquire lock -------------------------------------------------------------
LOCK="$tasksDir/.id-alloc.lock"
STALE_AFTER=120   # seconds
# Locally the lock is held for milliseconds: give up after 10 s. With git ids the
# holder may be on the network (each call bounded by TASK_ID_NET_TIMEOUT, at most
# 100 s, and it refreshes the lock before each one): wait until a lock would be stale.
waits=100; [ "$MODE" != local ] && waits=$(( (STALE_AFTER + 5) * 10 ))
acquired=0
for _ in $(seq 1 "$waits"); do
    if mkdir "$LOCK" 2>/dev/null; then acquired=1; break; fi
    # Break a lock left behind by a crashed process.
    if [ -d "$LOCK" ]; then
        # GNU/busybox `stat -c` first: busybox `stat -f` is filesystem status, which
        # prints to stdout and fails, so a BSD-first chain captures junk (lock.test.sh).
        age=$(( $(date +%s) - $(stat -c %Y "$LOCK" 2>/dev/null || stat -f %m "$LOCK" 2>/dev/null || echo 0) ))
        [ "$age" -gt "$STALE_AFTER" ] && rm -rf "$LOCK"
    fi
    sleep 0.1
done
[ "$acquired" -eq 1 ] || { echo "ERROR: could not acquire id lock: $LOCK" >&2; exit 1; }
trap 'rm -rf "$LOCK"' EXIT
printf 'pid=%s\n' "$$" > "$LOCK/owner"
IDGIT_LOCK="$LOCK"   # id-git.sh refreshes it before each network call

# --- Self-healing candidate ---------------------------------------------------
# Highest id already on disk wins over a stale/never-incremented counter.
maxExisting=$(task_highest_id "$tasksDir" "$prefix")
candidate=$nextId
[ $((maxExisting + 1)) -gt "$candidate" ] && candidate=$((maxExisting + 1))

# write_task <id> <path> -> create the task file; 1 if it already exists.
# noclobber: atomic create-or-fail. Never clobbers an existing task file.
write_task() {
    ( set -o noclobber; : > "$2" ) 2>/dev/null || return 1
    if [ "$FROM_STDIN" -eq 1 ]; then
        sed "s/{{ID}}/$1/g" | stamp_created > "$2"
    else
        printf -- '---\ncreated: %s\n---\n' "$CREATED" > "$2"
    fi
    printf '%s=%s\n' "$1" "$2"
}

# --- Reserve files ------------------------------------------------------------
if [ "$MODE" = git ]; then
    # The remote push reserves the numbers first; only then are the files made.
    pending=$(idgit_cache_list "$tasksDir" "$prefix" pending)
    # First use of git ids in this clone: its own unpushed task files join the pending.
    if [ -z "$(idgit_cache_get "$tasksDir" "$prefix")" ]; then
        pending="$pending $(idgit_local_only "$repo" "$idRemote" "$tasksDir" "$prefix" | tr '\n' ' ')"
    fi
    reserved=$(idgit_reserve "$repo" "$idRemote" "$idBranch" "$prefix" "$tasksDir" "$candidate" "$COUNT" 0 \
        "$pending") || {
        echo "ERROR: no id allocated; no task file created." >&2; exit 1; }
    for n in $(printf '%s\n' "$reserved" | grep -v '='); do
        id=$(printf '%s-%03d' "$prefix" "$n")
        write_task "$id" "$tasksDir/$id.md" || {
            echo "ERROR: $id.md appeared while its id was being reserved; the id is spent, run again." >&2
            exit 1; }
    done
    candidate=$(printf '%s\n' "$reserved" | sed -n 's/^next=//p')
else
    allocated=0; numbers=""
    while [ "$allocated" -lt "$COUNT" ]; do
        id=$(printf '%s-%03d' "$prefix" "$candidate")
        write_task "$id" "$tasksDir/$id.md" && { allocated=$((allocated + 1)); numbers="$numbers $candidate"; }
        candidate=$((candidate + 1))
    done
fi

# --- Persist nextId -----------------------------------------------------------
# idSource git keeps it in the clone's cache, never in the shared config.
if [ "$MODE" != local ]; then
    if [ "$MODE" = git ]; then idgit_settle "$tasksDir" "$prefix" "$reserved"
    elif [ -n "${repo:-}" ]; then idgit_add_pending "$tasksDir" "$prefix" "$candidate" $numbers; fi
elif [ -n "$configFile" ] && [ -f "$configFile" ]; then
    # In place, in any layout: the whole project config, or this project's registry entry.
    if [ "$configScope" = "local" ]; then task_config_set_num "$configFile" nextId "$candidate" || true
    else task_config_set_num "$configFile" nextId "$candidate" "$PROJECT_DIR" || true; fi
fi
