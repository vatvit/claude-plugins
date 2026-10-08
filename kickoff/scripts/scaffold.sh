#!/usr/bin/env bash
# scaffold.sh [project-root] — write the project setup from the answers (questionnaire R and K).
#
#   docs/ skeleton     K1: an _index.md per folder, with the frontmatter docs-manager expects.
#                      docs-manager, when installed, fills in their AUTO-INDEX blocks.
#   CLAUDE.md          instructions only: git, the entry point, crew, tasks, approvals, exceptions
#   task config        R6–R8: .task-config.json in the repo, or, for tasks outside the repo, an
#                      entry in the task skill's per-account registry, plus the task workflow
#
# One line per file: created | exists | unchanged | updated | refused <path>. Files that only seed a
# folder are written once and then left alone. CLAUDE.md is regenerated, but a version edited
# since is refused (exit 3) unless --force. Refuses to run while questions are still open.
#
#   --diff    write nothing: report what would happen, and show how CLAUDE.md would change (diff -u)
#   --force   replace a CLAUDE.md that was edited since (after the user has seen --diff)
set -euo pipefail
. "$(dirname "$0")/lib.sh"

root="" dry=0 force=0
for a in "$@"; do
    case "$a" in --diff) dry=1 ;; --force) force=1 ;; -*) echo "scaffold.sh: unknown option $a" >&2; exit 2 ;; *) root="$a" ;; esac
done
root="$(project_root "$root")"
[ -f "$(answers_file "$root")" ] || { echo "scaffold.sh: no answers yet" >&2; exit 1; }
open="$(bash "$KICKOFF_SCRIPTS/plan.sh" "$root" --next)"
[ -z "$open" ] || { echo "scaffold.sh: questions are still open — see plan.sh --next" >&2; exit 1; }

{ read -r A1; read -r A3; read -r C3; read -r K1; read -r R6; read -r R7; read -r R8; } \
    < <(kickoff_awk get.awk "$root" -v ids="A1 A3 C3 K1 R6 R7 R8")
name="${A1:-$(basename "$root")}"
slug="$(printf '%s' "$name" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9._-' '-')"
rc=0

report() { printf '%-9s %s\n' "$1" "${2#"$root"/}"; }

# once <dest> <tmp> — seed a file that is the user's from then on.
once() {
    if [ -e "$1" ]; then rm -f "$2"; report exists "$1"; return; fi
    if [ "$dry" = 1 ]; then rm -f "$2"; report would-create "$1"; return; fi
    mkdir -p "$(dirname "$1")"; mv "$2" "$1"; report created "$1"
}
# guarded <dest> <tmp> — a generated file: rewritten when unchanged since, refused when edited.
guarded() {
    local r
    if [ "$dry" = 1 ]; then
        if [ ! -f "$1" ]; then r=would-create; elif cmp -s "$1" "$2"; then r=unchanged
        else r=differs; diff -u "$1" "$2" | sed "s|$2|(proposed)|" || true; fi
        rm -f "$2"; report "$r" "$1"; return
    fi
    r="$(write_if_changed "$1" "$2" "$force")" || rc=3; report "$r" "$1"
}
index_md() { # index_md <folder> <title> <description>
    local t; t="$(mktemp)"
    printf -- '---\ntitle: %s\ndescription: %s\n---\n\n# %s\n' "$2" "$3" "$2" > "$t"
    once "$root/docs${1:+/$1}/_index.md" "$t"
}

# --- docs/ skeleton (K1) ----------------------------------------------------------------------
if [ -n "$K1" ]; then
    index_md "" "$name docs" "Everything known about $name, starting from the charter"
    index_md project "Project" "What $name is and why: the charter, its decisions and open questions"
    case "$K1" in
        Minimal*) ;;
        *)  index_md architecture "Architecture" "How $name is built: its shape, its modules, and the decisions behind them"
            index_md dev "Development" "How to run, build and test $name, all in Docker"
            case "$C3" in Client*) index_md external "External" "Source material from outside the project, kept as received and catalogued" ;; esac
            case "$A3" in Game*) index_md design "Design" "How the game plays and looks" ;; esac ;;
    esac
fi

# --- task config and workflow (R6–R8) ---------------------------------------------------------
tasks_where=""
if [ -n "$R6" ]; then
    [ -n "$R7" ] || { echo "scaffold.sh: R6 is answered but the task prefix R7 is not" >&2; exit 1; }
    case "$R6" in
        Outside*)
            # Per account, like the task skill itself: $CLAUDE_CONFIG_DIR first, then ~/.claude.
            G="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/project-tasks"; tdir="$G/$slug"; reg="$G/config.json"
            # Not a path: a client's repo must not carry the user's home directory (identity rule).
            tasks_where="outside the repo (the task skill finds them through its registry)"
            [ "$dry" = 1 ] || mkdir -p "$G"
            if [ -f "$reg" ] && grep -qF "\"$root\":" "$reg"; then report exists "$reg"
            elif [ "$dry" = 1 ]; then report would-update "$reg"
            else
                t="$(mktemp)"
                in=/dev/null; [ -f "$reg" ] && in="$reg"
                KO_ROOT="$root" KO_DIR="$tdir" KO_PREFIX="$R7" \
                    awk -f "$KICKOFF_SCRIPTS/json.awk" -f "$KICKOFF_SCRIPTS/registry-insert.awk" "$in" > "$t" || {
                    rm -f "$t"; report refused "$reg"; rc=3; t=""; }
                if [ -n "$t" ]; then [ -f "$reg" ] && r=updated || r=created; mv "$t" "$reg"; report "$r" "$reg"; fi
            fi ;;
        *)
            tdir="$root/tasks"; tasks_where='in `tasks/`'
            t="$(mktemp)"; printf '{\n  "tasksDir": "tasks",\n  "prefix": "%s",\n  "nextId": 1\n}\n' "$R7" > "$t"
            once "$root/.task-config.json" "$t" ;;
    esac
    case "$R8" in
        One*|Minimal*) wf=workflow-minimal.md ;;
        *) wf=workflow-profiles.md ;;
    esac
    t="$(mktemp)"; cp "$KICKOFF_SCRIPTS/../templates/$wf" "$t"; once "$tdir/_workflow/WORKFLOW.md" "$t"
fi

# --- CLAUDE.md ----------------------------------------------------------------------------------
t="$(mktemp)"; kickoff_awk claude.awk "$root" -v tasks="$tasks_where" > "$t"; guarded "$root/CLAUDE.md" "$t"

echo "next: create the first tasks — agree the charter · architecture overview · dev harness with the first vertical slice and its tests"
exit $rc
