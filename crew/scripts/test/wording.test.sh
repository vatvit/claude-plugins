#!/usr/bin/env bash
# PLUG-060: one task, one session. The skill and the scripts say so, and never speak of a
# "slice" — an undefined word that read as "a piece of a task shared out between sessions".
. "$(dirname "$0")/helpers.sh"
K="$S/../skills/crew"

echo "-- no 'slice' in the skill, its references or the scripts"
hits="$(grep -rli 'slice' "$K" "$S" "$S/../hooks" | grep -v '/test/' || true)"
check "no file says slice" "" "$hits"

echo "-- the rule is stated"
out="$(cat "$K/SKILL.md")"
check "SKILL.md: one task, one session" yes "$(contains "One task, one session" "$out")"
check "SKILL.md: split into sub-tasks to work in parallel" yes "$(contains "sub-tasks" "$out")"
out="$(cat "$K/references/playbook.md")"
check "playbook: one task, one session" yes "$(contains "One task, one session" "$out")"
check "playbook: ownership moves by an explicit hand-over" yes "$(contains "never has two owners" "$out")"

finish
