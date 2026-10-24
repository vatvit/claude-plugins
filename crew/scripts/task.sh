#!/usr/bin/env bash
# One task, one session (PLUG-061): which task each session works on, as `task=` in its
# sessions/<name>. A task another session owns is refused; --take moves it and tells the old owner.
# crew_line shows each session's task, so status, SessionStart and whoami all name it.
#
# Sourced (by tree.sh): task_assign. Executed (via crew.sh): the CLI below.
# help: task — the task this session works on
# help: task <ID> [--take] [--for NAME] — work on <ID> (one task per session); --take moves it from its owner; --for: coordinator assigns
# help: task --clear [--for NAME] — this session (or NAME) works on no task

[ -n "${CREW_LIB_DIR:-}" ] || . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

# _task_assign <me> <target> <id> <take 0|1> — under the sessions lock
_task_assign() {
    local me="$1" who="$2" id="$3" take="$4" owner
    owner="$(task_owner "$id")"
    if [ "$owner" = "$who" ]; then echo "task: $id — already $([ "$who" = "$me" ] && echo yours || echo "$who's")"; return 0; fi
    if [ -n "$owner" ] && [ "$take" -eq 0 ]; then
        echo "task: $id — REFUSED, owned by $(display_of "$owner"). One task, one session: ask the coordinator for a hand-over, or on their word: $(prefix_for "$me") task $id --take" >&2
        return 1
    fi
    if [ -n "$owner" ]; then
        sess_set "$owner" task
        load_area inbox
        declare -F mail_send >/dev/null && mail_send "$me" "$owner" task <<EOF
[$(crew_id)] $(display_of "$me") → $(display_of "$owner"): TASK — $(display_of "$me") took over $id$([ "$who" = "$me" ] || echo " for $(display_of "$who")"). It is no longer yours: stop work on it and tell the coordinator where you left it.
EOF
    fi
    sess_set "$who" task "$id"
    echo "task: $id — $([ "$who" = "$me" ] && echo yours || echo "$who's")${owner:+ (taken over from $owner)}"
}
# task_assign <me> <target> <id> [take] — refuses (return 1) when another session owns <id>
task_assign() { with_lock sessions _task_assign "$1" "$2" "$3" "${4:-0}"; }

task_main() {
    local me who="" id="" take=0 clear=0
    crew_init; need_active
    me="$(caller_name)"
    [ -n "$me" ] && [ -f "$STATE/sessions/$me" ] || die "this session has not joined the crew: crew whoami <name>, or prefix CREW_AS=<name>"
    while [ $# -gt 0 ]; do
        case "$1" in
            --take) take=1 ;;
            --clear) clear=1 ;;
            --for) who="$(name_for "${2:-}")"; shift ;;
            -*) die "unknown option: $1" ;;
            *) [ -z "$id" ] || die "one task id only"; id="$1" ;;
        esac
        shift
    done
    if [ -n "$who" ] && [ "$who" != "$me" ]; then
        [ "$(sess_get "$me" role)" = coordinator ] || die "only the coordinator assigns tasks to other sessions"
        [ -f "$STATE/sessions/$who" ] || die "no session '$who' in this crew"
    fi
    who="${who:-$me}"
    if [ "$clear" -eq 1 ]; then
        [ -z "$id" ] || die "task --clear takes no id"
        with_lock sessions sess_set "$who" task
        echo "task: none for $who"; return 0
    fi
    if [ -z "$id" ]; then
        id="$(sess_get "$who" task)"; echo "task: ${id:-none}"; return 0
    fi
    valid_name "$id" || die "a task id: letters, digits, . _ -"
    task_assign "$me" "$who" "$id" "$take"
}

if is_main; then set -euo pipefail; task_main "$@"; fi
