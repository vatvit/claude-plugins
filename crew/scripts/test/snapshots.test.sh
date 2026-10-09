#!/usr/bin/env bash
# PLUG-030: a snapshot before every write — log, show, diff, restore, dedupe, prune, skips, speed.
. "$(dirname "$0")/helpers.sh"
R="$TMP/repo"; new_repo "$R"
join "$R" s1 coordinator; join "$R" s2
ids() { crew_as s1 "$R" snapshot log "$1" | sed 's/^  #\([0-9]*\).*/\1/' | paste -sd' ' -; }

echo "-- overwrite and recover"
edit "$R" s1 a.txt "s1 careful work"
edit "$R" s2 a.txt "s2 overwrote it"
out="$(crew_as s1 "$R" snapshot log a.txt)"
check "two snapshots, newest first" "2 1" "$(ids a.txt)"
check "…attributed" yes "$(contains "by s2" "$out")"
check "show #1 is the committed content" one "$(crew_as s1 "$R" snapshot show 1)"
check "show #2 is s1's work" "s1 careful work" "$(crew_as s1 "$R" snapshot show '#2')"
out="$(crew_as s1 "$R" snapshot diff 2)"
check "diff against now" yes "$(contains "+s2 overwrote it" "$out")"
out="$(crew_as s1 "$R" snapshot restore 2)"
check "restore brings s1's version back" "s1 careful work" "$(cat "$R/a.txt")"
check "…and snapshots what it replaced" "3 2 1" "$(ids a.txt)"
check "…which is s2's text" "s2 overwrote it" "$(crew_as s1 "$R" snapshot show 3)"

echo "-- dedupe, new files, skips"
edit "$R" s1 a.txt "s1 careful work"         # same content as the newest snapshot? no: newest is s2's
n="$(ids a.txt | wc -w | tr -d ' ')"
edit "$R" s1 a.txt "again"; edit "$R" s1 a.txt "again"
check "an unchanged file is not snapshotted twice in a row" $((n + 1)) "$(ids a.txt | wc -w | tr -d ' ')"
edit "$R" s1 brand-new.txt "x"
check "a new file has nothing to snapshot" "" "$(ids brand-new.txt)"
printf 'a\000b' > "$R/bin.dat"
hook pre-edit.sh "$(payload sid-s1 "$R" Edit file_path "$R/bin.dat")" >/dev/null
check "binary skipped" "" "$(ids bin.dat)"
check "…with a note on stderr" yes "$(contains "binary" "$(cat "$TMP/hook.err")")"
printf '{"snapshotMaxKB":1}' > "$R/.crew.json"
awk 'BEGIN { for (i = 0; i < 200; i++) print "0123456789" }' > "$R/big.txt"
hook pre-edit.sh "$(payload sid-s1 "$R" Edit file_path "$R/big.txt")" >/dev/null
check "over snapshotMaxKB skipped" "" "$(ids big.txt)"

echo "-- retention"
printf '{"snapshotKeep":3}' > "$R/.crew.json"
for i in 1 2 3 4 5 6; do edit "$R" s1 b.txt "v$i"; done
check "only snapshotKeep per path kept" 3 "$(ids b.txt | wc -w | tr -d ' ')"
check "…the newest" "v5" "$(crew_as s1 "$R" snapshot show "$(ids b.txt | cut -d' ' -f1)")"
printf '{"snapshotKeep":1}' > "$R/.crew.json"
out="$(crew_as s1 "$R" snapshot prune)"
check "prune applies a lower setting" 1 "$(ids b.txt | wc -w | tr -d ' ')"
check "prune drops unreferenced blobs" "$(cut -f5 "$R/.git/crew/snapshots/log" | sort -u | wc -l | tr -d ' ')" "$(ls "$R/.git/crew/snapshots/blobs" | wc -l | tr -d ' ')"
rm -f "$R/.crew.json"

echo "-- holds respected by restore; hook speed"
crew_as s2 "$R" hold a.txt >/dev/null
out="$(crew_as s1 "$R" snapshot restore 1 2>&1)"; rc=$?
check "restore of a file another session holds is refused" 1 "$rc"
pl="$(payload sid-s1 "$R" Edit file_path "$R/b.txt")"
start=$(date +%s)
for i in 1 2 3 4 5 6 7 8 9 10; do printf 'speed %s\n' "$i" > "$R/b.txt"; printf '%s' "$pl" | bash "$H/pre-edit.sh" >/dev/null 2>&1; done
el=$(( $(date +%s) - start ))
echo "  (10 pre-edit hook runs with a snapshot each: ${el}s)"
check "the hook stays fast (10 runs under 15 s, even on a loaded machine)" yes "$( [ "$el" -lt 15 ] && echo yes || echo no)"
out="$(crew_as s1 "$R" snapshot show 999 2>&1)"; rc=$?
check "unknown id refused" 1 "$rc"

finish
