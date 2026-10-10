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
says() { echo "$1" | grep -q -- "$2" && echo yes || echo no; }        # says <output> <regex>
saysf() { printf "%s\n" "$1" | grep -qF -- "$2" && echo yes || echo no; }   # saysf <output> <fixed text>

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
  *" run "*)    printf '[%s]\n' "$@" > "$SHIM_LOG/argv.log"   # one word per line: argv, exactly
                echo "running tests"; sleep "${FAKE_SLEEP:-0}"; exit "${FAKE_RC:-0}" ;;
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

# project fixture: compose + Dockerfile + scripts + test code
P="$TMP/proj"; mkdir -p "$P/scripts" "$P/tests"
echo "services: {app: {build: .}}" > "$P/compose.yml"
echo "FROM alpine" > "$P/Dockerfile"
printf '#!/bin/sh\nrun-tests\n' > "$P/scripts/test-all.sh"
for s in nope risky slow prop prop2 other; do printf '#!/bin/sh\necho %s\n' "$s" > "$P/scripts/$s.sh"; done
echo "test one" > "$P/tests/one.test"

approve() { bash "$S/approve.sh" "$P" "$@" --yes 2>&1; }
client() { bash "$S/delay.sh" --project "$P" "$@" 2>&1; }
store() { echo "$DELAY_HOME/$(encode_path "$P")"; }
regdir() { echo "$DELAY_REGISTRY/$(encode_path "$P")/jobs"; }
pid_of() { job_id "$P" "$(pair_id compose.yml "${2:-app}" "$1")"; }     # pid_of <script> [service] -> approve ID
queue_raw() { # queue_raw <id> <script> [param...] — a queue entry written behind the client's back
    local id="$1" sc="$2" a; shift 2
    mkdir -p "$(store)/queue"; echo "$P" > "$(store)/project.path"
    {
        printf 'id=%s\nproject=%s\ncreated=%s\ncompose=compose.yml\nservice=app\nscript=%s\n' "$id" "$P" "$NOW" "$sc"
        for a in "$@"; do printf 'arg=%s\n' "$a"; done
    } > "$(store)/queue/$id.job"
}
queued() { ls "$(store)/queue" 2>/dev/null | wc -l | tr -d ' '; }
cleanq() { for f in "$(store)"/queue/*.job; do [ -f "$f" ] && rm -f "$f"; done; }
win() { bash "$S/approve.sh" --window "$@" >/dev/null 2>&1; }      # the human sets the window
WINFILE="$DELAY_INSTALL_PREFIX/Library/Application Support/claude-delay/window"
dispatch() { : > "$TMP/docker.log"; : > "$TMP/argv.log"; bash "$S/dispatch.sh" 2>&1; }
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
check "2g rel_inside normalises" "scripts/test-all.sh" "$(rel_inside "$P" ./tests/../scripts/test-all.sh)"
check "2h pair_id is a valid name" "yes" "$(valid_name "$(pair_id compose.yml app scripts/test-all.sh)" && echo yes || echo no)"
check "2i pair_id differs per service" "no" "$([ "$(pair_id c a s)" = "$(pair_id c b s)" ] && echo yes || echo no)"

echo "== approve =="
out="$(approve scripts/test-all.sh --compose compose.yml --service app)"
PAIR="$(pair_id compose.yml app scripts/test-all.sh)"; JF="$(regdir)/$PAIR"; TID="$(pid_of scripts/test-all.sh)"
check "3a approves the pair" "yes" "$(says "$out" '^approved scripts/test-all.sh')"
check "3b pins compose" "yes" "$(has "$JF" "pin=compose.yml ")"
check "3c pins the script" "yes" "$(has "$JF" "pin=scripts/test-all.sh ")"
check "3d auto-pins Dockerfile" "yes" "$(has "$JF" "pin=Dockerfile ")"
check "3e does not pin test code" "no" "$(has "$JF" "tests/")"
check "3f command defaults to the script" "scripts/test-all.sh" "$(kv command "$JF")"
check "3g project.path recorded" "$P" "$(cat "$DELAY_REGISTRY/$(encode_path "$P")/project.path")"
before="$(ls -i "$JF")"; approve scripts/test-all.sh --compose compose.yml --service app >/dev/null
check "3h re-approve unchanged leaves file untouched" "$before" "$(ls -i "$JF")"
check "3i script outside project refused" "1" "$(approve ../etc.sh --compose compose.yml --service app >/dev/null; echo $?)"
check "3j pin outside project refused" "1" "$(approve scripts/test-all.sh --compose compose.yml --service app --pin ../../etc/hosts >/dev/null; echo $?)"
check "3k a script that is not .sh refused" "1" "$(approve compose.yml --compose compose.yml --service app >/dev/null; echo $?)"
check "3l bad service name refused" "1" "$(approve scripts/test-all.sh --compose compose.yml --service 'a b' >/dev/null; echo $?)"
check "3m the script is recorded" "scripts/test-all.sh" "$(kv script "$JF")"

printf 'services:\n  app:\n    privileged: true\n    volumes:\n      - type: bind\n        source: /var/run/docker.sock\n        target: /s\n      - type: bind\n        source: %s/src\n        target: /app\n      - type: bind\n        source: /Users\n        target: /u\n    network_mode: host\n' "$P" > "$TMP/risky.yml"
RJF="$(regdir)/$(pair_id compose.yml app scripts/risky.sh)"
out="$(FAKE_COMPOSE_CONFIG="$TMP/risky.yml" approve scripts/risky.sh --compose compose.yml --service app)"; rc=$?
check "4a red flags refuse" "1" "$rc"
check "4b flags privileged" "yes" "$(says "$out" 'privileged container')"
check "4c flags docker socket" "yes" "$(says "$out" 'docker socket')"
check "4d flags host mount outside project" "yes" "$(says "$out" 'outside the project: /Users$')"
check "4e project mount is not a flag" "no" "$(says "$out" "outside the project: $P/src")"
check "4f flags host network" "yes" "$(says "$out" 'host namespace')"
check "4g nothing written on refusal" "no" "$([ -f "$RJF" ] && echo yes || echo no)"
FAKE_COMPOSE_CONFIG="$TMP/risky.yml" approve scripts/risky.sh --compose compose.yml --service app --accept-risks >/dev/null
check "4h --accept-risks approves" "yes" "$([ -f "$RJF" ] && echo yes || echo no)"
bash "$S/approve.sh" --revoke "$(pid_of scripts/risky.sh)" >/dev/null 2>&1
check "4i revoke by ID" "no" "$([ -f "$RJF" ] && echo yes || echo no)"
check "4j --list shows the approved pair with its ID" "yes" "$(l="$(bash "$S/approve.sh" --list)"; says "$l" "^  $TID  scripts/test-all.sh  *approved *compose.yml / app / scripts/test-all.sh")"

echo "== param-as-command scan (approve) =="
scan_try() { # scan_try <name> <body> -> approve output; rc in $SCAN_RC
    printf '#!/bin/sh\n%s\n' "$2" > "$P/scripts/$1.sh"
    out="$(approve "scripts/$1.sh" --compose compose.yml --service app)"; SCAN_RC=$?
}
scan_try s-eval 'eval "$1"'
check "21a eval refused, the line named" "1:yes" "$SCAN_RC:$(says "$out" 'line 2')"
scan_try s-shc 'sh -c "$1"'
check "21b sh -c with a param refused" "1" "$SCAN_RC"
scan_try s-bashc 'bash -lc "run $*"'
check "21c bash -lc with a param refused" "1" "$SCAN_RC"
scan_try s-npm 'npm run "$1"'
check "21d npm run <param> refused" "1" "$SCAN_RC"
scan_try s-make 'cd app && make $1'
check "21e make <param> refused" "1" "$SCAN_RC"
scan_try s-cmdpos 'set -e; "$@"'
check "21f a param in command position refused" "1" "$SCAN_RC"
scan_try s-then 'if true; then $1; fi'
check "21g ... also after then" "1" "$SCAN_RC"
scan_try s-source '. "$1"'
check "21h sourcing a param refused" "1" "$SCAN_RC"
scan_try s-clean 'case "${1:-full}" in full) run-tests ;; smoke) run-tests -k smoke ;; *) echo "unknown: $1" >&2; exit 2 ;; esac
pytest "$@"'
check "21i params used as data pass" "0" "$SCAN_RC"
scan_try s-comment '# never: eval "$1" or sh -c "$1"
echo ok'
check "21j a comment is not a flag" "0" "$SCAN_RC"
scan_try s-risk 'eval "$1"'
out="$(approve scripts/s-risk.sh --compose compose.yml --service app --accept-risks)"
check "21k --accept-risks approves it anyway" "yes" "$(says "$out" '^approved')"
for s in s-clean s-comment s-risk; do bash "$S/approve.sh" --revoke "$(pid_of "scripts/$s.sh")" >/dev/null 2>&1; done

echo "== client =="
win 03:00 4
out="$(client add scripts/test-all.sh)"; rc=$?
check "5a add an approved script" "0" "$rc"
ID="$(echo "$out" | awk '/^queued/ { sub(/:$/, "", $2); print $2 }')"
check "5b queue entry holds no time" "no" "$(has "$(store)/queue/$ID.job" "run_at")"
check "5c queue entry holds no command" "no" "$(has "$(store)/queue/$ID.job" "command=")"
check "5c2 the container came from the one approval" "compose.yml app" "$(kv compose "$(store)/queue/$ID.job") $(kv service "$(store)/queue/$ID.job")"
check "5d add tells the window" "yes" "$(says "$out" 'window: 03:00 for 4h — next 2026-10-04 03:00')"
check "5e reminder asks the user to install and start" "yes:yes" "$(says "$out" "^ACTION FOR THE USER"):$(says "$out" "install.sh")"
check "5e2 ... with the full, quoted path to copy" "yes" "$(saysf "$out" "  sudo bash \"$S/install.sh\"        (once)")"
out="$(client add scripts/test-all.sh 13:00)"; rc=$?
check "5f a time argument is refused" "1" "$rc"
check "5g refusal points at the user's window" "yes" "$(says "$out" "user's run window")"
out="$(client add scripts/test-all.sh)"; rc=$?
check "5h duplicate add is not queued twice" "1" "$(queued)"
check "5i duplicate add is OK and names the existing id" "0:yes" "$rc:$(says "$out" "already queued $ID: .*not added again")"
out="$(client add scripts/nope.sh --compose compose.yml --service app)"; rc=$?
check "5j unapproved pair is still queued" "0:yes" "$rc:$(says "$out" "(not approved yet)")"
check "5k the note gives approve <ID>" "yes" "$(says "$out" "approve.sh\" $(pid_of scripts/nope.sh) ")"
out="$(client add scripts/other.sh)"; rc=$?
check "5k2 unapproved script, no container named -> refused, asks for one" "1:yes" "$rc:$(says "$out" "--compose FILE --service NAME")"
mkdir -p "$TMP/other/scripts"; cp "$P/compose.yml" "$P/scripts/test-all.sh" "$TMP/other/" 2>/dev/null; cp "$P/scripts/test-all.sh" "$TMP/other/scripts/"
out="$(bash "$S/delay.sh" --project "$TMP/other" add scripts/test-all.sh --compose compose.yml --service app 2>&1)"; rc=$?
check "5l another project: approval there is separate" "0:yes" "$rc:$(says "$out" "(not approved yet)")"
rm -rf "$DELAY_HOME/$(encode_path "$TMP/other")"
for f in "$(store)"/queue/*.job; do [ "$(kv script "$f")" = scripts/nope.sh ] && rm -f "$f"; done
check "5m list shows the queued job" "yes" "$(l="$(client list)"; says "$l" "$ID  scripts/test-all.sh")"
check "5n list shows the window" "yes" "$(l="$(client list)"; says "$l" '^window: 03:00 for 4h')"
check "5o show a queued job" "status=queued" "$(client show "$ID" | tail -1)"
check "5p jobs lists approved pairs" "yes" "$(l="$(client jobs)"; says "$l" '^scripts/test-all.sh  *compose.yml / app')"
check "5q rm removes" "0" "$(client rm "$ID" >/dev/null; echo $?)"
check "5r rm unknown fails" "1" "$(client rm "$ID" >/dev/null; echo $?)"
check "5s rm refuses traversal" "1" "$(client rm ../x >/dev/null; echo $?)"
rm -f "$WINFILE"
check "5t no window, not installed -> install will set it" "yes" "$(l="$(bash "$S/delay.sh" status)"; says "$l" '^window: not set yet')"
check "5t2 status gives the install command, full path" "yes" "$(l="$(bash "$S/delay.sh" status)"; saysf "$l" "install_cmd=sudo bash \"$S/install.sh\"")"
win 03:00 4

echo "== params and duplicates =="
cleanq
client add scripts/test-all.sh -- full >/dev/null; client add scripts/test-all.sh -- smoke >/dev/null
check "20a different params -> two jobs" "2" "$(queued)"
cleanq
client add scripts/test-all.sh -- a b >/dev/null; out="$(client add scripts/test-all.sh -- b a)"; rc=$?
check "20b same params in another order -> one job" "1" "$(queued)"
check "20c ... the second add is OK, says already queued" "0:yes" "$rc:$(says "$out" "^already queued")"
check "20d params kept in the given order" "a b" "$(entry_args "$(store)"/queue/*.job | tr '\n' ' ' | sed 's/ $//')"
cleanq
client add scripts/test-all.sh -- filter=p1,p2 >/dev/null; client add scripts/test-all.sh -- filter=p2,p1 >/dev/null
check "20e each param compared exactly: filter=p1,p2 != filter=p2,p1" "2" "$(queued)"
cleanq
client add scripts/test-all.sh -- a >/dev/null; client add scripts/test-all.sh -- a a >/dev/null
check "20f a repeated param is a different job" "2" "$(queued)"
cleanq
client add scripts/test-all.sh >/dev/null; client add scripts/test-all.sh -- >/dev/null
check "20g an empty -- is no params" "1" "$(queued)"
cleanq
check "20h a param with a newline refused" "1" "$(client add scripts/test-all.sh -- "$(printf 'a\nb')" >/dev/null; echo $?)"
check "20i an empty param refused" "1" "$(client add scripts/test-all.sh -- "" >/dev/null; echo $?)"
check "20j 65 params refused" "1" "$(client add scripts/test-all.sh -- $(seq 1 65) >/dev/null; echo $?)"
check "20k 64 params accepted" "0" "$(client add scripts/test-all.sh -- $(seq 1 64) >/dev/null; echo $?)"
cleanq
big="$(printf '%04100d' 0)"
check "20l more than 4096 bytes refused" "1" "$(client add scripts/test-all.sh -- "$big" >/dev/null; echo $?)"
check "20m nothing queued by the refusals" "0" "$(queued)"
check "20n a non-.sh script refused" "1" "$(client add compose.yml --compose compose.yml --service app >/dev/null; echo $?)"
check "20o a script outside the project refused" "1" "$(client add ../x.sh --compose compose.yml --service app >/dev/null; echo $?)"
check "20p a missing script refused" "1" "$(client add scripts/missing.sh --compose compose.yml --service app >/dev/null; echo $?)"
out="$(client add scripts/test-all.sh -- 'x y' '*')"
check "20q list shows the params" "yes" "$(l="$(client list)"; says "$l" "scripts/test-all.sh x y \*")"
cleanq
approve scripts/test-all.sh --compose compose.yml --service app2 >/dev/null
out="$(client add scripts/test-all.sh)"; rc=$?
check "20r one script, two containers, none named -> refused with both" "1:yes:yes" "$rc:$(says "$out" '/ app$')":"$(says "$out" '/ app2$')"
check "20s ... naming one queues it" "0" "$(client add scripts/test-all.sh --service app2 --compose compose.yml >/dev/null; echo $?)"
cleanq; bash "$S/approve.sh" --revoke "$(pid_of scripts/test-all.sh app2)" >/dev/null 2>&1

echo "== approval by ID =="
AP_="$S/approve.sh"
cleanq
out="$(DELAY_HOME="$TMP/emptyhome" DELAY_REGISTRY="$TMP/emptyreg" bash "$AP_")"
check "18a nothing anywhere -> says so" "No jobs yet: nothing approved, nothing waiting." "$out"
PID_="$(pid_of scripts/prop.sh)"
out="$(client add scripts/prop.sh --compose compose.yml --service app --timeout 900)"; rc=$?
check "18b add of an unapproved pair queues it" "0:yes" "$rc:$(says "$out" 'scripts/prop.sh.*(not approved yet)')"
check "18c the note gives approve <ID>" "yes" "$(says "$out" "approve.sh\" $PID_ ")"
check "18d the note points at the full list" "yes" "$(says "$out" '(all projects and jobs: sudo')"
out="$(bash "$AP_")"
check "18e list: project, ID, WAITING, the pair" "yes" "$(says "$out" "^  $PID_  scripts/prop.sh  *WAITING for approval *compose.yml / app")"
check "18f list shows the project path" "yes" "$(echo "$out" | grep -qx "$P" && echo yes || echo no)"
check "18g list shows approved pairs with their ID" "yes" "$(says "$out" "^  $TID  scripts/test-all.sh  *approved")"
out="$(bash "$AP_" "$PID_" --yes)"; rc=$?
check "18h approve by ID" "0" "$rc"
PJ="$(regdir)/$(pair_id compose.yml app scripts/prop.sh)"
check "18i ... registry gets the pair and the proposed timeout" "app|scripts/prop.sh|900" "$(kv service "$PJ")|$(kv script "$PJ")|$(kv timeout "$PJ")"
check "18j ... and lists it approved" "yes" "$(l="$(bash "$AP_")"; says "$l" "^  $PID_  scripts/prop.sh  *approved")"
out="$(client add scripts/prop.sh -- again)"
check "18k approved -> no approve line in the note" "no" "$(says "$out" "approve.sh\" $PID_")"
cleanq
client add scripts/prop2.sh --compose compose.yml --service app >/dev/null
out="$(client add scripts/prop2.sh --compose compose.yml --service app --timeout 60)"
check "18n re-add with --timeout updates the queued proposal" "yes:1:60" \
  "$(says "$out" 'proposal updated'):$(queued):$(kv proposed_timeout "$(store)"/queue/*.job)"
echo "# edited" >> "$P/scripts/prop.sh"
check "18q pinned file changed -> list says re-approve" "yes" "$(l="$(bash "$AP_")"; says "$l" "^  $PID_  scripts/prop.sh  *CHANGED, re-approve")"
check "18r re-approve by the same ID" "0" "$(bash "$AP_" "$PID_" --yes >/dev/null 2>&1; echo $?)"
check "18s ... approved again" "yes" "$(l="$(bash "$AP_")"; says "$l" "^  $PID_  scripts/prop.sh  *approved")"
check "18t revoke by ID" "0:no" "$(bash "$AP_" --revoke "$PID_" >/dev/null 2>&1; echo $?):$([ -f "$PJ" ] && echo yes || echo no)"
check "18u unknown ID refused" "1" "$(bash "$AP_" abcdef --yes >/dev/null 2>&1; echo $?)"
check "18v container half-named refused" "1" "$(client add scripts/prop.sh --compose compose.yml >/dev/null; echo $?)"
check "18w compose outside the project refused" "1" "$(client add scripts/prop.sh --compose ../c.yml --service app >/dev/null; echo $?)"
RID="$(pid_of scripts/risky.sh)"
client add scripts/risky.sh --compose compose.yml --service app >/dev/null
check "18x approve <ID> still refuses red flags" "1" "$(FAKE_COMPOSE_CONFIG="$TMP/risky.yml" bash "$AP_" "$RID" --yes >/dev/null 2>&1; echo $?)"
cleanq

echo "== dispatch =="
queue_raw j0 scripts/test-all.sh
win() { bash "$S/approve.sh" --window "$@" >/dev/null 2>&1; }
rm -f "$WINFILE"; dispatch >/dev/null
check "6a no window set -> nothing starts" "yes" "$([ -f "$(store)/queue/j0.job" ] && echo yes || echo no)"
win 13:00 2; dispatch >/dev/null
check "6b outside the window -> nothing starts" "yes" "$([ -f "$(store)/queue/j0.job" ] && echo yes || echo no)"
check "6c docker untouched outside the window" "0" "$(wc -c < "$TMP/docker.log" | tr -d ' ')"
rm -f "$(store)/queue/j0.job"
win 11:00 4
queue_raw j1 scripts/test-all.sh; dispatch >/dev/null
check "6d inside the window -> passed" "passed" "$(meta j1 status)"
check "6e docker compose run invoked" "yes" "$(has "$TMP/docker.log" "compose -f compose.yml run --rm -T --name claude-delay-j1 app scripts/test-all.sh")"
check "6f output captured on the host" "yes" "$(has "$(store)/results/j1/log" "running tests")"
check "6g store never handed to docker" "no" "$(has "$TMP/docker.log" "$DELAY_HOME")"
queue_raw jp scripts/test-all.sh 'a b' '*' '$(id)'; dispatch >/dev/null
check "6h params reach the container as argv words, unglobbed, unexpanded" "[app]|[scripts/test-all.sh]|[a b]|[*]|[\$(id)]" \
  "$(awk 'f { printf "%s|", $0 } $0 == "[claude-delay-jp]" { f = 1 }' "$TMP/argv.log" | sed 's/|$//')"
check "6i the result keeps the params" "yes" "$(has "$(store)/results/jp/meta" "arg=a b")"
queue_raw jc scripts/test-all.sh; printf 'command=evil\nproposed_command=evil\n' >> "$(store)/queue/jc.job"; dispatch >/dev/null
check "6j the registry's command runs, never the queue's" "no:passed" "$(has "$TMP/docker.log" evil):$(meta jc status)"

queue_raw j3 scripts/test-all.sh; FAKE_RC=3 dispatch >/dev/null
check "7a non-zero exit -> failed" "failed" "$(meta j3 status)"
check "7b exit code kept" "3" "$(meta j3 exit)"

echo "changed" >> "$P/tests/one.test"
queue_raw j4 scripts/test-all.sh; dispatch >/dev/null
check "8a test code change still runs" "passed" "$(meta j4 status)"
cp "$P/compose.yml" "$TMP/compose.bak"; echo "# privileged: true" >> "$P/compose.yml"
queue_raw j5 scripts/test-all.sh; dispatch >/dev/null
check "8b compose change -> needs-reapproval" "needs-reapproval" "$(meta j5 status)"
check "8c docker not called on pin mismatch" "no" "$(has "$TMP/docker.log" "run")"
check "8d log names the changed file" "yes" "$(has "$(store)/results/j5/log" "changed: compose.yml")"
cp "$TMP/compose.bak" "$P/compose.yml"

queue_raw j6 scripts/nope.sh; dispatch >/dev/null
check "9a unapproved pair -> not-approved" "not-approved" "$(meta j6 status)"
queue_raw j7 ""; dispatch >/dev/null
check "9b missing script -> invalid" "invalid" "$(meta j7 status)"
mkdir -p "$(store)/queue"; printf 'id=j8\nproject=%s\njob=tests-full\ncreated=%s\n' "$P" "$NOW" > "$(store)/queue/j8.job"; dispatch >/dev/null
check "9c a 1.x entry (job name only) -> invalid, says re-queue" "invalid:yes" "$(meta j8 status):$(has "$(store)/results/j8/log" "delay 1.x")"
queue_raw j9 scripts/test-all.sh; sed "s|^project=.*|project=$TMP/other|" "$(store)/queue/j9.job" > "$TMP/j9" && mv "$TMP/j9" "$(store)/queue/j9.job"
dispatch >/dev/null
check "9d project.path mismatch -> invalid" "invalid" "$(meta j9 status)"
queue_raw j10 scripts/test-all.sh; FAKE_DOCKER_INFO=1 dispatch >/dev/null
check "9e docker down -> docker-unavailable" "docker-unavailable" "$(meta j10 status)"

approve scripts/slow.sh --compose compose.yml --service app --timeout 1 >/dev/null
queue_raw j11 scripts/slow.sh; FAKE_SLEEP=6 dispatch >/dev/null
check "9f timeout kills and records" "timeout" "$(meta j11 status)"
check "9g timeout removes the container by name" "yes" "$(has "$TMP/docker.log" "rm -f claude-delay-j11")"

mv "$P" "$TMP/proj.moved"
queue_raw j12 scripts/test-all.sh; dispatch >/dev/null
check "9h project gone -> project-missing" "project-missing" "$(meta j12 status)"
mv "$TMP/proj.moved" "$P"

mkdir -p "$DELAY_HOME/.lock"; sleep 30 & holder=$!; echo $holder > "$DELAY_HOME/.lock/pid"
queue_raw j13 scripts/test-all.sh; dispatch >/dev/null
check "10a live lock holder -> no run" "yes" "$([ -f "$(store)/queue/j13.job" ] && echo yes || echo no)"
kill $holder 2>/dev/null; wait $holder 2>/dev/null
dispatch >/dev/null
check "10b stale lock reclaimed" "passed" "$(meta j13 status)"
check "10c lock released" "no" "$([ -d "$DELAY_HOME/.lock" ] && echo yes || echo no)"

for i in $(seq 1 25); do queue_raw "r$(printf %02d "$i")" scripts/test-all.sh; done
dispatch >/dev/null
check "11a retention keeps $DELAY_KEEP_RESULTS" "$DELAY_KEEP_RESULTS" "$(ls "$(store)/results" | wc -l | tr -d ' ')"
check "11b keeps the newest" "yes" "$([ -d "$(store)/results/r25" ] && echo yes || echo no)"
check "11c list shows results" "yes" "$(l="$(client list)"; says "$l" 'r25  scripts/test-all.sh.*passed')"
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
check "13a8 install reports the window" "yes" "$(says "$out" "run window: 02:30 for 2h")"
check "13a9 install shows the job list with IDs" "yes" "$(says "$out" "^  $TID  scripts/test-all.sh  *approved")"
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
l="$(bash "$S/delay.sh" status)"
check "13h6 status gives the approve and start commands, full paths" "yes:yes" \
  "$(saysf "$l" "approve_cmd=sudo \"$SYS/bin/approve.sh\""):$(saysf "$l" "start_cmd=sudo \"$SYS/bin/start.sh\"")"
out="$(inst --interval 5)"
check "13h3 --interval 5 -> StartInterval 300" "yes" "$(has "$AP" "<key>StartInterval</key><integer>300</integer>")"
check "13h4 status shows it" "interval_min=5" "$(bash "$S/delay.sh" status | grep interval_min)"
check "13h5 bad interval refused" "1" "$(inst --interval 0 >/dev/null; echo $?)"
echo "# drift" >> "$BIN/dispatch.sh"
check "13i status spots an outdated copy" "installed_current=no" "$(bash "$S/delay.sh" status | grep installed_current)"
queue_raw q-drift scripts/test-all.sh
check "13i2 ... and the ACTION block asks for the re-install" "yes" "$(l="$(client list)"; says "$l" "install.sh.*update")"
rm -f "$(store)/queue/q-drift.job"
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

echo "== migration from 1.x (install) =="
old() { # old <name> <service> — a 1.x registry entry: named, wrapper=, pins kept
    printf 'compose=compose.yml\nservice=%s\nwrapper=scripts/test-all.sh\ncommand=bash /w/test-all.sh full\ntimeout=600\napproved_by=nobody\npin=compose.yml %s\npin=scripts/test-all.sh %s\n' \
        "$2" "$(sha256_file "$P/compose.yml")" "$(sha256_file "$P/scripts/test-all.sh")" > "$(regdir)/$1"
}
old legacy app3; old legacy2 app3
MJ="$(regdir)/$(pair_id compose.yml app3 scripts/test-all.sh)"
out="$(inst)"
check "22a the named entries are gone" "no:no" "$([ -f "$(regdir)/legacy" ] && echo yes || echo no):$([ -f "$(regdir)/legacy2" ] && echo yes || echo no)"
check "22b ... one pair file holds the approval, wrapper= -> script=" "scripts/test-all.sh|" "$(kv script "$MJ")|$(kv wrapper "$MJ")"
check "22c ... command, timeout and pins kept, so no re-approval" "bash /w/test-all.sh full|600|yes" "$(kv command "$MJ")|$(kv timeout "$MJ")|$(verify_pins "$P" "$MJ" >/dev/null && echo yes || echo no)"
check "22d ... the report names what moved and what was dropped" "yes:yes" "$(says "$out" 'migrated legacy')":"$(says "$out" 'dropped legacy2')"
out="$(inst)"
check "22e a second install migrates nothing" "no" "$(says "$out" 'migrated')"
bash "$S/approve.sh" --revoke "$(pid_of scripts/test-all.sh app3)" >/dev/null 2>&1

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
queue_raw s3 scripts/nope.sh; out="$(st)"
check "14c only unapproved queued -> nothing started" "yes" "$(says "$out" 'nothing approved')"
rm -f "$WINFILE"; queue_raw s1 scripts/test-all.sh
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
check "14n ... and says the Mac must be awake" "yes" "$(says "$out" 'must be awake')"
rm -f "$DELAY_STATE/wakes"; win 13:00 2; out="$(FAKE_PMSET_RC=1 st)"
check "14o pmset refused -> warned, not recorded" "yes:0" "$(says "$out" 'pmset refused'):$(wc -c < "$DELAY_STATE/wakes" | tr -d ' ')"
win 11:00 4; out="$(st)"
check "14p window already open -> no wake needed" "0" "$(schedules)"

echo "== reminder (Claude relays it to the user) =="
win 13:00 2; rm -f "$DELAY_HOME/armed" "$(store)/queue/s3.job"      # s3 (unapproved) would rightly ask for approval
out="$(client add scripts/test-all.sh)"
check "15a not started -> ACTION FOR THE USER" "yes" "$(says "$out" '^ACTION FOR THE USER')"
check "15b names the start command" "yes" "$(says "$out" 'bin/start.sh')"
st >/dev/null
out="$(FAKE_LOADED=0 client list)"
check "15c started and loaded -> no action asked" "no" "$(says "$out" 'ACTION FOR THE USER')"
out="$(FAKE_LOADED=1 client list)"
check "15d armed but not loaded -> asks again" "yes" "$(says "$out" 'ACTION FOR THE USER')"
check "15e status reports the runner" "runner=started" "$(FAKE_LOADED=0 bash "$S/delay.sh" status | grep '^runner=')"
queue_raw s9 scripts/nope.sh; out="$(FAKE_LOADED=0 client list)"
check "15f started, but an unapproved job queued -> asks to approve it, not to start" "yes:no" "$(says "$out" "approve.sh\" $(pid_of scripts/nope.sh) "):$(says "$out" "bin/start.sh")"
rm -f "$(store)/queue/s9.job"

echo "== runner unloads itself =="
: > "$TMP/launchctl.log"; dispatch >/dev/null
check "16a before the window, jobs waiting -> stays loaded" "0" "$(grep -c bootout "$TMP/launchctl.log" | tr -d ' ')"
DELAY_NOW=$((NOW + 3600)) dispatch >/dev/null
check "16b in the window: runs the queue" "0" "$(queued)"
check "16c ... then unloads itself" "yes" "$(has "$TMP/launchctl.log" "bootout gui/$(id -u)/com.claude-delay.dispatch")"
check "16d ... and disarms" "no" "$([ -f "$DELAY_HOME/armed" ] && echo yes || echo no)"
queue_raw u1 scripts/test-all.sh; st >/dev/null; : > "$TMP/launchctl.log"
DELAY_NOW=$((NOW + 3600 + 7200)) dispatch >/dev/null
check "16e window over, Mac never woke -> unloads" "yes" "$(has "$TMP/launchctl.log" bootout)"
check "16f ... the job stays queued for the next start" "yes" "$([ -f "$(store)/queue/u1.job" ] && echo yes || echo no)"
out="$(client list)"
check "16g ... and Claude is told to ask again" "yes" "$(says "$out" 'ACTION FOR THE USER')"

echo "== --awake (keep the Mac awake until the jobs are done) =="
win 13:00 2; rm -f "$DELAY_HOME/armed"; cleanq
queue_raw a1 scripts/test-all.sh
out="$(st --awake)"
check "19a start --awake arms it" "1" "$(kv awake "$DELAY_HOME/armed")"
check "19b ... and says so" "yes" "$(says "$out" 'keeping the Mac awake')"
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
queue_raw a2 scripts/test-all.sh; st >/dev/null; : > "$TMP/caffeinate.log"; dispatch >/dev/null
check "19h without --awake: no caffeinate hold" "0" "$(grep -c -- '-t ' "$TMP/caffeinate.log" | tr -d ' ')"
echo 999999 > "$DELAY_HOME/awake.pid"; sleep 30 & OTHER=$!; echo $OTHER > "$DELAY_HOME/awake.pid"
DELAY_NOW=$((NOW + 3600)) dispatch >/dev/null
check "19i never kills a pid that is not our caffeinate" "yes" "$(kill -0 $OTHER 2>/dev/null && echo yes || echo no)"
kill $OTHER 2>/dev/null; wait $OTHER 2>/dev/null

check "19j default without install --awake: sleeps" "awake_default=no" "$(bash "$S/delay.sh" status | grep awake_default)"
out="$(inst --awake)"
check "19k install --awake sets the default" "awake_default=yes:yes" \
  "$(bash "$S/delay.sh" status | grep awake_default):$(says "$out" 'start.sh keeps the Mac awake')"
inst >/dev/null
check "19l re-install without the flag keeps it" "awake_default=yes" "$(bash "$S/delay.sh" status | grep awake_default)"
rm -f "$DELAY_HOME/armed"; queue_raw a3 scripts/test-all.sh; st >/dev/null
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
