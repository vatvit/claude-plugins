#!/usr/bin/env bash
# renumber.sh (PLUG-127): move a task to a freshly allocated id: its content,
# created date and artifacts go with it, its own mentions follow, and other tasks
# change only when named, because after a clash a mention may mean either task.
#
# Run: bash scripts/test/renumber.test.sh   (from the plugin root)
set -uo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

PROJ="$TMP/proj"; T="$PROJ/tasks"; mkdir -p "$T"
printf '{\n  "tasksDir": "tasks",\n  "prefix": "RN",\n  "nextId": 1\n}\n' > "$PROJ/.task-config.json"
rn() { bash "$SC/renumber.sh" "$PROJ" "$@"; }

printf -- '---\ntitle: "RN-001: the one that moves"\nstatus: proposed\ncreated: 2020-01-02 03:04\n---\n\nSee RN-001/notes.md. Not RN-0010, not XRN-001.\n' > "$T/RN-001.md"
mkdir -p "$T/RN-001"; echo notes > "$T/RN-001/notes.md"
printf -- '---\ntitle: depends on it\nstatus: proposed\ndepends-on: [RN-001]\n---\n\nAfter RN-001.\n' > "$T/RN-002.md"
printf -- '---\ntitle: mentions it\nstatus: proposed\n---\n\nLike RN-001, sort of.\n' > "$T/RN-003.md"
printf -- '---\ntitle: a big number\nstatus: proposed\n---\n\nRN-1000 and RN-100 are different.\n' > "$T/RN-004.md"
: > "$T/RN-100.md"; : > "$T/RN-1000.md"

echo "-- refusals change nothing --"
snap() { ( cd "$T" && ls -R; cat ./*.md ) | cksum; }
s0=$(snap)
out=$(rn RN-077 2>&1); rc=$?
check "a missing task is refused" "1" "$rc"
out=$(rn 'RN-001;rm' 2>&1); rc=$?
check "a malformed id is refused" "1" "$rc"
out=$(rn RN-001 --update RN-099 2>&1); rc=$?
check "an --update id that does not exist is refused" "1" "$rc"
contains "... naming it" "RN-099" "$out"
check "nothing changed, nothing allocated" "$s0" "$(snap)"

echo "-- renumber, updating RN-002 only --"
out=$(rn RN-001 --update RN-002 2>&1); rc=$?
check "it succeeds" "0" "$rc"
contains "old= is printed" "old=RN-001" "$out"
contains "new= is the next free id" "new=RN-1001" "$out"
N="$T/RN-1001.md"
check "the old file is gone" "no" "$([ -e "$T/RN-001.md" ] && echo yes || echo no)"
check "own mentions follow, at a boundary only" \
  "See RN-1001/notes.md. Not RN-0010, not XRN-001." "$(tail -1 "$N")"
check "the title follows" 'title: "RN-1001: the one that moves"' "$(grep '^title' "$N")"
check "created is kept" "created: 2020-01-02 03:04" "$(grep '^created' "$N")"
check "renumbered-from is recorded" "renumbered-from: RN-001" "$(grep '^renumbered-from' "$N")"
check "the artifacts moved" "notes" "$(cat "$T/RN-1001/notes.md" 2>/dev/null)"
check "... and the old folder is gone" "no" "$([ -d "$T/RN-001" ] && echo yes || echo no)"
check "--update rewrote depends-on" "depends-on: [RN-1001]" "$(grep '^depends-on' "$T/RN-002.md")"
check "--update rewrote the text" "After RN-1001." "$(tail -1 "$T/RN-002.md")"
check "an unnamed task is untouched" "Like RN-001, sort of." "$(tail -1 "$T/RN-003.md")"
contains "... and reported as a ref" "ref=RN-003:" "$out"
lacks "a task updated is not reported" "ref=RN-002" "$out"

echo "-- boundaries with wider ids --"
rn RN-100 --update RN-004 >/dev/null 2>&1
check "RN-100 changes, RN-1000 does not" "RN-1000 and RN-1002 are different." "$(tail -1 "$T/RN-004.md")"

echo "-- an epic --"
printf -- '---\ntitle: an epic\nstatus: proposed\ntype: epic\nepic-name: big\n---\n' > "$T/RN-005.md"
bash "$SC/update-epic-index.sh" "$T" RN >/dev/null 2>&1
rn RN-005 >/dev/null 2>&1
contains "the epic index follows" '"big":"RN-1003"' "$(cat "$T/_epic-index.json")"

report renumber
