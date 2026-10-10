#!/usr/bin/env bash
# delay.sh — the client Claude runs. It queues a JOB for the human's run window: a .sh script in
# the project, the container it runs in (compose file + service), and free params. The human
# approves the pair (container + script) once, in the root-owned registry (`sudo approve.sh`);
# params are never approved — they reach the script as argv. Claude never chooses a command
# that runs, nor a time.
#
#   delay.sh [--project DIR] add <script.sh> [--compose FILE --service NAME] [--timeout SECONDS]
#                                [--command "CMD"] [-- param...]
#                                           queue for the next window; the container may be left
#                                           out when the script is approved with exactly one
#   delay.sh [--project DIR] list           run window, queued jobs, latest results
#   delay.sh [--project DIR] show <id>      one job: meta + log path
#   delay.sh [--project DIR] rm <id>        remove a queued job
#   delay.sh [--project DIR] jobs           approved pairs for this project
#   delay.sh status                         install state, window, runner
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/lib.sh"

MAX_PARAMS=64 MAX_PARAM_BYTES=4096

PROJECT_ARG=""
if [ "${1:-}" = "--project" ]; then PROJECT_ARG="${2:-}"; shift 2 || die "--project needs a dir"; fi
cmd="${1:-}"; shift || true

when_str() { fmt_epoch "$1" "%Y-%m-%d %H:%M"; }

window_str() { # one line describing the run window
    local c w
    if c="$(window_conf)" && w="$(window_target "$(now)")"; then
        if in_window "$(now)"; then echo "window: ${c% *} for ${c#* }h — open now"
        else echo "window: ${c% *} for ${c#* }h — next $(when_str "$w")"; fi
    else
        if runner_installed; then
            echo "window: NOT SET — nothing runs until the user runs: $(sys_cmd approve.sh) --window HH:MM HOURS"
        else echo "window: not set yet — the install sets it (default 03:00 for 4h)"; fi
    fi
}

# The commands the user runs, full paths, quoted (the system dir has a space) — copied, never typed.
install_cmd() { printf 'sudo bash "%s/install.sh"' "$DELAY_LIB_DIR"; }
sys_cmd() { printf 'sudo "%s/bin/%s"' "$DELAY_SYSTEM" "$1"; }   # sys_cmd <script>

# The runner is not always on: the user starts it (sudo start.sh) when jobs are queued. Claude
# relays this block to the user verbatim — it is the "reminder to run the daemon".
runner_reminder() {
    local pend any=0 q id kind root f current=yes
    for q in "$DELAY_HOME"/*/queue/*.job; do [ -f "$q" ] && { any=1; break; }; done
    [ "$any" = 1 ] || return 0
    pend="$(all_jobs "$DELAY_HOME" | awk -F'\t' '$2 == "pending"')"
    runner_installed && ! installed_current && current=no
    if [ -z "$pend" ] && [ "$current" = yes ] && runner_armed; then
        echo "runner: started for this window — nothing to do"; return 0
    fi
    echo "ACTION FOR THE USER — queued jobs will not run until you run:"
    runner_installed || echo "  $(install_cmd)        (once)"
    [ "$current" = yes ] || echo "  $(install_cmd)        (update: the installed copy is outdated)"
    runner_installed && ! window_conf >/dev/null && echo "  $(sys_cmd approve.sh) --window HH:MM HOURS        (once)"
    if [ -n "$pend" ]; then
        printf '%s\n' "$pend" | while IFS=$'\t' read -r id kind root _ f; do
            echo "  $(sys_cmd approve.sh) $id        (review + approve $(kv script "$f") in $root, once)"
        done
        echo "  (all projects and jobs: $(sys_cmd approve.sh))"
    fi
    runner_armed || echo "  $(sys_cmd start.sh)"
}

case "$cmd" in
status)
    if runner_installed; then
        echo "installed=yes"
        if installed_current; then echo "installed_current=yes"; else echo "installed_current=no"; fi
        echo "interval_min=$(awk -F'[<>]' '/StartInterval/ { print $7 / 60; exit }' "$DELAY_PLIST")"
    else echo "installed=no"; fi
    window_str
    if [ "$(setting awake)" = 1 ]; then echo "awake_default=yes"; else echo "awake_default=no"; fi
    if runner_armed; then echo "runner=started"; else echo "runner=not-started"; fi
    echo "queued_approved=$(approved_queued "$DELAY_HOME")"
    echo "registry=$DELAY_REGISTRY"
    echo "store=$DELAY_HOME"
    echo "install_cmd=$(install_cmd)"
    echo "approve_cmd=$(sys_cmd approve.sh)"
    echo "start_cmd=$(sys_cmd start.sh)"
    exit 0 ;;
esac

ROOT="$(project_root "$PROJECT_ARG")" || die "no such project dir: ${PROJECT_ARG:-$PWD}"
REG="$DELAY_REGISTRY/$(encode_path "$ROOT")"
reg_ok() { [ "$(cat "$REG/project.path" 2>/dev/null)" = "$ROOT" ]; }

case "$cmd" in
add)
    script="${1:-}"
    [ -n "$script" ] || die "usage: delay.sh add <script.sh> [--compose FILE --service NAME] [--timeout S] [--command CMD] [-- param...]"
    shift
    case "$script" in
        *.sh) ;;
        *) die "a job is a .sh script inside the project, got '$script' — wrap the command in a script" ;;
    esac
    given="$script"
    script="$(rel_inside "$ROOT" "$given")" || die "script '$given' is not a regular file inside $ROOT"
    compose="" service="" p_command="" p_timeout=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --compose) compose="${2:-}"; shift 2 || die "--compose needs a file" ;;
            --service) service="${2:-}"; shift 2 || die "--service needs a name" ;;
            --command) p_command="${2:-}"; shift 2 || die "--command needs a value" ;;
            --timeout) p_timeout="${2:-}"; shift 2 || die "--timeout needs seconds" ;;
            --) shift; break ;;
            *) die "no time argument: queued jobs run in the user's run window ($(window_str)); params go after --" ;;
        esac
    done
    # params: data for the script, passed as argv — checked here, never approved
    [ $# -le "$MAX_PARAMS" ] || die "at most $MAX_PARAMS params, got $#"
    bytes=0
    for a in "$@"; do
        [ -n "$a" ] || die "a param may not be empty"
        case "$a" in *$'\n'*|*$'\r'*) die "a param must be one line" ;; esac
        bytes=$((bytes + $(printf '%s' "$a" | wc -c)))
    done
    [ "$bytes" -le "$MAX_PARAM_BYTES" ] || die "params total $bytes bytes, at most $MAX_PARAM_BYTES"
    case "$p_timeout" in *[!0-9]*) die "--timeout must be seconds" ;; esac
    case "$p_command" in *$'\n'*) die "--command must be one line" ;; esac

    # the container: named, or the one this script is approved with
    if [ -n "$compose$service" ]; then
        [ -n "$compose" ] && [ -n "$service" ] || die "name the container with both --compose FILE and --service NAME"
        compose="$(rel_inside "$ROOT" "$compose")" || die "compose file is not a regular file inside $ROOT"
        valid_name "$service" || die "invalid service name '$service'"
    else
        found="$(if reg_ok; then for f in "$REG"/jobs/*; do
            if [ -f "$f" ] && [ "$(kv script "$f")" = "$script" ]; then printf '%s\t%s\n' "$(kv compose "$f")" "$(kv service "$f")"; fi
        done; fi)"
        case "$(printf '%s' "$found" | grep -c . || true)" in
            0) die "$script is not approved with any container yet — name the one it runs in: delay.sh add $script --compose FILE --service NAME" ;;
            1) IFS=$'\t' read -r compose service <<EOF
$found
EOF
               ;;
            *) { echo "$script is approved with several containers:"
                 printf '%s\n' "$found" | awk -F'\t' '{ print "  " $1 " / " $2 }'; } >&2
               die "name one: delay.sh add $script --compose FILE --service NAME" ;;
        esac
    fi

    store="$(project_store "$ROOT")"
    tmp="$store/queue/.add.$$.tmp"
    trap 'rm -f "$tmp"' EXIT
    id="$(fmt_epoch "$(now)" %Y%m%d-%H%M%S)-$$"
    {
        echo "id=$id"
        echo "project=$ROOT"
        echo "created=$(now)"
        echo "compose=$compose"; echo "service=$service"; echo "script=$script"
        for a in "$@"; do printf 'arg=%s\n' "$a"; done
        [ -z "$p_command" ] || echo "proposed_command=$p_command"
        [ -z "$p_timeout" ] || echo "proposed_timeout=$p_timeout"
    } > "$tmp"
    pair="$(entry_pair "$tmp")"
    note=""; registry_pair "$ROOT" "$pair" >/dev/null || note=" (not approved yet)"

    # a duplicate: the same pair and the same params in any order — OK, not added twice
    sig="$(entry_sig "$tmp")"
    for f in "$store"/queue/*.job; do
        [ -f "$f" ] && [ "$(entry_sig "$f")" = "$sig" ] || continue
        upd=""
        if [ -n "$p_command$p_timeout" ]; then
            {
                awk -v t="${p_timeout:+1}" -v c="${p_command:+1}" '
                    !(t && index($0, "proposed_timeout=") == 1) && !(c && index($0, "proposed_command=") == 1)' "$f"
                [ -z "$p_command" ] || echo "proposed_command=$p_command"
                [ -z "$p_timeout" ] || echo "proposed_timeout=$p_timeout"
            } > "$tmp"
            mv "$tmp" "$f"
            upd=", proposal updated"
        fi
        echo "already queued $(kv id "$f"): $(job_desc "$f")$note — not added again$upd"
        window_str; runner_reminder; exit 0
    done
    mv "$tmp" "$store/queue/$id.job"
    echo "queued $id: $(job_desc "$store/queue/$id.job")$note"
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
        printf '%s\t%s\n' "$(kv created "$f")" "$f"
    done | sort -n | while IFS=$'\t' read -r _ f; do
        printf '  %s  %s\n' "$(kv id "$f")" "$(job_desc "$f")"
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
        printf '  %s  %-40s %-18s %s\n' "$d" "$(job_desc "$m")" "$st" \
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
    if ! reg_ok || [ -z "$(ls "$REG/jobs" 2>/dev/null)" ]; then
        echo "no approved pairs for $ROOT"
        echo "  queue one (delay.sh add <script.sh> --compose FILE --service NAME) — the user approves it by the ID it gets"
        runner_installed || echo "  (install first, once: $(install_cmd))"
        exit 0
    fi
    for f in "$REG"/jobs/*; do
        if [ -z "$(kv script "$f")" ]; then
            echo "$(basename "$f")  (approved by delay 1.x — the user re-installs to migrate it)"; continue
        fi
        printf '%-20s %s / %s — runs %s (timeout %ss)\n' "$(kv script "$f")" "$(kv compose "$f")" \
            "$(kv service "$f")" "$(kv command "$f")" "$(kv timeout "$f")"
    done
    ;;

*)
    header "$0"
    [ -z "$cmd" ] || exit 1
    ;;
esac
