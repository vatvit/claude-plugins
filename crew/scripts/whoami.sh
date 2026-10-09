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
    reg_drop "$n"; rm -f "$STATE/sessions/$n"; echo "crew: $n left"; exit 0
fi

display="$1"; name="$(name_for "$1")"; shift; role=worker; take=0; sid=""
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
if [ -z "$sid" ] && [ -f "$CREW_PENDING/$name" ]; then sid="$(cat "$CREW_PENDING/$name")"; fi
rm -f "$CREW_PENDING/$name"
[ -n "$sid" ] || die "cannot see this session's id — run whoami through the Bash tool with the crew plugin enabled (hooks load at session start: a session already running when crew was installed must be restarted), or pass --sid <session id>"
mkdir -p "$STATE/sessions"          # only now: a failed join must not switch crew on for the repo

bind() {
    local old cur c o
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
    printf 'sid=%s\nrole=%s\nsince=%s\ndisplay=%s\n' "$sid" "$role" "$(now)" "$display" | replace_file "$STATE/sessions/$name"
    reg_set "$name" "$sid"
}
with_lock sessions bind
echo "crew $(crew_id): you are $name ($role). Prefix every crew call with: $(prefix_for "$name")"
echo "crew: $(crew_line)"
# mail waiting for this name (sent before it joined, or to its previous session): say so, arm the notice
load_area inbox; declare -F mail_start >/dev/null && mail_start "$name" "$sid"
exit 0
