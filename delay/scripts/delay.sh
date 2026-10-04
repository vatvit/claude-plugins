#!/usr/bin/env bash
# delay.sh — the client Claude runs. It queues a job NAME for the human's run window. What the
# name runs lives in the root-owned registry, which only the human writes (`sudo approve.sh`).
# Claude may PROPOSE a definition for a job that is not approved yet; it is just shown to the
# human, who approves it by ID. Claude never chooses a command that runs, nor a time.
#
#   delay.sh [--project DIR] add <job> [--compose FILE --service NAME --wrapper SCRIPT
#                                       [--command "CMD"] [--timeout SECONDS]]
#                                           queue for the next window (+ propose a definition)
#   delay.sh [--project DIR] list           run window, queued jobs, latest results
#   delay.sh [--project DIR] show <id>      one job: meta + log path
#   delay.sh [--project DIR] rm <id>        remove a queued job
#   delay.sh [--project DIR] jobs           approved job names for this project
#   delay.sh status                         install state, window, runner
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/lib.sh"

PROJECT_ARG=""
if [ "${1:-}" = "--project" ]; then PROJECT_ARG="${2:-}"; shift 2 || die "--project needs a dir"; fi
cmd="${1:-}"; shift || true
install_hint() {
    echo "  approve (human, sudo): sudo \"$DELAY_SYSTEM/bin/approve.sh\" $1 <job> --compose FILE --service NAME --wrapper SCRIPT"
    runner_installed || echo "  (install first, once: sudo bash $DELAY_LIB_DIR/install.sh)"
}

when_str() { fmt_epoch "$1" "%Y-%m-%d %H:%M"; }

window_str() { # one line describing the run window
    local c w
    if c="$(window_conf)" && w="$(window_target "$(now)")"; then
        if in_window "$(now)"; then echo "window: ${c% *} for ${c#* }h — open now"
        else echo "window: ${c% *} for ${c#* }h — next $(when_str "$w")"; fi
    else
        if runner_installed; then
            echo "window: NOT SET — nothing runs until the user runs: sudo \"$DELAY_SYSTEM/bin/approve.sh\" --window HH:MM HOURS"
        else echo "window: not set yet — the install sets it (default 03:00 for 4h)"; fi
    fi
}

# The runner is not always on: the user starts it (sudo start.sh) when jobs are queued. Claude
# relays this block to the user verbatim — it is the "reminder to run the daemon".
runner_reminder() {
    local pend line any=0 q id kind root job f
    for q in "$DELAY_HOME"/*/queue/*.job; do [ -f "$q" ] && { any=1; break; }; done
    [ "$any" = 1 ] || return 0
    pend="$(all_jobs "$DELAY_HOME" | awk -F'\t' '$2 == "pending"')"
    if [ -z "$pend" ] && runner_armed; then echo "runner: started for this window — nothing to do"; return 0; fi
    echo "ACTION FOR THE USER — queued jobs will not run until you run:"
    runner_installed || echo "  sudo bash $DELAY_LIB_DIR/install.sh        (once)"
    runner_installed && ! window_conf >/dev/null && echo "  sudo \"$DELAY_SYSTEM/bin/approve.sh\" --window HH:MM HOURS        (once)"
    if [ -n "$pend" ]; then
        printf '%s\n' "$pend" | while IFS=$'\t' read -r id kind root job f; do
            if [ -n "$(kv proposed_compose "$f")" ]; then
                echo "  sudo \"$DELAY_SYSTEM/bin/approve.sh\" $id        (review + approve '$job' in $root, once)"
            else
                echo "  sudo \"$DELAY_SYSTEM/bin/approve.sh\" \"$root\" $job --compose FILE --service NAME --wrapper SCRIPT"
            fi
        done
        echo "  (all projects and jobs: sudo \"$DELAY_SYSTEM/bin/approve.sh\")"
    fi
    runner_armed || echo "  sudo \"$DELAY_SYSTEM/bin/start.sh\""
}

case "$cmd" in
status)
    if runner_installed; then
        echo "installed=yes"
        # launchd and sudo run root-owned copies: a plugin update reaches them only via re-install
        current=yes
        for s in lib.sh dispatch.sh start.sh approve.sh; do
            cmp -s "$DELAY_LIB_DIR/$s" "$DELAY_SYSTEM/bin/$s" || current=no
        done
        echo "installed_current=$current"
        echo "interval_min=$(awk -F'[<>]' '/StartInterval/ { print $7 / 60; exit }' "$DELAY_PLIST")"
    else echo "installed=no"; fi
    window_str
    if [ "$(setting awake)" = 1 ]; then echo "awake_default=yes"; else echo "awake_default=no"; fi
    if runner_armed; then echo "runner=started"; else echo "runner=not-started"; fi
    echo "queued_approved=$(approved_queued "$DELAY_HOME")"
    echo "registry=$DELAY_REGISTRY"
    echo "store=$DELAY_HOME"
    exit 0 ;;
esac

ROOT="$(project_root "$PROJECT_ARG")" || die "no such project dir: ${PROJECT_ARG:-$PWD}"

case "$cmd" in
add)
    job="${1:-}"
    [ -n "$job" ] || die "usage: delay.sh add <job> [--compose FILE --service NAME --wrapper SCRIPT [--command CMD] [--timeout S]]"
    shift
    valid_name "$job" || die "invalid job name '$job' (allowed: A-Z a-z 0-9 . _ -)"
    p_compose="" p_service="" p_wrapper="" p_command="" p_timeout=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --compose) p_compose="${2:-}"; shift 2 || die "--compose needs a file" ;;
            --service) p_service="${2:-}"; shift 2 || die "--service needs a name" ;;
            --wrapper) p_wrapper="${2:-}"; shift 2 || die "--wrapper needs a file" ;;
            --command) p_command="${2:-}"; shift 2 || die "--command needs a value" ;;
            --timeout) p_timeout="${2:-}"; shift 2 || die "--timeout needs seconds" ;;
            *) die "no time argument: queued jobs run in the user's run window ($(window_str))" ;;
        esac
    done
    # A proposal is checked here only so mistakes surface now; approve.sh checks it all again.
    if [ -n "$p_compose$p_service$p_wrapper$p_command$p_timeout" ]; then
        [ -n "$p_compose" ] && [ -n "$p_service" ] && [ -n "$p_wrapper" ] ||
            die "a proposal needs --compose, --service and --wrapper together"
        inside_project "$ROOT" "$p_compose" >/dev/null || die "compose file '$p_compose' is not a file inside $ROOT"
        inside_project "$ROOT" "$p_wrapper" >/dev/null || die "wrapper '$p_wrapper' is not a file inside $ROOT"
        valid_name "$p_service" || die "invalid service name '$p_service'"
        case "$p_timeout" in *[!0-9]*) die "--timeout must be seconds" ;; esac
        case "$p_command" in *$'\n'*) die "--command must be one line" ;; esac
    fi
    # not approved yet is fine: it is queued anyway, approval is checked again when it runs,
    # and the ACTION block below tells the user how to approve it
    write_entry() { # <id> <created> — atomic; carries the proposal when one was given
        {
            echo "id=$1"
            echo "project=$ROOT"
            echo "job=$job"
            echo "created=$2"
            if [ -n "$p_compose" ]; then
                echo "proposed_compose=$p_compose"; echo "proposed_service=$p_service"
                echo "proposed_wrapper=$p_wrapper"
                [ -z "$p_command" ] || echo "proposed_command=$p_command"
                [ -z "$p_timeout" ] || echo "proposed_timeout=$p_timeout"
            fi
        } > "$store/queue/.$1.tmp"
        mv "$store/queue/.$1.tmp" "$store/queue/$1.job"
    }
    approved_note() { registry_job "$ROOT" "$job" >/dev/null || echo " (not approved yet)"; }
    store="$(project_store "$ROOT")"
    for f in "$store"/queue/*.job; do
        [ -f "$f" ] && [ "$(kv job "$f")" = "$job" ] || continue
        if [ -n "$p_compose" ]; then
            write_entry "$(kv id "$f")" "$(kv created "$f")"
            echo "already queued $(kv id "$f"): $job$(approved_note) — proposal updated"
        else
            echo "already queued $(kv id "$f"): $job$(approved_note)"
        fi
        window_str; runner_reminder; exit 0
    done
    id="$(fmt_epoch "$(now)" %Y%m%d-%H%M%S)-$$"
    write_entry "$id" "$(now)"
    echo "queued $id: $job$(approved_note)"
    window_str
    runner_reminder
    ;;

list)
    store="$DELAY_HOME/$(encode_path "$ROOT")"
    echo "project: $ROOT"
    window_str
    echo "queued:"
    for f in "$store"/queue/*.job; do
        [ -f "$f" ] || continue
        printf '%s\t%s\t%s\n' "$(kv created "$f")" "$(kv id "$f")" "$(kv job "$f")"
    done | sort -n | while IFS=$'\t' read -r _ id job; do
        printf '  %s  %s\n' "$id" "$job"
    done
    [ -n "$(ls "$store"/queue/*.job 2>/dev/null)" ] || echo "  (none)"
    echo "results (latest first):"
    found=0
    for d in $(ls -r "$store/results" 2>/dev/null); do
        m="$store/results/$d/meta"
        [ -f "$m" ] || m="$store/results/$d/job"
        [ -f "$m" ] || continue
        found=1
        st="$(kv status "$m")"; [ -n "$st" ] || st=running
        printf '  %s  %-20s %-18s %s\n' "$d" "$(kv job "$m")" "$st" \
            "$(s="$(kv started "$m")"; [ -n "$s" ] && when_str "$s")"
    done
    [ "$found" = 1 ] || echo "  (none)"
    runner_reminder
    ;;

show)
    id="${1:-}"; valid_name "$id" || die "usage: delay.sh show <id>"
    d="$DELAY_HOME/$(encode_path "$ROOT")/results/$id"
    if [ -f "$DELAY_HOME/$(encode_path "$ROOT")/queue/$id.job" ]; then
        cat "$DELAY_HOME/$(encode_path "$ROOT")/queue/$id.job"; echo "status=queued"; exit 0
    fi
    [ -d "$d" ] || die "no job $id in this project"
    if [ -f "$d/meta" ]; then cat "$d/meta"; else cat "$d/job"; echo "status=running"; fi
    echo "log=$d/log"
    ;;

rm)
    id="${1:-}"; valid_name "$id" || die "usage: delay.sh rm <id>"
    f="$DELAY_HOME/$(encode_path "$ROOT")/queue/$id.job"
    [ -f "$f" ] || die "no queued job $id (already run, or another project)"
    rm -f "$f"
    echo "removed $id"
    ;;

jobs)
    dir="$DELAY_REGISTRY/$(encode_path "$ROOT")"
    if [ "$(cat "$dir/project.path" 2>/dev/null)" != "$ROOT" ] || [ -z "$(ls "$dir/jobs" 2>/dev/null)" ]; then
        echo "no approved jobs for $ROOT"
        install_hint "$ROOT"
        exit 0
    fi
    for f in "$dir"/jobs/*; do
        printf '%-20s %s run --rm %s %s (timeout %ss)\n' "$(basename "$f")" "$(kv compose "$f")" \
            "$(kv service "$f")" "$(kv command "$f")" "$(kv timeout "$f")"
    done
    ;;

*)
    sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
    [ -z "$cmd" ] || exit 1
    ;;
esac
