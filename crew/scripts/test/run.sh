#!/usr/bin/env bash
# Run every crew suite; prints failures and each suite's tally. Dual-target:
#   bash crew/scripts/test/run.sh
#   docker build -t crew-test crew/scripts/test   # once: bash:5 (Alpine/busybox) + git
#   docker run --rm -v "$PWD":/w -w /w crew-test bash crew/scripts/test/run.sh
D="$(cd "$(dirname "$0")" && pwd -P)"; rc=0
for t in "$D"/*.test.sh; do
    out="$(bash "$t" 2>&1)" || rc=1
    printf '%s\n' "$out" | grep -v '^  ok ' || true
done
[ "$rc" -eq 0 ] && echo "ALL GREEN" || echo "FAILURES"
exit "$rc"
