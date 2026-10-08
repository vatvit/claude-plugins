#!/usr/bin/env bash
# crew PreToolUse hook for Bash:
#   1. `crew.sh whoami <name>` — leave this session's id for whoami.sh to bind (works before a
#      crew exists: it is how one starts)
#   2. git guard — deny commands that touch the whole shared index or tree (land area)
# Always exits 0; a denial is a JSON decision on stdout, not an exit code.
h="${BASH_SOURCE[0]%/*}"; [ "$h" != "${BASH_SOURCE[0]}" ] || h=.; . "$h/fast.sh"   # no fork
crew_fast_read
case "$PAYLOAD" in *whoami*) ;; *) crew_fast_skip && exit 0 ;; esac   # whoami may start a crew
# only commands that can trip the git guard (or start a crew) need the full hook
case "$PAYLOAD" in
    *whoami*|*git*" add"*|*git*commit*|*git*stash*|*git*checkout*|*git*switch*|*git*restore*|*git*reset*|*git*clean*) ;;
    *git*worktree*|*git*branch*|*git*rebase*|*git*pull*|*git*merge*|*git*cherry-pick*|*git*revert*|*git*" am"*|*git*push*) ;;
    *) exit 0 ;;
esac
(
    . "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd -P)/lib.sh"
    hook_init || exit 0
    cmd="$(printf '%s' "$PAYLOAD" | payload_str command)"
    case "$cmd" in
        *crew.sh*whoami*)
            n="$(printf '%s\n' "$cmd" | awk '{ for (i = 1; i < NF; i++) if ($i == "whoami") { print $(i + 1); exit } }')"
            if valid_name "$n" && [ -n "$SID" ]; then
                mkdir -p "$STATE/pending" && printf '%s\n' "$SID" > "$STATE/pending/$n"
            fi ;;
    esac
    crew_active || exit 0
    load_area land; declare -F git_guard >/dev/null && git_guard "$NAME" "$cmd"
    exit 0
)
exit 0
