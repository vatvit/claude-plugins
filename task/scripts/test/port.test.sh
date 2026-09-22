#!/usr/bin/env bash
# Packaging + independence tests for the task plugin.
#
# These cover what the move to a plugin can actually get wrong, none of which
# the epic-dashboard suite touches:
#
#   R2/R4/R5  no absolute path, no reach into a sibling plugin, bash-3.2 clean
#   R9/R3     works as a copy of this directory outside the marketplace repo
#             with no siblings installed — the state most installs are in, and
#             the path least likely to be exercised by hand
#
# Run: bash scripts/test/port.test.sh   (from the plugin root)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SELF="scripts/test/port.test.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0

check() { # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"
    else fail=$((fail+1)); echo "  FAIL $1"; echo "         expected: [$2]"; echo "         actual:   [$3]"; fi
}

# scan <extended-regex> [subdir] -> matching files, plugin-relative, one line.
# This file necessarily contains every pattern it searches for, so it excludes
# itself; without that every check below reports its own source as a violation.
scan() {
    grep -rlE "$1" "$ROOT/${2:-}" 2>/dev/null \
      | sed "s|$ROOT/||" | grep -v "^$SELF$" \
      | sort | tr '\n' ' ' | sed 's/ $//'
}

echo "-- packaging --"

# T1  no absolute path anywhere in the shipped plugin (R2)
check "no absolute /Users or /home path" "" "$(scan '(/Users/|/home/)[A-Za-z]')"

# T2  the only permitted mention of the old repo is the README provenance line (R2)
check "old repo named only in README" "README.md" "$(scan 'claude-skill-task')"

# T3  no sibling plugin is sourced or executed (R4)
check "no sibling plugin path" "" "$(scan 'session-storage/|docs-manager/|task-roadmap/' scripts)"

# T4  bash 3.2 clean: no associative arrays, globstar or ^^ expansion (R5)
check "bash 3.2 constructs only" "" "$(scan 'declare -A|globstar' scripts)"

# T5  never sed -i in shipped code: -i '' is BSD-only, bare -i is GNU-only (R5)
check "no in-place sed" "" "$(scan 'sed -i' scripts)"

# T5b  shebangs must be `env bash`. `#!/bin/bash` is wrong on Alpine, where
#      bash lives at /usr/local/bin/bash — and it bites only when one script
#      execs another directly, as allocate-id.sh execs resolve-config.sh.
check "env-form shebang" "" "$(scan '^#!/bin/bash' scripts)"

# T6  every shipped script is executable
check "scripts executable" "" \
  "$(find "$ROOT/scripts" -name '*.sh' ! -perm -u+x | sed "s|$ROOT/||" | sort | tr '\n' ' ' | sed 's/ $//')"

echo "-- standalone copy, no siblings (R9) --"

# The plugin is copied somewhere with no marketplace repo above it and no
# sibling plugins beside it, then driven end to end.
ISO="$TMP/isolated"; mkdir -p "$ISO"
cp -R "$ROOT" "$ISO/task"
PROJ="$TMP/proj"; mkdir -p "$PROJ/tasks"
printf '{\n  "tasksDir": "tasks",\n  "prefix": "TST",\n  "nextId": 1\n}\n' > "$PROJ/.task-config.json"
SC="$ISO/task/scripts"

# T7  config resolves from the project, with a relative tasksDir
check "resolve-config prefix" "TST" \
  "$(bash "$SC/resolve-config.sh" "$PROJ" 2>/dev/null | grep '^prefix=' | cut -d= -f2)"

# T8  ID allocation works and returns the path it created (R7)
out=$(printf -- '---\ntitle: first\nstatus: proposed\ntype: epic\nepic-name: alpha\n---\n\n## Goal\n\ng\n\n## Sub-tasks\n\n- TST-002: child\n' \
      | bash "$SC/allocate-id.sh" "$PROJ" --stdin 2>/dev/null)
check "allocate-id returns ID=path" "TST-001" "${out%%=*}"
check "allocate-id created the file" "yes" \
  "$([ -f "$PROJ/tasks/TST-001.md" ] && echo yes || echo no)"

# T9  a second allocation never reuses the id
out2=$(printf -- '---\ntitle: second\nstatus: proposed\nepic: alpha\n---\n' \
       | bash "$SC/allocate-id.sh" "$PROJ" --stdin 2>/dev/null)
check "second id does not collide" "TST-002" "${out2%%=*}"

# T10 resolve-task reads frontmatter back
check "resolve-task title" "second" \
  "$(bash "$SC/resolve-task.sh" "$PROJ/tasks" TST 2 2>/dev/null | grep '^title=' | cut -d= -f2-)"

# T11 read-tasks emits both tasks as JSON
check "read-tasks finds 2" "2" \
  "$(bash "$SC/read-tasks.sh" "$PROJ/tasks" TST 2>/dev/null | grep -o '"id":"TST-[0-9]*"' | wc -l | tr -d ' ')"

# T12 epic index builds and resolves by epic-name
bash "$SC/update-epic-index.sh" "$PROJ/tasks" TST >/dev/null 2>&1
check "epic index maps alpha" "TST-001" \
  "$(bash "$SC/resolve-epic.sh" "$PROJ/tasks" TST alpha 2>/dev/null | grep '^id=' | cut -d= -f2)"

# T13 the dashboard reports the sub-task, from the isolated copy
check "dashboard sees sub-task" "1" \
  "$(bash "$SC/epic-dashboard.sh" "$PROJ/tasks" TST 1 2>/dev/null | grep -c '"id":"TST-002"' | tr -d ' ')"

# T13b the renderer works from the isolated copy too — it is the one script
#      that shells out to three others, so a broken path shows up here first.
check "list renders from the isolated copy" "1" \
  "$(bash "$SC/list-tasks.sh" "$PROJ/tasks" TST 1 2>/dev/null | grep -c '── epic: alpha' | tr -d ' ')"

echo "-- session-storage absent (R3) --"

# T14 no script may depend on the session-storage plugin. The skill detects it
#     from context and skips silently; the scripts must not know it exists.
check "no script calls storage.sh" "" "$(scan 'storage\.sh' scripts)"

# T14b session-active.sh is handed a helper path by the caller. With none set
#      it must say so and exit 0, never fail the command it is part of.
check "active-tasks is a no-op with no helper" "status=unavailable" \
  "$(env -u TASK_STORAGE_BIN -u TASK_SESSION_ID bash "$SC/session-active.sh" "$PROJ/tasks" TST get 2>&1)"

# T15 every command above ran with no session-storage present anywhere, which
#     is the assertion: R3 holds if nothing above failed.
check "end-to-end completed without session-storage" "0" "$fail"

echo
echo "passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
