#!/usr/bin/env bash
# The git id source within bounded time (PLUG-133): every network git call has a
# deadline (TASK_ID_NET_TIMEOUT), a remote that never answers makes allocation fall
# back (or fail) instead of hanging, a session waiting for the id lock during a slow
# but healthy push does not give up, and the lock holder keeps its lock fresh.
#
# Fixture repos under $TMP only; HOME and the system git config are isolated.
# Run: bash scripts/test/net-timeout.test.sh   (from the plugin root; needs git)
set -uo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

command -v git >/dev/null 2>&1 || { echo "SKIP: git not installed"; exit 0; }
export HOME="$TMP/home" GIT_CONFIG_NOSYSTEM=1; mkdir -p "$HOME"; unset CLAUDE_CONFIG_DIR

g() { git -c user.email=u@t -c user.name=u -c init.defaultBranch=main "$@"; }
alloc() { bash "$SC/allocate-id.sh" "$@"; }
counter() { git -C "$REMOTE" show "task-ids:NT.next-id" 2>/dev/null; }
mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"; }

REMOTE="$TMP/remote.git"; g init -q --bare "$REMOTE"
A="$TMP/a"; mkdir -p "$A/tasks"
printf '{\n  "tasksDir": "tasks",\n  "prefix": "NT",\n  "nextId": 1\n}\n' > "$A/.task-config.json"
( cd "$A" && g init -q && g add -A && g commit -qm init && g remote add origin "$REMOTE" && g push -q origin main )
bash "$SC/id-source.sh" "$A" git >/dev/null

echo "-- a remote that never answers: fall back within the deadline --"
printf '#!/bin/sh\nexec sleep 30\n' > "$TMP/hang.sh"; chmod +x "$TMP/hang.sh"
git -C "$A" remote set-url origin "ssh://hang.invalid/r.git"
t0=$(date +%s)
out=$(GIT_SSH="$TMP/hang.sh" TASK_ID_NET_TIMEOUT=2 alloc "$A" 2>&1); rc=$?
dt=$(( $(date +%s) - t0 ))
check "it allocates" "0" "$rc"
contains "locally, as for an unreachable remote" "cannot be reached" "$out"
check "within the deadline, not the hang (${dt}s)" "yes" "$([ "$dt" -lt 10 ] && echo yes || echo no)"
git -C "$A" remote set-url origin "$REMOTE"
alloc "$A" >/dev/null 2>&1                                   # claims the pending NT-001

echo "-- a push that never finishes: fail within the deadline, no task file --"
printf '#!/bin/sh\nsleep 8\n' > "$REMOTE/hooks/pre-receive"; chmod +x "$REMOTE/hooks/pre-receive"
before=$(ls "$A/tasks" | wc -l | tr -d ' ')
t0=$(date +%s)
out=$(TASK_ID_NET_TIMEOUT=2 alloc "$A" 2>&1); rc=$?
dt=$(( $(date +%s) - t0 ))
check "it fails" "1" "$rc"
contains "it says the push did not finish in time" "did not finish within 2s" "$out"
check "no task file was created" "$before" "$(ls "$A/tasks" | wc -l | tr -d ' ')"
check "within the deadline, not the hang (${dt}s)" "yes" "$([ "$dt" -lt 7 ] && echo yes || echo no)"
rm -f "$REMOTE/hooks/pre-receive"

echo "-- a bad TASK_ID_NET_TIMEOUT is ignored, never used --"
out=$(TASK_ID_NET_TIMEOUT='1;touch x' alloc "$A" 2>&1); rc=$?
check "it allocates with the default" "0" "$rc"

echo "-- waiting for the lock during a long hold does not give up --"
mkdir "$A/tasks/.id-alloc.lock"
( sleep 12; rm -rf "$A/tasks/.id-alloc.lock" ) &
t0=$(date +%s)
out=$(alloc "$A" 2>&1); rc=$?
dt=$(( $(date +%s) - t0 ))
wait
check "it waits and allocates" "0" "$rc"
check "it really waited for the holder (${dt}s)" "yes" "$([ "$dt" -ge 11 ] && echo yes || echo no)"

echo "-- the holder keeps the lock fresh before each network call --"
L="$TMP/held.lock"; mkdir "$L"; touch -t 200001010000 "$L"
( . "$SC/lib.sh"; . "$SC/id-git.sh"; IDGIT_LOCK="$L" idgit_probe "$A" origin task-ids >/dev/null )
age=$(( $(date +%s) - $(mtime "$L") ))
check "the lock's mtime is recent (${age}s old)" "yes" "$([ "$age" -lt 60 ] && echo yes || echo no)"

report net-timeout
