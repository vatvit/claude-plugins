#!/usr/bin/env bash
# Shared helpers for the task plugin's scripts. Source it, don't execute it.

# task_global_roots -> global (cross-project) storage roots, one per line,
# most specific first. Claude Code sets CLAUDE_CONFIG_DIR when it runs under a
# non-default account (e.g. ~/.claude-work); ~/.claude stays as the fallback so
# a registry created there keeps resolving from every account.
# HOME may be unset (a sandbox, a bare container): then there is no ~/.claude root,
# and the project's own .task-config.json is all there is (root CLAUDE.md, Without HOME).
task_global_roots() {
    local home="${HOME:-}"
    if [ -n "${CLAUDE_CONFIG_DIR:-}" ] && [ "${CLAUDE_CONFIG_DIR%/}" != "$home/.claude" ]; then
        printf '%s/project-tasks\n' "${CLAUDE_CONFIG_DIR%/}"
    fi
    [ -z "$home" ] || printf '%s/.claude/project-tasks\n' "$home"
    return 0
}

# task_global_file <relpath> -> the first <root>/<relpath> that exists, or
# nothing. An absent file is normal, so this always returns 0.
task_global_file() {
    local root
    while IFS= read -r root; do
        if [ -f "$root/$1" ]; then
            printf '%s\n' "$root/$1"
            return 0
        fi
    done <<EOR
$(task_global_roots)
EOR
    return 0
}

# task_project_dir <dir> -> the project directory <dir> stands for. Inside a
# linked git worktree that is the same place in the main tree: every worktree
# checks out its own copy of the config and the tasks folder, and resolving
# from that copy gave each worktree its own id lock and id sequence. Anywhere
# else (no git, the main tree, a bare repo's worktree) it is <dir> unchanged.
task_project_dir() {
    local dir="$1" out gd cd prefix main
    out=$(cd "$dir" 2>/dev/null && git rev-parse --git-dir --git-common-dir --show-prefix 2>/dev/null) \
        || { printf '%s\n' "$dir"; return 0; }
    gd=$(printf '%s\n' "$out" | sed -n 1p)
    cd=$(printf '%s\n' "$out" | sed -n 2p)
    prefix=$(printf '%s\n' "$out" | sed -n 3p)
    gd=$(cd "$dir" && cd "$gd" 2>/dev/null && pwd -P) || { printf '%s\n' "$dir"; return 0; }
    cd=$(cd "$dir" && cd "$cd" 2>/dev/null && pwd -P) || { printf '%s\n' "$dir"; return 0; }
    # The main tree, or a bare repo's worktree: nothing to map to.
    if [ "$gd" = "$cd" ] || [ "${cd##*/}" != ".git" ]; then
        printf '%s\n' "$dir"; return 0
    fi
    main="${cd%/.git}"
    [ -d "$main" ] || { printf '%s\n' "$dir"; return 0; }
    prefix="${prefix%/}"
    if [ -n "$prefix" ]; then printf '%s/%s\n' "$main" "$prefix"; else printf '%s\n' "$main"; fi
    return 0
}

# task_canonical_id <prefix> <raw> -> the full id a number or full id stands
# for: `4`, `004` and `PREFIX-4` all give PREFIX-004; another prefix's full id
# is kept as given. Anything else (an epic-name, junk) prints nothing and
# returns 1, so the caller decides what it means.
task_canonical_id() {
    local p="$1" raw="$2" num
    case "$raw" in
        "$p"-*) num="${raw#"$p"-}" ;;
        *) num="$raw" ;;
    esac
    if printf '%s' "$num" | grep -qE '^[0-9]+$'; then
        num=$(printf '%s' "$num" | sed 's/^0*//')
        printf '%s-%03d\n' "$p" "${num:-0}"
    elif printf '%s' "$raw" | grep -qE '^[A-Z]+-[0-9]+$'; then
        printf '%s\n' "$raw"
    else
        return 1
    fi
}

# task_fm_set <file> <key> <value> [--require] -> set `key: value` in the
# frontmatter. An existing line is replaced, an absent key is added before the
# closing `---`, an empty value removes the line. With --require an absent key
# is an error (return 3) instead. The value goes through ENVIRON, not `awk -v`,
# which would read its backslashes as escapes. Written via a temp file and mv,
# skipped when nothing changed, so an unchanged file keeps its mtime.
task_fm_set() {
    local f="$1" k="$2" v="$3" req="${4:-}" tmp="$1.$$"
    FM_KEY="$k" FM_VAL="$v" FM_REQ="$req" awk '
    BEGIN { k = ENVIRON["FM_KEY"]; v = ENVIRON["FM_VAL"]; req = (ENVIRON["FM_REQ"] == "--require") }
    NR == 1 && /^---[ \t]*$/ { infm = 1; print; next }
    infm && /^---[ \t]*$/ {
        if (!done && v != "" && !req) { print k ": " v; done = 1 }
        infm = 0; print; next
    }
    infm && index($0, k ":") == 1 {
        if (v != "") print k ": " v
        done = 1; next
    }
    { print }
    END { if (req && !done) exit 3 }
    ' "$f" > "$tmp" || { rm -f "$tmp"; return 3; }
    if cmp -s "$tmp" "$f"; then rm -f "$tmp"; else mv "$tmp" "$f"; fi
    return 0
}

# task_highest_id <tasksDir> <prefix> -> the highest number among <PREFIX>-NNN.md
# files in tasksDir, 0 when there are none. The self-heal floor of allocation.
task_highest_id() {
    local f n max=0
    for f in "$1/$2-"*.md; do
        [ -e "$f" ] || continue
        n=$(basename "$f" .md); n="${n#"$2"-}"
        case "$n" in ''|*[!0-9]*) continue ;; esac
        n=$((10#$n))
        [ "$n" -gt "$max" ] && max=$n
    done
    printf '%s\n' "$max"
}

# The one JSON reader for the config files, as awk functions. Both files are flat
# objects of scalars: .task-config.json itself, and each project's entry in a global
# registry. Any layout is read: one line or many, CRLF, tabs, a value holding , or :
# (PLUG-131: a one-line config used to give tasksDir=<dir>/.tasks","prefix":...).
#   json_scope(s, proj)  -> 1 and JS/JL = where the pairs are in s: all of s when proj
#                           is "", else the inside of the object under key "proj"; 0 if absent
#   json_pairs(t)        -> n; K[i] key, V[i] raw value, VS[i]/VL[i] its place in t
#   json_decode(v)       -> a raw value as text: quotes off, \" \\ \/ decoded
#   json_quote(s)        -> s as a JSON string
# Escapes go through a character loop, never gsub: busybox reads a backslash in a gsub
# replacement differently (root CLAUDE.md, awk portability traps).
_TASK_JSON_AWK='
function json_scope(s, proj,   off, i, rest, j) {
    if (proj == "") { JS = 1; JL = length(s); return 1 }
    off = 0
    while ((i = index(substr(s, off + 1), "\"" proj "\"")) > 0) {
        off += i + length(proj) + 1
        rest = substr(s, off + 1)
        if (match(rest, /^[ \t\r\n]*:[ \t\r\n]*[{]/)) {
            JS = off + RLENGTH + 1
            j = index(substr(s, JS), "}"); if (!j) return 0
            JL = j - 1; return 1
        }
    }
    return 0
}
function json_pairs(t,   n, off, pair, k, v) {
    n = 0; off = 0
    while (match(substr(t, off + 1), /"[^"]*"[ \t\r\n]*:[ \t\r\n]*("([^"\\]|\\.)*"|[^,}" \t\r\n]+)/)) {
        pair = substr(t, off + RSTART, RLENGTH)
        k = substr(pair, 2); k = substr(k, 1, index(k, "\"") - 1)
        v = pair; sub(/^"[^"]*"[ \t\r\n]*:[ \t\r\n]*/, "", v)
        n++; K[n] = k; V[n] = v; VL[n] = length(v)
        VS[n] = off + RSTART + RLENGTH - length(v)
        off += RSTART + RLENGTH - 1
    }
    return n
}
function json_decode(v,   out, i, c) {
    if (substr(v, 1, 1) != "\"") return v
    v = substr(v, 2, length(v) - 2); out = ""
    for (i = 1; i <= length(v); i++) {
        c = substr(v, i, 1)
        if (c == "\\" && i < length(v) && index("\"\\/", substr(v, i + 1, 1))) { i++; c = substr(v, i, 1) }
        out = out c
    }
    return out
}
function json_quote(s,   out, i, c) {
    out = ""
    for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "\\" || c == "\"") out = out "\\"
        out = out c
    }
    return "\"" out "\""
}
'

# task_config_read <file> [<project-dir>] -> key=value lines (decoded, empty values
# skipped) of the flat config: the whole file, or the project's entry in a global
# registry. Exit 1 when the registry does not list the project.
task_config_read() {
    awk -v proj="${2:-}" "$_TASK_JSON_AWK"'
    { S = S $0 "\n" }
    END {
        if (!json_scope(S, proj)) exit 1
        n = json_pairs(substr(S, JS, JL))
        for (i = 1; i <= n; i++) { v = json_decode(V[i]); if (K[i] != "" && v != "") print K[i] "=" v }
    }' "$1"
}

# task_config_set_num <file> <key> <digits> [<project-dir>] -> replace that key's
# number in place, in the whole file or in the project's registry entry; every other
# byte (the file's layout) is kept. A key that is absent, or not a number, is left
# alone. Diff-guarded, tmp + mv. The one nextId write-back (allocate-id.sh).
task_config_set_num() {
    local f="$1" tmp rc
    case "$3" in ''|*[!0-9]*) return 2 ;; esac
    tmp="$f.tmp.$$"
    awk -v key="$2" -v num="$3" -v proj="${4:-}" "$_TASK_JSON_AWK"'
    { S = S $0 "\n" }
    END {
        if (json_scope(S, proj)) {
            n = json_pairs(substr(S, JS, JL))
            for (i = 1; i <= n; i++) if (K[i] == key && V[i] ~ /^[0-9]+$/) {
                p = JS + VS[i] - 1
                S = substr(S, 1, p - 1) num substr(S, p + VL[i]); break
            }
        }
        printf "%s", S
    }' "$f" > "$tmp"; rc=$?
    [ "$rc" -eq 0 ] && [ -s "$tmp" ] || { rm -f "$tmp"; return 1; }
    if cmp -s "$tmp" "$f"; then rm -f "$tmp"; else mv "$tmp" "$f"; fi
    return 0
}

# task_config_edit <file> [set <key> <string> | num <key> <digits> | del <key>]... -> rewrite a
# flat JSON config (the project's .task-config.json) with keys set or removed,
# keeping the order and the values of every other key. Reads any layout; writes one
# key per line. `set` writes a quoted string, `num` a bare integer (refused unless all
# digits); untouched values stay as they were. Diff-guarded, tmp + mv.
task_config_edit() {
    local f="$1" ed tmp rc; shift
    ed=$(mktemp) || return 1
    while [ $# -gt 0 ]; do
        case "$1" in
            set) [ $# -ge 3 ] || { rm -f "$ed"; return 2; }
                 printf 'set\t%s\t%s\n' "$2" "$3" >> "$ed"; shift 3 ;;
            num) [ $# -ge 3 ] || { rm -f "$ed"; return 2; }
                 case "$3" in ''|*[!0-9]*) rm -f "$ed"; return 2 ;; esac
                 printf 'num\t%s\t%s\n' "$2" "$3" >> "$ed"; shift 3 ;;
            del) [ $# -ge 2 ] || { rm -f "$ed"; return 2; }
                 printf 'del\t%s\n' "$2" >> "$ed"; shift 2 ;;
            *) rm -f "$ed"; return 2 ;;
        esac
    done
    tmp="$f.tmp.$$"
    awk -v edits="$ed" "$_TASK_JSON_AWK"'
    { S = S $0 "\n" }
    END {
        n = 0
        m = json_pairs(S)
        for (i = 1; i <= m; i++) { if (!(K[i] in val)) { n++; key[n] = K[i] }; val[K[i]] = V[i] }
        while ((getline line < edits) > 0) {
            split(line, e, "\t")
            if (e[1] == "del") { if (e[2] in val) delete val[e[2]] }
            else {
                if (!(e[2] in val)) { n++; key[n] = e[2] }
                val[e[2]] = (e[1] == "num" ? e[3] : json_quote(e[3]))
            }
        }
        print "{"
        m = 0
        for (i = 1; i <= n; i++) if (key[i] in val) { m++; out[m] = key[i] }
        for (i = 1; i <= m; i++) printf "  \"%s\": %s%s\n", out[i], val[out[i]], (i < m ? "," : "")
        print "}"
    }' "$f" > "$tmp"; rc=$?
    rm -f "$ed"
    [ "$rc" -eq 0 ] && [ -s "$tmp" ] || { rm -f "$tmp"; return 1; }
    if cmp -s "$tmp" "$f"; then rm -f "$tmp"; else mv "$tmp" "$f"; fi
    return 0
}

# The one matcher for task ids in text, at id boundaries only: a word character
# before or after a hit means it is part of something else, so X-100 never matches
# inside X-1000 or AX-100. Plain string search (index), no regex built from the id.
#   _task_id_awk replace <file> <OLD> <NEW>  -> the file with OLD replaced, on stdout
#   _task_id_awk lines   <file> <OLD>        -> the numbers of the lines mentioning OLD
_task_id_awk() {
    ID_MODE="$1" ID_OLD="$3" ID_NEW="${4:-}" awk '
    function word(c) { return c ~ /[A-Za-z0-9_]/ }
    BEGIN { m = ENVIRON["ID_MODE"]; o = ENVIRON["ID_OLD"]; n = ENVIRON["ID_NEW"]; lo = length(o) }
    {
        out = ""; rest = $0; hit = 0
        while ((i = index(rest, o)) > 0) {
            before = (i > 1) ? substr(rest, i - 1, 1) : substr(out, length(out), 1)
            if (!word(before) && !word(substr(rest, i + lo, 1))) { hit = 1; out = out substr(rest, 1, i - 1) n }
            else out = out substr(rest, 1, i - 1 + lo)
            rest = substr(rest, i + lo)
        }
        if (m == "replace") print out rest
        else if (hit) print FNR
    }' "$2"
}

# task_id_replace <file> <OLD> <NEW> -> replace the mentions of task id OLD with
# NEW (boundaries as above). Diff-guarded, tmp + mv.
task_id_replace() {
    local tmp="$1.tmp.$$"
    _task_id_awk replace "$1" "$2" "$3" > "$tmp" || { rm -f "$tmp"; return 1; }
    if cmp -s "$tmp" "$1"; then rm -f "$tmp"; else mv "$tmp" "$1"; fi
    return 0
}

# task_id_lines <file> <ID> -> the line numbers mentioning task id ID.
task_id_lines() { _task_id_awk lines "$1" "$2"; }
