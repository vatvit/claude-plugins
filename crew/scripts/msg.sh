#!/usr/bin/env bash
# Protocol messages, formatted and filled from crew state, ready to send with SendMessage.
# Kinds live in msg.d/ as msg_<kind> functions; Claude adds only the judgement lines.
# help: msg <kind> [--to NAME] [--send] [args] — print a ready-to-send message (msg with no kind lists kinds);
# help:   --send also files it in the recipient's mailbox (inbox), the copy a dropped SendMessage cannot lose
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
crew_init; need_active
for part in "$CREW_LIB_DIR"/msg.d/*.sh; do [ -f "$part" ] && . "$part"; done
FROM="$(me)"

# msg_head <KIND> <to> [summary]
msg_head() { echo "[$(crew_id)] $(display_of "$FROM") → $(display_of "$2"): $1${3:+ — $3}"; }

kind="${1:-}"; [ $# -gt 0 ] && shift
if [ -z "$kind" ] || ! declare -F "msg_$kind" >/dev/null; then
    echo "kinds: $(declare -F | sed -n 's/^declare -f msg_\([a-z_-]*\)$/\1/p' | grep -v '^head$\|^handoff_extra' | paste -sd' ' -)"
    [ -z "$kind" ] && exit 0 || exit 1
fi
TO=""; send=0; args=()
while [ $# -gt 0 ]; do
    case "$1" in --to) TO="${2:-}"; shift 2 ;; --send) send=1; shift ;; *) args+=("$1"); shift ;; esac
done
[ -n "$TO" ] || TO="$(coordinator)"; [ -n "$TO" ] || TO="all"
if [ "$send" -eq 0 ]; then "msg_$kind" ${args[@]+"${args[@]}"}; exit 0; fi
# --send: the same text, plus a durable copy in the recipient's mailbox (inbox.sh)
load_area inbox
out="$("msg_$kind" ${args[@]+"${args[@]}"})"
printf '%s\n' "$out"
mail_send "$FROM" "$TO" "$kind" <<<"$out"   # not a pipe: MAIL_TO must survive
note "in the mailbox of ${MAIL_TO:-nobody} — send it with SendMessage as well"
