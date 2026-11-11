#!/usr/bin/env bash
# Choose and inspect where task ids come from (epic task-id-sync).
#
# Usage:
#   id-source.sh <project-dir> git      Switch the project to the git id source:
#                                       create the counter branch on the remote (or
#                                       adopt the one another clone made), seed this
#                                       clone's cache, set idSource=git and remove
#                                       nextId from .task-config.json. Never commits:
#                                       the user commits the config change.
#   id-source.sh <project-dir> sync     Claim on the remote the ids this clone
#                                       allocated while it could not reach it
#                                       (pending), creating no task. Reports any the
#                                       remote had already passed (clash).
#   id-source.sh <project-dir> local    Switch the project back to the local id
#                                       source: claim the pending ids first when the
#                                       remote can be reached, write nextId (the
#                                       remote counter, never lower than anything
#                                       known here) into .task-config.json, remove
#                                       idSource, delete this clone's cache. The
#                                       counter branch on the remote is left alone.
#                                       Never commits. Ids never synced are named.
#   id-source.sh <project-dir> status   Print idSource, remote, branch, the remote
#                                       counter and this clone's cache (nextId,
#                                       pending and clash ids).
#
# The counter starts at max(nextId, highest task file + 1). Adopting an existing
# branch raises it to that value when it is lower and never lowers it, so running
# `git` again, from any clone, is safe.
#
# Only `.task-config.json` in the project is supported: a global registry is
# nested JSON, and a shared id source belongs to the project anyway.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
# shellcheck source=id-git.sh
. "$SCRIPT_DIR/id-git.sh"

usage() { echo "Usage: id-source.sh <project-dir> git|local|sync|status" >&2; exit 1; }
[ $# -eq 2 ] || usage
PROJECT_DIR="$(task_project_dir "$1")"
case "$2" in git|local|sync|status) CMD="$2" ;; *) echo "ERROR: unknown subcommand: $2" >&2; usage ;; esac

CONFIG=$("$SCRIPT_DIR/resolve-config.sh" "$PROJECT_DIR")
cfg() { printf '%s\n' "$CONFIG" | sed -n "s/^$1=//p" | head -n 1; }
tasksDir=$(cfg tasksDir); prefix=$(cfg prefix)
configFile=$(cfg configFile); configScope=$(cfg configScope)
idSource=$(cfg idSource); idSource="${idSource:-local}"
remote=$(cfg idRemote); remote="${remote:-$IDGIT_DEFAULT_REMOTE}"
branch=$(cfg idBranch); branch="${branch:-$IDGIT_DEFAULT_BRANCH}"
[ -n "$tasksDir" ] && [ -n "$prefix" ] || { echo "ERROR: config missing tasksDir/prefix" >&2; exit 1; }
# ids <numbers> -> PREFIX-NNN, space-separated.
ids() { local n out=""; for n in $1; do out="$out $(printf '%s-%03d' "$prefix" "$n")"; done; printf '%s' "${out# }"; }

if [ "$CMD" = status ]; then
    printf 'idSource=%s\nremote=%s\nbranch=%s\n' "$idSource" "$remote" "$branch"
    if repo=$(idgit_repo "$tasksDir"); then
        state=$(idgit_probe "$repo" "$remote" "$branch")
        printf 'remoteState=%s\n' "$state"
        if [ "$state" = ok ] && base=$(idgit_fetch "$repo" "$remote" "$branch") && [ -n "$base" ]; then
            printf 'remoteNextId=%s\n' "$(idgit_read "$repo" "$base" "$prefix")"
        fi
        printf 'cacheNextId=%s\n' "$(idgit_cache_get "$tasksDir" "$prefix")"
        printf 'pending=%s\n' "$(ids "$(idgit_cache_list "$tasksDir" "$prefix" pending)")"
        printf 'clash=%s\n' "$(ids "$(idgit_cache_list "$tasksDir" "$prefix" clash)")"
    else
        printf 'remoteState=norepo\n'
    fi
    exit 0
fi

# --- sync: claim the pending ids ----------------------------------------------
if [ "$CMD" = sync ]; then
    [ "$idSource" = git ] || { echo "ERROR: idSource is $idSource; sync is for idSource git" >&2; exit 1; }
    idgit_validate "$remote" "$branch" "$prefix" || exit 1
    repo=$(idgit_repo "$tasksDir") || { echo "ERROR: $tasksDir is not inside a git repo" >&2; exit 1; }
    case "$(idgit_probe "$repo" "$remote" "$branch")" in
        ok) ;;
        nobranch) echo "ERROR: the remote '$remote' has no branch '$branch'; run: id-source.sh <project-dir> git" >&2; exit 1 ;;
        *) echo "ERROR: the remote '$remote' cannot be reached; the pending ids stay pending" >&2; exit 1 ;;
    esac
    pending=$(idgit_cache_list "$tasksDir" "$prefix" pending)
    floor=$(idgit_cache_get "$tasksDir" "$prefix"); floor="${floor:-0}"
    reserved=$(idgit_reserve "$repo" "$remote" "$branch" "$prefix" "$tasksDir" "$floor" 0 0 "$pending") || exit 1
    idgit_settle "$tasksDir" "$prefix" "$reserved"
    echo "synced=${pending:-none}"
    echo "counter=$(printf '%s\n' "$reserved" | sed -n 's/^next=//p') on $remote/$branch"
    exit 0
fi

# Both switches edit the project's own config: a global registry is nested JSON.
[ "$configScope" = local ] || {
    echo "ERROR: switching the id source needs the project's own .task-config.json (this project uses $configFile)" >&2; exit 1; }


# --- local: the way back ------------------------------------------------------
if [ "$CMD" = local ]; then
    if [ "$idSource" != git ]; then echo "idSource=$idSource (already; nothing to do)"; exit 0; fi
    next=$(( $(task_highest_id "$tasksDir" "$prefix") + 1 ))
    unsynced=""; clash=""
    if repo=$(idgit_repo "$tasksDir"); then
        cached=$(idgit_cache_get "$tasksDir" "$prefix"); [ -n "$cached" ] && [ "$cached" -gt "$next" ] && next=$cached
        pending=$(idgit_cache_list "$tasksDir" "$prefix" pending)
        if idgit_validate "$remote" "$branch" "$prefix" 2>/dev/null &&
           [ "$(idgit_probe "$repo" "$remote" "$branch")" = ok ]; then
            # Claim what is pending, so no other clone is handed those numbers later.
            reserved=$(idgit_reserve "$repo" "$remote" "$branch" "$prefix" "$tasksDir" "$next" 0 0 "$pending") || exit 1
            idgit_settle "$tasksDir" "$prefix" "$reserved"
            counter=$(printf '%s\n' "$reserved" | sed -n 's/^next=//p')
            [ "$counter" -gt "$next" ] && next=$counter
        else
            # Offline: the counter as last fetched, when this clone ever fetched it.
            last=$(idgit_git "$repo" rev-parse -q --verify "refs/remotes/$remote/$branch" 2>/dev/null || true)
            if [ -n "$last" ]; then counter=$(idgit_read "$repo" "$last" "$prefix"); [ "$counter" -gt "$next" ] && next=$counter; fi
            unsynced=$pending
        fi
        clash=$(idgit_cache_list "$tasksDir" "$prefix" clash)
    fi
    task_config_edit "$configFile" num nextId "$next" del idSource || { echo "ERROR: could not update $configFile" >&2; exit 1; }
    if [ -n "${repo:-}" ] && cf=$(idgit_cache_file "$tasksDir" "$prefix"); then
        rm -f "$cf"; rmdir "${cf%/*}" 2>/dev/null || true
    fi
    [ -z "$unsynced" ] || echo "WARNING: the remote could not be reached; never synced: $(ids "$unsynced"). Another clone may hold the same numbers; check before you share them (references/renumber.md)." >&2
    [ -z "$clash" ] || echo "WARNING: still to check for a clash: $(ids "$clash") (references/renumber.md)." >&2
    echo "idSource=local"
    echo "nextId=$next"
    echo "Edited $configFile (idSource removed, nextId: $next). Commit and push it, so every clone allocates locally. The branch $remote/$branch is left as it was; delete it by hand when no clone uses it."
    exit 0
fi

# --- git: set up or adopt -----------------------------------------------------
idgit_validate "$remote" "$branch" "$prefix" || exit 1
repo=$(idgit_repo "$tasksDir") || { echo "ERROR: $tasksDir is not inside a git repo" >&2; exit 1; }
case "$(idgit_probe "$repo" "$remote" "$branch")" in
    noremote) echo "ERROR: the repo has no remote '$remote' (set idRemote, or add the remote)" >&2; exit 1 ;;
    unreachable) echo "ERROR: the remote '$remote' cannot be reached; try again when online" >&2; exit 1 ;;
esac

nextId=$(cfg nextId); case "$nextId" in ''|*[!0-9]*) nextId=0 ;; esac
cached=$(idgit_cache_get "$tasksDir" "$prefix"); [ -n "$cached" ] && [ "$cached" -gt "$nextId" ] && nextId=$cached
floor=$(( $(task_highest_id "$tasksDir" "$prefix") + 1 ))
[ "$nextId" -gt "$floor" ] && floor=$nextId

# One number under two file names, or a task file still holding merge-conflict
# markers: worth fixing before ids are shared. Reported, never blocking.
# numbered_files -> "<number>\t<file name>" per task file. A function: bash 3.2
# cannot parse a `case` pattern's `)` inside `$( )` (root CLAUDE.md).
numbered_files() {
    local f b n
    for f in "$tasksDir/$prefix-"*.md; do
        [ -f "$f" ] || continue; b=$(basename "$f"); n="${b%.md}"; n="${n#"$prefix"-}"
        case "$n" in ''|*[!0-9]*) continue ;; esac
        printf '%s\t%s\n' "$((10#$n))" "$b"
    done
}
dups=$(numbered_files | sort -k1,1n -k2,2 | awk -F'\t' '($1 "") == prev { line = line " " $2; c++; next }
        { if (c) print line; prev = ($1 ""); line = $2; c = 0 } END { if (c) print line }')
[ -z "$dups" ] || printf '%s\n' "$dups" | while IFS= read -r l; do
    echo "WARNING: one number, several files: $l. Keep one, move the others with renumber.sh (references/renumber.md)." >&2; done
marked=$( { grep -l '^<<<<<<< ' "$tasksDir/$prefix-"*.md 2>/dev/null || true; } | while IFS= read -r f; do basename "$f"; done | tr '\n' ' ')
[ -z "$marked" ] || echo "WARNING: merge-conflict markers in: ${marked% }. Two tasks may have been merged into one file; see references/renumber.md (during a merge)." >&2

pending="$(idgit_cache_list "$tasksDir" "$prefix" pending) $(idgit_local_only "$repo" "$remote" "$tasksDir" "$prefix" | tr '\n' ' ')"
reserved=$(idgit_reserve "$repo" "$remote" "$branch" "$prefix" "$tasksDir" "$floor" 0 1 "$pending") || exit 1
counter=$(printf '%s\n' "$reserved" | sed -n 's/^next=//p')
idgit_settle "$tasksDir" "$prefix" "$reserved"
task_config_edit "$configFile" set idSource git del nextId || { echo "ERROR: could not update $configFile" >&2; exit 1; }

echo "idSource=git"
echo "counter=$counter on $remote/$branch ($prefix.next-id)"
echo "Edited $configFile (idSource: git, nextId removed). Commit and push it, so every clone allocates from $remote/$branch."
