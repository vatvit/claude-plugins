#!/usr/bin/env bash
# Offline allocation with the git id source (PLUG-128): an id allocated while the
# remote is unreachable is recorded as pending in the clone's cache; the next push
# claims it, in the same push as a new reservation; one the remote counter already
# passed is reported as a possible clash and kept until renumber.sh moves it.
#
# Fixture repos under $TMP only; HOME and the system git config are isolated.
# Run: bash scripts/test/offline.test.sh   (from the plugin root; needs git)
set -uo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

command -v git >/dev/null 2>&1 || { echo "SKIP: git not installed"; exit 0; }
export HOME="$TMP/home" GIT_CONFIG_NOSYSTEM=1; mkdir -p "$HOME"; unset CLAUDE_CONFIG_DIR

g() { git -c user.email=u@t -c user.name=u -c init.defaultBranch=main "$@"; }
alloc() { bash "$SC/allocate-id.sh" "$@"; }
idsrc() { bash "$SC/id-source.sh" "$@"; }
counter() { git -C "$REMOTE" show "task-ids:OF.next-id" 2>/dev/null; }
commits() { git -C "$REMOTE" rev-list --count task-ids 2>/dev/null || echo 0; }
offline() { git -C "$1" remote set-url origin "$TMP/nowhere.git"; }
online() { git -C "$1" remote set-url origin "$REMOTE"; }
field() { idsrc "$1" status | sed -n "s/^$2=//p"; }

REMOTE="$TMP/remote.git"; g init -q --bare "$REMOTE"
A="$TMP/a"; mkdir -p "$A/tasks"
printf '{\n  "tasksDir": "tasks",\n  "prefix": "OF",\n  "nextId": 1\n}\n' > "$A/.task-config.json"
( cd "$A" && g init -q && g add -A && g commit -qm init && g remote add origin "$REMOTE" && g push -q origin main )
idsrc "$A" git >/dev/null
( cd "$A" && g commit -qam "git ids" && g push -q origin main )
B="$TMP/b"; g clone -q "$REMOTE" "$B"

echo "-- offline: allocated at once, recorded as pending --"
offline "$A"
out=$(alloc "$A" 2>&1); rc=$?
check "allocation succeeds" "0" "$rc"
contains "it takes the next id" "OF-001=" "$out"
contains "it says the id is pending" "pending" "$out"
check "status lists it as pending" "OF-001" "$(field "$A" pending)"
check "the remote did not move" "1" "$(counter)"

echo "-- back online: the pending id is claimed with the next reservation, in one push --"
online "$A"; c0=$(commits)
out=$(alloc "$A" 2>&1)
contains "the new id follows the pending one" "OF-002=" "$out"
check "one push" "$((c0 + 1))" "$(commits)"
check "the counter covers both" "3" "$(counter)"
check "nothing is pending any more" "" "$(field "$A" pending)"
check "no clash" "" "$(field "$A" clash)"
lacks "no clash warning" "clash" "$out"

echo "-- a clash: another clone took the number while A was offline --"
offline "$A"
alloc "$A" >/dev/null 2>&1          # A: OF-003, pending
alloc "$B" >/dev/null 2>&1          # B: OF-003 on the remote (B has no OF-003 file)
online "$A"
out=$(alloc "$A" 2>&1)
contains "the clash is reported" "OF-003" "$out"
contains "... pointing to the renumbering guide" "renumber" "$out"
check "status keeps it as a clash" "OF-003" "$(field "$A" clash)"
check "nothing is pending" "" "$(field "$A" pending)"
contains "A's new id is past the remote's" "OF-004=" "$out"

echo "-- renumber.sh clears a clash --"
out=$(bash "$SC/renumber.sh" "$A" OF-003 2>&1)
contains "the clash moves to a fresh id" "old=OF-003" "$out"
check "status no longer lists the clash" "" "$(field "$A" clash)"

echo "-- sync: claims pending ids without creating a task --"
offline "$A"
alloc "$A" >/dev/null 2>&1
p=$(field "$A" pending)
out=$(idsrc "$A" sync 2>&1); rc=$?
check "sync while unreachable fails" "1" "$rc"
online "$A"
n0=$(ls "$A/tasks" | wc -l | tr -d ' ')
out=$(idsrc "$A" sync 2>&1); rc=$?
check "sync succeeds" "0" "$rc"
check "pending is cleared" "" "$(field "$A" pending)"
check "the counter covers the pending id" "$(( ${p#OF-} + 1 ))" "$(counter)"
check "no task file is created" "$n0" "$(ls "$A/tasks" | wc -l | tr -d ' ')"
out=$(idsrc "$A" sync 2>&1); rc=$?
check "a second sync is a no-op" "0" "$rc"

report offline
