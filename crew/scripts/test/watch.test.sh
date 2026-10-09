#!/usr/bin/env bash
# PLUG-045: silence watchdog — activity stamps, watch --once findings on a fake clock, the loop's
# de-duplication, status' last activity, and degrading without the mailbox.
. "$(dirname "$0")/helpers.sh"
R="$TMP/repo"; new_repo "$R"
join "$R" s1 coordinator; join "$R" s2; join "$R" s3
ST="$R/.git/crew"
T0="$(date +%s)"
at() { echo $((T0 + $1 * 60)); }                       # at <minutes from T0> -> epoch
W() { CREW_NOW="$(at "$1")" crew_as s1 "$R" watch --once 2>&1; }   # W <minutes> -> findings
has() { contains "$1" "$2"; }

echo "-- activity stamps"
check "joining stamps the session" yes "$( [ -f "$ST/seen/sid-s2" ] && echo yes || echo no)"
rm -f "$ST/seen/sid-s2"
mailhook post "$(payload sid-s2 "$R" Bash command ls)" >/dev/null
check "a tool call stamps the session" yes "$( [ -f "$ST/seen/sid-s2" ] && echo yes || echo no)"
rm -f "$ST/seen/sid-s2"
out="$(printf '%s' "$(payload sid-s2 "$R" Bash command ls)" | env PATH="" "$BASH" "$H/mail.sh" post 2>&1)"
check "…without a fork" "" "$out"
check "…and still stamped" yes "$( [ -f "$ST/seen/sid-s2" ] && echo yes || echo no)"
hook session-start.sh "$(payload sid-s3 "$R" x x x)" >/dev/null
check "SessionStart stamps too" yes "$( [ -f "$ST/seen/sid-s3" ] && echo yes || echo no)"

echo "-- silent while holding"
crew_as s2 "$R" hold a.txt >/dev/null
out="$(W 14)"
check "not reported before silenceMin" no "$(has "s2 silent" "$out")"
check "…quiet says so" yes "$(has "watch: quiet" "$out")"
out="$(W 17)"
check "reported after silenceMin" yes "$(has "s2 silent" "$out")"
check "…naming the hold" yes "$(has "hold a.txt" "$out")"
check "…and the next step" yes "$(has "next:" "$out")"
check "an idle session with nothing held is not reported" no "$(has "s3 silent" "$out")"
check "silenceMin is a config key, default 15" yes "$(has "silenceMin=15 (default)" "$(crew_as s1 "$R" config)")"
printf '{"silenceMin":5}' > "$R/.crew.json"
check "silenceMin is configurable" yes "$(has "s2 silent" "$(W 6)")"
rm -f "$R/.crew.json"
mailhook post "$(payload sid-s2 "$R" Bash command ls)" >/dev/null
check "a session that just worked is not silent" no "$(has "s2 silent" "$(W 5)")"
crew_as s2 "$R" release a.txt --unchanged >/dev/null

echo "-- silent with a slot, or with dirty paths"
id="$(crew_as s3 "$R" slot request cpu 3 | sed -n 's/.*#\([0-9]*\).*/\1/p' | head -1)"
out="$(W 17)"
check "a waiting slot counts" yes "$(has "s3 silent" "$out")"
check "…named" yes "$(has "slot #$id" "$out")"
crew_as s3 "$R" slot cancel "$id" >/dev/null
edit "$R" s3 c.txt "s3 work"
out="$(W 17)"
check "claimed dirty paths count" yes "$(has "s3 silent" "$out")"
check "…named" yes "$(has "c.txt" "$out")"
rm -f "$R/c.txt"

echo "-- unread mail"
CREW_NOW="$(at 0)" crew_as s2 "$R" msg decision please answer --send >/dev/null 2>&1
check "mail unread for less than silenceMin: not yet" no "$(has "unread" "$(W 10)")"
out="$(W 17)"
check "mail unread past silenceMin is reported" yes "$(has "s1 has 1 unread" "$out")"
check "…with the command to read it" yes "$(has "inbox" "$out")"
crew_as s1 "$R" inbox >/dev/null

echo "-- stale slot"
id="$(CREW_NOW="$(at 0)" crew_as s3 "$R" slot request cpu 1 | sed -n 's/.*#\([0-9]*\).*/\1/p' | head -1)"
CREW_NOW="$(at 0)" crew_as s3 "$R" slot start "$id" >/dev/null
mailhook post "$(payload sid-s3 "$R" Bash command ls)" >/dev/null
out="$(CREW_NOW="$(at 13)" crew_as s1 "$R" watch --once 2>&1)"
check "a slot past estimate + grace is stale" yes "$(has "slot #$id" "$out")"
check "…with the release command" yes "$(has "slot release $id" "$out")"
crew_as s3 "$R" slot done "$id" >/dev/null

echo "-- status: last activity"
out="$(crew_as s1 "$R" status)"; rc=$?
check "status exits 0 with no slots (a part ending in a false test used to end it)" 0 "$rc"
check "status shows each session's last activity" yes "$(has "activity:" "$out")"
check "…in minutes" yes "$(has "s2 0m ago" "$out")"

echo "-- the loop reports a finding once per silenceMin, not every round"
crew_as s2 "$R" hold a.txt >/dev/null
out="$(CREW_NOW="$(at 17)" CREW_WATCH_ROUNDS=3 crew_as s1 "$R" watch --every 0 2>&1)"
check "three rounds, one line" 1 "$(printf '%s\n' "$out" | grep -c "s2 silent")"
check "the loop prints nothing when quiet" no "$(has "watch: quiet" "$out")"
crew_as s2 "$R" release a.txt --unchanged >/dev/null

echo "-- without the mailbox"
mkdir -p "$TMP/solo"; cp -R "$S/.." "$TMP/solo/crew"; rm -f "$TMP/solo/crew/scripts/inbox.sh"
out="$(cd "$R" && CREW_NOW="$(at 17)" CREW_AS=s1 bash "$TMP/solo/crew/scripts/crew.sh" watch --once 2>&1)"; rc=$?
check "watch still runs" 0 "$rc"
check "…and says quiet" yes "$(has "watch: quiet" "$out")"

finish
