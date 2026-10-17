#!/usr/bin/env bash
# Tests for kickoff's setup scaffold (scaffold.sh): docs skeleton, CLAUDE.md, task config.
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
autofill "$P" A1=mine A3="Product / app / service" A4=Mine A5="No remote yet" R7=MINE E1=No I5=n/a C4=n/a C5="Never — always free to break"
out=$(sc "$P"); rc=$?
check "2a runs clean" "0" "$rc"
check "2b docs skeleton: project, architecture, dev" "yes yes yes yes" "$(exists "$P/docs/_index.md") $(exists "$P/docs/project/_index.md") $(exists "$P/docs/architecture/_index.md") $(exists "$P/docs/dev/_index.md")"
check "2c no external/ without client documents, no design/ outside games" "no no" "$(exists "$P/docs/external") $(exists "$P/docs/design")"
check "2d _index.md carries docs-manager frontmatter" "title: Development" "$(sed -n 2p "$P/docs/dev/_index.md")"
check "2e task config in the repo with the prefix" '"prefix": "MINE",' "$(grep prefix "$P/.task-config.json" | sed 's/^ *//')"
check "2f code and docs profiles by default" "yes" "$(has '`type: docs`' "$(cat "$P/tasks/_workflow/WORKFLOW.md")")"
C=$(cat "$P/CLAUDE.md")
check "2g CLAUDE.md points to the charter" "yes" "$(has '[the charter](docs/project/charter.md)' "$C")"
check "2h CLAUDE.md carries the branching choice" "yes" "$(has '**Branching:** Trunk' "$C")"
check "2i CLAUDE.md names the tasks" "yes" "$(has 'prefix `MINE`, kept in `tasks/`' "$C")"
check "2j no remote line without a remote" "no" "$(has 'Remote:' "$C")"
check "2k crew line when several sessions" "yes" "$(has 'joins the crew' "$C")"
check "2l nothing approved when no AI" "no" "$(has 'Approved:' "$C")"
check "2m CLAUDE.md stays small" "yes" "$([ "$(wc -l < "$P/CLAUDE.md")" -lt 25 ] && echo yes || echo no)"
check "2n the next step names the first tasks" "yes" "$(has 'agree the charter' "$out")"
W="$P/tasks/_workflow/WORKFLOW.md"
check "2o the task-shaping step names INVEST" "yes" "$(has INVEST "$(stepline "$W" requirements)")"
check "2p architecture names SOLID and DRY" "yes yes" "$(has SOLID "$(stepline "$W" architecture)") $(has DRY "$(stepline "$W" architecture)")"
check "2q implementation and tech-debt name DRY" "yes yes" "$(has DRY "$(stepline "$W" implementation)") $(has duplication "$(stepline "$W" tech-debt)")"
D=$(find "$P/docs" -name _index.md | while read -r f; do sed -n 's/^description: //p' "$f"; done)
check "2r every seeded folder states one purpose: 4 described, 4 distinct, no TODO" "4 4 0" "$(echo "$D" | grep -c .) $(echo "$D" | sort -u | grep -c .) $(echo "$D" | grep -ci todo)"

echo "== re-running =="
i1=$(ino "$P/CLAUDE.md"); i2=$(ino "$P/docs/dev/_index.md")
out=$(sc "$P")
check "3a nothing changes on a re-run" "$i1 $i2" "$(ino "$P/CLAUDE.md") $(ino "$P/docs/dev/_index.md")"
check "3b ... and it says so" "no" "$(has created "$out")"
echo "my note" >> "$P/docs/dev/_index.md"; sc "$P" >/dev/null
check "3c a seeded file is the user's: never overwritten" "my note" "$(tail -1 "$P/docs/dev/_index.md")"
echo "hand edit" >> "$P/CLAUDE.md"; sc "$P" >/dev/null; check "3d an edited CLAUDE.md is refused" "3" "$?"
check "3e ... and kept" "hand edit" "$(tail -1 "$P/CLAUDE.md")"
W="$P/tasks/_workflow/WORKFLOW.md"; echo "11. my-step - The project's own" >> "$W"; w1="$(cksum < "$W")"; sc "$P" >/dev/null
check "3f an existing WORKFLOW.md stays byte-identical" "$w1" "$(cksum < "$W")"

echo "== a client's PoC: tasks outside the repo =="
REG="$HOME/.claude/project-tasks/config.json"
mkdir -p "$(dirname "$REG")"; printf '{\n  "projects": {\n    "/elsewhere": {\n      "tasksDir": "/x",\n      "prefix": "X",\n      "nextId": 7\n    }\n  }\n}\n' > "$REG"
P=$(fresh client)
autofill "$P" A1="Client PoC" A4="A client's" A5="git@example.com:acme/poc.git" C3="Client documents — ingest into \`docs/external/\`" \
    E1="Yes, via an API" E2=OpenAI R3="VPN needed" R7=CPOC R8="One minimal profile" I5=n/a C4=n/a C5="Never — always free to break"
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
check "4k external/ for client documents" "yes" "$(exists "$P/docs/external/_index.md")"
out=$(sc "$P"); check "4l the registry entry is not added twice" "1" "$(grep -cF "\"$P\": {" "$REG")"
CLAUDE_CONFIG_DIR="$HOME/acct-2" bash -c 'true'
P2=$(fresh client2); autofill "$P2" A1=two A4="A client's" A5="No remote yet" R7=TWO E1=No I5=n/a C4=n/a C5="Never — always free to break"
CLAUDE_CONFIG_DIR="$HOME/acct-2" sc "$P2" >/dev/null
check "4m a second account registers in its own registry" "yes no" "$(exists "$HOME/acct-2/project-tasks/config.json") $(grep -qF "\"$P2\"" "$REG" && echo yes || echo no)"

echo "== minimal docs, a game =="
P=$(fresh game); autofill "$P" A1=g A3=Game A4=Mine A5="No remote yet" R7=G E1=No I5=n/a C4=n/a C5="Never — always free to break"
sc "$P" >/dev/null
check "5a a game gets design/" "yes" "$(exists "$P/docs/design/_index.md")"
P=$(fresh minimal); autofill "$P" A1=m A4=Mine A5="No remote yet" R7=M E1=No I5=n/a C4=n/a C5="Never — always free to break" K1="Minimal: \`project/\` only"
sc "$P" >/dev/null
check "5b minimal docs: project/ only" "yes no" "$(exists "$P/docs/project/_index.md") $(exists "$P/docs/dev")"

summary
