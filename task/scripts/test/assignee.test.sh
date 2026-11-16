#!/usr/bin/env bash
# Tests for the opt-in assignee (PLUG-138): the `assignees` config mode, the user's id
# (override file, then TASK_ME), the Assignee column and the default mine + unassigned
# view of /task list, assign.sh. Mode off must leave every output as it was.
# Fixtures live in a temp dir only.
#
# Run: bash scripts/test/assignee.test.sh   (from the plugin root)
set -uo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

g() { git -c user.email=t@t -c user.name=t -c init.defaultBranch=main "$@"; }
# task <dir> <num> <title> [assignee] [extra frontmatter line]
task() {
    { printf -- '---\ntitle: %s\nstatus: proposed\npriority: medium\n' "$3"
      [ -z "${4:-}" ] || printf 'assignee: %s\n' "$4"
      [ -z "${5:-}" ] || printf '%s\n' "$5"
      printf -- '---\n\nBody of %s.\n' "$3"; } > "$1/T-$2.md"
}
fixture() { # fixture <dir> [with-assignees]
    mkdir -p "$1"
    task "$1" 001 "mine"          "${2:+Me@X.io}"
    task "$1" 002 "theirs"        "${2:+ann}"
    task "$1" 003 "free"
    task "$1" 004 "theirs too"    "${2:+bo}"
    task "$1" 005 "epic member"   "${2:+ann}" "epic: big"
    task "$1" 006 "the epic"      ""          "type: epic
epic-name: big"
    task "$1" 007 "closed one"    "${2:+ann}" "status: completed"
    return 0
}
L() { local d="$1"; shift; bash "$SC/list-tasks.sh" "$d" T "$@" 2>&1; }

PLAIN="$TMP/plain"; WITH="$TMP/with"
fixture "$PLAIN"; fixture "$WITH" yes

echo "-- T1 mode off: output identical to a task set without assignees (R2) --"
for args in "" "summary" "digest" "group=status" "all" "6" "epic=big"; do
    # shellcheck disable=SC2086
    check "off, no flag: list $args unchanged" "$(L "$PLAIN" $args)" "$(L "$WITH" $args)"
    # shellcheck disable=SC2086
    check "off, --assignees=off: list $args unchanged" "$(L "$PLAIN" $args)" "$(L "$WITH" --assignees=off --me=me@x.io $args)"
done
P="$TMP/proj-off"; mkdir -p "$P"; printf '{\n  "tasksDir": "t",\n  "prefix": "T"\n}\n' > "$P/.task-config.json"
out=$(TASK_ME=me@x.io bash "$SC/resolve-config.sh" "$P")
lacks "off: resolve-config prints no me=" "me=" "$out"
lacks "off: resolve-config prints no assignees=" "assignees=" "$out"

echo "-- T2 an unknown mode is off, with a warning (R1) --"
printf '{\n  "tasksDir": "t",\n  "prefix": "T",\n  "assignees": "bogus"\n}\n' > "$P/.task-config.json"
err=$(bash "$SC/resolve-config.sh" "$P" 2>&1 >/dev/null)
out=$(bash "$SC/resolve-config.sh" "$P" 2>/dev/null)
contains "bogus: warning" "WARNING: assignees=\"bogus\"" "$err"
contains "bogus: reported as off" "assignees=off" "$out"
lacks "bogus: no me=" "me=" "$out"
check "bogus via list-tasks: today's list" "$(L "$PLAIN")" "$(bash "$SC/list-tasks.sh" "$WITH" T --assignees=bogus 2>/dev/null)"

ON="--assignees=self"
echo "-- T3 the Assignee column (R6) --"
out=$(L "$WITH" $ON --me=me@x.io assignee=all)
check "header: ID, Assignee, Status" "ID     Assignee  Status    Priority  Epic    Title" "$(printf '%s\n' "$out" | head -1)"
contains "row shows the assignee as written" "T-001  Me@X.io   proposed" "$out"
out=$(L "$PLAIN" $ON --me=me@x.io)
lacks "no task has one: no column" "Assignee" "$out"
out=$(L "$WITH" $ON --me=me@x.io digest)
contains "digest: assignee line" "T-001  proposed  medium  assignee: Me@X.io" "$out"
mkdir -p "$TMP/cr"; task "$TMP/cr" 001 "dated" "ann" "created: 2026-01-02 03:04"
check "after Created, before Status" "ID     Created     Assignee  Status    Priority  Title" \
  "$(L "$TMP/cr" $ON --me=x assignee=all | head -1)"

echo "-- T4 default view: mine + unassigned, then a drill-down (R7) --"
out=$(L "$WITH" $ON --me=me@x.io)
contains "mine shown (case-insensitive)" "T-001" "$out"
contains "unassigned shown" "T-003" "$out"
contains "epic (unassigned) shown" "T-006" "$out"
lacks "others hidden" "T-002" "$out"
lacks "others hidden (2)" "T-004" "$out"
contains "drill-down line" "+ 3 assigned to others — /task list assignee=all" "$out"
out=$(L "$WITH" $ON --me=ann)
lacks "no others to hide: no line" "assigned to others" "$(L "$TMP/cr" $ON --me=ann)"
out=$(L "$WITH" $ON --me=me@x.io priority=high)
contains "other filters on top: nothing left" "No matching tasks." "$out"
lacks "other filters on top: others counted only if they pass" "assigned to others" "$out"
out=$(L "$WITH" $ON --me=me@x.io summary)
contains "summary: mine + unassigned" "Total open: 3" "$out"
contains "summary: drill-down" "+ 3 assigned to others" "$out"
out=$(L "$WITH" $ON --me=me@x.io all)
lacks "a closed task of others is still hidden" "T-007" "$out"
contains "... and counted" "+ 4 assigned to others" "$out"

echo "-- T5 id unknown: nothing hidden, unassigned first (R7) --"
out=$(L "$WITH" $ON)
check "unassigned first, then the rest by id" "T-003 T-006 T-001 T-002 T-004 T-005" \
  "$(printf '%s\n' "$out" | sed -n 's/^\(T-[0-9]*\).*/\1/p' | tr '\n' ' ' | sed 's/ $//')"
lacks "no drill-down" "assigned to others" "$out"

echo "-- T6 epic views are never narrowed (R8) --"
out=$(L "$WITH" $ON --me=me@x.io 6)
contains "another's sub-task shown" "T-005  ann" "$out"
lacks "no drill-down in an epic view" "assigned to others" "$out"

echo "-- T7 shorthands and matching (R9, Q6) --"
ids() { printf '%s\n' "$1" | sed -n 's/^\(T-[0-9]*\).*/\1/p' | tr '\n' ' ' | sed 's/ $//'; }
check "assignee=me" "T-001" "$(ids "$(L "$WITH" $ON --me=ME@x.io assignee=me)")"
check "assignee=_" "T-003 T-006" "$(ids "$(L "$WITH" $ON --me=me@x.io assignee=_)")"
check "assignee=me,_" "T-001 T-003 T-006" "$(ids "$(L "$WITH" $ON --me=me@x.io assignee=me,_)")"
check "assignee=all" "T-001 T-002 T-003 T-004 T-005 T-006" "$(ids "$(L "$WITH" $ON --me=me@x.io assignee=all)")"
check "assignee=<id>, case ignored" "T-002 T-005" "$(ids "$(L "$WITH" $ON --me=me@x.io assignee=ANN)")"
out=$(bash "$SC/list-tasks.sh" "$WITH" T $ON assignee=me 2>&1); code=$?
check "assignee=me without an id: exit 3" "3" "$code"
contains "... says why" "needs your id" "$out"
check "mode off: assignee=ann is today's exact match" "T-002 T-005" "$(ids "$(L "$WITH" assignee=ann)")"

echo "-- T8 resolve-config me= (R3) --"
NG="$TMP/nogit"; mkdir -p "$NG/t"
printf '{\n  "tasksDir": "t",\n  "prefix": "T",\n  "nextId": 2,\n  "assignees": "unassigned"\n}\n' > "$NG/.task-config.json"
task "$NG/t" 001 "one"
me_of() { sed -n 's/^me=//p'; }
check "neither: me= empty" "" "$(env -u TASK_ME bash "$SC/resolve-config.sh" "$NG" | me_of)"
check "TASK_ME, normalised" "bob@x.io" "$(TASK_ME=' Bob@X.io ' bash "$SC/resolve-config.sh" "$NG" | me_of)"
out=$(bash "$SC/assign.sh" "$NG" --me 'Ann@Y.io')
check "override written outside git: <proj>/.task/me" "ann@y.io" "$(cat "$NG/.task/me")"
contains "... and reported" "file=$NG/.task/me" "$out"
check "override wins over TASK_ME" "ann@y.io" "$(TASK_ME=bob bash "$SC/resolve-config.sh" "$NG" | me_of)"
out=$(bash "$SC/assign.sh" "$NG" --me 'all' 2>&1); code=$?
check "a reserved id is refused" "1" "$code"

echo "-- T9 override in git: common dir, shared by worktrees, never tracked (R4, R15) --"
GP="$TMP/gitproj"; mkdir -p "$GP/t"; GP="$(cd "$GP" && pwd -P)"
printf '{\n  "tasksDir": "t",\n  "prefix": "T",\n  "nextId": 2,\n  "assignees": "self"\n}\n' > "$GP/.task-config.json"
task "$GP/t" 001 "one"
( cd "$GP" && g init -q && g add -A && g commit -qm init && g worktree add -q --detach .wt ) || { echo "FAIL: git fixture"; exit 1; }
before=$(cd "$GP" && git status --porcelain)
bash "$SC/assign.sh" "$GP" --me carol >/dev/null
check "override in the git common dir" "carol" "$(cat "$GP/.git/task/me" 2>/dev/null)"
check "git status unchanged" "$before" "$(cd "$GP" && git status --porcelain)"
check "a linked worktree reads the same id" "carol" "$(env -u TASK_ME bash "$SC/resolve-config.sh" "$GP/.wt" | me_of)"

echo "-- T10 override location not writable: session only (R4) --"
RO="$TMP/ro"; mkdir -p "$RO/t"; : > "$RO/.task"   # a file where the dir would go: even root cannot mkdir it
printf '{\n  "tasksDir": "t",\n  "prefix": "T",\n  "assignees": "self"\n}\n' > "$RO/.task-config.json"
out=$(bash "$SC/assign.sh" "$RO" --me dan 2>&1); code=$?
check "not writable: exit 0" "0" "$code"
contains "not writable: says session scope" "scope=session — $RO/.task not writable" "$out"
lacks "not writable: no file= line" "file=" "$out"

echo "-- T11 assign.sh set, clear, claim, refusals (R11, R12) --"
A() { bash "$SC/assign.sh" "$NG" "$@" 2>&1; }
fm() { sed -n 's/^assignee: //p' "$NG/t/T-001.md"; }
A 1 >/dev/null; check "default who = me (the override)" "ann@y.io" "$(fm)"
out=$(A 1 --claim); contains "claim on my task: mine" "claim=mine" "$out"
A 1 'Bob' >/dev/null; check "set another id, lowercased" "bob" "$(fm)"
out=$(A 1 me --claim); contains "claim on another's: other" "claim=other" "$out"
check "... and nothing changed" "bob" "$(fm)"
A 1 _ >/dev/null; check "_ clears the field" "0" "$(grep -c '^assignee:' "$NG/t/T-001.md")"
out=$(A 1 --claim); contains "claim on unassigned: claimed" "claim=claimed" "$out"
check "... and written" "ann@y.io" "$(fm)"
for bad in all '' 'a,b' 'x"y'; do
    A 1 "$bad" >/dev/null; code=$?
    check "refuses who=[$bad]" "1" "$code"
done
out=$(A 99 bob); code=$?
check "unknown task: exit 1" "1" "$code"
out=$(bash "$SC/assign.sh" "$PLAIN" 1 bob 2>&1); code=$?
check "no config: exit 1" "1" "$code"
mkdir -p "$TMP/offp/t"; printf '{\n  "tasksDir": "t",\n  "prefix": "T"\n}\n' > "$TMP/offp/.task-config.json"; task "$TMP/offp/t" 001 one
out=$(bash "$SC/assign.sh" "$TMP/offp" 1 bob 2>&1); code=$?
check "mode off: refused" "1" "$code"
contains "... with the way to turn it on" "--mode unassigned|self" "$out"
out=$(env -u TASK_ME bash "$SC/assign.sh" "$RO" 1 2>&1); code=$?
check "me unknown: exit 3" "3" "$code"

echo "-- T12 assign.sh mode (R13) --"
MP="$TMP/modep"; mkdir -p "$MP"; printf '{\n  "tasksDir": "t",\n  "prefix": "T",\n  "nextId": 7\n}\n' > "$MP/.task-config.json"
bash "$SC/assign.sh" "$MP" --mode self >/dev/null
check "mode self written, the rest kept" '{|  "tasksDir": "t",|  "prefix": "T",|  "nextId": 7,|  "assignees": "self"|}' \
  "$(tr '\n' '|' < "$MP/.task-config.json" | sed 's/|$//')"
bash "$SC/assign.sh" "$MP" --mode off >/dev/null
check "mode off removes the key" '{|  "tasksDir": "t",|  "prefix": "T",|  "nextId": 7|}' \
  "$(tr '\n' '|' < "$MP/.task-config.json" | sed 's/|$//')"
out=$(bash "$SC/assign.sh" "$MP" --mode team 2>&1); code=$?
check "bad mode refused" "1" "$code"
GH="$TMP/ghome"; GPJ="$TMP/gproj"; mkdir -p "$GH/.claude/project-tasks" "$GPJ"; GPJ="$(cd "$GPJ" && pwd -P)"
printf '{\n  "projects": {\n    "%s": {"tasksDir": "%s/t", "prefix": "T", "nextId": 1}\n  }\n}\n' "$GPJ" "$GPJ" > "$GH/.claude/project-tasks/config.json"
out=$(env -u CLAUDE_CONFIG_DIR HOME="$GH" bash "$SC/assign.sh" "$GPJ" --mode self 2>&1); code=$?
check "global-registry project refused" "1" "$code"
contains "... names where to edit" "set \"assignees\": \"self\"" "$out"

echo "-- T13 without HOME (R14) --"
: > "$TMP/home-is-a-file"
for h in unset missing file; do
    case "$h" in
        unset)   run() { env -u HOME -u CLAUDE_CONFIG_DIR -u TASK_ME bash "$@" 2>&1; } ;;
        missing) run() { env -u CLAUDE_CONFIG_DIR -u TASK_ME HOME="$TMP/no-such-home" bash "$@" 2>&1; } ;;
        file)    run() { env -u CLAUDE_CONFIG_DIR -u TASK_ME HOME="$TMP/home-is-a-file" bash "$@" 2>&1; } ;;
    esac
    check "HOME $h: me from the project" "ann@y.io" "$(run "$SC/resolve-config.sh" "$NG" | me_of)"
    run "$SC/assign.sh" "$NG" 1 _ >/dev/null; run "$SC/assign.sh" "$NG" 1 >/dev/null
    check "HOME $h: assign works" "ann@y.io" "$(fm)"
    contains "HOME $h: default view" "+ 3 assigned to others" "$(run "$SC/list-tasks.sh" "$WITH" T $ON --me=me@x.io)"
done

echo "-- T14 review fixes (PLUG-138 follow-up) --"
# ~ is a substring match: me and all are plain text there, never the shorthands.
check "assignee~me is a substring, not mine" "T-001" "$(ids "$(L "$WITH" $ON --me=ann assignee~me)")"
out=$(bash "$SC/list-tasks.sh" "$WITH" T $ON 'assignee~me' 2>&1); code=$?
check "assignee~me needs no id" "0" "$code"
check "assignee~all matches only text" "" "$(ids "$(L "$WITH" $ON --me=ann assignee~all)")"
# A saved id that is not usable falls back to TASK_ME.
mkdir -p "$NG/.task"; printf 'me\n' > "$NG/.task/me"
check "unusable override: TASK_ME wins" "bob@x.io" "$(TASK_ME=bob@x.io bash "$SC/resolve-config.sh" "$NG" | me_of)"
bash "$SC/assign.sh" "$NG" --me ann@y.io >/dev/null
# Epics named like the old verbs are ordinary ids.
task "$NG/t" 002 "epic mode" "" "type: epic
epic-name: mode"
task "$NG/t" 003 "epic me" "" "type: epic
epic-name: me"
bash "$SC/assign.sh" "$NG" mode bob >/dev/null 2>&1
check "an epic named mode can be assigned" "bob" "$(sed -n 's/^assignee: //p' "$NG/t/T-002.md")"
out=$(bash "$SC/assign.sh" "$NG" me me --claim 2>&1)
contains "an epic named me can be claimed" "claim=claimed" "$out"
check "... and is the user's" "ann@y.io" "$(sed -n 's/^assignee: //p' "$NG/t/T-003.md")"

report assignee
