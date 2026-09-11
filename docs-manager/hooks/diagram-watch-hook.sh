#!/bin/bash
#
# docs-manager PostToolUse hook — warn when an edited file is watched by a diagram.
#
# This is the valuable half of the staleness feature. `docs.sh diagram check` tells
# you a diagram is suspect at some later point, in CI or when someone remembers to
# look. This tells the person who just changed the code, while the change is fresh —
# which is the only moment a diagram actually gets fixed.
#
# Contract, in order of importance:
#   1. ALWAYS exit 0. It never blocks the tool call that triggered it, whatever
#      happens — no diagrams, no docs dir, malformed payload, unreadable file.
#   2. NEVER write anything. It reports; blessing stays a human act.
#   3. Be cheap when there is nothing to do. Most projects have no diagram sources;
#      those pay one `find` and stop.
#
# Note the warning goes to stderr deliberately, so do NOT wrap this in a
# `2>/dev/null` guard — that would silence the one thing the hook is for.
#
# Reads the hook payload (JSON) on stdin.

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

input="$(cat)"
fp="$(printf '%s' "$input" \
  | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')"
[ -n "$fp" ] || exit 0

# Resolve the docs root. A project without one has nothing to check.
DOCS_DIR="${DOCS_MANAGER_ROOT:-docs}"
case "$DOCS_DIR" in /*) : ;; *) DOCS_DIR="$ROOT/$DOCS_DIR" ;; esac
[ -d "$DOCS_DIR" ] || exit 0

# Cheap exit for the common case: no diagram sources at all.
sources="$(find "$DOCS_DIR" -type f -name '*.diagram.md' 2>/dev/null)"
[ -n "$sources" ] || exit 0

ROOT_DEFAULT="$DOCS_DIR"
# shellcheck source=../scripts/lib.sh
. "$PLUGIN_ROOT/scripts/lib.sh" || exit 0
# shellcheck source=../scripts/diagram.sh
. "$PLUGIN_ROOT/scripts/diagram.sh" || exit 0

# Absolute, normalized path of the edited file, to compare against watch targets.
case "$fp" in
  /*) edited="$(normalize_path "$fp")" ;;
  *)  edited="$(normalize_path "$ROOT/$fp")" ;;
esac

while IFS= read -r src; do
  [ -n "$src" ] || continue
  while IFS= read -r watched; do
    [ -n "$watched" ] || continue
    if [ "$(normalize_path "$watched")" = "$edited" ]; then
      echo "docs-manager: $fp is watched by $src — the diagram may now be wrong." >&2
      echo "  review it, then: docs.sh diagram bless $(basename "$src" .diagram.md)" >&2
      break
    fi
  done <<EOF
$(watch_files "$src" 2>/dev/null)
EOF
done <<EOF
$sources
EOF

exit 0
