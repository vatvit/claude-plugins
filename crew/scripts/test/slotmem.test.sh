#!/usr/bin/env bash
# PLUG-090: memory-aware slots (--mem against the slotMemGB budget) and named slot groups (--group).
. "$(dirname "$0")/helpers.sh"
R="$TMP/repo"; new_repo "$R"
join "$R" s1 coordinator; join "$R" s2; join "$R" s3; join "$R" s4
export CREW_NOW=1791028800 CREW_SLOT_POLL=0.2 TZ=UTC        # 2026-10-03 12:00:00 UTC
field() { awk -F'\t' -v id="$1" -v f="$2" '$1 == id { print $f }' "$CREW_HOME/slots"; }
states() { local i o=""; for i in "$@"; do o="$o${o:+/}$(field "$i" 7)"; done; echo "$o"; }
clear_all() { local i; for i in $(cut -f1 "$CREW_HOME/slots" 2>/dev/null); do crew_as s1 "$R" slot release "$i" >/dev/null; done; }

echo "-- groups: at most one running slot per group"
crew_as s1 "$R" slot request cpu 30 --group heavy-build >/dev/null           # #1 runs
out="$(crew_as s2 "$R" slot request cpu 30 --group heavy-build)"             # #2 same group
crew_as s3 "$R" slot request cpu 5 >/dev/null                                # #3 no group
check "same group waits, no group runs beside" running/waiting/running "$(states 1 2 3)"
check "…the wait has an ETA at the group's end" yes "$(contains "ETA 12:30" "$out")"
out="$(crew_as s1 "$R" slot list)"
check "list shows the group" yes "$(contains "#1 s1 (you) cpu 30m RUNNING since 12:00, ends ~12:30 · group heavy-build" "$out")"
crew_as s1 "$R" slot done 1 >/dev/null
crew_as s2 "$R" slot start 2 >/dev/null
check "the next of the group starts once it is free" running "$(field 2 7)"
clear_all

echo "-- no budget: --mem is shown but admits everything (today's behaviour)"
crew_as s1 "$R" slot request cpu 10 --mem 10 >/dev/null                      # #4
crew_as s2 "$R" slot request cpu 10 --mem 10 >/dev/null                      # #5
check "without slotMemGB both run" running/running "$(states 4 5)"
out="$(crew_as s1 "$R" slot list)"
check "list shows each slot's memory" yes "$(contains "#4 s1 (you) cpu 10m RUNNING since 12:00, ends ~12:10 · 10G" "$out")"
clear_all

echo "-- budget 14 GB"
crew_as s1 "$R" config set --user slotMemGB 14 >/dev/null
crew_as s1 "$R" slot request cpu 30 --mem 10 >/dev/null                      # #6
crew_as s2 "$R" slot request cpu 30 --mem 2 >/dev/null                       # #7
crew_as s3 "$R" slot request cpu 30 --mem 2 >/dev/null                       # #8
check "a 10 GB and two 2 GB slots run together" running/running/running "$(states 6 7 8)"
out="$(crew_as s4 "$R" slot request cpu 30 --mem 10)"                        # #9
check "a second 10 GB slot waits" waiting "$(field 9 7)"
check "…with an ETA once memory frees" yes "$(contains "ETA 12:30" "$out")"
out="$(crew_as s1 "$R" slot list)"
check "list shows the budget in use" yes "$(contains "memory: 14 of 14 GB in use" "$out")"
crew_as s1 "$R" slot request cpu 5 >/dev/null                                # #10: no memory
check "a slot that declares no memory still runs beside" running "$(field 10 7)"
crew_as s1 "$R" slot done 10 >/dev/null
crew_as s2 "$R" slot done 7 >/dev/null                                       # 12 GB in use
crew_as s2 "$R" slot request cpu 5 --mem 2 >/dev/null                        # #11: would fit
check "a slot that fits does not pass a waiting one that does not" waiting "$(field 11 7)"
crew_as s1 "$R" slot done 6 >/dev/null                                       # 2 GB in use
crew_as s4 "$R" slot start 9 >/dev/null
check "the 10 GB slot starts once memory frees" running "$(field 9 7)"
clear_all
crew_as s1 "$R" slot request cpu 5 --mem 20 >/dev/null                       # #12: larger than the budget
check "a slot larger than the budget still runs alone" running "$(field 12 7)"
clear_all

echo "-- input"
out="$(crew_as s1 "$R" slot request cpu 5 --mem lots 2>&1)"; rc=$?
check "--mem must be a whole number" 1:yes "$rc:$(contains "whole number of GB" "$out")"
out="$(crew_as s1 "$R" slot request cpu 5 --group 'a b' 2>&1)"; rc=$?
check "a group is one word" 1:yes "$rc:$(contains "group" "$out")"

echo "-- slot run tells its command which slot it is in"
out="$(crew_as s2 "$R" slot run cpu 1 --mem 3 --group gpu -- sh -c 'echo "$CREW_SLOT_ID $CREW_SLOT_CLASS $CREW_SLOT_MEM $CREW_SLOT_GROUP"' 2>/dev/null)"
check "id, class, mem and group in the environment" "13 cpu 3 gpu" "$out"

finish
