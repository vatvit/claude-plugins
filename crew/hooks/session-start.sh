#!/usr/bin/env bash
# crew SessionStart hook — a few lines of context, and NOTHING in a repo without a crew, so the
# plugin costs no tokens where it is not used. Runs again after /compact, which re-teaches the prefix.
# Always exits 0.
h="${BASH_SOURCE[0]%/*}"; [ "$h" != "${BASH_SOURCE[0]}" ] || h=.; . "$h/fast.sh"   # no fork
crew_fast_read
crew_fast_skip && exit 0
(
    . "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd -P)/lib.sh"
    hook_init || exit 0
    crew_active || exit 0
    # auto-join: a session with a title (--name, /rename) joins as a worker under that title —
    # never taking a name another session holds; the coordinator role stays an explicit choice
    title="$(printf '%s' "$PAYLOAD" | payload_str session_title)"
    if [ -z "$NAME" ] && [ -n "$title" ] && [ -n "$SID" ]; then
        n="$(name_for "$title")"
        if valid_name "$n" && [ ! -f "$STATE/sessions/$n" ] \
            && CREW_PROJECT_DIR="$CREW_PROJECT_DIR" bash "$CREW_BIN" whoami "$title" --sid "$SID" >/dev/null 2>&1; then
            NAME="$n"
        fi
    fi
    if [ -n "$NAME" ]; then
        role="$(sess_get "$NAME" role)"; c="$(coordinator)"
        echo "crew $(crew_id): you are $NAME ($role) · committer: $(cfg committer)${c:+ ($c coordinates)} · guards: $(cfg hookMode) · crew: $(crew_line)"
        echo "crew: run crew commands as: $(prefix_for "$NAME") <command> — start with 'status'; 'help' lists commands. Working rules: the crew skill."
        load_area inbox; declare -F mail_start >/dev/null && mail_start "$NAME" "$SID"
    else
        echo "crew: this repo runs crew $(crew_id) ($(crew_line)). Join before editing: bash $CREW_BIN whoami \"<the name peers address you by in SendMessage>\" [worker|coordinator] — spaces are fine; it must be unique on this machine. A session with a title (/rename) joins by itself. Working rules: the crew skill."
    fi
)
exit 0
