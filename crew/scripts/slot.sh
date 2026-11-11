#!/usr/bin/env bash
# The slot queue: one queue for machine time, enforced by a script instead of by people remembering
# to check. The machine is shared by every crew on it, so the queue is too (PLUG-074): $CREW_HOME/slots
# (per machine) is TSV, one slot per line:
#   id  name  class  minutes  prio  requested  state  started  why  crew  mem  group  budget
# class: cpu (may overlap other cpu) | exclusive (nothing else runs) | quiet (nothing else runs, and
# this crew's pushes and background jobs wait too). prio: 0 failing on the shared branch, 1 the user's
# critical ask, 2 normal. mem: GB the slot declares (empty = 0); group: a named mutex, at most one running
# slot per group (PLUG-090); budget: the requester's slotMemGB (slots_budget). Order: prio, then shortest,
# then first come. Names are unique on the machine, so the name is the owner; crew is the owner's crew id,
# for display. A slot whose owner is no longer live (reg_live) is reaped under the lock by the next slot command.
#
# One plan for every viewer (PLUG-102): the order and who may start come from the queue alone, never from
# the viewer's own config, or two accounts' waiters each see the other's slot first and neither starts. The
# one deliberate exception is slotIgnoreCrews, which only lets this crew stop waiting for another.
# A waiter that cannot start leaves its reason in $SLOTS.wait (id  epoch  what is ahead); a slot that can
# start but does not is STUCK and holds nobody back (slots_plan).
#
# History (PLUG-097): every request, start, done, cancel, release and reap is appended to $SLOTS.log as
#   time  event  <the slot's row>
# under the same lock, so `crew time` can split a `slot run` into queue and run. Trimmed to the newest
# SLOT_LOG_KEEP lines when it grows past twice that.
#
# Scope (PLUG-119): slotScope machine (default) keeps the queue in $CREW_HOME; project keeps it in $STATE, which
# needs no HOME, and is also where a machine scope falls back when HOME is not writable (slot_scope).
#
# Sourced: slots_sorted, slot_quiet_holder (the git guard uses it to hold pushes during a quiet slot).
# Executed: the CLI below.
# help: slot request <cpu|exclusive|quiet> <min> [--mem GB] [--group NAME] [--prio failing|critical] [--why TEXT] — join the queue
# help: slot start [id] | done [id] | cancel [id] — begin your turn / finish / leave the queue
# help: slot run <class> <min> [--mem GB] [--group NAME] [--prio P] [--why TEXT] -- <cmd...> — request, wait, run, release in one go; the command gets CREW_SLOT_ID/CLASS/MEM/GROUP
# help: slot list — the queue with ETAs; stale slots flagged
# help: slot clear — exit 0 when no quiet slot runs (check before pushes and background jobs)
# help: slot release <id> — coordinator: remove a slot of this crew (a stale one)

[ -n "${CREW_LIB_DIR:-}" ] || . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

SLOT_POLL="${CREW_SLOT_POLL:-5}"
SLOT_LOG_KEEP="${CREW_SLOT_LOG_KEEP:-10000}"
# slot_paths — where the queue is; needs STATE: set now when it is known, else by crew_try_init (lib.sh) once it is
slot_paths() { SLOTS="$(slots_dir)/slots"; SLOT_WAIT="$SLOTS.wait"; }
[ -z "${STATE:-}" ] || slot_paths
slot_lock() { with_lock_at "$(dirname "$SLOTS")" slots "$@"; }
# slot_scope_note — once per crew, when the queue is in the project only because HOME is not usable
slot_scope_note() {
    slot_scope_fallback || return 0
    [ ! -e "$STATE/slot-scope-said" ] || return 0
    : > "$STATE/slot-scope-said"
    note "slots: project scope — HOME not writable, so this queue covers only this repo: crews in other repos on this machine do not wait for its slots, nor it for theirs, and an exclusive slot here does not keep their runs off the machine (slotScope in .crew.json)"
}
slot_ours() { [ -f "$STATE/sessions/$1" ]; }               # <name> — a member of this crew
ours_list() { sess_names | paste -sd' ' -; }               # this crew's names, for slots_plan

# slots_budget — the machine's memory budget: the largest slotMemGB a queued slot was requested under
slots_budget() { if [ -s "$SLOTS" ]; then awk -F'\t' '$13 + 0 > b { b = $13 + 0 } END { print b + 0 }' "$SLOTS"; else echo 0; fi; }
# slots_ignored — the crew ids whose slots this crew does not wait for (slotIgnoreCrews, PLUG-104), never its own
slots_ignored() { cfg slotIgnoreCrews | grep -v -x -F -- "$(crew_id)" | paste -sd' ' - || true; }
slots_last_event() { [ -s "$SLOTS.log" ] && tail -n 1 "$SLOTS.log" | cut -f1; return 0; }   # epoch of the last slot event

# _slots_reap — drop the slots of owners no longer live (their crew ended, they left or were replaced)
_slots_reap() {
    local n dead=""
    [ -s "$SLOTS" ] || return 0
    for n in $(cut -f2 "$SLOTS" | sort -u); do reg_live "$n" || dead="$dead $n"; done
    [ -z "$dead" ] || CREW_SLOT_DROP_EVENT=reaped _slots_drop $dead >/dev/null
}

# slots_sorted — running first (by start), then waiting in queue order: prio, shortest, first come —
# except that a slot never passes a waiting slot it competes with that was requested before it (PLUG-096).
# Shortest-first alone let a stream of short cpu slots, each sorted ahead of a long exclusive and each
# allowed beside the running ones, starve it for over an hour.
slots_sorted() {
    [ -s "$SLOTS" ] || return 0
    awk -F'\t' '$7 == "running"' "$SLOTS" | sort -t "$(printf '\t')" -k8,8n
    awk -F'\t' '$7 == "waiting"' "$SLOTS" | sort -t "$(printf '\t')" -k5,5n -k4,4n -k6,6n -k1,1n | _slots_no_pass
}

# _slots_no_pass — stdin: waiting slots in shortest-first order; stdout: the queue. Slot j blocks a later
# requested slot i (prio no better than j's) when they compete: j is exclusive/quiet (whatever i is: a cpu
# slot would run beside it, PLUG-096, and a shorter exclusive would still keep it waiting, PLUG-101), or both
# declare memory under the budget, or both are in one group. A slot of an ignored crew blocks nothing.
# Repeatedly the first slot in shortest-first order with no blocker left goes next; the relation follows
# request order, so it never cycles.
_slots_no_pass() {
    awk -F'\t' -v budget="$(slots_budget)" -v ign=" $(slots_ignored) " '
        function blocks(j, i) {
            if (x[j] || p[j] > p[i] || r[j] > r[i] || (r[j] == r[i] && id[j] > id[i])) return 0
            return c[j] != "cpu" || (budget > 0 && m[i] > 0 && m[j] > 0) ||
                   (g[i] != "" && (g[i] "") == (g[j] ""))
        }
        { L[++n] = $0; c[n] = $3; p[n] = $5 + 0; r[n] = $6 + 0; id[n] = $1 + 0; m[n] = $11 + 0; g[n] = $12
          x[n] = (index(ign, " " $10 " ") > 0) }
        END {
            budget += 0
            for (k = 1; k <= n; k++)
                for (i = 1; i <= n; i++) {
                    if (out[i]) continue
                    free = 1
                    for (j = 1; j <= n; j++) if (j != i && !out[j] && blocks(j, i)) { free = 0; break }
                    if (free) { out[i] = 1; print L[i]; break }
                }
        }'
}

# slots_plan — slots_sorted as fields 1-10, then five fields: eta (start), end, startable now (1/0), stale
# (1/0: running past its estimate + slotGraceMin — the one place that rule lives; slot list and watch read
# it), ours (1/0: the owner is in this crew — the one place that test lives for awk), then mem (GB, 0 when
# not declared) and group as fields 16-17, so readers of 11-15 never see the row grow, then a flag (18) and
# its detail (19): "stuck" (detail: why) or "ignored".
# Memory (PLUG-090): with a budget (slots_budget), a cpu slot that declares mem starts while the sum fits (a
# slot larger than the budget runs alone). A slot held back for memory holds back every later slot that
# declares memory too, so small ones cannot starve it (the PLUG-096 lesson). Group: one running slot per group.
# Stuck (PLUG-102): a waiting slot that can start now but has not, either because its waiter's note, written
# after the last slot event, still says "not yet" (the views disagree), or because no slot event happened
# for slotStuckMin. Its owner may still start it; it holds nobody back. Ignored (PLUG-104): a slot of a crew
# in slotIgnoreCrews holds nobody back either.
slots_plan() {
    slots_sorted | awk -F'\t' -v OFS='\t' -v now="$(now)" -v grace="$(cfg slotGraceMin)" -v ours="$(ours_list)" \
        -v budget="$(slots_budget)" -v ign=" $(slots_ignored) " -v last="$(slots_last_event)" \
        -v stuckmin="$(cfg slotStuckMin)" -v waitf="$SLOT_WAIT" '
        BEGIN { n = split(ours, a, " "); for (i = 1; i <= n; i++) o[a[i]] = 1; budget += 0; stuckmin += 0
                while ((getline l < waitf) > 0) { split(l, w, "\t"); wat[w[1] ""] = w[2] + 0; wsee[w[1] ""] = w[3] } }
        function max(a, b) { return a > b ? a : b }
        function row(eta, end, go, stale, flag, why) {
            print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, eta, end, go, stale, ($2 in o), m, g, flag, why }
        { m = $11 + 0; g = $12 }
        index(ign, " " $10 " ") {
            if ($7 == "running") row($8, max($8 + $4 * 60, now), 0, 0, "ignored", "")
            else row(now, now + $4 * 60, 0, 0, "ignored", "")
            next }
        $7 == "running" {
            end = max($8 + $4 * 60, now)
            free_all = max(free_all, end)
            if ($3 != "cpu") { free_ex = max(free_ex, end); run_ex = 1 } else run_cpu = 1
            if (m > 0) { used += m; free_mem = max(free_mem, end) }
            if (g != "") gfree[g] = max(gfree[g], end)
            row($8, end, 0, (now > $8 + ($4 + grace) * 60), "", ""); next }
        {   # waiting, in queue order
            if ($3 == "cpu") { s = max(now, free_ex); go = (!run_ex && !ahead_ex) }
            else { s = max(now, free_all); go = (!run_ex && !run_cpu && !ahead) }
            if (g != "" && (g in gfree)) { go = 0; s = max(s, gfree[g]) }
            held = (m > 0 && budget > 0 && (mem_held || (used > 0 && used + m > budget)))
            if (held) { go = 0; s = max(s, free_mem) }
            if (go && (($1 "") in wat) && wat[$1 ""] > last + 0) {
                row(s, s + $4 * 60, 1, 0, "stuck", "its waiter sees: behind " wsee[$1 ""]); next }
            if (go && last != "" && now - last >= stuckmin * 60) {
                row(s, s + $4 * 60, 1, 0, "stuck", "no start for " int((now - last) / 60) "m"); next }
            if (held) mem_held = 1
            if ($3 != "cpu") ahead_ex = 1
            end = s + $4 * 60; free_all = max(free_all, end)
            if ($3 != "cpu") free_ex = end
            if (m > 0) { free_mem = max(free_mem, end); if (go) used += m }
            if (g != "") gfree[g] = max(gfree[g], end)
            ahead = 1
            row(s, end, go, 0, "", "") }'
}

slot_quiet_holder() { # -> name of the session of THIS crew running a quiet slot, empty when none
    slots_plan | awk -F'\t' '$7 == "running" && $3 == "quiet" && $15 { print $2; exit }'
}

slot_line() { # one formatted line from a slots_plan record (stdin); another crew's slot is tagged [crew]
    awk -F'\t' -v now="$(now)" -v grace="$(cfg slotGraceMin)" -v me="${1:-}" '
        function hm(t,   c) { c = "date -r " t " +%H:%M 2>/dev/null || date -d @" t " +%H:%M"; c | getline r; close(c); return r }
        {   p = ($5 == 0 ? " · failing" : ($5 == 1 ? " · critical" : ""))
            who = $2 ((($2 "") == me) ? " (you)" : "") ($15 ? "" : " [" $10 "]")
            why = ($9 != "" ? " — " $9 : "")
            why = ($16 > 0 ? " · " $16 "G" : "") ($17 != "" ? " · group " $17 : "") why
            ig = ($18 == "ignored" ? " · ignored" : "")
            if ($7 == "running") {
                st = $14 ? " · STALE (past estimate + " grace "m)" : ""
                printf "  #%s %s %s %sm RUNNING since %s, ends ~%s%s%s%s%s\n", $1, who, $3, $4, hm($8), hm($12), p, st, ig, why
            } else {
                at = ig != "" ? "ignored" : ($13 == 1 ? "can start now" : "ETA " hm($11))
                if ($18 == "stuck") at = at " · STUCK (" $19 ")"
                printf "  #%s %s %s %sm waiting · %s%s%s\n", $1, who, $3, $4, at, p, why
            }
        }'
}

slots_list() { # [me] — every slot on the machine
    local plan; slot_lock _slots_reap; plan="$(slots_plan)"
    [ -n "$plan" ] || { echo "slots: none"; return 0; }
    echo "slots:"; printf '%s\n' "$plan" | slot_line "${1:-}"
    printf '%s\n' "$plan" | awk -F'\t' -v b="$(slots_budget)" \
        'b > 0 && $7 == "running" && $18 != "ignored" { u += $16 } END { if (b > 0) printf "  memory: %d of %d GB in use\n", u, b }'
}

# --- mutations (under the slots lock) -------------------------------------------------------------
_slot_log() { # <event> — stdin: slot rows; appends one history line per row
    local t; t="$(now)"
    awk -F'\t' -v OFS='\t' -v t="$t" -v e="$1" 'NF { print t, e, $0 }' >> "$SLOTS.log"
}
_slot_log_trim() {
    [ -f "$SLOTS.log" ] || return 0
    [ "$(wc -l < "$SLOTS.log")" -gt $((SLOT_LOG_KEEP * 2)) ] || return 0
    tail -n "$SLOT_LOG_KEEP" "$SLOTS.log" | replace_file "$SLOTS.log"
}
_slot_set() { # <id> <new line|empty to remove>
    { awk -F'\t' -v id="$1" '$1 != id' "$SLOTS" 2>/dev/null; [ -n "$2" ] && printf '%s\n' "$2"; } | replace_file "$SLOTS"
}
_slot_get() { [ -s "$SLOTS" ] && awk -F'\t' -v id="$1" '$1 == id' "$SLOTS"; return 0; }

_request() { # <me> <class> <min> <prio> <why> <mem> <group> — prints the new id
    local id b; id=$(( $(cat "$SLOTS.seq" 2>/dev/null || echo 0) + 1 )); echo "$id" > "$SLOTS.seq"
    b="$(cfg slotMemGB)"; case "$b" in ''|*[!0-9]*) b=0 ;; esac
    _slots_reap
    _slot_set "$id" "$(printf '%s\t%s\t%s\t%s\t%s\t%s\twaiting\t\t%s\t%s\t%s\t%s\t%s' "$id" "$1" "$2" "$3" "$4" "$(now)" "$5" "$(crew_id)" "$6" "$7" "$b")"
    _slot_get "$id" | _slot_log request; _slot_log_trim
    echo "$id"
}

# _slot_wait_note <id> [what is ahead] — the waiter's reason for <id> (none: drop it); notes of slots no
# longer queued go too
_slot_wait_note() {
    { [ -s "$SLOT_WAIT" ] && [ -f "$SLOTS" ] && awk -F'\t' -v id="$1" -v sf="$SLOTS" \
          'FILENAME == sf { q[$1 ""] = 1; next } (($1 "") in q) && ($1 "") != id' "$SLOTS" "$SLOT_WAIT"
      [ -n "${2:-}" ] && printf '%s\t%s\t%s\n' "$1" "$(now)" "$2"; } | replace_file "$SLOT_WAIT"
}

_start() { # <me> <id> — 0 started, 1 not yet (prints why, and leaves it in $SLOT_WAIT), 2 error
    local l plan go eta
    _slots_reap                         # a gone owner's slot must not hold the machine
    l="$(_slot_get "$2")"
    [ -n "$l" ] || { echo "slot: #$2 does not exist" >&2; return 2; }
    [ "$(printf '%s' "$l" | cut -f2)" = "$1" ] || { echo "slot: #$2 is not yours" >&2; return 2; }
    [ "$(printf '%s' "$l" | cut -f7)" = running ] && { echo "slot: #$2 already running"; return 0; }
    plan="$(slots_plan)"
    go="$(printf '%s\n' "$plan" | awk -F'\t' -v id="$2" '($1 "") == id { print $13 }')"
    if [ "$go" = 1 ]; then
        _slot_set "$2" "$(printf '%s' "$l" | awk -F'\t' -v OFS='\t' -v t="$(now)" '{ $7 = "running"; $8 = t; print }')"
        _slot_get "$2" | _slot_log start
        _slot_wait_note "$2"
        echo "slot: #$2 started — run now, then: slot done $2"; return 0
    fi
    eta="$(printf '%s\n' "$plan" | awk -F'\t' -v id="$2" '($1 "") == id { print $11 }')"
    _slot_wait_note "$2" "$(printf '%s\n' "$plan" | awk -F'\t' -v id="$2" '($1 "") == id { exit }
        $18 == "" { printf "%s#%s", (n++ ? " " : ""), $1 } END { if (!n) printf "?" }')"
    echo "slot: #$2 not yet — ETA $(hhmm "$eta"). Ahead of you:"
    printf '%s\n' "$plan" | awk -F'\t' -v id="$2" '($1 "") == id { exit } { print }' | slot_line "$1"
    return 1
}

_finish() { # <me> <id> <verb> — done/cancel: the owner, or the coordinator of the owner's crew
    local l o; l="$(_slot_get "$2")"
    [ -n "$l" ] || { echo "slot: #$2 does not exist" >&2; return 2; }
    o="$(printf '%s' "$l" | cut -f2)"
    if [ "$o" != "$1" ] && { [ "$1" != "$(coordinator)" ] || ! slot_ours "$o"; }; then
        slot_ours "$o" || o="$o of crew $(printf '%s' "$l" | cut -f10) — its coordinator releases it"
        echo "slot: #$2 belongs to $o" >&2; return 2
    fi
    _slot_set "$2" ""; _slot_wait_note "$2"
    printf '%s\n' "$l" | _slot_log "$3"
    echo "slot: #$2 $3"
}

_slots_drop() { # <name...> — every slot of these sessions; prints how many went
    local tmp="$SLOTS.drop.$$" n
    [ -s "$SLOTS" ] || { echo 0; return 0; }
    printf '%s\n' "$@" > "$tmp"
    n="$(awk -F'\t' -v df="$tmp" 'FILENAME == df { d[$0] = 1; next } ($2 in d) { n++ } END { print n + 0 }' "$tmp" "$SLOTS")"
    awk -F'\t' -v df="$tmp" 'FILENAME == df { d[$0] = 1; next } ($2 in d)' "$tmp" "$SLOTS" | _slot_log "${CREW_SLOT_DROP_EVENT:-dropped}"
    awk -F'\t' -v df="$tmp" 'FILENAME == df { d[$0] = 1; next } !($2 in d)' "$tmp" "$SLOTS" | replace_file "$SLOTS"
    rm -f "$tmp"; _slot_wait_note ""; echo "$n"
}
slots_drop() { slot_lock _slots_drop "$@"; }   # crew end, whoami --leave

my_slot() { # <me> <state> — my oldest slot in that state
    [ -s "$SLOTS" ] || return 0
    awk -F'\t' -v n="$1" -v s="$2" '($2 "") == n && $7 == s { print $1; exit }' "$SLOTS"
}

# _slot_mail <me> <id> <what> — tell the coordinator about a member's slot (PLUG-107), so a wait or an
# overrun reaches it as mail, not as a silence to guess at; the coordinator's own slots tell nobody
_slot_mail() {
    local c l
    c="$(coordinator)"; [ -n "$c" ] && [ "$c" != "$1" ] || return 0
    load_area inbox; declare -F mail_send >/dev/null || return 0
    l="$(_slot_get "$2")"; [ -n "$l" ] || return 0
    printf '%s\n' "$l" | awk -F'\t' -v h="[$(crew_id)] $(display_of "$1") → $(display_of "$c"): SLOT" -v id="$2" -v w="$3" \
        -v e="$(hhmm "$(( $(printf '%s' "$l" | cut -f8) + $(printf '%s' "$l" | cut -f4) * 60 ))")" \
        '{ printf "%s — #%s %s (%s %sm, ends ~%s%s)\n", h, id, w, $3, $4, e, ($9 != "" ? " — " $9 : "") }' \
        | mail_send "$1" "$c" slot 2>/dev/null
    return 0
}
# slot_started <me> <id> — after a start: mail the coordinator when the slot waited longer than slotWaitMin
slot_started() {
    local l w lim
    l="$(_slot_get "$2")"; [ -n "$l" ] || return 0
    w=$(( $(printf '%s' "$l" | cut -f8) - $(printf '%s' "$l" | cut -f6) ))
    lim="$(cfg slotWaitMin)"; case "$lim" in ''|*[!0-9]*) lim="$(cfg_default slotWaitMin)" ;; esac
    [ "$w" -gt $((lim * 60)) ] && _slot_mail "$1" "$2" "started after $((w / 60))m waiting"
    return 0
}
# _slot_overrun <me> <id> <min> — run in the background by `slot run`: one mail once the slot is past its
# estimate (CREW_SLOT_OVERRUN_SEC overrides, for tests). Sleeps in short steps, so the kill after the run
# leaves no long sleep behind.
_slot_overrun() {
    local left="${CREW_SLOT_OVERRUN_SEC:-$(( $3 * 60 ))}" step
    while [ "$left" -gt 0 ]; do step=5; [ "$left" -lt 5 ] && step="$left"; sleep "$step"; left=$((left - step)); done
    [ "$(_slot_get "$2" | cut -f7)" = running ] && _slot_mail "$1" "$2" "is past its $3m estimate, still running"
    return 0
}

after_move() { # what the coordinator should tell the queue now
    local next
    next="$(slots_plan | awk -F'\t' '$7 == "waiting" && $13 == 1 { printf "%s#%s %s", (n++ ? ", " : ""), $1, $2 }')"
    [ -n "$next" ] && echo "slot: can start now: $next"
    [ -n "$(slots_plan | awk -F'\t' '$7 == "waiting"')" ] && echo "slot: the queue moved — tell the waiting sessions: msg queue-moved \"<why>\""
    return 0
}

slot_main() {
    local sub="${1:-list}" me cls min prio=2 why="" mem=0 group="" id rc timer; [ $# -gt 0 ] && shift
    crew_init; need_active; slot_scope_note
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
                    --mem) case "${2:-}" in ''|*[!0-9]*) die "--mem takes a whole number of GB: '${2:-}'" ;; esac
                           mem="$2"; shift 2 ;;
                    --group) case "${2:-}" in ''|*[!A-Za-z0-9._-]*) die "--group takes one word (letters, digits, . _ -): '${2:-}'" ;; esac
                           group="$2"; shift 2 ;;
                    --why) why="$(printf '%s' "${2:-}" | tr '\t\n' '  ')"; shift 2 ;;
                    --) shift; break ;;
                    *) die "unknown argument: $1" ;;
                esac
            done
            id="$(slot_lock _request "$me" "$cls" "$min" "$prio" "$why" "$mem" "$group")"
            if [ "$sub" = request ]; then
                echo "slot: #$id requested ($cls, ${min}m)"
                slot_lock _start "$me" "$id" >/dev/null && { echo "slot: #$id started — run now, then: slot done $id"; return 0; }
                slots_plan | awk -F'\t' -v id="$id" '$1 == id' | slot_line "$me"
                echo "slot: start it when it can start: slot start $id"
                return 0
            fi
            [ $# -gt 0 ] || die "slot run … -- <command>"
            CREW_ON_EXIT="slot_lock _finish '$me' '$id' done >/dev/null 2>&1 || true"
            while :; do
                rc=0; slot_lock _start "$me" "$id" >/dev/null || rc=$?
                [ "$rc" -eq 0 ] && break
                [ "$rc" -eq 2 ] && die "slot #$id vanished while waiting (released by the coordinator?)"
                sleep "$SLOT_POLL"
            done
            slot_started "$me" "$id"
            ( trap - EXIT; _slot_overrun "$me" "$id" "$min" ) </dev/null >/dev/null 2>&1 &
            timer=$!
            CREW_ON_EXIT="kill $timer 2>/dev/null; $CREW_ON_EXIT"
            echo "slot: #$id running: $*" >&2
            rc=0; CREW_SLOT_ID="$id" CREW_SLOT_CLASS="$cls" CREW_SLOT_MEM="$mem" CREW_SLOT_GROUP="$group" "$@" || rc=$?
            kill "$timer" 2>/dev/null || true
            slot_lock _finish "$me" "$id" done >&2; CREW_ON_EXIT=""
            after_move >&2
            return "$rc" ;;
        start)
            id="${1:-$(my_slot "$me" waiting)}"; [ -n "$id" ] || die "you have no waiting slot"
            slot_lock _start "$me" "$id" && slot_started "$me" "$id" ;;
        done|cancel)
            id="${1:-$(my_slot "$me" running)}"; [ -n "$id" ] || id="$(my_slot "$me" waiting)"
            [ -n "$id" ] || die "you have no slot"
            slot_lock _finish "$me" "$id" "$( [ "$sub" = done ] && echo done || echo cancelled)"
            after_move ;;
        release)
            [ "$me" = "$(coordinator)" ] || die "only the coordinator releases another session's slot"
            slot_lock _finish "$me" "${1:?slot release <id>}" released
            after_move ;;
        *) die "unknown slot command: $sub — crew.sh help" ;;
    esac
}

if is_main; then set -euo pipefail; slot_main "$@"; fi
