#!/usr/bin/env bash
# PLUG-044: durable mailbox — msg --send, inbox, the unread notice (PostToolUse, SessionStart),
# the Stop check, status, and the fork-free fast path.
. "$(dirname "$0")/helpers.sh"
R="$TMP/repo"; new_repo "$R"
join "$R" s1 coordinator; join "$R" s2; join "$R" s3
M="$R/.git/crew/mail"
unread() { ls "$M/$1/new" 2>/dev/null | grep -c . ; }   # unread <name> -> count
mailhook() { printf '%s' "$2" | bash "$H/mail.sh" "$1" 2>"$TMP/hook.err"; }   # mailhook <post|stop> <payload>

echo "-- msg --send"
out="$(crew_as s2 "$R" msg decision plain print)"
check "msg without --send writes no mail" no "$( [ -d "$M" ] && echo yes || echo no)"
printf 'feat(x): y — PLUG-1\n' > "$TMP/m"
out="$(CREW_NOW=1000 crew_as s2 "$R" msg handoff --task PLUG-1 --msg-file "$TMP/m" --send 2>&1)"
check "--send still prints the message for SendMessage" yes "$(contains "s2 → s1: HANDOFF — PLUG-1 ready to land" "$out")"
check "…and says it is in the mailbox" yes "$(contains "in the mailbox of s1" "$out")"
check "the coordinator has 1 unread" 1 "$(unread s1)"
check "the sender has none" 0 "$(unread s2)"

echo "-- unread notice: PostToolUse"
out="$(mailhook post "$(payload sid-s1 "$R" Bash command ls)")"
check "the recipient's next tool call is told" yes "$(contains "1 unread" "$out")"
check "…as PostToolUse additionalContext" yes "$(contains '"hookEventName":"PostToolUse","additionalContext"' "$out")"
check "…naming the command" yes "$(contains "CREW_AS=s1 bash" "$out")"
check "…and inbox" yes "$(contains " inbox" "$out")"
out="$(mailhook post "$(payload sid-s2 "$R" Bash command ls)")"
check "the sender's tool call: nothing" "" "$out"

echo "-- unread notice: SessionStart"
out="$(hook session-start.sh "$(payload sid-s1 "$R" x x x)")"
check "SessionStart says it too" yes "$(contains "1 unread" "$out")"
out="$(hook session-start.sh "$(payload sid-s2 "$R" x x x)")"
check "…and stays at 2 lines with no mail" 2 "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"

echo "-- Stop check"
out="$(mailhook stop "$(payload sid-s1 "$R" x x x)")"
check "a Stop with unread mail is held" yes "$(contains '"decision":"block"' "$out")"
check "…with the reason and the command" yes "$(contains "inbox" "$out")"
out="$(mailhook stop "$(payload sid-s1 "$R" x x x)")"
check "the second Stop for the same mail passes" "" "$out"
out="$(mailhook stop "$(payload sid-s2 "$R" x x x)")"
check "a Stop with no mail passes" "" "$out"

echo "-- inbox"
out="$(crew_as s1 "$R" inbox)"
check "inbox shows the full hand-off" yes "$(contains "paths (" "$out")"
check "…with the commit message" yes "$(contains "feat(x): y — PLUG-1" "$out")"
check "…and the test-first line" yes "$(contains "test-first:" "$out")"
check "…and marks it read" 0 "$(unread s1)"
out="$(crew_as s1 "$R" inbox)"
check "a second inbox: nothing unread" yes "$(contains "no unread" "$out")"
out="$(mailhook post "$(payload sid-s1 "$R" Bash command ls)")"
check "after reading, tool calls are quiet again" "" "$out"
out="$(crew_as s1 "$R" inbox --all)"
check "inbox --all shows read mail too" yes "$(contains "HANDOFF" "$out")"
out="$(cd "$R" && bash "$C" inbox 2>&1)"; rc=$?
check "inbox without CREW_AS fails" 1 "$rc"

echo "-- a new Stop after new mail is held again"
CREW_NOW=1100 crew_as s2 "$R" msg decision second one --send >/dev/null 2>&1
out="$(mailhook stop "$(payload sid-s1 "$R" x x x)")"
check "new mail: held once more" yes "$(contains '"decision":"block"' "$out")"
crew_as s1 "$R" inbox >/dev/null

echo "-- order, --to all, --ack"
CREW_NOW=2000 crew_as s1 "$R" msg decision first --to s2 --send >/dev/null 2>&1
CREW_NOW=2001 crew_as s1 "$R" msg stop 18:00 --to all --send >/dev/null 2>&1
check "--to all reaches s2" 2 "$(unread s2)"
check "…and s3" 1 "$(unread s3)"
check "…but not the sender" 0 "$(unread s1)"
out="$(crew_as s2 "$R" inbox)"
first="$(printf '%s\n' "$out" | grep -n 'DECISION' | cut -d: -f1)"; second="$(printf '%s\n' "$out" | grep -n 'STOP TIME' | cut -d: -f1)"
check "inbox is oldest first" yes "$( [ -n "$first" ] && [ -n "$second" ] && [ "$first" -lt "$second" ] && echo yes || echo no)"
id="$(ls "$M/s3/new")"
out="$(crew_as s3 "$R" inbox --ack nope 2>&1)"; rc=$?
check "--ack of an unknown id fails" 1 "$rc"
out="$(crew_as s3 "$R" inbox --ack "$((10#$id))")"
check "--ack <id> marks one read" 0 "$(unread s3)"
check "…without printing the body" no "$(contains "finish by" "$out")"

echo "-- status"
CREW_NOW=3000 crew_as s2 "$R" msg decision for status --send >/dev/null 2>&1
out="$(crew_as s1 "$R" status)"
check "status shows unread per session" yes "$(contains "s1 1 unread" "$out")"
crew_as s1 "$R" inbox >/dev/null
out="$(crew_as s1 "$R" status)"
check "status: no mail line when all is read" no "$(contains "unread" "$out")"

echo "-- a rejoined session (new sid) is still told"
crew_as s2 "$R" msg decision for rejoin --to s3 --send >/dev/null 2>&1
(cd "$R" && bash "$C" whoami s3 --sid sid-s3b --take) >/dev/null 2>&1
out="$(mailhook post "$(payload sid-s3b "$R" Bash command ls)")"
check "whoami arms the notice for the new sid" yes "$(contains "1 unread" "$out")"
crew_as s3 "$R" inbox >/dev/null

echo "-- a stale marker heals itself"
mkdir -p "$R/.git/crew/unread"; : > "$R/.git/crew/unread/sid-s2"
out="$(mailhook post "$(payload sid-s2 "$R" Bash command ls)")"
check "marker without mail: nothing said" "" "$out"
check "…and the marker is gone" no "$( [ -e "$R/.git/crew/unread/sid-s2" ] && echo yes || echo no)"

echo "-- hookMode=warn: the Stop check warns instead of holding"
printf '{"hookMode":"warn"}' > "$R/.crew.json"
crew_as s2 "$R" msg decision warn mode --send >/dev/null 2>&1
out="$(mailhook stop "$(payload sid-s1 "$R" x x x)")"
check "warn: no block" no "$(contains '"decision":"block"' "$out")"
check "warn: a systemMessage instead" yes "$(contains '"systemMessage"' "$out")"
rm -f "$R/.crew.json"; crew_as s1 "$R" inbox >/dev/null

echo "-- display names"
(cd "$R" && bash "$C" whoami "Max Worker" --sid sid-gw) >/dev/null 2>&1
out="$(crew_as s1 "$R" msg decision hi --to "Max Worker" --send 2>&1)"; rc=$?
check "--to a display name is mailed" 0 "$rc"
check "…into the slug's box" 1 "$(unread max-worker)"
crew_as max-worker "$R" inbox >/dev/null

echo "-- mail is per crew"
R2="$TMP/repo2"; new_repo "$R2"; join "$R2" t1 coordinator; join "$R2" t2
crew_as s2 "$R" msg decision only for crew one --send >/dev/null 2>&1
check "another crew's state has no mail" no "$( [ -d "$R2/.git/crew/mail" ] && echo yes || echo no)"
out="$(mailhook post "$(payload sid-t1 "$R2" Bash command ls)")"
check "…and its coordinator is not told" "" "$out"
crew_as s1 "$R" inbox >/dev/null

echo "-- fast path: no fork without mail"
# With an empty PATH every external command fails loudly, so silence on stderr means no fork.
quiet() { printf '%s' "$2" | env PATH="" "$BASH" "$H/mail.sh" "$1" 2>&1; }
check "PostToolUse, crew without mail: no fork" "" "$(quiet post "$(payload sid-s1 "$R" Bash command ls)")"
check "Stop, crew without mail: no fork" "" "$(quiet stop "$(payload sid-s1 "$R" x x x)")"
check "PostToolUse, no crew at all: no fork" "" "$(quiet post "$(payload sid-x "$TMP/nowhere" Bash command ls)")"
crew_as s2 "$R" msg decision control --send >/dev/null 2>&1
out="$(quiet post "$(payload sid-s1 "$R" Bash command ls)")"
check "control: with mail the slow path runs, and the probe sees its forks" yes "$( [ -n "$out" ] && echo yes || echo no)"

finish
