#!/usr/bin/env bash
# all.sh — run every kickoff test suite; non-zero if any fails.
rc=0
for t in "$(dirname "$0")"/*.test.sh; do echo "### $(basename "$t")"; bash "$t" || rc=1; done
exit $rc
