#!/usr/bin/env bash
# defaults.sh list | set <ID> <value> | unset <ID> — the user's own defaults, for this account.
#
# Kept in ${CLAUDE_CONFIG_DIR:-~/.claude}/kickoff.json, a flat JSON object of question ids to
# strings. A default here wins over the questionnaire's ★ (and over its (★ if …)), for every
# project this Claude account kicks off. Every key is optional; an absent file means none.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

f="$(user_defaults_file)"
cmd="${1:-}"; [ $# -gt 0 ] && shift

# write_tsv <tsv> — the file rewritten from ID TAB value lines, sorted by id, diff-guarded.
write_tsv() {
    local t; t="$(mktemp)"
    sort "$1" | awk -f "$KICKOFF_SCRIPTS/json.awk" -f "$KICKOFF_SCRIPTS/defaults-write.awk" > "$t"
    mkdir -p "$(dirname "$f")"; write_if_changed "$f" "$t" 1 >/dev/null
}
known() { grep -q "^| $1 |" "$KICKOFF_QUESTIONNAIRE" || { echo "defaults.sh: no question $1 in the questionnaire" >&2; exit 2; }; }

case "$cmd" in
    list) defaults_tsv ;;
    set)
        [ $# -eq 2 ] || { echo "usage: defaults.sh set <ID> <value>" >&2; exit 2; }
        known "$1"; case "$2" in *$'\n'*|*$'\t'*) echo "defaults.sh: a value is one line, no tabs" >&2; exit 2 ;; esac
        t="$(mktemp)"; { defaults_tsv | awk -F'\t' -v id="$1" '$1 != id'; printf '%s\t%s\n' "$1" "$2"; } > "$t"
        write_tsv "$t"; rm -f "$t" ;;
    unset)
        [ $# -eq 1 ] || { echo "usage: defaults.sh unset <ID>" >&2; exit 2; }
        [ -f "$f" ] || exit 0
        t="$(mktemp)"; defaults_tsv | awk -F'\t' -v id="$1" '$1 != id' > "$t"; write_tsv "$t"; rm -f "$t" ;;
    *) echo "usage: defaults.sh list | set <ID> <value> | unset <ID>" >&2; exit 2 ;;
esac
