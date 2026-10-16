#!/usr/bin/env bash
# lib.sh — shared helpers for task-roadmap. Sourced, never executed.
#
# SCOPE: this file belongs to task-roadmap and is sourced only by task-roadmap's own
# scripts. Plugins must work standalone and in any combination, so nothing here may be
# shared with another plugin and nothing here may source another plugin's file. DRY
# applies *within* a plugin — a sibling plugin carrying its own copy of a small helper
# is correct, not debt.

# json_str <key> <file> — first string value for <key>, or empty.
#
# The `|| true` is load-bearing. generate.sh runs under `set -euo pipefail`, and grep
# exits non-zero when it matches nothing; with pipefail that status propagates out of
# the pipeline, out of `v="$(json_str …)"`, and kills the script. A key simply being
# absent from a config file is normal, not an error.
#
# This was a real shipped bug: any .task-roadmap.json that did not contain *every*
# key aborted generation. It went unnoticed because the .task-config.json read
# happened to sit inside an `&&` list, where `set -e` is suppressed.
json_str() {
  grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$2" 2>/dev/null \
    | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//' || true
}

# json_str_array <key> <file> — one element per line for a single-line string array.
json_str_array() {
  grep -o "\"$1\"[[:space:]]*:[[:space:]]*\[[^]]*\]" "$2" 2>/dev/null \
    | grep -o '"[^"]*"' | sed '1d; s/^"//; s/"$//' || true
}

# resolve_tasks_dir <project-root> — the configured tasks directory, relative.
#
# ONE implementation of the precedence rule, because there used to be two: generate.sh
# read .task-config.json then let .task-roadmap.json overwrite, while the hook looped
# both and broke on the first hit. They agreed only by coincidence, and nothing would
# have caught them drifting apart.
#
# Precedence: .task-roadmap.json > .task-config.json > "tasks".
#
# Reading a key out of .task-config.json — a file another tool owns — is deliberate and
# allowed: it is shared *data*, not shared code, and this degrades to the default when
# the file is absent. task-roadmap never requires the task tooling to be installed.
resolve_tasks_dir() {
  local root="$1" v dir="tasks"
  [ -f "$root/.task-config.json" ] && {
    v="$(json_str tasksDir "$root/.task-config.json")"; [ -n "$v" ] && dir="$v"; }
  [ -f "$root/.task-roadmap.json" ] && {
    v="$(json_str tasksDir "$root/.task-roadmap.json")"; [ -n "$v" ] && dir="$v"; }
  printf '%s\n' "${dir%/}"
  return 0
}

# project_root <dir> — the project <dir> stands for. Inside a linked git worktree that
# is the same place in the main tree: each worktree checks out its own stale copy of
# the tasks, and the roadmap belongs to the main tree's. Anywhere else (no git, the
# main tree, a bare repo's worktree) it is <dir> unchanged. The task plugin applies the
# same rule in its own copy — plugins share no code.
project_root() {
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
