# status part: unread crew mail per session. Sourced by status.sh (lib loaded, ROOT/STATE/ME set).
load_area inbox
if declare -F mail_status >/dev/null; then mail_status; fi
