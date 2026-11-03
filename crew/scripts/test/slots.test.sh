#!/usr/bin/env bash
# PLUG-028: the slot queue — classes, ordering, ETAs, run, stale slots, quiet check.
. "$(dirname "$0")/helpers.sh"
R="$TMP/repo"; new_repo "$R"
join "$R" s1 coordinator; join "$R" s2; join "$R" s3
export CREW_NOW=1791028800 CREW_SLOT_POLL=0.2 TZ=UTC        # 2026-10-03 12:00:00 UTC
field() { awk -F'\t' -v id="$1" -v f="$2" '$1 == id { print $f }' "$CREW_HOME/slots"; }

echo "-- exclusive vs cpu"
out="$(crew_as s1 "$R" slot request exclusive 10 --why e2e)"
check "first exclusive starts at once" yes "$(contains "#1 started" "$out")"
out="$(crew_as s2 "$R" slot request exclusive 5)"
check "second exclusive waits" running/waiting "$(field 1 7)/$(field 2 7)"
check "…with an ETA after the first" yes "$(contains "ETA 12:10" "$out")"
out="$(crew_as s3 "$R" slot request cpu 3)"
check "cpu waits while exclusive runs" waiting "$(field 3 7)"
out="$(crew_as s2 "$R" slot start 2)"; rc=$?
check "start refused while exclusive runs" 1 "$rc"
check "…naming what is ahead" yes "$(contains "#1 s1 exclusive 10m RUNNING" "$out")"
out="$(crew_as s3 "$R" slot start 2 2>&1)"; rc=$?
check "cannot start someone else's slot" 2 "$rc"
out="$(crew_as s1 "$R" slot done)"
check "done says who can start" yes "$(contains "can start now: #2 s2" "$out")"
check "…and to tell the queue" yes "$(contains "msg queue-moved" "$out")"
out="$(crew_as s3 "$R" slot start 3)"; rc=$?
check "a cpu 3m requested later does not pass the waiting exclusive 5m" 1 "$rc"
crew_as s2 "$R" slot start 2 >/dev/null
check "…which starts" running "$(field 2 7)"
out="$(crew_as s1 "$R" slot request cpu 9)"                                    # #4: behind the running #2
check "cpu waits while exclusive runs, ETA at its end" waiting:yes "$(field 4 7):$(contains "ETA 12:05" "$out")"
crew_as s2 "$R" slot done >/dev/null
crew_as s3 "$R" slot start 3 >/dev/null
check "cpu starts once the exclusive is done" running "$(field 3 7)"
crew_as s1 "$R" slot start 4 >/dev/null
check "cpu alongside cpu" running "$(field 4 7)"
crew_as s3 "$R" slot done >/dev/null; crew_as s1 "$R" slot done >/dev/null

echo "-- priority order"
crew_as s1 "$R" slot request cpu 1 >/dev/null                                  # #5 runs
crew_as s2 "$R" slot request exclusive 2 >/dev/null                            # #6 normal
crew_as s3 "$R" slot request exclusive 9 --prio critical >/dev/null            # #7 critical
crew_as s2 "$R" slot request exclusive 20 --prio failing --why "main red" >/dev/null   # #8 failing
order="$(cd "$R" && CREW_AS=s1 bash -c '. "'"$S"'/slot.sh"; crew_init; slots_sorted' | cut -f1 | paste -sd' ' -)"
check "running, then failing, critical, normal" "5 8 7 6" "$order"
out="$(crew_as s1 "$R" slot list)"
check "list flags failing" yes "$(contains "#8 s2 exclusive 20m waiting · ETA 12:01 · failing — main red" "$out")"
check "ETAs chain behind each other" yes "$(contains "#7 s3 exclusive 9m waiting · ETA 12:21 · critical" "$out")"
out="$(crew_as s1 "$R" msg queue-moved "#5 finished early")"
check "queue-moved goes to all with the reason" yes "$(contains "s1 → all: QUEUE MOVED — #5 finished early" "$out")"
check "…listing each waiting slot" yes "$(contains "#6 s2 exclusive 2m waiting" "$out")"
out="$(crew_as s1 "$R" status)"
check "status shows the queue" yes "$(contains "#5 s1 (you) cpu 1m RUNNING" "$out")"

echo "-- stale + release"
CREW_NOW=$((CREW_NOW + 30 * 60)) out="$(crew_as s1 "$R" slot list)"
check "a slot past estimate + grace is STALE" yes "$(contains "STALE" "$out")"
out="$(crew_as s2 "$R" slot release 5 2>&1)"; rc=$?
check "release is coordinator-only" 1 "$rc"
crew_as s1 "$R" slot release 5 >/dev/null
check "coordinator releases" "" "$(field 5 7)"
for i in 6 7 8; do crew_as s1 "$R" slot release $i >/dev/null; done

echo "-- quiet"
crew_as s3 "$R" slot request quiet 5 >/dev/null
out="$(crew_as s1 "$R" slot clear)"; rc=$?
check "clear fails during a quiet slot" 1 "$rc"
check "…naming the holder" yes "$(contains "s3 has a quiet slot running" "$out")"
crew_as s1 "$R" slot request cpu 1 >/dev/null
check "nothing starts during quiet" waiting "$(field 10 7)"
crew_as s3 "$R" slot done >/dev/null
out="$(crew_as s1 "$R" slot clear)"; rc=$?
check "clear passes after it" 0 "$rc"
crew_as s1 "$R" slot cancel 10 >/dev/null

echo "-- a waiting exclusive is not starved by later cpu slots (PLUG-096)"
crew_as s1 "$R" slot request cpu 5 >/dev/null                                  # #11 runs
crew_as s2 "$R" slot request exclusive 60 >/dev/null                           # #12 waits for #11
crew_as s3 "$R" slot request cpu 5 >/dev/null                                  # #13: shorter, but later
check "a later cpu slot does not start beside a running cpu while an exclusive waits" running/waiting/waiting \
    "$(field 11 7)/$(field 12 7)/$(field 13 7)"
order="$(cd "$R" && CREW_AS=s1 bash -c '. "'"$S"'/slot.sh"; crew_init; slots_sorted' | cut -f1 | paste -sd' ' -)"
check "…it queues behind the exclusive, shortest-first notwithstanding" "11 12 13" "$order"
crew_as s1 "$R" slot done >/dev/null
out="$(crew_as s3 "$R" slot start 13)"; rc=$?
check "…nor once the machine is free: the exclusive goes first" 1 "$rc"
out="$(crew_as s2 "$R" slot start 12)"; rc=$?
check "…and the exclusive starts" 0:running "$rc:$(field 12 7)"
crew_as s2 "$R" slot done >/dev/null
crew_as s3 "$R" slot start 13 >/dev/null
check "…then the cpu slot" running "$(field 13 7)"
crew_as s3 "$R" slot done >/dev/null
crew_as s1 "$R" slot request cpu 5 >/dev/null                                  # #14 runs
crew_as s2 "$R" slot request exclusive 60 >/dev/null                           # #15 waits
crew_as s3 "$R" slot request cpu 5 --prio failing >/dev/null                   # #16 fixes the shared branch
check "a failing-priority cpu slot may still go first" running "$(field 16 7)"
for i in 14 15 16; do crew_as s1 "$R" slot release $i >/dev/null; done

echo "-- run"
out="$(crew_as s2 "$R" slot run cpu 1 -- sh -c 'echo ran; exit 3' 2>/dev/null)"; rc=$?
check "run runs the command" ran "$out"
check "…returns its exit code" 3 "$rc"
check "…and releases the slot" "" "$(awk -F'\t' '$7 != ""' "$CREW_HOME/slots")"
crew_as s1 "$R" slot request exclusive 1 >/dev/null                           # blocks the run below
( crew_as s2 "$R" slot run cpu 1 -- sh -c "echo started > '$TMP/ran'" >/dev/null 2>&1 ) &
sleep 1
check "run waits while blocked" no "$( [ -f "$TMP/ran" ] && echo yes || echo no)"
crew_as s1 "$R" slot done >/dev/null
wait
check "run starts once free" started "$(cat "$TMP/ran" 2>/dev/null)"
out="$(crew_as s2 "$R" slot request turbo 1 2>&1)"; rc=$?
check "unknown class refused" 1 "$rc"

finish
