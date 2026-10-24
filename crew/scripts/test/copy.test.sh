#!/usr/bin/env bash
# PLUG-029: work in a copy, land with merge-or-refuse apply; rebase; landCheck; holds respected.
. "$(dirname "$0")/helpers.sh"
R="$TMP/repo"; new_repo "$R"
printf 'l1\nl2\nl3\nl4\nl5\nl6\nl7\n' > "$R/m.txt"; printf 'gone\n' > "$R/del.txt"
git -C "$R" add -A && git -C "$R" commit -q -m files
join "$R" s1 coordinator; join "$R" s2
tree_sum() { (cd "$R" && find . \( -path ./.git -o -path ./.worktrees \) -prune -o -type f -print | LC_ALL=C sort | while IFS= read -r f; do cksum "$f"; done); }
# newk <name> — a fresh copy, named; K is its folder (a detached worktree in .worktrees/)
newk() { N="$1"; K="$R/.worktrees/repo-$1"; crew_as s2 "$R" copy new "$1" >/dev/null; }

echo "-- new + take"
N=k1; K="$R/.worktrees/repo-k1"
out="$(crew_as s2 "$R" copy new k1)"
check "copy made at HEAD" yes "$(contains "at $(git -C "$R" rev-parse --short HEAD)" "$out")"
check "the copy is a worktree in .worktrees/" 1 "$(git -C "$R" worktree list --porcelain | grep -c "^worktree $K$")"
check "…detached: no branch" no "$(git -C "$K" symbolic-ref -q HEAD >/dev/null && echo yes || echo no)"
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
newk k2
awk 'NR==1{$0="copy-l1"}1' "$R/m.txt" > "$K/m.txt"
awk 'NR==7{$0="peer-l7"}1' "$R/m.txt" > "$TMP/x" && mv "$TMP/x" "$R/m.txt"        # a peer, uncommitted
out="$(crew_as s2 "$R" apply "$K")"; rc=$?
check "peer edit in another hunk: merged" yes "$(contains "0 taken, 1 merged" "$out")"
check "…both edits present" "copy-l1 peer-l7" "$(sed -n '1p;7p' "$R/m.txt" | paste -sd' ' -)"
git -C "$R" add -A && git -C "$R" commit -q -m merged

echo "-- conflict refuses everything"
newk k3
awk 'NR==3{$0="copy-l3"}1' "$R/m.txt" > "$K/m.txt"; printf 'copy b\n' > "$K/b.txt"
awk 'NR==3{$0="peer-l3"}1' "$R/m.txt" > "$TMP/x" && mv "$TMP/x" "$R/m.txt"
before="$(tree_sum)"
out="$(crew_as s2 "$R" apply "$K")"; rc=$?
check "conflict: apply fails" 1 "$rc"
check "…naming the file" yes "$(contains "refused  m.txt" "$out")"
check "…the tree is byte-identical (b.txt not landed either)" "$before" "$(tree_sum)"
git -C "$R" checkout -q -- m.txt

echo "-- rebase a stale copy"
newk k4
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

echo "-- rebase --ours: a conflict resolved in the copy (PLUG-048)"
check "the refusal names the flag and the path" yes "$(contains "copy rebase $K --ours m.txt" "$out")"
printf 'copy-b\n' > "$K/b.txt"; printf 'peer-b\n' > "$R/b.txt"; git -C "$R" commit -q -am peer-b
awk 'NR==2{$0="clash+copy-l2"}1' "$R/m.txt" > "$K/m.txt"                  # resolved by hand in the copy
cp "$K/m.txt" "$TMP/resolved"
out="$(crew_as s2 "$R" copy rebase "$K" 2>&1)"; rc=$?
check "a resolved copy without --ours: still refused" 1 "$rc"
out="$(crew_as s2 "$R" copy rebase "$K" --ours m.txt 2>&1)"; rc=$?
check "--ours covers only the paths it names (b.txt still clashes)" 1 "$rc"
check "…naming b.txt" yes "$(contains "rebase conflict in b.txt" "$out")"
check "…the copy is unchanged" yes "$(cmp -s "$TMP/resolved" "$K/m.txt" && echo yes || echo no)"
out="$(crew_as s2 "$R" copy rebase "$K" m.txt 2>&1)"; rc=$?
check "a path without --ours is a usage error" 1 "$rc"
out="$(crew_as s2 "$R" copy rebase "$K" --ours m.txt b.txt a.txt 2>&1)"; rc=$?
check "--ours on every conflicting path: rebased" 0 "$rc"
check "…keeps the copy's resolution" yes "$(cmp -s "$TMP/resolved" "$K/m.txt" && echo yes || echo no)"
check "…and the copy's b.txt" copy-b "$(cat "$K/b.txt")"
check "…says what it took" yes "$(contains "--ours: m.txt" "$out")"
check "…and names an --ours path that had no conflict" yes "$(contains "--ours: a.txt — no conflict there" "$out")"
check "…the copy is on HEAD now" no "$(contains "stale" "$(crew_as s2 "$R" copy status "$K")")"

echo "-- rebase an unchanged copy (PLUG-048)"
newk k5
printf 'more\n' > "$R/more.txt"; git -C "$R" add more.txt && git -C "$R" commit -q -m more
out="$(crew_as s2 "$R" copy rebase "$K" 2>"$TMP/err")"; rc=$?
check "unchanged copy: rebased" 0 "$rc"
check "…no errors" "" "$(cat "$TMP/err")"
check "…0 files carried over" yes "$(contains "(0 changed files carried over)" "$out")"
check "…and the copy moved" more "$(cat "$K/more.txt")"

echo "-- landCheck"
newk k6
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
out="$(crew_as s2 "$R" copy new "$N" 2>&1)"; rc=$?
check "a copy name already in use is refused" 1 "$rc"
crew_as s1 "$R" release a.txt >/dev/null 2>&1

echo "-- worktree copies: .gitignore, names, remove, hooks (PLUG-065)"
G="$TMP/g"; new_repo "$G"; join "$G" g1 coordinator; join "$G" g2
crew_as g2 "$G" copy new one >/dev/null
check "the first copy ignores /.worktrees/ in .gitignore" "/.worktrees/" "$(cat "$G/.gitignore" 2>/dev/null)"
check "…and the main tree shows nothing else" "?? .gitignore" "$(git -C "$G" status --porcelain)"
check "…left uncommitted" "" "$(git -C "$G" log --oneline -- .gitignore)"
cp "$G/.gitignore" "$TMP/gi"; crew_as g2 "$G" copy new two >/dev/null
check "a second copy does not touch .gitignore" yes "$(cmp -s "$TMP/gi" "$G/.gitignore" && echo yes || echo no)"
I="$TMP/i"; new_repo "$I"; printf 'node_modules/\n.worktrees\n' > "$I/.gitignore"
git -C "$I" add .gitignore && git -C "$I" commit -q -m ignore; join "$I" i1 coordinator
cp "$I/.gitignore" "$TMP/gi"; crew_as i1 "$I" copy new x >/dev/null
check "an existing ignore rule: .gitignore untouched" yes "$(cmp -s "$TMP/gi" "$I/.gitignore" && echo yes || echo no)"
check "…and the main tree is clean" "" "$(git -C "$I" status --porcelain)"
J="$TMP/j"; new_repo "$J"; join "$J" j1 coordinator
crew_as j1 "$J" copy new x >/dev/null
check "no .gitignore yet: created with the one line" "/.worktrees/" "$(cat "$J/.gitignore")"
out="$(crew_as g2 "$G" copy new ../escape 2>&1)"; rc=$?
check "a name with a slash is refused" 1 "$rc"
check "…nothing made outside .worktrees/" no "$( [ -e "$TMP/escape" ] || [ -e "$G/escape" ] && echo yes || echo no)"
W="$G/.worktrees/g-one"
check "status by name" yes "$(contains ".worktrees/g-one based on" "$(crew_as g2 "$G" copy status one 2>&1)")"
out="$(cd "$W" && CREW_AS=g2 bash "$C" copy status one 2>&1)"; rc=$?
check "copy commands work from inside the copy" 0 "$rc"
check "…against the main tree" yes "$(contains "0 changed" "$out")"

echo "-- hooks inside a worktree copy (PLUG-065)"
crew_as g1 "$G" hold a.txt >/dev/null
HOOK_OUT="$(hook pre-edit.sh "$(payload sid-g2 "$W" Edit file_path "$W/a.txt")")"
check "an edit in the copy is not held up by a hold on the tree" no "$(denied "$HOOK_OUT")"
printf 'copy\n' > "$W/a.txt"
check "…and not claimed as a tree path" no "$(contains ".worktrees" "$(cat "$G/.git/crew/claims" 2>/dev/null)")"
check "the guard finds the crew from inside the copy" deny \
    "$( [ "$(denied "$(hook pre-bash.sh "$(payload sid-g2 "$W" Bash command 'git stash')")")" = yes ] && echo deny || echo allow)"
check "a raw git worktree from a member is denied" yes \
    "$(denied "$(hook pre-bash.sh "$(payload sid-g2 "$G" Bash command 'git worktree add .worktrees/x')")")"
check "…and the denial names crew's command" yes "$(contains "copy new <name>" "$(hook pre-bash.sh "$(payload sid-g2 "$G" Bash command 'git worktree add x')")")"
check "crew copy new is not denied" no \
    "$(denied "$(hook pre-bash.sh "$(payload sid-g2 "$G" Bash command "bash $C copy new three")")")"
crew_as g1 "$G" release a.txt --unchanged >/dev/null

echo "-- remove (PLUG-065)"
out="$(crew_as g2 "$G" copy remove one 2>&1)"; rc=$?
check "remove refused while the copy has work the tree lacks" 1 "$rc"
check "…naming the file" yes "$(contains "a.txt" "$out")"
check "…the copy is still there" yes "$( [ -f "$W/a.txt" ] && echo yes || echo no)"
crew_as g2 "$G" apply one >/dev/null
out="$(crew_as g2 "$G" copy remove one 2>&1)"; rc=$?
check "remove after apply" 0 "$rc$([ "$rc" = 0 ] || echo ": $out")"
check "…the folder is gone" no "$( [ -e "$W" ] && echo yes || echo no)"
check "…and git forgot the worktree" 0 "$(git -C "$G" worktree list --porcelain | grep -c "g-one")"
mkdir -p "$G/.worktrees/foreign"
out="$(crew_as g2 "$G" copy remove "$G/.worktrees/foreign" 2>&1)"; rc=$?
check "a folder that is not crew's copy is left alone" 1 "$rc"
check "…still there" yes "$( [ -d "$G/.worktrees/foreign" ] && echo yes || echo no)"

finish
