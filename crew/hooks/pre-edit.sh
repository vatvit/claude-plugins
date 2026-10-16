#!/usr/bin/env bash
# crew PreToolUse hook for Edit/Write/MultiEdit/NotebookEdit, in this order:
#   1. holds guard (crew members only) — deny an edit to a file another session holds (or an unheld hot spot)
#   2. snapshot    — save the file's current content, so an overwrite can be recovered
#   3. claim       — record that this session touched the path (status, handoff, land read it)
# Each step comes from its area script and is skipped when that script is absent.
# Always exits 0; a denial is a JSON decision on stdout, not an exit code.
h="${BASH_SOURCE[0]%/*}"; [ "$h" != "${BASH_SOURCE[0]}" ] || h=.; . "$h/fast.sh"   # no fork
crew_fast_read
crew_fast_skip && exit 0
(
    . "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd -P)/lib.sh"
    hook_init || exit 0
    crew_active || exit 0
    fp="$(printf '%s' "$PAYLOAD" | payload_str file_path)"
    [ -n "$fp" ] || fp="$(printf '%s' "$PAYLOAD" | payload_str notebook_path)"
    [ -n "$fp" ] || exit 0
    case "$fp" in /*) : ;; *) fp="$CREW_PROJECT_DIR/$fp" ;; esac
    rel="$(rel_path "$fp")"
    case "$rel" in /*) exit 0 ;; esac          # outside the work tree: not crew's business
    case "$rel" in "$CREW_WT"/*) exit 0 ;; esac  # a copy (PLUG-065) is private: no hold, snapshot or claim
    [ -z "$NAME" ] || { load_area holds; declare -F holds_guard >/dev/null && holds_guard "$NAME" "$rel"; }   # members only (PLUG-055)
    load_area snapshot; declare -F snapshot_save >/dev/null && snapshot_save "${NAME:-?}" "$rel"
    [ -n "$NAME" ] && claim_add "$NAME" "$rel"
    exit 0
)
exit 0
