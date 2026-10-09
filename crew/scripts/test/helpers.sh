#!/usr/bin/env bash
# Shared test helpers for crew suites. Sourced by every *.test.sh.
#
# Each suite works in a throwaway git repo under mktemp -d; the user's real ~/.claude/crew.json
# is never read (CREW_USER_CONFIG points into the fixture).
set -uo pipefail

S="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"     # crew/scripts
H="$(cd "$S/../hooks" && pwd -P)"                             # crew/hooks
C="$S/crew.sh"
TMP="$(mktemp -d)"; TMP="$(cd "$TMP" && pwd -P)"             # macOS: /var -> /private/var
trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0
export CREW_USER_CONFIG="$TMP/user-crew.json"
export CREW_HOME="$TMP/crew-home"                             # machine-wide name registry
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
export GIT_CONFIG_NOSYSTEM=1 HOME="$TMP/home"; mkdir -p "$HOME"

check() { # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"
    else fail=$((fail+1)); echo "  FAIL $1"; echo "         expected: [$2]"; echo "         actual:   [$3]"; fi
}
contains() { case "$2" in *"$1"*) echo yes ;; *) echo no ;; esac; }   # contains <needle> <haystack>
finish() { echo "$(basename "$0"): $pass passed, $fail failed"; [ "$fail" -eq 0 ]; }

# new_repo <dir> — a repo with one commit on branch main
new_repo() {
    mkdir -p "$1" && git -C "$1" init -q -b main 2>/dev/null || { git -C "$1" init -q && git -C "$1" checkout -q -b main; }
    printf 'one\n' > "$1/a.txt"; printf 'base\n' > "$1/b.txt"
    git -C "$1" add -A && git -C "$1" commit -q -m init
}

json_esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk 'BEGIN { ORS = "\\n" } { print }' | sed 's/\\n$//'; }
# payload <sid> <cwd> <tool> <key> <value> — a PreToolUse/SessionStart-shaped hook payload
payload() {
    printf '{"session_id":"%s","cwd":"%s","hook_event_name":"x","tool_name":"%s","tool_input":{"%s":"%s","content":"x"}}' \
        "$1" "$2" "$3" "$4" "$(json_esc "$5")"
}
hook() { # hook <script> <payload> -> stdout; returns the hook exit code
    local out rc; out="$(printf '%s' "$2" | bash "$H/$1" 2>"$TMP/hook.err")"; rc=$?; printf "%s" "$out"; return $rc
}
denied() { contains '"permissionDecision":"deny"' "$1"; }
mailhook() { printf '%s' "$2" | bash "$H/mail.sh" "$1" 2>"$TMP/hook.err"; }   # mailhook <post|stop> <payload>

# join <repo> <name> [role] — join through the real path: pre-bash hook sees the id, whoami binds it
join() {
    local cmd="bash $C whoami $2 ${3:-worker}"
    hook pre-bash.sh "$(payload "sid-$2" "$1" Bash command "$cmd")" >/dev/null
    (cd "$1" && bash "$C" whoami "$2" "${3:-worker}") >/dev/null
}
# edit <repo> <name> <path> <content> — the pre-edit hook, then the write itself
edit() {
    HOOK_OUT="$(hook pre-edit.sh "$(payload "sid-$2" "$1" Edit file_path "$1/$3")")"
    [ "$(denied "$HOOK_OUT")" = yes ] && return 1
    mkdir -p "$(dirname "$1/$3")"; printf '%s\n' "$4" > "$1/$3"
}
crew_as() { local n="$1" r="$2"; shift 2; (cd "$r" && CREW_AS="$n" bash "$C" "$@"); }
