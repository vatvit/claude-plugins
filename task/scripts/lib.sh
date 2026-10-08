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
