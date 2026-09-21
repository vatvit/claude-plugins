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
#   2. ~/.claude/project-tasks/config.json  (global, fallback)
#
# Exit 1 if config missing or project not found.
set -euo pipefail

PROJECT_DIR="${1:-$(pwd)}"
LOCAL_CONFIG="$PROJECT_DIR/.task-config.json"
GLOBAL_CONFIG="$HOME/.claude/project-tasks/config.json"

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

# --- Fallback to global config ---
if [ ! -f "$GLOBAL_CONFIG" ] || [ ! -s "$GLOBAL_CONFIG" ]; then
    echo "ERROR: No config found. Create .task-config.json in project root or add project to $GLOBAL_CONFIG" >&2
    exit 1
fi

result=$(awk -v proj="$PROJECT_DIR" '
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
' "$GLOBAL_CONFIG" 2>/dev/null) || {
    echo "ERROR: Project not found in config: $PROJECT_DIR" >&2
    echo "Create .task-config.json in project root or add project to $GLOBAL_CONFIG" >&2
    exit 1
}

# Expand ~ in values and output
echo "$result" | while IFS='=' read -r key val; do
    val="${val/#\~/$HOME}"
    printf '%s=%s\n' "$key" "$val"
done
printf 'configFile=%s\n' "$GLOBAL_CONFIG"
printf 'configScope=global\n'
