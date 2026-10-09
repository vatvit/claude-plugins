#!/usr/bin/env bash
# PLUG-042: display names with spaces (crew name = slug) and auto-join from the session title.
. "$(dirname "$0")/helpers.sh"
R="$TMP/repo"; new_repo "$R"
start_payload() { printf '{"session_id":"%s","cwd":"%s","hook_event_name":"SessionStart","source":"startup"%s}' "$1" "$2" "${3:+,\"session_title\":\"$3\"}"; }

echo "-- no crew: a titled session creates nothing"
out="$(hook session-start.sh "$(start_payload sid-t "$R" "Ann Worker")")"
check "silent without a crew" "" "$out"
check "…and no crew/ created" no "$( [ -d "$R/.git/crew" ] && echo yes || echo no)"

echo "-- display names"
out="$(cd "$R" && bash "$C" whoami "Max Coordinator" coordinator --sid sid-g)"
check "a display name with a space is accepted" yes "$(contains "you are max-coordinator (coordinator)" "$out")"
check "…display kept" "display=Max Coordinator" "$(grep '^display=' "$R/.git/crew/sessions/max-coordinator")"
check "…prefix uses the slug" yes "$(contains "CREW_AS=max-coordinator bash" "$out")"
hook pre-bash.sh "$(payload sid-a "$R" Bash command "bash $C whoami \"Ann Worker\"")" >/dev/null
out="$(cd "$R" && bash "$C" whoami "Ann Worker")"
check "quoted display name joins through the hook (no --sid)" yes "$(contains "you are ann-worker (worker)" "$out")"
out="$(cd "$R" && bash "$C" whoami "!!!" --sid x 2>&1)"; rc=$?
check "a display with no usable characters is refused" 1 "$rc"
join "$R" PLUG-W1
check "a valid name keeps its case (no slug change)" yes "$( [ -f "$R/.git/crew/sessions/PLUG-W1" ] && echo yes || echo no)"

echo "-- messages and lookups use the display name"
out="$(crew_as ann-worker "$R" msg handoff)"
check "header: display names both sides" yes "$(contains "Ann Worker → Max Coordinator: HANDOFF" "$out")"
out="$(cd "$R" && CREW_AS="Ann Worker" bash "$C" status)"
check "CREW_AS accepts the display name" yes "$(contains "you: ann-worker" "$out")"
out="$(cd "$R" && bash "$C" whoami)"
check "crew line shows display names" yes "$(contains "Max Coordinator coordinator" "$out")"

echo "-- auto-join from the session title"
out="$(hook session-start.sh "$(start_payload sid-b "$R" "Bob Builder")")"
check "titled session joins as a worker" yes "$(contains "you are bob-builder (worker)" "$out")"
check "…bound" "sid=sid-b" "$(grep '^sid=' "$R/.git/crew/sessions/bob-builder")"
out="$(hook session-start.sh "$(start_payload sid-b "$R" "Bob Builder")")"
check "again (resume): still bob-builder" yes "$(contains "you are bob-builder (worker)" "$out")"
out="$(hook session-start.sh "$(start_payload sid-other "$R" "Bob Builder")")"
check "a title held by another session is not taken" "sid=sid-b" "$(grep '^sid=' "$R/.git/crew/sessions/bob-builder")"
check "…join hint instead" yes "$(contains "whoami" "$out")"
out="$(hook session-start.sh "$(start_payload sid-n "$R")")"
check "untitled session: hint, nothing bound" yes "$(contains "Join before editing" "$out")"
check "coordinator stays explicit" yes "$(contains "Max Coordinator coordinator" "$(cd "$R" && bash "$C" whoami)")"

finish
