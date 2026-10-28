#!/usr/bin/env bash
# plan.sh [project-root] [--next | --review] — what to ask now, with the resolved defaults.
#
# Default output: one tab-separated row per question —
#   section  id  state  value  question  options
# state is answered | stale | ask | explicit | judge | skip; value is the answer, or the default to offer
# (for explicit: the recommendation, never accepted as a default — the user picks).
#   --next    only the first section that still has questions to ask (empty: nothing left)
#   --review  a markdown table of every answer, for the review screen
#   --before-docs  as if the charter were not written: the questions the docs depend on, without §N
set -euo pipefail
. "$(dirname "$0")/lib.sh"

root="" mode=all docs=()
for a in "$@"; do
    case "$a" in
        --next) mode=next ;;
        --review) mode=review ;;
        --before-docs) docs=(-v written=0) ;;   # after kickoff_awk's own -v written, so it wins
        -*) echo "plan.sh: unknown option $a" >&2; exit 2 ;;
        *) root="$a" ;;
    esac
done
root="$(project_root "$root")"
kickoff_awk plan.awk "$root" -v mode="$mode" ${docs[@]+"${docs[@]}"}
