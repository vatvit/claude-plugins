#!/usr/bin/env bash
# PLUG-097: crew time — where each member's wall time went, from generated transcripts and the slot history.
. "$(dirname "$0")/helpers.sh"
R="$TMP/repo"; new_repo "$R"
join "$R" s1 coordinator; join "$R" w1; join "$R" w2      # w2: no transcript anywhere
export CREW_NOW=1791028800 TZ=UTC                       # 2026-10-03 12:00:00 UTC
export CREW_TRANSCRIPTS="$TMP/tx"; P="$TMP/tx/-repo"; mkdir -p "$P"

# Transcript lines shaped like Claude Code's (keys in its order: message before type, timestamp last).
ts() { printf '2026-10-03T%s.000Z' "$1"; }
human()  { printf '{"parentUuid":null,"isSidechain":false,"type":"user","message":{"role":"user","content":"%s"},"uuid":"u","timestamp":"%s","origin":{"kind":"human"}}\n' "$2" "$(ts "$1")"; }
tooluse() { printf '{"parentUuid":"p","isSidechain":false,"message":{"role":"assistant","content":[{"type":"tool_use","id":"%s","name":"%s","input":{"command":"%s","description":"d"}}]},"type":"assistant","uuid":"a","timestamp":"%s"}\n' "$2" "$3" "$4" "$(ts "$1")"; }
said()   { printf '{"parentUuid":"p","isSidechain":%s,"message":{"role":"assistant","content":[{"type":"text","text":"ok"}]},"type":"assistant","uuid":"a","timestamp":"%s"}\n' "${2:-false}" "$(ts "$1")"; }
result() { printf '{"parentUuid":"p","isSidechain":false,"type":"user","message":{"role":"user","content":[{"tool_use_id":"%s","type":"tool_result","content":"%s"}]},"uuid":"u","timestamp":"%s","toolUseResult":{"stdout":"x"}}\n' "$2" "$3" "$(ts "$1")"; }
peer()   { printf '{"parentUuid":"p","isSidechain":false,"type":"user","message":{"role":"user","content":"%s"},"isMeta":true,"uuid":"u","timestamp":"%s","origin":{"kind":"peer","from":"x"}}\n' "$2" "$(ts "$1")"; }
notif()  { printf '{"parentUuid":"p","isSidechain":false,"type":"user","message":{"role":"user","content":"<task-notification><task-id>%s</task-id><status>completed</status></task-notification>"},"uuid":"u","timestamp":"%s","origin":{"kind":"task-notification"}}\n' "$2" "$(ts "$1")"; }
compact() { printf '{"parentUuid":"p","isSidechain":false,"type":"user","message":{"role":"user","content":"summary"},"isCompactSummary":true,"uuid":"u","timestamp":"%s"}\n' "$(ts "$1")"; }
other()  { printf '{"type":"attachment","attachment":{"type":"queued_command","prompt":"x","origin":{"kind":"peer"}},"timestamp":"%s"}\n' "$(ts "$1")"; }

{   human   09:00:00 "TOPSECRET user prompt"
    tooluse 09:01:00 toolu_a Bash "npm test"
    result  09:06:00 toolu_a "out \\\"{{[\\\" TOPSECRET done"                     # 5 min a process; braces after an escaped quote
    tooluse 09:07:00 toolu_b Bash "CREW_AS=w1 crew slot run cpu 5 -- ./t.sh"
    result  09:17:00 toolu_b "ok"                                               # 10 min: 5 queue + 5 run (slot log)
    other   09:18:30                                                            # an attachment: ignored
    tooluse 09:18:00 toolu_c Read ""
    result  09:18:30 toolu_c "file"                                             # 30 s a tool
    said    09:19:00
    peer    09:29:00 "[alpha] s1 → w1: DECISION — go ahead"                     # 10 min a decision
    tooluse 09:30:00 toolu_d Bash "crew land --msg-file m -- a.txt"
    result  09:31:00 toolu_d "landed"                                           # 1 min the shared tree
    tooluse 09:32:00 toolu_e Bash "crew slot run cpu 5 -- ./long.sh"
    result  09:32:05 toolu_e "Command running in background with ID: bg1"
    said    09:33:00
    said    09:48:00 true                                                       # a subagent's entry: ignored
    notif   09:43:00 bg1                                                        # 10 min: 5 queue + 5 run (background slot)
    peer    09:53:00 "[alpha] s1 → w1: HANDOFF — review this"                   # 10 min a peer's work
    said    09:54:00
    human   10:54:00 "next"                                                     # 60 min idle: not counted
    said    10:55:00
    compact 10:58:00                                                            # 3 min compaction
    said    10:59:00
} > "$P/sid-w1.jsonl"
{   human   09:00:00 "start"
    said    09:20:00                                                            # 20 min working
    tooluse 09:21:00 toolu_z SendMessage ""
    result  09:22:00 toolu_z "sent"                                             # 1 min a tool
} > "$P/sid-s1.jsonl"
d0=1790985600                                                                   # 2026-10-03 00:00 UTC
printf '%s\tstart\t7\tw1\tcpu\t5\t2\t%s\trunning\t%s\t\talpha\t0\t\n' $((d0 + 9*3600 + 12*60)) $((d0 + 9*3600 + 7*60)) $((d0 + 9*3600 + 12*60)) >> "$CREW_HOME/slots.log"
printf '%s\tstart\t8\tw1\tcpu\t5\t2\t%s\trunning\t%s\t\talpha\t0\t\n' $((d0 + 9*3600 + 38*60)) $((d0 + 9*3600 + 33*60)) $((d0 + 9*3600 + 38*60)) >> "$CREW_HOME/slots.log"
printf '%s\tdone\t7\tw1\tcpu\t5\t2\t%s\trunning\t%s\t\talpha\t0\t\n' $((d0 + 9*3600 + 17*60)) $((d0 + 9*3600 + 7*60)) $((d0 + 9*3600 + 12*60)) >> "$CREW_HOME/slots.log"

row() { printf '%s\n' "$out" | awk -v l="$1" 'index($0, l) == 1 { sub(/^.{30}/, ""); gsub(/  +/, " "); sub(/^ /, ""); print; exit }'; }

echo "-- one table, a column per member and the crew"
out="$(crew_as s1 "$R" time)"
check "header names the window" yes "$(contains "crew time since 2026-10-03 00:00 (local), gaps over 30 min not counted" "$out")"
check "columns: members, then the crew" "s1 w1 (crew)" "$(printf '%s\n' "$out" | sed -n 2p | awk '{ $1 = $1; print }')"
check "Claude working" "0:21 95% 0:09 16% 0:30 38%" "$(row "Claude working")"
check "a process: foreground, the slot's run, background" "- 0:15 25% 0:15 19%" "$(row "a process running")"
check "the slot queue, split by the slot log" "- 0:10 17% 0:10 12%" "$(row "the slot queue")"
check "a tool" "0:01 5% 0:01 1% 0:02 2%" "$(row "a tool (not Bash)")"
check "the shared tree (a land)" "- 0:01 2% 0:01 1%" "$(row "the shared tree")"
check "a decision from a peer" "- 0:10 17% 0:10 12%" "$(row "a decision from a peer")"
check "a peer's work" "- 0:10 17% 0:10 12%" "$(row "a peer's work")"
check "compaction" "- 0:03 5% 0:03 4%" "$(row "compaction")"
check "idle gaps are cut, not counted" "- 1:00 1:00" "$(row "idle, not counted")"
check "no category for the user here (the prompt after the idle gap was cut)" "" "$(row "the user")"
check "no transcript text is printed" no "$(contains "TOPSECRET" "$out")"

echo "-- window, threshold, a second session id"
out="$(crew_as s1 "$R" time --since 09:30)"
check "--since cuts the window" "- 0:01 3% 0:01 3%" "$(row "the shared tree")"
check "…and nothing before it" "" "$(row "a decision from a peer")"
out="$(crew_as s1 "$R" time --idle 90)"
check "--idle raises the threshold: the hour counts as the user" "- 1:00 50% 1:00 43%" "$(row "the user")"
crew_as w1 "$R" whoami w1 --sid sid-w1b --take >/dev/null 2>&1                             # a /clear: a new session id
{ human 11:00:00 "again"; said 11:30:00; } > "$P/sid-w1b.jsonl"
out="$(crew_as s1 "$R" time)"
check "both of a member's sessions are read" "0:21 95% 0:39 44% 1:00 54%" "$(row "Claude working")"
check "…and the merge is said" yes "$(contains "several session ids" "$out")"
out="$(crew_as s1 "$R" time --since "2026-10-03 11:45")"
check "an empty window says so, no table of zeros" yes:no "$(contains "nothing to count in this window" "$out"):$(contains "Claude working" "$out")"
out="$(crew_as s1 "$R" time --since yesterday 2>&1)"; rc=$?
check "a bad --since is refused" 1:yes "$rc:$(contains "--since takes HH:MM" "$out")"

echo "-- slot history"
: > "$CREW_HOME/slots.log"
crew_as w1 "$R" slot request cpu 5 >/dev/null
crew_as w1 "$R" slot done >/dev/null
check "request, start and done are logged" "request start done" "$(cut -f2 "$CREW_HOME/slots.log" | paste -sd' ' -)"
check "…with the owner" w1 "$(cut -f4 "$CREW_HOME/slots.log" | sort -u)"
CREW_SLOT_LOG_KEEP=1 crew_as w1 "$R" slot request cpu 5 >/dev/null
check "the log is trimmed past twice its keep (then the start)" 2 "$(wc -l < "$CREW_HOME/slots.log" | tr -d ' ')"
crew_as w1 "$R" slot cancel >/dev/null

echo "-- the coordinator's review reminder (PLUG-098)"
rm -f "$R/.git/crew/time-reviewed"; : > "$CREW_HOME/slots.log"
t0="$(sed -n 's/^since=//p' "$R"/.git/crew/sessions/* | sort -n | head -1)"      # the crew's first join
out="$(CREW_NOW=$((t0 + 3600)) crew_as s1 "$R" watch --once)"
check "a young crew is not reminded" no "$(contains "review" "$out")"
out="$(CREW_NOW=$((t0 + 25 * 3600)) crew_as s1 "$R" watch --once)"
check "after a day without a review, watch reminds" yes "$(contains "crew time not reviewed for 25h — next: run crew time" "$out")"
CREW_NOW=$((t0 + 25 * 3600)) crew_as s1 "$R" time >/dev/null
out="$(CREW_NOW=$((t0 + 26 * 3600)) crew_as s1 "$R" watch --once)"
check "running crew time is the review" no "$(contains "review" "$out")"
r=$((t0 + 25 * 3600))
printf '%s\tstart\t9\tw1\tcpu\t5\t2\t%s\trunning\t%s\t\t%s\t0\t\n' $((r + 4000)) $((r + 100)) $((r + 4000)) "$(sed -n 's/^crew=//p' "$CREW_HOME/names/w1")" >> "$CREW_HOME/slots.log"
out="$(CREW_NOW=$((r + 4100)) crew_as s1 "$R" watch --once)"
check "65 min in the slot queue since the review: reminded early" yes "$(contains "this crew waited 65m in the slot queue since the last review" "$out")"
printf '%s\tstart\t9\tz9\tcpu\t5\t2\t%s\trunning\t%s\t\tother\t0\t\n' $((r + 4000)) $((r + 100)) $((r + 4000)) > "$CREW_HOME/slots.log"
out="$(CREW_NOW=$((r + 4100)) crew_as s1 "$R" watch --once)"
check "…another crew's queue waits do not count" no "$(contains "review" "$out")"
crew_as s1 "$R" config set timeReviewHours 0 >/dev/null
out="$(CREW_NOW=$((t0 + 99 * 3600)) crew_as s1 "$R" watch --once)"
check "timeReviewHours 0 turns the reminder off" no "$(contains "review" "$out")"

finish
