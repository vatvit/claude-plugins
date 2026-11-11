#!/usr/bin/env bash
# Run every task suite; prints failures and each suite's tally. Dual-target:
#   bash task/scripts/test/run.sh
#   docker build -t task-test task/scripts/test   # once: bash:5 (Alpine/busybox) + git
#   docker run --rm -v "$PWD":/w -w /w task-test bash task/scripts/test/run.sh
D="$(cd "$(dirname "$0")" && pwd -P)"; rc=0
for t in "$D"/*.test.sh; do
    out="$(bash "$t" 2>&1)" || rc=1
    printf '%s\n' "$out" | grep -v '^  ok ' || true
done
[ "$rc" -eq 0 ] && echo "ALL GREEN" || echo "FAILURES"
exit "$rc"
