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

# charter_file <root> — the charter charter.sh writes. Its existence is the `charter written` fact:
# the docs are written, so the What-next questions (questionnaire §N) may be asked.
charter_file() { printf '%s/docs/project/charter.md\n' "$1"; }

# --- HOME is optional (PLUG-121; repo CLAUDE.md, "Without HOME: the project folder must be enough") ---

# kickoff_account_dir — the per-account Claude dir: $CLAUDE_CONFIG_DIR, else ~/.claude; nothing when
# neither exists to name (HOME unset and no CLAUDE_CONFIG_DIR). Files in it are read, never required.
kickoff_account_dir() {
    if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then printf '%s\n' "${CLAUDE_CONFIG_DIR%/}"
    elif [ -n "${HOME:-}" ]; then printf '%s/.claude\n' "$HOME"; fi
    return 0
}

# kickoff_home_usable — 0 when kickoff could keep its dir under HOME. A set $HOME proves nothing: it may
# be a sandbox's throwaway home, or a path that cannot be written. The probe leaves nothing behind and
# never creates or removes the shared ~/.claude/kickoff itself: a process that made and removed it once
# pulled it from under a concurrent probe, which then called HOME unusable (home 8a/8b). So with the dir
# present it writes a temp file in it; without, a temp dir of its own in the nearest existing ancestor.
# An ancestor that exists but is not a directory (HOME is a file) means no.
kickoff_home_usable() {
    [ -n "${HOME:-}" ] || return 1
    local d="$HOME/.claude/kickoff" p t
    if [ -d "$d" ]; then
        t="$(mktemp "$d/.probe.XXXXXX" 2>/dev/null)" || return 1
        rm -f "$t"; return 0
    fi
    p="$d"
    while [ ! -d "$p" ]; do
        [ ! -e "$p" ] || return 1
        p="${p%/*}"; [ -n "$p" ] || p=/
    done
    t="$(mktemp -d "$p/.kickoff-probe.XXXXXX" 2>/dev/null)" || return 1
    rmdir "$t"; return 0
}

# project_config_file <root> — kickoff's own choices for this project (flat JSON, every key optional).
# Today: "ports": "home" | "project". Lives in the project, so the choice is there when HOME is not.
project_config_file() { printf '%s/.kickoff.json\n' "$1"; }

# project_state_dir <root> — where kickoff keeps per-project state that is never committed: .git/kickoff
# in a git repo, .kickoff/ otherwise.
project_state_dir() {
    if [ -d "$1/.git" ]; then printf '%s/.git/kickoff\n' "$1"; else printf '%s/.kickoff\n' "$1"; fi
}

# task_registry_roots — the task plugin's global project-tasks dirs, one per line, most specific first:
# CLAUDE_CONFIG_DIR's, then ~/.claude's (skipped when HOME is empty). The task plugin computes the same
# list itself; plugins share no code, so this is kickoff's own copy of the semantics.
task_registry_roots() {
    local home="${HOME:-}"
    if [ -n "${CLAUDE_CONFIG_DIR:-}" ] && [ "${CLAUDE_CONFIG_DIR%/}" != "$home/.claude" ]; then
        printf '%s/project-tasks\n' "${CLAUDE_CONFIG_DIR%/}"
    fi
    [ -z "$home" ] || printf '%s/.claude/project-tasks\n' "$home"
    return 0
}

# task_registry_entry_file <root> — the first registry config.json that lists <root>; nothing when none does.
task_registry_entry_file() {
    local d
    while IFS= read -r d; do
        [ -n "$d" ] && [ -r "$d/config.json" ] && grep -qF "\"$1\":" "$d/config.json" 2>/dev/null \
            && { printf '%s\n' "$d/config.json"; return 0; }
    done <<EOR
$(task_registry_roots)
EOR
    return 0
}

# user_defaults_file — the user layer: the user's own defaults, overriding the questionnaire's ★.
# PER ACCOUNT on purpose (repo CLAUDE.md, "Per account or per machine"): a work account and a
# personal one answer "whose project?" differently, so it follows CLAUDE_CONFIG_DIR. Nothing when
# there is no account dir (no HOME): then there are no user defaults.
user_defaults_file() { local d; d="$(kickoff_account_dir)"; [ -z "$d" ] || printf '%s/kickoff.json\n' "$d"; }

# defaults_tsv — the user layer as `ID<TAB>value` lines; nothing when the file is absent.
# A flat JSON object of question ids to strings; \" and \\ escapes are decoded. Other keys are ignored.
defaults_tsv() {
    local f; f="$(user_defaults_file)"
    [ -n "$f" ] && [ -f "$f" ] && [ -r "$f" ] || return 0
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
    local f; f="$(kickoff_account_dir)/plugins/installed_plugins.json"
    [ "$f" != "/plugins/installed_plugins.json" ] && [ -f "$f" ] && [ -r "$f" ] || { echo; return 0; }
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
    local prog="$1" root="$2" ans defs plugins written=0; shift 2
    ans="$(answers_file "$root")"; [ -f "$ans" ] || ans=/dev/null
    defs="$(mktemp)"; defaults_tsv > "$defs"
    plugins="$(installed_plugins "$root")"
    [ -f "$(charter_file "$root")" ] && written=1
    awk -v plugins="$plugins" -v written="$written" "$@" -f "$KICKOFF_LIB_AWK" -f "$KICKOFF_SCRIPTS/$prog" "$ans" "$defs" "$KICKOFF_QUESTIONNAIRE"
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
