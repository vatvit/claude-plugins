#!/usr/bin/env bash
# crew mail hook, for two events (the argument):
#   post  PostToolUse — stamp this session's activity for the watchdog (every tool call, so this is
#         the one stamp that matters); while it has unread crew mail, say so after every tool call
#         (additionalContext), so a hand-off whose SendMessage was dropped is still seen
#   stop  Stop — a session about to go idle with unread mail is held once per message and told to
#         read it (hookMode=warn: only warned); catches "the coordinator went idle on a hand-off"
# Fork-free unless there is mail: with no marker for this session the hook ends on builtins.
# Always exits 0.
h="${BASH_SOURCE[0]%/*}"; [ "$h" != "${BASH_SOURCE[0]}" ] || h=.; . "$h/fast.sh"   # no fork
crew_fast_read
crew_fast_skip && exit 0
crew_fast_seen                       # activity stamp for the watchdog (watch.sh)
crew_fast_unread || exit 0
(
    . "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd -P)/lib.sh"
    hook_init || exit 0
    crew_active || exit 0
    load_area inbox
    case "${1:-}" in
        post) declare -F mail_notice >/dev/null && mail_notice "$NAME" "$SID" ;;
        stop) declare -F mail_stop   >/dev/null && mail_stop   "$NAME" "$SID" ;;
    esac
    exit 0
)
exit 0
