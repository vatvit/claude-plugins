#!/usr/bin/env bash
# A linked git worktree resolves to the main tree (PLUG-063).
#
# Each worktree checks out its own copy of .task-config.json and the tasks
# folder. Resolving the project from the worktree's own path gave every
# worktree its own id lock and id sequence, so two of them could create the
# same id. The project is the main tree; a subdirectory keeps its place in it.
#
# Worktrees are made only inside this test's own temporary repo.
#
# Run: bash scripts/test/worktree.test.sh   (from the plugin root; needs git)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SC="$ROOT/scripts"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0

check() { # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"
    else fail=$((fail+1)); echo "  FAIL $1"; echo "         expected: [$2]"; echo "         actual:   [$3]"; fi
}

command -v git >/dev/null 2>&1 || { echo "SKIP: git not installed"; exit 0; }

# rc <dir> <key> — one value from resolve-config.sh, run from <dir> with no argument
rc() { (cd "$1" && bash "$SC/resolve-config.sh" 2>&1) | grep "^$2=" | cut -d= -f2-; }
# rca <dir> <key> — the same, with <dir> passed as the argument (what the skill does)
rca() { bash "$SC/resolve-config.sh" "$1" 2>&1 | grep "^$2=" | cut -d= -f2-; }

g() { git -c user.email=t@t -c user.name=t -c init.defaultBranch=main "$@"; }

MAIN="$TMP/main"; mkdir -p "$MAIN/.tasks" "$MAIN/sub"
MAIN="$(cd "$MAIN" && pwd -P)"
printf '{\n  "tasksDir": ".tasks",\n  "prefix": "WT",\n  "nextId": 1\n}\n' > "$MAIN/.task-config.json"
: > "$MAIN/.tasks/.keep"; : > "$MAIN/sub/.keep"
( cd "$MAIN" && g init -q && g add -A && g commit -qm init && g worktree add -q --detach .worktrees/main-x ) \
    || { echo "FAIL: fixture"; exit 1; }
WT="$MAIN/.worktrees/main-x"

echo "-- resolve-config from a worktree --"
check "main tree resolves to itself" "$MAIN/.tasks" "$(rc "$MAIN" tasksDir)"
check "worktree (pwd) resolves to the main tree" "$MAIN/.tasks" "$(rc "$WT" tasksDir)"
check "worktree (argument) resolves to the main tree" "$MAIN/.tasks" "$(rca "$WT" tasksDir)"
check "configFile is the main tree's" "$MAIN/.task-config.json" "$(rca "$WT" configFile)"
check "projectDir names the main tree" "$MAIN" "$(rca "$WT" projectDir)"
check "projectDir in the main tree" "$MAIN" "$(rca "$MAIN" projectDir)"

echo "-- one id sequence across trees --"
a=$(bash "$SC/allocate-id.sh" "$MAIN" | cut -d= -f1)
b=$(bash "$SC/allocate-id.sh" "$WT" | cut -d= -f1)
check "main tree allocates WT-001" "WT-001" "$a"
check "worktree allocates WT-002 from the same sequence" "WT-002" "$b"
check "the worktree's own copy is untouched" "no" "$([ -e "$WT/.tasks/WT-002.md" ] && echo yes || echo no)"
check "nextId written to the main tree's config" "3" \
    "$(awk -F: '/nextId/{gsub(/[ ,]/,"",$2); print $2}' "$MAIN/.task-config.json")"

echo "-- unchanged where there is no linked worktree --"
PLAIN="$TMP/plain"; mkdir -p "$PLAIN"
printf '{\n  "tasksDir": "t",\n  "prefix": "P"\n}\n' > "$PLAIN/.task-config.json"
check "no git: the directory itself" "$PLAIN/t" "$(rca "$PLAIN" tasksDir)"
SUBP="$TMP/subp"; mkdir -p "$SUBP"
printf '{\n  "tasksDir": "t",\n  "prefix": "S"\n}\n' > "$SUBP/.task-config.json"
cp "$SUBP/.task-config.json" "$MAIN/sub/.task-config.json"
check "a subdirectory of the main tree stays itself" "$MAIN/sub/t" "$(rca "$MAIN/sub" tasksDir)"
check "the same subdirectory in a worktree maps into the main tree" "$MAIN/sub/t" "$(rca "$WT/sub" tasksDir)"

BARE="$TMP/bare.git"
( g init -q --bare "$BARE" && cd "$MAIN" && g push -q "$BARE" HEAD:main && cd "$BARE" && g worktree add -q "$TMP/bwt" main ) \
    || { echo "FAIL: bare fixture"; exit 1; }
check "a bare repo's worktree stays itself" "$TMP/bwt/.tasks" "$(rca "$TMP/bwt" tasksDir)"

echo
echo "worktree: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
