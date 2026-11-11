#!/usr/bin/env bash
# PLUG-111 probe: what a plugin script can rely on in the environment it runs in.
# Read-only except for one throwaway file per candidate dir, removed straight away.
# Takes no arguments. Prints the VALUES of a fixed allow-list of variables and only the
# NAMES of every other variable, so that no token or secret ends up in the output.
# Run it in Cowork, and once on the host CLI for comparison:
#   bash .tasks/PLUG-111/cowork-probe.sh > probe-<where>.txt
set -u
[ $# -eq 0 ] || { echo "cowork-probe.sh takes no arguments" >&2; exit 2; }

section() { printf '\n--- %s ---\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1 && echo yes || echo no; }

section "system"
echo "uname=$(uname -a 2>/dev/null)"
[ -r /etc/os-release ] && grep -E '^(ID|VERSION_ID|PRETTY_NAME)=' /etc/os-release
echo "bash=${BASH_VERSION:-?}"
echo "id=$(id 2>/dev/null)"
echo "hostname=$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null)"
echo "pwd=$(pwd)"
echo "in_container=$( [ -f /.dockerenv ] && echo dockerenv; grep -qaE 'docker|containerd|kubepods' /proc/1/cgroup 2>/dev/null && echo cgroup; [ -n "${container:-}" ] && echo "container=$container"; true)"

section "env: values (allow-list)"
for v in HOME USER SHELL TMPDIR PATH LANG \
    CLAUDE_CONFIG_DIR CLAUDE_PLUGIN_ROOT CLAUDE_PLUGIN_DATA CLAUDE_PROJECT_DIR \
    CLAUDE_CODE_TMPDIR CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_REMOTE CLAUDECODE \
    CLAUDE_CODE_SANDBOXED CLAUDE_CODE_IS_COWORK CLAUDE_ENV_FILE; do
    if [ -n "${!v+x}" ]; then printf '%s=%s\n' "$v" "${!v}"; else printf '%s=<unset>\n' "$v"; fi
done

section "env: names only (anything with CLAUDE, ANTHROPIC, COWORK, SANDBOX, DESKTOP, AGENT)"
env | cut -d= -f1 | grep -iE 'claude|anthropic|cowork|sandbox|desktop|agent' | sort

section "tools"
for c in git awk gawk mawk busybox sed grep find stat date mktemp flock lsof docker \
    launchctl pmset caffeinate jq python3 curl; do printf '%-11s %s\n' "$c" "$(have "$c")"; done
echo "awk_version=$(awk --version 2>&1 | head -1)"
echo "date_flavour=$(date -d @0 +%Y >/dev/null 2>&1 && echo gnu-or-busybox || echo bsd)"
echo "stat_c=$(stat -c %Y / >/dev/null 2>&1 && echo yes || echo no)"

section "paths: exists / writable / persists?"
for d in "$HOME" "$HOME/.claude" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" "${CLAUDE_PLUGIN_DATA:-/nonexistent}" \
    "${CLAUDE_PLUGIN_ROOT:-/nonexistent}" "${TMPDIR:-/tmp}" /tmp "$(pwd)"; do
    e=no; w=no
    [ -d "$d" ] && e=yes
    if [ "$e" = yes ]; then
        p="$d/.plug111-probe.$$"
        ( : > "$p" ) 2>/dev/null && w=yes; rm -f "$p" 2>/dev/null
    fi
    printf '%-60s exists=%s writable=%s\n' "$d" "$e" "$w"
done
# Persistence: a marker left in HOME on purpose. A second run prints when it was written.
m="$HOME/.plug111-persist-marker"
if [ -f "$m" ]; then echo "persist_marker=found, written $(cat "$m")"; else
    date '+%Y-%m-%d %H:%M:%S' > "$m" 2>/dev/null && echo "persist_marker=written now (run again in a new task to see whether HOME persists)" || echo "persist_marker=HOME not writable"; fi

section "~/.claude contents (names only, depth 1)"
ls -1A "$HOME/.claude" 2>/dev/null | head -40 || echo "<none>"
[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json" ] && echo "installed_plugins.json=present" || echo "installed_plugins.json=absent"

section "mounts (non-system)"
grep -vE ' (proc|sysfs|devpts|tmpfs|cgroup2?|mqueue|securityfs|debugfs|tracefs|bpf|pstore|configfs|fusectl|devtmpfs|overlay|hugetlbfs|autofs|binfmt_misc) ' /proc/mounts 2>/dev/null | head -30 || mount 2>/dev/null | head -30

section "hook-input samples (written by the probe hook, if installed)"
ls -1 "${TMPDIR:-/tmp}"/plug111-hook-* /tmp/plug111-hook-* 2>/dev/null | sort -u | head -20 || true
