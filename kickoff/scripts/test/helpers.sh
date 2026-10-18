#!/usr/bin/env bash
# helpers.sh — shared by kickoff's test suites. Sourced, never executed.
S="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0
# Which plugins count as installed is pinned, never read from the machine running the tests.
# The sibling plugins kickoff can set up are on; a test that needs them off sets KICKOFF_PLUGINS="".
export KICKOFF_PLUGINS="crew task task-roadmap docs-manager"

check() { # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"
    else fail=$((fail+1)); echo "  FAIL $1"; echo "         expected: [$2]"; echo "         actual:   [$3]"; fi
}
has() { case "$2" in *"$1"*) echo yes ;; *) echo no ;; esac; }   # has <needle> <haystack>
fresh() { rm -rf "$TMP/$1"; mkdir -p "$TMP/$1"; echo "$TMP/$1"; }
summary() { echo; echo "passed: $pass  failed: $fail"; [ "$fail" -eq 0 ]; }

# autofill <project> [ID=value ...] — answer the whole questionnaire the way a user accepting every
# default would: each round takes plan.sh --next, records the override for an id if one is given,
# else the offered default, else n/a (free text with no default). An `explicit` question is never
# settled by accepting defaults, so it takes an override or autofill fails. Bounded, so a plan that
# never settles fails the test instead of hanging it.
autofill() {
    local p="$1" rounds=0 rows row id st val o given left n; shift
    while rows="$(bash "$S/plan.sh" "$p" --next)"; [ -n "$rows" ]; do
        rounds=$((rounds + 1)); [ "$rounds" -le 30 ] || { echo "autofill: plan never settles" >&2; return 1; }
        left="" n=0
        # Not `IFS=$'\t' read`: tab is IFS whitespace, so an empty value column would collapse and
        # the question text would be read as the value.
        while IFS= read -r row; do
            id="$(echo "$row" | cut -f2)"; st="$(echo "$row" | cut -f3)"; val="$(echo "$row" | cut -f4)"
            given=0
            for o in "$@"; do case "$o" in "$id="*) val="${o#*=}"; given=1 ;; esac; done
            if [ "$st" = explicit ] && [ "$given" = 0 ]; then left="$left $id"; continue; fi
            bash "$S/answer.sh" --root "$p" "$id" "${val:-n/a}"; n=$((n + 1))
        done <<< "$rows"
        [ "$n" -gt 0 ] || { echo "autofill:$left must be asked explicitly — pass ID=value" >&2; return 1; }
    done
    return 0
}
