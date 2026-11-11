#!/usr/bin/env bash
# ports.sh <command> — the machine-wide registry of dev ports.
#
#   next                 the next free port (nothing is written)
#   allocate <name>      reserve the next free port for <name> and print it; an existing name
#                        prints its port again. <name> is a project, or <project>/<service>.
#   set <name> <port>    register a port that is already in use (refused if another name holds it)
#   release <name>       forget <name>
#   viewer <name>        the E2E viewer's two ports, derived from <name>'s port: × 10 + 1 (the viewer) and
#                        × 10 + 2 (run-and-watch), registered as <name>/e2e-view and <name>/e2e-ui and printed
#                        as `e2e-view TAB port` / `e2e-ui TAB port`. Refused when <name> has no port, when it is
#                        above 6553, or when another name or a compose file already uses a derived port.
#   list [--all]         name TAB port; --all adds the ports found in compose files (name: the file)
#   scope [home|project] without an argument: where this project's ports are kept, one of
#                          home             ~/.claude/kickoff/ports.json (chosen, or already there)
#                          project          the project folder (chosen)
#                          ask              HOME is usable and nobody has chosen yet: ask the user
#                          project-no-home  HOME is not usable: the project folder, nothing to ask
#                        with an argument: record the choice in the project's .kickoff.json
#
# MACHINE-WIDE ON PURPOSE, WHEN IN HOME. The registry is ~/.claude/kickoff/ports.json and ignores
# CLAUDE_CONFIG_DIR: two Claude accounts on one Mac share one Docker, so a per-account registry
# would hand out the same port twice (repo CLAUDE.md, "Per account or per machine").
#
# HOME IS OPTIONAL (PLUG-121). Nothing is written to HOME unless the user chose it (scope home) or the
# machine-wide registry is already there (an earlier yes). Otherwise, and whenever HOME is not usable
# (unset, missing, not writable), the registry is the project's own: .git/kickoff/ports.json, or
# .kickoff/ports.json outside git. It sees only this project: the port is checked against its registry
# and the compose files under the project folder, never against other projects.
#
# A port is free when neither the registry nor any compose file under the projects dir uses it.
# The compose scan always runs, not only when the registry is new, so a port a project took
# without kickoff is still never handed out.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

PORT_BASE="${KICKOFF_PORT_BASE:-3030}"

die() { echo "ports.sh: $*" >&2; exit "${2:-2}"; }

# chosen_scope <root> — home | project from the project's .kickoff.json; empty when not chosen.
chosen_scope() {
    local f v; f="$(project_config_file "$1")"
    [ -r "$f" ] || return 0
    v="$(grep -o '"ports"[[:space:]]*:[[:space:]]*"[^"]*"' "$f" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/' || true)"
    case "$v" in home|project) printf '%s\n' "$v" ;; esac
    return 0
}

# current_scope <root> — home | project | ask | project-no-home (see the header).
current_scope() {
    local c; c="$(chosen_scope "$1")"
    if ! kickoff_home_usable; then
        [ "$c" != home ] || { echo home-gone; return 0; }
        echo project-no-home; return 0
    fi
    if [ "$c" = home ] || { [ -z "$c" ] && [ -f "$HOME/.claude/kickoff/ports.json" ]; }; then echo home
    elif [ "$c" = project ]; then echo project
    else echo ask; fi
}

# resolve_registry — sets PORTS_FILE, LOCK and PROJECTS_DIR for this run. KICKOFF_PORTS_FILE and
# KICKOFF_PROJECTS_DIR override (the tests, a custom machine).
resolve_registry() {
    local root scope; root="$(project_root)" || exit 1
    scope="$(current_scope "$root")"
    case "$scope" in
        home) PORTS_FILE="$HOME/.claude/kickoff/ports.json"; PROJECTS_DIR="$HOME/projects" ;;
        home-gone) die "this project keeps its port list in HOME (.kickoff.json), and HOME is not usable here: ports.sh needs HOME for that. Run ports.sh scope project to keep it in the project folder instead" 1 ;;
        *) PORTS_FILE="$(project_state_dir "$root")/ports.json"; PROJECTS_DIR="$root"
           case "$scope" in
               ask) echo "ports.sh: project scope — nobody has chosen yet whether to keep the port list in HOME; ask, then run ports.sh scope home|project" >&2 ;;
               *) echo "ports.sh: project scope — HOME not writable" >&2 ;;
           esac ;;
    esac
    [ -z "${KICKOFF_PORTS_FILE:-}" ] || PORTS_FILE="$KICKOFF_PORTS_FILE"
    [ -z "${KICKOFF_PROJECTS_DIR:-}" ] || PROJECTS_DIR="$KICKOFF_PROJECTS_DIR"
    LOCK="$PORTS_FILE.lock"
}

# set_scope <home|project> — record the user's choice in the project's own config.
set_scope() {
    local root f t; root="$(project_root)" || exit 1; f="$(project_config_file "$root")"
    if [ "$1" = home ] && ! kickoff_home_usable; then
        die "keeping the port list in HOME needs HOME, and HOME is not usable here (unset, missing or not writable): the project folder is used instead" 1
    fi
    t="$(mktemp)"
    if [ -f "$f" ] && grep -q '"ports"' "$f"; then
        awk -v v="$1" '/"ports"[[:space:]]*:/ { sub(/"ports"[[:space:]]*:[[:space:]]*"[^"]*"/, "\"ports\": \"" v "\"") } { print }' "$f" > "$t"
    elif [ -f "$f" ] && grep -q '{' "$f"; then
        awk -v v="$1" '!d && /\{/ { sub(/\{/, "{\n  \"ports\": \"" v "\"" ((index($0, "}") > index($0, "{") && $0 ~ /\{[[:space:]]*\}/) ? "" : ",")); d = 1 } { print }' "$f" > "$t"
    else
        printf '{\n  "ports": "%s"\n}\n' "$1" > "$t"
    fi
    write_if_changed "$f" "$t" 1 >/dev/null
}

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
port_of() { registry | awk -F'\t' -v n="$1" '($1 "") == n { print $2; exit }'; }

do_allocate() {
    local name="$1" p tsv; p="$(port_of "$name")"
    if [ -n "$p" ]; then echo "$p"; return; fi
    p="$(next_free)" || die "no free port from $PORT_BASE" 1
    tsv="$(mktemp)"; { registry; printf '%s\t%s\n' "$name" "$p"; } > "$tsv"
    write_registry "$tsv"; rm -f "$tsv"; echo "$p"
}

do_set() {
    local name="$1" port="$2" holder tsv
    holder="$(registry | awk -F'\t' -v p="$port" -v n="$name" '$2 == p && ($1 "") != n { print $1; exit }')"
    [ -z "$holder" ] || die "port $port is registered to $holder" 3
    tsv="$(mktemp)"; { registry | awk -F'\t' -v n="$name" '($1 "") != n'; printf '%s\t%s\n' "$name" "$port"; } > "$tsv"
    write_registry "$tsv"; rm -f "$tsv"; echo "$port"
}

# do_viewer <name> — both derived ports are checked before either is written, so a refusal registers nothing.
# A derived port the registry already holds under the same name is the project's own: its compose file
# publishing it is no conflict, and asking again prints the same ports without a write.
do_viewer() {
    local name="$1" app own p holder hit
    app="$(port_of "$name")"
    [ -n "$app" ] || die "no port registered for $name: register the app's port first, or pick the viewer's two ports by hand with ports.sh set $name/e2e-view <port> and ports.sh set $name/e2e-ui <port>" 1
    [ "$app" -le 6553 ] || die "the port of $name is $app: × 10 + 2 would pass 65535, so pick the viewer's two ports by hand with ports.sh set $name/e2e-view <port> and ports.sh set $name/e2e-ui <port>" 1
    for own in e2e-view:1 e2e-ui:2; do
        p=$((app * 10 + ${own#*:})); own="$name/${own%%:*}"
        holder="$(registry | awk -F'\t' -v p="$p" -v n="$own" '$2 == p && ($1 "") != n { print $1; exit }')"
        [ -z "$holder" ] || die "port $p is registered to $holder" 3
        [ "$(port_of "$own")" = "$p" ] && continue
        hit="$(scanned | awk -F'\t' -v p="$p" '$2 == p { print $1; exit }')"
        [ -z "$hit" ] || die "port $p is published in $hit" 3
    done
    do_set "$name/e2e-view" $((app * 10 + 1)) >/dev/null
    do_set "$name/e2e-ui" $((app * 10 + 2)) >/dev/null
    printf 'e2e-view\t%s\ne2e-ui\t%s\n' $((app * 10 + 1)) $((app * 10 + 2))
}

do_release() {
    local tsv; tsv="$(mktemp)"; registry | awk -F'\t' -v n="$1" '($1 "") != n' > "$tsv"
    write_registry "$tsv"; rm -f "$tsv"
}

cmd="${1:-}"; [ $# -gt 0 ] && shift
case "$cmd" in next|allocate|set|release|viewer|list) resolve_registry ;; esac
case "$cmd" in
    scope)
        case "${1:-}" in
            '') s="$(current_scope "$(project_root)")"; [ "$s" != home-gone ] || s=home; echo "$s" ;;
            home|project) set_scope "$1" ;;
            *) die "usage: ports.sh scope [home|project]" ;;
        esac ;;
    next) next_free || die "no free port from $PORT_BASE" 1 ;;
    allocate) [ $# -eq 1 ] || die "usage: ports.sh allocate <name>"; valid_name "$1"; with_lock do_allocate "$1" ;;
    set) [ $# -eq 2 ] || die "usage: ports.sh set <name> <port>"; valid_name "$1"
         case "$2" in ''|*[!0-9]*) die "bad port: '$2'" ;; esac; with_lock do_set "$1" "$2" ;;
    release) [ $# -eq 1 ] || die "usage: ports.sh release <name>"; with_lock do_release "$1" ;;
    viewer) [ $# -eq 1 ] || die "usage: ports.sh viewer <name>"; valid_name "$1"; with_lock do_viewer "$1" ;;
    list) registry; [ "${1:-}" = --all ] && scanned; true ;;
    *) die "usage: ports.sh next | allocate <name> | set <name> <port> | release <name> | viewer <name> | list [--all] | scope [home|project]" ;;
esac
