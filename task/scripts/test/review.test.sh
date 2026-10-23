#!/usr/bin/env bash
# Tests for reviewing a backlog for a tag (PLUG-082): the digest listing,
# tags.sh candidates with its keyword search and epic hints.
#
# Run: bash scripts/test/review.test.sh   (from the plugin root)
set -uo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

D="$TMP/tasks"; mkdir -p "$D"

# filler <n> -> n lines of prose, the bulk a real task carries below its summary
filler() { i=0; while [ "$i" -lt "$1" ]; do
    echo "Notes line $i: what was tried, which file changed and why, and what the next session should know."
    i=$((i+1)); done; }
workflow() { echo '## Workflow'; echo; echo '| # | Step | Status | Notes |'; echo '|---|------|--------|-------|'
    for s in Context Requirements Assessment POC Domain Architecture Tests Subtasks Implementation; do
        echo "| 10 | $s | done | a note about the $s step that is long enough to matter |"; done; echo; }
mk() { # mk <id> <status> <frontmatter-extra|-> <title> <section> <summary>   (stdin: more body)
    { echo '---'; echo "title: $4"; echo "status: $2"
      [ "$3" != "-" ] && printf '%s\n' "$3"
      echo '---'; echo; workflow
      echo "## $5"; echo; echo "$6"; echo; cat; } > "$D/TST-$1.md"
}

mk 001 proposed 'type: epic
epic-name: render
tags: ["performance"]' "Rendering epic" Goal "Make the renderer fast." < /dev/null
mk 002 proposed 'epic: render' "Sprite batching" Description "Batch draw calls per atlas." < /dev/null
mk 003 proposed 'epic: render' "Shader cache" Description "Keep compiled shaders between runs." < /dev/null
mk 004 proposed - "Login form" Description "A login form for the web client." <<'EOF'
## Notes

The submit handler is slow on large forms; LATENCY spikes after 300 fields.
EOF
mk 005 proposed 'tags: ["performance"]' "Profile startup" Description "Find what slows startup." < /dev/null
mk 006 completed - "Old latency fix" Description "Fixed a latency bug." < /dev/null
mk 007 proposed - "Docs pass" Problem "The README is out of date." < /dev/null
mk 008 proposed - "Long summary" Description "$(printf 'word%s ' $(seq 1 120))" < /dev/null
mk 009 proposed - "Bulky task" Description "Short summary of a bulky task." < <(echo '## Log'; echo; filler 80)
printf '%s\n' '---' 'title: Ordered task' 'status: proposed' '---' '' '## Context' '' 'Context comes first here.' \
  '' '## Description' '' '| col | table |' 'The real summary.' > "$D/TST-011.md"
printf '%s\n' '---' 'title: Bare task' 'status: proposed' '---' '' 'Just a paragraph, no sections.' > "$D/TST-010.md"

L() { bash "$SC/list-tasks.sh" "$D" TST "$@"; }
ids() { printf '%s\n' "$1" | grep -oE '^TST-[0-9]+' | tr '\n' ' ' | sed 's/ $//'; }

echo "-- digest --"
out=$(L digest)
check "every open task, by id"       "TST-001 TST-002 TST-003 TST-004 TST-005 TST-007 TST-008 TST-009 TST-010 TST-011" "$(ids "$out")"
contains "title shown"               "Sprite batching" "$out"
contains "Description excerpted"     "Batch draw calls per atlas." "$out"
contains "Goal used without Description" "Make the renderer fast." "$out"
contains "Problem used too"          "The README is out of date." "$out"
contains "bare paragraph used"       "Just a paragraph, no sections." "$out"
lacks "workflow table left out"      "a note about the" "$out"
check "Description wins over earlier sections" "  The real summary." "$(printf '%s\n' "$out" | grep -A2 '^TST-011' | tail -1)"
contains "tags shown"                "tags: performance" "$out"
contains "epic shown"                "epic: render" "$out"
long=$(printf '%s\n' "$out" | grep -A2 '^TST-008' | tail -1)
check "excerpt capped (≤ 160 + …)"   "1" "$([ "${#long}" -le 170 ] && echo 1 || echo 0)"
contains "cut marked"                "…" "$long"
full="$(printf 'word%s ' $(seq 1 120))"; cut="${long#  }"; cut="${cut%…}"
prefix() { case "$2" in "$1"*) echo 1 ;; *) echo 0 ;; esac; }
check "cut on a word boundary"       "1" "$(prefix "$cut " "$full")"
long=$(L digest=40 | grep -A2 '^TST-008' | tail -1)
check "digest=N sets the cap"        "1" "$([ "${#long}" -le 50 ] && echo 1 || echo 0)"
check "honours status filter"        "TST-006" "$(ids "$(L digest status=completed)")"
check "honours all"                  "1" "$(L digest all | grep -c '^TST-006')"
check "honours tags filter"          "TST-001 TST-005" "$(ids "$(L digest tags=performance)")"
check "honours epic filter (strict)" "TST-001 TST-002 TST-003" "$(ids "$(L digest epic=render --strict-epic)")"
bytes_files=$(cat "$D"/*.md | wc -c)
bytes_digest=$(L digest | wc -c)
check "digest ≤ 1/20 of the bulky task" "1" \
  "$([ $(( $(wc -c < "$D/TST-009.md") / 20 )) -ge $(L digest | grep -A2 '^TST-009' | wc -c) ] && echo 1 || echo 0)"
check "digest far smaller than the files" "1" "$([ $((bytes_digest * 4)) -lt "$bytes_files" ] && echo 1 || echo 0)"

echo "-- candidates --"
C() { bash "$SC/tags.sh" "$D" TST candidates "$@"; }
before=$(cat "$D"/*.md | cksum)
out=$(C performance --match "latency,shader")
check "never writes"                 "$before" "$(cat "$D"/*.md | cksum)"
contains "body-only keyword found"   "$(printf 'TST-004\tmatch\t')" "$out"
contains "matching line reported"    "LATENCY spikes after 300 fields" "$out"
contains "title/summary match"       "$(printf 'TST-003\t')" "$out"
contains "already tagged marked"     "$(printf 'TST-005\ttagged')" "$out"
lacks "closed hidden by default"     "TST-006" "$out"
check "--all includes closed"        "1" "$(C performance --match latency --all | grep -c '^TST-006')"
contains "epic hint for a sub-task"  "$(printf 'TST-002\tvia epic\tTST-001')" "$out"
lacks "epic hint adds nothing else"  "TST-007" "$out"
lacks "unrelated task absent"        "TST-010" "$out"
out=$(C performance)
check "no --match: hints + tagged only" "TST-001 TST-002 TST-003 TST-005" "$(ids "$out")"
out=$(C 'Performance' --match 'LATENCY')
contains "tag and keywords lowercased" "$(printf 'TST-004\tmatch')" "$out"
out=$(C 'a"b' 2>&1); rc=$?
check "bad tag rejected"             "1" "$rc"

report review
