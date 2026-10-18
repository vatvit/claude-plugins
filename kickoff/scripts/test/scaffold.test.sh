#!/usr/bin/env bash
# Tests for kickoff's setup scaffold (scaffold.sh): CLAUDE.md, the quality doc, task config and workflow.
#
#   bash kickoff/scripts/test/scaffold.test.sh
#   docker run --rm -v "$PWD":/w -w /w bash:5 bash kickoff/scripts/test/scaffold.test.sh
set -uo pipefail
. "$(dirname "$0")/helpers.sh"

export HOME="$TMP/home"; mkdir -p "$HOME"; unset CLAUDE_CONFIG_DIR
sc() { bash "$S/scaffold.sh" "$@"; }
exists() { [ -e "$1" ] && echo yes || echo no; }
ino() { ls -i "$1" | awk '{print $1}'; }
stepline() { grep -E "^[0-9]+\. $2 - " "$1"; }   # stepline <WORKFLOW.md> <step>

echo "== guards =="
P=$(fresh none); sc "$P" >/dev/null 2>&1; check "1a no answers is an error" "1" "$?"
P=$(fresh open); bash "$S/answer.sh" --root "$P" A1 open
sc "$P" >/dev/null 2>&1; check "1b open questions are an error" "1" "$?"
check "1c ... and nothing was written" "no" "$(exists "$P/CLAUDE.md")"

echo "== an own project: tasks in the repo =="
P=$(fresh mine)
a() { bash "$S/answer.sh" --root "$P" "$@"; }
a F2 "Unit"; a F2 --add "E2E success path"; a F3 "Formatter / code style"; a F3 --add "Linter / static analysis"
autofill "$P" A1=mine A3="Product / app / service" A4=Mine A5="No remote yet" R8=MINE D3=English K2=English I6=n/a C4=n/a \
    C5="Never — always free to break" F1="Basic" F4=n/a F5=n/a F6=n/a F7="One command runs them"
out=$(sc "$P"); rc=$?
check "2a runs clean" "0" "$rc"
check "2b no docs skeleton: docs/ is docs-manager's" "no no" "$(exists "$P/docs/_index.md") $(exists "$P/docs/dev")"
check "2e task config in the repo with the prefix" '"prefix": "MINE",' "$(grep prefix "$P/.task-config.json" | sed 's/^ *//')"
check "2f code and docs profiles by default" "yes" "$(has '`type: docs`' "$(cat "$P/tasks/_workflow/WORKFLOW.md")")"
C=$(cat "$P/CLAUDE.md")
check "2g CLAUDE.md points to the charter" "yes" "$(has '[the charter](docs/project/charter.md)' "$C")"
check "2h CLAUDE.md carries the branching choice" "yes" "$(has '**Branching:** Trunk' "$C")"
check "2i CLAUDE.md names the tasks" "yes" "$(has 'prefix `MINE`, kept in `tasks/`' "$C")"
check "2j no remote line without a remote" "no" "$(has 'Remote:' "$C")"
check "2k crew line when several sessions" "yes" "$(has 'joins the crew' "$C")"
check "2l nothing approved without external services" "no" "$(has 'Approved:' "$C")"
check "2m CLAUDE.md stays small" "yes" "$([ "$(wc -l < "$P/CLAUDE.md")" -lt 30 ] && echo yes || echo no)"
check "2n the next step names the first tasks" "yes" "$(has 'agree the charter' "$out")"
check "2s no identity line for an own project" "no" "$(has 'Identity:' "$C")"
check "2t the quality level and the checks run" "yes yes" "$(has '**Quality level:** Basic' "$C") $(has '**Checks run:** One command runs them.' "$C")"
Q="$P/docs/project/quality.md"
check "2u quality.md: frontmatter for docs-manager" "title: Quality" "$(sed -n 2p "$Q")"
check "2v ... a resulting set becomes a list" "2" "$(sed -n '/^## Tests?$/,/^## /p' "$Q" | grep -c '^- ')"
check "2w ... the question heading drops (pick any)" "no" "$(has 'pick any' "$(cat "$Q")")"
check "2x ... n/a aspects stay out" "no" "$(has '## Non-functional' "$(cat "$Q")")"
W="$P/tasks/_workflow/WORKFLOW.md"
check "2o the task-shaping step names INVEST" "yes" "$(has INVEST "$(stepline "$W" requirements)")"
check "2p architecture names SOLID and DRY" "yes yes" "$(has SOLID "$(stepline "$W" architecture)") $(has DRY "$(stepline "$W" architecture)")"
check "2q implementation and tech-debt name DRY" "yes yes" "$(has DRY "$(stepline "$W" implementation)") $(has duplication "$(stepline "$W" tech-debt)")"

echo "== re-running =="
i1=$(ino "$P/CLAUDE.md"); i2=$(ino "$P/.task-config.json"); i3=$(ino "$Q")
out=$(sc "$P")
check "3a nothing changes on a re-run" "$i1 $i2 $i3" "$(ino "$P/CLAUDE.md") $(ino "$P/.task-config.json") $(ino "$Q")"
check "3b ... and it says so" "no" "$(has created "$out")"
echo '  "x": 1' >> "$P/.task-config.json"; sc "$P" >/dev/null
check "3c a seeded file is the user's: never overwritten" '  "x": 1' "$(tail -1 "$P/.task-config.json")"
echo "hand edit" >> "$P/CLAUDE.md"; sc "$P" >/dev/null; check "3d an edited CLAUDE.md is refused" "3" "$?"
check "3e ... and kept" "hand edit" "$(tail -1 "$P/CLAUDE.md")"
W="$P/tasks/_workflow/WORKFLOW.md"; echo "11. my-step - The project's own" >> "$W"; w1="$(cksum < "$W")"; sc "$P" >/dev/null
check "3f an existing WORKFLOW.md stays byte-identical" "$w1" "$(cksum < "$W")"

echo "== practices left out of the workflow (R10) =="
P=$(fresh practices)
a R10 "INVEST — a task of more than one behaviour is split into small vertical slices"; a R10 --add "SOLID — one responsibility per module, depend on abstractions"
autofill "$P" A1=pr A4=Mine A5="No remote yet" R8=PR D3=English K2=English I6=n/a C4=n/a C5="Never — always free to break" F1="None — no automated checks yet, or one smoke test"
sc "$P" >/dev/null
W="$P/tasks/_workflow/WORKFLOW.md"
check "6a a dropped practice leaves every step (DRY)" "no" "$(has DRY "$(cat "$W")")"
check "6b ... and so does the other (Tests first)" "no" "$(has 'Tests first' "$(cat "$W")")"
check "6c the kept ones stay (INVEST, SOLID)" "yes yes" "$(has INVEST "$(stepline "$W" requirements)") $(has SOLID "$(stepline "$W" architecture)")"
check "6d a step still reads as a sentence" "yes" "$(stepline "$W" tech-debt | grep -q '[.]$' && echo yes || echo no)"
check "6e level None is still recorded in the quality doc" "yes" "$(has "None — no automated checks" "$(cat "$P/docs/project/quality.md")")"

echo "== a client's PoC: tasks outside the repo =="
REG="$HOME/.claude/project-tasks/config.json"
mkdir -p "$(dirname "$REG")"; printf '{\n  "projects": {\n    "/elsewhere": {\n      "tasksDir": "/x",\n      "prefix": "X",\n      "nextId": 7\n    }\n  }\n}\n' > "$REG"
P=$(fresh client)
autofill "$P" A1="Client PoC" A4="A client's" A5="git@example.com:acme/poc.git" E1="USES — an LLM API" E2=OpenAI \
    R3="VPN needed" R8=CPOC R9="One minimal profile" D3=English K2=English I6=n/a C4=n/a C5="Never — always free to break" \
    F1="None — no automated checks yet, or one smoke test"
out=$(sc "$P"); rc=$?
check "4a runs clean" "0" "$rc"
check "4b no task config in a client's repo" "no" "$(exists "$P/.task-config.json")"
check "4c the registry gains the project" "yes" "$(grep -qF "\"$P\": {" "$REG" && echo yes || echo no)"
check "4d ... and keeps the existing entry" '"nextId": 7' "$(grep -F '"nextId": 7' "$REG" | sed 's/^ *//')"
check "4e ... in valid shape" "yes" "$(awk '/^    "\/elsewhere": \{$/{a=1} /^    },$/{b=1} END{print (a&&b)?"yes":"no"}' "$REG")"
check "4f tasks live in the per-account dir, slugged" "yes" "$(exists "$HOME/.claude/project-tasks/client-poc/_workflow/WORKFLOW.md")"
check "4g the minimal workflow" "yes" "$(has 'one minimal profile' "$(cat "$HOME/.claude/project-tasks/client-poc/_workflow/WORKFLOW.md")")"
W="$HOME/.claude/project-tasks/client-poc/_workflow/WORKFLOW.md"
check "4o the minimal workflow: INVEST at context, SOLID and DRY at implementation" "yes yes yes" "$(has INVEST "$(stepline "$W" context)") $(has SOLID "$(stepline "$W" implementation)") $(has DRY "$(stepline "$W" implementation)")"
C=$(cat "$P/CLAUDE.md")
check "4h CLAUDE.md never carries the home path (identity)" "no" "$(has "$HOME" "$C")"
check "4i the remote and its quirks" "yes yes" "$(has 'git@example.com:acme/poc.git' "$C") $(has 'VPN needed' "$C")"
check "4j the provider approval" "yes" "$(has 'calling OpenAI in development and tests' "$C")"
check "4n the tasks location reads as prose" "yes" "$(has 'kept outside the repo (the task skill' "$C")"
check "4k a client's project keeps personal identity out (A6)" "yes" "$(has '**Identity:** only the project owner' "$C")"
out=$(sc "$P"); check "4l the registry entry is not added twice" "1" "$(grep -cF "\"$P\": {" "$REG")"
P2=$(fresh client2); autofill "$P2" A1=two A4="A client's" A5="No remote yet" R8=TWO D3=English K2=English I6=n/a C4=n/a \
    C5="Never — always free to break" F1="None — no automated checks yet, or one smoke test"
CLAUDE_CONFIG_DIR="$HOME/acct-2" sc "$P2" >/dev/null
check "4m a second account registers in its own registry" "yes no" "$(exists "$HOME/acct-2/project-tasks/config.json") $(grep -qF "\"$P2\"" "$REG" && echo yes || echo no)"

echo "== without the task plugin =="
P=$(fresh notask)
KICKOFF_PLUGINS="" autofill "$P" A1=nt A4=Mine A5="No remote yet" D3=English K2=English I6=n/a C4=n/a \
    C5="Never — always free to break" F1="None — no automated checks yet, or one smoke test"
KICKOFF_PLUGINS="" sc "$P" >/dev/null; rc=$?
check "5a runs clean" "0" "$rc"
check "5b no task config, no workflow" "no no" "$(exists "$P/.task-config.json") $(exists "$P/tasks")"
check "5c no crew line" "no" "$(has 'joins the crew' "$(cat "$P/CLAUDE.md")")"

summary
