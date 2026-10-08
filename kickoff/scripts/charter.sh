#!/usr/bin/env bash
# charter.sh [project-root] [--force] [--stdout] — write docs/project/charter.md from the answers.
#
# Prints created | unchanged | updated | refused. An existing charter that differs is refused
# (exit 3), because it may have been edited by hand since kickoff; --force overwrites it.
# --stdout prints the charter instead of writing it.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

root="" force=0 out=file
for a in "$@"; do
    case "$a" in
        --force) force=1 ;;
        --stdout) out=stdout ;;
        -*) echo "charter.sh: unknown option $a" >&2; exit 2 ;;
        *) root="$a" ;;
    esac
done
root="$(project_root "$root")"
[ -f "$(answers_file "$root")" ] || { echo "charter.sh: no answers yet ($(answers_file "$root"))" >&2; exit 1; }

if [ "$out" = stdout ]; then kickoff_awk charter.awk "$root"; exit; fi
tmp="$(mktemp)"
kickoff_awk charter.awk "$root" > "$tmp"
write_if_changed "$root/docs/project/charter.md" "$tmp" "$force"
