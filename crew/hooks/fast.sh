# Sourced first by every crew hook. Builtins only — no fork — because the hooks run on every Bash
# call and every edit in EVERY repo, and most repos have no crew. Decides "no crew here" in ~0 ms.

# crew_fast_read — the hook payload from stdin into PAYLOAD (read, not cat: no fork)
crew_fast_read() { PAYLOAD=""; IFS= read -r -d '' PAYLOAD || true; }

# crew_fast_skip — true when no crew can be active for the payload's cwd: the nearest .git is a
# directory without crew/ in it, or there is no repo at all. A .git FILE (submodule) is "unsure".
# When it finds the crew, CREW_FAST_STATE is its state dir (empty when unsure).
crew_fast_skip() {
    local re='"cwd"[[:space:]]*:[[:space:]]*"([^"]*)"' d=""
    CREW_FAST_STATE=""
    [[ $PAYLOAD =~ $re ]] && d="${BASH_REMATCH[1]}"
    [ -n "$d" ] || d="${CLAUDE_PROJECT_DIR:-$PWD}"
    while :; do
        if [ -d "$d/.git" ]; then [ -d "$d/.git/crew" ] && { CREW_FAST_STATE="$d/.git/crew"; return 1; }; return 0; fi
        [ -e "$d/.git" ] && return 1
        [ -z "$d" ] || [ "$d" = / ] && return 0
        d="${d%/*}"
    done
}

# crew_fast_sid — the payload's session id into CREW_FAST_SID (empty when absent or unsafe as a filename)
crew_fast_sid() {
    local re='"session_id"[[:space:]]*:[[:space:]]*"([^"/]+)"'
    CREW_FAST_SID=""
    [[ $PAYLOAD =~ $re ]] && CREW_FAST_SID="${BASH_REMATCH[1]}"
    return 0
}

# crew_fast_seen — after crew_fast_skip: stamp this session's activity ($STATE/seen/<sid>, its
# mtime is the time; watch.sh reads it). A redirection on a builtin, so no fork; no seen/ dir yet
# (a crew from before the watchdog) just means no stamp until the next join or SessionStart.
crew_fast_seen() {
    [ -n "$CREW_FAST_STATE" ] || return 0
    crew_fast_sid
    [ -n "$CREW_FAST_SID" ] && [ -d "$CREW_FAST_STATE/seen" ] && : > "$CREW_FAST_STATE/seen/$CREW_FAST_SID"
    return 0
}

# crew_fast_unread — after crew_fast_skip: false when the payload's session has no unread-mail
# marker (inbox.sh leaves $STATE/unread/<sid>). Unsure (no state dir found) is true.
crew_fast_unread() {
    [ -n "$CREW_FAST_STATE" ] || return 0
    crew_fast_sid
    [ -n "$CREW_FAST_SID" ] && [ -e "$CREW_FAST_STATE/unread/$CREW_FAST_SID" ]
}
