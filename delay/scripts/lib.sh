#!/usr/bin/env bash
# Shared helpers for the delay plugin. Sourced, never executed.
#
# Paths come from one place: when an `installed.conf` sits next to this file (the root-owned
# copy that the launchd jobs run), it is authoritative and DELAY_* environment overrides are
# IGNORED — otherwise `launchctl setenv DELAY_REGISTRY=...` could point the dispatcher at a
# user-writable registry. Running from the plugin source tree, the overrides are honoured;
# they are the test seams.

DELAY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DELAY_OWNER="claude-delay"
DELAY_KEEP_RESULTS=20

if [ -f "$DELAY_LIB_DIR/installed.conf" ]; then
    unset DELAY_HOME DELAY_SYSTEM DELAY_REGISTRY DELAY_STATE DELAY_NOW DELAY_DOCKER_WAIT DELAY_INSTALL_PREFIX \
          DELAY_AS_ROOT DELAY_USER_HOME
    # shellcheck disable=SC1091
    . "$DELAY_LIB_DIR/installed.conf"
    DELAY_INSTALLED=1
else
    DELAY_INSTALLED=0
fi
DELAY_PREFIX="${DELAY_INSTALL_PREFIX:-}"
DELAY_HOME="${DELAY_HOME:-$HOME/.claude/delay}"
DELAY_SYSTEM="${DELAY_SYSTEM:-$DELAY_PREFIX/Library/Application Support/claude-delay}"
DELAY_REGISTRY="${DELAY_REGISTRY:-$DELAY_SYSTEM/registry}"
DELAY_STATE="${DELAY_STATE:-$DELAY_SYSTEM/state}"
DELAY_DOCKER_WAIT="${DELAY_DOCKER_WAIT:-60}"

die() { echo "delay: $*" >&2; exit 1; }

now() { echo "${DELAY_NOW:-$(date +%s)}"; }

# --- dates: BSD first, GNU/busybox fallback -------------------------------------------
# fmt_epoch <epoch> <strftime>
fmt_epoch() {
    date -r "$1" "+$2" 2>/dev/null || date -d "@$1" "+$2"
}

# parse_local "YYYY-MM-DD HH:MM:SS" -> epoch. Seconds must be explicit: BSD `date -j -f`
# fills any field missing from the format with the CURRENT value, not zero.
parse_local() {
    date -j -f "%Y-%m-%d %H:%M:%S" "$1" +%s 2>/dev/null || date -d "$1" +%s 2>/dev/null
}

# --- the run window: the ONLY "when" -------------------------------------------------------
# The human sets it (`sudo approve.sh --window HH:MM HOURS`); Claude never chooses a time.
# $DELAY_SYSTEM/window is root-owned: start=HH:MM, hours=N. Jobs START only inside it; a job
# whose window passed while the Mac could not wake waits for the next one.
valid_hhmm() { case "$1" in [01][0-9]:[0-5][0-9]|2[0-3]:[0-5][0-9]) return 0 ;; esac; return 1; }
valid_hours() { case "$1" in [1-9]|1[0-9]|2[0-4]) return 0 ;; esac; return 1; }

window_conf() { # -> "HH:MM HOURS", exit 1 when unset or invalid
    local s h
    s="$(kv start "$DELAY_SYSTEM/window")"; h="$(kv hours "$DELAY_SYSTEM/window")"
    valid_hhmm "$s" && valid_hours "$h" || return 1
    echo "$s $h"
}

set_window() { # <HH:MM> <hours> — validated; the only writer of the window file (install, approve)
    valid_hhmm "$1" || die "run time must be HH:MM (00:00-23:59), got '$1'"
    valid_hours "$2" || die "window length must be 1-24 hours, got '$2'"
    mkdir -p "$DELAY_SYSTEM" 2>/dev/null && [ -w "$DELAY_SYSTEM" ] || die "$DELAY_SYSTEM is not writable — run with sudo"
    printf 'start=%s\nhours=%s\n' "$1" "$2" | write_if_changed "$DELAY_SYSTEM/window"
    chmod 644 "$DELAY_SYSTEM/window"
}

window_start_on() { # <epoch> <HH:MM> -> epoch of HH:MM on that epoch's local day
    parse_local "$(fmt_epoch "$1" %Y-%m-%d) $2:00"
}

window_hours() { local c; c="$(window_conf)" || return 1; echo "${c#* }"; }

# window_target <epoch> -> start of the window a job queued now runs in: the open one (today's or
# yesterday's — a window may cross midnight), else the next one
window_target() {
    local t="$1" c h st s
    c="$(window_conf)" || return 1; h="${c#* }"
    st="$(window_start_on "$t" "${c% *}")" || return 1
    for s in "$st" "$((st - 86400))"; do
        [ "$t" -ge "$s" ] && [ "$t" -lt $((s + h * 3600)) ] && { echo "$s"; return 0; }
    done
    next_window "$t"
}

in_window() { # <epoch> -> exit 0 while a window is open
    local s
    s="$(window_target "$1")" || return 1
    [ "$s" -le "$1" ]
}

next_window() { # <epoch> -> the next window start strictly after it
    local t="$1" c st
    c="$(window_conf)" || return 1
    st="$(window_start_on "$t" "${c% *}")" || return 1
    [ "$st" -gt "$t" ] || st=$((st + 86400))
    echo "$st"
}

# --- identity ---------------------------------------------------------------------------
project_root() { # [dir] -> absolute physical project root
    local d="${1:-$PWD}" top
    d="$(cd "$d" 2>/dev/null && pwd -P)" || return 1
    top="$(cd "$d" && git rev-parse --show-toplevel 2>/dev/null)" || top=""
    if [ -n "$top" ]; then (cd "$top" && pwd -P); else echo "$d"; fi
}

encode_path() { printf '%s' "$1" | tr -c 'A-Za-z0-9\n' '-'; }

valid_name() { # job names and ids: no path tricks, ever
    case "$1" in ''|.|..|*[!A-Za-z0-9._-]*) return 1 ;; esac
    return 0
}

# --- key=value files ----------------------------------------------------------------------
# kv <key> <file> -> first value; empty (and status 0) when absent — absence is normal.
kv() {
    [ -f "$2" ] || return 0
    awk -v k="$1" 'index($0, k "=") == 1 { print substr($0, length(k) + 2); exit }' "$2" || true
}

sha256() { # [file] — of the file, or of stdin; Alpine has only sha256sum, macOS has shasum too
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi | awk '{print $1}'
}
sha256_file() { sha256 "$1"; }

# job_id <project> <job> -> the short id the human approves by. Stable: approval is per
# (project, job), so every queued run of a job and its registry entry share one id.
job_id() { printf '%s\n%s' "$1" "$2" | sha256 | cut -c1-6; }

# inside_project <root> <relpath> -> absolute physical path, exit 1 when it escapes the root
inside_project() {
    local root="$1" rel="$2" dir base abs
    case "$rel" in /*) return 1 ;; esac
    dir="$(dirname "$root/$rel")"; base="$(basename "$rel")"
    dir="$(cd "$dir" 2>/dev/null && pwd -P)" || return 1
    abs="$dir/$base"
    [ -f "$abs" ] && [ ! -L "$abs" ] || return 1
    case "$abs" in "$root"/*) echo "$abs" ;; *) return 1 ;; esac
}

# write_if_changed <file> — stdin becomes the file; untouched when identical (diff-guard)
write_if_changed() {
    local f="$1" tmp
    tmp="$(mktemp "${f}.XXXXXX")" || return 1
    cat > "$tmp"
    if [ -f "$f" ] && cmp -s "$tmp" "$f"; then rm -f "$tmp"; else mv "$tmp" "$f"; fi
}

# --- registry -----------------------------------------------------------------------------
# registry_job <project_root> <job> -> path of the approved job file, exit 1 when not approved
registry_job() {
    local enc dir
    valid_name "$2" || return 1
    enc="$(encode_path "$1")"; dir="$DELAY_REGISTRY/$enc"
    [ "$(cat "$dir/project.path" 2>/dev/null)" = "$1" ] || return 1
    [ -f "$dir/jobs/$2" ] || return 1
    echo "$dir/jobs/$2"
}

# verify_pins <project_root> <job_file> -> exit 0 when every pin matches; prints mismatches
verify_pins() {
    local root="$1" jf="$2" rel sum abs bad=0
    while read -r rel sum; do
        [ -n "$rel" ] || continue
        abs="$(inside_project "$root" "$rel")" || { echo "missing: $rel"; bad=1; continue; }
        [ "$(sha256_file "$abs")" = "$sum" ] || { echo "changed: $rel"; bad=1; }
    done <<EOF
$(awk 'index($0, "pin=") == 1 { print substr($0, 5) }' "$jf")
EOF
    return $bad
}

# project_store <project_root> -> ~/.claude/delay/<enc>, created; dies on encoding collision
project_store() {
    local d existing
    d="$DELAY_HOME/$(encode_path "$1")"
    mkdir -p "$d/queue" "$d/results" || return 1
    existing="$(cat "$d/project.path" 2>/dev/null)"
    if [ -z "$existing" ]; then printf '%s\n' "$1" > "$d/project.path"
    elif [ "$existing" != "$1" ]; then die "store $d belongs to $existing, not $1 (path encoding collision)"; fi
    echo "$d"
}

# approved_queued <store> -> how many queue entries name a job approved for their project.
# Safe to run as root over a user-writable store: it only reads names and checks the registry.
approved_queued() {
    local q job root n=0
    for q in "$1"/*/queue/*.job; do
        [ -f "$q" ] || continue
        job="$(kv job "$q")"
        valid_name "$job" || continue
        root="$(cat "$(dirname "$(dirname "$q")")/project.path" 2>/dev/null)" || continue
        registry_job "$root" "$job" >/dev/null && n=$((n + 1))
    done
    echo "$n"
}

# --- the runner: loaded on demand by start.sh, unloads itself when done -------------------
# Its plist lives root-owned under $DELAY_SYSTEM, deliberately NOT in /Library/LaunchAgents —
# anything there is loaded at every login, which is the always-on runner we do not want.
DELAY_LABEL="com.claude-delay.dispatch"
DELAY_PLIST="$DELAY_SYSTEM/$DELAY_LABEL.plist"

runner_installed() { [ -f "$DELAY_PLIST" ] && [ -f "$DELAY_SYSTEM/bin/dispatch.sh" ]; }

runner_loaded() { # [uid]
    launchctl print "gui/${1:-$(id -u)}/$DELAY_LABEL" >/dev/null 2>&1
}

# runner_armed -> exit 0 when the runner is loaded for the window a job queued now would use
runner_armed() {
    local w
    w="$(window_target "$(now)")" || return 1
    [ "$(kv start "$DELAY_HOME/armed")" = "$w" ] && runner_loaded
}

# --- sudo context (install.sh, start.sh) --------------------------------------------------
is_root() { # DELAY_AS_ROOT is a test seam (ignored by installed copies)
    case "${DELAY_AS_ROOT:-}" in 1) return 0 ;; 0) return 1 ;; esac
    [ "$(id -u)" = 0 ]
}

sudo_user() { # -> the account that ran sudo; dies when there is none
    [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ] || die "run via sudo from your own account (SUDO_USER is unset)"
    echo "$SUDO_USER"
}

user_home() { # <user> -> home dir
    local h="${DELAY_USER_HOME:-}"
    [ -n "$h" ] || h="$(dscl . -read "/Users/$1" NFSHomeDirectory 2>/dev/null | awk '{print $2}')" || true
    [ -n "$h" ] && [ -d "$h" ] || die "cannot find the home directory of $1"
    echo "$h"
}

user_store() { # the queue store to read: the sudo user's when running as root, else our own
    if is_root; then echo "$(user_home "$(sudo_user)")/.claude/delay"; else echo "$DELAY_HOME"; fi
}

# all_jobs <store> -> TSV records: id, kind, project, job, file — one per (project, job).
#   approved: in the registry (file = the registry job file)
#   pending:  queued but not approved (file = a queue entry, which may carry a proposal)
all_jobs() {
    local d p f q job
    {
        for d in "$DELAY_REGISTRY"/*; do
            [ -f "$d/project.path" ] || continue; p="$(cat "$d/project.path")"
            for f in "$d"/jobs/*; do
                [ -f "$f" ] || continue; job="$(basename "$f")"; valid_name "$job" || continue
                printf '%s\tapproved\t%s\t%s\t%s\n' "$(job_id "$p" "$job")" "$p" "$job" "$f"
            done
        done
        for d in "$1"/*; do
            [ -f "$d/project.path" ] || continue; p="$(cat "$d/project.path")"
            for q in "$d"/queue/*.job; do
                [ -f "$q" ] || continue; job="$(kv job "$q")"; valid_name "$job" || continue
                registry_job "$p" "$job" >/dev/null && continue
                printf '%s\tpending\t%s\t%s\t%s\n' "$(job_id "$p" "$job")" "$p" "$job" "$q"
            done
        done
    } | awk -F'\t' '!seen[$1]++'
}

# print_jobs — every project with its approved and waiting jobs and their IDs (approve.sh, install.sh)
print_jobs() {
    local tmp p
    tmp="$(mktemp)"
    all_jobs "$(user_store)" > "$tmp"
    if [ ! -s "$tmp" ]; then
        echo "No jobs yet: nothing approved, nothing waiting."; rm -f "$tmp"; return 0
    fi
    echo "Approve or re-approve:  sudo \"$DELAY_SYSTEM/bin/approve.sh\" <ID>      Revoke:  ... --revoke <ID>"
    cut -f3 "$tmp" | sort -u | while IFS= read -r p; do
        echo
        echo "$p"
        awk -F'\t' -v p="$p" '$3 == p' "$tmp" | sort -t "$(printf '\t')" -k2,2 -k4,4 |
        while IFS=$'\t' read -r id kind _ job f; do
            if [ "$kind" = approved ]; then
                st="approved"
                if [ ! -d "$p" ]; then st="project missing"
                elif ! verify_pins "$p" "$f" >/dev/null 2>&1; then st="CHANGED, re-approve"; fi
                printf '  %s  %-16s %-22s %s / %s / %s\n' "$id" "$job" "$st" \
                    "$(kv compose "$f")" "$(kv service "$f")" "$(kv command "$f")"
            elif [ -n "$(kv proposed_compose "$f")" ]; then
                printf '  %s  %-16s %-22s %s / %s / %s\n' "$id" "$job" "WAITING for approval" \
                    "$(kv proposed_compose "$f")" "$(kv proposed_service "$f")" \
                    "$(c="$(kv proposed_command "$f")"; [ -n "$c" ] && echo "$c" || kv proposed_wrapper "$f")"
            else
                printf '  %s  %-16s %-22s %s\n' "$id" "$job" "WAITING, no definition" \
                    "ask Claude to re-queue it with --compose/--service/--wrapper, or use the full form"
            fi
        done
    done
    rm -f "$tmp"
}

# --- settings: root-owned key=value defaults the human sets at install ---------------------
setting() { kv "$1" "$DELAY_SYSTEM/settings"; }   # <key> -> value, empty when unset

set_setting() { # <key> <value> — keeps the other keys; diff-guarded
    local f="$DELAY_SYSTEM/settings"
    mkdir -p "$DELAY_SYSTEM" 2>/dev/null && [ -w "$DELAY_SYSTEM" ] || die "$DELAY_SYSTEM is not writable — run with sudo"
    { awk -v k="$1" 'index($0, k "=") != 1' "$f" 2>/dev/null || true; echo "$1=$2"; } | sort | write_if_changed "$f"
    chmod 644 "$f"
}
