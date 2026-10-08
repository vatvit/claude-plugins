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
