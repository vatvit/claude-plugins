#!/usr/bin/env bash
# Tests for list-tasks.sh — the rendering rules /task list used to describe in
# prose and the model executed by hand. Each case pins one documented rule.
#
# Run: bash scripts/test/list-tasks.test.sh   (from the plugin root)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SC="$ROOT/scripts"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0

check() { # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"
    else fail=$((fail+1)); echo "  FAIL $1"; echo "         expected: [$2]"; echo "         actual:   [$3]"; fi
}
contains() { # contains <name> <needle> <haystack>
    case "$3" in *"$2"*) pass=$((pass+1)); echo "  ok   $1" ;;
    *) fail=$((fail+1)); echo "  FAIL $1"; echo "         missing: [$2]"; echo "         in:"; printf '%s\n' "$3" | sed 's/^/           /' ;; esac
}
lacks() { # lacks <name> <needle> <haystack>
    case "$3" in *"$2"*) fail=$((fail+1)); echo "  FAIL $1"; echo "         unexpected: [$2]" ;;
    *) pass=$((pass+1)); echo "  ok   $1" ;; esac
}

D="$TMP/tasks"; mkdir -p "$D"
task() { # task <id> <status> <priority> <epic|-> <type|-> <title>
    { echo '---'
      echo "title: $6"
      echo "status: $2"
      [ "$3" != "-" ] && echo "priority: $3"
      [ "$5" != "-" ] && echo "type: $5"
      [ "$4" != "-" ] && echo "epic: $4"
      echo '---'
      echo
      echo 'body'
    } > "$D/TST-$1.md"
}

# TST-001 is the epic; 002-012 are its sub-tasks; 020+ are untagged.
{ echo '---'; echo 'title: Alpha epic'; echo 'status: in-progress'; echo 'type: epic'
  echo 'epic-name: alpha'; echo 'priority: high'; echo '---'; echo
  echo '## Goal'; echo; echo 'Ship alpha.'; } > "$D/TST-001.md"

task 002 in-progress high   alpha feature "Sub in progress"
task 003 blocked     medium alpha bugfix  "Sub blocked"
task 004 approved    low    alpha feature "Sub approved"
task 005 proposed    high   alpha feature "Sub proposed one"
task 006 proposed    medium alpha feature "Sub proposed two"
task 007 proposed    low    alpha feature "Sub proposed three"
task 008 completed   high   alpha feature "Sub done one"
task 009 completed   low    alpha feature "Sub done two"
task 010 rejected    low    alpha feature "Sub rejected"
task 020 proposed    high   -     feature "Untagged rate limiting"
task 021 proposed    medium -     bugfix  "Untagged dark mode"
task 022 blocked     high   -     feature "Untagged payment flow"

echo "-- flat table --"
out=$(bash "$SC/list-tasks.sh" "$D" TST)
contains "header row"            "ID " "$out"
contains "epic marked [Epic]"    "[Epic]" "$out"
contains "sub-task shows epic id" "TST-001" "$out"
lacks    "completed excluded"     "Sub done one" "$out"
lacks    "rejected excluded"      "Sub rejected" "$out"
check    "flat sorted by id" "TST-001" "$(printf '%s\n' "$out" | sed -n '2p' | awk '{print $1}')"

echo "-- all --"
out=$(bash "$SC/list-tasks.sh" "$D" TST all)
contains "all includes completed" "Sub done one" "$out"
contains "all includes rejected"  "Sub rejected" "$out"

echo "-- filters --"
out=$(bash "$SC/list-tasks.sh" "$D" TST type=bugfix)
contains "type filter keeps bugfix" "Sub blocked" "$out"
lacks    "type filter drops feature" "Sub in progress" "$out"
out=$(bash "$SC/list-tasks.sh" "$D" TST title~untagged)
contains "partial match is case-insensitive" "Untagged dark mode" "$out"
lacks    "partial match excludes others" "Sub blocked" "$out"
out=$(bash "$SC/list-tasks.sh" "$D" TST epic=_)
contains "epic=_ keeps untagged" "Untagged dark mode" "$out"
lacks    "epic=_ drops members" "Sub blocked" "$out"
out=$(bash "$SC/list-tasks.sh" "$D" TST status=completed)
contains "explicit status filter reaches closed tasks" "Sub done one" "$out"

echo "-- epic view (bare id) --"
out=$(bash "$SC/list-tasks.sh" "$D" TST 1)
contains "epic header with counts" "── epic: alpha — 7 open / 10 total ──" "$out"
contains "closed collapsed to a count" "✓ 3 closed (2 completed, 1 rejected) — /task list TST-001 status=completed,rejected" "$out"
contains "epic row first" "TST-001" "$out"
lacks    "closed rows not listed" "Sub done two" "$out"
check    "open sub-tasks are never collapsed" "7" \
  "$(printf '%s\n' "$out" | grep -c '^  TST-')"
check    "open order: in-progress then blocked then approved" "TST-002 TST-003 TST-004" \
  "$(printf '%s\n' "$out" | grep '^  TST-' | sed -n '2,4p' | awk '{print $1}' | tr '\n' ' ' | sed 's/ $//')"
lacks    "bare id stays strict — no untagged group" "no epic" "$out"

echo "-- epic filter (smart ,_ default) --"
out=$(bash "$SC/list-tasks.sh" "$D" TST epic=alpha)
contains "epic= adds the untagged group" "── no epic (3) ──" "$out"
contains "untagged task listed" "Untagged payment flow" "$out"
out=$(bash "$SC/list-tasks.sh" "$D" TST epic=alpha --strict-epic)
lacks "--strict-epic drops the untagged group" "no epic" "$out"

echo "-- grouping and collapsing --"
i=30
while [ $i -lt 48 ]; do task "0$i" proposed medium - feature "Bulk task $i"; i=$((i+1)); done
out=$(bash "$SC/list-tasks.sh" "$D" TST)
contains "auto-grouped past 15 tasks" "── in-progress (2) ──" "$out"
contains "group order puts blocked after in-progress" "── blocked (2) ──" "$out"
contains "large group collapsed" "... and " "$out"
contains "collapse names the drill-down" "(use /task list status=proposed)" "$out"
check    "collapsed group shows five rows" "5" \
  "$(printf '%s\n' "$out" | awk '/── proposed/{f=1;next} /^── /{f=0} f && /TST-/{n++} END{print n+0}')"

echo "-- explicit group and sort --"
out=$(bash "$SC/list-tasks.sh" "$D" TST type=bugfix,feature group=type)
contains "grouped by type" "── feature (" "$out"
contains "grouped by type keeps status column" "blocked" "$out"
out=$(bash "$SC/list-tasks.sh" "$D" TST epic=alpha --strict-epic sort=priority)
check "sort=priority puts critical/high first" "high" \
  "$(printf '%s\n' "$out" | grep '^  TST-002' | awk '{print $3}')"

echo "-- summary --"
out=$(bash "$SC/list-tasks.sh" "$D" TST summary)
contains "summary groups by status" "── in-progress (2) ── " "$out"
contains "summary caps ids at five" " +" "$out"
contains "summary totals open tasks" "Total open: " "$out"
out=$(bash "$SC/list-tasks.sh" "$D" TST summary all)
contains "summary with all totals everything" "Total: " "$out"

echo "-- misc --"
out=$(bash "$SC/list-tasks.sh" "$D" TST type=bugfix --active=TST-003)
contains "active task marked" "* TST-003" "$out"
bash "$SC/list-tasks.sh" "$D" TST 999 >/dev/null 2>&1
check "unknown epic reference fails" "1" "$?"
bash "$SC/list-tasks.sh" "$D" TST 2 >/dev/null 2>&1
check "non-epic id is rejected as an epic reference" "1" "$?"
out=$(bash "$SC/list-tasks.sh" "$D" TST type=nothing-matches)
check "empty result is not an error" "No matching tasks." "$out"

echo
echo "passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
