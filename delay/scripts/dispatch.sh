#!/usr/bin/env bash
# dispatch.sh — the runner. Loaded on demand by start.sh (the human's command) as a LaunchAgent
# that ticks every 60 s, as the user so docker (a per-user OrbStack) is reachable; launchd fires
# an overdue StartInterval tick on wake, which is what turns the pmset wake into a run.
#
# Inside the human's run window it runs the queued jobs; outside it starts nothing, so the time
# is never Claude's choice. It UNLOADS ITSELF when the queue is empty or the armed window has
# ended (jobs left over wait until the human starts the runner again) — no always-on daemon.
#
# Per queued entry: claim it (atomic mv) → re-check everything against the root-owned
# registry → verify pins → wait for docker → run under caffeinate with a timeout → record the
# result on the host. The queue is never trusted: it only names a job, and every check is
# repeated here because the queue is user-writable.
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/lib.sh"

is_digits() { case "$1" in ''|*[!0-9]*) return 1 ;; esac; return 0; }

# --- start.sh --awake: a caffeinate the runner owns, released when it unloads ---------------
AWAKE_PID="$DELAY_HOME/awake.pid"
awake_alive() { # -> pid of OUR caffeinate, if it is still running (checked by name: pids get reused)
    local p cmd
    p="$(cat "$AWAKE_PID" 2>/dev/null)" || return 1
    is_digits "$p" && kill -0 "$p" 2>/dev/null || return 1
    cmd="$(ps -p "$p" -o command= 2>/dev/null || tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null || true)"
    case "$cmd" in *caffeinate*) echo "$p" ;; *) return 1 ;; esac
}
stop_awake() {
    local p
    if p="$(awake_alive)"; then kill "$p" 2>/dev/null || true; fi
    rm -f "$AWAKE_PID"
}

unload() { # the last thing a tick does: launchd stops us the moment bootout lands
    stop_awake
    rm -f "$DELAY_HOME/armed"
    [ -n "${LOCK:-}" ] && rm -rf "$LOCK"
    trap - EXIT
    launchctl bootout "gui/$(id -u)/$DELAY_LABEL" >/dev/null 2>&1 || true
    exit 0
}

[ -d "$DELAY_HOME" ] || unload

# --- one dispatcher at a time; a dead holder's lock is reclaimed -------------------------
LOCK="$DELAY_HOME/.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
    holder="$(cat "$LOCK/pid" 2>/dev/null || true)"
    if [ -n "$holder" ] && kill -0 "$holder" 2>/dev/null; then exit 0; fi
    rm -rf "$LOCK"; mkdir "$LOCK" 2>/dev/null || exit 0
fi
echo $$ > "$LOCK/pid"
trap 'rm -rf "$LOCK"' EXIT

# Keep the Mac awake while armed with --awake: -i (no idle sleep) -s (no system sleep on AC),
# capped at the window end so it can never outlive the run even if unloading fails. The plist
# sets AbandonProcessGroup, so it survives this tick's exit.
armed_end="$(kv end "$DELAY_HOME/armed")"
if [ "$(kv awake "$DELAY_HOME/armed")" = 1 ] && is_digits "$armed_end" && [ "$armed_end" -gt "$(now)" ]; then
    if ! awake_alive >/dev/null; then
        nohup caffeinate -i -s -t $((armed_end - $(now))) >/dev/null 2>&1 &
        echo $! > "$AWAKE_PID"
    fi
else
    stop_awake
fi


wait_for_docker() {
    local waited=0
    until docker info >/dev/null 2>&1; do
        [ "$waited" -ge "$DELAY_DOCKER_WAIT" ] && return 1
        sleep 5; waited=$((waited + 5))
    done
}

# run_job <rd> <project> <job_file> -> sets RC and TIMED_OUT
run_job() {
    local rd="$1" proj="$2" jf="$3" compose service command timeout pid start name
    compose="$(kv compose "$jf")"; service="$(kv service "$jf")"
    command="$(kv command "$jf")"; timeout="$(kv timeout "$jf")"
    is_digits "$timeout" || timeout=10800
    set -f; set -- $command; set +f        # split on spaces, never glob, never eval
    name="claude-delay-$(basename "$rd")"
    echo "== docker compose -f $compose run --rm -T --name $name $service $* ==" >> "$rd/log"
    ( cd "$proj" && exec docker compose -f "$compose" run --rm -T --name "$name" "$service" "$@" ) < /dev/null >> "$rd/log" 2>&1 &
    pid=$!
    if command -v caffeinate >/dev/null 2>&1; then caffeinate -i -w "$pid" >/dev/null 2>&1 & fi
    TIMED_OUT=0; start="$(date +%s)"
    while kill -0 "$pid" 2>/dev/null; do
        if [ $(( $(date +%s) - start )) -ge "$timeout" ]; then
            TIMED_OUT=1
            kill -TERM "$pid" 2>/dev/null; sleep 2; kill -KILL "$pid" 2>/dev/null
            # killing the CLI does not always stop the container — remove it by name
            docker rm -f "$name" >/dev/null 2>&1 || true
            break
        fi
        sleep 1
    done
    wait "$pid"; RC=$?
}

process() { # process <store> <queue_file>
    local store="$1" q="$2" id rd proj job jf started st rc="" pins
    id="$(basename "$q" .job)"
    valid_name "$id" || { rm -f "$q"; return; }
    rd="$store/results/$id"
    mkdir "$rd" 2>/dev/null || return          # someone else claimed it
    mv "$q" "$rd/job" 2>/dev/null || { rmdir "$rd"; return; }
    : > "$rd/log"
    started="$(now)"
    proj="$(kv project "$rd/job")"; job="$(kv job "$rd/job")"

    if ! valid_name "$job" || [ "$(cat "$store/project.path")" != "$proj" ]; then
        st=invalid
    elif [ ! -d "$proj" ]; then
        st=project-missing
    elif ! jf="$(registry_job "$proj" "$job")"; then
        st=not-approved
    elif ! pins="$(verify_pins "$proj" "$jf")"; then
        st=needs-reapproval
        printf '%s\n' "$pins" >> "$rd/log"
    elif ! wait_for_docker; then
        st=docker-unavailable
    else
        run_job "$rd" "$proj" "$jf"
        rc="$RC"
        if [ "$TIMED_OUT" = 1 ]; then st=timeout; elif [ "$rc" = 0 ]; then st=passed; else st=failed; fi
        if (cd "$proj" && git rev-parse --git-dir >/dev/null 2>&1); then
            echo "== git status --short after the run ==" >> "$rd/log"
            (cd "$proj" && git status --short 2>&1 | head -50) >> "$rd/log"
        fi
    fi

    {
        cat "$rd/job"
        echo "started=$started"
        echo "finished=$(now)"
        echo "status=$st"
        echo "exit=$rc"
    } > "$rd/.meta.tmp"
    mv "$rd/.meta.tmp" "$rd/meta"
}

prune() { # keep the newest DELAY_KEEP_RESULTS results per project
    ls "$1/results" 2>/dev/null | sort | awk -v k="$DELAY_KEEP_RESULTS" '{ a[NR] = $0 }
        END { for (i = 1; i <= NR - k; i++) print a[i] }' | while read -r old; do
        valid_name "$old" && rm -rf "$1/results/$old"
    done
}

if in_window "$(now)"; then
    for store in "$DELAY_HOME"/*; do
        [ -f "$store/project.path" ] || continue
        for q in "$store"/queue/*.job; do
            [ -f "$q" ] || continue
            c="$(kv created "$q")"; is_digits "$c" || c=0
            printf '%s\t%s\n' "$c" "$q"
        done | sort -n | while IFS=$'\t' read -r _ q; do
            in_window "$(now)" || break     # the window closed during earlier runs
            process "$store" "$q"
        done
        prune "$store"
    done
fi

# --- nothing left to do → unload --------------------------------------------------------------
left=no
for q in "$DELAY_HOME"/*/queue/*.job; do [ -f "$q" ] && { left=yes; break; }; done
end="$(kv end "$DELAY_HOME/armed")"
if [ "$left" = no ]; then unload; fi
if is_digits "$end" && [ "$(now)" -ge "$end" ]; then unload; fi
exit 0
