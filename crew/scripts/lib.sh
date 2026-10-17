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
# Per ACCOUNT: the user's preferences follow the Claude account (Claude Code sets CLAUDE_CONFIG_DIR
# for a non-default one), so each account keeps its own crew.json.
CREW_USER_CONFIG="${CREW_USER_CONFIG:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/crew.json}"
# Per MACHINE: the session-name registry deliberately ignores CLAUDE_CONFIG_DIR — SendMessage
# addresses sessions of every account on this machine, so all accounts must see one registry.
CREW_HOME="${CREW_HOME:-$HOME/.claude/crew}"
CREW_KEYS="crewId sharedBranch committer push tree treeSync taskPush treeLink treeSetup crewRules hookMode hotSpots landCheck snapshotKeep snapshotMaxKB slotGraceMin silenceMin"

die()  { echo "crew: $*" >&2; exit 1; }
note() { echo "crew: $*" >&2; }

now() { echo "${CREW_NOW:-$(date +%s)}"; }

# file_mtime <file> -> epoch. GNU/busybox first: busybox `stat -f` is filesystem info and prints junk
# to stdout even as it fails, while BSD `stat -c` fails cleanly.
file_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null; }
# json_esc <text> — a JSON string body (\ and " escaped, newlines as \n), for hook output
json_esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk 'BEGIN { ORS = "\\n" } { print }' | sed 's/\\n$//'; }

# --- dates: BSD first, GNU/busybox fallback ---------------------------------------------
fmt_epoch() { date -r "$1" "+$2" 2>/dev/null || date -d "@$1" "+$2"; }
hhmm() { fmt_epoch "$1" %H:%M; }

# --- project + state -----------------------------------------------------------------------
# crew_init: sets ROOT (the main work tree), CREW_TREE (the work tree the caller is in: ROOT, or
# a linked worktree), STATE (<git-common-dir>/crew). Dies outside a repo.
crew_try_init() { # same, but returns 1 instead of dying — for hooks, which must never fail
    local start="${CREW_PROJECT_DIR:-$(pwd)}" r rest common gd
    r="$(git -C "$start" rev-parse --path-format=absolute --show-toplevel --git-common-dir --git-dir 2>/dev/null)" || return 1
    # three lines, or no work tree (a bare repo prints no toplevel)
    CREW_TREE="${r%%$'\n'*}"; rest="${r#*$'\n'}"; [ -n "$CREW_TREE" ] && [ "$rest" != "$r" ] || return 1
    common="${rest%%$'\n'*}"; gd="${rest#*$'\n'}"; [ "$gd" != "$rest" ] || return 1
    # In a linked worktree the crew is still the main tree's: ROOT is where every session lands.
    ROOT="$CREW_TREE"
    case "$common" in */.git) [ "$gd" = "$common" ] || ROOT="${common%/.git}" ;; esac
    STATE="$common/crew"
    # ids parked by the pre-bash hook for whoami; OUTSIDE crew/, so a join that never completes does
    # not switch crew on for the repo (crew_active is "crew/ exists")
    CREW_PENDING="$common/crew-pending"
    cfg_load
}
# crew's own worktrees live in ONE folder of the main tree, named <repo>-<name> (PLUG-062). The
# folder name is also the Docker Compose project name a copy gets by default.
CREW_WT=.worktrees
crew_wt_dir() { printf '%s/%s/%s-%s\n' "$ROOT" "$CREW_WT" "${ROOT##*/}" "$1"; }   # <name>
# crew_wt_ignore — make sure the main tree ignores crew's worktree folder: one line appended to
# .gitignore (created when absent), only when no rule covers it yet. Left uncommitted, never removed.
crew_wt_ignore() {
    local f="$ROOT/.gitignore" t
    git -C "$ROOT" check-ignore -q "$CREW_WT/" 2>/dev/null && return 0
    t="$(mktemp)"
    { [ -f "$f" ] && cat "$f" && [ -n "$(tail -c 1 "$f")" ] && echo; echo "/$CREW_WT/"; } > "$t"
    if cmp -s "$t" "$f" 2>/dev/null; then rm -f "$t"; else cat "$t" > "$f"; rm -f "$t"; fi
    note "added /$CREW_WT/ to .gitignore (not committed) — crew's worktrees live there"
}
# crew_wt_add <name> <git worktree add args after the folder...> — the ONE way crew makes a worktree
# (copy new, tree new): a free folder, the ignore line, then git. Prints the folder.
crew_wt_add() {
    local name="$1" dir; shift
    dir="$(crew_wt_dir "$name")"
    [ ! -e "$dir" ] || die "$dir is in use (crew status lists crew's worktrees)"
    crew_wt_ignore
    git -C "$ROOT" worktree add -q "$dir" "$@" >/dev/null 2>&1 || die "git worktree add $dir failed"
    printf '%s\n' "$dir"
}
# A crew worktree's record: crew-copy in ITS git dir — base= root= made= by=, and task= for a task
# worktree (PLUG-066). The name predates task worktrees: a pre-2.1 clone copy has the same file.
crew_wt_metafile() { local g; g="$(git -C "$1" rev-parse --absolute-git-dir 2>/dev/null)" && echo "$g/crew-copy"; }
crew_wt_meta() { sed -n "s/^$2=//p" "$(crew_wt_metafile "$1")" 2>/dev/null | head -1 || true; }   # <dir> <key>; empty when absent
crew_wt_write_meta() { # <dir> <base> <made> <by> [task] — by: the session that made it, "" when unknown
    printf 'base=%s\nroot=%s\nmade=%s\nby=%s\n%s' "$2" "$ROOT" "$3" "$4" "${5:+task=$5
}" > "$(crew_wt_metafile "$1")"
}
# A new worktree has no untracked files (PLUG-067). treeLink lists the local ones to link from the
# main tree; each entry is data — a relative path with no .. — never executed. treeSetup is the
# project's own setup step: printed for the session, never run by crew.
crew_link_ok() { [ -n "$1" ] && case "/$1/" in //*|*/../*|*/./*) return 1 ;; esac; }
# crew_wt_ready <dir> — after crew made a worktree: the links, the setup step, the Docker report
crew_wt_ready() {
    local d="$1" p
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        crew_link_ok "$p" || { echo "crew: treeLink $p: not a path inside the main tree — skipped"; continue; }
        [ -e "$ROOT/$p" ] || { echo "crew: treeLink $p is not in the main tree — skipped"; continue; }
        [ ! -e "$d/$p" ] && [ ! -L "$d/$p" ] || continue                   # tracked: the branch's own
        mkdir -p "$(dirname "$d/$p")" && ln -s "$ROOT/$p" "$d/$p"
    done <<EOF
$(cfg treeLink)
EOF
    p="$(cfg treeSetup)"
    [ -z "$p" ] || echo "crew: before working in $d, run the project's setup there: $p (crew prints it, never runs it)"
    compose_report "$d"
}
# crew_link_filter <prefix> — stdin lines minus "<prefix><a treeLink path>": the links are not work
crew_link_filter() { cfg_resolve treeLink; awk -v links="$CFG_V" -v pre="$1" 'BEGIN { n = split(links, a, "\037"); for (i = 1; i <= n; i++) l[pre a[i]] = 1 } !($0 in l)'; }
# crew_wt_dirty <dir> — git status of a crew worktree, one line per file, its links left out
crew_wt_dirty() { git -C "$1" status --porcelain --untracked-files=all 2>/dev/null | crew_link_filter '?? '; }
# crew_wt_task <dir> — the task id when <dir> is inside one of crew's task worktrees, else empty
crew_wt_task() {
    local top
    top="$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" || return 0
    case "$top" in "$ROOT/$CREW_WT"/*) crew_wt_meta "$top" task ;; esac
    return 0
}
# compose_report <dir> — Docker option D (PLUG-068): what in the project's compose setup stops a
# second copy running beside the first (compose-report.awk). Read-only: one `docker compose config`.
# Silent without a compose file or docker, or when that command fails.
compose_report() {
    local d="$1" f="" cfg p
    if [ -z "${COMPOSE_FILE:-}" ]; then
        for f in compose.yaml compose.yml docker-compose.yaml docker-compose.yml; do [ -f "$d/$f" ] && break; f=""; done
        [ -n "$f" ] || return 0
    fi
    command -v docker >/dev/null 2>&1 || return 0
    cfg="$(cd "$d" && docker compose config --no-interpolate 2>/dev/null)" || return 0
    p="$(printf '%s' "${d##*/}" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9_-')"   # compose's name for the folder
    printf '%s\n' "$cfg" | awk -v proj="$p" -v root="$(cd "$d" && pwd -P)" -f "$CREW_LIB_DIR/compose-report.awk"
    return 0
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

# --- hook payloads ---------------------------------------------------------------------------
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
# Both files are parsed ONCE per process (crew_try_init → cfg_load) into CREW_CFG: TSV lines of
# layer, key, value (array elements joined by \037). Every cfg call after that forks nothing —
# the pre-edit hook reads config several times per edit, so this is what keeps it fast.
#
# cfg_parse <layer> <file> — the top-level keys of a flat JSON object. Strings cannot contain a
# double quote (put such a command in a script); an empty value counts as unset.
cfg_parse() {
    [ -f "$2" ] || return 0
    awk -v layer="$1" 'BEGIN { RS = "\001" }
    {   s = $0
        while (match(s, /"[^"]*"[ \t\r\n]*:[ \t\r\n]*/)) {
            k = substr(s, RSTART + 1); k = substr(k, 1, index(k, "\"") - 1)
            s = substr(s, RSTART + RLENGTH); v = ""; c = substr(s, 1, 1)
            if (c == "\"") { s = substr(s, 2); e = index(s, "\""); v = substr(s, 1, e - 1); s = substr(s, e + 1) }
            else if (c == "[") {
                e = index(s, "]"); a = substr(s, 2, e - 2); s = substr(s, e + 1)
                while (match(a, /"[^"]*"/)) { v = v (v == "" ? "" : "\037") substr(a, RSTART + 1, RLENGTH - 2); a = substr(a, RSTART + RLENGTH) }
            }
            else if (match(s, /^[-0-9A-Za-z.]+/)) { v = substr(s, 1, RLENGTH); s = substr(s, RLENGTH + 1) }
            if (v != "") printf "%s\t%s\t%s\n", layer, k, v
        } }' "$2"
}
cfg_load() { CREW_CFG="$(cfg_parse project "$ROOT/.crew.json"; cfg_parse user "$CREW_USER_CONFIG")"; }

cfg_default() {
    case "$1" in
        committer) echo human-approved ;; push) echo human ;; hookMode) echo deny ;;
        tree) echo shared ;; treeSync) echo merge ;;
        snapshotKeep) echo 20 ;; snapshotMaxKB) echo 1024 ;; slotGraceMin) echo 10 ;; silenceMin) echo 15 ;;
    esac
    return 0
}
cfg_project_only() { case "$1" in crewId|sharedBranch|hotSpots|landCheck|tree|treeSync|taskPush|treeLink|treeSetup|crewRules) return 0 ;; esac; return 1; }
# crew_rules_print — the project's crew-only rules (crewRules: a file in the tree), for a member
# only: printed on join and by SessionStart, so a solo session or a non-member never pays for them
crew_rules_print() {
    local p; p="$(cfg crewRules)"
    [ -n "$p" ] || return 0
    crew_link_ok "$p" || { echo "crew: crewRules $p: not a path inside the tree — skipped"; return 0; }
    [ -f "$ROOT/$p" ] || { echo "crew: crewRules $p is not in the tree — no crew-only rules shown"; return 0; }
    echo "crew: this project's rules while a crew runs ($p):"
    cat "$ROOT/$p"
}
# git_policy_note — empty once the user has said how this project commits and pushes (PLUG-057).
# Until then the defaults hold (nobody commits, nobody pushes) and the coordinator asks the user.
# A value in either layer counts: the user may decide once for the account.
git_policy_note() {
    local k u=""
    for k in committer push; do cfg_resolve "$k"; [ "$CFG_SRC" != default ] || u="$u${u:+, }$k"; done
    [ -z "$u" ] || echo "not decided for this project ($u): nothing is committed or pushed until the user says how — ask them, then record their answer: crew config set committer coordinator|each-session|human-approved, crew config set push committer|human"
    return 0
}
# tree_policy_note — empty once the user has said whether this project works in one shared tree or
# in a worktree per task (PLUG-066). Project layer only: the answer differs per project.
tree_policy_note() {
    [ -n "$(cfg_layer project tree)" ] || echo "not decided for this project: everyone works in the one shared tree until the user says otherwise — ask them once, then record their answer: crew config set tree shared|worktrees"
    return 0
}

# cfg_layer <layer> <key> -> that layer's raw value, ignoring precedence (config.sh's notes use it)
cfg_layer() {
    local l k v
    while IFS=$'\t' read -r l k v; do [ "$l" = "$1" ] && [ "$k" = "$2" ] && { printf '%s\n' "$v"; return 0; }; done <<EOF_CFG
${CREW_CFG:-}
EOF_CFG
    return 0
}
# cfg_resolve <key> — sets CFG_V (raw) and CFG_SRC (project | user | default) without forking
cfg_resolve() {
    local l k v
    CFG_V=""; CFG_SRC=default
    while IFS=$'\t' read -r l k v; do
        [ "$k" = "$1" ] || continue
        if [ "$l" = project ]; then CFG_V="$v"; CFG_SRC=project; return 0; fi
        if [ "$l" = user ] && ! cfg_project_only "$1"; then CFG_V="$v"; CFG_SRC=user; fi
    done <<EOF_CFG
${CREW_CFG:-}
EOF_CFG
    [ "$CFG_SRC" = default ] && CFG_V="$(cfg_default "$1")"
    return 0
}
cfg_src() { cfg_resolve "$1"; echo "$CFG_SRC"; }
cfg() { # <key> -> value; an array prints one element per line
    cfg_resolve "$1"
    case "$CFG_V" in *$'\037'*) printf '%s\n' "$CFG_V" | tr '\037' '\n' ;; *) printf '%s\n' "$CFG_V" ;; esac
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
# reg_live <name> — true while the registry entry's crew still has that session with the same sid
# (a crew ended, a session left or rebound: stale). The one liveness rule for names and slots.
reg_live() {
    local st sid
    st="$(reg_get "$1" state)"; sid="$(reg_get "$1" sid)"
    [ -n "$st" ] && [ -f "$st/sessions/$1" ] && grep -q -x "sid=$sid" "$st/sessions/$1"
}
# reg_other <name> -> "<crew> (<work tree>)" when a LIVE session of ANOTHER crew owns the name
reg_other() {
    local st; st="$(reg_get "$1" state)"
    [ -n "$st" ] && [ "$st" != "$STATE" ] && reg_live "$1" || return 0
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
# One EXIT trap for every crew script: drop a lock held by a dying process, then run the
# script's own cleanup (CREW_ON_EXIT, e.g. `slot run` releasing its slot). Nothing else sets traps.
CREW_HELD_LOCK=""; CREW_ON_EXIT=""
crew_on_exit() { [ -n "$CREW_HELD_LOCK" ] && rm -rf "$CREW_HELD_LOCK"; CREW_HELD_LOCK=""; [ -n "$CREW_ON_EXIT" ] && eval "$CREW_ON_EXIT"; return 0; }
trap crew_on_exit EXIT

# with_lock <name> <cmd...> — mkdir mutex in the crew's state; a lock older than 30 s is a crashed
# holder's. with_lock_at <dir> <name> <cmd...> — the same in another dir (the machine's slots: CREW_HOME).
with_lock() { with_lock_at "$STATE" "$@"; }
with_lock_at() {
    local l="$1/.lock-$2" i=0 age rc; mkdir -p "$1"; shift 2
    until mkdir "$l" 2>/dev/null; do
        i=$((i + 1))
        if [ $((i % 50)) -eq 0 ]; then
            age=$(( $(date +%s) - $(file_mtime "$l" || date +%s) ))
            [ "$age" -gt 30 ] && rm -rf "$l"
        fi
        [ "$i" -gt 600 ] && die "could not take lock $l"
        sleep 0.1
    done
    CREW_HELD_LOCK="$l"
    "$@" && rc=0 || rc=$?
    rm -rf "$l"; CREW_HELD_LOCK=""
    return $rc
}

# replace_file <file> — stdin becomes the file (temp + mv); untouched when identical.
replace_file() {
    local tmp="$1.tmp.$$"
    cat > "$tmp"
    if [ -f "$1" ] && cmp -s "$tmp" "$1"; then rm -f "$tmp"; else mv "$tmp" "$1"; fi
}

# --- sessions: $STATE/sessions/<name> holds sid= role= since= display= ------------------------
# The crew NAME is a slug safe for files and CREW_AS. The DISPLAY name is what peers address the
# session by in SendMessage (it may contain spaces: "Max Coordinator"). A valid name is its own
# slug, so names like PLUG-W1 keep their case.
valid_name() { case "$1" in ''|-*|*[!A-Za-z0-9_.-]*) return 1 ;; esac; return 0; }
name_for() { # <display or name> -> crew name (slug)
    if valid_name "$1"; then printf '%s\n' "$1"; return 0; fi
    printf '%s\n' "$1" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9_.\n-' '-' | sed 's/--*/-/g; s/^-//; s/-$//'
}
sess_get() { # <name> <key>
    [ -f "$STATE/sessions/$1" ] || return 0
    sed -n "s/^$2=//p" "$STATE/sessions/$1" | head -1
}
display_of() { local d; d="$(sess_get "$1" display)"; printf '%s\n' "${d:-$1}"; }
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
crew_line() { # "Max Coordinator coordinator · PLUG-W1 worker"
    local n out=""
    for n in $(sess_names); do out="$out${out:+ · }$(display_of "$n") $(sess_get "$n" role)"; done
    printf '%s\n' "$out"
}
# caller_name — the caller's crew name, empty when unknown: CREW_AS (name or display name) wins,
# else CREW_SID, which SessionStart exports for every later Bash command via CLAUDE_ENV_FILE
caller_name() {
    if [ -n "${CREW_AS:-}" ]; then name_for "$CREW_AS"; return 0; fi
    [ -n "${CREW_SID:-}" ] && name_of_sid "$CREW_SID"
    return 0
}
me() {
    local n; n="$(caller_name)"
    [ -n "$n" ] || die "who is calling? this session has no crew identity — join (crew whoami <name>) or prefix the command with CREW_AS=<your crew name>"
    [ -f "$STATE/sessions/$n" ] || die "'$n' is not in this crew — join with: crew whoami $n [worker|coordinator]"
    printf '%s\n' "$n"
}
prefix_for() { echo "CREW_AS=$1 crew"; }

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
    esc="$(json_esc "$r")"
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
    [ -n "${PAYLOAD+set}" ] || PAYLOAD="$(cat)"   # the hooks read it already (fast.sh)
    CREW_PROJECT_DIR="$(printf '%s' "$PAYLOAD" | payload_str cwd)"
    [ -n "$CREW_PROJECT_DIR" ] || CREW_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
    crew_try_init || return 1
    SID="$(printf '%s' "$PAYLOAD" | payload_str session_id)"
    NAME=""; crew_active && NAME="$(name_of_sid "$SID")"
    return 0
}
