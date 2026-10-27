#!/usr/bin/env bash
# Tests for kickoff: the questionnaire model (plan), recording answers, and the charter.
#
# Dual-target, like the other plugins: the host (macOS bash 3.2 + BSD userland) and a bash:5
# container (busybox awk — byte-oriented, which is what catches multibyte slips like ★ and §).
#
#   bash kickoff/scripts/test/kickoff.test.sh
#   docker run --rm -v "$PWD":/w -w /w bash:5 bash kickoff/scripts/test/kickoff.test.sh
set -uo pipefail

. "$(dirname "$0")/helpers.sh"
a() { bash "$S/answer.sh" --root "$P" "$@"; }                   # record an answer in $P
field() { bash "$S/plan.sh" "$P" | awk -F'\t' -v id="$1" -v f="$2" '$2 == id { print $f }'; }
state() { field "$1" 3; }
value() { field "$1" 4; }

echo "== plan: branching and defaults =="

P=$(fresh empty)
check "1a every question is listed" "59" "$(bash "$S/plan.sh" "$P" | wc -l | tr -d ' ')"
check "1b A0 is asked first" "ask" "$(state A0)"
check "1c a question on an unanswered one waits (B6 on B5)" "pending" "$(state B6)"
check "1d PoC-only questions wait for A3" "pending" "$(state X1)"
check "1e prose condition is a judgement (I6)" "judge" "$(state I6)"
check "1f --next is section A only" "A" "$(bash "$S/plan.sh" "$P" --next | cut -f1 | sort -u | tr -d '\n')"
check "1g plain default resolved, markers stripped" "PoC / experiment" "$(value A3)"
check "1h options shown without markers" "no" "$(has '★' "$(bash "$S/plan.sh" "$P")")"
# A question whose (★ if …) default depends on an unanswered one waits, even inside its section:
# asked on the same screen as A4, A6 was offered against an empty A4 and recommended the wrong option.
check "1i a default on an unanswered question waits (A6 on A4)" "pending" "$(state A6)"
check "1j ... and is not offered by --next" "no" "$(has $'\tA6\t' "$(bash "$S/plan.sh" "$P" --next)")"
a A4 "A client's"
check "1k once A4 is answered, A6 is asked with the default it implies" "ask Yes — use only the project owner's identity" "$(state A6) $(value A6)"
a A4 Mine
check "1l ... and follows a changed A4" "No" "$(value A6)"

P=$(fresh poc); a A3 "PoC / experiment"
check "2a A3 = PoC with a prose part makes X1 a judgement" "judge" "$(state X1)"
check "2b conditional default applies (C1)" "Minimal, but functional end to end" "$(value C1)"
check "2c a proposed option is never a default (B1)" "" "$(value B1)"
check "2d R1 keeps the plain default" "Trunk — one branch, no feature branches" "$(value R1)"

P=$(fresh lib); a A3 "Library / plugin / tool"
check "3a A3 = Library: a false part makes an 'and' false (X1)" "skip" "$(state X1)"
check "3b A3 ≠ Library skips I2" "skip" "$(state I2)"
check "3c conditional default overrides the plain one (R1)" "GitFlow" "$(value R1)"
check "3d the plain default where no condition holds (C1)" "Production-grade from the start" "$(value C1)"
check "3e 'or' with a prose part becomes a judgement (R4)" "judge" "$(state R4)"
P=$(fresh product); a A3 "Product / app / service"
check "3f 'or' with a true formal part is asked (R4)" "ask" "$(state R4)"

P=$(fresh mine); a A4 Mine
check "4a own project keeps tasks in the repo" 'In the repo, `tasks/`' "$(value R7)"
P=$(fresh client); a A4 "A client's"
check "4b client project moves tasks out" "Outside the repo" "$(value R7)"
a R6 None
check "4c 'and': no task files, no task file questions (R7)" "skip" "$(state R7)"
a R6 "Markdown task files (task plugin)"
check "4d 'and': both parts hold (R7)" "ask" "$(state R7)"
check "4e installed: crew is asked about (R5)" "ask" "$(state R5)"
check "4f not installed: crew is not (R5)" "skip" "$(KICKOFF_PLUGINS="" state R5)"
check "4g not installed: task files are not set up (R7)" "skip" "$(KICKOFF_PLUGINS="" state R7)"
P=$(fresh notask)
check "4h without the task plugin, tracking defaults to None (R6)" "None" "$(KICKOFF_PLUGINS="" value R6)"
check "4i with it, to markdown task files (R6)" "Markdown task files (task plugin)" "$(value R6)"
a B5 "Good enough — exploring"
check "4j answered condition is false while B6 is skipped (F11)" "skip" "$(state F11)"
a B5 "High for the core result, simplest that works elsewhere"; a B6 "The search results"
check "4k 'answered' condition holds" "ask" "$(state F11)"

P=$(fresh has); a F1 "Standard — Basic + integration tests"
check "4l 'has' waits while the multi-select is still to ask (F8 on F2)" "pending" "$(state F8)"
a F2 "Unit"; a F2 --add "E2E success path"
check "4m 'has' is false when no value matches" "skip" "$(state F8)"
a F2 --add "Integration / functional"
check "4n 'has' holds when any value matches, not just the first" "ask" "$(state F8)"
a F1 "None — no automated checks yet"
check "4o 'and' is false on a false part while the other is pending (F12)" "skip" "$(state F12)"

# The E2E viewer is optional (PLUG-087): asked only with E2E tests, and whether they run in a browser is a judgement.
P=$(fresh viewer); a F1 "Basic"; a F2 "Unit"; a F2 --add "E2E success path"
check "4p the E2E viewer is a judgement when the tests include E2E (F13)" "judge" "$(state F13)"
check "4q ... and defaults to No" "No" "$(value F13)"
a F2 "Unit"
check "4r without E2E tests it is not asked (F13)" "skip" "$(state F13)"
a F1 "None — no automated checks yet"
check "4s level None does not ask it (F13)" "skip" "$(state F13)"

# Without the override, the installed plugins come from Claude Code's own record: user scope counts
# everywhere, local and project scope only in their own project.
P=$(fresh installed); CFG="$TMP/cfg"; mkdir -p "$CFG/plugins"
entry() { printf '    "%s@market": [\n      {\n        "scope": "%s",\n        "projectPath": "%s",\n        "version": "1.0.0"\n      }\n    ]%s\n' "$@"; }
{ printf '{\n  "version": 2,\n  "plugins": {\n'
  entry crew user /anywhere ","; entry task local "$P" ","; entry task-roadmap project /another/project ""
  printf '  }\n}\n'; } > "$CFG/plugins/installed_plugins.json"
pstate() { (unset KICKOFF_PLUGINS; CLAUDE_CONFIG_DIR="$CFG" state "$1"); }
check "4p user scope is installed everywhere (crew)" "ask" "$(pstate R5)"
a A4 Mine; a R6 "Markdown task files (task plugin)"
check "4q local scope in this project is installed (task)" "ask" "$(pstate R7)"
check "4r another project's install is not (task-roadmap)" "skip" "$(pstate R11)"
check "4s no record at all: nothing is installed" "skip" "$(unset KICKOFF_PLUGINS; CLAUDE_CONFIG_DIR="$TMP/nowhere" state R5)"

P=$(fresh stale); a A3 "PoC / experiment"; a X1 "None — one demo user"
check "5a an answer shows as answered" "answered" "$(state X1)"
check "5b answered rows carry the answer" "None — one demo user" "$(value X1)"
a A3 "Product / app / service"
check "5c an answer whose question no longer applies is stale" "stale" "$(state X1)"
check "5d review marks it" "yes" "$(has 'no longer applies' "$(bash "$S/plan.sh" "$P" --review)")"
check "5e --next never offers answered questions" "no" "$(has $'\tA3\t' "$(bash "$S/plan.sh" "$P" --next)")"
a C2 "OUT OF SCOPE — a UI"; a C2 --add "OUT OF SCOPE — serving in production"
check "5f review lists every value of a multi-select" "yes" "$(has 'a UI; OUT OF SCOPE — serving' "$(bash "$S/plan.sh" "$P" --review)")"

echo "== C5 and F1: always asked explicitly =="
# A question with a real trade-off is one a user must pick themselves: accepting a section's
# defaults never settles it.
claude_md() { (. "$S/lib.sh"; kickoff_awk claude.awk "$P" -v tasks=""); }
for kind in "PoC / experiment|Not needed yet" "Library / plugin / tool|From the start" "Product / app / service|Later" "Internal tool / automation|Later"; do
    P=$(fresh c5kind); a A3 "${kind%%|*}"; v="$(value C5)"
    check "9a C5 is explicit for ${kind%%|*}" "explicit" "$(state C5)"
    check "9b ... and recommends what A3 implies" "${kind#*|}" "${v%% —*}"
done
P=$(fresh c5next)
autofill "$P" A1=x A4=Mine A5="No remote yet" R8=X D3=English K2=English I6=n/a 2>/dev/null; rc=$?
check "9c accepting every default never answers C5" "1 0" "$rc $(grep -c '^C5: ' "$P/.kickoff-answers")"
check "9d --next then offers C5 alone, still to ask" "C	C5	explicit" "$(bash "$S/plan.sh" "$P" --next | cut -f1-3)"
a C5 "Never — always free to break"
autofill "$P" A1=x A4=Mine A5="No remote yet" R8=X D3=English K2=English I6=n/a 2>/dev/null; rc=$?
check "9j nor F1: --next stops at it" "1 F	F1	explicit" "$rc $(bash "$S/plan.sh" "$P" --next | cut -f1-3)"
P=$(fresh c5answers)
for pair in "Not needed yet|no shims" "Never|no shims" "From the start|deprecate before removing" "Later — from the first client|free to break until the first client"; do
    a C5 "${pair%%|*}"
    check "9e CLAUDE.md turns '${pair%%|*}' into an instruction" "yes" "$(has "${pair#*|}" "$(claude_md | grep '^- \*\*Backward compatibility:\*\*')")"
done
a C5.why "The first client integrates against the API"
CH="$(bash "$S/charter.sh" "$P" --stdout)"
check "9f the charter records the decision with its why" "yes" "$(has "Later — from the first client | The first client integrates against the API |" "$(echo "$CH" | sed -n '/^## Decisions/,/^## Open/p')")"
check "9g a later answer is revisited: an open question names the trigger" "yes" "$(has "the first client" "$(echo "$CH" | sed -n '/^## Open questions/,$p')")"
a C5 "From the start"
check "9h other answers add no open question" "no" "$(has "From the start" "$(bash "$S/charter.sh" "$P" --stdout | sed -n '/^## Open questions/,$p')")"
a C5 "Not decided yet"
check "9i not decided yet goes to Open questions, no CLAUDE.md line" "yes no" "$(has "Not decided yet" "$(bash "$S/charter.sh" "$P" --stdout | sed -n '/^## Open questions/,$p')") $(has 'Backward compatibility' "$(claude_md)")"

echo "== answer.sh =="

P=$(fresh ans)
a C2 "Production hosting"; a C2 "Real email"
check "6a a plain answer replaces" "1" "$(grep -c '^C2: ' "$P/.kickoff-answers")"
a C2 --add "Real payments"
check "6b --add keeps both" "2" "$(grep -c '^C2: ' "$P/.kickoff-answers")"
a C2 "Only this"
check "6c replacing a list leaves one value" "C2: Only this" "$(grep '^C2: ' "$P/.kickoff-answers")"
a --clear C2
check "6d --clear removes it" "0" "$(grep -c '^C2: ' "$P/.kickoff-answers")"
a B5.why 'Back\slash and "quotes" & | pipes'
check "6e a value is stored literally" 'B5.why: Back\slash and "quotes" & | pipes' "$(grep '^B5.why: ' "$P/.kickoff-answers")"
a Z9 x 2>/dev/null; check "6f an unknown id is refused" "2" "$?"
a A1 $'two\nlines' 2>/dev/null; check "6g a multi-line value is refused" "2" "$?"
a A1 same; ino1=$(ls -i "$P/.kickoff-answers" | awk '{print $1}')
a A1 same; ino2=$(ls -i "$P/.kickoff-answers" | awk '{print $1}')
check "6h recording the same answer never rewrites the file" "$ino1" "$ino2"

# A computed default (*italics* in the questionnaire) describes how to work the value out; it is never
# an answer itself. A live run recorded the task prefix as "3–5 letters derived from A1".
P=$(fresh computed)
check "6i the plan marks a computed default (R8)" "yes" "$(has '*' "$(value R8)")"
check "6j …and only computed ones (A3)" "no" "$(has '*' "$(value A3)")"
for id in A1 A4 A5 I6 R8 K2; do
    d="$(value "$id")"; plain="${d#\*}"; plain="${plain%\*}"
    a "$id" "$d" 2>/dev/null; r1=$?; a "$id" "$plain" 2>/dev/null; r2=$?
    check "6k $id: its computed default is refused, marked or not" "2 2 0" "$r1 $r2 $([ -f "$P/.kickoff-answers" ] && grep -c "^$id: " "$P/.kickoff-answers" || echo 0)"
done
check "6l the refusal says what to do" "yes" "$(has "work it out" "$(a R8 "$(value R8)" 2>&1)")"
a R8 DEMO; check "6m a worked-out value is recorded" "R8: DEMO" "$(grep '^R8: ' "$P/.kickoff-answers")"
a B1 "*Claude proposes one sentence from A2 and A3*" 2>/dev/null; r1=$?
a D2 "Claude proposes 2–3 ways fitting A2" 2>/dev/null; r2=$?
check "6n a proposed option is refused too, an example after it or not" "2 2" "$r1 $r2"

echo "== charter.sh =="

P=$(fresh none)
bash "$S/charter.sh" "$P" >/dev/null 2>&1; check "7a no answers is an error" "1" "$?"

P=$(fresh ch)
a A1 demo; a A2 "A demo project"; a A3 "PoC / experiment"; a B1 "Prove it"; a C2 "Hosting"; a C2 --add "Email"
a I3 "Not decided yet"; a I2 "One | deployable"; a I2.why "Keeps scope small"
out=$(bash "$S/charter.sh" "$P"); check "7b first run creates" "created" "$out"
C="$P/docs/project/charter.md"
check "7c title from A1" "yes" "$(has '# demo — charter' "$(cat "$C")")"
check "7d a section heading is exact (no half characters)" "## Goal" "$(grep '^## Goal' "$C")"
check "7e a list answer becomes bullets" "2" "$(sed -n '/^## Non-goals/,/^## /p' "$C" | grep -c '^- ')"
check "7f undecided goes to Open questions" "yes" "$(sed -n '/^## Open questions/,$p' "$C" | grep -q 'State it keeps?' && echo yes || echo no)"
check "7g undecided is not a decision" "no" "$(sed -n '/^## Decisions/,/^## Open/p' "$C" | grep -q 'State it keeps?' && echo yes || echo no)"
check "7h pipes are escaped in the table, why is carried" '| D1 | **Infra shape?** One \| deployable | Keeps scope small |' "$(grep '^| D1 ' "$C")"
check "7i overview carries A3" "yes" "$(has '**Kind of project?** PoC / experiment' "$(cat "$C")")"
check "7j frontmatter for docs-manager" "title: Charter" "$(sed -n 2p "$C")"
check "7k re-run with the same answers changes nothing" "unchanged" "$(bash "$S/charter.sh" "$P")"
echo "hand edit" >> "$C"
bash "$S/charter.sh" "$P" >/dev/null; check "7l a hand-edited charter is refused" "3" "$?"
check "7m --force overwrites" "updated" "$(bash "$S/charter.sh" "$P" --force)"
a A3 "Product / app / service"; a X1 "None — one demo user"; bash "$S/charter.sh" "$P" --force >/dev/null
check "7n stale answers stay out" "no" "$(grep -q 'Login?' "$C" && echo yes || echo no)"

a I6 n/a
check "7o n/a counts as answered" "answered" "$(state I6)"
a C4 n/a; bash "$S/charter.sh" "$P" --force >/dev/null
check "7p n/a is not written to the charter" "no" "$(grep -q "n/a" "$C" && echo yes || echo no)"
check "7q quality-only answers stay out of the charter" "no" "$(a F1 'Basic'; a F3 'Linter / static analysis'; bash "$S/charter.sh" "$P" --stdout | grep -q 'Linter' && echo yes || echo no)"

echo "== replay: a client PoC calling an AI service =="
P=$(fresh replay)
a A1 acme-poc; a A2 "A PoC for Acme: solve process problems with wide use of AI"; a A3 "PoC / experiment"
a A4 "A client's"; a B5 "High for the core result, simplest that works elsewhere"
a B6 "What the model produces: accuracy, citations, no invented facts"
a E1 "USES — an LLM API"; a E2 "OpenAI"; a E2.why "Same API as Azure OpenAI, so moving to Azure later is easy"
a I1 "The client's own hosting"; a I2 "One deployable"
D=$(bash "$S/charter.sh" "$P" --stdout | sed -n '/^## Decisions/,/^## Open/p')
check "8a hosting later"   "yes" "$(has "The client's own hosting" "$D")"
check "8b infra shape"     "yes" "$(has "One deployable" "$D")"
check "8c external service" "yes" "$(has "USES — an LLM API" "$D")"
check "8d quality bar"     "yes" "$(has "High for the core result" "$D")"
check "8e provider + why"  "yes" "$(has "OpenAI | Same API as Azure OpenAI" "$D")"


echo "== references =="
# Every reference SKILL.md links must exist: the skill reads them on demand, so a dangling link fails silently.
R="$S/../skills/kickoff"
missing=$(grep -o '(references/[a-z0-9-]*\.md)' "$R/SKILL.md" | tr -d '()' | sort -u | while read -r f; do [ -f "$R/$f" ] || echo "$f"; done)
check "10a every reference SKILL.md links exists" "" "$missing"
check "10b the E2E viewer guide is one of them" "yes" "$(has 'references/e2e-viewer.md' "$(cat "$R/SKILL.md")")"

summary
