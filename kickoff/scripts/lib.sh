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

# user_defaults_file — the user layer: the user's own defaults, overriding the questionnaire's ★.
# PER ACCOUNT on purpose (repo CLAUDE.md, "Per account or per machine"): a work account and a
# personal one answer "whose project?" differently, so it follows CLAUDE_CONFIG_DIR.
user_defaults_file() { printf '%s/kickoff.json\n' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; }

# defaults_tsv — the user layer as `ID<TAB>value` lines; nothing when the file is absent.
# A flat JSON object of question ids to strings; \" and \\ escapes are decoded. Other keys are ignored.
defaults_tsv() {
    local f; f="$(user_defaults_file)"
    [ -f "$f" ] || return 0
    awk '
        { s = s $0 "\n" }
        END {
            while (match(s, /"[A-Z][0-9]+"[ \t\n]*:[ \t\n]*"/)) {
                k = substr(s, RSTART + 1, RLENGTH); sub(/".*/, "", k)
                s = substr(s, RSTART + RLENGTH); v = ""
                while (s != "") {
                    c = substr(s, 1, 1)
                    if (c == "\\") { v = v substr(s, 2, 1); s = substr(s, 3); continue }
                    if (c == "\"") { s = substr(s, 2); break }
                    v = v c; s = substr(s, 2)
                }
                print k "\t" v
            }
        }' "$f"
    return 0
}

# installed_plugins <root> — the plugins Claude Code has enabled for this project, space-separated
# names without their marketplace: user-scoped ones, and local- or project-scoped ones installed for
# <root>. Read from Claude Code's own record; nothing when it is absent. KICKOFF_PLUGINS, when set
# (even empty), replaces the lookup — the tests pin it that way. Conditions `<plugin> installed`.
installed_plugins() {
    if [ -n "${KICKOFF_PLUGINS+set}" ]; then printf '%s\n' "$KICKOFF_PLUGINS"; return 0; fi
    local f="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json"
    [ -f "$f" ] || { echo; return 0; }
    awk -v root="$1" '
        function val(s) { sub(/^[^:]*:[ \t]*"/, "", s); sub(/".*/, "", s); return s }
        /^    "[^"]+@[^"]+": \[/ { name = $0; sub(/^    "/, "", name); sub(/@.*/, "", name); next }
        name != "" && /"scope":/       { scope = val($0) }
        name != "" && /"projectPath":/ { path = val($0) }
        name != "" && /^      \}/ {
            if (scope != "" && scope != "local" && scope != "project") on[name] = 1
            else if (path == root) on[name] = 1
            scope = ""; path = ""
        }
        /^    \]/ { name = "" }
        END { for (n in on) out = out (out == "" ? "" : " ") n; print out }' "$f"
    return 0
}

# kickoff_awk <program.awk> <root> [awk args...] — run a program over the model. The answers file
# and the user layer are passed as files; an absent one becomes /dev/null.
kickoff_awk() {
    local prog="$1" root="$2" ans defs plugins; shift 2
    ans="$(answers_file "$root")"; [ -f "$ans" ] || ans=/dev/null
    defs="$(mktemp)"; defaults_tsv > "$defs"
    plugins="$(installed_plugins "$root")"
    awk -v plugins="$plugins" "$@" -f "$KICKOFF_LIB_AWK" -f "$KICKOFF_SCRIPTS/$prog" "$ans" "$defs" "$KICKOFF_QUESTIONNAIRE"
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
