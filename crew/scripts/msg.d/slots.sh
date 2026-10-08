# Message kinds for the slot queue. Sourced by msg.sh: FROM, TO and msg_head are set.
load_area slot

# queue-moved <why> — every waiting session's new time, and the reason (the coordinator sends it)
msg_queue-moved() {
    local plan; plan="$(slots_plan)"
    [ "$TO" = "$(coordinator)" ] && TO=all
    msg_head "QUEUE MOVED" "$TO" "${*:-<fill: why>}"
    if [ -z "$plan" ]; then echo "  queue empty — machine is free"; return 0; fi
    printf '%s\n' "$plan" | slot_line
}

# slot <id> — ask the coordinator for a slot already requested (or show it)
msg_slot() {
    local plan
    plan="$(slots_plan | awk -F'\t' -v id="${1:?slot <id>}" '$1 == id')"
    [ -n "$plan" ] || die "no slot #$1"
    msg_head "SLOT" "$TO" "#$1"
    printf '%s\n' "$plan" | slot_line "$FROM"
}
