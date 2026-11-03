#!/usr/bin/env bash
# PLUG-091: status shows an untracked directory as one line (count + owner), like git status does.
. "$(dirname "$0")/helpers.sh"
R="$TMP/repo"; new_repo "$R"
join "$R" s1 coordinator; join "$R" s2
mkdir -p "$R/scratch" "$R/other"
i=0; while [ "$i" -lt 1000 ]; do printf 'x\n' > "$R/scratch/f$i.txt"; i=$((i + 1)); done
printf 'y\n' > "$R/other/o.txt"
edit "$R" s2 a.txt "tracked change"

echo "-- an untracked directory is one line"
out="$(crew_as s1 "$R" status)"
check "the directory shows once, with its count" yes "$(contains "scratch/ (1000 files)" "$out")"
check "…no file of it is listed" no "$(contains "scratch/f7.txt" "$out")"
check "…the whole screen stays short" yes "$([ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" -lt 30 ] && echo yes || echo no)"
check "…dirty still counts every file" yes "$(contains "dirty (1002)" "$out")"
check "…unclaimed, said so" yes "$(contains "unclaimed: " "$out")"
check "…a tracked change keeps its own path and owner" yes "$(contains "s2: a.txt" "$out")"
check "…a directory with one file lists that file" yes "$(contains "other/o.txt" "$out")"

echo "-- a held path inside is listed"
crew_as s2 "$R" hold scratch/f7.txt >/dev/null
out="$(crew_as s1 "$R" status)"
check "the held path shows" yes "$(contains "scratch/f7.txt" "$out")"
check "…the rest of the directory is one line, minus it" yes "$(contains "scratch/ (999 files)" "$out")"
crew_as s1 "$R" drop scratch/f7.txt >/dev/null

echo "-- the owner of a collapsed directory"
edit "$R" s2 scratch/f3.txt "mine"
out="$(crew_as s1 "$R" status)"
check "a claimed file gives its owner" yes "$(contains "s2: " "$out")"
out2="$(printf "%s\n" "$out" | grep "^  s2")"; check "…the directory line is in that owner's group" yes "$(contains "scratch/ (1000 files)" "$out2")"

echo "-- --all expands"
out="$(crew_as s1 "$R" status --all)"
check "every file is listed" yes "$(contains "scratch/f999.txt" "$out")"
check "…no collapsed line" no "$(contains "scratch/ (" "$out")"
check "an unknown option is refused" 1 "$(crew_as s1 "$R" status --nope >/dev/null 2>&1; echo $?)"

finish
