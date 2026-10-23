#!/usr/bin/env bash
# Tests for epic-dashboard.sh: membership, work order, recommendation.
#
# Membership is the sub-task's `epic:` field and nothing else (PLUG-077). An
# epic used to list its sub-tasks in `## Sub-tasks` as well — the same fact
# stored twice, kept in step by hand, and read by the dashboard while
# `/task list` read the field, so the two views of one epic could disagree.
# Such a section is now prose: an id listed there is not a member (T3).
#
# Run: bash scripts/test/epic-dashboard.test.sh   (from the plugin root)
set -uo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/epic-dashboard.sh"

# json <epic-ref> -> the dashboard's raw output
json() { bash "$SCRIPT" "$TMP" TST "$1" 2>/dev/null; }

# ids <epic-ref> -> the sub-task ids reported, space separated
ids() {
    json "$1" | sed 's/.*"subtasks":\[//; s/\].*//' \
      | grep -oE '"id":"TST-[0-9]+"' | cut -d'"' -f4 | tr '\n' ' ' | sed 's/ $//'
}
# queue <epic-ref> -> the work queue, space separated
queue() {
    json "$1" | grep -oE '"queue":\[[^]]*\]' | grep -oE 'TST-[0-9]+' | tr '\n' ' ' | sed 's/ $//'
}
field() { json "$1" | grep -oE "\"$2\":\"[^\"]*\"" | cut -d'"' -f4; }

epic() { # epic <num> <epic-name>   (stdin: extra body)
    { printf -- '---\ntitle: "E %s"\nstatus: in-progress\ntype: epic\nepic-name: %s\npriority: high\n---\n\n## Goal\n\ng\n\n' "$2" "$2"
      cat; } > "$TMP/TST-$1.md"
}
sub() { # sub <num> <epic-name|-> <status> <priority>
    { printf -- '---\ntitle: s%s\nstatus: %s\ntype: feature\n' "$1" "$3"
      [ "$2" = "-" ] || printf 'epic: %s\n' "$2"
      printf 'priority: %s\n---\n' "$4"; } > "$TMP/TST-$1.md"
}

# --- T1: members come from the `epic:` field, no section needed ------------
epic 001 alpha </dev/null
sub 002 alpha proposed low
sub 003 alpha proposed low
sub 004 alpha proposed low
sub 005 beta  proposed low
sub 006 -     proposed low
check "T1 epic: field is membership" "TST-002 TST-003 TST-004" "$(ids 001)"

# --- T2: an epic-name resolves to the same epic as its id ------------------
check "T2 epic-name == id" "$(json 001)" "$(json alpha)"

# --- T3: a `## Sub-tasks` list is prose now, not membership -----------------
epic 010 gamma <<'EOF'
## Sub-tasks

- TST-006: listed, but has no epic: field
- TST-011: listed and tagged
EOF
sub 011 gamma proposed low
check "T3 listed-only task is not a member" "TST-011" "$(ids 010)"

# --- T4: closed sub-tasks are members, never queued ------------------------
epic 020 delta </dev/null
sub 021 delta completed high
sub 022 delta rejected  high
sub 023 delta proposed  low
check "T4a closed tasks listed, last" "TST-023 TST-021 TST-022" "$(ids 020)"
check "T4b closed tasks not queued"   "TST-023" "$(queue 020)"

# --- T5: work order: in-progress, approved, proposed; then priority, id ----
epic 030 eps </dev/null
sub 031 eps proposed    critical
sub 032 eps approved    low
sub 033 eps in-progress low
sub 034 eps approved    high
sub 035 eps proposed    high
sub 036 eps proposed    high
sub 037 eps blocked     critical
check "T5a queue order, blocked left out" "TST-033 TST-034 TST-032 TST-031 TST-035 TST-036" "$(queue 030)"
check "T5b recommend = queue head" "TST-033" "$(field 030 recommend)"
check "T5c recommend_reason" "in-progress" "$(field 030 recommend_reason)"

# --- T6: only blocked left: recommend it, queue empty ---------------------
epic 040 zeta </dev/null
sub 041 zeta blocked   low
sub 042 zeta blocked   high
sub 043 zeta completed low
check "T6a empty queue" "" "$(queue 040)"
check "T6b blocked recommended" "TST-042 blocked" "$(field 040 recommend) $(field 040 recommend_reason)"

# --- T7: everything closed -> all-done --------------------------------------
epic 050 eta </dev/null
sub 051 eta completed low
sub 052 eta rejected  low
check "T7 all-done" "all-done" "$(field 050 recommend_reason)"

# --- T8: no sub-tasks -> empty list, no recommendation, exit 0 --------------
epic 060 theta </dev/null
out=$(bash "$SCRIPT" "$TMP" TST 060 2>/dev/null); rc=$?
check "T8a exit 0" "0" "$rc"
check "T8b empty subtasks, no reason" '"subtasks":[] ' "$(printf '%s' "$out" | grep -oE '"subtasks":\[\]') $(field 060 recommend_reason)"

# --- T9: a non-epic or an unknown name is refused --------------------------
bash "$SCRIPT" "$TMP" TST 002 >/dev/null 2>&1; check "T9a non-epic id exits 1" "1" "$?"
bash "$SCRIPT" "$TMP" TST nope >/dev/null 2>&1; check "T9b unknown name exits 1" "1" "$?"

# --- T10: a missing status counts as proposed ------------------------------
epic 070 iota </dev/null
printf -- '---\ntitle: nostatus\nepic: iota\n---\n' > "$TMP/TST-071.md"
check "T10 missing status = proposed" "TST-071 proposed" "$(queue 070) $(field 070 recommend_reason)"

# --- T11: ids order numerically, not lexically -----------------------------
epic 080 kappa </dev/null
sub 099  kappa proposed low
sub 1000 kappa proposed low
check "T11 numeric id order" "TST-099 TST-1000" "$(queue 080)"

# --- T12: quotes and backslashes in titles stay valid JSON -----------------
epic 090 lam </dev/null
printf -- '---\ntitle: a "q" b\\c\nstatus: proposed\nepic: lam\n---\n' > "$TMP/TST-091.md"
check "T12 escaped title" '"title":"a \"q\" b\\c"' "$(json 090 | grep -oE '"title":"a [^,]*"' | tail -1)"

# --- T13: resolve-task.sh takes an epic-name too, so do/finish need one call -
RT="$(dirname "$SCRIPT")/resolve-task.sh"
check "T13a resolve-task by epic-name" "id=TST-001" "$(bash "$RT" "$TMP" TST alpha 2>/dev/null | head -1)"
bash "$RT" "$TMP" TST nope >/dev/null 2>&1; check "T13b unknown name exits 1" "1" "$?"
err=$(bash "$RT" "$TMP" TST nope 2>&1 >/dev/null)
check "T13c unknown name says so" "yes" \
  "$(echo "$err" | grep -q "No epic found with name 'nope'" && echo yes)"

report epic-dashboard
