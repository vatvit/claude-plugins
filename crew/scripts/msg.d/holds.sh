# Message kinds for holds. Sourced by msg.sh: FROM, TO and msg_head are set.
load_area holds

# hold <path...> — announce holds you have taken
msg_hold() {
    local p
    msg_head HOLD "$TO" "${1:?hold <path...>}${2:+ …}"
    for p in "$@"; do p="$(rel_path "$p")"; echo "  $p — $(hold_desc "$p")"; done
    echo "nobody else edits these until I release them with a green sha."
}

# release <path> — announce the last release of a path, from holds.log
msg_release() {
    local p l
    p="$(rel_path "${1:?release <path>}")"
    l="$(awk -F'\t' -v p="$p" '$2 == p { l = $0 } END { print l }' "$STATE/holds.log" 2>/dev/null)"
    [ -n "$l" ] || die "no release of $p recorded"
    msg_head RELEASE "$TO" "$p"
    printf '%s\n' "$l" | awk -F'\t' '{ printf "  released at %s by %s → %s\n", $5, $3, ($4 == "-" ? "free" : "now held by " $4) }'
}

# extra hand-off lines: the holds to release once the slice has landed
msg_handoff_extra_holds() {
    [ -s "$STATE/holds" ] || return 0
    local mine
    mine="$(awk -F'\t' -v n="$FROM" '$2 == n { print $1 }' "$STATE/holds")"
    [ -n "$mine" ] || return 0
    echo "holds I release once this lands: $(printf '%s\n' "$mine" | paste -sd' ' -)  (release <path> --sha <landed sha>)"
}
