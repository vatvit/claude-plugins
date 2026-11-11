#!/usr/bin/env bash
# Any JSON layout of the config files (PLUG-131). A valid .task-config.json on one line
# used to give `tasksDir=<dir>/.tasks","prefix":"T","nextId`, and a one-line global
# registry let the nextId write-back hit the first project instead of this one. One reader
# for both files; nextId is written back in place, keeping the file's layout.
#
# Run: bash scripts/test/config-layout.test.sh   (from the plugin root)
set -uo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

H="$TMP/home"; mkdir -p "$H/.claude/project-tasks"
export HOME="$H"; unset CLAUDE_CONFIG_DIR
rc() { bash "$SC/resolve-config.sh" "$1" 2>&1; }
val() { printf '%s\n' "$1" | sed -n "s/^$2=//p"; }
alloc() { bash "$SC/allocate-id.sh" "$@" 2>&1; }

echo "-- a project config on one line --"
P="$TMP/one"; mkdir -p "$P"
printf '{"tasksDir":".tasks","prefix":"T","nextId":4}\n' > "$P/.task-config.json"
out=$(rc "$P")
check "tasksDir is the dir alone" "$P/.tasks" "$(val "$out" tasksDir)"
check "prefix" "T" "$(val "$out" prefix)"
check "nextId" "4" "$(val "$out" nextId)"
out=$(alloc "$P")
contains "allocation works" "T-004=" "$out"
check "nextId is written back in place, the layout kept" '{"tasksDir":".tasks","prefix":"T","nextId":5}' "$(cat "$P/.task-config.json")"

echo "-- odd but valid layouts --"
Q="$TMP/odd"; mkdir -p "$Q"
printf '{\r\n\t"nextId" :\t7 ,\r\n\t"tasksDir" : "a,b:c" ,"prefix":\r\n "Q" }' > "$Q/.task-config.json"
out=$(rc "$Q")
check "a value holding , and : is kept whole" "$Q/a,b:c" "$(val "$out" tasksDir)"
check "CRLF, tabs, a value on the next line" "Q" "$(val "$out" prefix)"
check "nextId first, spaces around the colon" "7" "$(val "$out" nextId)"
E="$TMP/esc"; mkdir -p "$E"
printf '{"tasksDir": "t \\"x\\" \\\\ y", "prefix": "E"}\n' > "$E/.task-config.json"
check "escapes in a string are decoded" "$E/t \"x\" \\ y" "$(val "$(rc "$E")" tasksDir)"

echo "-- the multi-line form the skill writes still works --"
M="$TMP/multi"; mkdir -p "$M"
printf '{\n  "tasksDir": "tasks",\n  "prefix": "M",\n  "nextId": 2\n}\n' > "$M/.task-config.json"
alloc "$M" >/dev/null
check "nextId written back, the file otherwise unchanged" \
    "$(printf '{\n  "tasksDir": "tasks",\n  "prefix": "M",\n  "nextId": 3\n}')" "$(cat "$M/.task-config.json")"

echo "-- a global registry on one line, two projects --"
G1="$TMP/g1"; G2="$TMP/g2"; mkdir -p "$G1" "$G2"
REG="$H/.claude/project-tasks/config.json"
printf '{"projects":{"%s":{"tasksDir":"%s/tasks","prefix":"GA","nextId":10},"%s":{"tasksDir":"%s/tasks","prefix":"GB","nextId":20}}}\n' \
    "$G1" "$G1" "$G2" "$G2" > "$REG"
out=$(rc "$G2")
check "the second project's own prefix" "GB" "$(val "$out" prefix)"
check "... its tasksDir" "$G2/tasks" "$(val "$out" tasksDir)"
check "... its nextId" "20" "$(val "$out" nextId)"
check "... scope global" "global" "$(val "$out" configScope)"
out=$(alloc "$G2")
contains "allocation in the second project" "GB-020=" "$out"
out=$(rc "$G1"); check "the first project's nextId is untouched" "10" "$(val "$out" nextId)"
out=$(rc "$G2"); check "the second project's nextId moved on" "21" "$(val "$out" nextId)"
out=$(rc "$TMP/unlisted"); contains "a project the registry lacks is still not found" "not found" "$out"

report config-layout
