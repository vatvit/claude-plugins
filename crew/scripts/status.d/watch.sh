# status part: each session's last activity. Sourced by status.sh (lib loaded, ROOT/STATE/ME set).
load_area watch
if declare -F watch_status >/dev/null; then watch_status; fi
