#!/usr/bin/env bash
# Switching a project with several active clones to the git id source (PLUG-129).
# A clone's task files that no branch of the remote has are its own, unsynced ones.
# The first time the clone uses git ids (its first allocation, or setup), they are
# claimed on the counter, or reported as a possible clash when the counter already
# passed them. Setup also warns about one number under two file names and about task
# files still holding merge-conflict markers.
#
# Fixture repos under $TMP only; HOME and the system git config are isolated.
# Run: bash scripts/test/migration.test.sh   (from the plugin root; needs git)
set -uo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

command -v git >/dev/null 2>&1 || { echo "SKIP: git not installed"; exit 0; }
export HOME="$TMP/home" GIT_CONFIG_NOSYSTEM=1; mkdir -p "$HOME"; unset CLAUDE_CONFIG_DIR

g() { git -c user.email=u@t -c user.name=u -c init.defaultBranch=main "$@"; }
alloc() { bash "$SC/allocate-id.sh" "$@"; }
idsrc() { bash "$SC/id-source.sh" "$@"; }
counter() { git -C "$REMOTE" show "task-ids:MG.next-id" 2>/dev/null; }
field() { idsrc "$1" status | sed -n "s/^$2=//p"; }
task() { printf -- '---\ntitle: %s\nstatus: proposed\n---\n' "$2" > "$1"; }

REMOTE="$TMP/remote.git"; g init -q --bare "$REMOTE"
A="$TMP/a"; mkdir -p "$A/tasks"
printf '{\n  "tasksDir": "tasks",\n  "prefix": "MG",\n  "nextId": 5\n}\n' > "$A/.task-config.json"
for n in 1 2 3 4; do task "$A/tasks/MG-00$n.md" "shared $n"; done
( cd "$A" && g init -q && g add -A && g commit -qm init && g remote add origin "$REMOTE" && g push -q origin main )
B="$TMP/b"; g clone -q "$REMOTE" "$B"
C="$TMP/c"; g clone -q "$REMOTE" "$C"

# Before the switch, B made two tasks of its own that it never pushed.
task "$B/tasks/MG-005.md" "B's own, below the counter-to-be"
task "$B/tasks/MG-009.md" "B's own, above it"

echo "-- A switches; C allocates first and takes MG-005 --"
idsrc "$A" git >/dev/null
( cd "$A" && g commit -qam "git ids" && g push -q origin main )
( cd "$B" && g pull -q ) ; ( cd "$C" && g pull -q )
out=$(alloc "$C" 2>&1)
contains "C gets MG-005" "MG-005=" "$out"
lacks "C has nothing of its own to report" "WARNING" "$out"

echo "-- B's first allocation: its own files are claimed or reported --"
out=$(alloc "$B" 2>&1)
contains "MG-005 is reported as a possible clash" "MG-005 was allocated" "$out"
lacks "MG-009 is not a clash" "MG-009 was allocated" "$out"
contains "B's new id is past its own MG-009" "MG-010=" "$out"
check "the counter covers MG-009 and MG-010" "11" "$(counter)"
check "status keeps the clash" "MG-005" "$(field "$B" clash)"
lacks "tasks the remote has are not reported" "MG-001" "$out"

echo "-- only the first run checks --"
out=$(alloc "$B" 2>&1)
lacks "a second allocation reports nothing" "WARNING" "$out"

echo "-- setup (adopting) in a clone with files of its own --"
D="$TMP/d"; g clone -q "$REMOTE" "$D"
task "$D/tasks/MG-006.md" "D's own, the counter passed it"
out=$(idsrc "$D" git 2>&1); rc=$?
check "setup succeeds" "0" "$rc"
contains "it reports D's own MG-006" "MG-006 was allocated" "$out"
check "status keeps it" "MG-006" "$(field "$D" clash)"

echo "-- setup warns about one number under two names, and conflict markers --"
E="$TMP/e"; g clone -q "$REMOTE" "$E"
task "$E/tasks/MG-03.md" "a second name for 3"
printf -- '---\ntitle: merged\n<<<<<<< HEAD\nstatus: proposed\n=======\nstatus: completed\n>>>>>>> other\n---\n' > "$E/tasks/MG-002.md"
out=$(idsrc "$E" git 2>&1); rc=$?
check "setup still succeeds" "0" "$rc"
contains "it names both files of number 3" "MG-003.md MG-03.md" "$out"
contains "it names the file with conflict markers" "MG-002.md" "$out"
contains "it points to the renumbering guide" "renumber.md" "$out"

report migration
