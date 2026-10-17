#!/usr/bin/env bash
# End the crew (PLUG-075): release its holds and slots, free its names on the machine, print the
# message for its members, and remove its state, so every hook is silent here again ("no crew, no
# cost"). Refused while something would be lost — a crew worktree holding work the shared branch does
# not, unread mail — unless the user says --force. crew's worktrees are never deleted, only named.
# help: end [--force] — coordinator: end the crew here (holds, slots, names freed; repo back to no crew)
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
crew_init
load_area copy; load_area tree; load_area inbox; load_area slot

force=0
case "${1:-}" in --force) force=1 ;; '') ;; *) die "end [--force]" ;; esac
crew_active || { echo "crew: no crew in this repo — nothing to end"; exit 0; }

members="$(sess_names)"
by="$(caller_name)"; [ -n "$by" ] && [ -f "$STATE/sessions/$by" ] || by=""

# end_lost — one line per thing that ending would strand
end_lost() {
    local dir rel kind b who un be dirty p n
    while IFS=$'\t' read -r dir rel kind b who un be dirty; do
        case "$kind" in
            copy\ *) p="$(copy_unlanded "$dir" | paste -sd, - | sed 's/,/, /g')"
                     [ -z "$p" ] || echo "  $rel ($kind): $p — land it: crew apply ${kind#copy }" ;;
            task\ *) [ "$un$dirty" = 00 ] || echo "  $rel ($kind): $un unmerged, $dirty uncommitted — merge it: crew tree merge ${kind#task }" ;;
        esac
    done <<EOF
$(crew_trees)
EOF
    for p in $members; do
        n="$(mail_count "$p")"; [ "$n" -eq 0 ] || echo "  $p: $n unread crew message$([ "$n" -eq 1 ] || echo s) — crew inbox"
    done
}

if [ "$force" -eq 0 ]; then
    [ -n "$by" ] && [ "$by" = "$(coordinator)" ] || die "only the coordinator ends the crew — or the user's explicit word: crew end --force"
    lost="$(end_lost)"
    [ -z "$lost" ] || die "not ending: this would be lost —
$lost
deal with it first, or on the user's explicit word: crew end --force"
fi

holds=0; [ -f "$STATE/holds" ] && holds="$(grep -c . "$STATE/holds" || true)"
slots="$(slots_drop $members)"
left="$(crew_trees | awk -F'\t' '$3 != "-" { printf "%s%s", (n++ ? ", " : ""), $2 }')"
names="" to=""
for n in $members; do
    reg_drop "$n"; names="$names${names:+, }$(display_of "$n")"
    [ "$n" = "$by" ] || to="$to${to:+, }$(display_of "$n")"
done
id="$(crew_id)"
mkdir -p "$CREW_HOME"
printf '%s\t%s\t%s\t%s\t%s holds, %s slots\tby %s\n' "$(fmt_epoch "$(now)" '%Y-%m-%d %H:%M')" "$id" "$ROOT" \
    "${names:-none}" "$holds" "$slots" "${by:-the user (--force)}" >> "$CREW_HOME/ended"
from="${by:+$(display_of "$by")}"
rm -rf "$STATE" "$CREW_PENDING"

plural() { [ "$1" -eq 1 ] && echo "$1 $2" || echo "$1 ${2}s"; }
echo "crew: crew $id ended — released: $(plural "$holds" hold), $(plural "$slots" slot); names freed: ${names:-none}"
[ -z "$left" ] || echo "crew: left in place: $left (crew never deletes a worktree: land or remove them yourself)"
if [ -n "$to" ]; then
    echo "crew: send it with SendMessage to: $to"
    echo "[$id] ${from:-the user} → all: CREW ENDED"
    echo "crew $id is closed: holds and slots are released and your crew name is free. Work on as a solo session — crew's guards no longer apply here; the project's crew-only rules do not either."
fi
