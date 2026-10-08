#!/usr/bin/env bash
# Effective config, one key per line with the layer it came from.
# help: config — effective settings and where each comes from (project > user > default)
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
crew_init
for k in $CREW_KEYS; do
    v="$(cfg "$k" | paste -sd, -)"; src="$(cfg_src "$k")"
    [ "$k" = sharedBranch ] && [ "$src" = default ] && v="$(shared_branch)" && src="default: the checked-out branch"
    printf '%s=%s (%s)\n' "$k" "$v" "$src"
    if cfg_project_only "$k" && [ -n "$(cfg_layer user "$k")" ]; then
        echo "  note: $k in $CREW_USER_CONFIG is ignored — it only makes sense per project (.crew.json)"
    fi
done
