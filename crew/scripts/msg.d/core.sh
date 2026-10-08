# Core message kinds. Sourced by msg.sh: FROM, TO and msg_head are set.

# handoff [--task ID] [--msg-file F] — the path list, commit message and test-first proof
msg_handoff() {
    local task="" mf="" paths n f
    while [ $# -gt 0 ]; do
        case "$1" in --task) task="${2:-}"; shift 2 ;; --msg-file) mf="${2:-}"; shift 2 ;; *) die "handoff: unknown argument $1" ;; esac
    done
    paths="$(my_dirty "$FROM")"
    n="$(printf '%s' "$paths" | grep -c . || true)"
    msg_head HANDOFF "$TO" "${task:+$task }ready to land"
    echo "paths ($n):"
    printf '%s\n' "$paths" | sed '/^$/d; s/^/  /'
    echo "commit message:"
    if [ -n "$mf" ] && [ -f "$mf" ]; then sed 's/^/  /' "$mf"; else echo "  <fill: type(scope): summary${task:+ — $task}>"; fi
    echo "test-first: failing on HEAD: <fill: test + its failure> · deliberate bug caught: <fill>"
    echo "verified: <fill: suite + result line>"
    for f in $(declare -F | sed -n 's/^declare -f \(msg_handoff_extra_.*\)$/\1/p'); do "$f"; done
}

# decision <text> [--by user|coordinator] — to be recorded in the task file as written
msg_decision() {
    local by=coordinator text=""
    while [ $# -gt 0 ]; do
        case "$1" in --by) by="${2:-}"; shift 2 ;; *) text="$text${text:+ }$1"; shift ;; esac
    done
    [ "$by" = user ] && by="the user's" || by="the coordinator's"
    msg_head DECISION "$TO" "$by"
    echo "$text"
    echo "record it in the task file as $by decision, verbatim."
}

# stop <HH:MM> — a hard stop time
msg_stop() {
    msg_head "STOP TIME" "$TO" "${1:?stop needs HH:MM}"
    echo "finish by ${1}, or stop between runs; hand off what is green, leave nothing failing in the tree."
}
