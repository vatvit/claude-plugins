#!/usr/bin/env bash
# Read task frontmatter for a whole tasks directory.
#
# Usage: read-tasks.sh <tasksDir> <prefix> [options]
#   --all              Include every task, whatever its status
#   --status=X,Y       Include only tasks whose status is one of X,Y
#   --id=<full-id>     Read one task file only (PREFIX-NNN)
#   --records          Emit TSV records instead of JSON
#   --excerpt=N        Add an `excerpt` field: the start of the task's summary,
#                      about N characters, cut on a word, `…` when cut
#   --help             This text
#   Default: excludes completed and rejected tasks
#
# Output, JSON (default):
#   [{"id":"TASK-001","title":"...","status":"...",...},...]
#
# Output, --records — one line per frontmatter field, tab separated:
#   TASK-001<TAB>id<TAB>TASK-001
#   TASK-001<TAB>title<TAB>Implement auth
#   TASK-001<TAB>status<TAB>proposed
# Every task gets an `id` record first, so a task with empty frontmatter is
# still visible to the consumer. Field order is the order in the file.
#
# `tags` is a list, decoded here and nowhere else: `["a", "b, c"]` (quoted, a
# comma inside quotes kept) or leniently `[a, b]`; each tag trimmed and
# lowercased, blanks and repeats dropped, an empty list the same as no field.
# Records carry it in one canonical form, `["a", "b, c"]`; a tag cannot hold a
# `"`, so consumers split that on `", "`. JSON mode emits a JSON array.
#
# The excerpt is taken from `## Description`; without one, from the first
# section that is not `## Workflow` (an epic's Goal, a Problem); without
# sections, from the text after the frontmatter. Tables, code fences and
# headings are left out, whitespace is collapsed to single spaces.
#
# This is the plugin's only bulk frontmatter reader: list-tasks.sh,
# resolve-task.sh, resolve-epic.sh and update-epic-index.sh all go through it
# rather than carrying a parser each.
#
# No dependencies — pure bash + awk.
set -euo pipefail

if [ "${1:-}" = "--help" ]; then
    sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; $d'
    exit 0
fi

TASKS_DIR="${1:?Usage: read-tasks.sh <tasksDir> <prefix> [--all|--status=X,Y] [--id=ID] [--records]}"
PREFIX="${2:?Usage: read-tasks.sh <tasksDir> <prefix> [--all|--status=X,Y] [--id=ID] [--records]}"
shift 2

FILTER_MODE="default"   # default | all | custom
STATUSES=""
MODE="json"
ONLY_ID=""
EXCERPT=0

for arg in "$@"; do
    case "$arg" in
        --all)      FILTER_MODE="all" ;;
        --status=*) FILTER_MODE="custom"; STATUSES="${arg#--status=}" ;;
        --records)  MODE="records" ;;
        --id=*)     ONLY_ID="${arg#--id=}" ;;
        --excerpt=*) EXCERPT="${arg#--excerpt=}"
                     case "$EXCERPT" in ''|*[!0-9]*) echo "ERROR: --excerpt needs a number" >&2; exit 1 ;; esac ;;
    esac
done

# Collect the files to read. A missing file or an empty directory is not an
# error: an empty list is a legitimate answer (empty JSON array, no records).
# An indexed array, not xargs: xargs may split a long list across several awk
# runs, which would emit several JSON arrays instead of one.
declare -a files
files=()
if [ -n "$ONLY_ID" ]; then
    [ -f "$TASKS_DIR/$ONLY_ID.md" ] && files=("$TASKS_DIR/$ONLY_ID.md")
else
    for f in "$TASKS_DIR"/"$PREFIX"-*.md; do
        [ -f "$f" ] || continue
        files[${#files[@]}]="$f"
    done
fi

if [ ${#files[@]} -eq 0 ]; then
    [ "$MODE" = "json" ] && printf '[]\n'
    exit 0
fi

awk -v mode="$MODE" -v filtermode="$FILTER_MODE" -v statuses="$STATUSES" -v exn="$EXCERPT" '
# cap <text> -> at most exn characters, cut after a whole word, `…` when cut
function cap(t,   n, w, i, out) {
    if (length(t) <= exn) return t
    n = split(t, w, " "); out = ""
    for (i = 1; i <= n; i++) {
        if (length(out) + length(w[i]) + (out == "" ? 0 : 1) > exn) break
        out = out (out == "" ? "" : " ") w[i]
    }
    return out "…"
}
# body: collect the text the excerpt may come from, never more than it needs
function body(   h) {
    if ($0 ~ /^```/) { infence = !infence; return }
    if (infence) return
    if ($0 ~ /^## /) {
        h = $0; sub(/^## +/, "", h); sub(/[ \t]+$/, "", h)
        sec = (h == "Description") ? "desc" : (h != "Workflow" && !firstseen ? "first" : "other")
        if (sec == "first") firstseen = 1
        return
    }
    if ($0 ~ /^#/ || $0 ~ /^[ \t]*\|/ || $0 ~ /^[ \t]*$/) return
    if (sec == "desc")       { if (length(xd) < 2 * exn) xd = xd " " $0 }
    else if (sec == "first") { if (length(xf) < 2 * exn) xf = xf " " $0 }
    else if (sec == "")      { if (length(xp) < 2 * exn) xp = xp " " $0 }
}
function excerpt(   t) {
    t = (xd != "") ? xd : ((xf != "") ? xf : xp)
    gsub(/[ \t]+/, " ", t); sub(/^ /, "", t); sub(/ $/, "", t)
    return cap(t)
}
# decode_tags <raw> -> the canonical `["a", "b"]`, or "" for no tags.
function decode_tags(raw,   s, i, c, e, q, n, out, seen, k) {
    s = raw
    sub(/^\[/, "", s); sub(/\][ \t]*$/, "", s)
    n = 0; out = ""; e = ""; q = 0
    for (i = 1; i <= length(s) + 1; i++) {
        c = (i <= length(s)) ? substr(s, i, 1) : ","
        if (c == "\"") { q = !q; continue }
        if (c != "," || q) { e = e c; continue }
        gsub(/\\/, "", e); gsub(/^[ \t]+|[ \t]+$/, "", e); e = tolower(e)
        if (e != "" && !((k = "|" e) in seen)) {
            seen[k] = 1
            out = out (n++ ? ", " : "") "\"" e "\""
        }
        e = ""
    }
    return n ? "[" out "]" : ""
}
function emit(   i, v, t) {
    if (cur == "") return
    if (filtermode == "all")         ok = 1
    else if (filtermode == "custom") ok = (st in allow)
    else                             ok = (st != "completed" && st != "rejected")
    if (!ok) return
    if (exn > 0 && (t = excerpt()) != "") { nk++; kk[nk] = "excerpt"; vv[nk] = t }
    if (mode == "records") {
        print cur "\t" "id" "\t" cur
        for (i = 1; i <= nk; i++) print cur "\t" kk[i] "\t" vv[i]
    } else {
        printf "%s{\"id\":\"%s\"", (nout ? "," : ""), cur
        for (i = 1; i <= nk; i++) {
            v = vv[i]
            if (kk[i] == "tags") { gsub(/", "/, "\",\"", v); printf ",\"tags\":%s", v; continue }
            gsub(/\\/, "\\\\", v); gsub(/"/, "\\\"", v)
            printf ",\"%s\":\"%s\"", kk[i], v
        }
        printf "}"
        nout++
    }
}
BEGIN {
    if (statuses != "") { n = split(statuses, sa, ","); for (i = 1; i <= n; i++) allow[sa[i]] = 1 }
    if (mode != "records") printf "["
}
FNR == 1 {
    emit()
    nk = 0; st = ""; infm = 0; fmdone = 0
    sec = ""; firstseen = 0; infence = 0; xd = ""; xf = ""; xp = ""
    cur = FILENAME; sub(/.*\//, "", cur); sub(/\.md$/, "", cur)
}
fmdone { if (exn > 0) body(); next }
/^---[ \t]*$/ { if (infm) { fmdone = 1 } else { infm = 1 } next }
infm && /:/ {
    key = $0; val = $0
    sub(/:.*/, "", key)
    sub(/^[^:]*:[ \t]*/, "", val)
    gsub(/^[ \t]+|[ \t]+$/, "", key)
    gsub(/^[ \t]+|[ \t]+$/, "", val)
    if (length(val) > 1 && substr(val, 1, 1) == "\"" && substr(val, length(val), 1) == "\"")
        val = substr(val, 2, length(val) - 2)
    if (key == "tags") val = decode_tags(val)
    if (key != "" && val != "") {
        nk++; kk[nk] = key; vv[nk] = val
        if (key == "status") st = val
    }
}
FNR > 25 { fmdone = 1 }
END {
    emit()
    if (mode != "records") printf "]\n"
}
' "${files[@]}"
