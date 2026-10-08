#!/usr/bin/env bash
# crew PreToolUse hook for Bash:
#   1. `crew.sh whoami <name>` — leave this session's id for whoami.sh to bind (works before a
#      crew exists: it is how one starts)
#   2. git guard — deny commands that touch the whole shared index or tree (land area)
# Always exits 0; a denial is a JSON decision on stdout, not an exit code.
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
