#!/usr/bin/env bash
# start.sh — the HUMAN starts the runner for the next run window. Claude never runs it; it only
# relays the reminder that `delay.sh add` prints.
#
#   sudo start.sh [--awake|--no-awake]   schedule a pmset wake for the window start, load the runner
#   start.sh [--awake|--no-awake]        load the runner only — no wake: the Mac must be awake then
#
#   --awake     also keep the Mac awake from now until the jobs are done (the runner holds a
#               caffeinate -i -s, capped at the window end). Closing the lid still sleeps a laptop.
#   --no-awake  let it sleep tonight. Without either flag: the default chosen at install
#               (`install.sh --awake`), else sleep.
#
# Nothing is loaded until this runs, and the runner (dispatch.sh) unloads itself once the queue
# is empty or the window has ended — so there is no always-on daemon. Being the human's command
# it is also a per-night approval: queued jobs do not run until someone starts the runner.
#
# As root it reads the user's queue only to count approved jobs (pairs checked against the
# root-owned registry); nothing from the queue is executed or trusted for timing. The wake is
# tagged with our owner and is the only one it cancels later — never `pmset schedule cancelall`.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/lib.sh"

# Wake just AFTER the window opens: launchd runs the runner's overdue tick right at wake, and that
# tick must already be inside the window — a wake before it would find the window shut, and the
# next tick may come only after the Mac has gone back to sleep.
WAKE_AFTER=30

AWAKE="$(setting awake)"; [ "$AWAKE" = 1 ] || AWAKE=0
case "${1:-}" in --awake) AWAKE=1 ;; --no-awake) AWAKE=0 ;; '') ;; *) die "usage: start.sh [--awake|--no-awake]" ;; esac

STORE="$(user_store)"
if is_root; then U="$(sudo_user)"; ROOT=1; else U="$(id -un)"; ROOT=0; fi
UID_="$(id -u "$U")"

runner_installed || die "not installed — first: sudo bash <plugin>/scripts/install.sh"
window_conf >/dev/null || die "no run window set — first: sudo \"$DELAY_SYSTEM/bin/approve.sh\" --window HH:MM HOURS"

N="$(approved_queued "$STORE")"
if [ "$N" = 0 ]; then echo "nothing approved is queued — nothing to start"; exit 0; fi

T="$(now)"
WS="$(window_target "$T")"; WE=$((WS + $(window_hours) * 3600))

# --- the wake: one, ours, at the window start -----------------------------------------------
wake_note="window already open — no wake needed"
if [ "$WS" -gt "$T" ]; then
    W="$(fmt_epoch $((WS + WAKE_AFTER)) "%m/%d/%y %H:%M:%S")"
    if [ "$ROOT" = 1 ]; then
        mkdir -p "$DELAY_STATE"; touch "$DELAY_STATE/wakes"
        while IFS= read -r old; do
            [ -n "$old" ] && [ "$old" != "$W" ] && { pmset schedule cancel wake "$old" "$DELAY_OWNER" >/dev/null 2>&1 || true; }
        done < "$DELAY_STATE/wakes"
        if grep -qxF "$W" "$DELAY_STATE/wakes" || pmset schedule wake "$W" "$DELAY_OWNER" >/dev/null 2>&1; then
            echo "$W" | write_if_changed "$DELAY_STATE/wakes"
            wake_note="wake scheduled for $W"
        else
            : | write_if_changed "$DELAY_STATE/wakes"
            wake_note="WARNING: pmset refused the wake — the Mac must be awake in the window"
        fi
    else
        wake_note="no wake scheduled (run with sudo for that) — the Mac must be awake in the window"
    fi
fi

# --- arm: record the window, load the runner ------------------------------------------------
mkdir -p "$STORE"
{ printf 'start=%s\nend=%s\n' "$WS" "$WE"; [ "$AWAKE" = 0 ] || echo "awake=1"; } | write_if_changed "$STORE/armed"
[ "$ROOT" = 1 ] && [ -z "$DELAY_PREFIX" ] && chown "$U" "$STORE/armed"
if ! runner_loaded "$UID_"; then
    launchctl bootstrap "gui/$UID_" "$DELAY_PLIST" ||
        die "could not load the runner — is $U logged in? (docker needs the login session too)"
fi

echo "started: $N approved job(s) queued; window $(fmt_epoch "$WS" "%Y-%m-%d %H:%M") – $(fmt_epoch "$WE" "%H:%M")"
echo "  $wake_note"
[ "$AWAKE" = 0 ] || echo "  keeping the Mac awake until the jobs are done (capped at $(fmt_epoch "$WE" "%H:%M")) — keep the lid open"
echo "  the runner unloads itself when the queue is done or the window ends"
