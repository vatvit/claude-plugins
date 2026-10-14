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
check "…prefix uses the slug" yes "$(contains "CREW_AS=max-coordinator crew" "$out")"
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

echo "-- membership is opt-in (PLUG-055): a title never joins a session"
out="$(hook session-start.sh "$(start_payload sid-b "$R" "Bob Builder")")"
check "titled session is not joined" no "$( [ -f "$R/.git/crew/sessions/bob-builder" ] && echo yes || echo no)"
check "…told it is outside the crew and unguarded" yes "$(contains "you are not in it — its guards do not apply to you" "$out")"
check "…and how to join if it is meant to" yes "$(contains "crew whoami" "$out")"
out="$(hook session-start.sh "$(start_payload sid-n "$R")")"
check "untitled session: the same line, nothing bound" yes "$(contains "you are not in it" "$out")"
join "$R" bob-builder
out="$(hook session-start.sh "$(start_payload sid-bob-builder "$R" "Bob Builder")")"
check "a member that joined explicitly is recognised on start" yes "$(contains "you are bob-builder (worker)" "$out")"
check "coordinator stays explicit" yes "$(contains "Max Coordinator coordinator" "$(cd "$R" && bash "$C" whoami)")"

finish
