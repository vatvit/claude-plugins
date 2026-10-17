#!/usr/bin/env bash
# PLUG-032: several crews on one machine — crew id in messages, machine-wide unique names.
. "$(dirname "$0")/helpers.sh"
A="$TMP/alpha"; B="$TMP/beta"; new_repo "$A"; new_repo "$B"

echo "-- names are unique across crews"
join "$A" s1 coordinator
hook pre-bash.sh "$(payload sid-b1 "$B" Bash command "bash $C whoami s1 coordinator")" >/dev/null
out="$(cd "$B" && bash "$C" whoami s1 coordinator 2>&1)"; rc=$?
check "same name in another crew is refused" 1 "$rc"
check "…naming the other crew" yes "$(contains "in use by crew alpha ($A)" "$out")"
check "…suggesting a crew-scoped name" yes "$(contains "Try beta-s1" "$out")"
out="$(cd "$B" && bash "$C" whoami beta-s1 coordinator --sid sid-b1)"
check "the suggested name works" yes "$(contains "crew beta: you are beta-s1 (coordinator)" "$out")"
out="$(cd "$B" && bash "$C" whoami s1 worker --sid sid-b2 --take 2>&1)"; rc=$?
check "--take overrides" 0 "$rc"
check "registry now points at beta" yes "$(contains "beta" "$(cat "$CREW_HOME/names/s1")")"
(cd "$B" && bash "$C" whoami --leave s1) >/dev/null
check "--leave drops our registry entry" no "$( [ -f "$CREW_HOME/names/s1" ] && echo yes || echo no)"

echo "-- stale entries are taken over"
join "$A" s9
rm -f "$A/.git/crew/sessions/s9"               # alpha's s9 is gone without leaving
out="$(cd "$B" && bash "$C" whoami s9 --sid sid-b9 2>&1)"; rc=$?
check "a stale entry is taken without a flag" 0 "$rc"
join "$A" s7
(cd "$A" && bash "$C" whoami s7 --sid sid-other --take) >/dev/null   # rebound to another session
out="$(cd "$B" && bash "$C" whoami s7 --sid sid-b7 2>&1)"; rc=$?
check "an entry whose sid changed is live (rebound): refused" 1 "$rc"

echo "-- crew id in context and messages"
out="$(hook session-start.sh "$(payload sid-s1 "$A" x x x)")"
check "SessionStart names the crew" yes "$(contains "crew alpha: you are s1" "$out")"
out="$(hook session-start.sh "$(payload sid-new "$A" x x x)")"
check "join hint asks for a machine-unique name" yes "$(contains "unique on this machine" "$out")"
join "$A" s2
out="$(crew_as s2 "$A" msg handoff)"
check "msg header is tagged" yes "$(contains "[alpha] s2 → s1: HANDOFF" "$out")"
out="$(crew_as s2 "$A" status)"
check "status header is tagged" yes "$(contains "crew alpha · you: s2" "$out")"
printf '{"crewId":"game api"}' > "$A/.crew.json"
out="$(crew_as s2 "$A" msg stop 22:59)"
check "crewId from .crew.json, sanitised" yes "$(contains "[game-api] s2 → s1" "$out")"
printf '{"crewId":"mine"}' > "$CREW_USER_CONFIG"
rm -f "$A/.crew.json"
out="$(crew_as s2 "$A" msg stop 22:59)"
check "crewId in the user file is ignored" yes "$(contains "[alpha] s2" "$out")"
rm -f "$CREW_USER_CONFIG"

echo "-- PLUG-074: one slot queue for the machine"
export CREW_NOW=1791028800 TZ=UTC                               # 12:00 UTC
join "$B" b1 coordinator; join "$B" b2
crew_as s2 "$A" slot request exclusive 10 --why e2e >/dev/null  # alpha's heavy run holds the machine
out="$(crew_as b2 "$B" slot request cpu 3)"
check "a cpu slot in another repo waits behind it" yes "$(contains "waiting · ETA 12:10" "$out")"
out="$(crew_as b2 "$B" slot start 2)"; rc=$?
check "…start refused, naming the other crew's run" 1:yes "$rc:$(contains "#1 s2 [alpha] exclusive 10m RUNNING" "$out")"
out="$(crew_as s2 "$A" slot list)"
check "alpha sees beta's slot tagged" yes "$(contains "#2 b2 [beta] cpu 3m waiting" "$out")"
out="$(crew_as b1 "$B" slot release 1 2>&1)"; rc=$?
check "beta's coordinator cannot release alpha's slot" yes:yes "$([ "$rc" -ne 0 ] && echo yes):$(contains "s2 of crew alpha — its coordinator releases it" "$out")"
crew_as s2 "$A" slot done >/dev/null
out="$(crew_as b2 "$B" slot start 2)"
check "once alpha is done, beta starts" yes "$(contains "#2 started" "$out")"
crew_as b2 "$B" slot done >/dev/null
crew_as s2 "$A" slot request quiet 5 >/dev/null
out="$(crew_as b1 "$B" slot clear)"; rc=$?
check "another crew's quiet slot does not hold beta's pushes" 0 "$rc"
out="$(crew_as b2 "$B" slot request cpu 1)"
check "…but it still holds the machine" yes "$(contains "waiting" "$out")"
(cd "$A" && bash "$C" whoami --leave s2) >/dev/null
out="$(crew_as b2 "$B" slot start)"
check "a slot whose owner left is reaped: beta runs" yes "$(contains "started" "$out")"
check "…and gone from the machine queue" no "$(contains "quiet" "$(cat "$CREW_HOME/slots")")"
crew_as b2 "$B" slot done >/dev/null
join "$A" a3
out="$(crew_as a3 "$A" slot request exclusive 5)"
check "alpha's new member holds the machine" yes "$(contains "#5 started" "$out")"
rm -rf "$A/.git/crew"                                         # alpha vanishes without ending
out="$(crew_as b2 "$B" slot request cpu 1)"
check "a vanished crew's slot is reaped" yes "$(contains "started" "$out")"

finish
