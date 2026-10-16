#!/usr/bin/env bash
# PLUG-069: `status` lists crew's worktrees — folder, task or copy, branch, owner, unmerged commits,
# how far behind the shared branch, uncommitted files — and only counts the ones crew did not make.
. "$(dirname "$0")/helpers.sh"

T="$TMP/t"; new_repo "$T"; join "$T" t1 coordinator; join "$T" t2
trees() { crew_as t1 "$T" status | awk '/^trees:/ { on = 1; print; next } on && /^  / { print; next } { on = 0 }'; }

echo "-- no worktrees"
check "no trees: line" "" "$(trees)"

echo "-- a copy, a task worktree, and two that are not crew's"
crew_as t2 "$T" copy new one >/dev/null
git -C "$T" worktree add -q -b task/PLUG-7 "$T/.worktrees/t-PLUG-7" 2>/dev/null
P="$T/.worktrees/t-PLUG-7"
printf 'x\n' > "$P/x.txt"; git -C "$P" add x.txt; git -C "$P" commit -q -m x
printf 'y\n' > "$P/y.txt"; git -C "$P" add y.txt; git -C "$P" commit -q -m y
printf 'new\n' > "$T/c.txt"; git -C "$T" add c.txt; git -C "$T" commit -q -m c      # the shared branch moves on
printf 'dirty\n' > "$T/.worktrees/t-one/a.txt"; printf 'n\n' > "$T/.worktrees/t-one/n.txt"
git -C "$T" worktree add -q --detach "$TMP/elsewhere" 2>/dev/null
git -C "$T" worktree add -q -b feature-x "$T/.worktrees/t-feature" 2>/dev/null
out="$(trees)"
check "the header counts both kinds" "trees: 2 crew worktrees · 2 not crew's (left alone)" "$(printf '%s\n' "$out" | head -1)"
copy="$(printf '%s\n' "$out" | grep 't-one' || true)"
check "the copy: folder, name, detached, owner" yes "$(contains ".worktrees/t-one · copy one · detached · by t2" "$copy")"
check "…0 unmerged, 1 behind, 2 uncommitted" yes "$(contains "0 unmerged · 1 behind · 2 uncommitted" "$copy")"
task="$(printf '%s\n' "$out" | grep 'PLUG-7' || true)"
check "the task worktree: folder, task, branch" yes "$(contains ".worktrees/t-PLUG-7 · task PLUG-7 · task/PLUG-7" "$task")"
check "…owner unknown without crew's record" yes "$(contains "by ?" "$task")"
check "…2 unmerged, 1 behind, 0 uncommitted" yes "$(contains "2 unmerged · 1 behind · 0 uncommitted" "$task")"
check "a foreign branch in .worktrees/ is not listed" no "$(contains "feature" "$out")"
check "a worktree outside .worktrees/ is not listed" no "$(contains "elsewhere" "$out")"
check "two crew lines" 2 "$(printf '%s\n' "$out" | grep -c '^  ')"

echo "-- only foreign ones"
U="$TMP/u"; new_repo "$U"; join "$U" u1 coordinator
git -C "$U" worktree add -q --detach "$TMP/u-elsewhere" 2>/dev/null
check "counted in one line" "trees: none of crew's · 1 not crew's (left alone)" "$(crew_as u1 "$U" status | grep '^trees:')"

echo "-- rebase keeps the owner"
crew_as t1 "$T" copy rebase one >/dev/null 2>&1 || true
check "by t2 after a rebase" yes "$(contains "copy one · detached · by t2" "$(trees)")"

finish
