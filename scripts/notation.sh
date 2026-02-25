#!/usr/bin/env bash
# notation.sh — Set, clear, or manage session-specific status line notations
#
# Usage:
#   notation.sh set <session_id> <text>     — Set notation for a session
#   notation.sh clear <session_id>           — Clear notation for a session
#   notation.sh get <session_id>             — Get current notation
#   notation.sh cleanup [max_age_hours]      — Remove stale files (default: 24h)
#   notation.sh list                         — List all active notations

NOTATION_DIR="/tmp/claude-notations"
mkdir -p "$NOTATION_DIR"

case "${1:-}" in
  set)
    session_id="$2"
    shift 2
    notation="$*"
    if [ -z "$session_id" ] || [ -z "$notation" ]; then
      echo "Usage: notation.sh set <session_id> <text>" >&2
      exit 1
    fi
    echo "$notation" > "${NOTATION_DIR}/${session_id}"
    echo "Notation set: $notation"
    ;;

  clear)
    session_id="$2"
    if [ -z "$session_id" ]; then
      echo "Usage: notation.sh clear <session_id>" >&2
      exit 1
    fi
    rm -f "${NOTATION_DIR}/${session_id}"
    echo "Notation cleared"
    ;;

  get)
    session_id="$2"
    if [ -z "$session_id" ]; then
      echo "Usage: notation.sh get <session_id>" >&2
      exit 1
    fi
    notation_file="${NOTATION_DIR}/${session_id}"
    if [ -f "$notation_file" ]; then
      cat "$notation_file"
    else
      echo "(no notation set)"
    fi
    ;;

  cleanup)
    max_age_hours="${2:-24}"
    find "$NOTATION_DIR" -type f -not -name ".*" -mmin +$((max_age_hours * 60)) -delete 2>/dev/null
    remaining=$(find "$NOTATION_DIR" -type f -not -name ".*" 2>/dev/null | wc -l | tr -d ' ')
    echo "Cleanup done. $remaining active notation(s) remaining."
    ;;

  list)
    files=$(find "$NOTATION_DIR" -type f -not -name ".*" 2>/dev/null)
    if [ -z "$files" ]; then
      echo "No active notations"
    else
      echo "$files" | while read -r f; do
        session=$(basename "$f")
        notation=$(cat "$f")
        # macOS stat format
        if stat -f %m "$f" >/dev/null 2>&1; then
          age_min=$(( ($(date +%s) - $(stat -f %m "$f")) / 60 ))
        else
          # Linux stat format
          age_min=$(( ($(date +%s) - $(stat -c %Y "$f")) / 60 ))
        fi
        echo "  ${session}: ${notation}  (${age_min}m ago)"
      done
    fi
    ;;

  *)
    echo "Usage: notation.sh {set|clear|get|cleanup|list}" >&2
    echo "" >&2
    echo "Commands:" >&2
    echo "  set <session_id> <text>   Set status line notation" >&2
    echo "  clear <session_id>        Clear notation" >&2
    echo "  get <session_id>          Get current notation" >&2
    echo "  cleanup [hours]           Remove stale files (default: 24h)" >&2
    echo "  list                      Show all active notations" >&2
    exit 1
    ;;
esac
