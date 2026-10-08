#!/usr/bin/env bash
# PLUG-027: hot-spot holds — hold, guard, release with a sha, chains, warn mode, concurrency.
. "$(dirname "$0")/helpers.sh"
R="$TMP/repo"; new_repo "$R"
join "$R" s1 coordinator; join "$R" s2; join "$R" s3
printf '{"hotSpots":["b.txt","scenes/*.ts"]}' > "$R/.crew.json"

echo "-- hold + guard"
out="$(crew_as s1 "$R" hold a.txt --task PLUG-9)"
check "hold a free path" yes "$(contains "a.txt — yours" "$out")"
out="$(crew_as s1 "$R" hold a.txt)"
check "hold again: already yours" yes "$(contains "already yours" "$out")"
out="$(crew_as s2 "$R" hold a.txt 2>&1)"; rc=$?
check "hold a held path fails" 1 "$rc"
check "…naming holder and chain hint" yes "$(contains "held by s1 since" "$out")"
edit "$R" s2 a.txt "s2 wants it"; rc=$?
check "s2 edit of s1's hold is denied" 1 "$rc"
check "…naming the holder" yes "$(contains "a.txt is held by s1 since" "$HOOK_OUT")"
check "…with the task" yes "$(contains "(PLUG-9)" "$HOOK_OUT")"
check "…and the chain command" yes "$(contains "CREW_AS=s2 bash" "$HOOK_OUT")"
edit "$R" s1 a.txt "s1 edit"; rc=$?
check "holder edits freely" 0 "$rc"

echo "-- hot spots"
edit "$R" s2 b.txt "x"; rc=$?
check "unheld hot spot is denied" 1 "$rc"
check "…telling to hold first" yes "$(contains "b.txt is a hot spot: take the hold first" "$HOOK_OUT")"
edit "$R" s2 scenes/main.ts "x"; rc=$?
check "glob hot spot is denied" 1 "$rc"
crew_as s2 "$R" hold b.txt >/dev/null
edit "$R" s2 b.txt "s2 edit"; rc=$?
check "held hot spot: holder may edit" 0 "$rc"
out="$(hook pre-edit.sh "$(payload sid-x "$R" Edit file_path "$R/b.txt")")"
check "unnamed session denied on a held path" yes "$(denied "$out")"
edit "$R" s3 c.txt "free file"; rc=$?
check "ordinary file is free" 0 "$rc"

echo "-- release"
out="$(crew_as s1 "$R" release a.txt 2>&1)"; rc=$?
check "release without sha fails" 1 "$rc"
out="$(crew_as s1 "$R" release a.txt --unchanged 2>&1)"; rc=$?
check "--unchanged refused while dirty" 1 "$rc"
git -C "$R" add c.txt && git -C "$R" commit -q -m c -- c.txt
other="$(git -C "$R" rev-parse --short HEAD)"
out="$(crew_as s1 "$R" release a.txt --sha "$other" 2>&1)"; rc=$?
check "release with a sha that did not touch it fails" 1 "$rc"
check "…saying so" yes "$(contains "did not touch it" "$out")"
crew_as s3 "$R" chain a.txt >/dev/null
crew_as s1 "$R" chain a.txt s2 >/dev/null
out="$(crew_as s1 "$R" who a.txt)"
check "chain order" yes "$(contains "next: s3,s2" "$out")"
out="$(crew_as s2 "$R" release a.txt --sha HEAD 2>&1)"; rc=$?
check "a non-holder worker cannot release" 1 "$rc"
git -C "$R" commit -q -m a -- a.txt
sha="$(git -C "$R" rev-parse --short HEAD)"
out="$(crew_as s1 "$R" release a.txt --sha "$sha")"
check "release passes the hold down the chain" yes "$(contains "now held by s3 (then s2)" "$out")"
check "new holder is s3" s3 "$(awk -F'\t' '$1=="a.txt"{print $2}' "$R/.git/crew/holds")"
out="$(crew_as s1 "$R" msg release a.txt --to all)"
check "msg release reads the log" yes "$(contains "released at $sha by s1 → now held by s3" "$out")"
out="$(crew_as s3 "$R" release a.txt --unchanged)"
check "--unchanged on a clean path" yes "$(contains "now held by s2" "$out")"
out="$(crew_as s2 "$R" release a.txt --unchanged)"
check "end of chain: free" yes "$(contains "a.txt unchanged → free" "$out")"
out="$(crew_as s2 "$R" drop b.txt 2>&1)"; rc=$?
check "drop is coordinator-only" 1 "$rc"
crew_as s1 "$R" drop b.txt >/dev/null
check "coordinator drops" "" "$(awk -F'\t' '$1=="b.txt"' "$R/.git/crew/holds")"

echo "-- status + handoff"
crew_as s2 "$R" hold b.txt >/dev/null
out="$(crew_as s2 "$R" status)"
check "status lists holds" yes "$(contains "b.txt — s2 since" "$out")"
out="$(crew_as s2 "$R" msg handoff)"
check "handoff names holds to release" yes "$(contains "holds I release once this lands: b.txt" "$out")"
out="$(crew_as s2 "$R" msg hold b.txt)"
check "msg hold" yes "$(contains "s2 → s1: HOLD — b.txt" "$out")"

echo "-- warn mode"
printf '{"hotSpots":["b.txt"],"hookMode":"warn"}' > "$R/.crew.json"
edit "$R" s3 b.txt "warned"; rc=$?
check "warn mode lets the edit through" 0 "$rc"
check "…with a message" yes "$(contains "hookMode=warn" "$HOOK_OUT")"
printf '{"hotSpots":["b.txt"]}' > "$R/.crew.json"

echo "-- concurrency"
for n in s1 s2 s3; do (crew_as "$n" "$R" hold race.txt >/dev/null 2>&1 && echo "$n" >> "$TMP/winners") & done; wait
check "exactly one concurrent hold wins" 1 "$(wc -l < "$TMP/winners" | tr -d ' ')"

finish
