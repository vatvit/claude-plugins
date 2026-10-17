#!/usr/bin/env bash
# PLUG-075: `crew end` — disband a crew and give the repo back its no-crew state; refused while
# something would be lost, unless the user says --force.
. "$(dirname "$0")/helpers.sh"
R="$TMP/repo"; new_repo "$R"
join "$R" e1 coordinator; (cd "$R" && bash "$C" whoami "Eve Worker" --sid sid-eve) >/dev/null
crew_as eve-worker "$R" hold a.txt >/dev/null
crew_as eve-worker "$R" slot request cpu 5 >/dev/null

echo "-- refused"
out="$(crew_as eve-worker "$R" end 2>&1)"; rc=$?
check "a worker cannot end the crew" 1:yes "$rc:$(contains "only the coordinator ends the crew" "$out")"
crew_as e1 "$R" copy new keep >/dev/null 2>&1
printf 'unlanded\n' > "$R/.worktrees/repo-keep/a.txt"
crew_as e1 "$R" msg stop 18:00 --to eve-worker --send >/dev/null 2>&1
out="$(crew_as e1 "$R" end 2>&1)"; rc=$?
check "refused while a copy holds unlanded work" 1:yes "$rc:$(contains ".worktrees/repo-keep (copy keep): a.txt" "$out")"
check "…and while mail is unread" yes "$(contains "eve-worker: 1 unread" "$out")"
check "…saying how to override" yes "$(contains "crew end --force" "$out")"
check "nothing was removed" yes "$( [ -d "$R/.git/crew/sessions" ] && echo yes || echo no)"

echo "-- forced"
out="$(cd "$R" && bash "$C" end --force 2>&1)"; rc=$?
check "--force ends it, even with no identity" 0 "$rc"
check "the crew state is gone" no "$( [ -e "$R/.git/crew" ] && echo yes || echo no)"
check "names are free on the machine" "" "$(ls "$CREW_HOME/names" 2>/dev/null)"
check "the copy is left in place, and named" yes:yes "$( [ -d "$R/.worktrees/repo-keep" ] && echo yes):$(contains "left in place: .worktrees/repo-keep" "$out")"
check "a ready message for every member" yes "$(contains "send it with SendMessage to: e1, Eve Worker" "$out")"
check "…saying what was released" yes "$(contains "released: 1 hold, 1 slot" "$out")"
check "a record outside the removed state" yes "$(contains "repo" "$(cat "$CREW_HOME/ended" 2>/dev/null)")"
out="$(hook session-start.sh "$(payload sid-e1 "$R" x x x)")"
check "SessionStart is silent again" "" "$out"
out="$(cd "$R" && bash "$C" active)"; rc=$?
check "crew active says no" 1 "$rc"

echo "-- clean end, and again"
Q="$TMP/q"; new_repo "$Q"; join "$Q" q1 coordinator; join "$Q" q2
out="$(crew_as q1 "$Q" end 2>&1)"; rc=$?
check "the coordinator ends a crew with nothing open" 0 "$rc"
check "…message to the others" yes "$(contains "to: q2" "$out")"
out="$(cd "$Q" && bash "$C" end 2>&1)"; rc=$?
check "a second end is a no-op" 0:yes "$rc:$(contains "no crew in this repo — nothing to end" "$out")"
join "$Q" q1 coordinator
check "a new crew can start after" yes "$( [ -f "$Q/.git/crew/sessions/q1" ] && echo yes || echo no)"

finish
