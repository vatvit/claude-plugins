#!/usr/bin/env bash
# The slot queue: one queue for machine time, enforced by a script instead of by people remembering
# to check. $STATE/slots is TSV, one slot per line:
#   id  name  class  minutes  prio  requested  state  started  why
# class: cpu (may overlap other cpu) | exclusive (nothing else runs) | quiet (nothing else runs, and
# pushes and background jobs wait too). prio: 0 failing on the shared branch, 1 the user's critical
# ask, 2 normal. Order: prio, then shortest, then first come.
#
# Sourced: slots_sorted, slot_quiet_holder (the git guard uses it to hold pushes during a quiet slot).
# Executed: the CLI below.
# help: slot request <cpu|exclusive|quiet> <min> [--prio failing|critical] [--why TEXT] — join the queue
# help: slot start [id] | done [id] | cancel [id] — begin your turn / finish / leave the queue
# help: slot run <class> <min> [--prio P] [--why TEXT] -- <cmd...> — request, wait, run, release in one go
# help: slot list — the queue with ETAs; stale slots flagged
# help: slot clear — exit 0 when no quiet slot runs (check before pushes and background jobs)
# help: slot release <id> — coordinator: remove any slot (a stale one)

[ -n "${CREW_LIB_DIR:-}" ] || . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

SLOT_POLL="${CREW_SLOT_POLL:-5}"

# slots_sorted — running first (by start), then waiting in queue order
slots_sorted() {
    [ -s "$STATE/slots" ] || return 0
    awk -F'\t' '$7 == "running"' "$STATE/slots" | sort -t "$(printf '\t')" -k8,8n
    awk -F'\t' '$7 == "waiting"' "$STATE/slots" | sort -t "$(printf '\t')" -k5,5n -k4,4n -k6,6n -k1,1n
}

# slots_plan — slots_sorted plus four fields: eta (start), end, startable now (1/0), stale (1/0: running
# past its estimate + slotGraceMin — the one place that rule lives; slot list and watch read it)
slots_plan() {
    slots_sorted | awk -F'\t' -v OFS='\t' -v now="$(now)" -v grace="$(cfg slotGraceMin)" '
        function max(a, b) { return a > b ? a : b }
        $7 == "running" {
            end = max($8 + $4 * 60, now)
            free_all = max(free_all, end)
            if ($3 != "cpu") { free_ex = max(free_ex, end); run_ex = 1 } else run_cpu = 1
            print $0, $8, end, 0, (now > $8 + ($4 + grace) * 60); next }
        {   # waiting, in queue order
            if ($3 == "cpu") {
                s = max(now, free_ex); go = (!run_ex && !ahead_ex)
            } else {
                s = max(now, free_all); go = (!run_ex && !run_cpu && !ahead)
                ahead_ex = 1
            }
            end = s + $4 * 60; free_all = max(free_all, end)
            if ($3 != "cpu") free_ex = end
            ahead = 1
            print $0, s, end, go, 0 }'
}

slot_quiet_holder() { # -> name of the session running a quiet slot, empty when none
    [ -s "$STATE/slots" ] || return 0
    awk -F'\t' '$7 == "running" && $3 == "quiet" { print $2; exit }' "$STATE/slots"
}

slot_line() { # one formatted line from a slots_plan record (stdin)
    awk -F'\t' -v now="$(now)" -v grace="$(cfg slotGraceMin)" -v me="${1:-}" '
        function hm(t,   c) { c = "date -r " t " +%H:%M 2>/dev/null || date -d @" t " +%H:%M"; c | getline r; close(c); return r }
        {   p = ($5 == 0 ? " · failing" : ($5 == 1 ? " · critical" : ""))
            who = $2 (($2 == me) ? " (you)" : "")
            why = ($9 != "" ? " — " $9 : "")
            if ($7 == "running") {
                st = $13 ? " · STALE (past estimate + " grace "m)" : ""
                printf "  #%s %s %s %sm RUNNING since %s, ends ~%s%s%s%s\n", $1, who, $3, $4, hm($8), hm($11), p, st, why
            } else {
                printf "  #%s %s %s %sm waiting · %s%s%s\n", $1, who, $3, $4, ($12 == 1 ? "can start now" : "ETA " hm($10)), p, why
            }
        }'
}

slots_list() { # [me]
    local plan; plan="$(slots_plan)"
    [ -n "$plan" ] || { echo "slots: none"; return 0; }
    echo "slots:"; printf '%s\n' "$plan" | slot_line "${1:-}"
}

# --- mutations (under the slots lock) -------------------------------------------------------------
_slot_set() { # <id> <new line|empty to remove>
    { awk -F'\t' -v id="$1" '$1 != id' "$STATE/slots" 2>/dev/null; [ -n "$2" ] && printf '%s\n' "$2"; } | replace_file "$STATE/slots"
}
_slot_get() { [ -s "$STATE/slots" ] && awk -F'\t' -v id="$1" '$1 == id' "$STATE/slots"; return 0; }

_request() { # <me> <class> <min> <prio> <why> — prints the new id
    local id; id=$(( $(cat "$STATE/slots.seq" 2>/dev/null || echo 0) + 1 )); echo "$id" > "$STATE/slots.seq"
    _slot_set "$id" "$(printf '%s\t%s\t%s\t%s\t%s\t%s\twaiting\t\t%s' "$id" "$1" "$2" "$3" "$4" "$(now)" "$5")"
    echo "$id"
}

_start() { # <me> <id> — 0 started, 1 not yet (prints why), 2 error
    local l go eta
    l="$(_slot_get "$2")"
    [ -n "$l" ] || { echo "slot: #$2 does not exist" >&2; return 2; }
    [ "$(printf '%s' "$l" | cut -f2)" = "$1" ] || { echo "slot: #$2 is not yours" >&2; return 2; }
    [ "$(printf '%s' "$l" | cut -f7)" = running ] && { echo "slot: #$2 already running"; return 0; }
    go="$(slots_plan | awk -F'\t' -v id="$2" '$1 == id { print $12 }')"
    if [ "$go" = 1 ]; then
        _slot_set "$2" "$(printf '%s' "$l" | awk -F'\t' -v OFS='\t' -v t="$(now)" '{ $7 = "running"; $8 = t; print }')"
        echo "slot: #$2 started — run now, then: slot done $2"; return 0
    fi
    eta="$(slots_plan | awk -F'\t' -v id="$2" '$1 == id { print $10 }')"
    echo "slot: #$2 not yet — ETA $(hhmm "$eta"). Ahead of you:"
    slots_plan | awk -F'\t' -v id="$2" '$1 == id { exit } { print }' | slot_line "$1"
    return 1
}

_finish() { # <me> <id> <verb> — done/cancel: the owner, or the coordinator
    local l; l="$(_slot_get "$2")"
    [ -n "$l" ] || { echo "slot: #$2 does not exist" >&2; return 2; }
    if [ "$(printf '%s' "$l" | cut -f2)" != "$1" ] && [ "$1" != "$(coordinator)" ]; then
        echo "slot: #$2 belongs to $(printf '%s' "$l" | cut -f2)" >&2; return 2
    fi
    _slot_set "$2" ""
    echo "slot: #$2 $3"
}

my_slot() { # <me> <state> — my oldest slot in that state
    [ -s "$STATE/slots" ] || return 0
    awk -F'\t' -v n="$1" -v s="$2" '$2 == n && $7 == s { print $1; exit }' "$STATE/slots"
}

after_move() { # what the coordinator should tell the queue now
    local next
    next="$(slots_plan | awk -F'\t' '$7 == "waiting" && $12 == 1 { printf "%s#%s %s", (n++ ? ", " : ""), $1, $2 }')"
    [ -n "$next" ] && echo "slot: can start now: $next"
    [ -n "$(slots_plan | awk -F'\t' '$7 == "waiting"')" ] && echo "slot: the queue moved — tell the waiting sessions: msg queue-moved \"<why>\""
    return 0
}

slot_main() {
    local sub="${1:-list}" me cls min prio=2 why="" id rc; [ $# -gt 0 ] && shift
    crew_init; need_active
    case "$sub" in
        list) slots_list "${CREW_AS:-}"; return 0 ;;
        clear)
            local q; q="$(slot_quiet_holder)"
            [ -z "$q" ] && { echo "slot: no quiet slot running"; return 0; }
            echo "slot: $q has a quiet slot running — hold pushes and background jobs"; slots_list; return 1 ;;
    esac
    me="$(me)"
    case "$sub" in
        request|run)
            cls="${1:-}"; min="${2:-}"; shift 2 || die "slot $sub <cpu|exclusive|quiet> <minutes>"
            case "$cls" in cpu|exclusive|quiet) ;; *) die "class is cpu, exclusive or quiet: '$cls'" ;; esac
            case "$min" in ''|*[!0-9]*) die "minutes must be a whole number: '$min'" ;; esac
            while [ $# -gt 0 ]; do
                case "$1" in
                    --prio) case "${2:-}" in failing) prio=0 ;; critical) prio=1 ;; *) die "--prio failing|critical" ;; esac; shift 2 ;;
                    --why) why="$(printf '%s' "${2:-}" | tr '\t\n' '  ')"; shift 2 ;;
                    --) shift; break ;;
                    *) die "unknown argument: $1" ;;
                esac
            done
            id="$(with_lock slots _request "$me" "$cls" "$min" "$prio" "$why")"
            if [ "$sub" = request ]; then
                echo "slot: #$id requested ($cls, ${min}m)"
                with_lock slots _start "$me" "$id" >/dev/null && { echo "slot: #$id started — run now, then: slot done $id"; return 0; }
                slots_plan | awk -F'\t' -v id="$id" '$1 == id' | slot_line "$me"
                echo "slot: start it when it can start: slot start $id"
                return 0
            fi
            [ $# -gt 0 ] || die "slot run … -- <command>"
            CREW_ON_EXIT="with_lock slots _finish '$me' '$id' done >/dev/null 2>&1 || true"
            while :; do
                rc=0; with_lock slots _start "$me" "$id" >/dev/null || rc=$?
                [ "$rc" -eq 0 ] && break
                [ "$rc" -eq 2 ] && die "slot #$id vanished while waiting (released by the coordinator?)"
                sleep "$SLOT_POLL"
            done
            echo "slot: #$id running: $*" >&2
            rc=0; "$@" || rc=$?
            with_lock slots _finish "$me" "$id" done >&2; CREW_ON_EXIT=""
            after_move >&2
            return "$rc" ;;
        start)
            id="${1:-$(my_slot "$me" waiting)}"; [ -n "$id" ] || die "you have no waiting slot"
            with_lock slots _start "$me" "$id" ;;
        done|cancel)
            id="${1:-$(my_slot "$me" running)}"; [ -n "$id" ] || id="$(my_slot "$me" waiting)"
            [ -n "$id" ] || die "you have no slot"
            with_lock slots _finish "$me" "$id" "$( [ "$sub" = done ] && echo done || echo cancelled)"
            after_move ;;
        release)
            [ "$me" = "$(coordinator)" ] || die "only the coordinator releases another session's slot"
            with_lock slots _finish "$me" "${1:?slot release <id>}" released
            after_move ;;
        *) die "unknown slot command: $sub — crew.sh help" ;;
    esac
}

if is_main; then set -euo pipefail; slot_main "$@"; fi
