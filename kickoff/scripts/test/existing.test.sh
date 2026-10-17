#!/usr/bin/env bash
# Tests for existing-project mode: inspect.sh's inferences, and that a project already kicked off
# is neither asked nor changed. No git binary: .git is built by hand, as inspect.sh only reads it.
#
#   bash kickoff/scripts/test/existing.test.sh
#   docker run --rm -v "$PWD":/w -w /w bash:5 bash kickoff/scripts/test/existing.test.sh
set -uo pipefail
. "$(dirname "$0")/helpers.sh"

export HOME="$TMP/home"; mkdir -p "$HOME"; unset CLAUDE_CONFIG_DIR
inspect() { bash "$S/inspect.sh" "$P"; }
inferred() { inspect | awk -F'\t' -v id="$1" '$2 != "" && $1 == id { print $2 }'; }
exists() { [ -e "$1" ] && echo yes || echo no; }

echo "== what an empty or bare directory says =="
P=$(fresh empty)
check "1a an empty directory is a new repo" "New, empty repo" "$(inferred A0)"
check "1b the name is the directory" "empty" "$(inferred A1)"
check "1c no .git, no remote inference" "" "$(inferred A5)"
P=$(fresh code); echo 'print(1)' > "$P/main.py"
check "1d files but no setup" "Existing code, no setup" "$(inferred A0)"

echo "== a set-up project =="
P=$(fresh full)
mkdir -p "$P/.git/refs/heads" "$P/docs/architecture" "$P/docs/external" "$P/scripts"
printf '[core]\n\tbare = false\n[remote "origin"]\n\turl = git@example.com:acme/full.git\n\tfetch = +refs/heads/*:refs/remotes/origin/*\n' > "$P/.git/config"
: > "$P/.git/refs/heads/develop"
printf '{\n  "tasksDir": "tasks",\n  "prefix": "FUL",\n  "nextId": 4\n}\n' > "$P/.task-config.json"
echo '#!/usr/bin/env bash' > "$P/scripts/dev.sh"; echo '# x' > "$P/CLAUDE.md"
printf 'services:\n  app:\n    ports:\n      - "3041:3000"\n  e2e:\n    profiles: [e2e]\n    image: x\nvolumes:\n  data:\n' > "$P/compose.yaml"
check "2a partly set up, with what was found" "yes" "$(has $'A0\tExisting, partly set up\tfound: CLAUDE.md docs .task-config.json' "$(inspect)")"
check "2b the remote from .git/config" "git@example.com:acme/full.git" "$(inferred A5)"
check "2c a develop branch means GitFlow, in the questionnaire's words" "GitFlow" "$(inferred R1)"
check "2d tasks in the repo, full option text" 'In the repo, `tasks/`' "$(inferred R6)"
check "2e the prefix" "FUL" "$(inferred R7)"
check "2f the entry point" '`scripts/dev.sh` (up, down, test, e2e, sh)' "$(inferred R4)"
check "2g services behind profiles do not count" "One container, one monolith" "$(inferred I2)"
check "2h the dev port" "3041" "$(inferred I5)"
check "2i the docs skeleton" "yes" "$(has '`project/` `architecture/`' "$(inferred K1)")"
check "2j docs/external means client documents" "yes" "$(has 'Client documents' "$(inferred C3)")"
check "2k every proposal carries its evidence" "0" "$(inspect | awk -F'\t' '$3 == ""' | wc -l | tr -d ' ')"
check "2l inspecting writes nothing" "no" "$(exists "$P/.kickoff-answers")"
bash "$S/answer.sh" --root "$P" R7 OTHER
check "2m an answer wins: answered questions are not proposed" "" "$(inferred R7)"

echo "== tasks outside the repo =="
P=$(fresh outside); mkdir -p "$HOME/.claude/project-tasks"
printf '{\n  "projects": {\n    "%s": {\n      "tasksDir": "/t",\n      "prefix": "OUT",\n      "nextId": 1\n    }\n  }\n}\n' "$P" > "$HOME/.claude/project-tasks/config.json"
check "3a found in the task registry" "Outside the repo" "$(inferred R6)"
check "3b its prefix" "OUT" "$(inferred R7)"

echo "== a project kicked off before: nothing asked, nothing changed =="
P=$(fresh done)
autofill "$P" A1=done A4=Mine A5="No remote yet" R7=DON E1=No I5=n/a C4=n/a C5="Never — always free to break"
bash "$S/charter.sh" "$P" >/dev/null; bash "$S/scaffold.sh" "$P" >/dev/null
before=$(cd "$P" && find . -type f | sort | while read -r f; do echo "$f $(cksum < "$f")"; done)
check "4a nothing left to ask" "" "$(bash "$S/plan.sh" "$P" --next)"
check "4b the charter is unchanged" "unchanged" "$(bash "$S/charter.sh" "$P")"
out=$(bash "$S/scaffold.sh" "$P")
check "4c the scaffold creates or updates nothing" "no" "$(echo "$out" | grep -qE '^(created|updated)' && echo yes || echo no)"
after=$(cd "$P" && find . -type f | sort | while read -r f; do echo "$f $(cksum < "$f")"; done)
check "4d no file changed" "$before" "$after"

echo "== an edited file is shown, not overwritten =="
echo "my rule" >> "$P/CLAUDE.md"; echo "my decision" >> "$P/docs/project/charter.md"
out=$(bash "$S/scaffold.sh" "$P" --diff)
check "5a --diff shows the change to CLAUDE.md" "yes" "$(has '-my rule' "$out")"
check "5b --diff reports it as differs" "yes" "$(has 'differs   CLAUDE.md' "$out")"
check "5c --diff wrote nothing" "my rule" "$(tail -1 "$P/CLAUDE.md")"
bash "$S/scaffold.sh" "$P" >/dev/null; check "5d without --force it is refused" "3" "$?"
check "5e --force replaces it once approved" "no" "$(bash "$S/scaffold.sh" "$P" --force >/dev/null; has 'my rule' "$(cat "$P/CLAUDE.md")")"
out=$(bash "$S/charter.sh" "$P" --diff)
check "5f charter --diff shows the hand edit" "yes" "$(has '-my decision' "$out")"
check "5g ... and writes nothing" "my decision" "$(tail -1 "$P/docs/project/charter.md")"
P2=$(fresh fresh2); bash "$S/answer.sh" --root "$P2" A1 x
check "5h charter --diff on a new project" "would-create docs/project/charter.md" "$(bash "$S/charter.sh" "$P2" --diff)"

summary
