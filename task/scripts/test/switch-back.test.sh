#!/usr/bin/env bash
# Switching a project back from the git id source to local (PLUG-130): pending ids
# are claimed first when the remote can be reached, nextId returns to the config at
# the remote counter (never lower than anything known), the clone's cache goes, and
# the remote counter branch is left alone. The config is edited, never committed.
#
# Fixture repos under $TMP only; HOME and the system git config are isolated.
# Run: bash scripts/test/switch-back.test.sh   (from the plugin root; needs git)
set -uo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

command -v git >/dev/null 2>&1 || { echo "SKIP: git not installed"; exit 0; }
export HOME="$TMP/home" GIT_CONFIG_NOSYSTEM=1; mkdir -p "$HOME"; unset CLAUDE_CONFIG_DIR

g() { git -c user.email=u@t -c user.name=u -c init.defaultBranch=main "$@"; }
alloc() { bash "$SC/allocate-id.sh" "$@"; }
idsrc() { bash "$SC/id-source.sh" "$@"; }
counter() { git -C "$REMOTE" show "task-ids:SB.next-id" 2>/dev/null; }
cfg() { sed -n "s/^ *\"$2\": *\"*\\([^\",]*\\)\"*,*\$/\\1/p" "$1/.task-config.json"; }
cache() { echo "$1/.git/task-ids/SB.cache"; }

REMOTE="$TMP/remote.git"; g init -q --bare "$REMOTE"
A="$TMP/a"; mkdir -p "$A/tasks"
printf '{\n  "tasksDir": "tasks",\n  "prefix": "SB",\n  "nextId": 1\n}\n' > "$A/.task-config.json"
( cd "$A" && g init -q && g add -A && g commit -qm init && g remote add origin "$REMOTE" && g push -q origin main )
idsrc "$A" git >/dev/null
( cd "$A" && g commit -qam "git ids" && g push -q origin main )
B="$TMP/b"; g clone -q "$REMOTE" "$B"
alloc "$B" >/dev/null 2>&1; alloc "$A" >/dev/null 2>&1     # SB-001 (B), SB-002 (A); counter 3

echo "-- refusals --"
out=$(idsrc "$A" bogus 2>&1); rc=$?
check "an unknown subcommand is still refused" "1" "$rc"

echo "-- back to local, online: pending claimed first --"
git -C "$A" remote set-url origin "$TMP/nowhere.git"
alloc "$A" >/dev/null 2>&1                                   # SB-003 offline, pending
alloc "$B" >/dev/null 2>&1                                   # B, online, also takes SB-003
git -C "$A" remote set-url origin "$REMOTE"
out=$(idsrc "$A" local 2>&1); rc=$?
check "it succeeds" "0" "$rc"
check "the remote counter is not lowered" "4" "$(counter)"
contains "the pending SB-003 is claimed: B passed it, so it is named as a clash" "SB-003 was allocated" "$out"
contains "... and listed as still to check" "still to check for a clash: SB-003" "$out"
check "nextId returns to the config at the remote counter" "4" "$(cfg "$A" nextId)"
check "idSource is gone (local is the default)" "" "$(cfg "$A" idSource)"
check "the clone's cache is gone" "no" "$([ -e "$(cache "$A")" ] && echo yes || echo no)"
check "the remote branch still exists" "yes" "$(git -C "$REMOTE" rev-parse -q --verify task-ids >/dev/null && echo yes || echo no)"
check "nothing was committed" "git ids" "$(git -C "$A" log -1 --format=%s)"
contains "it tells the user to commit and push" "Commit and push" "$out"
out=$(alloc "$A" 2>&1)
contains "the next local allocation continues from there" "SB-004=" "$out"
lacks "... with no git warning" "WARNING" "$out"

echo "-- running it again is a no-op --"
c0=$(cksum < "$A/.task-config.json")
out=$(idsrc "$A" local 2>&1); rc=$?
check "it succeeds" "0" "$rc"
check "the config is unchanged" "$c0" "$(cksum < "$A/.task-config.json")"

echo "-- back to local, offline: unsynced ids are named --"
C="$TMP/c"; g clone -q "$REMOTE" "$C"
idsrc "$C" status >/dev/null                                 # C fetches the counter (4) while online
git -C "$C" remote set-url origin "$TMP/nowhere.git"
alloc "$C" >/dev/null 2>&1                                   # SB-001 in C (it has no task files), pending
out=$(idsrc "$C" local 2>&1); rc=$?
check "it succeeds" "0" "$rc"
contains "it names the ids never synced" "never synced: SB-001" "$out"
check "nextId is the counter as last fetched" "4" "$(cfg "$C" nextId)"

report switch-back
