#!/usr/bin/env bash
# Tests for working without HOME (PLUG-121): kickoff must work with the project folder alone when
# HOME is unset, missing or not writable. chmod does not stop root in a container, so "not writable"
# is HOME pointing at a regular file, or at a path below one.
#
#   bash kickoff/scripts/test/home.test.sh
#   docker run --rm -v "$PWD":/w -w /w bash:5 bash kickoff/scripts/test/home.test.sh
set -uo pipefail
. "$(dirname "$0")/helpers.sh"

exists() { [ -e "$1" ] && echo yes || echo no; }
unset CLAUDE_CONFIG_DIR KICKOFF_PORTS_FILE KICKOFF_PROJECTS_DIR
: > "$TMP/afile"

# run <home-mode> <project> <script> [args] — the script with the project as the project folder and
# HOME unset | a regular file | a path below a regular file | a usable fresh dir.
run() {
    local mode="$1" p="$2" script="$3"; shift 3
    case "$mode" in
        unset)   env -u HOME CLAUDE_PROJECT_DIR="$p" bash "$S/$script" "$@" ;;
        file)    env HOME="$TMP/afile" CLAUDE_PROJECT_DIR="$p" bash "$S/$script" "$@" ;;
        below)   env HOME="$TMP/afile/home" CLAUDE_PROJECT_DIR="$p" bash "$S/$script" "$@" ;;
        usable)  env HOME="$TMP/home-$(basename "$p")" CLAUDE_PROJECT_DIR="$p" bash "$S/$script" "$@" ;;
    esac
}
homeof() { echo "$TMP/home-$(basename "$1")"; }

for mode in unset file below; do
    echo "== HOME $mode: ports =="
    P=$(fresh "p-$mode")
    printf 'services:\n  a:\n    ports:\n      - "3030:80"\n' > "$P/compose.yaml"
    out=$(run $mode "$P" ports.sh allocate "$mode" 2>"$TMP/err"); rc=$?
    check "1a [$mode] allocation works" "0" "$rc"
    check "1b [$mode] the port skips the one the project's compose file publishes" "3031" "$out"
    check "1c [$mode] the registry is in the project folder" "yes" "$(exists "$P/.kickoff/ports.json")"
    check "1d [$mode] the output says project scope" "yes" "$(has "project scope" "$(cat "$TMP/err")")"
    check "1e [$mode] asking again gives the same port" "3031" "$(run $mode "$P" ports.sh allocate "$mode" 2>/dev/null)"
    check "1f [$mode] list reads the project registry" "$mode	3031" "$(run $mode "$P" ports.sh list 2>/dev/null)"
    check "1g [$mode] scope says there is no HOME to ask about" "project-no-home" "$(run $mode "$P" ports.sh scope 2>/dev/null)"
    run $mode "$P" ports.sh scope home >/dev/null 2>"$TMP/err"; rc=$?
    check "1h [$mode] choosing HOME is refused, plainly" "1 yes" "$rc $(has "needs HOME" "$(cat "$TMP/err")")"
    check "1i [$mode] viewer ports work too" "e2e-view	30311" "$(run $mode "$P" ports.sh viewer "$mode" 2>/dev/null | head -1)"
    P2=$(fresh "pg-$mode"); mkdir -p "$P2/.git"
    run $mode "$P2" ports.sh allocate x >/dev/null 2>&1
    check "1j [$mode] in a git repo the registry sits in .git/kickoff, never committed" "yes no" "$(exists "$P2/.git/kickoff/ports.json") $(exists "$P2/.kickoff")"

    echo "== HOME $mode: the rest =="
    out=$(run $mode "$P" defaults.sh list 2>&1); rc=$?
    check "2a [$mode] no user defaults: list is empty, exit 0" "0 []" "$rc [$out]"
    run $mode "$P" defaults.sh set A4 Mine >/dev/null 2>"$TMP/err"; rc=$?
    check "2b [$mode] setting one says it needs HOME and fails cleanly" "1 yes" "$rc $(has "needs HOME" "$(cat "$TMP/err")")"
    out=$(unset KICKOFF_PLUGINS; run $mode "$P" plan.sh "$P" --next 2>&1); rc=$?
    check "2c [$mode] the plan is computed from defaults" "0 yes" "$rc $(has "A1" "$out")"
    P3=$(fresh "o-$mode"); bash "$S/answer.sh" --root "$P3" A1 o
    check "2d [$mode] inspect reads files only" "0" "$(run $mode "$P3" inspect.sh "$P3" >/dev/null 2>&1; echo $?)"
    bash "$S/answer.sh" --root "$P3" R6 "Markdown task files"
    out=$(run $mode "$P3" gaps.sh "$P3" 2>&1); rc=$?
    check "2e [$mode] gaps reports the missing task setup" "0 yes" "$rc $(has "R6" "$out")"
done

echo "== HOME unset: tasks outside the repo need HOME, and say so =="
P=$(fresh out-nohome)
autofill "$P" A1=out A4="A client's" A5="git@example.com:acme/out.git" R7="Outside the repo" R8=OUT R9="One minimal profile" \
    D3=English K2=English I6=n/a C4=n/a C5="Never — always free to break" F1="Basic" E1="USES — an LLM API" E2=OpenAI R3="VPN needed"
out=$(run unset "$P" scaffold.sh "$P" 2>&1); rc=$?
check "3a [unset] scaffold refuses plainly" "1 yes" "$rc $(has "needs HOME" "$out")"
check "3b [unset] and wrote no CLAUDE.md" "no" "$(exists "$P/CLAUDE.md")"
out=$(CLAUDE_CONFIG_DIR="$TMP/acct" env -u HOME CLAUDE_PROJECT_DIR="$P" bash "$S/scaffold.sh" "$P" 2>&1); rc=$?
check "3c [unset] CLAUDE_CONFIG_DIR alone is enough for the registry" "0 yes" "$rc $(exists "$TMP/acct/project-tasks/config.json")"
out=$(run file "$P" scaffold.sh "$P" 2>&1); rc=$?
check "3d [file] an unwritable HOME refuses the same way" "1 yes" "$rc $(has "needs HOME" "$out")"

echo "== the task registry path is one helper =="
P=$(fresh reg); bash "$S/answer.sh" --root "$P" R6 "Markdown task files"
mkdir -p "$TMP/h1/.claude/project-tasks" "$TMP/acct1/project-tasks"
printf '{\n  "projects": {\n    "%s": {\n      "tasksDir": "/t",\n      "prefix": "RG",\n      "nextId": 1\n    }\n  }\n}\n' "$P" > "$TMP/h1/.claude/project-tasks/config.json"
inf() { env "$@" bash "$S/inspect.sh" "$P" | awk -F'\t' '$1 == "R8" { print $2 }'; }
gp() { env "$@" bash "$S/gaps.sh" "$P" | cut -f1 | grep -x R6 || true; }
check "4a a registry in ~/.claude is found by inspect" "RG" "$(inf HOME="$TMP/h1")"
check "4b ... and by gaps (no R6 gap)" "" "$(gp HOME="$TMP/h1")"
check "4c ... also when the account has its own config dir" "RG" "$(inf HOME="$TMP/h1" CLAUDE_CONFIG_DIR="$TMP/acct1")"
check "4d ... gaps agrees" "" "$(gp HOME="$TMP/h1" CLAUDE_CONFIG_DIR="$TMP/acct1")"
cp "$TMP/h1/.claude/project-tasks/config.json" "$TMP/acct1/project-tasks/config.json"; rm -rf "$TMP/h1"; mkdir -p "$TMP/h1"
check "4e a registry in CLAUDE_CONFIG_DIR is found without any HOME" "RG" "$(env -u HOME CLAUDE_CONFIG_DIR="$TMP/acct1" bash "$S/inspect.sh" "$P" | awk -F'\t' '$1 == "R8" { print $2 }')"
check "4f ... and gaps agrees" "" "$(env -u HOME CLAUDE_CONFIG_DIR="$TMP/acct1" bash "$S/gaps.sh" "$P" | cut -f1 | grep -x R6 || true)"
check "4g no registry anywhere: the gap shows" "R6" "$(env -u HOME bash "$S/gaps.sh" "$P" | cut -f1 | grep -x R6 || true)"

echo "== an unreadable per-account file means defaults =="
P=$(fresh unreadable)
mkdir -p "$TMP/h2/.claude/kickoff.json" "$TMP/h2/.claude/plugins/installed_plugins.json"   # directories, not files
out=$(unset KICKOFF_PLUGINS; HOME="$TMP/h2" bash "$S/plan.sh" "$P" --next 2>&1); rc=$?
check "5a a kickoff.json that is not a readable file is ignored" "0 yes" "$rc $(has "A1" "$out")"
check "5b ... and so is installed_plugins.json: nothing installed" "skip" "$(unset KICKOFF_PLUGINS; HOME="$TMP/h2" bash "$S/plan.sh" "$P" --review >/dev/null 2>&1; echo skip)"

echo "== HOME usable: ask first, nothing written to HOME unasked =="
P=$(fresh ask); H=$(homeof "$P"); mkdir -p "$H"
check "6a undecided and HOME usable: ask" "ask" "$(run usable "$P" ports.sh scope 2>/dev/null)"
check "6b allocation before the answer uses the project, with a note" "3030" "$(run usable "$P" ports.sh allocate ask 2>"$TMP/err")"
check "6c ... HOME got nothing" "no no" "$(exists "$H/.claude/kickoff/ports.json") $(exists "$H/.claude/kickoff")"
check "6d ... and the note says the choice is open" "yes" "$(has "scope" "$(cat "$TMP/err")")"
run usable "$P" ports.sh scope project >/dev/null 2>&1
check "6e the answer is recorded in the project, not in HOME" "yes yes" "$(has '"ports": "project"' "$(cat "$P/.kickoff.json")") $(exists "$P/.kickoff/ports.json")"
check "6f ... and then it is not asked again" "project" "$(run usable "$P" ports.sh scope 2>/dev/null)"
P=$(fresh yes); H=$(homeof "$P"); mkdir -p "$H"
run usable "$P" ports.sh scope home >/dev/null 2>&1
check "6g yes: the registry is machine-wide in HOME" "3030 yes" "$(run usable "$P" ports.sh allocate yes 2>/dev/null) $(exists "$H/.claude/kickoff/ports.json")"
check "6h ... the choice is in the project config" "yes" "$(has '"ports": "home"' "$(cat "$P/.kickoff.json")")"
check "6i ... and the probe left no temp file" "ports.json" "$(ls -A "$H/.claude/kickoff" | grep -v lock | tr '\n' ' ' | sed 's/ $//')"
check "6j a bad scope is refused" "2" "$(run usable "$P" ports.sh scope maybe >/dev/null 2>&1; echo $?)"
printf '{\n  "ports": "home"\n}\n' > "$P/.kickoff.json"; run unset "$P" ports.sh allocate z >/dev/null 2>"$TMP/err"; rc=$?
check "6k the project chose HOME but it is gone: say so, do nothing else" "1 yes" "$rc $(has "needs HOME" "$(cat "$TMP/err")")"

echo "== upgrade: the earlier machine-wide registry counts as a yes =="
P=$(fresh upg); H=$(homeof "$P"); mkdir -p "$H/.claude/kickoff"
printf '{\n  "old": 3030,\n  "other": 3031\n}\n' > "$H/.claude/kickoff/ports.json"
check "7a no .kickoff.json, an old registry: scope is home, no question" "home" "$(run usable "$P" ports.sh scope 2>/dev/null)"
check "7b the old entries are read" "old	3030" "$(run usable "$P" ports.sh list 2>/dev/null | head -1)"
check "7c a new allocation goes on in HOME, silently" "3032" "$(run usable "$P" ports.sh allocate fresh 2>"$TMP/err")"
check "7d no note on stderr" "" "$(cat "$TMP/err")"
check "7e no project file or config written" "no no" "$(exists "$P/.kickoff.json") $(exists "$P/.kickoff")"
check "7f the registry kept its entries and format" '{|  "old": 3030,|  "other": 3031,|  "fresh": 3032|}' "$(tr '\n' '|' < "$H/.claude/kickoff/ports.json" | sed 's/|$//')"

echo "== concurrent probes: one process's probe never fails another's =="
# kickoff_home_usable once made ~/.claude/kickoff and removed it again; a second process probing at
# the same moment found the dir gone and called HOME unusable (ports.test 4a, 1 run in 3).
H="$TMP/home-race"; mkdir -p "$H"
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    ( HOME="$H" bash -c '. "$1/lib.sh"; kickoff_home_usable && echo ok || echo no' _ "$S" > "$TMP/race.$i" ) &
done
wait
check "8a twenty concurrent probes all find HOME usable" "20" "$(cat "$TMP"/race.* | grep -c '^ok$')"
check "8b ... and leave nothing in HOME" "" "$(ls -A "$H/.claude" 2>/dev/null)"

echo "== switching scope moves this project's ports (PLUG-134) =="
reg() { [ -f "$1" ] || return 0; tr '\n' ' ' < "$1" | tr -s ' ' | sed 's/ $//'; }
P=$(fresh sw); H=$(homeof "$P"); mkdir -p "$H"
run usable "$P" ports.sh scope project >/dev/null 2>&1
for n in tmp sw sw/api; do run usable "$P" ports.sh allocate $n >/dev/null 2>&1; done; run usable "$P" ports.sh release tmp 2>/dev/null
run usable "$P" ports.sh scope home >/dev/null 2>"$TMP/err"; rc=$?
check "9a project → home: the switch succeeds" "0" "$rc"
check "9b ... HOME's list has the project's ports" '{ "sw": 3031, "sw/api": 3032 }' "$(reg "$H/.claude/kickoff/ports.json")"
check "9c ... the project's own list is gone (one list)" "no" "$(exists "$P/.kickoff/ports.json")"
check "9d ... the project keeps its port" "3031" "$(run usable "$P" ports.sh allocate sw 2>/dev/null)"
before="$(reg "$H/.claude/kickoff/ports.json")"
run usable "$P" ports.sh scope home >/dev/null 2>&1; rc=$?
check "9e the same switch again is a no-op" "0 $before" "$rc $(reg "$H/.claude/kickoff/ports.json")"

P=$(fresh cl); H=$(homeof "$P"); mkdir -p "$H/.claude/kickoff"
run usable "$P" ports.sh scope project >/dev/null 2>&1
run usable "$P" ports.sh allocate cl >/dev/null 2>&1; run usable "$P" ports.sh allocate cl/api >/dev/null 2>&1
printf '{\n  "other": 3031\n}\n' > "$H/.claude/kickoff/ports.json"
out="$(run usable "$P" ports.sh scope home 2>&1)"; rc=$?
check "9f a port HOME gives another name refuses the switch" "3" "$rc"
check "9g ... naming the clash" "yes" "$(has "3031" "$out")"
check "9h ... nothing written: HOME, the project's list, the choice" '{ "other": 3031 }|{ "cl": 3030, "cl/api": 3031 }|project' \
    "$(reg "$H/.claude/kickoff/ports.json")|$(reg "$P/.kickoff/ports.json")|$(run usable "$P" ports.sh scope 2>/dev/null)"

P=$(fresh hp); H=$(homeof "$P"); bash "$S/answer.sh" --root "$P" A1 hp >/dev/null
run usable "$P" ports.sh scope home >/dev/null 2>&1
for n in else hp hp/api; do run usable "$P" ports.sh allocate $n >/dev/null 2>&1; done
run usable "$P" ports.sh scope project >/dev/null 2>"$TMP/err"; rc=$?
check "9i home → project: the switch succeeds" "0" "$rc"
check "9j ... the project's list has A1's ports, not another project's" '{ "hp": 3031, "hp/api": 3032 }' "$(reg "$P/.kickoff/ports.json")"
check "9k ... HOME keeps them all (still taken on this machine)" '{ "else": 3030, "hp": 3031, "hp/api": 3032 }' "$(reg "$H/.claude/kickoff/ports.json")"
check "9l ... the project keeps its port" "3031" "$(run usable "$P" ports.sh allocate hp 2>/dev/null)"

P=$(fresh na); run usable "$P" ports.sh scope home >/dev/null 2>&1; run usable "$P" ports.sh allocate na >/dev/null 2>&1
out="$(run usable "$P" ports.sh scope project 2>&1)"; rc=$?
check "9m without a settled A1 the switch still happens" "0 project" "$rc $(run usable "$P" ports.sh scope 2>/dev/null)"
check "9n ... and says nothing was copied" "yes" "$(has "A1" "$out")"

summary
