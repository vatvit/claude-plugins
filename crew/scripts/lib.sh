#!/usr/bin/env bash
# Shared helpers for the crew plugin. Sourced, never executed.
#
# The ONE place that resolves the project, the state directory, config layering, session
# identity, claims, locking and hook decisions. Every crew script and hook sources this.
#
# State lives in <git-common-dir>/crew/: shared by every session on the working tree, never
# committed, and needs no .gitignore entry. Its existence is what makes crew "active" in a repo.

CREW_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CREW_PLUGIN_DIR="$(dirname "$CREW_LIB_DIR")"
CREW_BIN="$CREW_LIB_DIR/crew.sh"
CREW_USER_CONFIG="${CREW_USER_CONFIG:-$HOME/.claude/crew.json}"
CREW_HOME="${CREW_HOME:-$HOME/.claude/crew}"          # machine-wide: the name registry
CREW_KEYS="crewId sharedBranch committer hookMode hotSpots landCheck snapshotKeep snapshotMaxKB slotGraceMin"

die()  { echo "crew: $*" >&2; exit 1; }
note() { echo "crew: $*" >&2; }

now() { echo "${CREW_NOW:-$(date +%s)}"; }

# --- dates: BSD first, GNU/busybox fallback ---------------------------------------------
fmt_epoch() { date -r "$1" "+$2" 2>/dev/null || date -d "@$1" "+$2"; }
hhmm() { fmt_epoch "$1" %H:%M; }

# --- project + state -----------------------------------------------------------------------
# crew_init: sets ROOT (work tree top), STATE (<git-common-dir>/crew). Dies outside a repo.
crew_try_init() { # same, but returns 1 instead of dying — for hooks, which must never fail
    local start="${CREW_PROJECT_DIR:-$(pwd)}" gd
    ROOT="$(git -C "$start" rev-parse --show-toplevel 2>/dev/null)" || return 1
    gd="$(git -C "$ROOT" rev-parse --git-common-dir 2>/dev/null)" || return 1
    case "$gd" in /*) : ;; *) gd="$ROOT/$gd" ;; esac
    STATE="$(cd "$gd" && pwd -P)/crew"
}
crew_init() { crew_try_init || die "not inside a git work tree: ${CREW_PROJECT_DIR:-$(pwd)}"; }
crew_active() { [ -d "$STATE" ]; }
need_active() { crew_active || die "no crew in this repo yet — start one: crew.sh whoami <name> coordinator"; }

# rel_path <path> -> repo-relative path (absolute paths under ROOT are stripped)
rel_path() {
    local p="$1"
    case "$p" in
        "$ROOT"/*) p="${p#"$ROOT"/}" ;;
        /*) local r; r="$(cd "$ROOT" && pwd -P)"; case "$p" in "$r"/*) p="${p#"$r"/}" ;; esac ;;
    esac
    case "$p" in ./*) p="${p#./}" ;; esac
    printf '%s\n' "$p"
}

# --- JSON (flat config + hook payloads) ----------------------------------------------------
# json_val <key> <file> -> a string value, an array's elements one per line, or a bare scalar.
# Empty when absent. Config strings cannot contain a double quote (put such a command in a script).
json_val() {
    [ -f "$2" ] || return 0
    local flat v
    flat="$(tr '\n\t' '  ' < "$2")"
    v="$(printf '%s' "$flat" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 \
        | sed 's/.*:[[:space:]]*"//; s/"$//' || true)"
    [ -n "$v" ] && { printf '%s\n' "$v"; return 0; }
    v="$(printf '%s' "$flat" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\[[^]]*\]" | head -1 \
        | grep -o '"[^"]*"' | sed '1d; s/^"//; s/"$//' || true)"
    [ -n "$v" ] && { printf '%s\n' "$v"; return 0; }
    printf '%s' "$flat" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*[-0-9A-Za-z.]*" | head -1 \
        | sed 's/.*:[[:space:]]*//' || true
    return 0
}

# payload_str <key> — first JSON string value of <key> in the hook payload on stdin, unescaped.
payload_str() {
    awk -v key="$1" 'BEGIN { RS = "\001" }
    {
        if (!match($0, "\"" key "\"[ \t\r\n]*:[ \t\r\n]*\"")) exit
        s = substr($0, RSTART + RLENGTH); out = ""; n = length(s)
        for (i = 1; i <= n; i++) {
            c = substr(s, i, 1)
            if (c == "\\") {
                e = substr(s, i + 1, 1); i++
                if (e == "n") out = out "\n"; else if (e == "t") out = out "\t"
                else if (e == "u") { out = out "?"; i += 4 } else out = out e
                continue
            }
            if (c == "\"") break
            out = out c
        }
        printf "%s", out
    }'
}

# --- config: project .crew.json > user ~/.claude/crew.json > default, per key ---------------
cfg_default() {
    case "$1" in
        committer) echo coordinator ;; hookMode) echo deny ;;
        snapshotKeep) echo 20 ;; snapshotMaxKB) echo 1024 ;; slotGraceMin) echo 10 ;;
    esac
    return 0
}
cfg_project_only() { case "$1" in crewId|sharedBranch|hotSpots|landCheck) return 0 ;; esac; return 1; }

# cfg_src <key> -> "project" | "user" | "default"
cfg_src() {
    [ -n "$(json_val "$1" "$ROOT/.crew.json")" ] && { echo project; return 0; }
    if ! cfg_project_only "$1" && [ -n "$(json_val "$1" "$CREW_USER_CONFIG")" ]; then echo user; return 0; fi
    echo default
}
cfg() {
    case "$(cfg_src "$1")" in
        project) json_val "$1" "$ROOT/.crew.json" ;;
        user)    json_val "$1" "$CREW_USER_CONFIG" ;;
        *)       cfg_default "$1" ;;
    esac
}
# crew_id: configured, else the repo folder name — tags every message so crews never cross
crew_id() {
    local i; i="$(cfg crewId)"
    [ -n "$i" ] || i="$(basename "$ROOT")"
    printf '%s\n' "$i" | tr -c 'A-Za-z0-9_.\n-' '-'
}

# --- machine-wide name registry: $CREW_HOME/names/<name> holds state= crew= sid= ----------------
# SendMessage addresses sessions across the whole machine, so a crew name must be unique there too.
reg_set() { mkdir -p "$CREW_HOME/names" && printf 'state=%s\ncrew=%s\nsid=%s\n' "$STATE" "$(crew_id)" "$2" | replace_file "$CREW_HOME/names/$1"; }
reg_get() { [ -f "$CREW_HOME/names/$1" ] && sed -n "s/^$2=//p" "$CREW_HOME/names/$1" | head -1; return 0; }
# reg_other <name> -> "<crew> (<work tree>)" when a LIVE session of ANOTHER crew owns the name
reg_other() {
    local st sid
    st="$(reg_get "$1" state)"; sid="$(reg_get "$1" sid)"
    [ -n "$st" ] && [ "$st" != "$STATE" ] || return 0
    [ -f "$st/sessions/$1" ] && grep -q -x "sid=$sid" "$st/sessions/$1" || return 0   # stale entry
    printf '%s (%s)\n' "$(reg_get "$1" crew)" "$(dirname "$(dirname "$st")")"
}
reg_drop() { [ "$(reg_get "$1" state)" = "$STATE" ] && rm -f "$CREW_HOME/names/$1"; return 0; }
# shared_branch: configured, else the branch checked out now
shared_branch() {
    local b; b="$(cfg sharedBranch)"
    [ -n "$b" ] || b="$(git -C "$ROOT" symbolic-ref --short -q HEAD || true)"
    printf '%s\n' "$b"
}

# --- locking ---------------------------------------------------------------------------------
# with_lock <name> <cmd...> — mkdir mutex; a lock older than 30 s is a crashed holder's.
with_lock() {
    local l="$STATE/.lock-$1" i=0 age rc; shift
    mkdir -p "$STATE"
    until mkdir "$l" 2>/dev/null; do
        i=$((i + 1))
        if [ $((i % 50)) -eq 0 ]; then
            age=$(( $(date +%s) - $(stat -f %m "$l" 2>/dev/null || stat -c %Y "$l" 2>/dev/null || date +%s) ))
            [ "$age" -gt 30 ] && rm -rf "$l"
        fi
        [ "$i" -gt 600 ] && die "could not take lock $l"
        sleep 0.1
    done
    CREW_HELD_LOCK="$l"; trap 'rm -rf "$CREW_HELD_LOCK"' EXIT
    "$@" && rc=0 || rc=$?
    rm -rf "$l"; CREW_HELD_LOCK=""; trap - EXIT
    return $rc
}

# replace_file <file> — stdin becomes the file (temp + mv); untouched when identical.
replace_file() {
    local tmp="$1.tmp.$$"
    cat > "$tmp"
    if [ -f "$1" ] && cmp -s "$tmp" "$1"; then rm -f "$tmp"; else mv "$tmp" "$1"; fi
}

# --- sessions: $STATE/sessions/<name> holds sid= role= since= -------------------------------
valid_name() { case "$1" in ''|-*|*[!A-Za-z0-9_.-]*) return 1 ;; esac; return 0; }
sess_get() { # <name> <key>
    [ -f "$STATE/sessions/$1" ] || return 0
    sed -n "s/^$2=//p" "$STATE/sessions/$1" | head -1
}
sess_names() { [ -d "$STATE/sessions" ] && ls "$STATE/sessions" 2>/dev/null; return 0; }
name_of_sid() { # <sid> -> name, empty when unbound
    local f
    [ -n "$1" ] && [ -d "$STATE/sessions" ] || return 0
    f="$(grep -l -x "sid=$1" "$STATE"/sessions/* 2>/dev/null | head -1 || true)"
    [ -n "$f" ] && basename "$f"
    return 0
}
coordinator() {
    local n
    for n in $(sess_names); do [ "$(sess_get "$n" role)" = coordinator ] && { echo "$n"; return 0; }; done
    return 0
}
crew_line() { # "s1 coordinator · s2 worker"
    local n out=""
    for n in $(sess_names); do out="$out${out:+ · }$n $(sess_get "$n" role)"; done
    printf '%s\n' "$out"
}
# me — the caller's crew name, from CREW_AS (the prefix SessionStart hands each session)
me() {
    local n="${CREW_AS:-}"
    [ -n "$n" ] || die "who is calling? prefix the command with CREW_AS=<your crew name>"
    [ -f "$STATE/sessions/$n" ] || die "'$n' is not in this crew — join with: crew.sh whoami $n [worker|coordinator]"
    printf '%s\n' "$n"
}
prefix_for() { echo "CREW_AS=$1 bash $CREW_BIN"; }

# --- claims: which session touched which dirty path ($STATE/claims: path<TAB>name<TAB>epoch) ---
_claim_add() { # <name> <path...>
    local n="$1" t; shift; t="$(now)"
    local tmp="$STATE/claims.add.$$"; : > "$tmp"
    local p; for p in "$@"; do printf '%s\t%s\t%s\n' "$p" "$n" "$t" >> "$tmp"; done
    { [ -f "$STATE/claims" ] && cat "$STATE/claims"; cat "$tmp"; } \
        | awk -F'\t' '!seen[$1 FS $2]++' | replace_file "$STATE/claims"
    rm -f "$tmp"
}
claim_add() { mkdir -p "$STATE"; with_lock claims _claim_add "$@"; }
_claim_drop() { # <path...> — every session's claim on these paths
    [ -f "$STATE/claims" ] || return 0
    local tmp="$STATE/claims.drop.$$"; printf '%s\n' "$@" > "$tmp"
    awk -F'\t' -v df="$tmp" 'FILENAME == df { drop[$0] = 1; next } !($1 in drop)' "$tmp" "$STATE/claims" \
        | replace_file "$STATE/claims"
    rm -f "$tmp"
}
claim_drop() { with_lock claims _claim_drop "$@"; }
claimants() { # <path> -> names, comma-separated
    [ -f "$STATE/claims" ] || return 0
    awk -F'\t' -v p="$1" '$1 == p { o = o (o ? "," : "") $2 } END { print o }' "$STATE/claims"
}

# dirty_paths — repo-relative path per line: modified, staged, untracked, deleted (renames: new path)
dirty_paths() {
    git -C "$ROOT" status --porcelain -z -uall | tr '\0' '\n' \
        | awk 'skip { skip = 0; next } { st = substr($0, 1, 2); print substr($0, 4); if (st ~ /[RC]/) skip = 1 }'
}
# dirty_owned — "path<TAB>claimants" for every dirty path (claimants empty when nobody)
dirty_owned() {
    local tmp="$STATE/dirty.$$" c="$STATE/claims"
    [ -f "$c" ] || c=/dev/null
    dirty_paths > "$tmp"
    # FILENAME, not NR == FNR: an empty claims file would make that test true for the dirty list
    awk -F'\t' -v cf="$c" 'FILENAME == cf { if ($1 in c) c[$1] = c[$1] "," $2; else c[$1] = $2; next }
                { print $0 "\t" c[$0] }' "$c" "$tmp"
    rm -f "$tmp"
}
# my_dirty <name> — dirty paths this session claims
my_dirty() { dirty_owned | awk -F'\t' -v n="$1" '{ k = "," $2 ","; if (index(k, "," n ",")) print $1 }'; }

# --- hook decisions --------------------------------------------------------------------------
# hook_block <reason> — deny the tool call (hookMode=deny) or let it through with a warning.
# Always exit 0: a hook never crashes the call that triggered it.
hook_block() {
    local r="crew: $1" esc
    esc="$(printf '%s' "$r" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk 'BEGIN { ORS = "\\n" } { print }' | sed 's/\\n$//')"
    if [ "$(cfg hookMode)" = warn ]; then
        echo "$r (hookMode=warn: allowed)" >&2
        printf '{"systemMessage":"%s (hookMode=warn: allowed)"}\n' "$esc"
    else
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$esc"
    fi
    exit 0
}

# --- area modules ------------------------------------------------------------------------------
# Each area script (holds.sh, slot.sh, ...) defines functions when sourced and runs its CLI when
# executed. load_area <name> sources it when present, so hooks degrade if one is missing.
load_area() { [ -f "$CREW_LIB_DIR/$1.sh" ] && . "$CREW_LIB_DIR/$1.sh"; return 0; }
is_main() { [ "${BASH_SOURCE[1]}" = "$0" ]; }

# --- hooks -----------------------------------------------------------------------------------
# hook_init — read the payload on stdin into PAYLOAD, then set ROOT, STATE, SID and NAME (empty
# when the session has not joined). Returns 1 outside a git repo: the hook has nothing to do.
hook_init() {
    PAYLOAD="$(cat)"
    CREW_PROJECT_DIR="$(printf '%s' "$PAYLOAD" | payload_str cwd)"
    [ -n "$CREW_PROJECT_DIR" ] || CREW_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
    crew_try_init || return 1
    SID="$(printf '%s' "$PAYLOAD" | payload_str session_id)"
    NAME=""; crew_active && NAME="$(name_of_sid "$SID")"
    return 0
}
