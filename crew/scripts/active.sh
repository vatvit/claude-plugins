#!/usr/bin/env bash
# Is a crew running in this repo? For hooks, scripts and a project's own checks (PLUG-076):
# exit 0 with one line (the crew, and the caller when it is in it), exit 1 and silent otherwise —
# outside git too, so `if crew active; then …` reads cleanly anywhere.
# help: active — exit 0 and one line while a crew runs here (you: name, role); exit 1, silent, when not
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
crew_try_init && crew_active || exit 1
n="$(caller_name)"
[ -n "$n" ] && [ -f "$STATE/sessions/$n" ] || n=""
echo "crew $(crew_id): $(crew_line)${n:+ · you: $n ($(sess_get "$n" role))}"
