#!/usr/bin/env bash
# PLUG-061: one task, one session — crew task sets, shows, refuses, takes over and clears a session's task.
. "$(dirname "$0")/helpers.sh"
R="$TMP/repo"; new_repo "$R"
join "$R" s1 coordinator; join "$R" s2; join "$R" s3

echo "-- set and show"
out="$(crew_as s2 "$R" task 2>&1)"
check "no task yet" yes "$(contains "task: none" "$out")"
out="$(crew_as s2 "$R" task PLUG-7 2>&1)"; rc=$?
check "take a free task" 0 "$rc"
check "…says so" yes "$(contains "task: PLUG-7 — yours" "$out")"
out="$(crew_as s2 "$R" task 2>&1)"
check "show it" yes "$(contains "task: PLUG-7" "$out")"
out="$(crew_as s2 "$R" task PLUG-7 2>&1)"
check "again: already yours" yes "$(contains "already yours" "$out")"
out="$(crew_as s1 "$R" status)"
check "status shows the session's task" yes "$(contains "s2 worker on PLUG-7" "$out")"
out="$(printf '{"session_id":"sid-s3","cwd":"%s"}' "$R" | bash "$H/session-start.sh")"
check "SessionStart shows it too" yes "$(contains "s2 worker on PLUG-7" "$out")"

echo "-- one task, one session"
out="$(crew_as s3 "$R" task PLUG-7 2>&1)"; rc=$?
check "a task another session owns is refused" 1 "$rc"
check "…naming the owner" yes "$(contains "REFUSED, owned by s2" "$out")"
check "…and the hand-over" yes "$(contains "task PLUG-7 --take" "$out")"
check "…and nothing changed" yes "$(contains "s2 worker on PLUG-7 · s3 worker" "$(crew_as s1 "$R" status)")"
out="$(crew_as s3 "$R" task PLUG-7 --take 2>&1)"; rc=$?
check "--take moves it" 0 "$rc"
check "…the new owner has it" yes "$(contains "s2 worker · s3 worker on PLUG-7" "$(crew_as s1 "$R" status)")"
out="$(crew_as s2 "$R" inbox 2>&1)"
check "…and the old owner is told" yes "$(contains "s3 took over PLUG-7" "$out")"

echo "-- one session, one task"
crew_as s3 "$R" task PLUG-8 >/dev/null 2>&1
check "a new task replaces the old one" yes "$(contains "s3 worker on PLUG-8" "$(crew_as s1 "$R" status)")"
check "…and frees it" yes "$(contains "task: PLUG-7 — yours" "$(crew_as s2 "$R" task PLUG-7 2>&1)")"

echo "-- the coordinator assigns"
out="$(crew_as s2 "$R" task PLUG-9 --for s3 2>&1)"; rc=$?
check "a worker cannot assign" 1 "$rc"
out="$(crew_as s1 "$R" task PLUG-9 --for s3 2>&1)"; rc=$?
check "the coordinator can" 0 "$rc"
check "…to that session" yes "$(contains "s3 worker on PLUG-9" "$(crew_as s1 "$R" status)")"
out="$(crew_as s1 "$R" task PLUG-9 --for nobody 2>&1)"; rc=$?
check "not to a session that is not in the crew" 1 "$rc"

echo "-- clear, leave, rejoin"
crew_as s3 "$R" task --clear >/dev/null 2>&1
check "--clear drops it" "sessions: s1 coordinator · s2 worker on PLUG-7 · s3 worker" "$(crew_as s1 "$R" status | grep '^sessions:')"
lacks_out="$(crew_as s1 "$R" status)"
check "…from every view" no "$(contains "PLUG-9" "$lacks_out")"
join "$R" s2
check "re-joining keeps the task" yes "$(contains "s2 worker on PLUG-7" "$(crew_as s1 "$R" status)")"
crew_as s1 "$R" whoami --leave s2 >/dev/null 2>&1
check "leaving frees it" yes "$(contains "task: PLUG-7 — yours" "$(crew_as s3 "$R" task PLUG-7 2>&1)")"

echo "-- tree new takes the task"
crew_as s1 "$R" config set tree worktrees >/dev/null
out="$(crew_as s3 "$R" tree new PLUG-20 2>&1)"
check "the session that makes a task worktree owns the task" yes "$(contains "s3 worker on PLUG-20" "$(crew_as s1 "$R" status)")"
crew_as s1 "$R" task PLUG-21 >/dev/null 2>&1
out="$(crew_as s3 "$R" tree new PLUG-21 2>&1)"; rc=$?
check "a worktree for a task another session owns is still made" 0 "$rc"
check "…with the refusal shown" yes "$(contains "REFUSED, owned by s1" "$out")"
check "…and the task stays with its owner" yes "$(contains "s1 coordinator on PLUG-21" "$(crew_as s1 "$R" status)")"

echo "-- input is data"
out="$(crew_as s3 "$R" task 'x;rm -rf /' 2>&1)"; rc=$?
check "a task id that is not a word is rejected" 1 "$rc"
out="$(crew_as s3 "$R" task PLUG-1 --bogus 2>&1)"; rc=$?
check "an unknown option is rejected" 1 "$rc"
out="$(cd "$R" && bash "$C" task PLUG-1 2>&1)"; rc=$?
check "a caller outside the crew is told to join" 1 "$rc"

finish
