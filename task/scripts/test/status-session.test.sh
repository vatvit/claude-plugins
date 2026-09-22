#!/usr/bin/env bash
# Tests for set-status.sh and session-active.sh.
#
# The storage helper here is a five-line stand-in, which is the point: the
# plugin talks to whatever executable it is handed and must work with none.
#
# Run: bash scripts/test/status-session.test.sh   (from the plugin root)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SC="$ROOT/scripts"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0

check() {
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"
    else fail=$((fail+1)); echo "  FAIL $1"; echo "         expected: [$2]"; echo "         actual:   [$3]"; fi
}

D="$TMP/tasks"; mkdir -p "$D"
{ echo '---'; echo 'title: Alpha epic'; echo 'status: proposed'; echo 'type: epic'
  echo 'epic-name: alpha'; echo '---'; } > "$D/TST-001.md"
mk() { { echo '---'; echo "title: $3"; echo "status: $2"; [ "$4" != "-" ] && echo "epic: $4"; echo '---'; } > "$D/TST-$1.md"; }
mk 002 proposed "Sub one" alpha
mk 003 proposed "Sub two" alpha
mk 004 proposed "Loner"   -

# --- stand-in storage helper: <bin> get|set|clear <session> <key> [value] ---
BIN="$TMP/kv.sh"
cat > "$BIN" <<'KV'
#!/usr/bin/env bash
f="$(dirname "$0")/kv-$2-$4.txt"; f="$(dirname "$0")/kv-$2-$3.txt"
case "$1" in
    get)   [ -f "$f" ] && cat "$f" || echo "(no value set for key: $3)" ;;
    set)   printf '%s' "$4" > "$f" ;;
    clear) rm -f "$f" ;;
esac
KV
chmod +x "$BIN"
export TASK_STORAGE_BIN="$BIN" TASK_SESSION_ID=sess1

get_active() { bash "$SC/session-active.sh" "$D" TST get | grep '^active=' | cut -d= -f2-; }

echo "-- set-status --"
out=$(bash "$SC/set-status.sh" "$D" TST 4 approved)
check "old and new reported" "old=proposed new=approved" \
  "$(printf '%s\n' "$out" | grep -E '^(old|new)=' | tr '\n' ' ' | sed 's/ $//')"
check "frontmatter rewritten" "status: approved" "$(grep '^status:' "$D/TST-004.md")"

bash "$SC/set-status.sh" "$D" TST 4 nonsense >/dev/null 2>&1
check "invalid status rejected" "1" "$?"
bash "$SC/set-status.sh" "$D" TST 777 approved >/dev/null 2>&1
check "unknown task rejected" "1" "$?"

echo "-- parent epic cascade --"
out=$(bash "$SC/set-status.sh" "$D" TST 2 in-progress)
check "cascade reported" "epic_id=TST-001 epic_old=proposed epic_new=in-progress" \
  "$(printf '%s\n' "$out" | grep '^epic_' | tr '\n' ' ' | sed 's/ $//')"
check "epic file updated" "status: in-progress" "$(grep '^status:' "$D/TST-001.md")"
out=$(bash "$SC/set-status.sh" "$D" TST 3 in-progress)
check "no second cascade once the epic is in-progress" "" "$(printf '%s\n' "$out" | grep '^epic_id=' || true)"
out=$(bash "$SC/set-status.sh" "$D" TST 4 blocked)
check "only in-progress cascades" "" "$(printf '%s\n' "$out" | grep '^epic_id=' || true)"

echo "-- active-tasks --"
# TST-002 going in-progress added it *and* its epic. TST-003 followed, but a
# sibling sub-task is not the parent-epic case, so it raised a conflict and was
# not appended — that decision belongs to the user, not to the script.
check "sub-task and epic both active" "TST-001,TST-002" "$(get_active)"

bash "$SC/session-active.sh" "$D" TST add TST-003 --force >/dev/null
bash "$SC/session-active.sh" "$D" TST remove TST-003 >/dev/null
check "remove drops only that id" "TST-001,TST-002" "$(get_active)"

out=$(bash "$SC/session-active.sh" "$D" TST add TST-004)
check "unrelated task conflicts instead of appending" "status=conflict" "$(printf '%s\n' "$out" | grep '^status=')"
check "conflict names the active tasks" "conflict=TST-001,TST-002" "$(printf '%s\n' "$out" | grep '^conflict=')"
check "conflict changed nothing" "TST-001,TST-002" "$(get_active)"

out=$(bash "$SC/session-active.sh" "$D" TST add TST-004 --force)
check "--force appends" "TST-001,TST-002,TST-004" "$(get_active)"

bash "$SC/session-active.sh" "$D" TST remove TST-004 >/dev/null
bash "$SC/session-active.sh" "$D" TST remove TST-002 >/dev/null
out=$(bash "$SC/session-active.sh" "$D" TST add TST-003)
check "sub-task under an active epic appends silently" "status=added" "$(printf '%s\n' "$out" | grep '^status=')"
check "epic kept, sub-task appended" "TST-001,TST-003" "$(get_active)"

out=$(bash "$SC/session-active.sh" "$D" TST add TST-003)
check "adding twice is a no-op" "status=present" "$(printf '%s\n' "$out" | grep '^status=')"

bash "$SC/session-active.sh" "$D" TST set TST-002 >/dev/null
check "set replaces the list, epic included" "TST-001,TST-002" "$(get_active)"

out=$(bash "$SC/set-status.sh" "$D" TST 2 completed)
check "leaving in-progress drops the id" "TST-001" "$(get_active)"
check "the parent epic is never dropped with it" "TST-001" "$(get_active)"

bash "$SC/session-active.sh" "$D" TST remove TST-001 >/dev/null
check "removing the last id clears the key" "" "$(get_active)"

echo "-- storage helper absent --"
out=$(env -u TASK_STORAGE_BIN bash "$SC/session-active.sh" "$D" TST get)
check "no helper is a silent no-op" "status=unavailable" "$(printf '%s\n' "$out" | grep '^status=')"
out=$(env -u TASK_STORAGE_BIN bash "$SC/set-status.sh" "$D" TST 3 in-progress)
check "set-status still works without a helper" "0" "$?"
check "and says so" "active_status=unavailable" "$(printf '%s\n' "$out" | grep '^active_status=')"
out=$(TASK_STORAGE_BIN="$TMP/not-there.sh" bash "$SC/session-active.sh" "$D" TST get)
check "a helper path that is not executable is also a no-op" "status=unavailable" \
  "$(printf '%s\n' "$out" | grep '^status=')"

echo "-- idempotence --"
before=$(cat "$D/TST-004.md")
bash "$SC/set-status.sh" "$D" TST 4 blocked >/dev/null
check "re-setting the same status leaves the file alone" "$before" "$(cat "$D/TST-004.md")"

echo
echo "passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
