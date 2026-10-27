#!/usr/bin/env bash
# scaffold.sh [project-root] — write the project setup from the answers.
#
#   quality doc        §F: docs/project/quality.md (quality.awk), when §F was answered
#   CLAUDE.md          instructions only: git, identity, dev environment, entry point, crew, tasks,
#                      quality, approvals, rules that differ here
#   task config        R7–R10, when the task plugin is installed: .task-config.json in the repo, or,
#                      for tasks outside the repo, an entry in the task skill's per-account registry,
#                      plus the task workflow with the practices R10 kept
#
# The rest of docs/ is not kickoff's: docs-manager sets it up, when installed.
#
# One line per file: created | exists | unchanged | updated | refused <path>. Files that only seed a
# folder are written once and then left alone. CLAUDE.md and the quality doc are regenerated, but a
# version edited since is refused (exit 3) unless --force. Refuses to run while questions are still open.
#
#   --diff    write nothing: report what would happen, and show how a generated file would change (diff -u)
#   --force   replace a generated file that was edited since (after the user has seen --diff)
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

{ read -r A1; read -r R7; read -r R8; read -r R9; read -r F13; } < <(kickoff_awk get.awk "$root" -v ids="A1 R7 R8 R9 F13")
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

# --- task config and workflow (R7–R10), only with the task plugin: R7 is asked only then ---------
tasks_where=""
if [ -n "$R7" ]; then
    [ -n "$R8" ] || { echo "scaffold.sh: R7 is answered but the task prefix R8 is not" >&2; exit 1; }
    case "$R7" in
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
                KO_ROOT="$root" KO_DIR="$tdir" KO_PREFIX="$R8" \
                    awk -f "$KICKOFF_SCRIPTS/json.awk" -f "$KICKOFF_SCRIPTS/registry-insert.awk" "$in" > "$t" || {
                    rm -f "$t"; report refused "$reg"; rc=3; t=""; }
                if [ -n "$t" ]; then [ -f "$reg" ] && r=updated || r=created; mv "$t" "$reg"; report "$r" "$reg"; fi
            fi ;;
        *)
            tdir="$root/tasks"; tasks_where='in `tasks/`'
            t="$(mktemp)"; printf '{\n  "tasksDir": "tasks",\n  "prefix": "%s",\n  "nextId": 1\n}\n' "$R8" > "$t"
            once "$root/.task-config.json" "$t" ;;
    esac
    case "$R9" in
        One*|Minimal*) wf=workflow-minimal.md ;;
        *) wf=workflow-profiles.md ;;
    esac
    t="$(mktemp)"; kickoff_awk workflow.awk "$root" -v template="$KICKOFF_SCRIPTS/../templates/$wf" > "$t"; once "$tdir/_workflow/WORKFLOW.md" "$t"
fi

# --- quality doc (§F) -------------------------------------------------------------------------
t="$(mktemp)"; kickoff_awk quality.awk "$root" > "$t"
if [ -s "$t" ]; then guarded "$root/docs/project/quality.md" "$t"; else rm -f "$t"; fi

# --- CLAUDE.md ----------------------------------------------------------------------------------
t="$(mktemp)"; kickoff_awk claude.awk "$root" -v tasks="$tasks_where" > "$t"; guarded "$root/CLAUDE.md" "$t"

viewer=""; case "$F13" in Yes*) viewer=" · the E2E viewer, from kickoff's instructions" ;; esac
echo "next: create the first tasks — agree the charter · architecture overview · dev harness with the first vertical slice and its tests$viewer"
exit $rc
