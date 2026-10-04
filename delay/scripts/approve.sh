#!/usr/bin/env bash
# approve.sh — the HUMAN's command, run with sudo. Writes the root-owned registry that is the
# whitelist: a job name → compose file + service + command, with the files that define the
# container's confinement pinned by sha256. Claude never runs this.
#
#   sudo approve.sh                  every project: approved jobs and jobs waiting, with an ID
#   sudo approve.sh <ID>             review that job and approve it (y/N); also re-approves an
#                                    approved job whose pinned files changed
#   sudo approve.sh --revoke <ID>    take an approval back
#   sudo approve.sh --window HH:MM HOURS   when ALL queued jobs may start (daily, local time)
#   approve.sh --window                    show it
#
#   Full form, without an ID (when nobody proposed a definition):
#   sudo approve.sh <project-dir> <job> --compose FILE --service NAME --wrapper SCRIPT
#                   [--command "CMD"] [--timeout SECONDS] [--pin FILE]...
#   Any form takes [--accept-risks] [--yes].
#
# An ID stands for a (project, job) pair. A waiting job's definition is what Claude proposed
# with `delay.sh add <job> --compose … --service … --wrapper …`; nothing proposed is trusted —
# it is shown to you, re-validated, red-flag checked and pinned only when you answer y.
# Paths are relative to the project root and must stay inside it. The wrapper is pinned on the
# host; `--command` (default: the wrapper path) is what runs inside the container. A Dockerfile
# next to the compose file is pinned automatically.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/lib.sh"

usage() { sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

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

find_id() { # <id> -> sets KIND ROOT JOB SRC, dies when unknown
    local rec
    rec="$(all_jobs "$(user_store)" | awk -F'\t' -v id="$1" '$1 == id')"
    [ -n "$rec" ] || die "no job with ID $1 — run 'sudo approve.sh' to see the list"
    IFS=$'\t' read -r _ KIND ROOT JOB SRC <<EOF2
$rec
EOF2
}

COMPOSE="" SERVICE="" WRAPPER="" COMMAND="" TIMEOUT=10800 RISKS=0 YES=0
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
    if [ $# -eq 2 ] && is_id "$2"; then
        find_id "$2"
        [ "$KIND" = approved ] || die "$JOB ($2) is not approved — nothing to revoke"
    else
        [ $# -eq 3 ] || usage
        ROOT="$(root_of "$2")"; JOB="$3"; valid_name "$JOB" || die "invalid job name '$JOB'"
    fi
    need_writable
    f="$DELAY_REGISTRY/$(encode_path "$ROOT")/jobs/$JOB"
    [ -f "$f" ] || die "job '$JOB' is not approved for $ROOT"
    rm -f "$f"
    echo "revoked $JOB for $ROOT"
    exit 0 ;;
-*) usage ;;
esac

if is_id "$1"; then
    # approve by ID: the definition comes from the registry (re-approve) or from the proposal
    find_id "$1"; shift
    [ -d "$ROOT" ] || die "project $ROOT no longer exists"
    if [ "$KIND" = approved ]; then
        COMPOSE="$(kv compose "$SRC")"; SERVICE="$(kv service "$SRC")"
        COMMAND="$(kv command "$SRC")"; TIMEOUT="$(kv timeout "$SRC")"
        WRAPPER="$(kv wrapper "$SRC")"
        PINS="$(awk 'index($0, "pin=") == 1 { s = substr($0, 5); sub(/ [^ ]*$/, "", s); print s }' "$SRC")"
    else
        COMPOSE="$(kv proposed_compose "$SRC")"; SERVICE="$(kv proposed_service "$SRC")"
        WRAPPER="$(kv proposed_wrapper "$SRC")"; COMMAND="$(kv proposed_command "$SRC")"
        TIMEOUT="$(kv proposed_timeout "$SRC")"
        [ -n "$COMPOSE" ] || die "nobody proposed a definition for $JOB — ask Claude to re-queue it with --compose/--service/--wrapper, or use the full form (sudo approve.sh -h)"
    fi
    [ -n "$TIMEOUT" ] || TIMEOUT=10800
    [ -n "$WRAPPER" ] || WRAPPER="$(printf '%s\n' "$PINS" | sed -n 2p)"
else
    [ $# -ge 2 ] || usage
    ROOT="$(root_of "$1")"; JOB="$2"; shift 2
fi
valid_name "$JOB" || die "invalid job name '$JOB' (allowed: A-Z a-z 0-9 . _ -)"

while [ $# -gt 0 ]; do
    case "$1" in
        --compose) COMPOSE="${2:-}"; shift 2 ;;
        --service) SERVICE="${2:-}"; shift 2 ;;
        --wrapper) WRAPPER="${2:-}"; shift 2 ;;
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
[ -n "$COMPOSE" ] && [ -n "$SERVICE" ] && [ -n "$WRAPPER" ] || usage
case "$TIMEOUT" in ''|*[!0-9]*) die "--timeout must be seconds" ;; esac
case "$SERVICE" in *[!A-Za-z0-9._-]*) die "invalid service name '$SERVICE'" ;; esac
[ -n "$COMMAND" ] || COMMAND="$WRAPPER"
case "$COMMAND" in *$'\n'*) die "--command must be one line" ;; esac

relpath() { # absolute (inside ROOT) -> relative to ROOT
    echo "${1#"$ROOT"/}"
}

COMPOSE_ABS="$(inside_project "$ROOT" "$COMPOSE")" || die "compose file '$COMPOSE' is not a regular file inside $ROOT"
WRAPPER_ABS="$(inside_project "$ROOT" "$WRAPPER")" || die "wrapper '$WRAPPER' is not a regular file inside $ROOT"

PIN_LIST="$(mktemp)"; trap 'rm -f "$PIN_LIST"' EXIT
{
    relpath "$COMPOSE_ABS"
    relpath "$WRAPPER_ABS"
    df="$(dirname "$COMPOSE_ABS")/Dockerfile"
    [ -f "$df" ] && [ ! -L "$df" ] && relpath "$df"
    printf '%s\n' "$PINS" | while IFS= read -r p; do
        [ -n "$p" ] || continue
        a="$(inside_project "$ROOT" "$p")" || { echo "BAD:$p"; continue; }
        relpath "$a"
    done
} | awk '!seen[$0]++' > "$PIN_LIST"
bad="$(grep '^BAD:' "$PIN_LIST" || true)"
[ -z "$bad" ] || die "pin outside the project or not a regular file: ${bad#BAD:}"

# --- red flags in the effective compose config ---------------------------------------------
FLAGS=""
if CONFIG="$(cd "$ROOT" && as_user docker compose -f "$(relpath "$COMPOSE_ABS")" config 2>&1)"; then
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

echo "Project:  $ROOT"
echo "Job:      $JOB"
echo "Runs:     docker compose -f $(relpath "$COMPOSE_ABS") run --rm -T $SERVICE $COMMAND"
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
    echo "compose=$(relpath "$COMPOSE_ABS")"
    echo "service=$SERVICE"
    echo "wrapper=$(relpath "$WRAPPER_ABS")"
    echo "command=$COMMAND"
    echo "timeout=$TIMEOUT"
    echo "approved_by=${SUDO_USER:-$(id -un)}"
    while IFS= read -r p; do echo "pin=$p $(sha256_file "$ROOT/$p")"; done < "$PIN_LIST"
} | write_if_changed "$DIR/jobs/$JOB"
chmod 644 "$DIR/jobs/$JOB" "$DIR/project.path"
echo "approved $JOB for $ROOT"
