#!/usr/bin/env bash
# Tests for the `created:` date (PLUG-099): allocate-id.sh writes it, /task list
# shows it as a Created column and sorts by it, digest prints it.
# Fixtures live in a temp dir only.
#
# Run: bash scripts/test/created.test.sh   (from the plugin root)
set -uo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

# The clock is injected as a date value; allocate-id.sh never executes it.
NOW="2026-03-04 05:06"
PROJ="$TMP/proj"; mkdir -p "$PROJ"
printf '{\n  "tasksDir": "tasks",\n  "prefix": "TST",\n  "nextId": 1\n}\n' > "$PROJ/.task-config.json"
T="$PROJ/tasks"
alloc() { TASK_CREATED_NOW="$NOW" bash "$SC/allocate-id.sh" "$PROJ" "$@"; }

echo "-- allocate-id writes created --"
out=$(printf -- '---\ntitle: one\nstatus: proposed\n---\n\n## Goal\n\ncreated: not me\n' | alloc --stdin)
check "stdin: id printed" "TST-001" "${out%%=*}"
check "stdin: created inside the frontmatter" \
  "---|title: one|status: proposed|created: 2026-03-04 05:06|---" \
  "$(sed -n '1,5p' "$T/TST-001.md" | tr '\n' '|' | sed 's/|$//')"
check "stdin: body untouched" "created: not me" "$(tail -1 "$T/TST-001.md")"

printf -- '---\ntitle: two\ncreated: 2020-01-02 03:04\n---\n' | alloc --stdin >/dev/null
check "stdin: an existing created is kept" "1" "$(grep -c '^created:' "$T/TST-002.md")"
check "stdin: ... with its own value" "created: 2020-01-02 03:04" "$(grep '^created:' "$T/TST-002.md")"

printf 'no frontmatter here\n' | alloc --stdin >/dev/null
check "stdin: no frontmatter, body unchanged" "no frontmatter here" "$(cat "$T/TST-003.md")"

alloc --count 2 >/dev/null
check "count: first file has created" "created: 2026-03-04 05:06" "$(grep '^created:' "$T/TST-004.md")"
check "count: second file has created" "created: 2026-03-04 05:06" "$(grep '^created:' "$T/TST-005.md")"

printf -- '---\ntitle: real clock\n---\n' | bash "$SC/allocate-id.sh" "$PROJ" --stdin >/dev/null
check "real clock: format YYYY-MM-DD HH:MM" "1" \
  "$(grep -cE '^created: [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}$' "$T/TST-006.md")"

out=$(printf -- '---\ntitle: x\n---\n' | TASK_CREATED_NOW='$(touch /tmp/x)' bash "$SC/allocate-id.sh" "$PROJ" --stdin 2>&1)
check "a bad clock value is rejected" "1" "$(printf '%s' "$out" | grep -c 'ERROR')"

echo "-- reading it back --"
check "read-tasks sees the whole value" "2026-03-04 05:06" \
  "$(bash "$SC/read-tasks.sh" "$T" TST --records --id=TST-001 | awk -F'\t' '$2=="created"{print $3}')"

echo "-- list: column and sort --"
L="$TMP/list"; mkdir -p "$L"
mk() { # mk <n> <created|-> <title>
    { echo '---'; echo "title: $3"; echo 'status: proposed'
      [ "$2" != "-" ] && echo "created: $2"
      echo '---'; } > "$L/TST-$1.md"
}
mk 001 "2026-02-01 10:00" "Middle"
mk 002 "-"                "Undated b"
mk 003 "2026-01-15 09:30" "Oldest"
mk 004 "2026-03-01 08:00" "Newest"
mk 005 "-"                "Undated a"
out=$(bash "$SC/list-tasks.sh" "$L" TST)
contains "header: Created right after ID" "ID       Created     " "$out"
contains "row shows the date only" "2026-01-15" "$out"
lacks    "row hides the time" "09:30" "$out"
check "ids in file order by default" "TST-001 TST-002 TST-003 TST-004 TST-005" \
  "$(printf '%s\n' "$out" | sed 1d | awk '{printf "%s%s", (NR>1?" ":""), $1}')"
out=$(bash "$SC/list-tasks.sh" "$L" TST sort=created)
check "sort=created: oldest first, undated last by id" "TST-003 TST-001 TST-004 TST-002 TST-005" \
  "$(printf '%s\n' "$out" | sed 1d | awk '{printf "%s%s", (NR>1?" ":""), $1}')"
out=$(bash "$SC/list-tasks.sh" "$L" TST group=status sort=created)
contains "sort=created inside a group" "TST-003" "$out"
check "grouped: oldest first" "TST-003" "$(printf '%s\n' "$out" | grep -o 'TST-00[0-9]' | head -1)"

echo "-- list: no dates, no column --"
N="$TMP/nodates"; mkdir -p "$N"
printf -- '---\ntitle: Plain\nstatus: proposed\n---\n' > "$N/TST-001.md"
out=$(bash "$SC/list-tasks.sh" "$N" TST)
lacks "no Created column when nobody has a date" "Created" "$out"

echo "-- digest --"
out=$(bash "$SC/list-tasks.sh" "$L" TST digest)
contains "digest shows the date" "created: 2026-01-15" "$out"
lacks    "digest hides the time" "09:30" "$out"
check "undated task has no created in digest" "0" \
  "$(printf '%s\n' "$out" | grep 'TST-002' | grep -c created)"

report created
