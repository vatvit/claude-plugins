#!/usr/bin/env bash
# Shared helpers for the task plugin's scripts. Source it, don't execute it.

# task_global_roots -> global (cross-project) storage roots, one per line,
# most specific first. Claude Code sets CLAUDE_CONFIG_DIR when it runs under a
# non-default account (e.g. ~/.claude-work); ~/.claude stays as the fallback so
# a registry created there keeps resolving from every account.
task_global_roots() {
    if [ -n "${CLAUDE_CONFIG_DIR:-}" ] && [ "${CLAUDE_CONFIG_DIR%/}" != "$HOME/.claude" ]; then
        printf '%s/project-tasks\n' "${CLAUDE_CONFIG_DIR%/}"
    fi
    printf '%s/.claude/project-tasks\n' "$HOME"
}

# task_global_file <relpath> -> the first <root>/<relpath> that exists, or
# nothing. An absent file is normal, so this always returns 0.
task_global_file() {
    local root
    while IFS= read -r root; do
        if [ -f "$root/$1" ]; then
            printf '%s\n' "$root/$1"
            return 0
        fi
    done <<EOR
$(task_global_roots)
EOR
    return 0
}

# task_project_dir <dir> -> the project directory <dir> stands for. Inside a
# linked git worktree that is the same place in the main tree: every worktree
# checks out its own copy of the config and the tasks folder, and resolving
# from that copy gave each worktree its own id lock and id sequence. Anywhere
# else (no git, the main tree, a bare repo's worktree) it is <dir> unchanged.
task_project_dir() {
    local dir="$1" out gd cd prefix main
    out=$(cd "$dir" 2>/dev/null && git rev-parse --git-dir --git-common-dir --show-prefix 2>/dev/null) \
        || { printf '%s\n' "$dir"; return 0; }
    gd=$(printf '%s\n' "$out" | sed -n 1p)
    cd=$(printf '%s\n' "$out" | sed -n 2p)
    prefix=$(printf '%s\n' "$out" | sed -n 3p)
    gd=$(cd "$dir" && cd "$gd" 2>/dev/null && pwd -P) || { printf '%s\n' "$dir"; return 0; }
    cd=$(cd "$dir" && cd "$cd" 2>/dev/null && pwd -P) || { printf '%s\n' "$dir"; return 0; }
    # The main tree, or a bare repo's worktree: nothing to map to.
    if [ "$gd" = "$cd" ] || [ "${cd##*/}" != ".git" ]; then
        printf '%s\n' "$dir"; return 0
    fi
    main="${cd%/.git}"
    [ -d "$main" ] || { printf '%s\n' "$dir"; return 0; }
    prefix="${prefix%/}"
    if [ -n "$prefix" ]; then printf '%s/%s\n' "$main" "$prefix"; else printf '%s\n' "$main"; fi
    return 0
}

# task_fm_set <file> <key> <value> [--require] -> set `key: value` in the
# frontmatter. An existing line is replaced, an absent key is added before the
# closing `---`, an empty value removes the line. With --require an absent key
# is an error (return 3) instead. The value goes through ENVIRON, not `awk -v`,
# which would read its backslashes as escapes. Written via a temp file and mv,
# skipped when nothing changed, so an unchanged file keeps its mtime.
task_fm_set() {
    local f="$1" k="$2" v="$3" req="${4:-}" tmp="$1.$$"
    FM_KEY="$k" FM_VAL="$v" FM_REQ="$req" awk '
    BEGIN { k = ENVIRON["FM_KEY"]; v = ENVIRON["FM_VAL"]; req = (ENVIRON["FM_REQ"] == "--require") }
    NR == 1 && /^---[ \t]*$/ { infm = 1; print; next }
    infm && /^---[ \t]*$/ {
        if (!done && v != "" && !req) { print k ": " v; done = 1 }
        infm = 0; print; next
    }
    infm && index($0, k ":") == 1 {
        if (v != "") print k ": " v
        done = 1; next
    }
    { print }
    END { if (req && !done) exit 3 }
    ' "$f" > "$tmp" || { rm -f "$tmp"; return 3; }
    if cmp -s "$tmp" "$f"; then rm -f "$tmp"; else mv "$tmp" "$f"; fi
    return 0
}
