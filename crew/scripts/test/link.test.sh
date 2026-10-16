#!/usr/bin/env bash
# PLUG-067: a new worktree has no untracked files. The paths in treeLink are linked from the main
# tree into every worktree crew makes (data only: relative, inside the tree, never executed); the
# project's own setup step (treeSetup) is printed for the session to run, never run by crew.
. "$(dirname "$0")/helpers.sh"

R="$TMP/r"; new_repo "$R"; join "$R" c1 coordinator
printf 'SECRET=1\n' > "$R/.env"; mkdir -p "$R/conf"; printf 'local\n' > "$R/conf/local.yml"

echo "-- no keys: nothing linked, nothing printed"
out="$(crew_as c1 "$R" copy new plain 2>&1)"
check "made" yes "$([ -d "$R/.worktrees/r-plain" ] && echo yes || echo no)"
check "no .env" no "$([ -e "$R/.worktrees/r-plain/.env" ] && echo yes || echo no)"
check "no setup line" no "$(contains "setup" "$out")"

echo "-- config: paths are data, inside the tree"
for p in ../x /etc/passwd a/../../x ..; do
    check "refused: $p" yes "$(contains "inside the main tree" "$(crew_as c1 "$R" config set treeLink "$p" 2>&1)")"
done
crew_as c1 "$R" config set treeLink .env conf/local.yml missing.txt a.txt >/dev/null
crew_as c1 "$R" config set treeSetup "touch ran-setup" >/dev/null

echo "-- a copy gets the links and the printed step"
out="$(crew_as c1 "$R" copy new one 2>&1)"; W="$R/.worktrees/r-one"
check ".env is a link" yes "$([ -L "$W/.env" ] && echo yes || echo no)"
check "…to the main tree's" "SECRET=1" "$(cat "$W/.env")"
check "a nested path too" yes "$([ -L "$W/conf/local.yml" ] && echo yes || echo no)"
check "an absent path: a note" yes "$(contains "missing.txt is not in the main tree" "$out")"
check "a tracked path is left as it is" no "$([ -L "$W/a.txt" ] && echo yes || echo no)"
check "the setup step is printed" yes "$(contains "touch ran-setup" "$out")"
check "…and not run" no "$([ -e "$W/ran-setup" ] || [ -e "$R/ran-setup" ] && echo yes || echo no)"
check "the links are not work to land" yes "$(contains "· 0 changed" "$(crew_as c1 "$R" copy status one 2>&1)")"

echo "-- a task worktree too, and the links do not make it dirty"
crew_as c1 "$R" config set tree worktrees >/dev/null
crew_as c1 "$R" tree new PLUG-9 >/dev/null 2>&1; T="$R/.worktrees/r-PLUG-9"
check "linked" yes "$([ -L "$T/.env" ] && echo yes || echo no)"
check "status: 0 uncommitted" yes "$(contains "task PLUG-9 · task/PLUG-9 · by c1 · 0 unmerged · 0 behind · 0 uncommitted" "$(crew_as c1 "$R" status)")"
check "sync is not refused for them" 0 "$(crew_as c1 "$R" tree sync PLUG-9 >/dev/null 2>&1; echo $?)"
check "remove is not refused for them" 0 "$(crew_as c1 "$R" tree remove PLUG-9 >/dev/null 2>&1; echo $?)"
check "…and the main tree's .env is still there" "SECRET=1" "$(cat "$R/.env")"

echo "-- a hand-edited path outside the tree is skipped, not linked"
printf '{ "treeLink": ["../outside", ".env"] }\n' > "$R/.crew.json"
printf 'x\n' > "$TMP/outside"
out="$(crew_as c1 "$R" copy new two 2>&1)"
check "refused with a note" yes "$(contains "../outside: not a path inside the main tree" "$out")"
check "not linked" no "$([ -e "$R/.worktrees/outside" ] || [ -L "$R/.worktrees/outside" ] && echo yes || echo no)"
check "the rest still linked" yes "$([ -L "$R/.worktrees/r-two/.env" ] && echo yes || echo no)"

finish
