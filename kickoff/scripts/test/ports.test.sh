#!/usr/bin/env bash
# Tests for kickoff's machine-wide port registry (ports.sh).
#
#   bash kickoff/scripts/test/ports.test.sh
#   docker run --rm -v "$PWD":/w -w /w bash:5 bash kickoff/scripts/test/ports.test.sh
set -uo pipefail
. "$(dirname "$0")/helpers.sh"

# Every case gets its own HOME, so the real ~/.claude is never touched.
setup() { H=$(fresh "$1"); mkdir -p "$H/projects"; export HOME="$H" KICKOFF_PROJECTS_DIR="$H/projects"; unset KICKOFF_PORTS_FILE CLAUDE_CONFIG_DIR; }
ports() { bash "$S/ports.sh" "$@"; }
REG() { echo "$HOME/.claude/kickoff/ports.json"; }

echo "== allocation =="
setup a1
check "1a an empty machine starts at the base" "3030" "$(ports next)"
check "1b next writes nothing" "no" "$([ -f "$(REG)" ] && echo yes || echo no)"
check "1c allocate reserves it" "3030" "$(ports allocate alpha)"
check "1d the registry is under ~/.claude/kickoff" "yes" "$([ -f "$(REG)" ] && echo yes || echo no)"
ino1=$(ls -i "$(REG)" | awk '{print $1}')
check "1e allocating the same name again returns its port" "3030" "$(ports allocate alpha)"
check "1f ... without rewriting the registry" "$ino1" "$(ls -i "$(REG)" | awk '{print $1}')"
check "1g the next name gets the next port" "3031" "$(ports allocate beta)"
check "1h a service port is a name too" "3032" "$(ports allocate alpha/api)"
check "1i list shows name and port" "alpha	3030" "$(ports list | head -1)"
check "1j the registry is JSON, one entry per line" '{|  "alpha": 3030,|  "beta": 3031,|  "alpha/api": 3032|}' "$(tr '\n' '|' < "$(REG)" | sed 's/|$//')"

echo "== the compose scan =="
setup a2
mkdir -p "$HOME/projects/x/one" "$HOME/projects/x/two/docker"
cat > "$HOME/projects/x/one/docker-compose.yml" <<'Y'
services:
  web:
    ports:
      - "3030:3000"
      - '127.0.0.1:3031:80'
      - 3032:80 # unquoted, with a comment
      # - "3033:1"   commented out: not in use
Y
cat > "$HOME/projects/x/two/docker/compose.yml" <<'Y'
services:
  app:
    ports:
      - "${APP_PORT:-3034}:8000"
      - target: 80
        published: 3035
Y
check "2a every published host port is skipped; a commented one is free" "3033" "$(ports next)"
ports set held 3033 >/dev/null
check "2b compose ports and the registry together" "3036" "$(ports next)"
check "2c list --all names the compose file" "yes" "$(has "x/two/docker/compose.yml	3035" "$(ports list --all)")"

echo "== two accounts, one machine =="
setup a3
c1=$(CLAUDE_CONFIG_DIR="$HOME/acct-1" ports allocate one)
c2=$(CLAUDE_CONFIG_DIR="$HOME/acct-2" ports allocate two)
check "3a two accounts never get the same port" "3030 3031" "$c1 $c2"
check "3b ... because both use the one machine-wide registry" "no" "$([ -e "$HOME/acct-1/kickoff" ] || [ -e "$HOME/acct-2/kickoff" ] && echo yes || echo no)"

echo "== concurrency and the lock =="
setup a4
for i in 1 2 3 4 5 6 7 8; do ports allocate "p$i" > "$HOME/out.$i" & done; wait
check "4a eight parallel allocations get eight ports" "8" "$(cat "$HOME"/out.* | sort -u | wc -l | tr -d ' ')"
check "4b all eight are registered" "8" "$(ports list | wc -l | tr -d ' ')"
check "4c the lock is released" "no" "$([ -e "$(REG).lock" ] && echo yes || echo no)"
mkdir "$(REG).lock"; echo 999999 > "$(REG).lock/pid"
check "4d a lock left by a dead process is broken" "3038" "$(ports allocate late)"

echo "== set, release, refusals =="
setup a5
ports allocate alpha >/dev/null
ports set other 3030 >/dev/null 2>&1; check "5a set refuses a port another name holds" "3" "$?"
check "5b set registers a port in use elsewhere" "4000" "$(ports set legacy 4000)"
check "5c set may move a name" "4001" "$(ports set legacy 4001 >/dev/null; ports list | awk -F'\t' '$1 == "legacy" { print $2 }')"
ports release legacy
check "5d release forgets it" "no" "$(has legacy "$(ports list)")"
ports allocate 'bad name' >/dev/null 2>&1; check "5e a bad name is refused" "2" "$?"
ports set x 30x0 >/dev/null 2>&1; check "5f a bad port is refused" "2" "$?"
KICKOFF_PORT_BASE=5000 ports next >/dev/null; check "5g the base is configurable" "5000" "$(KICKOFF_PORT_BASE=5000 ports next)"

summary
