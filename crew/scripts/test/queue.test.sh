#!/usr/bin/env bash
# The machine queue across crews and accounts: exclusive is first come among exclusives (PLUG-101), one plan for
# every viewer and a stuck slot passed (PLUG-102), ignoring a named crew (PLUG-104), a member's wait and overrun
# mailed to the coordinator (PLUG-107).
. "$(dirname "$0")/helpers.sh"
A="$TMP/alpha"; B="$TMP/beta"; new_repo "$A"; new_repo "$B"
join "$A" a1 coordinator; join "$A" a2; join "$A" a3
join "$B" b1 coordinator; join "$B" b2
T="$((1791028800))"; export CREW_NOW="$T" CREW_SLOT_POLL=0.2 TZ=UTC        # 12:00 UTC
field() { awk -F'\t' -v id="$1" -v f="$2" '$1 == id { print $f }' "$CREW_HOME/slots"; }
order() { (cd "$1" && CREW_AS="$2" bash -c '. "'"$S"'/slot.sh"; crew_init; slots_sorted' | cut -f1 | paste -sd' ' -); }
clear_all() { local i o; for i in $(cut -f1 "$CREW_HOME/slots" 2>/dev/null); do
    o="$(field "$i" 2)"; case "$o" in a*) crew_as a1 "$A" slot release "$i" ;; *) crew_as b1 "$B" slot release "$i" ;; esac >/dev/null 2>&1; done; }
idof() { sed -n 's/.*#\([0-9][0-9]*\) .*/\1/p' | head -1; }

echo "-- PLUG-101: a later, shorter exclusive does not pass a waiting exclusive"
crew_as a1 "$A" slot request cpu 10 >/dev/null                                 # #1 runs
crew_as a2 "$A" slot request exclusive 50 >/dev/null                           # #2 waits
crew_as a3 "$A" slot request exclusive 40 >/dev/null                           # #3 later, shorter
check "queue order: the earlier exclusive first" "1 2 3" "$(order "$A" a1)"
crew_as a1 "$A" slot done 1 >/dev/null
out="$(crew_as a3 "$A" slot start 3)"; rc=$?
check "…the later one cannot start" 1 "$rc"
crew_as a2 "$A" slot start 2 >/dev/null
check "…the earlier one starts" running "$(field 2 7)"
crew_as a1 "$A" slot request exclusive 5 --prio critical >/dev/null           # #4
check "a higher priority still goes first" "2 4 3" "$(order "$A" a1)"
clear_all

echo "-- PLUG-102: every viewer computes one plan, whatever its own config"
UA="$TMP/user-a.json"; UB="$TMP/user-b.json"
printf '{"slotMemGB":14}' > "$UA"; printf '{}' > "$UB"
CREW_USER_CONFIG="$UA" crew_as a1 "$A" slot request cpu 60 --mem 10 >/dev/null  # #5 runs, 10 of 14 GB
CREW_USER_CONFIG="$UB" crew_as b2 "$B" slot request cpu 30 --mem 10 >/dev/null  # #6: does not fit
CREW_USER_CONFIG="$UA" crew_as a2 "$A" slot request cpu 5 --mem 10 >/dev/null   # #7: later, shorter
check "beta (no budget of its own) still holds a 10 GB slot back" waiting "$(field 6 7)"
oa="$(CREW_USER_CONFIG="$UA" order "$A" a1)"; ob="$(CREW_USER_CONFIG="$UB" order "$B" b1)"
check "alpha's and beta's queue order are the same" "$oa" "$ob"
out="$(CREW_USER_CONFIG="$UB" crew_as b2 "$B" slot start 6)"; rc=$?
check "…and beta's waiter does not start over the budget" 1 "$rc"
out="$(CREW_USER_CONFIG="$UB" crew_as b1 "$B" slot list)"
check "beta's list shows the machine's budget" yes "$(contains "memory: 10 of 14 GB in use" "$out")"
clear_all

echo "-- PLUG-102: a slot that can start but does not is passed"
crew_as a1 "$A" slot request exclusive 5 >/dev/null                           # #8 runs
id9="$(crew_as b2 "$B" slot request exclusive 10 | idof)"                     # #9 waits (nobody starts it)
id10="$(crew_as a2 "$A" slot request cpu 3 | idof)"                           # #10 behind #9
crew_as a1 "$A" slot done 8 >/dev/null                                        # the last event: T
out="$(CREW_NOW=$((T + 60)) crew_as a2 "$A" slot start "$id10")"; rc=$?
check "a minute later, the cpu slot still waits behind it" 1 "$rc"
printf '%s\t%s\t#%s\n' "$id9" "$((T + 30))" "$id10" > "$CREW_HOME/slots.wait"  # its waiter: 'not yet', after the last event
out="$(CREW_NOW=$((T + 60)) crew_as a1 "$A" slot list)"
check "list: it can start, yet its waiter sees otherwise" yes "$(contains "#$id9 b2 [beta] exclusive 10m waiting · can start now · STUCK (its waiter sees: behind #$id10)" "$out")"
out="$(CREW_NOW=$((T + 60)) crew_as a1 "$A" watch --once)"
check "watch reports the stuck slot" yes "$(contains "slot #$id9 of b2 [beta]" "$out")"
out="$(CREW_NOW=$((T + 60)) crew_as a2 "$A" slot start "$id10")"; rc=$?
check "…and the slot behind it starts" 0 "$rc"
CREW_NOW=$((T + 120)) crew_as a2 "$A" slot done "$id10" >/dev/null            # last event: T+120
rm -f "$CREW_HOME/slots.wait"
id11="$(CREW_NOW=$((T + 120)) crew_as a2 "$A" slot request cpu 3 | idof)"
out="$(CREW_NOW=$((T + 300)) crew_as a2 "$A" slot start "$id11")"; rc=$?
check "with no waiter note: still waits after 3 min" 1 "$rc"
out="$(CREW_NOW=$((T + 120 + 11 * 60)) crew_as a1 "$A" slot list)"
check "after slotStuckMin with no slot event, it is STUCK" yes "$(contains "STUCK (no start for 11m)" "$out")"
out="$(CREW_NOW=$((T + 120 + 11 * 60)) crew_as a2 "$A" slot start "$id11")"; rc=$?
check "…and passed" 0 "$rc"
CREW_NOW=$((T + 120 + 12 * 60)) crew_as a2 "$A" slot done "$id11" >/dev/null
out="$(CREW_NOW=$((T + 120 + 12 * 60)) crew_as b2 "$B" slot start "$id9")"; rc=$?
check "its owner can still start it" 0 "$rc"
clear_all

echo "-- PLUG-102: a waiter leaves its reason in slots.wait"
crew_as a1 "$A" slot request exclusive 5 >/dev/null
( crew_as b2 "$B" slot run cpu 1 -- true >/dev/null 2>&1 ) &
sleep 1
check "the waiter's note names what is ahead" yes "$(contains "#" "$(cat "$CREW_HOME/slots.wait" 2>/dev/null)")"
crew_as a1 "$A" slot done >/dev/null
wait
check "…and is gone once the slot ran" "" "$(cat "$CREW_HOME/slots.wait" 2>/dev/null)"
clear_all

echo "-- PLUG-104: slotIgnoreCrews"
printf '{"slotIgnoreCrews":["beta"]}' > "$A/.crew.json"
id="$(crew_as b1 "$B" slot request exclusive 30 | idof)"                       # beta's heavy run
out="$(crew_as a2 "$A" slot request cpu 5)"
check "alpha's slot starts beside an ignored crew's running exclusive" yes "$(contains "started" "$out")"
out="$(crew_as a1 "$A" slot list)"
check "…which alpha still lists, marked" yes "$(contains "#$id b1 [beta] exclusive 30m RUNNING since 12:00, ends ~12:30 · ignored" "$out")"
crew_as b1 "$B" slot done "$id" >/dev/null
out="$(crew_as b2 "$B" slot request exclusive 5)"
check "beta still waits for alpha's running slot" yes "$(contains "waiting" "$out")"
crew_as a2 "$A" slot done >/dev/null                                          # beta's exclusive could start now
out="$(crew_as a3 "$A" slot request exclusive 5)"
check "…and alpha passes beta's waiting exclusive" yes "$(contains "started" "$out")"
check "the key is in config" yes "$(contains "slotIgnoreCrews=beta (project)" "$(crew_as a1 "$A" config)")"
printf '{"slotIgnoreCrews":["alpha"]}' > "$A/.crew.json"
out="$(crew_as a1 "$A" slot list)"
check "a crew never ignores itself" no "$(contains "· ignored" "$(printf '%s\n' "$out" | grep ' a[0-9] ')")"
rm -f "$A/.crew.json"; clear_all

echo "-- PLUG-107: the coordinator hears of a member's long wait and overrun"
crew_as a1 "$A" slot request exclusive 30 >/dev/null                          # the coordinator's run, at T
id="$(crew_as a2 "$A" slot request cpu 5 | idof)"
CREW_NOW=$((T + 25 * 60)) crew_as a1 "$A" slot done >/dev/null
CREW_NOW=$((T + 25 * 60)) crew_as a2 "$A" slot start "$id" >/dev/null
out="$(crew_as a1 "$A" inbox)"
check "a start after a long wait is mailed to the coordinator" yes "$(contains "#$id started after 25m waiting" "$out")"
CREW_NOW=$((T + 25 * 60)) crew_as a2 "$A" slot done >/dev/null
crew_as a2 "$A" slot request exclusive 30 >/dev/null
id="$(crew_as a1 "$A" slot request cpu 5 | idof)"
CREW_NOW=$((T + 25 * 60)) crew_as a2 "$A" slot done >/dev/null
CREW_NOW=$((T + 25 * 60)) crew_as a1 "$A" slot start "$id" >/dev/null
check "the coordinator's own wait mails nobody" "inbox: no unread mail for a1" "$(crew_as a1 "$A" inbox)"
crew_as a1 "$A" slot done >/dev/null
CREW_SLOT_OVERRUN_SEC=1 crew_as a2 "$A" slot run cpu 1 -- sleep 3 >/dev/null 2>&1
out="$(crew_as a1 "$A" inbox)"
check "a run past its estimate is mailed once" 1 "$(printf '%s\n' "$out" | grep -c "past its 1m estimate")"
CREW_SLOT_OVERRUN_SEC=5 crew_as a2 "$A" slot run cpu 1 -- true >/dev/null 2>&1
sleep 6
check "a run within its estimate mails nothing" "inbox: no unread mail for a1" "$(crew_as a1 "$A" inbox)"
crew_as b2 "$B" slot run cpu 1 -- true >/dev/null 2>&1
check "a quick start mails nothing" "inbox: no unread mail for b1" "$(crew_as b1 "$B" inbox)"

finish
