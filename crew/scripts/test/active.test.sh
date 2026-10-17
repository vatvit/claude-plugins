#!/usr/bin/env bash
# PLUG-076: `crew active` — exit 0 with one line while a crew runs, 1 and silent otherwise — and
# crewRules, the project's crew-only rules, shown to members only.
. "$(dirname "$0")/helpers.sh"
R="$TMP/repo"; new_repo "$R"; N="$TMP/none"; new_repo "$N"; mkdir -p "$TMP/plain"

echo "-- crew active"
out="$(cd "$N" && bash "$C" active 2>&1)"; rc=$?
check "no crew: exit 1" 1 "$rc"
check "…and silent" "" "$out"
out="$(cd "$TMP/plain" && bash "$C" active 2>&1)"; rc=$?
check "outside git: exit 1, silent" "1:" "$rc:$out"
join "$R" a1 coordinator; join "$R" a2
out="$(cd "$R" && bash "$C" active)"; rc=$?
check "a crew: exit 0" 0 "$rc"
check "…one line: the crew" "crew repo: a1 coordinator · a2 worker" "$out"
out="$(crew_as a2 "$R" active)"
check "a member is told it is in" "crew repo: a1 coordinator · a2 worker · you: a2 (worker)" "$out"
out="$(cd "$R" && CREW_AS=zz bash "$C" active)"
check "a non-member is not" "crew repo: a1 coordinator · a2 worker" "$out"

echo "-- the guide's snippet (solo.md) runs as written"
snip="$(grep '^if crew active' "$S/../skills/crew/references/solo.md")"
check "solo.md has the snippet" yes "$(contains "crew active" "$snip")"
for d in "$R" "$N"; do printf '#!/bin/sh\necho e2e ran\n' > "$d/e2e.sh"; chmod +x "$d/e2e.sh"; done
crew() { bash "$C" "$@"; }
out="$(cd "$R" && export CREW_AS=a2 && eval "$snip" 2>&1)"
check "in a crew: through a slot" yes:yes "$(contains "e2e ran" "$out"):$(contains "running: ./e2e.sh" "$out")"
out="$(cd "$N" && eval "$snip" 2>&1)"
check "without one: plainly" "e2e ran" "$out"
unset -f crew

echo "-- crewRules"
out="$(crew_as a1 "$R" config set crewRules ../outside.md 2>&1)"; rc=$?
check "a path outside the tree is refused" 1:yes "$rc:$(contains "crewRules takes paths inside the main tree" "$out")"
out="$(crew_as a1 "$R" config set --user crewRules CLAUDE.crew.md 2>&1)"; rc=$?
check "crewRules is project-only" 1:yes "$rc:$(contains "crewRules is project-only" "$out")"
crew_as a1 "$R" config set crewRules CLAUDE.crew.md >/dev/null
out="$(hook session-start.sh "$(payload sid-a2 "$R" x x x)")"
check "a missing rules file is named, not fatal" yes "$(contains "crewRules CLAUDE.crew.md is not in the tree" "$out")"
printf '# crew-only\n- land with apply\n' > "$R/CLAUDE.crew.md"
out="$(hook session-start.sh "$(payload sid-a2 "$R" x x x)")"
check "SessionStart shows a member the rules" yes "$(contains "- land with apply" "$out")"
out="$(hook session-start.sh "$(payload sid-outsider "$R" x x x)")"
check "…not a non-member" no "$(contains "land with apply" "$out")"
hook pre-bash.sh "$(payload sid-a3 "$R" Bash command "bash $C whoami a3")" >/dev/null
out="$(cd "$R" && bash "$C" whoami a3)"
check "joining shows them" yes "$(contains "- land with apply" "$out")"
out="$(hook session-start.sh "$(payload sid-n "$N" x x x)")"
check "a repo with no crew: nothing at all" "" "$out"

finish
