# status part: the slot queue. Sourced by status.sh (lib loaded, ROOT/STATE/ME set).
load_area slot
[ -s "$STATE/slots" ] && slots_list "$ME"
