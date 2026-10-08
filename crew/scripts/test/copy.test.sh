#!/usr/bin/env bash
# PLUG-029: work in a copy, land with merge-or-refuse apply; rebase; landCheck; holds respected.
. "$(dirname "$0")/helpers.sh"
R="$TMP/repo"; new_repo "$R"
printf 'l1\nl2\nl3\nl4\nl5\nl6\nl7\n' > "$R/m.txt"; printf 'gone\n' > "$R/del.txt"
git -C "$R" add -A && git -C "$R" commit -q -m files
join "$R" s1 coordinator; join "$R" s2
tree_sum() { (cd "$R" && find . -path ./.git -prune -o -type f -print | LC_ALL=C sort | while IFS= read -r f; do cksum "$f"; done); }
K="$TMP/copy"

echo "-- new + take"
out="$(crew_as s2 "$R" copy new "$K")"
check "copy made at HEAD" yes "$(contains "at $(git -C "$R" rev-parse --short HEAD)" "$out")"
check "the copy is not a worktree" "" "$(git -C "$R" worktree list --porcelain | grep -c "$K" | sed 's/^0$//')"
printf 'copy a\n' > "$K/a.txt"; printf 'new\n' > "$K/new file.txt"; rm "$K/del.txt"
out="$(crew_as s2 "$R" copy status "$K")"
check "status lists changes" yes "$(contains "3 changed" "$out")"
out="$(crew_as s2 "$R" apply "$K")"; rc=$?
check "apply succeeds" 0 "$rc"
check "…summary" yes "$(contains "apply: 3 taken, 0 merged" "$out")"
check "taken content" "copy a" "$(cat "$R/a.txt")"
check "added file with a space" new "$(cat "$R/new file.txt")"
check "deleted file" no "$( [ -e "$R/del.txt" ] && echo yes || echo no)"
check "landed paths are claimed by s2" yes "$(contains "s2 (you): a.txt, del.txt, new file.txt" "$(crew_as s2 "$R" status)")"
out="$(crew_as s2 "$R" apply "$K")"
check "re-apply: already there" yes "$(contains "0 taken, 0 merged, 3 already there" "$out")"
git -C "$R" add -A && git -C "$R" commit -q -m landed

echo "-- merge"
rm -rf "$K"; crew_as s2 "$R" copy new "$K" >/dev/null
awk 'NR==1{$0="copy-l1"}1' "$R/m.txt" > "$K/m.txt"
awk 'NR==7{$0="peer-l7"}1' "$R/m.txt" > "$TMP/x" && mv "$TMP/x" "$R/m.txt"        # a peer, uncommitted
out="$(crew_as s2 "$R" apply "$K")"; rc=$?
check "peer edit in another hunk: merged" yes "$(contains "0 taken, 1 merged" "$out")"
check "…both edits present" "copy-l1 peer-l7" "$(sed -n '1p;7p' "$R/m.txt" | paste -sd' ' -)"
git -C "$R" add -A && git -C "$R" commit -q -m merged

echo "-- conflict refuses everything"
rm -rf "$K"; crew_as s2 "$R" copy new "$K" >/dev/null
awk 'NR==3{$0="copy-l3"}1' "$R/m.txt" > "$K/m.txt"; printf 'copy b\n' > "$K/b.txt"
awk 'NR==3{$0="peer-l3"}1' "$R/m.txt" > "$TMP/x" && mv "$TMP/x" "$R/m.txt"
before="$(tree_sum)"
out="$(crew_as s2 "$R" apply "$K")"; rc=$?
check "conflict: apply fails" 1 "$rc"
check "…naming the file" yes "$(contains "refused  m.txt" "$out")"
check "…the tree is byte-identical (b.txt not landed either)" "$before" "$(tree_sum)"
git -C "$R" checkout -q -- m.txt

echo "-- rebase a stale copy"
rm -rf "$K"; crew_as s2 "$R" copy new "$K" >/dev/null
awk 'NR==2{$0="copy-l2"}1' "$R/m.txt" > "$K/m.txt"
awk 'NR==6{$0="head-l6"}1' "$R/m.txt" > "$TMP/x" && mv "$TMP/x" "$R/m.txt"; printf 'z\n' > "$R/z.txt"
git -C "$R" add -A && git -C "$R" commit -q -m advance
out="$(crew_as s2 "$R" copy status "$K")"
check "status flags a stale copy" yes "$(contains "stale" "$out")"
out="$(crew_as s2 "$R" copy rebase "$K")"
check "rebase carries the change" yes "$(contains "rebased" "$out")"
check "…copy has HEAD's new file" z "$(cat "$K/z.txt")"
check "…and both edits" "copy-l2 head-l6" "$(sed -n '2p;6p' "$K/m.txt" | paste -sd' ' -)"
out="$(crew_as s2 "$R" apply "$K")"
check "rebased copy applies with a plain take" yes "$(contains "1 taken, 0 merged" "$out")"
git -C "$R" checkout -q -- m.txt
awk 'NR==2{$0="clash"}1' "$R/m.txt" > "$TMP/x" && mv "$TMP/x" "$R/m.txt"; git -C "$R" commit -q -am clash
cp "$K/m.txt" "$TMP/kept"
out="$(crew_as s2 "$R" copy rebase "$K" 2>&1)"; rc=$?
check "rebase conflict is refused" 1 "$rc"
check "…the copy is unchanged" yes "$(cmp -s "$TMP/kept" "$K/m.txt" && echo yes || echo no)"

echo "-- landCheck"
rm -rf "$K"; crew_as s2 "$R" copy new "$K" >/dev/null
printf 'checked\n' > "$K/a.txt"
printf '#!/bin/sh\nprintf "%%s|" "$@" > "%s/args"\nexit "${FAIL:-0}"\n' "$TMP" > "$R/check.sh"
git -C "$R" add check.sh && git -C "$R" commit -q -m check
printf '{"landCheck":"sh check.sh"}' > "$R/.crew.json"
out="$(crew_as s2 "$R" apply "$K")"
check "landCheck runs on the landed files" "a.txt|" "$(cat "$TMP/args")"
git -C "$R" checkout -q -- a.txt
before="$(tree_sum)"
out="$(FAIL=1 crew_as s2 "$R" apply "$K")"; rc=$?
check "failing landCheck refuses" 1 "$rc"
check "…tree restored byte-identical" "$before" "$(tree_sum)"
rm -f "$R/.crew.json"

echo "-- holds respected, wrong repo refused"
crew_as s1 "$R" hold a.txt >/dev/null
out="$(crew_as s2 "$R" apply "$K")"; rc=$?
check "a file held by someone else is refused" 1 "$rc"
check "…naming the holder" yes "$(contains "held by s1" "$out")"
O="$TMP/other"; new_repo "$O"
out="$(crew_as s2 "$R" copy status "$O" 2>&1)"; rc=$?
check "a non-copy is refused" 1 "$rc"
out="$(crew_as s2 "$R" copy new "$K" 2>&1)"; rc=$?
check "copy into a non-empty dir refused" 1 "$rc"

finish
