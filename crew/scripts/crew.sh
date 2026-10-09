#!/usr/bin/env bash
# crew — the one entry point: `crew.sh <command> [args]`. Each command lives in its own script;
# `help` lists them from their `# help:` lines, so a new command needs no edit here.
set -euo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cmd="${1:-help}"; [ $# -gt 0 ] && shift
case "$cmd" in
    hold|release|chain|who|drop) exec bash "$D/holds.sh" "$cmd" "$@" ;;
    apply) exec bash "$D/copy.sh" apply "$@" ;;
    help|-h|--help)
        echo "usage: crew <command> [args]   (identity from the session; else prefix CREW_AS=<name>; without PATH: bash $D/crew.sh)"
        for f in "$D"/*.sh; do sed -n 's/^# help: /  /p' "$f"; done
        exit 0 ;;
    lib|crew) ;;
    *) [ -f "$D/$cmd.sh" ] && exec bash "$D/$cmd.sh" "$@" ;;
esac
echo "crew: unknown command '$cmd' — crew.sh help" >&2; exit 1
