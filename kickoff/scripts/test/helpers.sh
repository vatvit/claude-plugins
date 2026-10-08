#!/usr/bin/env bash
# helpers.sh — shared by kickoff's test suites. Sourced, never executed.
S="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0

check() { # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"
    else fail=$((fail+1)); echo "  FAIL $1"; echo "         expected: [$2]"; echo "         actual:   [$3]"; fi
}
has() { case "$2" in *"$1"*) echo yes ;; *) echo no ;; esac; }   # has <needle> <haystack>
fresh() { rm -rf "$TMP/$1"; mkdir -p "$TMP/$1"; echo "$TMP/$1"; }
summary() { echo; echo "passed: $pass  failed: $fail"; [ "$fail" -eq 0 ]; }

# autofill <project> [ID=value ...] — answer the whole questionnaire the way a user accepting every
# default would: each round takes plan.sh --next, records the override for an id if one is given,
# else the offered default, else n/a (free text with no default). Bounded, so a plan that never
# settles fails the test instead of hanging it.
autofill() {
    local p="$1" rounds=0 rows id val o; shift
    while rows="$(bash "$S/plan.sh" "$p" --next)"; [ -n "$rows" ]; do
        rounds=$((rounds + 1)); [ "$rounds" -le 30 ] || { echo "autofill: plan never settles" >&2; return 1; }
        while IFS=$'\t' read -r _ id _ val _; do
            for o in "$@"; do case "$o" in "$id="*) val="${o#*=}" ;; esac; done
            bash "$S/answer.sh" --root "$p" "$id" "${val:-n/a}"
        done <<< "$rows"
    done
}
