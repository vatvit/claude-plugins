#!/usr/bin/env bash
# Silence watchdog: notices a crew that has gone quiet while work is waiting, so a dropped message
# can no longer stall it for hours. Activity is $STATE/seen/<sid>, whose mtime the hooks bump on
# every tool call (fast.sh: crew_fast_seen); a session never stamped counts from its join.
#
# A finding is one line, "<key>\t<text>"; the key (silent:<name>, unread:<name>, stale:<id>, …) lets
# the loop report each one once per silenceMin instead of every round, and --wait once until it clears
# (PLUG-103: a repeated finding ended every --wait at once, so coordinators stopped running it). Findings:
#   - a session silent longer than silenceMin while it owns something (a hold, a slot, dirty paths), unless
#     it waits in the slot queue or runs its own slot within the estimate: that is waiting, not silence;
#   - mail unread longer than silenceMin (when the mailbox area is installed);
#   - a stale slot (running past its estimate + slotGraceMin; slot.sh owns that rule);
#   - a slot of this crew waiting longer than slotWaitMin, with what holds the machine;
#   - a stuck slot of any crew: it can start but does not, and the queue passes it (slot.sh owns that rule);
#   - the coordinator's time review is due (time.sh owns that rule, PLUG-098).
# A loop or --wait run leaves $STATE/watch.pid, so SessionStart and status can tell a coordinator that
# nothing watches (PLUG-105).
#
# Sourced (status, whoami, SessionStart): watch_stamp, last_seen, watch_findings, watch_status.
# Executed (via crew.sh): the CLI below.
# help: watch [--once | --wait [--max MIN]] [--every SEC] — silence watchdog: one line per finding (--once: one pass;
# help:   --wait: exit 2 at the first new finding, to wake an idle coordinator from a background run; --max: exit 0 after MIN quiet minutes)

[ -n "${CREW_LIB_DIR:-}" ] || . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
load_area slot; load_area inbox; load_area time

cfg_min() { local s; s="$(cfg "$1")"; case "$s" in ''|*[!0-9]*) s="$(cfg_default "$1")" ;; esac; echo "$s"; }   # a bad value falls back to the default
silence_min() { cfg_min silenceMin; }

# watch_running — a loop or --wait watch of this crew is alive (its pid file and its process)
watch_running() { local p; p="$(cut -f1 "$STATE/watch.pid" 2>/dev/null)"; [ -n "$p" ] && kill -0 "$p" 2>/dev/null; }
# watch_off_note <name> — for a coordinator with no watch running: the line that says so, else nothing
watch_off_note() {
    [ "$(sess_get "$1" role)" = coordinator ] && ! watch_running || return 0
    echo "crew: watch is not running — nothing wakes you when the crew stalls. Start it with the Bash tool's run_in_background: $(prefix_for "$1") watch --wait --max 20, and again after every wake."
}

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

# watch_plan — slots_plan, or nothing without the slot area
watch_plan() { declare -F slots_plan >/dev/null && slots_plan; return 0; }
# watch_waits <plan> <name> — what <name> waits on in the queue: "slot #4 waiting 17m, ETA 12:10" or
# "slot #4 running 3m of 30m"; empty when nothing (a stale slot is not waiting: it has its own finding)
watch_waits() {
    printf '%s\n' "$1" | awk -F'\t' -v n="$2" -v now="$(now)" '
        function hm(t,   c) { c = "date -r " t " +%H:%M 2>/dev/null || date -d @" t " +%H:%M"; c | getline r; close(c); return r }
        ($2 "") != n || $14 == 1 { next }
        $7 == "waiting" { printf "%sslot #%s waiting %dm, %s", (k++ ? ", " : ""), $1, (now - $6) / 60, ($13 == 1 ? "can start now" : "ETA " hm($11)) }
        $7 == "running" { printf "%sslot #%s running %dm of %sm", (k++ ? ", " : ""), $1, (now - $8) / 60, $4 }'
}

# watch_findings — every finding now, "<key>\t<text>"
watch_findings() {
    local t lim n age own c first f plan
    t="$(now)"; lim=$(( $(silence_min) * 60 )); plan="$(watch_plan)"
    for n in $(sess_names); do
        age=$(( t - $(last_seen "$n") ))
        [ "$age" -gt "$lim" ] || continue
        own="$(watch_owns "$n")"; [ -n "$own" ] || continue
        [ -z "$(watch_waits "$plan" "$n")" ] || continue
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
    if [ -n "$plan" ]; then
        printf '%s\n' "$plan" | awk -F'\t' -v now="$t" -v wait="$(( $(cfg_min slotWaitMin) * 60 ))" '
            function hm(t,   c) { c = "date -r " t " +%H:%M 2>/dev/null || date -d @" t " +%H:%M"; c | getline r; close(c); return r }
            function who(i) { return "#" id[i] " " nm[i] (ours[i] ? "" : " [" cr[i] "]") }
            { id[NR] = $1; nm[NR] = $2; cr[NR] = $10; ours[NR] = $15 }
            $14 == 1 && $15 { printf "stale:%s\tslot #%s of %s (%s, %sm) is stale — next: ask %s; if gone, the coordinator runs: slot release %s\n", $1, $1, $2, $3, $4, $2, $1 }
            $18 == "stuck" { printf "stuck:%s\tslot #%s of %s [%s] can start but has not (%s); the queue passes it — next: tell %s or its crew'"'"'s coordinator\n", $1, $1, $2, $10, $19, $2 }
            $7 == "waiting" && $15 && $18 == "" && now - $6 > wait {
                b = ""; for (i = 1; i < NR && i <= 3; i++) b = b (b == "" ? "" : ", ") who(i)
                printf "queue:%s\tslot #%s of %s has waited %dm in the queue (%s) behind %s — next: tell the user how long, and why\n",
                    $1, $1, $2, (now - $6) / 60, ($13 == 1 ? "can start now" : "ETA " hm($11)), (b == "" ? "nothing" : b) }'
    fi
    if declare -F time_review_due >/dev/null; then
        f="$(time_review_due)"
        [ -z "$f" ] || printf 'review:time\t%s — next: run crew time, read it with references/time.md, report to the user and propose levers\n' "$f"
    fi
    return 0
}

# watch_status — status part: "activity: s1 0m ago · s2 22m ago"
watch_status() {
    local t n out=""
    t="$(now)"
    local plan w; plan="$(watch_plan)"
    for n in $(sess_names); do
        w="$(watch_waits "$plan" "$n")"
        out="$out${out:+ · }$(display_of "$n") $(( (t - $(last_seen "$n")) / 60 ))m ago${w:+ ($w)}"
    done
    [ -z "$out" ] || echo "activity: $out (silent after $(silence_min)m)"
}

# --- CLI -------------------------------------------------------------------------------------------
watch_main() {
    crew_init; need_active
    local mode=loop every=60 rounds="${CREW_WATCH_ROUNDS:-0}" i=0 lim f mem new cur t max="" t0
    while [ $# -gt 0 ]; do
        case "$1" in
            --once) mode=once ;; --wait) mode=wait ;;
            --every) every="${2:-}"; shift ;;
            --max) max="${2:-}"; shift ;;
            *) die "unknown argument: $1 — watch [--once | --wait [--max MIN]] [--every SEC]" ;;
        esac
        shift
    done
    case "$every" in ''|*[!0-9]*) die "--every takes seconds" ;; esac
    case "$max" in ''|[0-9]|[0-9]*[0-9]) ;; *) die "--max takes whole minutes" ;; esac
    if [ "$mode" = once ]; then
        f="$(watch_findings)"
        if [ -n "$f" ]; then printf '%s\n' "$f" | cut -f2-; else echo "watch: quiet (silenceMin $(silence_min))"; fi
        return 0
    fi
    # loop: report a finding when it first appears, and again once it has lasted silenceMin.
    # wait: report a finding once, until it clears; the memory outlives the run, so the next --wait does not
    # exit on what woke the last one. $mem: "<key>\t<epoch reported>"; $new: this round's findings to report
    new="$STATE/watch.$$.new"; cur="$STATE/watch.$$.cur"
    if [ "$mode" = wait ]; then mem="$STATE/watch.reported"; touch "$mem"
    else mem="$STATE/watch.$$"; : > "$mem"; fi
    printf '%s\t%s\n' "$$" "$(caller_name)" | replace_file "$STATE/watch.pid"
    CREW_ON_EXIT="rm -f '$new' '$cur'$([ "$mode" = wait ] || echo " '$mem'"); [ \"\$(cut -f1 '$STATE/watch.pid' 2>/dev/null)\" = $$ ] && rm -f '$STATE/watch.pid'"
    lim=$(( $(silence_min) * 60 )); t0="$(now)"
    while :; do
        t="$(now)"
        watch_findings > "$cur"
        if [ "$mode" = wait ]; then
            awk -F'\t' -v mf="$mem" 'FILENAME == mf { last[$1] = 1; next } !($1 in last)' "$mem" "$cur" > "$new"
            awk -F'\t' -v mf="$mem" -v now="$t" 'FILENAME == mf { last[$1] = $2; next }
                { print $1 "\t" (($1 in last) ? last[$1] : now) }' "$mem" "$cur" | replace_file "$mem"
        else
            awk -F'\t' -v mf="$mem" -v now="$t" -v lim="$lim" '
                FILENAME == mf { last[$1] = $2; next }
                !($1 in last) || now - last[$1] >= lim' "$mem" "$cur" > "$new"
            [ -s "$new" ] && awk -F'\t' -v nf="$new" -v now="$t" 'FILENAME == nf { due[$1] = 1; print $1 "\t" now; next }
                !($1 in due)' "$new" "$mem" | replace_file "$mem"
        fi
        if [ -s "$new" ]; then
            cut -f2- "$new"
            [ "$mode" = wait ] && exit 2
        fi
        if [ -n "$max" ] && [ $(( t - t0 )) -ge $(( max * 60 )) ]; then
            echo "watch: no new finding for ${max}m; open: $(grep -c . "$cur") (watch --once lists them)"
            return 0
        fi
        i=$((i + 1)); [ "$rounds" -gt 0 ] && [ "$i" -ge "$rounds" ] && return 0
        sleep "$every"
    done
}

if is_main; then set -euo pipefail; watch_main "$@"; fi
