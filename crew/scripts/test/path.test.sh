#!/usr/bin/env bash
# PLUG-043: a bare `crew` command (plugin bin/ is on the Bash tool's PATH) and no CREW_AS prefix:
# SessionStart exports CREW_SID through CLAUDE_ENV_FILE, scripts resolve sid -> name.
. "$(dirname "$0")/helpers.sh"
R="$TMP/repo"; new_repo "$R"
B="$S/../bin/crew"
join "$R" lead coordinator; join "$R" w1

echo "-- bin/crew"
check "bin/crew is executable" yes "$( [ -x "$B" ] && echo yes || echo no)"
out="$(cd "$R" && PATH="$(dirname "$B"):$PATH" crew help)"
check "bare 'crew help' works from PATH" yes "$(contains "whoami" "$out")"

echo "-- identity without CREW_AS"
out="$(cd "$R" && env -u CREW_AS CREW_SID=sid-w1 bash "$B" status)"
check "CREW_SID resolves the caller" yes "$(contains "you: w1 (worker)" "$out")"
out="$(cd "$R" && env -u CREW_AS CREW_SID=sid-w1 bash "$B" msg stop 22:00)"
check "…for messages too" yes "$(contains "w1 → lead: STOP TIME" "$out")"
out="$(cd "$R" && CREW_AS=lead CREW_SID=sid-w1 bash "$B" status)"
check "CREW_AS still overrides" yes "$(contains "you: lead (coordinator)" "$out")"
out="$(cd "$R" && env -u CREW_AS CREW_SID=sid-nobody bash "$B" msg stop 22:00 2>&1)"; rc=$?
check "unknown sid: refused with the way out" 1 "$rc"
check "…naming CREW_AS" yes "$(contains "CREW_AS" "$out")"

echo "-- SessionStart writes the env file"
EF="$TMP/envfile"; : > "$EF"
out="$(printf '{"session_id":"sid-w1","cwd":"%s"}' "$R" | CLAUDE_ENV_FILE="$EF" bash "$H/session-start.sh")"
check "export CREW_SID written" "export CREW_SID=sid-w1" "$(cat "$EF")"
check "…and the session is told to run bare crew" yes "$(contains "run crew commands as: crew <command>" "$out")"
printf '{"session_id":"sid-w1","cwd":"%s"}' "$R" | CLAUDE_ENV_FILE="$EF" bash "$H/session-start.sh" >/dev/null
check "idempotent (resume/compact)" 1 "$(grep -c CREW_SID "$EF")"
out="$(printf '{"session_id":"sid-w1","cwd":"%s"}' "$R" | env -u CLAUDE_ENV_FILE bash "$H/session-start.sh")"
check "no env file: falls back to the CREW_AS form" yes "$(contains "CREW_AS=w1 crew <command>" "$out")"

echo "-- short advice everywhere"
out="$(gx() { hook pre-bash.sh "$(payload sid-w1 "$R" Bash command "$1")"; }; gx 'git add -A')"
check "denials use the short form" yes "$(contains "CREW_AS=w1 crew" "$out")"
check "…not the long plugin path" no "$(contains "scripts/crew.sh" "$out")"

finish
