#!/usr/bin/env bash
# PLUG-068: Docker in a worktree. compose-report.awk reads `docker compose config --no-interpolate`
# and names what stops a project running twice side by side; compose_report is read-only and silent
# without docker or a compose file. The fixtures in compose/ are that command's normalized output.
. "$(dirname "$0")/helpers.sh"
F="$(dirname "$0")/compose"
report() { awk -v proj="$1" -v root="$2" -f "$S/compose-report.awk" "$3"; }

echo "-- the report, on fixture configs"
check "a clean config prints nothing" "" "$(report shop /w/shop "$F/clean.yml")"
check "every trap is named, once, in order" "$(cat "$F/traps.out")" "$(report shop /w/shop "$F/traps.yml")"
out="$(report acme /w/shop "$F/traps.yml")"
check "a name compose derived from the folder is not a trap" no "$(contains "name: acme" "$out")"
check "…the other traps still are" yes "$(contains "container_name acme-db" "$out")"
check "a port with no host side is not a trap" no "$(contains "9229" "$out")"
check "a mount inside the project is not a trap" no "$(contains "/w/shop/src" "$out")"
check "a named volume compose prefixes is not a trap" no "$(contains "pgdata" "$out")"

echo "-- compose_report"
R="$TMP/Shop.App"; new_repo "$R"
STUB="$TMP/stub"; mkdir -p "$STUB" "$TMP/empty"
printf '#!/bin/sh\n[ "$1 $2 $3" = "compose config --no-interpolate" ] || exit 9\ncat "%s"\n' "$TMP/cfg" > "$STUB/docker"
cp "$F/traps.yml" "$TMP/cfg"
chmod +x "$STUB/docker"
cr() { ( . "$S/lib.sh"; PATH="$1"; compose_report "$2" ); }
out="$(cr "$STUB:$PATH" "$R")"; rc=$?
check "no compose file: silent" "" "$out"
check "…exit 0" 0 "$rc"
printf 'services: {}\n' > "$R/compose.yaml"
out="$(cr "$TMP/empty" "$R")"; rc=$?
check "no docker: silent" "" "$out"
check "…exit 0" 0 "$rc"
out="$(cr "$STUB:$PATH" "$R")"
check "with docker: the report" yes "$(contains "container_name acme-db" "$out")"
printf 'name: shopapp\nservices: {}\n' > "$TMP/cfg"
check "the folder name, lowercased and cleaned, is the name compose derives" "" "$(cr "$STUB:$PATH" "$R")"
cp "$F/traps.yml" "$TMP/cfg"
printf '#!/bin/sh\nexit 1\n' > "$STUB/docker"
out="$(cr "$STUB:$PATH" "$R")"; rc=$?
check "docker compose config failing: silent" "" "$out"
check "…exit 0" 0 "$rc"

echo "-- copy new reports it"
printf '#!/bin/sh\ncat "%s"\n' "$TMP/cfg" > "$STUB/docker"
git -C "$R" add compose.yaml && git -C "$R" commit -q -m compose
join "$R" r1 coordinator
out="$(PATH="$STUB:$PATH" crew_as r1 "$R" copy new one 2>&1)"
check "copy new prints the report" yes "$(contains "cannot run twice side by side" "$out")"

finish
