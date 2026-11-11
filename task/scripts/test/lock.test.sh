#!/usr/bin/env bash
# The id lock (allocate-id.sh): a lock left behind by a crashed process is broken
# once it is stale, on every userland. busybox `stat -f` is filesystem status, not
# a file's mtime: it prints a screenful and fails, so a BSD-first `stat -f || stat -c`
# chain fed junk into the age arithmetic and allocation died (PLUG-125). Only the
# container run (busybox) can fail this; the host (BSD stat) passes either way.
#
# Run: bash scripts/test/lock.test.sh   (from the plugin root)
set -uo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

PROJ="$TMP/proj"; mkdir -p "$PROJ/tasks"
printf '{\n  "tasksDir": "tasks",\n  "prefix": "LK",\n  "nextId": 1\n}\n' > "$PROJ/.task-config.json"

echo "-- a stale lock is broken --"
mkdir "$PROJ/tasks/.id-alloc.lock"
touch -t 202001010000 "$PROJ/tasks/.id-alloc.lock"
out=$(bash "$SC/allocate-id.sh" "$PROJ" 2>&1); rc=$?
check "allocation succeeds past a stale lock" "0" "$rc"
contains "it allocates the first id" "LK-001=" "$out"
check "the lock is released afterwards" "no" "$([ -d "$PROJ/tasks/.id-alloc.lock" ] && echo yes || echo no)"

report lock
