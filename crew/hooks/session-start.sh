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
    # membership is opt-in (PLUG-055): only `crew whoami` joins. A session outside the crew works
    # as usual — the guards key on NAME — so a session is never put under them by starting here.
    # identity for every later Bash command: CLAUDE_ENV_FILE is a preamble Claude Code runs before
    # each one, so `crew` then knows the caller with no CREW_AS prefix (written once per session)
    run=""
    if [ -n "${CLAUDE_ENV_FILE:-}" ] && [ -n "$SID" ]; then
        grep -qx "export CREW_SID=$SID" "$CLAUDE_ENV_FILE" 2>/dev/null || printf 'export CREW_SID=%s\n' "$SID" >> "$CLAUDE_ENV_FILE"
        run=crew
    fi
    if [ -n "$NAME" ]; then
        role="$(sess_get "$NAME" role)"; c="$(coordinator)"
        echo "crew $(crew_id): you are $NAME ($role) · committer: $(cfg committer)${c:+ ($c coordinates)} · guards: $(cfg hookMode) · crew: $(crew_line)"
        echo "crew: run crew commands as: ${run:-$(prefix_for "$NAME")} <command> — start with 'status'; 'help' lists commands. Working rules: the crew skill."
        load_area inbox; declare -F mail_start >/dev/null && mail_start "$NAME" "$SID"
        load_area watch; declare -F watch_stamp >/dev/null && watch_stamp "$SID"
    else
        echo "crew: this repo runs crew $(crew_id) ($(crew_line)); you are not in it — its guards do not apply to you, work as usual. Only if the user puts this session in the crew: crew whoami \"<the name peers address you by in SendMessage>\" [worker|coordinator] — spaces are fine; it must be unique on this machine. Working rules: the crew skill."
    fi
)
exit 0
