#!/usr/bin/env bash
# Tests for task tags (PLUG-080): decoding in read-tasks.sh, the tags= filter,
# group=tags and the Tags column in list-tasks.sh, and tags.sh list/add/remove.
#
# Run: bash scripts/test/tags.test.sh   (from the plugin root)
set -uo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

D="$TMP/tasks"; mkdir -p "$D"
task() { # task <id> <status> <tags-line|-> <title>
    { echo '---'
      echo "title: $4"
      echo "status: $2"
      [ "$3" != "-" ] && echo "tags: $3"
      echo 'priority: medium'
      echo '---'
      echo
      echo 'body'
    } > "$D/TST-$1.md"
}

task 001 proposed  '["performance", "tech debt"]'                       "Perf debt"
task 002 proposed  '["Performance"]'                                      "Upper-case tag"
task 003 proposed  '["three of several words, and with comma", "ui"]'      "Comma tag"
task 004 proposed  -                                                      "No tags"
task 005 proposed  '[ui, asset-generation]'                               "Unquoted tags"
task 006 proposed  '[]'                                                   "Empty tags"
task 007 completed '["tech debt"]'                                      "Closed debt"
task 008 proposed  '["ui", "ui", " UI "]'                                 "Duplicate tags"

ids() { # the task ids a listing prints, in order, on one line
    printf '%s\n' "$1" | grep -oE 'TST-[0-9]+' | tr '\n' ' ' | sed 's/ $//'
}
field() { # field <id> <key> -> the key's value from resolve-task.sh
    bash "$SC/resolve-task.sh" "$D" TST "$1" | grep "^$2=" | cut -d= -f2- || true
}

echo "-- decoding (R1, R2) --"
check "canonical quoted form"          '["performance", "tech debt"]' "$(field 001 tags)"
check "lowercased on read"             '["performance"]'                "$(field 002 tags)"
check "comma inside quotes kept"       '["three of several words, and with comma", "ui"]' "$(field 003 tags)"
check "unquoted elements read"         '["ui", "asset-generation"]'     "$(field 005 tags)"
check "empty list is no field"         ""                               "$(field 006 tags)"
check "duplicates and blanks dropped"  '["ui"]'                         "$(field 008 tags)"
json=$(bash "$SC/read-tasks.sh" "$D" TST --id=TST-001)
contains "JSON mode emits an array"    '"tags":["performance","tech debt"]' "$json"
json=$(bash "$SC/read-tasks.sh" "$D" TST --id=TST-003)
contains "JSON array keeps the comma"  '"tags":["three of several words, and with comma","ui"]' "$json"

echo "-- filter (R3, R4) --"
L() { bash "$SC/list-tasks.sh" "$D" TST "$@"; }
check "tags= matches an element"       "TST-001 TST-002" "$(ids "$(L tags=performance)")"
check "tags= ignores case"             "TST-001 TST-002" "$(ids "$(L tags=PERFORMANCE)")"
check "comma OR within the filter"     "TST-001 TST-002 TST-003 TST-005 TST-008" "$(ids "$(L tags=ui,performance)")"
check "quoted value keeps its comma"   "TST-003" "$(ids "$(L 'tags="three of several words, and with comma"')")"
check "quoted value keeps its space"   "TST-001" "$(ids "$(L 'tags="tech debt"')")"
check "closed hidden unless all"       "TST-001 TST-007" "$(ids "$(L 'tags="tech debt"' all)")"
check "tags=_ lists untagged tasks"    "TST-004 TST-006" "$(ids "$(L tags=_)")"
check "tags~ matches inside a tag"     "TST-001" "$(ids "$(L tags~debt)")"
check "repeated tags= is AND"          "TST-001" "$(ids "$(L tags=performance 'tags="tech debt"')")"
check "combines with other fields"     "" "$(ids "$(L tags=performance status=blocked)")"
check "no partial-element match"       "" "$(ids "$(L tags=perf)")"

echo "-- Tags column (R6) --"
out=$(L tags=performance)
contains "header has Tags"             "Tags" "$out"
contains "row shows its tags"          "performance, tech debt" "$out"
out=$(L tags=_)
lacks "no Tags column when none set"   "Tags" "$out"

echo "-- group=tags (R5) --"
out=$(L group=tags)
contains "a group per tag"             "── performance (2) ──" "$out"
contains "comma tag is its own group"  "── three of several words, and with comma (1) ──" "$out"
check "two-tag task in both groups"    "2" "$(printf '%s\n' "$out" | grep -c 'TST-001')"
check "(no tags) group last"           "── (no tags) (2) ──" "$(printf '%s\n' "$out" | grep '^──' | tail -1)"
out=$(L group=tags summary)
check "summary total counts once"      "Total open: 7" "$(printf '%s\n' "$out" | tail -1)"
for n in 1 2 3 4 5 6; do task "05$n" proposed '["big group"]' "Big $n"; done
out=$(L group=tags)
contains "hint quotes a spaced tag"    '/task list tags="big group"' "$out"
rm -f "$D"/TST-05?.md

echo "-- tags.sh list (R7) --"
T() { bash "$SC/tags.sh" "$D" TST "$@"; }
out=$(T list)
contains "counts closed tasks too"     "$(printf 'tech debt\t2')" "$out"
contains "counts across spellings"     "$(printf 'performance\t2')" "$out"
contains "ui counted once per task"    "$(printf 'ui\t3')" "$out"
check "sorted by tag"                  "asset-generation" "$(printf '%s\n' "$out" | head -1 | cut -f1)"

echo "-- tags.sh add / remove (R8) --"
F="$D/TST-004.md"
out=$(T add 004 ui); rc=$?
check "add existing tag: exit 0"       "0" "$rc"
check "written canonical"              'tags: ["ui"]' "$(grep '^tags:' "$F")"
check "inside the frontmatter"         "---" "$(sed -n '6p' "$F")"
before=$(cat "$F")
out=$(T add 004 brandnew 2>&1); rc=$?
check "new tag refused: exit 1"        "1" "$rc"
contains "refusal names the tag"       "brandnew" "$out"
check "refused: file unchanged"        "$before" "$(cat "$F")"
out=$(T add 004 --new BrandNew); rc=$?
check "--new allows it, lowercased"    'tags: ["ui", "brandnew"]' "$(grep '^tags:' "$F")"
touch -t 202001010000 "$F"; m1=$(ls -l "$F")
T add 004 ui >/dev/null
check "no-op add leaves file alone"    "$m1" "$(ls -l "$F")"
T remove 004 ui >/dev/null
check "remove one"                     'tags: ["brandnew"]' "$(grep '^tags:' "$F")"
T remove 004 brandnew >/dev/null
check "last removed drops the line"    "" "$(grep '^tags:' "$F" || true)"
check "body untouched"                 "body" "$(tail -1 "$F")"
out=$(T add 004 --new 'a"b' 2>&1); rc=$?
check "quote in a tag rejected"        "1" "$rc"
out=$(T frobnicate 004 ui 2>&1); rc=$?
check "unknown action rejected"        "1" "$rc"
out=$(T add 999 ui 2>&1); rc=$?
check "unknown task rejected"          "1" "$rc"
T add 001 --new 'Three Of Several Words, And With Comma' >/dev/null
check "comma tag written quoted"       'tags: ["performance", "tech debt", "three of several words, and with comma"]' "$(grep '^tags:' "$D/TST-001.md")"

echo "-- untouched without tags (R9) --"
out=$(bash "$SC/set-status.sh" "$D" TST 004 approved)
check "set-status still writes"        "status: approved" "$(grep '^status:' "$F")"

report tags
