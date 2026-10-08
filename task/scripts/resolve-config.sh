#!/usr/bin/env bash
# Resolve project configuration for the current working directory.
# Usage: resolve-config.sh [project-dir]
# Output (key=value, one per line):
#   tasksDir=/absolute/path/to/tasks
#   prefix=TASK
#   nextId=7
#
# Search order:
#   1. <project-dir>/.task-config.json  (project-local, preferred)
#   2. $CLAUDE_CONFIG_DIR/project-tasks/config.json  (global, if that var is set)
#   3. ~/.claude/project-tasks/config.json  (global, fallback)
#   The first global registry that lists the project wins.
#
# Exit 1 if config missing or project not found.
set -euo pipefail

PROJECT_DIR="${1:-$(pwd)}"
LOCAL_CONFIG="$PROJECT_DIR/.task-config.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
# Where a new registry belongs: the active account's root.
PRIMARY_CONFIG="$(task_global_roots | head -n 1)/config.json"

# --- Try project-local config first ---
if [ -f "$LOCAL_CONFIG" ] && [ -s "$LOCAL_CONFIG" ]; then
    result=$(awk '
    {
        if (/:/) {
            line = $0
            # Extract key
            sub(/^[^"]*"/, "", line)
            key = line
            sub(/".*/, "", key)
            # Extract value
            line = $0
            sub(/^[^:]*:[ \t]*/, "", line)
            gsub(/^[ \t]+|[ \t,]+$/, "", line)
            val = line
            if (substr(val, 1, 1) == "\"") {
                sub(/^"/, "", val)
                sub(/"[^"]*$/, "", val)
            }
            if (key != "" && val != "") print key "=" val
        }
    }
    ' "$LOCAL_CONFIG" 2>/dev/null) || {
        echo "ERROR: Failed to parse local config: $LOCAL_CONFIG" >&2
        exit 1
    }

    # Resolve relative tasksDir against project dir, expand ~
    echo "$result" | while IFS='=' read -r key val; do
        val="${val/#\~/$HOME}"
        if [ "$key" = "tasksDir" ]; then
            case "$val" in
                /*) ;; # absolute — keep as-is
                *)  val="$PROJECT_DIR/$val" ;; # relative — resolve
            esac
        fi
        printf '%s=%s\n' "$key" "$val"
    done
    printf 'configFile=%s\n' "$LOCAL_CONFIG"
    printf 'configScope=local\n'
    exit 0
fi

# --- Fallback to the global registries, first that lists the project wins ---
# lookup_global <config-file> -> key=value lines for PROJECT_DIR; exit 1 if absent.
lookup_global() {
    awk -v proj="$PROJECT_DIR" '
BEGIN { found = 0; in_block = 0 }
{
    if (!found && index($0, "\"" proj "\"") > 0) {
        found = 1
        if (index($0, "{") > 0) in_block = 1
        next
    }
    if (found && !in_block && index($0, "{") > 0) {
        in_block = 1
        next
    }
    if (in_block) {
        if (index($0, "}") > 0) exit
        if (/:/) {
            line = $0
            # Extract key: text between first pair of double quotes
            sub(/^[^"]*"/, "", line)
            key = line
            sub(/".*/, "", key)
            # Extract value: everything after colon
            line = $0
            sub(/^[^:]*:[ \t]*/, "", line)
            gsub(/^[ \t]+|[ \t,]+$/, "", line)
            # Remove surrounding quotes if string value
            val = line
            if (substr(val, 1, 1) == "\"") {
                sub(/^"/, "", val)
                sub(/"[^"]*$/, "", val)
            }
            if (key != "" && val != "") print key "=" val
        }
    }
}
END { if (!found) exit 1 }
' "$1" 2>/dev/null
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
    if [ -z "$searched" ]; then
        echo "ERROR: No config found. Create .task-config.json in project root or add project to $PRIMARY_CONFIG" >&2
    else
        echo "ERROR: Project not found in config:$searched: $PROJECT_DIR" >&2
        echo "Create .task-config.json in project root or add project to $PRIMARY_CONFIG" >&2
    fi
    exit 1
fi

# Expand ~ in values and output
echo "$result" | while IFS='=' read -r key val; do
    val="${val/#\~/$HOME}"
    printf '%s=%s\n' "$key" "$val"
done
printf 'configFile=%s\n' "$GLOBAL_CONFIG"
printf 'configScope=global\n'
