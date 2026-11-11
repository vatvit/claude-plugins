#!/usr/bin/env bash
# Session identity. A crew name is the identity (holds, slots and claims are by name); the Claude
# session id only maps a hook payload to that name. The PreToolUse Bash hook sees the session id of
# the `whoami <name>` call and leaves it in $CREW_PENDING/<name>, so nobody has to type an id.
# help: whoami <name> [worker|coordinator] [--take] [--sid ID] — join the crew as <name>
# help: whoami — show the crew
# help: whoami --leave <name> — remove a session from the crew
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
crew_init

if [ $# -eq 0 ]; then
    need_active
    echo "crew: $(crew_line)"
    exit 0
fi
if [ "$1" = --leave ]; then
    need_active; n="$(name_for "${2:-}")"; valid_name "$n" && [ -f "$STATE/sessions/$n" ] || die "no session '$n'"
    load_area slot; declare -F slots_drop >/dev/null && slots_drop "$n" >/dev/null   # its slots leave with it
    reg_drop "$n"; rm -f "$STATE/sessions/$n"; echo "crew: $n left"; exit 0
fi

display="$1"; name="$(name_for "$1")"; pending="$name"; shift; role=worker; take=0; sid=""
while [ $# -gt 0 ]; do
    case "$1" in
        worker|coordinator) role="$1" ;;
        --take) take=1 ;;
        --sid) sid="${2:-}"; shift ;;
        *) die "unknown argument: $1" ;;
    esac
    shift
done
valid_name "$name" || die "a crew name needs letters or digits: '$display'"
if [ -z "$sid" ] && [ -f "$CREW_PENDING/$pending" ]; then sid="$(cat "$CREW_PENDING/$pending")"; fi
rm -f "$CREW_PENDING/$pending"        # the hook parked the id under the name as typed, before any prefix
[ -n "$sid" ] || die "cannot see this session's id — run whoami through the Bash tool with the crew plugin enabled (hooks load at session start: a session already running when crew was installed must be restarted), or pass --sid <session id>"
# the project prefix (name_prefix) makes names unique without a machine registry; a member that is
# already in keeps its name, so a crew running across an upgrade or a HOME that went away is not renamed
pre="$(name_prefix)"
if [ -n "$pre" ] && [ ! -f "$STATE/sessions/$name" ]; then
    case "$display" in "$pre"*) ;; *)
        display="$pre$display"; name="$(name_for "$display")"
        note "name prefixed with the project: $name (names must be unique without the machine registry; namePrefix in .crew.json)" ;;
    esac
fi
mkdir -p "$STATE/sessions"          # only now: a failed join must not switch crew on for the repo

bind() {
    local old cur c o t
    old="$(sess_get "$name" sid)"
    o="$(reg_other "$name")"
    if [ -n "$o" ] && [ "$take" -eq 0 ]; then
        die "'$name' is in use by crew $o — names must be unique on this machine, because SendMessage addresses are. Try $(crew_id)-$name, or add --take if that session is gone"
    fi
    if [ -n "$old" ] && [ "$old" != "$sid" ] && [ "$take" -eq 0 ]; then
        die "'$name' belongs to another session (since $(hhmm "$(sess_get "$name" since)")) — add --take if that session is gone"
    fi
    cur="$(name_of_sid "$sid")"
    [ -n "$cur" ] && [ "$cur" != "$name" ] && reg_drop "$cur" && rm -f "$STATE/sessions/$cur" && note "renamed $cur → $name (holds and claims stay under $cur until released)"
    if [ "$role" = coordinator ]; then
        c="$(coordinator)"
        if [ -n "$c" ] && [ "$c" != "$name" ]; then
            [ "$take" -eq 1 ] || die "$c is the coordinator — add --take to replace it"
            sed 's/^role=.*/role=worker/' "$STATE/sessions/$c" | replace_file "$STATE/sessions/$c"
            note "$c is now a worker"
        fi
    fi
    t="$(sess_get "$name" task)"     # a re-join (restart, --take) keeps the name's task
    { printf 'sid=%s\nrole=%s\nsince=%s\ndisplay=%s\n' "$sid" "$role" "$(now)" "$display"; [ -z "$t" ] || printf 'task=%s\n' "$t"; } \
        | replace_file "$STATE/sessions/$name"
    reg_set "$name" "$sid"
    # every session id a name has had, for `crew time` (PLUG-097): a /clear or restart changes the id
    if [ -n "$sid" ] && ! awk -F'\t' -v n="$name" -v s="$sid" '($1 "") == n && ($2 "") == s { f = 1 } END { exit !f }' "$STATE/sids" 2>/dev/null; then
        printf '%s\t%s\t%s\n' "$name" "$sid" "$(now)" >> "$STATE/sids"
    fi
}
with_lock sessions bind
echo "crew $(crew_id): you are $name ($role). Prefix every crew call with: $(prefix_for "$name")"
echo "crew: $(crew_line)"
crew_rules_print
load_area watch; declare -F watch_stamp >/dev/null && watch_stamp "$sid"   # the watchdog counts silence from here
# mail waiting for this name (sent before it joined, or to its previous session): say so, arm the notice
load_area inbox; declare -F mail_start >/dev/null && mail_start "$name" "$sid"
exit 0
