#!/usr/bin/env bash
# statusline-segment.sh — Status line segment that displays the session notation.
#
# This script reads the session_id from Claude Code's JSON input (stdin)
# and prints the notation if one is set.
#
# Integration: Add this to your existing statusline-command.sh, or use it standalone.
#
# Standalone usage in settings.json:
#   "statusLine": { "type": "command", "command": "bash /path/to/statusline-segment.sh" }
#
# Integration usage (add to your existing statusline script):
#   notation=$("${PLUGIN_ROOT}/scripts/statusline-segment.sh" <<< "$input")
#   [ -n "$notation" ] && out+="   $notation"

NOTATION_DIR="/tmp/claude-notations"
BOLD="\033[1m"
RESET="\033[0m"

input=$(cat)

session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)

if [ -n "$session_id" ]; then
  notation_file="${NOTATION_DIR}/${session_id}"
  if [ -f "$notation_file" ]; then
    notation=$(cat "$notation_file" 2>/dev/null)
    if [ -n "$notation" ]; then
      printf "${BOLD}🏷️  %s${RESET}" "$notation"
    fi
  fi
fi
