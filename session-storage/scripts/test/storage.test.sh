#!/usr/bin/env bash
# storage.sh and the two hooks: the key-value round trip, a plain refusal when the storage dir cannot
# be written, session ids and keys that could escape the storage dir refused (PLUG-132), the hooks
# working without jq, and `list` reading a dir's age with `stat -c` before `stat -f`.
# The plugin keeps nothing in HOME (it lives in ${CLAUDE_CODE_TMPDIR:-/tmp}), so HOME unset must not
# matter; an unwritable tmp must not be reported as "Stored" (PLUG-122).
#
# Run (from the plugin root):
#   bash scripts/test/storage.test.sh
#   docker run --rm -v "$PWD":/w -w /w bash:5 bash scripts/test/storage.test.sh
set -uo pipefail

SD="$(cd "$(dirname "$0")/.." && pwd)"; S="$SD/storage.sh"
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

echo "-- names that would escape the storage dir are refused --"
ST="$CLAUDE_CODE_TMPDIR/claude-session-storage"
out="$(st set s4 ../../escaped v)"; rc=$?
check "4a set refuses a key with ../" "1" "$rc"
check "4b ... and wrote nothing outside" "no" "$([ -e "$TMP/escaped" ] || [ -e "$CLAUDE_CODE_TMPDIR/escaped" ] && echo yes || echo no)"
check "4c ... and says why" "yes" "$(has "invalid key" "$out")"
out="$(st set .. k v)"; rc=$?
check "4d set refuses session id .." "1" "$rc"
check "4e get refuses a key with /" "1" "$(st get s1 a/b >/dev/null; echo $?)"
mkdir -p "$ST/s5"; : > "$CLAUDE_CODE_TMPDIR/sentinel"
out="$(st clear ../claude-session-storage)"; rc=$?
check "4f clear refuses a session id that names the storage root" "1" "$rc"
check "4g ... and removed nothing" "yes" "$([ -e "$CLAUDE_CODE_TMPDIR/sentinel" ] && [ -d "$ST/s5" ] && echo yes || echo no)"
check "4h list refuses session id .." "1" "$(st list .. >/dev/null; echo $?)"
check "4i a UUID session id and key active-tasks still work" "x" \
    "$(st set 3639a38d-fd63-4c66-a202-4e61422dab55 active-tasks x >/dev/null; st get 3639a38d-fd63-4c66-a202-4e61422dab55 active-tasks)"

echo "-- hooks: no jq needed --"
mkdir -p "$TMP/bin"; printf '#!/bin/sh\necho "jq: not installed" >&2; exit 127\n' > "$TMP/bin/jq"; chmod +x "$TMP/bin/jq"
hook() { PATH="$TMP/bin:$PATH" bash "$SD/$1" 2>"$TMP/hook.err"; }
out="$(printf '{ "cwd": "/x",\n  "session_id" : "abc-123", "hook_event_name": "SessionStart" }' | hook capture-session.sh)"; rc=$?
check "5a capture exits 0" "0" "$rc"
check "5b it injects the session id (multi-line JSON, not the first key)" "yes" "$(has "Your session_id is: abc-123." "$out")"
check "5c it creates the session dir" "yes" "$([ -d "$ST/abc-123" ] && echo yes || echo no)"
check "5d it records the current session" "abc-123" "$(cat "$ST/.current_session" 2>/dev/null)"
check "5e its output names the storage script" "yes" "$(has "$S set abc-123" "$out")"
out="$(printf '{"session_id":"abc-123"}' | hook cleanup-session.sh)"; rc=$?
check "5f cleanup exits 0" "0" "$rc"
check "5g it removes the session dir" "no" "$([ -d "$ST/abc-123" ] && echo yes || echo no)"
out="$(printf '{"cwd":"/x"}' | hook capture-session.sh)"; rc=$?
check "5h no session id: exit 0, nothing injected" "0:" "$rc:$out"

echo "-- hooks: a hostile session id touches nothing --"
: > "$CLAUDE_CODE_TMPDIR/sentinel"
mkdir -p "$ST/s6"
out="$(printf '{"session_id":"../claude-session-storage"}' | hook cleanup-session.sh)"; rc=$?
check "6a cleanup exits 0" "0" "$rc"
check "6b ... and the other sessions survive" "yes" "$([ -e "$CLAUDE_CODE_TMPDIR/sentinel" ] && [ -d "$ST/s6" ] && echo yes || echo no)"
check "6c ... and says why on stderr" "yes" "$(has "invalid session id" "$(cat "$TMP/hook.err")")"
out="$(printf '{"session_id":"../../hook-escaped"}' | hook capture-session.sh)"; rc=$?
check "6d capture exits 0" "0" "$rc"
check "6e ... creates nothing outside storage" "no" "$([ -e "$TMP/hook-escaped" ] || [ -e "$CLAUDE_CODE_TMPDIR/hook-escaped" ] && echo yes || echo no)"
check "6f ... and injects nothing" "" "$out"

echo "-- list: dir age from stat -c first (stat -f is filesystem status on GNU/busybox) --"
real_stat="$(command -v stat)"
# A GNU-like stat on any host: `-c %Y` works, `-f` (filesystem mode) prints junk and succeeds.
cat > "$TMP/bin/stat" <<STAT
#!/bin/sh
case "\$1" in
  -f) echo "?"; exit 0 ;;
  -c) "$real_stat" -c %Y "\$3" 2>/dev/null || "$real_stat" -f %m "\$3" ;;
  *) exec "$real_stat" "\$@" ;;
esac
STAT
chmod +x "$TMP/bin/stat"
st set s7 k v >/dev/null
out="$(PATH="$TMP/bin:$PATH" bash "$S" list 2>&1)"
check "7a the age is a number of minutes" "yes" "$(has "s7: 1 key(s)  (0m ago)" "$out")"

echo
echo "storage: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
