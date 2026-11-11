#!/usr/bin/env bash
# The git id source (PLUG-125, epic task-id-sync): ids are reserved by pushing a
# counter to a dedicated branch, so clones never hand out the same id, and the
# user's index, tree, HEAD and branches are never touched.
#
# Everything happens in fixture repos under $TMP: a bare "remote" and clones of it.
# HOME points into $TMP and the system git config is ignored, so the user's own git
# identity and settings never leak in (allocation commits then use the neutral author).
#
# Run: bash scripts/test/git-source.test.sh   (from the plugin root; needs git)
set -uo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

command -v git >/dev/null 2>&1 || { echo "SKIP: git not installed"; exit 0; }

export HOME="$TMP/home" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME"
unset CLAUDE_CONFIG_DIR

# g — git for the test's own actions (the user's), with an identity of its own.
g() { git -c user.email=u@t -c user.name=u -c init.defaultBranch=main "$@"; }
alloc() { bash "$SC/allocate-id.sh" "$@"; }
idsrc() { bash "$SC/id-source.sh" "$@"; }
counter() { git -C "$REMOTE" show "task-ids:GT.next-id" 2>/dev/null; }
commits() { git -C "$REMOTE" rev-list --count task-ids 2>/dev/null || echo 0; }
ids() { printf '%s\n' "$1" | sed 's/=.*//'; }

REMOTE="$TMP/remote.git"
g init -q --bare "$REMOTE"
A="$TMP/a"; mkdir -p "$A/tasks"
printf '{\n  "tasksDir": "tasks",\n  "prefix": "GT",\n  "nextId": 5\n}\n' > "$A/.task-config.json"
: > "$A/tasks/GT-007.md"
( cd "$A" && g init -q && g add -A && g commit -qm init && g remote add origin "$REMOTE" && g push -q origin main )

echo "-- config: idSource --"
P="$TMP/bad"; mkdir -p "$P"
printf '{\n  "tasksDir": "tasks",\n  "prefix": "BD",\n  "idSource": "svn"\n}\n' > "$P/.task-config.json"
out=$(alloc "$P" 2>&1); rc=$?
check "an unknown idSource is refused" "1" "$rc"
contains "... naming the allowed values" "local, git" "$out"
check "... and creates nothing" "no" "$([ -e "$P/tasks/BD-001.md" ] && echo yes || echo no)"

echo "-- setup: local -> git --"
out=$(idsrc "$A" git 2>&1); rc=$?
check "setup succeeds" "0" "$rc"
check "the counter starts at max(nextId, highest file + 1)" "8" "$(counter)"
check "config: idSource is git" "1" "$(grep -c '"idSource": "git"' "$A/.task-config.json")"
check "config: nextId is gone" "0" "$(grep -c nextId "$A/.task-config.json")"
check "config: the other keys are kept" "2" "$(grep -cE '"(tasksDir|prefix)"' "$A/.task-config.json")"
check "setup does not commit" "1" "$(cd "$A" && git rev-list --count HEAD)"
contains "setup tells the user to commit the config" "Commit and push it" "$out"
check "the user's branches are untouched by setup" "main" "$(cd "$A" && git for-each-ref --format='%(refname:short)' refs/heads)"
( cd "$A" && g commit -qam "switch to git ids" && g push -q origin main )

echo "-- resolve-config in git mode --"
cfg=$(bash "$SC/resolve-config.sh" "$A")
contains "nextId comes from the clone's cache" "nextId=8" "$cfg"
contains "idSource is reported" "idSource=git" "$cfg"

echo "-- allocate --"
before_cfg=$(cksum < "$A/.task-config.json")
out=$(alloc "$A" 2>&1)
check "A gets the counter's id" "GT-008" "$(ids "$out")"
check "the counter advanced" "9" "$(counter)"
check "allocation does not write the config" "$before_cfg" "$(cksum < "$A/.task-config.json")"

B="$TMP/b"; g clone -q "$REMOTE" "$B"
out=$(alloc "$B" 2>&1)
check "B, which never saw GT-008, gets the next id" "GT-009" "$(ids "$out")"

echo "-- setup again from another clone adopts --"
: > "$B/tasks/GT-030.md"
idsrc "$B" git >/dev/null 2>&1
check "adopting raises the counter to cover local files" "31" "$(counter)"
rm -f "$B/tasks/GT-030.md"
idsrc "$B" git >/dev/null 2>&1
check "adopting never lowers it" "31" "$(counter)"

echo "-- --count: one push --"
c0=$(commits)
out=$(alloc "$A" --count 3 2>&1)
check "three ids" "GT-031 GT-032 GT-033" "$(ids "$out" | tr '\n' ' ' | sed 's/ $//')"
check "one push" "$((c0 + 1))" "$(commits)"
check "the counter moved by three" "34" "$(counter)"

echo "-- the user's work is never touched --"
( cd "$A" && echo staged > staged.txt && g add staged.txt \
  && echo local > local.txt && g add local.txt && g commit -qm "unpushed" \
  && g checkout -q -b feature && echo wip > wip.txt && g add wip.txt && echo dirty >> local.txt )
snap() { ( cd "$A" && git symbolic-ref HEAD; git rev-parse HEAD; git ls-files -s | cksum
           git for-each-ref --format='%(refname) %(objectname)' refs/heads
           git status --porcelain | grep -v ' tasks/' ); }
s0=$(snap)
alloc "$A" >/dev/null 2>&1
check "index, tree, HEAD and branches are identical" "$s0" "$(snap)"

echo "-- concurrent clones never share an id --"
C="$TMP/c"; g clone -q "$REMOTE" "$C"
( for i in 1 2 3 4 5; do TASK_ID_RETRIES=30 alloc "$B"; done ) > "$TMP/b.out" 2>&1 &
( for i in 1 2 3 4 5; do TASK_ID_RETRIES=30 alloc "$C"; done ) > "$TMP/c.out" 2>&1 &
wait
all=$(cat "$TMP/b.out" "$TMP/c.out" | grep '^GT-' | sed 's/=.*//' | sort)
check "ten ids allocated" "10" "$(printf '%s\n' "$all" | grep -c .)"
check "no id twice" "" "$(printf '%s\n' "$all" | uniq -d)"

echo "-- a push the remote refuses --"
printf '#!/bin/sh\necho "refused by policy" >&2\nexit 1\n' > "$REMOTE/hooks/pre-receive"
chmod +x "$REMOTE/hooks/pre-receive"
n0=$(ls "$A/tasks" | wc -l | tr -d ' ')
out=$(alloc "$A" 2>&1); rc=$?
check "allocation fails" "1" "$rc"
contains "... with a message" "push" "$out"
check "... and creates no task file" "$n0" "$(ls "$A/tasks" | wc -l | tr -d ' ')"
rm -f "$REMOTE/hooks/pre-receive"

echo "-- the remote has no counter branch --"
R2="$TMP/empty.git"; g init -q --bare "$R2"
D="$TMP/d"; mkdir -p "$D/tasks"
printf '{\n  "tasksDir": "tasks",\n  "prefix": "GT",\n  "idSource": "git"\n}\n' > "$D/.task-config.json"
( cd "$D" && g init -q && g add -A && g commit -qm init && g remote add origin "$R2" )
out=$(alloc "$D" 2>&1); rc=$?
check "allocation fails" "1" "$rc"
contains "... naming the setup command" "id-source.sh" "$out"
check "... and creates no task file" "no" "$([ -e "$D/tasks/GT-001.md" ] && echo yes || echo no)"

echo "-- the remote is unreachable: local, with a warning --"
( cd "$D" && git remote set-url origin "$TMP/nowhere.git" )
out=$(alloc "$D" 2>&1); rc=$?
check "allocation succeeds" "0" "$rc"
contains "it allocates locally" "GT-001=" "$out"
contains "... and warns the id is not synced" "not synced" "$out"

echo "-- no git repo at all: local, with a warning --"
E="$TMP/e"; mkdir -p "$E/tasks"
printf '{\n  "tasksDir": "tasks",\n  "prefix": "GT",\n  "idSource": "git"\n}\n' > "$E/.task-config.json"
out=$(alloc "$E" 2>&1); rc=$?
check "allocation succeeds" "0" "$rc"
contains "it allocates locally" "GT-001=" "$out"
contains "... and warns" "not synced" "$out"

echo "-- setup refuses what it cannot do --"
out=$(idsrc "$E" git 2>&1); rc=$?
check "setup with no git repo fails" "1" "$rc"
out=$(idsrc "$A" bogus 2>&1); rc=$?
check "an unknown subcommand is refused" "1" "$rc"
F="$TMP/f"; mkdir -p "$F/tasks"
printf '{\n  "tasksDir": "tasks",\n  "prefix": "GT",\n  "idBranch": "bad..name"\n}\n' > "$F/.task-config.json"
( cd "$F" && g init -q && g add -A && g commit -qm init && g remote add origin "$REMOTE" )
out=$(idsrc "$F" git 2>&1); rc=$?
check "an invalid branch name is refused" "1" "$rc"

echo "-- task_config_edit (the config writer setup uses) --"
# Reading a one-line config is resolve-config.sh's job (PLUG-131); the writer
# itself must cope with one, keep other keys, and escape what it writes.
H="$TMP/h.json"
printf '{ "tasksDir": "my tasks", "prefix": "GT", "nextId": 1, "flag": true }\n' > "$H"
( . "$SC/lib.sh"; task_config_edit "$H" set idSource git del nextId )
check "a one-line config is rewritten one key per line" \
  '{|  "tasksDir": "my tasks",|  "prefix": "GT",|  "flag": true,|  "idSource": "git"|}' \
  "$(tr '\n' '|' < "$H" | sed 's/|$//')"
m0=$(ls -l "$H")
( . "$SC/lib.sh"; task_config_edit "$H" set idSource git )
check "an edit that changes nothing leaves the file alone" "$m0" "$(ls -l "$H")"
( . "$SC/lib.sh"; task_config_edit "$H" set note 'say "hi"' )
check "a written string is escaped" '  "note": "say \"hi\""' "$(grep note "$H")"

echo "-- status --"
out=$(idsrc "$A" status 2>&1)
contains "status names the source" "idSource=git" "$out"
contains "status names the branch" "branch=task-ids" "$out"

echo "-- no force anywhere --"
check "no forced push in the scripts" "" "$(grep -lE 'push.*(--force|[[:space:]]-f[[:space:]]|[[:space:]]\+)' "$SC"/*.sh 2>/dev/null)"

report git-source
