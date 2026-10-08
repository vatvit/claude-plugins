#!/usr/bin/env bash
# crew SessionStart hook — a few lines of context, and NOTHING in a repo without a crew, so the
# plugin costs no tokens where it is not used. Runs again after /compact, which re-teaches the prefix.
# Always exits 0.
(
    . "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd -P)/lib.sh"
    hook_init || exit 0
    crew_active || exit 0
    if [ -n "$NAME" ]; then
        role="$(sess_get "$NAME" role)"; c="$(coordinator)"
        echo "crew $(crew_id): you are $NAME ($role) · committer: $(cfg committer)${c:+ ($c coordinates)} · guards: $(cfg hookMode) · crew: $(crew_line)"
        echo "crew: run crew commands as: $(prefix_for "$NAME") <command> — start with 'status'; 'help' lists commands. Working rules: the crew skill."
    else
        echo "crew: this repo runs crew $(crew_id) ($(crew_line)). Join before editing: bash $CREW_BIN whoami <name> [worker|coordinator] — use the name peers address you by in SendMessage, unique on this machine (e.g. $(crew_id)-s1). Working rules: the crew skill."
    fi
)
exit 0
