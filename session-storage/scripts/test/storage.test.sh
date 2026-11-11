#!/usr/bin/env bash
# storage.sh: the key-value round trip, and a plain refusal when the storage dir cannot be written.
# The plugin keeps nothing in HOME (it lives in ${CLAUDE_CODE_TMPDIR:-/tmp}), so HOME unset must not
# matter; an unwritable tmp must not be reported as "Stored" (PLUG-122).
#
# Run (from the plugin root):
#   bash scripts/test/storage.test.sh
#   docker run --rm -v "$PWD":/w -w /w bash:5 bash scripts/test/storage.test.sh
set -uo pipefail

S="$(cd "$(dirname "$0")/.." && pwd)/storage.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0
check() { # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"
    else fail=$((fail+1)); echo "  FAIL $1"; echo "         expected: [$2]"; echo "         actual:   [$3]"; fi
}
has() { case "$2" in *"$1"*) echo yes ;; *) echo no ;; esac; }   # has <needle> <haystack>

export CLAUDE_CODE_TMPDIR="$TMP/tmp"; mkdir -p "$CLAUDE_CODE_TMPDIR"
st() { bash "$S" "$@" 2>&1; }

echo "-- round trip --"
st set s1 task-id "PLUG-122" >/dev/null
check "1a get returns what set stored" "PLUG-122" "$(st get s1 task-id)"
st set s1 note two words >/dev/null
check "1b a multi-word value is kept" "two words" "$(st get s1 note)"
check "1c list shows the key" "yes" "$(has "task-id: PLUG-122" "$(st list s1)")"
st clear s1 task-id >/dev/null
check "1d clear removes the key" "yes" "$(has "no value set" "$(st get s1 task-id)")"

echo "-- no HOME: nothing changes --"
out="$(env -u HOME bash "$S" set s2 k v 2>&1)"; rc=$?
check "2a HOME unset: set exits 0" "0" "$rc"
check "2b HOME unset: get works" "v" "$(env -u HOME bash "$S" get s2 k 2>&1)"

echo "-- storage dir not writable: a plain refusal, not a false 'Stored' --"
: > "$TMP/tmp-is-a-file"
out="$(CLAUDE_CODE_TMPDIR="$TMP/tmp-is-a-file" bash "$S" set s3 k v 2>&1)"; rc=$?
check "3a set exits 1" "1" "$rc"
check "3b set does not claim it stored" "no" "$(has "Stored" "$out")"
check "3c set says why" "yes" "$(has "cannot write" "$out")"
check "3d no raw mkdir noise" "no" "$(has "mkdir:" "$out")"

echo
echo "storage: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
