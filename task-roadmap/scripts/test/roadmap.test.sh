#!/usr/bin/env bash
# Tests for task-roadmap: config resolution, generation, and the hook.
#
# Written BEFORE extracting lib.sh, to pin behaviour that had no coverage at all.
# The config-precedence rules below were previously implemented twice — once in
# generate.sh and once inline in regenerate-hook.sh — and agreed only by
# coincidence. These cases are what make it safe to collapse them into one.
#
# Dual-target, same as docs-manager: the host (macOS bash 3.2 + BSD userland) and a
# bash:5 container (GNU coreutils) catch different portability bugs.
#
#   bash task-roadmap/scripts/test/roadmap.test.sh
#   docker run --rm -v "$PWD":/w -w /w bash:5 bash task-roadmap/scripts/test/roadmap.test.sh
set -uo pipefail

SCRIPTS="$(cd "$(dirname "$0")/.." && pwd)"
GEN="$SCRIPTS/generate.sh"
HOOK="$SCRIPTS/regenerate-hook.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0

check() { # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"
    else fail=$((fail+1)); echo "  FAIL $1"; echo "         expected: [$2]"; echo "         actual:   [$3]"; fi
}

fresh() { rm -rf "$TMP/$1"; mkdir -p "$TMP/$1"; echo "$TMP/$1"; }

task() { # task <dir> <id> <title>
    mkdir -p "$(dirname "$2")"
    printf -- '---\ntitle: %s\nstatus: proposed\ntype: feature\npriority: high\n---\n\nbody\n' "$3" > "$2"
}

echo "== generation =="

# --- 1: default tasks dir, no config at all ---------------------------------
R=$(fresh r1); mkdir -p "$R/tasks"
task "$R" "$R/tasks/T-001.md" "First"
task "$R" "$R/tasks/T-002.md" "Second"
out=$(bash "$GEN" "$R" 2>&1); rc=$?
check "1a generates with no config" "0" "$rc"
check "1b default root is tasks/" "yes" "$([ -f "$R/tasks/roadmap.html" ] && echo yes || echo no)"
check "1c counts both tasks" "yes" "$(echo "$out" | grep -q '(2 tasks)' && echo yes || echo no)"

# --- 2: missing tasks dir is an error, not a silent pass --------------------
R=$(fresh r2)
bash "$GEN" "$R" >/dev/null 2>&1; check "2 missing tasks dir is non-zero" "1" "$?"

# --- 2b: an EMPTY tasks dir gets a clear message, not an awk glob failure ---
# Previously the "$TASKS_DIR"/*.md glob stayed literal and awk reported
# `can't open file .../tasks/*.md` with exit 2. Nothing planned yet is normal.
R=$(fresh r2b); mkdir -p "$R/tasks"
out=$(bash "$GEN" "$R" 2>&1); rc=$?
check "2b empty tasks dir exits 1" "1" "$rc"
check "2c message is about task files, not awk" "yes" \
  "$(echo "$out" | grep -q 'no task files' && echo yes || echo no)"
check "2d no awk error leaked" "no" "$(echo "$out" | grep -q 'awk:' && echo yes || echo no)"

echo "== config precedence =="

# --- 3: tasksDir from .task-config.json (another tool's file, shared DATA) --
R=$(fresh r3); mkdir -p "$R/.tasks"
task "$R" "$R/.tasks/T-001.md" "First"
printf '{ "tasksDir": ".tasks", "prefix": "T", "nextId": 2 }\n' > "$R/.task-config.json"
bash "$GEN" "$R" >/dev/null 2>&1; rc=$?
check "3a reads tasksDir from .task-config.json" "0" "$rc"
check "3b output lands in the configured dir" "yes" "$([ -f "$R/.tasks/roadmap.html" ] && echo yes || echo no)"

# --- 4: .task-roadmap.json WINS over .task-config.json ----------------------
# This is the precedence rule that was implemented twice. Pin it.
R=$(fresh r4); mkdir -p "$R/other"
task "$R" "$R/other/T-001.md" "First"
printf '{ "tasksDir": "wrong-dir" }\n'    > "$R/.task-config.json"
printf '{ "tasksDir": "other" }\n'        > "$R/.task-roadmap.json"
bash "$GEN" "$R" >/dev/null 2>&1
check "4 .task-roadmap.json overrides .task-config.json" "yes" \
  "$([ -f "$R/other/roadmap.html" ] && echo yes || echo no)"

# --- 5: title and outputs from .task-roadmap.json ---------------------------
R=$(fresh r5); mkdir -p "$R/tasks"
task "$R" "$R/tasks/T-001.md" "First"
printf '{ "title": "My Plan", "outputs": ["docs/plan.html", "out/plan.html"] }\n' > "$R/.task-roadmap.json"
bash "$GEN" "$R" >/dev/null 2>&1
check "5a custom title applied" "yes" "$(grep -q 'My Plan' "$R/docs/plan.html" 2>/dev/null && echo yes || echo no)"
check "5b first output written" "yes" "$([ -f "$R/docs/plan.html" ] && echo yes || echo no)"
check "5c second output written" "yes" "$([ -f "$R/out/plan.html" ] && echo yes || echo no)"
check "5d default output NOT written" "no" "$([ -f "$R/tasks/roadmap.html" ] && echo yes || echo no)"

echo "== hook =="

payload() { printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1"; }

# --- 6: edits to a task file regenerate -------------------------------------
R=$(fresh r6); mkdir -p "$R/tasks"
task "$R" "$R/tasks/T-001.md" "First"
rm -f "$R/tasks/roadmap.html"
payload "$R/tasks/T-001.md" | CLAUDE_PROJECT_DIR="$R" bash "$HOOK" >/dev/null 2>&1; rc=$?
check "6a hook exits 0" "0" "$rc"
check "6b hook regenerated" "yes" "$([ -f "$R/tasks/roadmap.html" ] && echo yes || echo no)"

# --- 7: the hook honours the SAME precedence as generate.sh -----------------
R=$(fresh r7); mkdir -p "$R/other"
task "$R" "$R/other/T-001.md" "First"
printf '{ "tasksDir": "wrong-dir" }\n' > "$R/.task-config.json"
printf '{ "tasksDir": "other" }\n'     > "$R/.task-roadmap.json"
payload "$R/other/T-001.md" | CLAUDE_PROJECT_DIR="$R" bash "$HOOK" >/dev/null 2>&1
check "7 hook precedence matches generate.sh" "yes" \
  "$([ -f "$R/other/roadmap.html" ] && echo yes || echo no)"

# --- 8: unrelated paths and workflow defs are ignored -----------------------
R=$(fresh r8); mkdir -p "$R/tasks/_workflow"
task "$R" "$R/tasks/T-001.md" "First"
rm -f "$R/tasks/roadmap.html"
payload "$R/src/main.ts" | CLAUDE_PROJECT_DIR="$R" bash "$HOOK" >/dev/null 2>&1; rc=$?
check "8a unrelated path exits 0" "0" "$rc"
check "8b unrelated path did not regenerate" "no" "$([ -f "$R/tasks/roadmap.html" ] && echo yes || echo no)"
payload "$R/tasks/_workflow/WORKFLOW.md" | CLAUDE_PROJECT_DIR="$R" bash "$HOOK" >/dev/null 2>&1; rc=$?
check "8c _workflow path exits 0" "0" "$rc"
check "8d _workflow did not regenerate" "no" "$([ -f "$R/tasks/roadmap.html" ] && echo yes || echo no)"

# --- 9: the hook never blocks a tool call, whatever happens -----------------
R=$(fresh r9)
printf 'not json at all' | CLAUDE_PROJECT_DIR="$R" bash "$HOOK" >/dev/null 2>&1
check "9a malformed payload exits 0" "0" "$?"
payload "$R/tasks/T-001.md" | CLAUDE_PROJECT_DIR="$R" bash "$HOOK" >/dev/null 2>&1
check "9b missing tasks dir exits 0" "0" "$?"

echo "== git worktree (PLUG-064) =="

# --- 9c: a linked worktree stands for the main tree --------------------------
# Each worktree checks out its own stale copy of the tasks; the roadmap belongs
# to the main tree's. Worktrees are made only inside this test's own temp repo.
if command -v git >/dev/null 2>&1; then
  g() { git -c user.email=t@t -c user.name=t -c init.defaultBranch=main "$@"; }
  R=$(fresh rw); R="$(cd "$R" && pwd -P)"; mkdir -p "$R/tasks"
  task "$R" "$R/tasks/T-001.md" "First"
  ( cd "$R" && g init -q && g add -A && g commit -qm init && g worktree add -q --detach .worktrees/rw-x ) >/dev/null 2>&1
  W="$R/.worktrees/rw-x"
  task "$R" "$R/tasks/T-002.md" "Second, main tree only"
  out=$(bash "$GEN" "$W" 2>&1)
  check "9c generate from a worktree reads the main tree" "yes" \
    "$(echo "$out" | grep -q '(2 tasks)' && echo yes || echo no)"
  check "9d the roadmap is written to the main tree" "yes" "$([ -f "$R/tasks/roadmap.html" ] && echo yes || echo no)"
  check "9e the worktree is unchanged" "" "$(cd "$W" && git status --porcelain)"
  rm -f "$R/tasks/roadmap.html"
  payload "$R/tasks/T-001.md" | CLAUDE_PROJECT_DIR="$W" bash "$HOOK" >/dev/null 2>&1
  check "9f hook in a worktree session regenerates the main tree's" "yes" \
    "$([ -f "$R/tasks/roadmap.html" ] && echo yes || echo no)"
  check "9g the worktree is still unchanged" "" "$(cd "$W" && git status --porcelain)"
  B="$TMP/rw.git"
  ( g init -q --bare "$B" && cd "$R" && g push -q "$B" HEAD:main && cd "$B" && g worktree add -q "$TMP/rwb" main ) >/dev/null 2>&1
  out=$(bash "$GEN" "$TMP/rwb" 2>&1)
  check "9h a bare repo's worktree stays itself" "yes" "$([ -f "$TMP/rwb/tasks/roadmap.html" ] && echo yes || echo no)"
else
  echo "  skip git worktree cases: git not installed"
fi
echo
echo "== packaging =="

# --- 10: no hardcoded #!/bin/bash shebang (PLUG-011) ------------------------
# Alpine puts bash at /usr/local/bin/bash with no /bin/bash, so a hardcoded
# shebang dies with "bad interpreter" as soon as a script is exec'd rather than
# run as `bash script.sh`. Deliberately duplicated from docs-manager's suite:
# per Plugin Independence a plugin never sources a sibling's file, so each one
# carries its own copy of this guard.
#
# The scan must exclude THIS FILE, which necessarily contains the string it
# searches for.
PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
hits=$(grep -rl '^#!/bin/bash' "$PLUGIN_ROOT" 2>/dev/null \
        | grep -v -x "$SELF" \
        | sed "s|^$PLUGIN_ROOT/||" | sort | tr '\n' ' ')
check "10 no hardcoded #!/bin/bash shebang" "" "${hits% }"


echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
