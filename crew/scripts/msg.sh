#!/usr/bin/env bash
# Protocol messages, formatted and filled from crew state, ready to send with SendMessage.
# Kinds live in msg.d/ as msg_<kind> functions; Claude adds only the judgement lines.
# help: msg <kind> [--to NAME] [args] — print a ready-to-send message (msg with no kind lists kinds)
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
crew_init; need_active
for part in "$CREW_LIB_DIR"/msg.d/*.sh; do [ -f "$part" ] && . "$part"; done
FROM="$(me)"

# msg_head <KIND> <to> [summary]
msg_head() { echo "$FROM → $2: $1${3:+ — $3}"; }

kind="${1:-}"; [ $# -gt 0 ] && shift
if [ -z "$kind" ] || ! declare -F "msg_$kind" >/dev/null; then
    echo "kinds: $(declare -F | sed -n 's/^declare -f msg_\([a-z_-]*\)$/\1/p' | grep -v '^head$\|^handoff_extra' | paste -sd' ' -)"
    [ -z "$kind" ] && exit 0 || exit 1
fi
TO=""; args=()
while [ $# -gt 0 ]; do
    case "$1" in --to) TO="${2:-}"; shift 2 ;; *) args+=("$1"); shift ;; esac
done
[ -n "$TO" ] || TO="$(coordinator)"; [ -n "$TO" ] || TO="all"
"msg_$kind" ${args[@]+"${args[@]}"}
