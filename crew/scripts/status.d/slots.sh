# status part: the slot queue. Sourced by status.sh (lib loaded, ROOT/STATE/ME set).
# A part must end true: status.sh sources it at the end of an && list under set -e.
load_area slot
if [ -s "$STATE/slots" ]; then slots_list "$ME"; fi
