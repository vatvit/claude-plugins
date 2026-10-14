#!/usr/bin/env bash
# crew PreToolUse hook for Bash:
#   1. `crew.sh whoami <name>` — leave this session's id for whoami.sh to bind (works before a
#      crew exists: it is how one starts)
#   2. git guard (crew members only) — deny commands that touch the whole shared index or tree (land area)
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
            # the argument after whoami: a bare word, or a quoted display name ("Max Coordinator")
            n="$(printf '%s\n' "$cmd" | awk '{ i = index($0, "whoami "); if (!i) exit; s = substr($0, i + 7); sub(/^ +/, "", s)
                q = substr(s, 1, 1); if (q == "\"" || q == "'\''") { s = substr(s, 2); print substr(s, 1, index(s, q) - 1) }
                else { split(s, a, /[ \t;&|]/); print a[1] } exit }')"
            n="$(name_for "$n")"
            if valid_name "$n" && [ -n "$SID" ]; then
                mkdir -p "$CREW_PENDING" && printf '%s\n' "$SID" > "$CREW_PENDING/$n"
            fi ;;
    esac
    crew_active || exit 0
    [ -n "$NAME" ] || exit 0              # outside the crew: works as usual (PLUG-055)
    load_area land; declare -F git_guard >/dev/null && git_guard "$NAME" "$cmd"
    exit 0
)
exit 0
