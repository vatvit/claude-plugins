#!/usr/bin/env bash
# PLUG-154: the working coordinator. With exactly one worker, the coordinator is told it may take a
# task of its own — in status and at SessionStart, never to a worker, and not once it has a task.
. "$(dirname "$0")/helpers.sh"
K="$S/../skills/crew"
HINT="take a task of your own"
R="$TMP/repo"; new_repo "$R"
start() { hook session-start.sh "$(payload "sid-$1" "$R" x x x)"; }

echo "-- a coordinator alone: no hint (no worker to give separate tasks to)"
join "$R" lead coordinator
check "status" no "$(contains "$HINT" "$(crew_as lead "$R" status)")"

echo "-- one worker: the coordinator is told"
join "$R" w1
check "status" yes "$(contains "$HINT" "$(crew_as lead "$R" status)")"
check "SessionStart" yes "$(contains "$HINT" "$(start lead)")"
check "…never the worker's status" no "$(contains "$HINT" "$(crew_as w1 "$R" status)")"
check "…nor the worker's SessionStart" no "$(contains "$HINT" "$(start w1)")"

echo "-- once the coordinator owns a task, the hint goes"
crew_as lead "$R" task PLUG-1 >/dev/null
check "status" no "$(contains "$HINT" "$(crew_as lead "$R" status)")"
check "SessionStart" no "$(contains "$HINT" "$(start lead)")"

echo "-- two workers: the coordinator coordinates, no hint"
R="$TMP/repo2"; new_repo "$R"   # names are unique on the machine, so new ones here
join "$R" boss coordinator; join "$R" wa; join "$R" wb
check "status" no "$(contains "$HINT" "$(crew_as boss "$R" status)")"
check "SessionStart" no "$(contains "$HINT" "$(start boss)")"
crew_as boss "$R" whoami --leave wb >/dev/null
check "…a worker leaves, one is left: the hint appears" yes "$(contains "$HINT" "$(crew_as boss "$R" status)")"

echo "-- the skill states the rule"
out="$(cat "$K/SKILL.md")"
check "SKILL.md: the coordinator may take a task of its own" yes "$(contains "a task of its own" "$out")"
check "SKILL.md: coordinating comes first" yes "$(contains "Coordinating comes first" "$out")"
check "SKILL.md: a short side job goes to a subagent" yes "$(contains "subagent" "$out")"

finish
