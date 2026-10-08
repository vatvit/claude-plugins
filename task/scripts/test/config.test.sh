#!/usr/bin/env bash
# Global-registry lookup for resolve-config.sh and resolve-task.sh.
#
# Claude Code sets CLAUDE_CONFIG_DIR when it runs under a non-default account
# (~/.claude-work and the like). The global registry and the global workflow
# must be read from there first, with ~/.claude as the fallback, so a second
# account neither loses the registry nor silently reads the wrong one.
#
# Run: bash scripts/test/config.test.sh   (from the plugin root)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SC="$ROOT/scripts"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0

check() { # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"
    else fail=$((fail+1)); echo "  FAIL $1"; echo "         expected: [$2]"; echo "         actual:   [$3]"; fi
}

H="$TMP/home"; ALT="$H/.claude-alt"
PROJ="$TMP/proj"; mkdir -p "$PROJ" "$H/.claude/project-tasks" "$ALT/project-tasks"

registry() { # registry <file> <prefix>  — a registry that lists PROJ
    printf '{\n  "%s": {\n    "tasksDir": "%s/tasks",\n    "prefix": "%s"\n  }\n}\n' \
        "$PROJ" "$PROJ" "$2" > "$1"
}
other() { printf '{\n  "/nowhere": {\n    "prefix": "NOPE"\n  }\n}\n' > "$1"; }

# rc <CLAUDE_CONFIG_DIR or ""> <key>  — one value from resolve-config.sh
rc() {
    if [ -n "$1" ]; then
        HOME="$H" CLAUDE_CONFIG_DIR="$1" bash "$SC/resolve-config.sh" "$PROJ" 2>&1 | grep "^$2=" | cut -d= -f2-
    else
        env -u CLAUDE_CONFIG_DIR HOME="$H" bash "$SC/resolve-config.sh" "$PROJ" 2>&1 | grep "^$2=" | cut -d= -f2-
    fi
}

echo "-- resolve-config: global registry --"

registry "$H/.claude/project-tasks/config.json" HOME
check "no CLAUDE_CONFIG_DIR reads ~/.claude" "HOME" "$(rc "" prefix)"
check "no registry under CLAUDE_CONFIG_DIR falls back to ~/.claude" "HOME" "$(rc "$ALT" prefix)"

other "$ALT/project-tasks/config.json"
check "project missing from CLAUDE_CONFIG_DIR registry falls back" "HOME" "$(rc "$ALT" prefix)"

registry "$ALT/project-tasks/config.json" ALT
check "CLAUDE_CONFIG_DIR registry wins" "ALT" "$(rc "$ALT" prefix)"
check "configFile names the registry that matched" "$ALT/project-tasks/config.json" "$(rc "$ALT" configFile)"
check "trailing slash on CLAUDE_CONFIG_DIR" "ALT" "$(rc "$ALT/" prefix)"
check "CLAUDE_CONFIG_DIR=~/.claude is not searched twice" "HOME" "$(rc "$H/.claude" prefix)"

rm -f "$H/.claude/project-tasks/config.json" "$ALT/project-tasks/config.json"
err=$(HOME="$H" CLAUDE_CONFIG_DIR="$ALT" bash "$SC/resolve-config.sh" "$PROJ" 2>&1); code=$?
check "no registry anywhere exits 1" "1" "$code"
check "error points at the active account's registry" "yes" \
    "$(echo "$err" | grep -qF "$ALT/project-tasks/config.json" && echo yes || echo no)"

printf '{\n  "tasksDir": "tasks",\n  "prefix": "LOC"\n}\n' > "$PROJ/.task-config.json"
registry "$ALT/project-tasks/config.json" ALT
check "project-local config still wins over any registry" "LOC" "$(rc "$ALT" prefix)"

echo "-- resolve-task: global workflow step files --"

T="$PROJ/tasks"; mkdir -p "$T"
printf -- '---\ntitle: t\nstatus: proposed\n---\n\n## Workflow\n\n| # | Step | Status |\n|---|------|--------|\n| 10 | Assessment | — |\n' > "$T/WF-001.md"
mkdir -p "$H/.claude/project-tasks/_workflow/steps" "$ALT/project-tasks/_workflow/steps"
echo home > "$H/.claude/project-tasks/_workflow/steps/assessment.md"

step() { HOME="$H" CLAUDE_CONFIG_DIR="$ALT" bash "$SC/resolve-task.sh" "$T" WF 1 2>&1 | grep '^step_file=' | cut -d= -f2-; }
check "step file falls back to ~/.claude" "$H/.claude/project-tasks/_workflow/steps/assessment.md" "$(step)"
echo alt > "$ALT/project-tasks/_workflow/steps/assessment.md"
check "step file from CLAUDE_CONFIG_DIR wins" "$ALT/project-tasks/_workflow/steps/assessment.md" "$(step)"
mkdir -p "$T/_workflow/steps"; echo proj > "$T/_workflow/steps/assessment.md"
check "project step file still wins" "$T/_workflow/steps/assessment.md" "$(step)"

echo
echo "passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
