# status part: holds. Sourced by status.sh (lib loaded, ROOT/STATE/ME set).
load_area holds
if [ -s "$STATE/holds" ]; then echo "holds:"; holds_list; fi
