#!/usr/bin/env bash
# approve.sh — the HUMAN's command, run with sudo. Writes the root-owned registry that is the
# whitelist: a PAIR — a container (compose file + service) and a .sh script that runs inside it —
# with the files that define the container's confinement and the script pinned by sha256.
# Params are never approved: Claude passes them per job, as argv, to the approved script.
# Claude never runs this.
#
#   sudo approve.sh                  every project: approved pairs and pairs waiting, with an ID
#   sudo approve.sh <ID>             review that pair and approve it (y/N); also re-approves an
#                                    approved pair whose pinned files changed
#   sudo approve.sh --revoke <ID>    take an approval back
#   sudo approve.sh --window HH:MM HOURS   when ALL queued jobs may start (daily, local time)
#   approve.sh --window                    show it
#
#   Full form, without an ID (before Claude queued the pair):
#   sudo approve.sh <project-dir> <script.sh> --compose FILE --service NAME
#                   [--command "CMD"] [--timeout SECONDS] [--pin FILE]...
#   Any form takes [--accept-risks] [--yes].
#
# An ID stands for a (project, pair). A waiting pair is what Claude queued with `delay.sh add`;
# nothing queued is trusted — it is shown to you, re-validated, red-flag checked and pinned only
# when you answer y. Paths are relative to the project root and must stay inside it. `--command`
# (default: the script path) is how the container calls the script; params are appended to it.
# A Dockerfile next to the compose file is pinned automatically.
#
# Red flags refuse unless --accept-risks: a privileged container, extra capabilities, the docker
# socket, host mounts outside the project, host namespaces — and a script that runs a param as a
# command (eval, sh -c "$1", a build runner taking "$1" as its target, "$@" in command position).
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/lib.sh"

usage() { header "$0"; exit 1; }

# Under sudo, git and docker must run as the real user: root's git refuses a repo it does not
# own ("dubious ownership"), and docker (OrbStack) is configured in the user's home.
as_user() {
    if [ "$(id -u)" = 0 ] && [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
        sudo -H -u "$SUDO_USER" "$@"
    else "$@"; fi
}

root_of() {
    local d top
    d="$(cd "$1" 2>/dev/null && pwd -P)" || die "no such project dir: $1"
    top="$(as_user git -C "$d" rev-parse --show-toplevel 2>/dev/null)" || top=""
    if [ -n "$top" ]; then (cd "$top" && pwd -P); else echo "$d"; fi
}

need_writable() {
    mkdir -p "$DELAY_REGISTRY" 2>/dev/null && [ -w "$DELAY_REGISTRY" ] ||
        die "registry $DELAY_REGISTRY is not writable — run with sudo (and install first)"
}

is_id() { case "$1" in [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) [ ! -e "$1" ] ;; *) return 1 ;; esac; }

find_id() { # <id> -> sets KIND ROOT SRC, dies when unknown
    local rec
    rec="$(all_jobs "$(user_store)" | awk -F'\t' -v id="$1" '$1 == id')"
    [ -n "$rec" ] || die "no job with ID $1 — run 'sudo approve.sh' to see the list"
    IFS=$'\t' read -r _ KIND ROOT _ SRC <<EOF2
$rec
EOF2
}

# scan_params <script> -> one line per place the script runs a param as a command. A safety net
# for the rule that unattended scripts treat params as data: it reads non-comment lines only,
# follows no other file, and does not see a param copied into a variable that is run later.
scan_params() {
    awk '
    /^[ \t]*#/ { next }
    {
        why = ""
        if ($0 ~ /(^|[;&|( \t])eval([ \t]|$)/) why = "eval"
        else if ($0 ~ /(^|[^A-Za-z0-9_.-])(sh|bash|zsh|dash|ksh)[ \t]+-[A-Za-z]*c[A-Za-z]*[ \t].*[$][{]?[0-9@*]/) why = "a shell -c on a param"
        else if ($0 ~ /(^|[;&|(])[ \t]*((then|do|else|exec)[ \t]+)*"?[$][{]?[0-9@*]/) why = "a param in command position"
        else if ($0 ~ /(^|[^A-Za-z0-9_.-])(npm|pnpm|yarn|npx|make|just)([ \t]+run)?[ \t]+"?[$][{]?[0-9@*]/) why = "a param as the build target"
        else if ($0 ~ /(^|[;&|(])[ \t]*(source|[.])[ \t]+"?[$][{]?[0-9@*]/) why = "a sourced param"
        if (why != "") { s = $0; sub(/^[ \t]+/, "", s); print "script runs a param as a command, line " NR " (" why "): " s }
    }' "$1"
}

COMPOSE="" SERVICE="" SCRIPT="" COMMAND="" TIMEOUT="" RISKS=0 YES=0
PINS=""

case "${1:-}" in
''|--list) print_jobs; exit 0 ;;
--window)
    if [ $# -eq 1 ]; then
        c="$(window_conf)" || { echo "run window: not set"; exit 0; }
        echo "run window: ${c% *} for ${c#* }h"; exit 0
    fi
    [ $# -eq 3 ] || usage
    set_window "$2" "$3"
    echo "run window: $2 for $3h — queued jobs start only inside it"
    exit 0 ;;
--revoke)
    [ $# -eq 2 ] && is_id "$2" || die "usage: approve.sh --revoke <ID> (the IDs: sudo approve.sh)"
    find_id "$2"
    [ "$KIND" = approved ] || die "$2 is not approved — nothing to revoke"
    need_writable
    what="$(job_desc "$SRC")"
    rm -f "$SRC"
    echo "revoked $2: $what for $ROOT"
    exit 0 ;;
-*) usage ;;
esac

if is_id "$1"; then
    # approve by ID: the definition comes from the registry (re-approve) or from the queued pair
    find_id "$1"; shift
    [ -d "$ROOT" ] || die "project $ROOT no longer exists"
    COMPOSE="$(kv compose "$SRC")"; SERVICE="$(kv service "$SRC")"; SCRIPT="$(kv script "$SRC")"
    if [ "$KIND" = approved ]; then
        COMMAND="$(kv command "$SRC")"; TIMEOUT="$(kv timeout "$SRC")"
        PINS="$(awk 'index($0, "pin=") == 1 { s = substr($0, 5); sub(/ [^ ]*$/, "", s); print s }' "$SRC")"
    else
        COMMAND="$(kv proposed_command "$SRC")"; TIMEOUT="$(kv proposed_timeout "$SRC")"
    fi
else
    [ $# -ge 2 ] || usage
    ROOT="$(root_of "$1")"; SCRIPT="$2"; shift 2
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --compose) COMPOSE="${2:-}"; shift 2 ;;
        --service) SERVICE="${2:-}"; shift 2 ;;
        --command) COMMAND="${2:-}"; shift 2 ;;
        --timeout) TIMEOUT="${2:-}"; shift 2 ;;
        --pin) PINS="$PINS
${2:-}"; shift 2 ;;
        --accept-risks) RISKS=1; shift ;;
        --yes) YES=1; shift ;;
        -h|--help) usage ;;
        *) die "unknown option $1" ;;
    esac
done
[ -n "$COMPOSE" ] && [ -n "$SERVICE" ] && [ -n "$SCRIPT" ] || usage
[ -n "$TIMEOUT" ] || TIMEOUT=10800
case "$TIMEOUT" in *[!0-9]*) die "--timeout must be seconds" ;; esac
case "$SERVICE" in *[!A-Za-z0-9._-]*) die "invalid service name '$SERVICE'" ;; esac
case "$SCRIPT" in *.sh) ;; *) die "the script must be a .sh file, got '$SCRIPT'" ;; esac
COMPOSE="$(rel_inside "$ROOT" "$COMPOSE")" || die "compose file is not a regular file inside $ROOT"
SCRIPT="$(rel_inside "$ROOT" "$SCRIPT")" || die "script is not a regular file inside $ROOT"
[ -n "$COMMAND" ] || COMMAND="$SCRIPT"
case "$COMMAND" in *$'\n'*) die "--command must be one line" ;; esac
PAIR="$(pair_id "$COMPOSE" "$SERVICE" "$SCRIPT")"

PIN_LIST="$(mktemp)"; trap 'rm -f "$PIN_LIST"' EXIT
{
    echo "$COMPOSE"
    echo "$SCRIPT"
    df="$(dirname "$ROOT/$COMPOSE")/Dockerfile"
    [ -f "$df" ] && [ ! -L "$df" ] && echo "${df#"$ROOT"/}"
    printf '%s\n' "$PINS" | while IFS= read -r p; do
        [ -n "$p" ] || continue
        rel_inside "$ROOT" "$p" || echo "BAD:$p"
    done
} | awk '!seen[$0]++' > "$PIN_LIST"
bad="$(grep '^BAD:' "$PIN_LIST" || true)"
[ -z "$bad" ] || die "pin outside the project or not a regular file: ${bad#BAD:}"

# --- red flags: the effective compose config, and the script's use of its params -------------
FLAGS=""
if CONFIG="$(cd "$ROOT" && as_user docker compose -f "$COMPOSE" config 2>&1)"; then
    FLAGS="$(printf '%s\n' "$CONFIG" | awk -v root="$ROOT" '
        /privileged: true/                    { print "privileged container" }
        /cap_add:/                            { print "extra capabilities (cap_add)" }
        /docker\.sock/                        { print "docker socket mounted — full host control" }
        /(network_mode|pid|ipc): "?host"?/    { print "host namespace: " $0 }
        /type: bind/                          { bind = 1; next }
        bind && /source:/ {
            s = $0; sub(/^[ \t]*source:[ \t]*/, "", s); gsub(/"/, "", s)
            if (s != root && index(s, root "/") != 1) print "host mount outside the project: " s
            bind = 0
        }
        /^[ \t]*- / { bind = 0 }' | awk '!seen[$0]++')"
else
    FLAGS="could not render 'docker compose config' — confinement unverified:
$CONFIG"
fi
SCAN="$(scan_params "$ROOT/$SCRIPT")"
[ -z "$SCAN" ] || FLAGS="$FLAGS${FLAGS:+
}$SCAN"

echo "Project:  $ROOT"
echo "Script:   $SCRIPT   (runs inside the container; Claude adds params per job)"
echo "Runs:     docker compose -f $COMPOSE run --rm -T $SERVICE $COMMAND <params...>"
echo "Timeout:  ${TIMEOUT}s"
echo "Pinned (any change => needs re-approval):"
sed 's/^/  /' "$PIN_LIST"
if [ -n "$FLAGS" ]; then
    echo "RED FLAGS:"
    printf '%s\n' "$FLAGS" | sed 's/^/  ! /'
    [ "$RISKS" = 1 ] || die "refusing: red flags present (re-run with --accept-risks if intended)"
fi

if [ "$YES" != 1 ]; then
    printf 'Approve? [y/N] '
    read -r ans < /dev/tty || ans=""
    case "$ans" in y|Y|yes) ;; *) echo "not approved"; exit 1 ;; esac
fi

need_writable
DIR="$DELAY_REGISTRY/$(encode_path "$ROOT")"
mkdir -p "$DIR/jobs"
existing="$(cat "$DIR/project.path" 2>/dev/null || true)"
if [ -z "$existing" ]; then printf '%s\n' "$ROOT" > "$DIR/project.path"
elif [ "$existing" != "$ROOT" ]; then die "registry $DIR belongs to $existing (path encoding collision)"; fi

{
    echo "compose=$COMPOSE"
    echo "service=$SERVICE"
    echo "script=$SCRIPT"
    echo "command=$COMMAND"
    echo "timeout=$TIMEOUT"
    echo "approved_by=${SUDO_USER:-$(id -un)}"
    while IFS= read -r p; do echo "pin=$p $(sha256_file "$ROOT/$p")"; done < "$PIN_LIST"
} | write_if_changed "$DIR/jobs/$PAIR"
chmod 644 "$DIR/jobs/$PAIR" "$DIR/project.path"
echo "approved $SCRIPT ($COMPOSE / $SERVICE) for $ROOT — ID $(job_id "$ROOT" "$PAIR")"
