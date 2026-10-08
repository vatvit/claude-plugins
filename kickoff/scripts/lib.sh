#!/usr/bin/env bash
# lib.sh — shared helpers for kickoff. Sourced, never executed.
#
# SCOPE: this file belongs to kickoff and is sourced only by kickoff's own scripts. Plugins
# must work standalone and in any combination (repo CLAUDE.md, Plugin Independence), so
# nothing here is shared with another plugin. The questionnaire model itself lives in
# lib.awk; this file only locates things and writes files.

KICKOFF_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KICKOFF_LIB_AWK="$KICKOFF_SCRIPTS/lib.awk"
KICKOFF_QUESTIONNAIRE="${KICKOFF_QUESTIONNAIRE:-$KICKOFF_SCRIPTS/../skills/kickoff/references/questionnaire.md}"

# project_root [dir] — the project being kicked off: the argument, else $CLAUDE_PROJECT_DIR, else $PWD.
project_root() {
    local r="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}"
    (cd "$r" 2>/dev/null && pwd) || { echo "kickoff: no such directory: $r" >&2; return 1; }
}

# answers_file <root> — where the kickoff answers are kept, in the project.
answers_file() { printf '%s/.kickoff-answers\n' "$1"; }

# defaults_tsv — the user layer as `ID<TAB>value` lines, or nothing. Filled in by PLUG-038.
defaults_tsv() { return 0; }

# kickoff_awk <program.awk> <root> [awk args...] — run a program over the model. The answers file
# and the user layer are passed as files; an absent one becomes /dev/null.
kickoff_awk() {
    local prog="$1" root="$2" ans defs; shift 2
    ans="$(answers_file "$root")"; [ -f "$ans" ] || ans=/dev/null
    defs="$(mktemp)"; defaults_tsv > "$defs"
    awk "$@" -f "$KICKOFF_LIB_AWK" -f "$KICKOFF_SCRIPTS/$prog" "$ans" "$defs" "$KICKOFF_QUESTIONNAIRE"
    local rc=$?; rm -f "$defs"; return $rc
}

# write_if_changed <dest> <tmp> [force] — move tmp over dest unless nothing changed.
# Prints created | unchanged | updated | refused. A differing dest is refused (exit 3)
# unless force is "1": a generated file may have been edited by hand since.
write_if_changed() {
    local dest="$1" tmp="$2" force="${3:-0}"
    if [ ! -f "$dest" ]; then
        mkdir -p "$(dirname "$dest")" && mv "$tmp" "$dest" && echo created; return
    fi
    if cmp -s "$tmp" "$dest"; then rm -f "$tmp"; echo unchanged; return 0; fi
    if [ "$force" = 1 ]; then mv "$tmp" "$dest" && echo updated; return; fi
    rm -f "$tmp"; echo refused; return 3
}
