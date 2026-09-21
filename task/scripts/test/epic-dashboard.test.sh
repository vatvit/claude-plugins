#!/usr/bin/env bash
# Regression tests for epic-dashboard.sh sub-task extraction.
#
# The bug these exist for: every line of the `## Sub-tasks` section was read as
# a sub-task, so PROSE naming a task made it a member. It failed silently and
# plausibly — a phantom row reads as a sloppy list, not a parser bug — and it
# was found only when an epic reported the same task three times.
#
# Run: bash scripts/test/epic-dashboard.test.sh   (from the plugin root)
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/epic-dashboard.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0

# ids(<epic-file-number>) -> the sub-task ids the dashboard reports, space separated
ids() {
    bash "$SCRIPT" "$TMP" TST "$1" 2>/dev/null \
      | tr ',' '\n' | grep -oE '"id":"TST-[0-9]+"' | cut -d'"' -f4 \
      | tail -n +2 | tr '\n' ' ' | sed 's/ $//'
}

check() { # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"
    else fail=$((fail+1)); echo "  FAIL $1"; echo "         expected: [$2]"; echo "         actual:   [$3]"; fi
}

epic() { # epic <num> <body-of-Sub-tasks-section>
    { printf -- '---\ntitle: "EPIC: t"\nstatus: in-progress\ntype: epic\nepic-name: t\npriority: high\n---\n\n## Goal\n\ng\n\n## Sub-tasks\n\n'
      cat; } > "$TMP/TST-$1.md"
}
sub() { printf -- '---\ntitle: s\nstatus: proposed\ntype: feature\npriority: low\n---\n' > "$TMP/TST-$1.md"; }

for n in 002 003 004 005 006; do sub $n; done

# --- T1: the documented bullet format still works -------------------------
epic 001 <<'EOF'
- TST-002: Registration endpoint
- TST-003: Login / logout
EOF
check "T1 bullet list" "TST-002 TST-003" "$(ids 001)"

# --- T2: the table format still works -------------------------------------
epic 010 <<'EOF'
| Task | Title |
|---|---|
| TST-002 | a |
| TST-003 | b |
EOF
check "T2 table rows" "TST-002 TST-003" "$(ids 010)"

# --- T3: THE BUG. Prose naming a task is not membership --------------------
epic 011 <<'EOF'
- TST-002: a

**TST-003 and TST-004 are resolved** — TST-003's scope shipped under TST-004.
EOF
check "T3 prose is not membership" "TST-002" "$(ids 011)"

# --- T4: prose saying a task is NOT in the epic (found in the wild) --------
epic 012 <<'EOF'
- TST-002: a

TST-005 (other thing) remains a separate epic.
EOF
check "T4 'separate epic' prose excluded" "TST-002" "$(ids 012)"

# --- T5: a subsection heading naming a ticket ------------------------------
epic 013 <<'EOF'
### Security (review findings — TST-006 audit)

- TST-002: a
EOF
check "T5 heading mention excluded" "TST-002" "$(ids 013)"

# --- T6: a wrapped bullet keeps the bullet's id, not the continuation's ----
epic 014 <<'EOF'
- **TST-002** — does a thing that pairs with the older work
  and supersedes TST-005 entirely. *(dep: TST-006)*
EOF
check "T6 continuation line excluded" "TST-002" "$(ids 014)"

# --- T7: an epic naming itself is not its own sub-task ---------------------
epic 015 <<'EOF'
Broken down today (`/task do TST-015` kickoff).

- TST-002: a
EOF
check "T7 self-reference excluded" "TST-002" "$(ids 015)"

# --- T8: one task listed twice is one sub-task -----------------------------
epic 016 <<'EOF'
- TST-002: a
- TST-003: b
- TST-002: a (listed again by mistake)
EOF
check "T8 duplicates collapsed" "TST-002 TST-003" "$(ids 016)"

# --- T9: numbered and indented items count ---------------------------------
epic 017 <<'EOF'
1. TST-002: a
   - TST-003: nested
EOF
check "T9 numbered + indented" "TST-002 TST-003" "$(ids 017)"

# --- T10: the section ends at the next H2 ----------------------------------
epic 018 <<'EOF'
- TST-002: a

## Notes

- TST-006: belongs to another section
EOF
check "T10 section boundary" "TST-002" "$(ids 018)"

# --- T11: an empty section reports nothing, and does not fail --------------
epic 019 <<'EOF'
_(none yet — break down after kickoff, once TST-006 unblocks it)_
EOF
check "T11 empty section" "" "$(ids 019)"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
