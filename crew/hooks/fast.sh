# Sourced first by every crew hook. Builtins only — no fork — because the hooks run on every Bash
# call and every edit in EVERY repo, and most repos have no crew. Decides "no crew here" in ~0 ms.

# crew_fast_read — the hook payload from stdin into PAYLOAD (read, not cat: no fork)
crew_fast_read() { PAYLOAD=""; IFS= read -r -d '' PAYLOAD || true; }

# crew_fast_skip — true when no crew can be active for the payload's cwd: the nearest .git is a
# directory without crew/ in it, or there is no repo at all. A .git FILE (submodule) is "unsure".
crew_fast_skip() {
    local re='"cwd"[[:space:]]*:[[:space:]]*"([^"]*)"' d=""
    [[ $PAYLOAD =~ $re ]] && d="${BASH_REMATCH[1]}"
    [ -n "$d" ] || d="${CLAUDE_PROJECT_DIR:-$PWD}"
    while :; do
        if [ -d "$d/.git" ]; then [ -d "$d/.git/crew" ] && return 1; return 0; fi
        [ -e "$d/.git" ] && return 1
        [ -z "$d" ] || [ "$d" = / ] && return 0
        d="${d%/*}"
    done
}
