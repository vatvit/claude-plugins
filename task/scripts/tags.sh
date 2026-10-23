#!/usr/bin/env bash
# The tags in use, adding or removing a task's tags, and the candidates a
# backlog review for a tag should look at.
#
# Usage: tags.sh <tasksDir> <prefix> list
#        tags.sh <tasksDir> <prefix> add <id> [--new] <tag>...
#        tags.sh <tasksDir> <prefix> remove <id> <tag>...
#        tags.sh <tasksDir> <prefix> candidates <tag> [--match "kw1,kw2"] [--all]
#
#   list     Every tag in use, closed tasks included, with how many tasks
#            carry it: `<tag><TAB><count>`, sorted by tag. This is what to
#            read before tagging, to reuse a tag and to spot a near-duplicate.
#   add      Add tags to a task. A tag no task uses yet is refused, and
#            named, unless --new is given: --new is passed only when the user
#            asked for that tag or agreed to it.
#   remove   Drop tags from a task; removing the last one drops the line.
#   candidates
#            The tasks to look at when reviewing a backlog for <tag>, one per
#            line, `<id><TAB><reason><TAB><detail>`, by id. Writes nothing.
#              tagged    has the tag already
#              match     a keyword (case ignored) is somewhere in the file;
#                        detail is the first line it is on
#              via epic  its epic has the tag or matched; detail is the epic
#            Open tasks only, unless --all. A shortlist, not a verdict: a task
#            that never uses the words is not in it — read the digest for those.
#
# Tags are lowercased and trimmed. One holding `"`, `\` or a control
# character is refused. Writes go through task_fm_set (atomic, diff-guarded)
# in the canonical form `tags: ["a", "b"]`; reading goes through
# read-tasks.sh, the plugin's one parser.
#
# Output of add/remove: `id=<ID>` and `tags=<canonical list>` (empty when none).
# Exit 1 on an unknown action, an unknown task or a refused tag.
#
# No dependencies — pure bash + awk.
set -euo pipefail

if [ "${1:-}" = "--help" ]; then
    sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; $d'
    exit 0
fi

USAGE="Usage: tags.sh <tasksDir> <prefix> list | add <id> [--new] <tag>... | remove <id> <tag>... | candidates <tag> [--match kw,...] [--all]"
TASKS_DIR="${1:?$USAGE}"
PREFIX="${2:?$USAGE}"
ACTION="${3:?$USAGE}"
shift 3

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

# tagsof(<canonical>, <arr>) -> n: splits read-tasks.sh's `["a", "b"]`.
# Prepended to every awk program here that reads a tags value.
TAGSOF='function tagsof(s, arr) {
    if (s == "") return 0
    sub(/^\["/, "", s); sub(/"\]$/, "", s)
    return split(s, arr, /", "/)
}'

# canonical tags of every task, one tag per line (`<id><TAB><tag>`)
all_tags() {
    "$SCRIPT_DIR/read-tasks.sh" "$TASKS_DIR" "$PREFIX" --all --records \
      | awk -F'\t' "$TAGSOF"'
        $2 == "tags" { n = tagsof($3, t); for (i = 1; i <= n; i++) print $1 "\t" t[i] }'
}

# norm_tag <tag> -> the tag trimmed and lowercased; exit 1 on one that cannot
# be a tag. A tag is data: checked, lowercased, never evaluated.
norm_tag() {
    case "$1" in
        *'"'*|*'\'*)  echo "ERROR: a tag cannot contain \" or \\: $1" >&2; exit 1 ;;
        *[[:cntrl:]]*) echo "ERROR: a tag cannot contain a control character" >&2; exit 1 ;;
    esac
    printf '%s\n' "$1" | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); print tolower($0) }'
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

case "$ACTION" in
    list)
        all_tags | awk -F'\t' '{ c[$2]++ } END { for (t in c) print t "\t" c[t] }' | sort
        exit 0 ;;
    candidates)
        TAG=$(norm_tag "${1:?$USAGE}") || exit 1
        shift
        [ -n "$TAG" ] || { echo "ERROR: empty tag" >&2; exit 1; }
        KW=""; ALL=0
        while [ $# -gt 0 ]; do
            case "$1" in
                --match)   KW="${2:?--match needs keywords}"; shift 2 ;;
                --match=*) KW="${1#--match=}"; shift ;;
                --all)     ALL=1; shift ;;
                *) echo "ERROR: unrecognised argument: $1" >&2; exit 1 ;;
            esac
        done
        "$SCRIPT_DIR/read-tasks.sh" "$TASKS_DIR" "$PREFIX" --all --records > "$WORK/rec"
        declare -a files
        files=()
        while IFS= read -r id; do
            [ -n "$id" ] && files[${#files[@]}]="$TASKS_DIR/$id.md"
        done < <(awk -F'\t' '$2 == "id" { print $1 }' "$WORK/rec")
        [ ${#files[@]} -gt 0 ] || exit 0
        CAND_TAG="$TAG" CAND_KW="$KW" CAND_ALL="$ALL" awk -F'\t' "$TAGSOF"'
        function closed(id,   s) { s = V[id, "status"]; return s == "completed" || s == "rejected" }
        function has(id,   n, t, i) { n = tagsof(V[id, "tags"], t); for (i = 1; i <= n; i++) if (t[i] == tag) return 1; return 0 }
        BEGIN {
            tag = ENVIRON["CAND_TAG"]; all = (ENVIRON["CAND_ALL"] == "1")
            nr = split(tolower(ENVIRON["CAND_KW"]), raw, ",")
            for (i = 1; i <= nr; i++) { k = raw[i]; gsub(/^[ \t]+|[ \t]+$/, "", k); if (k != "") kw[++nkw] = k }
        }
        NR == FNR {
            if ($2 == "id") order[++n] = $1
            else V[$1, $2] = $3
            next
        }
        FNR == 1 { id = FILENAME; sub(/.*\//, "", id); sub(/\.md$/, "", id) }
        (id in hit) || nkw == 0 || /^tags:/ { next }
        {
            low = tolower($0)
            for (i = 1; i <= nkw; i++) if (index(low, kw[i]) > 0) {
                line = $0; gsub(/[ \t]+/, " ", line); sub(/^ /, "", line)
                hit[id] = line; break
            }
        }
        END {
            for (i = 1; i <= n; i++) {
                id = order[i]
                if (V[id, "type"] == "epic" && V[id, "epic-name"] != "" && (has(id) || (id in hit)))
                    viaepic[V[id, "epic-name"]] = id
            }
            for (i = 1; i <= n; i++) {
                id = order[i]
                if (closed(id) && !all) continue
                if (has(id))                       print id "\ttagged\t"
                else if (id in hit)                print id "\tmatch\t" hit[id]
                else if (V[id, "epic"] in viaepic) print id "\tvia epic\t" viaepic[V[id, "epic"]]
            }
        }' "$WORK/rec" "${files[@]}"
        exit 0 ;;
    add|remove) ;;
    *) echo "ERROR: unknown action: $ACTION (list, add, remove, candidates)" >&2; exit 1 ;;
esac

RAW_ID="${1:?$USAGE}"; shift
NEW=0
if [ "$ACTION" = "add" ] && [ "${1:-}" = "--new" ]; then NEW=1; shift; fi
[ $# -gt 0 ] || { echo "$USAGE" >&2; exit 1; }

meta=$("$SCRIPT_DIR/resolve-task.sh" "$TASKS_DIR" "$PREFIX" "$RAW_ID") || exit 1
ID=$(printf '%s\n' "$meta"   | grep '^id='   | head -1 | cut -d= -f2- || true)
FILE=$(printf '%s\n' "$meta" | grep '^file=' | head -1 | cut -d= -f2- || true)
CUR=$(printf '%s\n' "$meta"  | grep '^tags=' | head -1 | cut -d= -f2- || true)

# The requested tags, normalised, one per line.
: > "$WORK/want"
for t in "$@"; do
    norm_tag "$t" >> "$WORK/want" || exit 1
done

if [ "$ACTION" = "add" ] && [ "$NEW" -eq 0 ]; then
    all_tags | cut -f2 > "$WORK/known"
    unknown=$(awk 'NR == FNR { k[$0] = 1; next } $0 != "" && !($0 in k)' "$WORK/known" "$WORK/want" | sort -u)
    if [ -n "$unknown" ]; then
        echo "ERROR: not a tag in use yet (add --new only with the user's OK):" >&2
        printf '%s\n' "$unknown" | sed 's/^/  /' >&2
        exit 1
    fi
fi

# Current tags, then the change, in order; the result in canonical form.
printf '%s\n' "$CUR" > "$WORK/cur"
NEWLIST=$(awk -v act="$ACTION" "$TAGSOF"'
    NR == FNR {
        n = tagsof($0, t)
        for (i = 1; i <= n; i++) { order[++m] = t[i]; have[t[i]] = 1 }
        next
    }
    $0 == "" { next }
    act == "add"    && !($0 in have) { order[++m] = $0; have[$0] = 1 }
    act == "remove" { delete have[$0] }
    END {
        out = ""; c = 0
        for (i = 1; i <= m; i++) if (order[i] in have) out = out (c++ ? ", " : "") "\"" order[i] "\""
        print c ? "[" out "]" : ""
    }' "$WORK/cur" "$WORK/want")

task_fm_set "$FILE" tags "$NEWLIST"
echo "id=$ID"
echo "tags=$NEWLIST"
