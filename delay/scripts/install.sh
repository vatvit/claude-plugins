#!/usr/bin/env bash
# install.sh — the HUMAN runs this once with sudo (and again after a plugin update).
# Claude never runs it.
#
#   sudo bash install.sh [--run-at HH:MM] [--hours N] [--interval MIN]
#        install or upgrade.
#        --run-at   when queued jobs start each night (default 03:00)
#        --hours    how long the window stays open for starts (default 4)
#        --interval how often the runner checks the queue while loaded, minutes (default 1)
#        --awake / --no-awake  default for every start.sh: keep the Mac awake until the jobs are
#                   done, or let it sleep and rely on the wake (default: sleep). Kept on re-install.
#        A first install sets the window from --run-at/--hours or the defaults. A re-install
#        keeps the existing window unless --run-at or --hours is given.
#   sudo bash install.sh --uninstall  unload the runner, cancel our wake, remove the installed
#                                     scripts and plist (keeps approvals, window and results)
#
# It LOADS NOTHING. It puts root-owned copies of the scripts and the runner's plist under
# /Library/Application Support/claude-delay; `start.sh` loads the runner when there is work and
# the runner unloads itself when done. The plist is deliberately not in /Library/LaunchAgents,
# where launchd would load it at every login.
#
# The copies are what launchd and sudo run — never the user-writable plugin directory, so neither
# a session nor an accidental edit changes what runs unattended. An `installed.conf` beside them
# pins their paths and makes them ignore DELAY_* environment overrides.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd -P)"
. "$SRC/lib.sh"
[ "$DELAY_INSTALLED" = 0 ] || die "run the plugin's install.sh, not an installed copy"
[ -n "$DELAY_PREFIX" ] || is_root || die "run with sudo"

U="$(sudo_user)"

INTERVAL=1 RUN_AT="" HOURS="" UNINSTALL=0 AWAKE_DEFAULT=""
while [ $# -gt 0 ]; do
    case "$1" in
        --interval) INTERVAL="${2:-}"; shift 2 || die "--interval needs minutes" ;;
        --run-at)   RUN_AT="${2:-}"; shift 2 || die "--run-at needs HH:MM" ;;
        --hours)    HOURS="${2:-}"; shift 2 || die "--hours needs a number" ;;
        --uninstall) UNINSTALL=1; shift ;;
        --awake) AWAKE_DEFAULT=1; shift ;;
        --no-awake) AWAKE_DEFAULT=0; shift ;;
        *) die "unknown option $1 (see the header of install.sh)" ;;
    esac
done
case "$INTERVAL" in [1-9]|[1-5][0-9]|60) ;; *) die "--interval must be 1-60 minutes" ;; esac
[ -z "$RUN_AT" ] || valid_hhmm "$RUN_AT" || die "--run-at must be HH:MM (00:00-23:59)"
[ -z "$HOURS" ] || valid_hours "$HOURS" || die "--hours must be 1-24"
UID_="$(id -u "$U")"
BIN="$DELAY_SYSTEM/bin"
SCRIPTS="lib.sh dispatch.sh start.sh approve.sh"

xml() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

if [ "$UNINSTALL" = 1 ]; then
    launchctl bootout "gui/$UID_/$DELAY_LABEL" >/dev/null 2>&1 || true
    if [ -f "$DELAY_STATE/wakes" ]; then
        while IFS= read -r w; do
            [ -n "$w" ] && { pmset schedule cancel wake "$w" "$DELAY_OWNER" >/dev/null 2>&1 || true; }
        done < "$DELAY_STATE/wakes"
        rm -f "$DELAY_STATE/wakes"
    fi
    rm -f "$DELAY_PLIST"
    rm -rf "$BIN"
    echo "uninstalled. kept: $DELAY_REGISTRY, $DELAY_SYSTEM/window and ~$U/.claude/delay"
    exit 0
fi

HOME_U="$(user_home "$U")"
mkdir -p "$BIN" "$DELAY_REGISTRY" "$DELAY_STATE"
for s in $SCRIPTS; do write_if_changed "$BIN/$s" < "$SRC/$s"; done

# the run window: defaults (03:00, 4h) on a first install; a re-install keeps it unless asked
if [ -n "$RUN_AT$HOURS" ] || ! window_conf >/dev/null; then
    cur="$(window_conf || true)"
    [ -n "$RUN_AT" ] || RUN_AT="${cur% *}"; [ -n "$RUN_AT" ] || RUN_AT=03:00
    [ -n "$HOURS" ] || HOURS="${cur#* }"; [ -n "$HOURS" ] || HOURS=4
    set_window "$RUN_AT" "$HOURS"
fi
[ -z "$AWAKE_DEFAULT" ] || set_setting awake "$AWAKE_DEFAULT"
{
    printf 'DELAY_INSTALL_PREFIX=%q\n' "$DELAY_PREFIX"
    printf 'DELAY_SYSTEM=%q\n' "$DELAY_SYSTEM"
} | write_if_changed "$BIN/installed.conf"

write_if_changed "$DELAY_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$DELAY_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$(xml "$BIN/dispatch.sh")</string>
  </array>
  <key>StartInterval</key><integer>$((INTERVAL * 60))</integer>
  <key>RunAtLoad</key><true/>
  <key>AbandonProcessGroup</key><true/>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>$(xml "$HOME_U/.orbstack/bin"):/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>StandardErrorPath</key><string>/tmp/claude-delay-runner.$(xml "$U").err</string>
</dict>
</plist>
EOF

if [ -z "$DELAY_PREFIX" ]; then
    chown -R root:wheel "$DELAY_SYSTEM"
    chmod 755 "$DELAY_SYSTEM" "$BIN" "$DELAY_REGISTRY" "$DELAY_STATE"
    chmod 644 "$DELAY_PLIST" "$BIN/installed.conf"
    chmod 755 "$BIN"/*.sh
fi
if command -v plutil >/dev/null 2>&1; then plutil -lint "$DELAY_PLIST" >/dev/null || die "generated plist is invalid"; fi

echo "installed for $U (nothing is loaded until start.sh runs; it checks every ${INTERVAL} min while loaded):"
echo "  scripts:  $BIN"
W="$(window_conf)"
echo "  run window: ${W% *} for ${W#* }h — change it: sudo \"$BIN/approve.sh\" --window HH:MM HOURS"
if [ "$(setting awake)" = 1 ]; then echo "  start.sh keeps the Mac awake until the jobs are done (installed with --awake; keep the lid open)"
else echo "  start.sh lets the Mac sleep and relies on the wake (re-install with --awake to change)"; fi
echo "  1. approve each waiting job once, by its ID (list below): sudo \"$BIN/approve.sh\" <ID>"
echo "  2. after Claude queues jobs, start the runner: sudo \"$BIN/start.sh\""

echo
print_jobs
