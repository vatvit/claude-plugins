#!/usr/bin/env bash
#
# task-roadmap PostToolUse hook — regenerate the roadmap when a task file changes.
#
# Fires after Edit/Write/MultiEdit. If the edited file is a task markdown file
# under the project's tasks dir (excluding _workflow/ definitions), regenerate.
# Reads the hook payload (JSON) on stdin; never blocks a tool call (always exit 0).
#
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"

input="$(cat)"
fp="$(printf '%s' "$input" \
  | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')"
[ -n "$fp" ] || exit 0

# Same precedence rule as generate.sh, from the same function — these were two
# separate implementations that agreed only by coincidence.
# shellcheck source=lib.sh
. "$PLUGIN_ROOT/scripts/lib.sh"
TASKS_DIR="$(resolve_tasks_dir "$ROOT")"

case "$fp" in
  */"$TASKS_DIR"/_workflow/*) exit 0 ;;      # workflow defs, not tasks
  */"$TASKS_DIR"/*.md)
    if bash "$PLUGIN_ROOT/scripts/generate.sh" "$ROOT" >/dev/null 2>&1; then
      echo "task-roadmap: regenerated" >&2
    fi
    ;;
esac
exit 0
