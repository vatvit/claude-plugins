#!/usr/bin/env bash
# Silence watchdog: notices a crew that has gone quiet while work is waiting, so a dropped message
# can no longer stall it for hours. Activity is $STATE/seen/<sid>, whose mtime the hooks bump on
# every tool call (fast.sh: crew_fast_seen); a session never stamped counts from its join.
#
# A finding is one line, "<key>\t<text>"; the key (silent:<name>, unread:<name>, stale:<id>) lets
# the loop report each one once per silenceMin instead of every round. Findings:
#   - a session silent longer than silenceMin while it owns something (a hold, a slot, dirty paths);
#   - mail unread longer than silenceMin (when the mailbox area is installed);
#   - a stale slot (running past its estimate + slotGraceMin; slot.sh owns that rule).
#
# Sourced (status, whoami, SessionStart): watch_stamp, last_seen, watch_findings, watch_status.
# Executed (via crew.sh): the CLI below.
# help: watch [--once | --wait] [--every SEC] — silence watchdog: one line per finding (--once: one pass;
# help:   --wait: exit 2 at the first finding, to wake an idle coordinator from a background run)

[ -n "${CREW_LIB_DIR:-}" ] || . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
load_area slot; load_area inbox

silence_min() { local s; s="$(cfg silenceMin)"; case "$s" in ''|*[!0-9]*) s="$(cfg_default silenceMin)" ;; esac; echo "$s"; }   # a bad value falls back to the default

# watch_stamp <sid> — the slow-path stamp (SessionStart, whoami); it also creates seen/
watch_stamp() {
    case "$1" in ''|*/*) return 0 ;; esac
    mkdir -p "$STATE/seen" && : > "$STATE/seen/$1"
}
last_seen() { # <name> -> epoch of the session's last activity
    local sid t=""
    sid="$(sess_get "$1" sid)"
    [ -n "$sid" ] && [ -f "$STATE/seen/$sid" ] && t="$(file_mtime "$STATE/seen/$sid")"
    [ -n "$t" ] || t="$(sess_get "$1" since)"
    echo "${t:-0}"
}
watch_owns() { # <name> -> "hold a.txt b.txt · slot #3 · dirty c.txt" (empty when it owns nothing)
    local h s d out=""
    h="$(awk -F'\t' -v n="$1" '($2 "") == n { printf "%s%s", (k++ ? " " : ""), $1 }' "$STATE/holds" 2>/dev/null)"
    s="$(awk -F'\t' -v n="$1" '($2 "") == n { printf "%s#%s", (k++ ? " " : ""), $1 }' "$SLOTS" 2>/dev/null)"
    d="$(my_dirty "$1" | paste -sd' ' -)"
    [ -n "$h" ] && out="hold $h"
    [ -n "$s" ] && out="$out${out:+ · }slot $s"
    [ -n "$d" ] && out="$out${out:+ · }dirty $d"
    printf '%s\n' "$out"
}

# watch_findings — every finding now, "<key>\t<text>"
watch_findings() {
    local t lim n age own c first f
    t="$(now)"; lim=$(( $(silence_min) * 60 ))
    for n in $(sess_names); do
        age=$(( t - $(last_seen "$n") ))
        [ "$age" -gt "$lim" ] || continue
        own="$(watch_owns "$n")"; [ -n "$own" ] || continue
        printf 'silent:%s\t%s silent %sm while owning: %s — next: ask them (msg … --to %s --send); if the session is gone, drop/release what it owns and reassign\n' \
            "$n" "$(display_of "$n")" $((age / 60)) "$own" "$n"
    done
    if declare -F mail_ids >/dev/null; then
        for n in $(sess_names); do
            first="$(mail_ids "$n" | head -1)"; [ -n "$first" ] || continue
            f="$STATE/mail/$n/new/$first"
            age=$(( t - $(mail_field "$f" at) ))
            [ "$age" -gt "$lim" ] || continue
            c="$(mail_count "$n")"
            printf 'unread:%s\t%s has %s unread for %sm (oldest #%s from %s, %s) — next: %s runs inbox; if it does not answer, relay it again with SendMessage\n' \
                "$n" "$n" "$c" $((age / 60)) "$((10#$first))" "$(mail_field "$f" from)" "$(mail_field "$f" kind)" "$n"
        done
    fi
    if declare -F slots_plan >/dev/null; then
        slots_plan | awk -F'\t' '$14 == 1 && $15 { printf "stale:%s\tslot #%s of %s (%s, %sm) is stale — next: ask %s; if gone, the coordinator runs: slot release %s\n", $1, $1, $2, $3, $4, $2, $1 }'
    fi
    return 0
}

# watch_status — status part: "activity: s1 0m ago · s2 22m ago"
watch_status() {
    local t n out=""
    t="$(now)"
    for n in $(sess_names); do out="$out${out:+ · }$(display_of "$n") $(( (t - $(last_seen "$n")) / 60 ))m ago"; done
    [ -z "$out" ] || echo "activity: $out (silent after $(silence_min)m)"
}

# --- CLI -------------------------------------------------------------------------------------------
watch_main() {
    crew_init; need_active
    local mode=loop every=60 rounds="${CREW_WATCH_ROUNDS:-0}" i=0 lim f mem new t
    while [ $# -gt 0 ]; do
        case "$1" in
            --once) mode=once ;; --wait) mode=wait ;;
            --every) every="${2:-}"; shift ;;
            *) die "unknown argument: $1 — watch [--once | --wait] [--every SEC]" ;;
        esac
        shift
    done
    case "$every" in ''|*[!0-9]*) die "--every takes seconds" ;; esac
    if [ "$mode" = once ]; then
        f="$(watch_findings)"
        if [ -n "$f" ]; then printf '%s\n' "$f" | cut -f2-; else echo "watch: quiet (silenceMin $(silence_min))"; fi
        return 0
    fi
    # loop / wait: report a finding when it first appears, and again once it has lasted silenceMin
    # $mem: "<key>\t<epoch reported>"; $new: this round's findings due for a report
    mem="$STATE/watch.$$"; new="$STATE/watch.$$.new"; : > "$mem"; CREW_ON_EXIT="rm -f '$mem' '$new'"
    lim=$(( $(silence_min) * 60 ))
    while :; do
        t="$(now)"
        watch_findings | awk -F'\t' -v mf="$mem" -v now="$t" -v lim="$lim" '
            FILENAME == mf { last[$1] = $2; next }
            !($1 in last) || now - last[$1] >= lim' "$mem" - > "$new"
        if [ -s "$new" ]; then
            cut -f2- "$new"
            awk -F'\t' -v nf="$new" -v now="$t" 'FILENAME == nf { due[$1] = 1; print $1 "\t" now; next }
                !($1 in due)' "$new" "$mem" | replace_file "$mem"
            [ "$mode" = wait ] && exit 2
        fi
        i=$((i + 1)); [ "$rounds" -gt 0 ] && [ "$i" -ge "$rounds" ] && return 0
        sleep "$every"
    done
}

if is_main; then set -euo pipefail; watch_main "$@"; fi
