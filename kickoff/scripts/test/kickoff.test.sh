#!/usr/bin/env bash
# Tests for kickoff: the questionnaire model (plan), recording answers, and the charter.
#
# Dual-target, like the other plugins: the host (macOS bash 3.2 + BSD userland) and a bash:5
# container (busybox awk — byte-oriented, which is what catches multibyte slips like ★ and §).
#
#   bash kickoff/scripts/test/kickoff.test.sh
#   docker run --rm -v "$PWD":/w -w /w bash:5 bash kickoff/scripts/test/kickoff.test.sh
set -uo pipefail

S="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0

check() { # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"
    else fail=$((fail+1)); echo "  FAIL $1"; echo "         expected: [$2]"; echo "         actual:   [$3]"; fi
}
has() { case "$2" in *"$1"*) echo yes ;; *) echo no ;; esac; }   # has <needle> <haystack>

fresh() { rm -rf "$TMP/$1"; mkdir -p "$TMP/$1"; echo "$TMP/$1"; }
a() { bash "$S/answer.sh" --root "$P" "$@"; }                   # record an answer in $P
field() { bash "$S/plan.sh" "$P" | awk -F'\t' -v id="$1" -v f="$2" '$2 == id { print $f }'; }
state() { field "$1" 3; }
value() { field "$1" 4; }

echo "== plan: branching and defaults =="

P=$(fresh empty)
check "1a every question is listed" "46" "$(bash "$S/plan.sh" "$P" | wc -l | tr -d ' ')"
check "1b A0 is asked first" "ask" "$(state A0)"
check "1c a question on an unanswered one waits (B6 on B5)" "pending" "$(state B6)"
check "1d PoC-only questions wait for A3" "pending" "$(state X1)"
check "1e prose condition is a judgement (I5)" "judge" "$(state I5)"
check "1f --next is section A only" "A" "$(bash "$S/plan.sh" "$P" --next | cut -f1 | sort -u | tr -d '\n')"
check "1g plain default resolved, markers stripped" "PoC / experiment" "$(value A3)"
check "1h options shown without markers" "no" "$(has '★' "$(bash "$S/plan.sh" "$P")")"

P=$(fresh poc); a A3 "PoC / experiment"
check "2a A3 = PoC opens X1" "ask" "$(state X1)"
check "2b conditional default applies (C1)" "Minimal code, simplest UI, but functional end to end" "$(value C1)"
check "2c conditional default applies (B1)" '"Try to solve the problem for real, and show a valuable result"' "$(value B1)"
check "2d R1 keeps the plain default" "Trunk — one branch, no feature branches" "$(value R1)"

P=$(fresh lib); a A3 "Library / plugin / tool"
check "3a A3 = Library skips X1" "skip" "$(state X1)"
check "3b A3 ≠ Library skips D1" "skip" "$(state D1)"
check "3c conditional default overrides the plain one (R1)" "GitFlow" "$(value R1)"
check "3d no PoC default for a library (C1)" "" "$(value C1)"
check "3e 'or' with a prose part becomes a judgement (R4)" "judge" "$(state R4)"
P=$(fresh game); a A3 Game
check "3f 'or' with a true formal part is asked (R4)" "ask" "$(state R4)"

P=$(fresh mine); a A4 Mine
check "4a own project keeps tasks in the repo" 'In the repo, `tasks/`' "$(value R6)"
P=$(fresh client); a A4 "A client's"
check "4b client project moves tasks out" "Outside the repo" "$(value R6)"
a B2 Me
check "4c ≠ is false on a match (B4 when B2 = Me)" "skip" "$(state B4)"
a B2 "The client's stakeholders"
check "4d ≠ is true otherwise" "ask" "$(state B4)"
check "4e prefix match ignores case (B2 = me)" "skip" "$(a B2 me; state B4)"
a B5 "Good enough — exploring"
check "4f answered condition is false while B6 is skipped (F2)" "skip" "$(state F2)"
a B5 "High for the core result, simplest that works elsewhere"; a B6 "The AI output"
check "4g 'answered' condition holds" "ask" "$(state F2)"

P=$(fresh stale); a A3 "PoC / experiment"; a X1 "None — one demo user"
check "5a an answer shows as answered" "answered" "$(state X1)"
check "5b answered rows carry the answer" "None — one demo user" "$(value X1)"
a A3 Game
check "5c an answer whose question no longer applies is stale" "stale" "$(state X1)"
check "5d review marks it" "yes" "$(has 'no longer applies' "$(bash "$S/plan.sh" "$P" --review)")"
check "5e --next never offers answered questions" "no" "$(has $'\tA3\t' "$(bash "$S/plan.sh" "$P" --next)")"

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

echo "== charter.sh =="

P=$(fresh none)
bash "$S/charter.sh" "$P" >/dev/null 2>&1; check "7a no answers is an error" "1" "$?"

P=$(fresh ch)
a A1 demo; a A2 "A demo project"; a A3 "PoC / experiment"; a B1 "Prove it"; a C2 "Hosting"; a C2 --add "Email"
a I3 "Not decided yet"; a I2 "One | container"; a I2.why "Keeps scope small"
out=$(bash "$S/charter.sh" "$P"); check "7b first run creates" "created" "$out"
C="$P/docs/project/charter.md"
check "7c title from A1" "yes" "$(has '# demo — charter' "$(cat "$C")")"
check "7d a section heading is exact (no half characters)" "## Goal" "$(grep '^## Goal' "$C")"
check "7e a list answer becomes bullets" "2" "$(sed -n '/^## Non-goals/,/^## /p' "$C" | grep -c '^- ')"
check "7f undecided goes to Open questions" "yes" "$(sed -n '/^## Open questions/,$p' "$C" | grep -q 'Storage?' && echo yes || echo no)"
check "7g undecided is not a decision" "no" "$(sed -n '/^## Decisions/,/^## Open/p' "$C" | grep -q 'Storage?' && echo yes || echo no)"
check "7h pipes are escaped in the table, why is carried" '| D1 | **Infra shape?** One \| container | Keeps scope small |' "$(grep '^| D1 ' "$C")"
check "7i overview carries A3" "yes" "$(has '**Kind of project?** PoC / experiment' "$(cat "$C")")"
check "7j frontmatter for docs-manager" "title: Charter" "$(sed -n 2p "$C")"
check "7k re-run with the same answers changes nothing" "unchanged" "$(bash "$S/charter.sh" "$P")"
echo "hand edit" >> "$C"
bash "$S/charter.sh" "$P" >/dev/null; check "7l a hand-edited charter is refused" "3" "$?"
check "7m --force overwrites" "updated" "$(bash "$S/charter.sh" "$P" --force)"
a A3 Game; a X1 "None — one demo user"; bash "$S/charter.sh" "$P" --force >/dev/null
check "7n stale answers stay out" "no" "$(grep -q 'Login?' "$C" && echo yes || echo no)"

a I5 n/a
check "7o n/a counts as answered" "answered" "$(state I5)"
a C4 n/a; bash "$S/charter.sh" "$P" --force >/dev/null
check "7p n/a is not written to the charter" "no" "$(grep -q "n/a" "$C" && echo yes || echo no)"

echo "== replay: the sample-poc kickoff =="
# sample-poc's charter, decisions D2–D5 and D7 (D1, laptop + Docker, is a global rule and never asked).
P=$(fresh sample)
a A1 sample-poc; a A2 "A PoC for Acme: solve process problems with wide use of AI"; a A3 "PoC / experiment"
a A4 "A client's"; a B2 "The client's stakeholders"; a B5 "High for the core result, simplest that works elsewhere"
a B6 "What the LLM, model or algorithm produces: accuracy, citations, no invented facts"
a I1 "The client's own hosting, or a cloud (AWS / Azure)"; a I2 "One container, one monolith"
a E1 "Yes, via an API"; a E2 "OpenAI"; a E2.why "Same API as Azure OpenAI, so moving to Azure later is easy"
D=$(bash "$S/charter.sh" "$P" --stdout | sed -n '/^## Decisions/,/^## Open/p')
check "8a D2 hosting later"   "yes" "$(has "The client's own hosting, or a cloud" "$D")"
check "8b D3 simplified infra" "yes" "$(has "One container, one monolith" "$D")"
check "8c D4 external AI"      "yes" "$(has "**Uses an AI model?** Yes, via an API" "$(bash "$S/charter.sh" "$P" --stdout)")"
check "8d D5 quality bar"      "yes" "$(has "High for the core result" "$D")"
check "8e D7 provider + why"   "yes" "$(has "OpenAI | Same API as Azure OpenAI" "$D")"

echo
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]
