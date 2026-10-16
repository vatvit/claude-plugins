#!/usr/bin/env bash
# PLUG-031: land exact path lists under the committer mode; the git guard on the shared index.
. "$(dirname "$0")/helpers.sh"
R="$TMP/repo"; new_repo "$R"
git -C "$R" branch other
git -C "$R" commit -q --allow-empty -m two                                # so HEAD~1 exists
join "$R" s1 coordinator; join "$R" s2; join "$R" s3
gx() { hook pre-bash.sh "$(payload "sid-$1" "$R" Bash command "$2")"; }    # gx <name> <command>
verdict() { [ "$(denied "$(gx "$1" "$2")")" = yes ] && echo deny || echo allow; }

echo "-- defaults: the user decides how this project commits and pushes (PLUG-057)"
check "coordinator: push denied" deny "$(verdict s1 'git push')"
check "worker: push denied" deny "$(verdict s2 'git push')"
out="$(gx s1 'git push')"
check "…the push is the user's" yes "$(contains "pushes are the user's" "$out")"
check "…points at prepush" yes "$(contains "CREW_AS=s1 crew land prepush" "$out")"
check "…and only on the user's word, at the setting" yes "$(contains "config set push committer" "$out")"
edit "$R" s1 z.txt "z"; printf 'feat: z — PLUG-1\n' > "$TMP/msg"
before="$(git -C "$R" rev-parse HEAD)"
out="$(crew_as s1 "$R" land --msg-file "$TMP/msg" -- z.txt)"
check "land commits nothing" "$before" "$(git -C "$R" rev-parse HEAD)"
check "…prints the commit for the user" yes "$(contains "git commit -F" "$out")"
rm -f "$R/z.txt"
out="$(crew_as s1 "$R" status)"
check "status: undecided is visible" yes "$(contains "not decided for this project (committer, push)" "$out")"
check "…with the settings to record" yes "$(contains "crew config set push committer|human" "$out")"
out="$(hook session-start.sh "$(payload sid-s1 "$R" x x x)")"
check "coordinator start line: ask the user" yes "$(contains "ask them" "$out")"
check "…shows push" yes "$(contains "push: human" "$out")"
check "worker start line: no ask (the coordinator asks)" no "$(contains "ask them" "$(hook session-start.sh "$(payload sid-s2 "$R" x x x)")")"
printf '{"push":"committer"}' > "$CREW_USER_CONFIG"
check "push decided, committer not: still asked" yes "$(contains "not decided for this project (committer)" "$(crew_as s1 "$R" status)")"
check "push=committer under human-approved: still the user's" deny "$(verdict s1 'git push')"
# the rest of this suite: a project whose user chose coordinator commits and pushes
printf '{"committer":"coordinator","push":"committer"}' > "$CREW_USER_CONFIG"
check "decided in the user layer: no question" no "$(contains "not decided" "$(crew_as s1 "$R" status)")"

echo "-- guard: denied for a worker"
for c in 'git add -A' 'git add .' 'git add -u' 'git add --all src' 'cd sub && git add -A' 'FOO=1 git -C . add -A' \
         'git commit -am wip' 'git commit -a -m wip' 'git commit -m wip -- a.txt' 'git stash' 'git stash pop' \
         'git checkout -- .' 'git checkout -b feat' 'git checkout other' 'git switch other' 'git switch -c feat' \
         'git restore .' 'git reset --hard' 'git reset' 'git reset HEAD~1' 'git clean -fd' 'git worktree add ../w' \
         'git worktree list' 'git branch feat' 'git branch -D other' 'git rebase main' 'git pull' 'git push' \
         'echo $(git add -A)' 'ls; git stash'; do
    check "worker: $c" deny "$(verdict s2 "$c")"
done
out="$(gx s2 'git add -A')"
check "denial names the alternative" yes "$(contains "msg handoff" "$out")"
check "denial carries the caller's prefix" yes "$(contains "CREW_AS=s2 crew" "$out")"

echo "-- guard: allowed"
for c in 'git status' 'git log --oneline -5' 'git diff' 'git add a.txt' 'git add -- "a b.txt"' 'git checkout -- a.txt' \
         'git checkout main' 'git switch main' 'git restore -- a.txt' 'git reset -- a.txt' 'git reset a.txt' \
         'git stash list' 'git branch' 'git branch --show-current' 'git clean -n' 'echo git is fine' 'ls -la'; do
    check "worker: $c" allow "$(verdict s2 "$c")"
done
check "coordinator: commit with a path list" allow "$(verdict s1 'git commit -F msg -- a.txt')"
check "coordinator: commit without a path list" deny "$(verdict s1 'git commit -m x')"
check "coordinator: rebase" allow "$(verdict s1 'git pull --rebase')"
check "coordinator: push" allow "$(verdict s1 'git push')"
check "coordinator: still no add -A" deny "$(verdict s1 'git add -A')"
echo "-- guard: a session outside the crew works as usual (PLUG-055)"
for c in 'git commit -m x -- a.txt' 'git commit -m x' 'git add -A' 'git commit -am wip' 'git push' 'git stash'; do
    check "non-member: $c" allow "$(verdict nobody "$c")"
done

echo "-- guard: a member with no coordinator is not sent to nobody (PLUG-055)"
R2="$TMP/solo"; new_repo "$R2"; join "$R2" w1
out="$(hook pre-bash.sh "$(payload sid-w1 "$R2" Bash command 'git commit -m x -- a.txt')")"
check "still denied: membership keeps the guard" yes "$(denied "$out")"
check "…says there is no coordinator" yes "$(contains "this crew has no coordinator" "$out")"
check "…names the way out" yes "$(contains "crew whoami w1 coordinator" "$out")"
check "…not a hand-off to nobody" no "$(contains "msg handoff" "$out")"
out="$(hook pre-bash.sh "$(payload sid-w1 "$R2" Bash command 'git push')")"
check "push: the same way out" yes "$(contains "crew whoami w1 coordinator" "$out")"
(cd "$R2" && CREW_AS=w1 bash "$C" whoami w1 coordinator --sid sid-w1 >/dev/null 2>&1)
check "…and the way out works: the commit is allowed" no "$(denied "$(hook pre-bash.sh "$(payload sid-w1 "$R2" Bash command "git commit -m x -- a.txt")")")"
check "with a coordinator the hand-off stays" yes "$(contains "msg handoff" "$(gx s2 'git commit -m x -- a.txt')")"

echo "-- guard: dry runs stage nothing (PLUG-046)"
for c in 'git add -A --dry-run' 'git add --dry-run -A' 'git add -n .' 'git add -nA' 'git add -An' 'git add -u -n'; do
    check "worker: $c" allow "$(verdict s2 "$c")"
done
check "…but 'git add -A' still denied" deny "$(verdict s2 'git add -A')"
check "…and -N (intent-to-add) is not a dry run" deny "$(verdict s2 'git add -NA')"

echo "-- guard: a flag inside a short-option cluster, in any position (PLUG-046)"
for c in 'git add -Av' 'git add -uv' 'git checkout -qf' 'git switch -qc feat' 'git branch -qD other'; do
    check "worker: $c" deny "$(verdict s2 "$c")"
done
check "coordinator: commit -av is the commit -a denial" yes "$(contains "git commit -a takes" "$(gx s1 'git commit -av -m x')")"
check "worker: git clean -fdn (a dry run)" allow "$(verdict s2 'git clean -fdn')"
check "worker: git add --verbose (a long option, not a cluster)" allow "$(verdict s2 'git add --verbose a.txt')"

echo "-- guard: the alternative depends on the role (PLUG-046)"
out="$(gx s1 'git add -A')"
check "coordinator on add -A: pointed at land" yes "$(contains "CREW_AS=s1 crew land --msg-file F -- <paths>" "$out")"
check "…not told to hand off" no "$(contains "msg handoff" "$out")"
out="$(gx s1 'git commit -am wip')"
check "coordinator on commit -a: pointed at land" yes "$(contains "land --msg-file F" "$out")"
check "…not told to hand off" no "$(contains "msg handoff" "$out")"
out="$(gx s2 'git commit -am wip')"
check "worker on commit -a: pointed at msg handoff" yes "$(contains "CREW_AS=s2 crew msg handoff" "$out")"
printf '{"committer":"each-session"}' > "$R/.crew.json"
out="$(gx s2 'git add -A')"
check "each-session worker on add -A: lands its own paths" yes "$(contains "CREW_AS=s2 crew land --msg-file F -- <your paths>" "$out")"
check "…not told to hand off" no "$(contains "msg handoff" "$out")"
rm -f "$R/.crew.json"

echo "-- guard: quiet slot holds pushes; warn mode"
crew_as s3 "$R" slot request quiet 5 >/dev/null
check "push during another's quiet slot" deny "$(verdict s1 'git push')"
check "…names the holder" yes "$(contains "s3 is running a quiet slot" "$(gx s1 'git push')")"
crew_as s3 "$R" slot done >/dev/null
printf '{"hookMode":"warn"}' > "$R/.crew.json"
out="$(gx s2 'git add -A')"
check "warn mode allows" no "$(denied "$out")"
check "…with the reason" yes "$(contains "hookMode=warn" "$out")"
printf '{"committer":"each-session"}' > "$R/.crew.json"
check "each-session: a worker commits a path list" allow "$(verdict s2 'git commit -F m -- a.txt')"
check "each-session: a worker pushes" allow "$(verdict s2 'git push')"
rm -f "$R/.crew.json"

echo "-- land"
printf 'feat: a — PLUG-1\n' > "$TMP/msg"
edit "$R" s2 a.txt "s2 a"; edit "$R" s3 b.txt "s3 b"; edit "$R" s2 "n e w.txt" "new"; rm "$R/b.txt"; git -C "$R" rm -q --cached b.txt 2>/dev/null; git -C "$R" reset -q -- b.txt
git -C "$R" rm -q a.txt --cached && git -C "$R" add a.txt          # leave a.txt staged, as a careless peer might
out="$(crew_as s2 "$R" land --msg-file "$TMP/msg" -- a.txt 2>&1)"; rc=$?
check "a worker cannot land (coordinator mode)" 1 "$rc"
out="$(crew_as s1 "$R" land -- a.txt 2>&1)"; rc=$?
check "land needs a message file" 1 "$rc"
out="$(crew_as s1 "$R" land --msg-file "$TMP/msg" -- a.txt nope.txt)"; rc=$?
check "a path that is not dirty refuses the whole land" 1 "$rc"
check "…naming it" yes "$(contains "refused  nope.txt — not dirty" "$out")"
check "…nothing committed" 2 "$(git -C "$R" rev-list --count HEAD)"
out="$(crew_as s1 "$R" land --msg-file "$TMP/msg" -- a.txt "n e w.txt")"; rc=$?
check "land commits" 0 "$rc"
check "…exactly the listed paths" "a.txt|n e w.txt" "$(git -C "$R" show --name-only --format= HEAD | paste -sd'|' -)"
check "…with the message" "feat: a — PLUG-1" "$(git -C "$R" log -1 --format=%s)"
check "…reports what it left (by owner)" yes "$(contains "not landed: b.txt (s3)" "$out")"
check "…b.txt still deleted in the tree, uncommitted" yes "$(git -C "$R" status --porcelain -- b.txt | grep -q . && echo yes || echo no)"
check "…landed claims dropped" no "$(contains "a.txt" "$(cat "$R/.git/crew/claims")")"

echo "-- holds, modes"
edit "$R" s2 c.txt "c"; crew_as s2 "$R" hold c.txt >/dev/null
out="$(crew_as s1 "$R" land --msg-file "$TMP/msg" -- c.txt)"
check "coordinator lands a held hand-off and says who releases" yes "$(contains "s2 releases c.txt: CREW_AS=s2 crew" "$out")"
printf '{"committer":"human-approved"}' > "$R/.crew.json"
edit "$R" s2 d.txt "d"
before="$(git -C "$R" rev-parse HEAD)"
out="$(crew_as s1 "$R" land --msg-file "$TMP/msg" -- d.txt)"
check "human-approved: nothing committed" "$before" "$(git -C "$R" rev-parse HEAD)"
check "…prints the exact commands" yes "$(contains "git commit -F" "$out")"
printf '{"committer":"each-session"}' > "$R/.crew.json"
out="$(crew_as s3 "$R" land --msg-file "$TMP/msg" -- d.txt)"; rc=$?
check "each-session: a peer's path is refused" 1 "$rc"
out="$(crew_as s2 "$R" land --msg-file "$TMP/msg" -- d.txt)"; rc=$?
check "each-session: own path lands" 0 "$rc"
rm -f "$R/.crew.json"

echo "-- prepush"
git init -q --bare "$TMP/origin.git" && git -C "$R" remote add origin "$TMP/origin.git" && git -C "$R" push -q origin main 2>/dev/null
edit "$R" s1 e.txt "e"; crew_as s1 "$R" land --msg-file "$TMP/msg" -- e.txt >/dev/null
out="$(crew_as s1 "$R" land prepush)"
check "prepush lists unpushed commits" yes "$(contains "$(git -C "$R" rev-parse --short HEAD)" "$out")"
crew_as s3 "$R" slot request quiet 5 >/dev/null
out="$(crew_as s1 "$R" land prepush)"; rc=$?
check "prepush holds during a quiet slot" 1 "$rc"

finish
