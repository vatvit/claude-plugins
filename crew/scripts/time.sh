#!/usr/bin/env bash
# crew time (PLUG-097): where each member's wall time went — Claude working, waiting for a tool, a process, the
# slot queue, the shared tree, a peer's decision or work, the user, compaction. Reads each member's Claude Code
# transcript, found by the session ids crew recorded for that name ($STATE/sids, written by whoami), and the
# slot history ($CREW_HOME/slots.log) to split a `slot run` into queue and run. Prints categories and tool
# names only, never transcript text. The parsing and the arithmetic are time.awk's.
#
# Transcripts: <config dir>/projects/<project key>/<session id>.jsonl, looked up in $CLAUDE_CONFIG_DIR,
# ~/.claude and every ~/.claude*/ (another account's config dir), so a crew spread over accounts is found.
# CREW_TRANSCRIPTS (colon-separated dirs of project dirs) replaces that search; the tests use it.
#
# Sourced (watch): time_review_due — the coordinator's reminder (PLUG-098). Every `crew time` run is a review
# and stamps $STATE/time-reviewed.
#
# help: time [--since HH:MM|YYYY-MM-DD|"YYYY-MM-DD HH:MM"] [--idle MIN] — where each member's time went (default: today; gaps over 30 min not counted)

[ -n "${CREW_LIB_DIR:-}" ] || . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
TIME_AWK="$CREW_LIB_DIR/time.awk"

# local_epoch <YYYY-MM-DD HH:MM> — local time to epoch; BSD first, then GNU/busybox; explicit seconds always
local_epoch() {
    date -j -f "%Y-%m-%d %H:%M:%S" "$1:00" +%s 2>/dev/null || date -d "$1:00" +%s 2>/dev/null
}

time_since() { # <spec> -> epoch
    local today; today="$(fmt_epoch "$(now)" %Y-%m-%d)"
    case "$1" in
        [0-2][0-9]:[0-5][0-9]) local_epoch "$today $1" ;;
        [0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]) local_epoch "$1 00:00" ;;
        [0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]\ [0-2][0-9]:[0-5][0-9]) local_epoch "$1" ;;
        *) return 1 ;;
    esac
}

time_dirs() { # the dirs that hold project dirs, one per line
    if [ -n "${CREW_TRANSCRIPTS:-}" ]; then printf '%s\n' "$CREW_TRANSCRIPTS" | tr ':' '\n'; return 0; fi
    local d
    for d in "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" "$HOME"/.claude "$HOME"/.claude*; do
        [ -d "$d/projects" ] && printf '%s\n' "$d/projects"
    done | awk '!seen[$0]++'
}

time_sids() { # name<TAB>sid for every session id each member had: the history, then the current one
    { [ -f "$STATE/sids" ] && cut -f1,2 "$STATE/sids"
      local n s; for n in $(sess_names); do s="$(sess_get "$n" sid)"; [ -z "$s" ] || printf '%s\t%s\n' "$n" "$s"; done
    } | awk -F'\t' 'NF == 2 && $2 ~ /^[A-Za-z0-9_-]+$/ && !seen[$0]++'
}

time_files() { # name<TAB>transcript path
    local dirs n s d f; dirs="$(time_dirs)"
    time_sids | while IFS=$'\t' read -r n s; do
        printf '%s\n' "$dirs" | while IFS= read -r d; do
            [ -n "$d" ] || continue
            for f in "$d"/*/"$s".jsonl; do [ ! -f "$f" ] || printf '%s\t%s\n' "$n" "$f"; done
        done
    done
    return 0                  # a member with no transcript is normal; never let its miss be the status
}

num_cfg() { local v; v="$(cfg "$1")"; case "$v" in ''|*[!0-9]*) v="$(cfg_default "$1")" ;; esac; echo "$v"; }

# time_review_due — prints the reason a review is due, nothing when it is not: no review for timeReviewHours
# (counted from the crew's first join when there was none), or this crew's slots waited timeReviewQueueMin in
# the queue since the last one (the slot log: start - requested of this crew's starts). 0 turns a rule off.
time_review_due() {
    local t h q last n s waited
    t="$(now)"; h="$(num_cfg timeReviewHours)"; q="$(num_cfg timeReviewQueueMin)"
    if [ -f "$STATE/time-reviewed" ]; then last="$(cat "$STATE/time-reviewed")"
    else last="$t"; for n in $(sess_names); do s="$(sess_get "$n" since)"; [ -n "$s" ] && [ "$s" -lt "$last" ] && last="$s"; done
    fi
    case "$last" in ''|*[!0-9]*) last="$t" ;; esac
    if [ "$h" -gt 0 ] && [ $((t - last)) -ge $((h * 3600)) ]; then
        echo "crew time not reviewed for $(( (t - last) / 3600 ))h"; return 0
    fi
    [ "$q" -gt 0 ] && [ -s "$CREW_HOME/slots.log" ] || return 0
    waited="$(awk -F'\t' -v c="$(crew_id)" -v since="$last" \
        '$2 == "start" && ($12 "") == c && $1 > since { w += $1 - $8 } END { print int(w / 60) }' "$CREW_HOME/slots.log")"
    [ "$waited" -lt "$q" ] || echo "this crew waited ${waited}m in the slot queue since the last review"
    return 0
}

time_main() {
    local since="" idle=30 files names
    crew_init; need_active
    while [ $# -gt 0 ]; do
        case "$1" in
            --since) since="$(time_since "${2:-}")" || die "--since takes HH:MM, YYYY-MM-DD or \"YYYY-MM-DD HH:MM\": '${2:-}'"; shift 2 ;;
            --idle) case "${2:-}" in ''|*[!0-9]*) die "--idle takes whole minutes: '${2:-}'" ;; esac; idle="$2"; shift 2 ;;
            *) die "unknown argument: $1 — time [--since …] [--idle MIN]" ;;
        esac
    done
    [ -n "$since" ] || since="$(time_since "$(fmt_epoch "$(now)" %Y-%m-%d)")"
    now > "$STATE/time-reviewed"
    files="$(time_files)"
    [ -n "$files" ] || { echo "time: no transcript found for this crew's sessions"; return 0; }
    names="$(printf '%s\n' "$files" | cut -f1 | awk '!seen[$0]++' | paste -sd' ' -)"
    echo "crew time since $(fmt_epoch "$since" '%Y-%m-%d %H:%M') (local), gaps over ${idle} min not counted"
    printf '%s\n' "$files" | awk -F'\t' -v stage=events -f "$TIME_AWK" \
        | sort -t "$(printf '\t')" -k1,1 -k2,2n \
        | awk -F'\t' -v stage=report -v since="$since" -v idle="$((idle * 60))" -v slotlog="$CREW_HOME/slots.log" \
              -v names="$names" -f "$TIME_AWK"
    printf '%s\n' "$files" | cut -f1 | sort | uniq -c | awk '$1 > 1 { n++ } END { if (n) print "(a member with several session ids is counted across all of them)" }'
    return 0
}

if is_main; then set -euo pipefail; time_main "$@"; fi
