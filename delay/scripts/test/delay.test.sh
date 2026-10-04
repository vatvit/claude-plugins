#!/usr/bin/env bash
# Tests for the delay plugin: dates, the client, approve, the dispatcher, wake sync, install.
#
# docker, pmset, launchctl and caffeinate are PATH shims that log their arguments — nothing
# here ever schedules a real wake, loads a launchd job or starts a container. Fixtures live
# under mktemp -d; the real ~/.claude and /Library are never touched (every path is redirected
# through the DELAY_* seams, which only the source tree honours).
#
# Dual-target, same as the other plugins:
#   bash delay/scripts/test/delay.test.sh
#   docker run --rm -v "$PWD":/w -w /w bash:5 bash delay/scripts/test/delay.test.sh
set -uo pipefail

S="$(cd "$(dirname "$0")/.." && pwd -P)"
TMP="$(mktemp -d)"; TMP="$(cd "$TMP" && pwd -P)"   # macOS: /var -> /private/var
trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0

check() { # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"
    else fail=$((fail+1)); echo "  FAIL $1"; echo "         expected: [$2]"; echo "         actual:   [$3]"; fi
}
has() { grep -qF -- "$2" "$1" 2>/dev/null && echo yes || echo no; }   # has <file> <text>

export TZ=UTC
export DELAY_HOME="$TMP/uhome/.claude/delay" DELAY_REGISTRY="$TMP/reg" DELAY_STATE="$TMP/state"
export DELAY_INSTALL_PREFIX="$TMP/prefix" DELAY_DOCKER_WAIT=0 DELAY_AS_ROOT=0   # start tests set 1 per call
NOW=1791028800                     # 2026-10-03 12:00:00 UTC
export DELAY_NOW=$NOW

SHIM="$TMP/shim"; mkdir -p "$SHIM"
cat > "$SHIM/docker" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$SHIM_LOG/docker.log"
case " $* " in
  *" info "*)   exit "${FAKE_DOCKER_INFO:-0}" ;;
  *" config"*)  cat "${FAKE_COMPOSE_CONFIG:-/dev/null}"; exit 0 ;;
  *" run "*)    echo "running tests"; sleep "${FAKE_SLEEP:-0}"; exit "${FAKE_RC:-0}" ;;
esac
EOF
printf '#!/usr/bin/env bash\necho "$*" >> "$SHIM_LOG/pmset.log"\nexit "${FAKE_PMSET_RC:-0}"\n' > "$SHIM/pmset"
cat > "$SHIM/launchctl" <<'EOF'
#!/usr/bin/env bash
[ "$1" = print ] && exit "${FAKE_LOADED:-1}"     # is the runner loaded?
echo "$*" >> "$SHIM_LOG/launchctl.log"
EOF
cat > "$SHIM/caffeinate" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$SHIM_LOG/caffeinate.log"
case " $* " in *" -t "*) sleep 60 ;; esac     # the hold: stays alive like the real one
exit 0
EOF
chmod +x "$SHIM"/*
export SHIM_LOG="$TMP" PATH="$SHIM:$PATH"

. "$S/lib.sh"

# project fixture: compose + Dockerfile + wrapper + test code
P="$TMP/proj"; mkdir -p "$P/scripts" "$P/tests"
echo "services: {app: {build: .}}" > "$P/compose.yml"
echo "FROM alpine" > "$P/Dockerfile"
printf '#!/bin/sh\nrun-tests\n' > "$P/scripts/test-all.sh"
echo "test one" > "$P/tests/one.test"

approve() { bash "$S/approve.sh" "$P" "$@" --yes 2>&1; }
client() { bash "$S/delay.sh" --project "$P" "$@" 2>&1; }
store() { echo "$DELAY_HOME/$(encode_path "$P")"; }
queue_raw() { # queue_raw <id> <job> — a queue entry written behind the client's back
    mkdir -p "$(store)/queue"; echo "$P" > "$(store)/project.path"
    printf 'id=%s\nproject=%s\njob=%s\ncreated=%s\n' "$1" "$P" "$2" "$NOW" > "$(store)/queue/$1.job"
}
win() { bash "$S/approve.sh" --window "$@" >/dev/null 2>&1; }      # the human sets the window
WINFILE="$DELAY_INSTALL_PREFIX/Library/Application Support/claude-delay/window"
dispatch() { : > "$TMP/docker.log"; bash "$S/dispatch.sh" 2>&1; }
meta() { kv "$2" "$(store)/results/$1/meta"; }

echo "== dates =="
check "1a parse_local is exact (BSD fills missing fields from now)" "$NOW" "$(parse_local "2026-10-03 12:00:00")"
check "1b fmt_epoch" "2026-10-03 12:00" "$(fmt_epoch $NOW "%Y-%m-%d %H:%M")"
check "1c pmset format" "10/03/26 12:00:00" "$(fmt_epoch $NOW "%m/%d/%y %H:%M:%S")"

echo "== run window =="
check "1d unset -> no window" "1" "$(window_conf >/dev/null; echo $?)"
check "1e bad start refused" "1" "$(bash "$S/approve.sh" --window 25:00 2 >/dev/null 2>&1; echo $?)"
check "1f bad length refused" "1" "$(bash "$S/approve.sh" --window 03:00 0 >/dev/null 2>&1; echo $?)"
win 13:00 2
check "1g set by approve --window" "13:00 2" "$(window_conf)"
check "1h --window shows it" "run window: 13:00 for 2h" "$(bash "$S/approve.sh" --window)"
check "1i next window later today" "$((NOW + 3600))" "$(next_window $NOW)"
check "1j before the window -> closed" "no" "$(in_window $NOW && echo yes || echo no)"
win 11:00 2
check "1k next window already passed -> tomorrow" "$((NOW + 82800))" "$(next_window $NOW)"
check "1l inside the window -> open" "yes" "$(in_window $NOW && echo yes || echo no)"
check "1m window end is exclusive" "no" "$(in_window $((NOW + 3600)) && echo yes || echo no)"
win 23:00 14
check "1n window crossing midnight -> open next day" "yes" "$(in_window $NOW && echo yes || echo no)"

echo "== identity =="
check "2a encode_path" "-a-b-c-d" "$(encode_path /a/b.c-d)"
check "2b valid_name rejects traversal" "no" "$(valid_name ../x && echo yes || echo no)"
check "2c valid_name rejects dot-dot" "no" "$(valid_name .. && echo yes || echo no)"
check "2d inside_project accepts" "$P/compose.yml" "$(inside_project "$P" compose.yml)"
check "2e inside_project rejects ../" "1" "$(inside_project "$P" ../x >/dev/null; echo $?)"
ln -s /etc/hosts "$P/link.yml"
check "2f inside_project rejects a symlink" "1" "$(inside_project "$P" link.yml >/dev/null; echo $?)"
rm -f "$P/link.yml"

echo "== approve =="
out="$(approve tests-full --compose compose.yml --service app --wrapper scripts/test-all.sh)"
JF="$DELAY_REGISTRY/$(encode_path "$P")/jobs/tests-full"
check "3a approves" "yes" "$(echo "$out" | grep -q '^approved tests-full' && echo yes || echo no)"
check "3b pins compose" "yes" "$(has "$JF" "pin=compose.yml ")"
check "3c pins wrapper" "yes" "$(has "$JF" "pin=scripts/test-all.sh ")"
check "3d auto-pins Dockerfile" "yes" "$(has "$JF" "pin=Dockerfile ")"
check "3e does not pin test code" "no" "$(has "$JF" "tests/")"
check "3f command defaults to wrapper" "scripts/test-all.sh" "$(kv command "$JF")"
check "3g project.path recorded" "$P" "$(cat "$DELAY_REGISTRY/$(encode_path "$P")/project.path")"
before="$(ls -i "$JF")"; approve tests-full --compose compose.yml --service app --wrapper scripts/test-all.sh >/dev/null
check "3h re-approve unchanged leaves file untouched" "$before" "$(ls -i "$JF")"
check "3i wrapper outside project refused" "1" "$(approve x --compose compose.yml --service app --wrapper ../etc >/dev/null; echo $?)"
check "3j pin outside project refused" "1" "$(approve x --compose compose.yml --service app --wrapper scripts/test-all.sh --pin ../../etc/hosts >/dev/null; echo $?)"
check "3k bad job name refused" "1" "$(approve ../evil --compose compose.yml --service app --wrapper scripts/test-all.sh >/dev/null; echo $?)"
check "3l bad service name refused" "1" "$(approve x --compose compose.yml --service 'a b' --wrapper scripts/test-all.sh >/dev/null; echo $?)"

printf 'services:\n  app:\n    privileged: true\n    volumes:\n      - type: bind\n        source: /var/run/docker.sock\n        target: /s\n      - type: bind\n        source: %s/src\n        target: /app\n      - type: bind\n        source: /Users\n        target: /u\n    network_mode: host\n' "$P" > "$TMP/risky.yml"
out="$(FAKE_COMPOSE_CONFIG="$TMP/risky.yml" approve risky --compose compose.yml --service app --wrapper scripts/test-all.sh)"; rc=$?
check "4a red flags refuse" "1" "$rc"
check "4b flags privileged" "yes" "$(echo "$out" | grep -q 'privileged container' && echo yes || echo no)"
check "4c flags docker socket" "yes" "$(echo "$out" | grep -q 'docker socket' && echo yes || echo no)"
check "4d flags host mount outside project" "yes" "$(echo "$out" | grep -q 'outside the project: /Users$' && echo yes || echo no)"
check "4e project mount is not a flag" "no" "$(echo "$out" | grep -q "outside the project: $P/src" && echo yes || echo no)"
check "4f flags host network" "yes" "$(echo "$out" | grep -q 'host namespace' && echo yes || echo no)"
check "4g nothing written on refusal" "no" "$([ -f "$DELAY_REGISTRY/$(encode_path "$P")/jobs/risky" ] && echo yes || echo no)"
FAKE_COMPOSE_CONFIG="$TMP/risky.yml" approve risky --compose compose.yml --service app --wrapper scripts/test-all.sh --accept-risks >/dev/null
check "4h --accept-risks approves" "yes" "$([ -f "$DELAY_REGISTRY/$(encode_path "$P")/jobs/risky" ] && echo yes || echo no)"
bash "$S/approve.sh" --revoke "$P" risky >/dev/null 2>&1
check "4i revoke" "no" "$([ -f "$DELAY_REGISTRY/$(encode_path "$P")/jobs/risky" ] && echo yes || echo no)"
check "4j --list shows the approved job with its ID" "yes" "$(l="$(bash "$S/approve.sh" --list)"; echo "$l" | grep -q "^  $(job_id "$P" tests-full)  tests-full  *approved *compose.yml / app / scripts/test-all.sh" && echo yes || echo no)"

echo "== client =="
win 03:00 4
out="$(client add tests-full)"; rc=$?
check "5a add approved job" "0" "$rc"
ID="$(echo "$out" | awk '/^queued/ { sub(/:$/, "", $2); print $2 }')"
check "5b queue entry holds no time" "no" "$(has "$(store)/queue/$ID.job" "run_at")"
check "5c queue entry holds no command" "no" "$(has "$(store)/queue/$ID.job" "test-all")"
check "5d add tells the window" "yes" "$(echo "$out" | grep -q 'window: 03:00 for 4h — next 2026-10-04 03:00' && echo yes || echo no)"
check "5e reminder asks the user to install and start" "yes:yes" "$(echo "$out" | grep -q "^ACTION FOR THE USER" && echo yes || echo no):$(echo "$out" | grep -q "install.sh" && echo yes || echo no)"
out="$(client add tests-full 13:00)"; rc=$?
check "5f a time argument is refused" "1" "$rc"
check "5g refusal points at the user's window" "yes" "$(echo "$out" | grep -q "user's run window" && echo yes || echo no)"
out="$(client add tests-full)"
check "5h duplicate add is not queued twice" "1" "$(ls "$(store)/queue" | wc -l | tr -d ' ')"
check "5i duplicate add names the existing id" "yes" "$(echo "$out" | grep -q "already queued $ID" && echo yes || echo no)"
out="$(client add nope)"; rc=$?
check "5j unapproved job is still queued" "0:yes" "$rc:$(echo "$out" | grep -q "(not approved yet)" && echo yes || echo no)"
check "5k the note names the approve command for it" "yes" "$(echo "$out" | grep -q "approve.sh\" \"$P\" nope --compose" && echo yes || echo no)"
mkdir -p "$TMP/other"
out="$(bash "$S/delay.sh" --project "$TMP/other" add tests-full 2>&1)"; rc=$?
check "5l unapproved project: queued, note asks to approve" "0:yes" "$rc:$(echo "$out" | grep -q "approve.sh\" \"$TMP/other\" tests-full" && echo yes || echo no)"
rm -rf "$DELAY_HOME/$(encode_path "$TMP/other")"; for f in "$(store)"/queue/*.job; do [ "$(kv job "$f")" = nope ] && rm -f "$f"; done
check "5m list shows the queued job" "yes" "$(l="$(client list)"; echo "$l" | grep -q "$ID  tests-full" && echo yes || echo no)"
check "5n list shows the window" "yes" "$(l="$(client list)"; echo "$l" | grep -q '^window: 03:00 for 4h' && echo yes || echo no)"
check "5o show a queued job" "status=queued" "$(client show "$ID" | tail -1)"
check "5p jobs lists approved names" "yes" "$(l="$(client jobs)"; echo "$l" | grep -q '^tests-full' && echo yes || echo no)"
check "5q rm removes" "0" "$(client rm "$ID" >/dev/null; echo $?)"
check "5r rm unknown fails" "1" "$(client rm "$ID" >/dev/null; echo $?)"
check "5s rm refuses traversal" "1" "$(client rm ../x >/dev/null; echo $?)"
rm -f "$WINFILE"
check "5t no window, not installed -> install will set it" "yes" "$(l="$(bash "$S/delay.sh" status)"; echo "$l" | grep -q '^window: not set yet' && echo yes || echo no)"

echo "== approval by ID =="
AP_="$S/approve.sh"
cleanq() { for f in "$(store)"/queue/*.job; do [ -f "$f" ] && rm -f "$f"; done; }
cleanq
out="$(DELAY_HOME="$TMP/emptyhome" DELAY_REGISTRY="$TMP/emptyreg" bash "$AP_")"
check "18a nothing anywhere -> says so" "No jobs yet: nothing approved, nothing waiting." "$out"
PID_="$(job_id "$P" proposed)"
out="$(client add proposed --compose compose.yml --service app --wrapper scripts/test-all.sh --timeout 900)"; rc=$?
check "18b add with a proposal queues it" "0:yes" "$rc:$(echo "$out" | grep -q 'proposed (not approved yet)' && echo yes || echo no)"
check "18c the note gives approve <ID>" "yes" "$(echo "$out" | grep -q "approve.sh\" $PID_ " && echo yes || echo no)"
check "18d the note points at the full list" "yes" "$(echo "$out" | grep -q '(all projects and jobs: sudo' && echo yes || echo no)"
out="$(bash "$AP_")"
check "18e list: project, ID, WAITING, the proposal" "yes" \
  "$(echo "$out" | grep -q "^  $PID_  proposed  *WAITING for approval *compose.yml / app / scripts/test-all.sh" && echo yes || echo no)"
check "18f list shows the project path" "yes" "$(echo "$out" | grep -qx "$P" && echo yes || echo no)"
check "18g list shows approved jobs with their ID" "yes" \
  "$(echo "$out" | grep -q "^  $(job_id "$P" tests-full)  tests-full  *approved" && echo yes || echo no)"
out="$(bash "$AP_" "$PID_" --yes)"; rc=$?
check "18h approve by ID" "0" "$rc"
PJ="$DELAY_REGISTRY/$(encode_path "$P")/jobs/proposed"
check "18i ... registry gets the proposal" "app|scripts/test-all.sh|900" "$(kv service "$PJ")|$(kv wrapper "$PJ")|$(kv timeout "$PJ")"
check "18j ... and lists it approved" "yes" "$(l="$(bash "$AP_")"; echo "$l" | grep -q "^  $PID_  proposed  *approved" && echo yes || echo no)"
out="$(client add proposed)"
check "18k approved -> no approve line in the note" "no" "$(echo "$out" | grep -q "approve.sh\" $PID_" && echo yes || echo no)"
NID="$(job_id "$P" noprop)"
out="$(client add noprop)"
check "18l no proposal -> the note gives the full form" "yes" "$(echo "$out" | grep -q "\"$P\" noprop --compose FILE" && echo yes || echo no)"
out="$(bash "$AP_" "$NID" --yes 2>&1)"; rc=$?
check "18m approve <ID> without a proposal refused" "1:yes" "$rc:$(echo "$out" | grep -q 'nobody proposed' && echo yes || echo no)"
out="$(client add noprop --compose compose.yml --service app --wrapper scripts/test-all.sh)"
check "18n re-add with a proposal updates the queued entry" "yes" "$(echo "$out" | grep -q 'proposal updated' && echo yes || echo no)"
check "18o ... still one entry" "1" "$(grep -l '^job=noprop$' "$(store)"/queue/*.job | wc -l | tr -d ' ')"
check "18p ... and approve <ID> now works" "0" "$(bash "$AP_" "$NID" --yes >/dev/null 2>&1; echo $?)"
echo "# edited" >> "$P/scripts/test-all.sh"
check "18q pinned file changed -> list says re-approve" "yes" "$(l="$(bash "$AP_")"; echo "$l" | grep -q "^  $PID_  proposed  *CHANGED, re-approve" && echo yes || echo no)"
check "18r re-approve by the same ID" "0" "$(bash "$AP_" "$PID_" --yes >/dev/null 2>&1; echo $?)"
check "18s ... approved again" "yes" "$(l="$(bash "$AP_")"; echo "$l" | grep -q "^  $PID_  proposed  *approved" && echo yes || echo no)"
approve tests-full --compose compose.yml --service app --wrapper scripts/test-all.sh >/dev/null   # re-pin after the edit
check "18t revoke by ID" "0:no" "$(bash "$AP_" --revoke "$NID" >/dev/null 2>&1; echo $?):$([ -f "$DELAY_REGISTRY/$(encode_path "$P")/jobs/noprop" ] && echo yes || echo no)"
check "18u unknown ID refused" "1" "$(bash "$AP_" abcdef --yes >/dev/null 2>&1; echo $?)"
check "18v proposal outside the project refused" "1" "$(client add bad --compose compose.yml --service app --wrapper ../x >/dev/null; echo $?)"
check "18w incomplete proposal refused" "1" "$(client add bad --compose compose.yml >/dev/null; echo $?)"
RID="$(job_id "$P" riskyprop)"
client add riskyprop --compose compose.yml --service app --wrapper scripts/test-all.sh >/dev/null
check "18x approve <ID> still refuses red flags" "1" "$(FAKE_COMPOSE_CONFIG="$TMP/risky.yml" bash "$AP_" "$RID" --yes >/dev/null 2>&1; echo $?)"
cleanq; bash "$AP_" --revoke "$PID_" >/dev/null 2>&1

echo "== dispatch =="
queue_raw j0 tests-full
dispatch >/dev/null
check "6a no window set -> nothing starts" "yes" "$([ -f "$(store)/queue/j0.job" ] && echo yes || echo no)"
win 13:00 2; dispatch >/dev/null
check "6b outside the window -> nothing starts" "yes" "$([ -f "$(store)/queue/j0.job" ] && echo yes || echo no)"
check "6c docker untouched outside the window" "0" "$(wc -c < "$TMP/docker.log" | tr -d ' ')"
rm -f "$(store)/queue/j0.job"
win 11:00 4
queue_raw j1 tests-full; dispatch >/dev/null
check "6d inside the window -> passed" "passed" "$(meta j1 status)"
check "6e docker compose run invoked" "yes" "$(has "$TMP/docker.log" "compose -f compose.yml run --rm -T --name claude-delay-j1 app scripts/test-all.sh")"
check "6f output captured on the host" "yes" "$(has "$(store)/results/j1/log" "running tests")"
check "6g store never handed to docker" "no" "$(has "$TMP/docker.log" "$DELAY_HOME")"

queue_raw j3 tests-full; FAKE_RC=3 dispatch >/dev/null
check "7a non-zero exit -> failed" "failed" "$(meta j3 status)"
check "7b exit code kept" "3" "$(meta j3 exit)"

echo "changed" >> "$P/tests/one.test"
queue_raw j4 tests-full; dispatch >/dev/null
check "8a test code change still runs" "passed" "$(meta j4 status)"
cp "$P/compose.yml" "$TMP/compose.bak"; echo "# privileged: true" >> "$P/compose.yml"
queue_raw j5 tests-full; dispatch >/dev/null
check "8b compose change -> needs-reapproval" "needs-reapproval" "$(meta j5 status)"
check "8c docker not called on pin mismatch" "no" "$(has "$TMP/docker.log" "run")"
check "8d log names the changed file" "yes" "$(has "$(store)/results/j5/log" "changed: compose.yml")"
cp "$TMP/compose.bak" "$P/compose.yml"

queue_raw j6 nope; dispatch >/dev/null
check "9a unapproved name -> not-approved" "not-approved" "$(meta j6 status)"
queue_raw j7 ../../evil; dispatch >/dev/null
check "9b traversal name -> invalid" "invalid" "$(meta j7 status)"
queue_raw j8 ""; dispatch >/dev/null
check "9c missing job name -> invalid" "invalid" "$(meta j8 status)"
queue_raw j9 tests-full; sed "s|^project=.*|project=$TMP/other|" "$(store)/queue/j9.job" > "$TMP/j9" && mv "$TMP/j9" "$(store)/queue/j9.job"
dispatch >/dev/null
check "9d project.path mismatch -> invalid" "invalid" "$(meta j9 status)"
queue_raw j10 tests-full; FAKE_DOCKER_INFO=1 dispatch >/dev/null
check "9e docker down -> docker-unavailable" "docker-unavailable" "$(meta j10 status)"

approve slow --compose compose.yml --service app --wrapper scripts/test-all.sh --timeout 1 >/dev/null
queue_raw j11 slow; FAKE_SLEEP=6 dispatch >/dev/null
check "9f timeout kills and records" "timeout" "$(meta j11 status)"
check "9g timeout removes the container by name" "yes" "$(has "$TMP/docker.log" "rm -f claude-delay-j11")"

mv "$P" "$TMP/proj.moved"
queue_raw j12 tests-full; dispatch >/dev/null
check "9h project gone -> project-missing" "project-missing" "$(meta j12 status)"
mv "$TMP/proj.moved" "$P"

mkdir -p "$DELAY_HOME/.lock"; sleep 30 & holder=$!; echo $holder > "$DELAY_HOME/.lock/pid"
queue_raw j13 tests-full; dispatch >/dev/null
check "10a live lock holder -> no run" "yes" "$([ -f "$(store)/queue/j13.job" ] && echo yes || echo no)"
kill $holder 2>/dev/null; wait $holder 2>/dev/null
dispatch >/dev/null
check "10b stale lock reclaimed" "passed" "$(meta j13 status)"
check "10c lock released" "no" "$([ -d "$DELAY_HOME/.lock" ] && echo yes || echo no)"

for i in $(seq 1 25); do queue_raw "r$(printf %02d "$i")" tests-full; done
dispatch >/dev/null
check "11a retention keeps $DELAY_KEEP_RESULTS" "$DELAY_KEEP_RESULTS" "$(ls "$(store)/results" | wc -l | tr -d ' ')"
check "11b keeps the newest" "yes" "$([ -d "$(store)/results/r25" ] && echo yes || echo no)"
check "11c list shows results" "yes" "$(l="$(client list)"; echo "$l" | grep -q 'r25  tests-full.*passed' && echo yes || echo no)"
check "11d show a result" "status=passed" "$(client show r25 | grep '^status=')"

echo "== install =="
UH="$TMP/uhome"
inst() { SUDO_USER=nobody DELAY_USER_HOME="$UH" bash "$S/install.sh" "$@" 2>&1; }
: > "$TMP/launchctl.log"
before="$(window_conf)"
out="$(inst)"; rc=$?
check "13a install succeeds" "0" "$rc"
check "13a2 re-install keeps the existing window" "$before" "$(window_conf)"
rm -f "$WINFILE"; inst >/dev/null
check "13a3 first install: default run-at 03:00 for 4h" "03:00 4" "$(window_conf)"
inst --run-at 02:30 >/dev/null
check "13a4 --run-at sets the time, keeps the length" "02:30 4" "$(window_conf)"
inst --hours 2 >/dev/null
check "13a5 --hours sets the length, keeps the time" "02:30 2" "$(window_conf)"
check "13a6 bad --run-at refused" "1:02:30 2" "$(inst --run-at 25:00 >/dev/null; echo $?):$(window_conf)"
check "13a7 unknown option refused" "1" "$(inst --bogus >/dev/null; echo $?)"
out="$(inst)"
check "13a8 install reports the window" "yes" "$(echo "$out" | grep -q "run window: 02:30 for 2h" && echo yes || echo no)"
check "13a9 install shows the job list with IDs" "yes" "$(echo "$out" | grep -q "^  $(job_id "$P" tests-full)  tests-full  *approved" && echo yes || echo no)"
SYS="$DELAY_INSTALL_PREFIX/Library/Application Support/claude-delay"
BIN="$SYS/bin"; AP="$SYS/com.claude-delay.dispatch.plist"
check "13b copies the scripts" "yes" "$(cmp -s "$S/start.sh" "$BIN/start.sh" && echo yes || echo no)"
check "13c installed.conf written" "yes" "$([ -f "$BIN/installed.conf" ] && echo yes || echo no)"
check "13d runner plist runs the installed copy" "yes" "$(has "$AP" "$BIN/dispatch.sh")"
check "13e nothing in LaunchAgents (would load at every login)" "no" "$([ -e "$DELAY_INSTALL_PREFIX/Library/LaunchAgents" ] && echo yes || echo no)"
check "13f nothing in LaunchDaemons" "no" "$([ -e "$DELAY_INSTALL_PREFIX/Library/LaunchDaemons" ] && echo yes || echo no)"
check "13g install loads nothing" "0" "$(grep -c bootstrap "$TMP/launchctl.log" | tr -d ' ')"
check "13h status sees the install" "installed_current=yes" "$(bash "$S/delay.sh" status | grep installed_current)"
check "13h2 default check interval is 1 min" "interval_min=1" "$(bash "$S/delay.sh" status | grep interval_min)"
out="$(inst --interval 5)"
check "13h3 --interval 5 -> StartInterval 300" "yes" "$(has "$AP" "<key>StartInterval</key><integer>300</integer>")"
check "13h4 status shows it" "interval_min=5" "$(bash "$S/delay.sh" status | grep interval_min)"
check "13h5 bad interval refused" "1" "$(inst --interval 0 >/dev/null; echo $?)"
echo "# drift" >> "$BIN/dispatch.sh"
check "13i status spots an outdated copy" "installed_current=no" "$(bash "$S/delay.sh" status | grep installed_current)"
cp "$S/dispatch.sh" "$BIN/dispatch.sh"
mkdir -p "$TMP/evilreg"
check "13j installed copy ignores DELAY_REGISTRY" "$SYS/registry" \
  "$(DELAY_REGISTRY="$TMP/evilreg" bash -c ". \"$BIN/lib.sh\"; echo \"\$DELAY_REGISTRY\"")"
check "13k installed copy ignores DELAY_AS_ROOT" "$([ "$(id -u)" = 0 ] && echo root || echo user)" \
  "$(DELAY_AS_ROOT=1 bash -c ". \"$BIN/lib.sh\"; is_root && echo root || echo user")"
cp "$S/install.sh" "$BIN/"
check "13l install from an installed copy refused" "1" "$(SUDO_USER=nobody DELAY_USER_HOME="$UH" bash "$BIN/install.sh" >/dev/null 2>&1; echo $?)"
rm -f "$BIN/install.sh"
check "13m refuses without sudo context" "1" "$(DELAY_USER_HOME="$UH" SUDO_USER= bash "$S/install.sh" >/dev/null 2>&1; echo $?)"

echo "== start (the human arms the runner) =="
st() { : > "$TMP/pmset.log"; : > "$TMP/launchctl.log"; DELAY_AS_ROOT=1 SUDO_USER=nobody DELAY_USER_HOME="$UH" bash "$S/start.sh" "$@" 2>&1; }
schedules() { grep -c 'schedule wake' "$TMP/pmset.log" | tr -d ' '; }
rm -rf "$(store)/queue"/* "$DELAY_HOME/armed"
win 13:00 2
W="$(fmt_epoch $((NOW + 3600 + 30)) "%m/%d/%y %H:%M:%S")"
mv "$AP" "$AP.bak"
check "14a not installed -> refused" "1" "$(st >/dev/null; echo $?)"
mv "$AP.bak" "$AP"
out="$(st)"; rc=$?
check "14b nothing queued -> nothing started" "0:0" "$rc:$(grep -c bootstrap "$TMP/launchctl.log" | tr -d ' ')"
queue_raw s3 nope; out="$(st)"
check "14c only unapproved queued -> nothing started" "yes" "$(echo "$out" | grep -q 'nothing approved' && echo yes || echo no)"
rm -f "$WINFILE"; queue_raw s1 tests-full
check "14d no window -> refused" "1" "$(st >/dev/null; echo $?)"
win 13:00 2
out="$(st)"; rc=$?
check "14e start succeeds" "0" "$rc"
check "14f wake 30s after the window opens, with our owner" "yes" "$(has "$TMP/pmset.log" "schedule wake $W claude-delay")"
check "14g loads the runner into the user's gui domain" "yes" "$(has "$TMP/launchctl.log" "bootstrap gui/$(id -u nobody) $AP")"
check "14h armed for the window" "$((NOW + 3600)) $((NOW + 10800))" "$(kv start "$DELAY_HOME/armed") $(kv end "$DELAY_HOME/armed")"
check "14i never cancelall" "no" "$(has "$TMP/pmset.log" cancelall)"
out="$(FAKE_LOADED=0 st)"
check "14j again: no second wake, no second load" "0:0" "$(schedules):$(grep -c bootstrap "$TMP/launchctl.log" | tr -d ' ')"
win 14:00 2; out="$(FAKE_LOADED=0 st)"
check "14k window moved -> old wake cancelled" "yes" "$(has "$TMP/pmset.log" "schedule cancel wake $W claude-delay")"
check "14l ... and the new one scheduled" "yes" "$(has "$TMP/pmset.log" "schedule wake $(fmt_epoch $((NOW + 7200 + 30)) "%m/%d/%y %H:%M:%S") claude-delay")"
out="$(: > "$TMP/pmset.log"; DELAY_AS_ROOT=0 bash "$S/start.sh" 2>&1)"
check "14m without sudo: no pmset call" "0" "$(wc -l < "$TMP/pmset.log" | tr -d ' ')"
check "14n ... and says the Mac must be awake" "yes" "$(echo "$out" | grep -q 'must be awake' && echo yes || echo no)"
rm -f "$DELAY_STATE/wakes"; win 13:00 2; out="$(FAKE_PMSET_RC=1 st)"
check "14o pmset refused -> warned, not recorded" "yes:0" "$(echo "$out" | grep -q 'pmset refused' && echo yes || echo no):$(wc -c < "$DELAY_STATE/wakes" | tr -d ' ')"
win 11:00 4; out="$(st)"
check "14p window already open -> no wake needed" "0" "$(schedules)"

echo "== reminder (Claude relays it to the user) =="
win 13:00 2; rm -f "$DELAY_HOME/armed" "$(store)/queue/s3.job"      # s3 (unapproved) would rightly ask for approval
out="$(client add tests-full)"
check "15a not started -> ACTION FOR THE USER" "yes" "$(echo "$out" | grep -q '^ACTION FOR THE USER' && echo yes || echo no)"
check "15b names the start command" "yes" "$(echo "$out" | grep -q 'bin/start.sh' && echo yes || echo no)"
st >/dev/null
out="$(FAKE_LOADED=0 client list)"
check "15c started and loaded -> no action asked" "no" "$(echo "$out" | grep -q 'ACTION FOR THE USER' && echo yes || echo no)"
out="$(FAKE_LOADED=1 client list)"
check "15d armed but not loaded -> asks again" "yes" "$(echo "$out" | grep -q 'ACTION FOR THE USER' && echo yes || echo no)"
check "15e status reports the runner" "runner=started" "$(FAKE_LOADED=0 bash "$S/delay.sh" status | grep '^runner=')"
queue_raw s9 nope; out="$(FAKE_LOADED=0 client list)"
check "15f started, but an unapproved job queued -> asks to approve it, not to start" "yes:no" "$(echo "$out" | grep -q " nope --compose" && echo yes || echo no):$(echo "$out" | grep -q "bin/start.sh" && echo yes || echo no)"
rm -f "$(store)/queue/s9.job"

echo "== runner unloads itself =="
: > "$TMP/launchctl.log"; dispatch >/dev/null
check "16a before the window, jobs waiting -> stays loaded" "0" "$(grep -c bootout "$TMP/launchctl.log" | tr -d ' ')"
DELAY_NOW=$((NOW + 3600)) dispatch >/dev/null
check "16b in the window: runs the queue" "0" "$(ls "$(store)/queue" | wc -l | tr -d ' ')"
check "16c ... then unloads itself" "yes" "$(has "$TMP/launchctl.log" "bootout gui/$(id -u)/com.claude-delay.dispatch")"
check "16d ... and disarms" "no" "$([ -f "$DELAY_HOME/armed" ] && echo yes || echo no)"
queue_raw u1 tests-full; st >/dev/null; : > "$TMP/launchctl.log"
DELAY_NOW=$((NOW + 3600 + 7200)) dispatch >/dev/null
check "16e window over, Mac never woke -> unloads" "yes" "$(has "$TMP/launchctl.log" bootout)"
check "16f ... the job stays queued for the next start" "yes" "$([ -f "$(store)/queue/u1.job" ] && echo yes || echo no)"
out="$(client list)"
check "16g ... and Claude is told to ask again" "yes" "$(echo "$out" | grep -q 'ACTION FOR THE USER' && echo yes || echo no)"

echo "== --awake (keep the Mac awake until the jobs are done) =="
win 13:00 2; rm -f "$DELAY_HOME/armed"; for f in "$(store)"/queue/*.job; do [ -f "$f" ] && rm -f "$f"; done
queue_raw a1 tests-full
out="$(st --awake)"
check "19a start --awake arms it" "1" "$(kv awake "$DELAY_HOME/armed")"
check "19b ... and says so" "yes" "$(echo "$out" | grep -q 'keeping the Mac awake' && echo yes || echo no)"
check "19c bad option refused" "1" "$(st --bogus >/dev/null; echo $?)"
: > "$TMP/caffeinate.log"; dispatch >/dev/null
check "19d first tick starts caffeinate -i -s, capped at the window end" "-i -s -t 10800" "$(head -1 "$TMP/caffeinate.log")"
APID="$(cat "$DELAY_HOME/awake.pid" 2>/dev/null)"
check "19e ... and it keeps running after the tick" "yes" "$(kill -0 "$APID" 2>/dev/null && echo yes || echo no)"
dispatch >/dev/null
check "19f next tick does not start a second one" "1" "$(grep -c -- '-t ' "$TMP/caffeinate.log" | tr -d ' ')"
DELAY_NOW=$((NOW + 3600)) dispatch >/dev/null
check "19g queue done -> runner unloads and releases it" "no:no" \
  "$(kill -0 "$APID" 2>/dev/null && echo yes || echo no):$([ -f "$DELAY_HOME/awake.pid" ] && echo yes || echo no)"
queue_raw a2 tests-full; st >/dev/null; : > "$TMP/caffeinate.log"; dispatch >/dev/null
check "19h without --awake: no caffeinate hold" "0" "$(grep -c -- '-t ' "$TMP/caffeinate.log" | tr -d ' ')"
echo 999999 > "$DELAY_HOME/awake.pid"; sleep 30 & OTHER=$!; echo $OTHER > "$DELAY_HOME/awake.pid"
DELAY_NOW=$((NOW + 3600)) dispatch >/dev/null
check "19i never kills a pid that is not our caffeinate" "yes" "$(kill -0 $OTHER 2>/dev/null && echo yes || echo no)"
kill $OTHER 2>/dev/null; wait $OTHER 2>/dev/null

check "19j default without install --awake: sleeps" "awake_default=no" "$(bash "$S/delay.sh" status | grep awake_default)"
out="$(inst --awake)"
check "19k install --awake sets the default" "awake_default=yes:yes" \
  "$(bash "$S/delay.sh" status | grep awake_default):$(echo "$out" | grep -q 'start.sh keeps the Mac awake' && echo yes || echo no)"
inst >/dev/null
check "19l re-install without the flag keeps it" "awake_default=yes" "$(bash "$S/delay.sh" status | grep awake_default)"
rm -f "$DELAY_HOME/armed"; queue_raw a3 tests-full; st >/dev/null
check "19m start with no flag follows the default" "1" "$(kv awake "$DELAY_HOME/armed")"
st --no-awake >/dev/null
check "19n start --no-awake overrides it for one night" "" "$(kv awake "$DELAY_HOME/armed")"
inst --no-awake >/dev/null
check "19o install --no-awake turns the default off" "awake_default=no" "$(bash "$S/delay.sh" status | grep awake_default)"
rm -f "$(store)/queue/a3.job" "$DELAY_HOME/armed"

echo "== uninstall =="
echo "$W" > "$DELAY_STATE/wakes"; : > "$TMP/pmset.log"; : > "$TMP/launchctl.log"
out="$(inst --uninstall)"
check "17a unloads the runner" "yes" "$(has "$TMP/launchctl.log" bootout)"
check "17b cancels our wake" "yes" "$(has "$TMP/pmset.log" "schedule cancel wake $W claude-delay")"
check "17c removes plist and scripts" "no" "$([ -f "$AP" ] || [ -d "$BIN" ] && echo yes || echo no)"
check "17d keeps the registry" "yes" "$([ -f "$JF" ] && echo yes || echo no)"

echo "== conventions =="
scan() { grep -nE "$1" "$S"/*.sh 2>/dev/null | grep -v '/test/' || true; }
check "14a no sed -i" "" "$(scan 'sed -i')"
check "14b no associative arrays" "" "$(scan 'declare -A')"
check "14c env shebangs only" "" "$(grep -L '^#!/usr/bin/env bash' "$S"/*.sh)"
check "14d never cancelall outside comments" "" "$(scan cancelall | grep -vE "^[^:]*:[0-9]+:[[:space:]]*#")"

echo
echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
