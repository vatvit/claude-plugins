#!/usr/bin/env bash
# ports.sh <command> — the machine-wide registry of dev ports.
#
#   next                 the next free port (nothing is written)
#   allocate <name>      reserve the next free port for <name> and print it; an existing name
#                        prints its port again. <name> is a project, or <project>/<service>.
#   set <name> <port>    register a port that is already in use (refused if another name holds it)
#   release <name>       forget <name>
#   list [--all]         name TAB port; --all adds the ports found in compose files (name: the file)
#
# MACHINE-WIDE ON PURPOSE. The registry is ~/.claude/kickoff/ports.json and ignores
# CLAUDE_CONFIG_DIR: two Claude accounts on one Mac share one Docker, so a per-account registry
# would hand out the same port twice (repo CLAUDE.md, "Per account or per machine").
#
# A port is free when neither the registry nor any compose file under the projects dir uses it.
# The compose scan always runs, not only when the registry is new, so a port a project took
# without kickoff is still never handed out.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

PORTS_FILE="${KICKOFF_PORTS_FILE:-$HOME/.claude/kickoff/ports.json}"
PROJECTS_DIR="${KICKOFF_PROJECTS_DIR:-$HOME/projects}"
PORT_BASE="${KICKOFF_PORT_BASE:-3030}"

die() { echo "ports.sh: $*" >&2; exit "${2:-2}"; }

# registry — name TAB port, from the flat JSON object (one "name": port per line).
registry() {
    [ -f "$PORTS_FILE" ] || return 0
    awk 'match($0, /"[^"]+"[ \t]*:[ \t]*[0-9]+/) {
        s = substr($0, RSTART, RLENGTH); n = s; sub(/^"/, "", n); sub(/".*/, "", n)
        p = s; sub(/.*:[ \t]*/, "", p); print n "\t" p }' "$PORTS_FILE"
}

# scanned — file TAB port for every host port published in a compose file under PROJECTS_DIR.
# Handles "3035:3000", '127.0.0.1:3035:3000', 8080:80, "${APP_PORT:-8310}:8000" and `published: 3035`.
scanned() {
    [ -d "$PROJECTS_DIR" ] || return 0
    find "$PROJECTS_DIR" -maxdepth 4 \( -name 'compose*.y*ml' -o -name 'docker-compose*.y*ml' \) \
        -not -path '*/node_modules/*' 2>/dev/null | while IFS= read -r f; do
        awk -v f="$f" '
            { line = $0; sub(/#.*/, "", line); gsub(/\$\{[A-Za-z_][A-Za-z0-9_]*:-/, "", line); gsub(/[}"\047]/, "", line) }
            line ~ /^[ \t]*-[ \t]*([0-9.]+:)?[0-9]+:[0-9]+/ {
                sub(/^[ \t]*-[ \t]*/, "", line); n = split(line, p, ":")
                host = (n >= 3) ? p[n - 1] : p[1]; sub(/[^0-9].*/, "", host); if (host != "") print f "\t" host
            }
            line ~ /^[ \t]*published:[ \t]*[0-9]+/ { sub(/.*published:[ \t]*/, "", line); sub(/[^0-9].*/, "", line); print f "\t" line }
        ' "$f"
    done
}

# next_free — the lowest port from PORT_BASE that nothing uses.
next_free() {
    { registry; scanned; } | awk -F'\t' -v base="$PORT_BASE" '
        { used[$2] = 1 } END { p = base; while (p in used) p++; if (p > 65535) exit 1; print p }'
}

# write_registry <tsv-file> — the registry, rewritten from name TAB port lines, sorted by port.
write_registry() {
    local tmp; tmp="$(mktemp)"
    sort -t "$(printf '\t')" -k2,2n -k1,1 "$1" | awk -F'\t' '
        BEGIN { print "{" } { line[NR] = "  \"" $1 "\": " $2 }
        END { for (i = 1; i <= NR; i++) print line[i] (i < NR ? "," : ""); print "}" }' > "$tmp"
    write_if_changed "$PORTS_FILE" "$tmp" 1 >/dev/null
}

# with_lock <fn> [args] — run fn holding the registry lock. A lock left by a dead process is broken.
LOCK="$PORTS_FILE.lock"
with_lock() {
    mkdir -p "$(dirname "$PORTS_FILE")"
    local tries=0 holder
    until mkdir "$LOCK" 2>/dev/null; do
        holder="$(cat "$LOCK/pid" 2>/dev/null || true)"
        if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then rm -rf "$LOCK"; continue; fi
        tries=$((tries + 1)); [ "$tries" -le 300 ] || die "registry is locked ($LOCK)" 4
        sleep 0.1 2>/dev/null || sleep 1
    done
    echo $$ > "$LOCK/pid"
    trap 'rm -rf "$LOCK"' EXIT
    "$@"
    rm -rf "$LOCK"; trap - EXIT
}

valid_name() { case "$1" in ''|*[!A-Za-z0-9._/-]*) die "bad name: '$1' (letters, digits, . _ / -)" ;; esac; }
port_of() { registry | awk -F'\t' -v n="$1" '$1 == n { print $2; exit }'; }

do_allocate() {
    local name="$1" p tsv; p="$(port_of "$name")"
    if [ -n "$p" ]; then echo "$p"; return; fi
    p="$(next_free)" || die "no free port from $PORT_BASE" 1
    tsv="$(mktemp)"; { registry; printf '%s\t%s\n' "$name" "$p"; } > "$tsv"
    write_registry "$tsv"; rm -f "$tsv"; echo "$p"
}

do_set() {
    local name="$1" port="$2" holder tsv
    holder="$(registry | awk -F'\t' -v p="$port" -v n="$name" '$2 == p && $1 != n { print $1; exit }')"
    [ -z "$holder" ] || die "port $port is registered to $holder" 3
    tsv="$(mktemp)"; { registry | awk -F'\t' -v n="$name" '$1 != n'; printf '%s\t%s\n' "$name" "$port"; } > "$tsv"
    write_registry "$tsv"; rm -f "$tsv"; echo "$port"
}

do_release() {
    local tsv; tsv="$(mktemp)"; registry | awk -F'\t' -v n="$1" '$1 != n' > "$tsv"
    write_registry "$tsv"; rm -f "$tsv"
}

cmd="${1:-}"; [ $# -gt 0 ] && shift
case "$cmd" in
    next) next_free || die "no free port from $PORT_BASE" 1 ;;
    allocate) [ $# -eq 1 ] || die "usage: ports.sh allocate <name>"; valid_name "$1"; with_lock do_allocate "$1" ;;
    set) [ $# -eq 2 ] || die "usage: ports.sh set <name> <port>"; valid_name "$1"
         case "$2" in ''|*[!0-9]*) die "bad port: '$2'" ;; esac; with_lock do_set "$1" "$2" ;;
    release) [ $# -eq 1 ] || die "usage: ports.sh release <name>"; with_lock do_release "$1" ;;
    list) registry; [ "${1:-}" = --all ] && scanned; true ;;
    *) die "usage: ports.sh next | allocate <name> | set <name> <port> | release <name> | list [--all]" ;;
esac
