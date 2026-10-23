#!/usr/bin/env bash
# answer.sh [--root DIR] [--add] <ID> <value> — record one answer in <root>/.kickoff-answers.
#
#   <ID>        a question id from the questionnaire (A3), <ID>.why for the reason behind it, or
#               <ID>.from for the evidence an answer was recovered from (an existing project)
#   --add       append another value instead of replacing (lists: C2, E4 …)
#   --clear     remove the answer (and nothing else); no value then
#
# One line per value, `ID: value`. The write goes through a temp file and is skipped when nothing
# changed, so recording the same answer twice never touches the file.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

root="" add=0 clear=0 args=()
while [ $# -gt 0 ]; do
    case "$1" in
        --root) root="$2"; shift 2 ;;
        --add) add=1; shift ;;
        --clear) clear=1; shift ;;
        -*) echo "answer.sh: unknown option $1" >&2; exit 2 ;;
        *) args+=("$1"); shift ;;
    esac
done
id="${args[0]:-}"; value="${args[1]:-}"
if [ -z "$id" ] || { [ "$clear" = 0 ] && [ "${#args[@]}" -ne 2 ]; }; then
    echo "usage: answer.sh [--root DIR] [--add|--clear] <ID> <value>" >&2; exit 2
fi
case "$value" in *$'\n'*) echo "answer.sh: a value is one line" >&2; exit 2 ;; esac
root="$(project_root "$root")"

base="${id%.why}"; base="${base%.from}"
grep -q "^| $base |" "$KICKOFF_QUESTIONNAIRE" || { echo "answer.sh: no question $base in the questionnaire" >&2; exit 2; }

if [ "$clear" = 0 ] && [ "$base" = "$id" ]; then
    how="$(KO_ID="$id" KO_VALUE="$value" kickoff_awk computed.awk "$root")"
    [ -z "$how" ] || { echo "answer.sh: $id: $how is how to get the answer, not the answer — work it out and record the value" >&2; exit 2; }
fi

file="$(answers_file "$root")"
tmp="$(mktemp)"
if [ -f "$file" ]; then cp "$file" "$tmp.in"; else
    printf '# kickoff answers: the source of docs/project/charter.md. Edit with kickoff/scripts/answer.sh.\n' > "$tmp.in"
fi
# ENVIRON, not -v: -v would interpret backslashes in the value.
KO_ID="$id" KO_VALUE="$value" KO_ADD="$add" KO_CLEAR="$clear" awk '
    BEGIN { id = ENVIRON["KO_ID"]; v = ENVIRON["KO_VALUE"]; add = ENVIRON["KO_ADD"]; clr = ENVIRON["KO_CLEAR"]; p = id ": " }
    substr($0, 1, length(p)) == p {
        if (add == 1) { print; next }                 # keep every value; the new one goes last
        if (clr != 1 && !done) { print p v; done = 1 } # replace in place, drop the others
        next
    }
    { print }
    END { if (clr != 1 && !done && add != 1) print p v; if (add == 1) print p v }
' "$tmp.in" > "$tmp"
rm -f "$tmp.in"
write_if_changed "$file" "$tmp" 1 >/dev/null
