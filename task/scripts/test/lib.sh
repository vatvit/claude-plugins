#!/usr/bin/env bash
# Shared by the task plugin's test suites. Source it, don't execute it:
#   . "$(dirname "$0")/lib.sh"
#
# Gives each suite ROOT (the plugin root), SC (its scripts/), a TMP directory
# removed on exit, the pass/fail counters, the assertions below, and report.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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

report() { # report <suite> -> the closing line; the suite's exit status
    echo
    echo "$1: $pass passed, $fail failed"
    [ "$fail" -eq 0 ]
}
