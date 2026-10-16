#!/usr/bin/env bash
# PLUG-066: worktree mode. The `tree` key is the user's, asked once per project; under `shared` the
# user may make a per-task exception. One task = branch task/<ID> = one worktree = one session; the
# member brings in the shared branch (merge or rebase), the coordinator merges; guards in a worktree.
. "$(dirname "$0")/helpers.sh"

R="$TMP/r"; new_repo "$R"; join "$R" c1 coordinator; join "$R" w1
crew_as c1 "$R" config set committer coordinator >/dev/null; crew_as c1 "$R" config set push human >/dev/null
P="$R/.worktrees/r-PLUG-7"

echo "-- undecided: the coordinator is told to ask"
check "status names it" yes "$(contains "worktrees: not decided for this project" "$(crew_as c1 "$R" status)")"
ss="$(hook session-start.sh "$(payload sid-c1 "$R" SessionStart source startup)")"
check "SessionStart names it" yes "$(contains "crew config set tree shared|worktrees" "$ss")"
check "the user layer is refused" yes "$(contains "project-only" "$(crew_as c1 "$R" config set --user tree worktrees 2>&1)")"
check "a bad value is refused" yes "$(contains "tree is shared or worktrees" "$(crew_as c1 "$R" config set tree maybe 2>&1)")"
crew_as c1 "$R" config set tree shared >/dev/null
check "decided: status is quiet" no "$(contains "worktrees: not decided" "$(crew_as c1 "$R" status)")"

echo "-- shared: tree new needs the user's exception"
out="$(crew_as w1 "$R" tree new PLUG-7 2>&1)"; rc=$?
check "refused" 1 "$rc"; check "…and says how" yes "$(contains "tree allow PLUG-7" "$out")"
check "a worker cannot allow" yes "$(contains "coordinator" "$(crew_as w1 "$R" tree allow PLUG-7 2>&1)")"
crew_as c1 "$R" tree allow PLUG-7 >/dev/null
check "status shows the exception" yes "$(contains "exceptions: PLUG-7" "$(crew_as c1 "$R" status)")"
out="$(crew_as w1 "$R" tree new PLUG-7 2>&1)"; rc=$?
check "with it: made" 0 "$rc"
check "the branch is task/PLUG-7" task/PLUG-7 "$(git -C "$P" symbolic-ref --short HEAD 2>/dev/null)"
check "…from the shared branch" "$(git -C "$R" rev-parse main)" "$(git -C "$R" rev-parse task/PLUG-7 2>/dev/null)"
check "status lists it with its owner" yes "$(contains ".worktrees/r-PLUG-7 · task PLUG-7 · task/PLUG-7 · by w1" "$(crew_as c1 "$R" status)")"
check "twice: refused" 1 "$(crew_as w1 "$R" tree new PLUG-7 >/dev/null 2>&1; echo $?)"
check "copy commands refuse a task worktree" yes "$(contains "task worktree" "$(crew_as w1 "$R" copy status PLUG-7 2>&1)")"

echo "-- guards in the task worktree"
wv() { [ "$(denied "$(hook pre-bash.sh "$(payload "sid-$1" "$2" Bash command "$3")")")" = yes ] && echo deny || echo allow; }
for c in 'git stash' 'git stash push -m x' 'git branch x' 'git branch -f main HEAD' 'git branch -D task/PLUG-7' \
         'git checkout main' 'git checkout -b other' 'git switch main' 'git switch -c other' 'git switch --detach' \
         'git update-ref refs/heads/main HEAD' 'git fetch . HEAD:main' 'git worktree add ../x' \
         'git push origin task/PLUG-7'; do
    check "worktree: $c" deny "$(wv w1 "$P" "$c")"
done
for c in 'git add -A' 'git commit -m x' 'git merge main' 'git checkout -- a.txt' 'git stash list' 'git branch' \
         'git switch task/PLUG-7' 'git reset --hard HEAD' 'git rebase main' 'git fetch origin'; do
    check "worktree: $c" allow "$(wv w1 "$P" "$c")"
done
check "from the main tree, -C into the worktree: stash denied" deny "$(wv w1 "$R" "git -C .worktrees/r-PLUG-7 stash")"
check "from the main tree, -C into the worktree: add -A allowed" allow "$(wv w1 "$R" "git -C $P add -A")"
check "the main tree keeps its own guard" deny "$(wv w1 "$R" 'git add -A')"
crew_as c1 "$R" config set taskPush w1 >/dev/null
check "taskPush: own task branch" allow "$(wv w1 "$P" 'git push origin task/PLUG-7')"
check "taskPush: HEAD:own branch" allow "$(wv w1 "$P" 'git push -u origin HEAD:task/PLUG-7')"
check "taskPush: the shared branch is not" deny "$(wv w1 "$P" 'git push origin HEAD:main')"
check "taskPush: no refspec is not" deny "$(wv w1 "$P" 'git push origin')"
check "taskPush: --all is not" deny "$(wv w1 "$P" 'git push --all origin')"
check "taskPush: --user refused" yes "$(contains "project-only" "$(crew_as c1 "$R" config set --user taskPush w1 2>&1)")"

echo "-- the flow: commit, bring in the shared branch with a conflict, resolve, merge, clean up"
printf 'task\n' > "$P/a.txt"; git -C "$P" commit -q -am "PLUG-7: a"
printf 'main\n' > "$R/a.txt"; git -C "$R" commit -q -am "other: a"
printf 'dirty\n' > "$P/b.txt"
check "sync refused while dirty" yes "$(contains "uncommitted" "$(crew_as w1 "$R" tree sync PLUG-7 2>&1)")"
git -C "$P" checkout -q -- b.txt
out="$(crew_as w1 "$R" tree sync PLUG-7 2>&1)"; rc=$?
check "sync: conflict reported" 1 "$rc"; check "…naming the file" yes "$(contains "a.txt" "$out")"
check "merge refused while the worktree is mid-merge" 1 "$(crew_as c1 "$R" tree merge PLUG-7 >/dev/null 2>&1; echo $?)"
printf 'both\n' > "$P/a.txt"; git -C "$P" add a.txt; git -C "$P" commit -q --no-edit
check "sync again: clean" 0 "$(crew_as w1 "$R" tree sync PLUG-7 >/dev/null 2>&1; echo $?)"
check "a worker cannot merge" yes "$(contains "coordinator" "$(crew_as w1 "$R" tree merge PLUG-7 2>&1)")"
check "remove refused: not merged" yes "$(contains "not merged" "$(crew_as w1 "$R" tree remove PLUG-7 2>&1)")"
crew_as c1 "$R" config set committer human-approved >/dev/null
out="$(crew_as c1 "$R" tree merge PLUG-7 2>&1)"
check "human-approved: the merge is printed" yes "$(contains "merge --no-ff --no-edit task/PLUG-7" "$out")"
check "…and not run" main "$(git -C "$R" show main:a.txt)"
crew_as c1 "$R" config set committer coordinator >/dev/null
out="$(crew_as c1 "$R" tree merge PLUG-7 2>&1)"; rc=$?
check "merged" 0 "$rc"
check "the shared branch has the resolution" both "$(git -C "$R" show main:a.txt)"
check "…as a merge commit" 2 "$(git -C "$R" log -1 --format=%P main | wc -w | tr -d ' ')"
check "the worktree is gone" no "$([ -d "$P" ] && echo yes || echo no)"
check "the branch is gone" no "$(git -C "$R" rev-parse -q --verify task/PLUG-7 >/dev/null && echo yes || echo no)"
check "the exception ended" no "$(contains "exceptions:" "$(crew_as c1 "$R" status)")"
check "the coordinator is told to regenerate" yes "$(contains "regenerate" "$out")"

echo "-- worktrees mode, rebase, remove"
crew_as c1 "$R" config set tree worktrees >/dev/null; crew_as c1 "$R" config set treeSync rebase >/dev/null
check "no exception needed" 0 "$(crew_as w1 "$R" tree new PLUG-8 >/dev/null 2>&1; echo $?)"
Q="$R/.worktrees/r-PLUG-8"
printf 'n\n' > "$Q/n.txt"; git -C "$Q" add n.txt; git -C "$Q" commit -q -m "PLUG-8: n"
printf 'm\n' > "$R/m.txt"; git -C "$R" add m.txt; git -C "$R" commit -q -m "other: m"
crew_as w1 "$R" tree sync PLUG-8 >/dev/null 2>&1
check "rebase: on top of the shared branch, no merge commit" "$(git -C "$R" rev-parse main)" "$(git -C "$Q" rev-parse HEAD~1)"
printf 'x\n' > "$Q/x.txt"
check "remove refused while dirty" yes "$(contains "uncommitted" "$(crew_as w1 "$R" tree remove PLUG-8 2>&1)")"
rm "$Q/x.txt"
check "remove refused while unmerged" yes "$(contains "not merged" "$(crew_as w1 "$R" tree remove PLUG-8 2>&1)")"
git -C "$Q" reset -q --hard main
check "remove: clean and merged" 0 "$(crew_as w1 "$R" tree remove PLUG-8 >/dev/null 2>&1; echo $?)"
check "…worktree and branch gone" no "$([ -d "$Q" ] || git -C "$R" rev-parse -q --verify task/PLUG-8 >/dev/null && echo yes || echo no)"

finish
