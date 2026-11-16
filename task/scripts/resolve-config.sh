#!/usr/bin/env bash
# Resolve project configuration for the current working directory.
# Usage: resolve-config.sh [project-dir]
# Output (key=value, one per line):
#   tasksDir=/absolute/path/to/tasks
#   prefix=TASK
#   nextId=7
#   configFile=/absolute/path/to/config
#   configScope=local|global
#   projectDir=/absolute/path   (in a linked git worktree: the main tree)
#   assignees=off|unassigned|self  only when the config has the key
#   me=<id>                     only when assignees is not off: the user's id, empty if unknown
#
# Search order:
#   1. <project-dir>/.task-config.json  (project-local, preferred)
#   2. $CLAUDE_CONFIG_DIR/project-tasks/config.json  (global, if that var is set)
#   3. ~/.claude/project-tasks/config.json  (global, fallback)
#   The first global registry that lists the project wins.
#
# Exit 1 if config missing or project not found.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
# A linked worktree stands for the same place in the main tree.
PROJECT_DIR="$(task_project_dir "${1:-$(pwd)}")"
LOCAL_CONFIG="$PROJECT_DIR/.task-config.json"
# Where a new registry belongs: the active account's root.
PRIMARY_CONFIG="$(task_global_roots | head -n 1)/config.json"

# with_assignees <key=value lines> -> the same lines, with `assignees=` normalised to
# off | unassigned | self (task_assignees_mode warns on anything else) and, when it is
# on, `me=` added: the user's id for this project, empty when unknown (PLUG-138).
# Without the key the lines pass through untouched, so a solo project sees no change.
with_assignees() {
    local raw mode nl='
'
    case "$nl$1" in *"${nl}assignees="*) ;; *) printf '%s\n' "$1"; return 0 ;; esac
    raw=$(task_kv "$1" assignees)
    mode=$(task_assignees_mode "$raw")
    printf '%s\n' "$1" | grep -v '^assignees=' || true
    printf 'assignees=%s\n' "$mode"
    [ "$mode" = "off" ] || printf 'me=%s\n' "$(task_me "$PROJECT_DIR")"
    return 0
}

# --- Try project-local config first ---
if [ -f "$LOCAL_CONFIG" ] && [ -s "$LOCAL_CONFIG" ]; then
    result=$(task_config_read "$LOCAL_CONFIG" 2>/dev/null) || {
        echo "ERROR: Failed to parse local config: $LOCAL_CONFIG" >&2
        exit 1
    }

    # Resolve relative tasksDir against project dir, expand ~. A function, because
    # bash 3.2 cannot parse a `case` pattern's `)` inside `$( )`.
    local_values() {
        echo "$result" | while IFS='=' read -r key val; do
            [ -z "${HOME:-}" ] || val="${val/#\~/$HOME}"
            if [ "$key" = "tasksDir" ]; then
                case "$val" in
                    /*) ;; # absolute — keep as-is
                    *)  val="$PROJECT_DIR/$val" ;; # relative — resolve
                esac
            fi
            printf '%s=%s\n' "$key" "$val"
        done
    }
    out=$(local_values)
    # idSource git: nextId is the clone's cache (id-git.sh), never the config's.
    if printf '%s\n' "$out" | grep -qx 'idSource=git'; then
        # shellcheck source=id-git.sh
        . "$SCRIPT_DIR/id-git.sh"
        out=$(printf '%s\n' "$out" | grep -v '^nextId=' || true)
        td=$(task_kv "$out" tasksDir)
        px=$(task_kv "$out" prefix)
        n=$(idgit_cache_get "$td" "$px")
        [ -z "$n" ] || out="$out
nextId=$n"
    fi
    with_assignees "$out"
    printf 'configFile=%s\n' "$LOCAL_CONFIG"
    printf 'configScope=local\n'
    printf 'projectDir=%s\n' "$PROJECT_DIR"
    exit 0
fi

# --- Fallback to the global registries, first that lists the project wins ---
# lookup_global <config-file> -> key=value lines for PROJECT_DIR; exit 1 if absent.
lookup_global() {
    task_config_read "$1" "$PROJECT_DIR" 2>/dev/null
}

GLOBAL_CONFIG=""
searched=""
while IFS= read -r root; do
    candidate="$root/config.json"
    [ -s "$candidate" ] || continue
    searched="$searched $candidate"
    if result=$(lookup_global "$candidate"); then
        GLOBAL_CONFIG="$candidate"
        break
    fi
done <<EOR
$(task_global_roots)
EOR

if [ -z "$GLOBAL_CONFIG" ]; then
    # Offer the global registry only where one could be created: its account dir
    # (the parent of project-tasks/) exists and is writable. Checked, never created.
    hint="Create .task-config.json in project root"
    primary_root="${PRIMARY_CONFIG%/config.json}"
    if [ "$primary_root" != "" ] && [ -d "${primary_root%/*}" ] && [ -w "${primary_root%/*}" ]; then
        hint="$hint or add project to $PRIMARY_CONFIG"
    fi
    if [ -z "$searched" ]; then
        echo "ERROR: No config found. $hint" >&2
    else
        echo "ERROR: Project not found in config:$searched: $PROJECT_DIR" >&2
        echo "$hint" >&2
    fi
    exit 1
fi

# Expand ~ in values and output
global_values() {
    echo "$result" | while IFS='=' read -r key val; do
        [ -z "${HOME:-}" ] || val="${val/#\~/$HOME}"
        printf '%s=%s\n' "$key" "$val"
    done
}
with_assignees "$(global_values)"
printf 'configFile=%s\n' "$GLOBAL_CONFIG"
printf 'configScope=global\n'
printf 'projectDir=%s\n' "$PROJECT_DIR"
