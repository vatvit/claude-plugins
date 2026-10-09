#!/usr/bin/env bash
# PLUG-026: identity, SessionStart context, layered config, claims, status, msg, dispatcher.
. "$(dirname "$0")/helpers.sh"
R="$TMP/repo"; new_repo "$R"

echo "-- no crew: hooks are silent and exit 0"
out="$(hook session-start.sh "$(payload s1 "$R" x x x)")"; HOOK_RC=$?
check "session-start silent without a crew" "" "$out"
check "session-start exit 0" 0 "$HOOK_RC"
out="$(hook pre-edit.sh "$(payload s1 "$R" Edit file_path "$R/a.txt")")"
check "pre-edit silent without a crew" "" "$out"
out="$(hook pre-bash.sh "$(payload s1 "$TMP" Bash command 'git add -A')")"
check "pre-bash outside a repo: silent" "" "$out"
out="$(printf 'not json' | bash "$H/pre-edit.sh")"; rc=$?
check "malformed payload: exit 0" 0 "$rc"

echo "-- whoami"
out="$(cd "$R" && bash "$C" whoami s1 coordinator 2>&1)"; rc=$?
check "whoami without a visible session id fails" 1 "$rc"
check "…and says how" yes "$(contains "--sid" "$out")"
check "a failed join does not switch crew on (no crew/ dir)" no "$( [ -d "$R/.git/crew" ] && echo yes || echo no)"
check "…and names the restart cause" yes "$(contains "must be restarted" "$out")"
hook pre-bash.sh "$(payload sid-s1 "$R" Bash command "bash $C whoami s1 coordinator")" >/dev/null
check "the parked id alone does not switch crew on either" no "$( [ -d "$R/.git/crew" ] && echo yes || echo no)"
out="$(cd "$R" && bash "$C" whoami s1 coordinator)"
check "whoami binds via the hook's pending id" yes "$(contains "you are s1 (coordinator)" "$out")"
check "…and teaches the prefix" yes "$(contains "CREW_AS=s1 bash" "$out")"
join "$R" s2
out="$(cd "$R" && bash "$C" whoami s3 coordinator --sid sid-s3 2>&1)"; rc=$?
check "a second coordinator is refused" 1 "$rc"
check "…naming the current one" yes "$(contains "s1 is the coordinator" "$out")"
out="$(cd "$R" && bash "$C" whoami s1 --sid other 2>&1)"; rc=$?
check "a name bound to another session is refused" 1 "$rc"
(cd "$R" && bash "$C" whoami s3 coordinator --sid sid-s3 --take) >/dev/null 2>&1
check "--take replaces the coordinator" "coordinator worker" "$(crew_as s3 "$R" whoami >/dev/null; grep -h role= "$R/.git/crew/sessions/s3" "$R/.git/crew/sessions/s1" | sed 's/role=//' | paste -sd' ' -)"
(cd "$R" && bash "$C" whoami s1 coordinator --sid sid-s1 --take) >/dev/null 2>&1
out="$(cd "$R" && bash "$C" whoami bad/name --sid x 2>&1)"; rc=$?
check "a name with odd characters becomes a slug (PLUG-042)" yes "$(contains "you are bad-name" "$out")"
(cd "$R" && bash "$C" whoami --leave bad-name) >/dev/null
(cd "$R" && bash "$C" whoami --leave s3) >/dev/null
check "--leave removes the session" no "$( [ -f "$R/.git/crew/sessions/s3" ] && echo yes || echo no)"

echo "-- SessionStart context"
out="$(hook session-start.sh "$(payload sid-s2 "$R" x x x)")"
check "named session: role line" yes "$(contains "you are s2 (worker)" "$out")"
check "named session: prefix line" yes "$(contains "CREW_AS=s2 bash" "$out")"
check "named session: at most 2 lines" 2 "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
out="$(hook session-start.sh "$(payload sid-new "$R" x x x)")"
check "unnamed session: join hint" yes "$(contains "whoami \"<the name" "$out")"

echo "-- config layering"
out="$(cd "$R" && bash "$C" config)"
check "default committer" yes "$(contains "committer=coordinator (default)" "$out")"
check "default hookMode" yes "$(contains "hookMode=deny (default)" "$out")"
printf '{\n  "committer": "human-approved",\n  "sharedBranch": "develop",\n  "snapshotKeep": 5\n}\n' > "$CREW_USER_CONFIG"
out="$(cd "$R" && bash "$C" config)"
check "user layer applies" yes "$(contains "committer=human-approved (user)" "$out")"
check "user number applies" yes "$(contains "snapshotKeep=5 (user)" "$out")"
check "project-only key ignored in user file" yes "$(contains "sharedBranch=main (default: the checked-out branch)" "$out")"
check "…with a note" yes "$(contains "only makes sense per project" "$out")"
printf '{"committer":"each-session","hotSpots":["src/schema.ts","scenes/*.ts"]}' > "$R/.crew.json"
out="$(cd "$R" && bash "$C" config)"
check "project overrides user" yes "$(contains "committer=each-session (project)" "$out")"
check "project array" yes "$(contains "hotSpots=src/schema.ts,scenes/*.ts (project)" "$out")"
check "partial project file: other keys still layer" yes "$(contains "snapshotKeep=5 (user)" "$out")"
rm -f "$R/.crew.json" "$CREW_USER_CONFIG"

echo "-- per account vs per machine"
mkdir -p "$TMP/acct2" "$HOME/.claude"
printf '{"committer":"each-session"}' > "$TMP/acct2/crew.json"
printf '{"committer":"human-approved"}' > "$HOME/.claude/crew.json"
out="$(cd "$R" && env -u CREW_USER_CONFIG CLAUDE_CONFIG_DIR="$TMP/acct2" bash "$C" config)"
check "user layer follows CLAUDE_CONFIG_DIR" yes "$(contains "committer=each-session (user)" "$out")"
out="$(cd "$R" && env -u CREW_USER_CONFIG -u CLAUDE_CONFIG_DIR bash "$C" config)"
check "…unset: ~/.claude/crew.json" yes "$(contains "committer=human-approved (user)" "$out")"
out="$(cd "$R" && CLAUDE_CONFIG_DIR="$TMP/acct2" bash "$C" config)"
check "…an explicit CREW_USER_CONFIG still wins" yes "$(contains "committer=coordinator (default)" "$out")"
# the name registry is per MACHINE: SendMessage spans accounts, so every account must see one registry
out="$(cd "$R" && env -u CREW_HOME CLAUDE_CONFIG_DIR="$TMP/acct2" bash -c '. "$1"; echo "$CREW_HOME"' x "$S/lib.sh")"
check "CREW_HOME ignores CLAUDE_CONFIG_DIR" "$HOME/.claude/crew" "$out"
rm -f "$HOME/.claude/crew.json"

echo "-- claims + status"
edit "$R" s1 a.txt "s1 edit"
edit "$R" s2 b.txt "s2 edit"
edit "$R" s1 c/new.txt "new"
edit "$R" s2 c/new.txt "both"
printf 'gen\n' > "$R/gen.log"
out="$(crew_as s1 "$R" status)"
check "status header names you" yes "$(contains "you: s1 (coordinator)" "$out")"
check "mine" yes "$(contains "s1 (you): a.txt" "$out")"
check "peer" yes "$(contains "s2: b.txt" "$out")"
check "shared path flagged" yes "$(contains "SHARED s1,s2: c/new.txt" "$out")"
check "unclaimed path flagged" yes "$(contains "unclaimed: gen.log" "$out")"
check "dirty count" yes "$(contains "dirty (4)" "$out")"
out="$(crew_as nobody "$R" status 2>&1)"
check "status works for an unknown caller" yes "$(contains "sessions:" "$out")"

echo "-- msg"
out="$(crew_as s2 "$R" msg handoff --task PLUG-1)"
check "handoff header" yes "$(contains "s2 → s1: HANDOFF — PLUG-1 ready to land" "$out")"
check "handoff lists own paths" yes "$(contains "  b.txt" "$out")"
check "handoff excludes others' paths" no "$(contains "a.txt" "$out")"
check "handoff asks for test-first proof" yes "$(contains "failing on HEAD" "$out")"
printf 'feat(x): y — PLUG-1\n' > "$TMP/m"
out="$(crew_as s2 "$R" msg handoff --msg-file "$TMP/m")"
check "handoff takes the commit message file" yes "$(contains "  feat(x): y — PLUG-1" "$out")"
out="$(crew_as s1 "$R" msg decision use the old schema --by user --to all)"
check "decision" yes "$(contains "s1 → all: DECISION — the user's" "$out")"
out="$(crew_as s1 "$R" msg)"
check "kinds listed" yes "$(contains "handoff" "$out")"
out="$(crew_as s1 "$R" msg nope 2>&1)"; rc=$?
check "unknown kind fails" 1 "$rc"
out="$(cd "$R" && bash "$C" msg handoff 2>&1)"; rc=$?
check "msg without CREW_AS fails" 1 "$rc"

echo "-- dispatcher + payload parsing"
out="$(bash "$C" help)"
check "help lists whoami" yes "$(contains "whoami <name>" "$out")"
out="$(bash "$C" nope 2>&1)"; rc=$?
check "unknown command fails" 1 "$rc"
. "$S/lib.sh"; CREW_ON_EXIT='rm -rf "$TMP"'   # lib owns the EXIT trap
check "payload_str unescapes" 'echo "a b" \x' "$(printf '%s' '{"command":"echo \"a b\" \\x"}' | payload_str command)"
check "payload_str: missing key empty" "" "$(printf '%s' '{"x":"y"}' | payload_str command)"

finish
