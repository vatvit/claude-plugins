#!/usr/bin/env bash
# PLUG-119: crew works with the project folder only. HOME unset, missing (cannot be created) or a plain
# file — chmod proves nothing as root in a container — and the upgrade case: new code, old state.
. "$(dirname "$0")/helpers.sh"

# nohome <mode> <cmd...> — run with no usable HOME. Nothing else points at the real machine either.
nohome() {
    local mode="$1"; shift
    case "$mode" in
        unset) env -u HOME -u CREW_HOME -u CREW_USER_CONFIG -u CLAUDE_CONFIG_DIR "$@" ;;
        missing) env -u CREW_HOME -u CREW_USER_CONFIG -u CLAUDE_CONFIG_DIR HOME="$TMP/a-file/nope" "$@" ;;
        file) env -u CREW_HOME -u CREW_USER_CONFIG -u CLAUDE_CONFIG_DIR HOME="$TMP/a-file" "$@" ;;
    esac
}
: > "$TMP/a-file"

for mode in unset missing file; do
    echo "-- no usable HOME ($mode): every capability works from the project folder"
    R="$TMP/repo-$mode"; new_repo "$R"; id="repo-$mode"
    out="$(cd "$R" && nohome $mode bash "$C" whoami boss coordinator --sid sid-b 2>&1)"; rc=$?
    check "$mode: whoami works" 0 "$rc"
    check "$mode: …the name carries the project prefix" yes "$(contains "you are $id-boss (coordinator)" "$out")"
    check "$mode: …no machine registry written" no "$( [ -e "$R/.git/crew/names" ] && echo yes || echo no)"
    out="$(cd "$R" && nohome $mode bash "$C" whoami "Ann Worker" --sid sid-a 2>&1)"
    check "$mode: a display name is prefixed too (peers address the display)" yes "$(contains "display=$id-Ann Worker" "$(cat "$R/.git/crew/sessions/$id-ann-worker")")"
    printf '%s' "$(payload sid-h "$R" Bash command "bash $C whoami hooked")" | nohome $mode bash "$H/pre-bash.sh" >/dev/null 2>&1
    out="$(cd "$R" && nohome $mode bash "$C" whoami hooked 2>&1)"
    check "$mode: the hook-parked session id finds the prefixed join" yes "$(contains "you are $id-hooked" "$out")"
    out="$(cd "$R" && nohome $mode bash "$C" whoami "$id-boss" coordinator --sid sid-b 2>&1)"
    check "$mode: re-joining by the full name does not prefix twice" no "$(contains "$id-$id" "$out")"
    out="$(cd "$R" && nohome $mode env CREW_AS=$id-boss bash "$C" slot request cpu 5 2>&1)"; rc=$?
    check "$mode: slot request works" 0 "$rc"
    check "$mode: …says the scope once" yes "$(contains "slots: project scope — HOME not writable" "$out")"
    check "$mode: …and that other repos' crews are not covered (PLUG-135)" yes "$(contains "does not keep their runs off the machine" "$out")"
    check "$mode: …the queue is in the project" yes "$( [ -s "$R/.git/crew/slots" ] && echo yes || echo no)"
    out="$(cd "$R" && nohome $mode env CREW_AS=$id-boss bash "$C" slot list 2>&1)"
    check "$mode: …not said again" no "$(contains "project scope" "$out")"
    check "$mode: …the slot is live (owner found without the registry)" no "$(contains STALE "$out")"
    out="$(cd "$R" && nohome $mode env CREW_AS=$id-boss bash "$C" slot done 2>&1)"; rc=$?
    check "$mode: slot done works" 0 "$rc"
    out="$(cd "$R" && nohome $mode env CREW_AS=$id-boss CREW_SLOT_POLL=0.2 bash "$C" slot run cpu 1 -- echo ran 2>&1)"
    check "$mode: slot run works" yes "$(contains ran "$out")"
    out="$(cd "$R" && nohome $mode bash "$C" config 2>&1)"; rc=$?
    check "$mode: config shows" 0 "$rc"
    out="$(cd "$R" && nohome $mode bash "$C" config set --user snapshotKeep 5 2>&1)"; rc=$?
    check "$mode: the user layer says it needs a usable HOME" yes "$([ $rc -ne 0 ] && contains "HOME" "$out")"
    out="$(cd "$R" && nohome $mode bash "$C" config set slotScope project 2>&1)"; rc=$?
    check "$mode: the project layer still takes settings" 0 "$rc"
    out="$(cd "$R" && nohome $mode env CREW_AS=$id-boss bash "$C" time 2>&1)"; rc=$?
    check "$mode: crew time degrades without transcripts" 0 "$rc"
    check "$mode: …with no shell error" no "$(printf '%s' "$out" | grep -Eq 'unbound|No such file|syntax error|Not a directory|cannot' && echo yes || echo no)"
    check "$mode: …and says what it has, as with HOME" yes "$(contains "no transcript found for this crew's sessions" "$out")"
    out="$(cd "$R" && nohome $mode bash "$C" status 2>&1)"; rc=$?
    check "$mode: status works" 0 "$rc"
    out="$(cd "$R" && nohome $mode bash "$C" whoami --leave "$id-ann-worker" 2>&1)"; rc=$?
    check "$mode: whoami --leave works" 0 "$rc"
    out="$(cd "$R" && nohome $mode env CREW_AS=$id-boss bash "$C" end --force 2>&1)"; rc=$?
    check "$mode: end works" 0 "$rc"
    check "$mode: …the crew is gone" no "$( [ -d "$R/.git/crew" ] && echo yes || echo no)"
done

echo "-- HOME usable: today's defaults"
R="$TMP/repo-home"; new_repo "$R"
join "$R" s1 coordinator; join "$R" s2
check "names stay as typed" yes "$( [ -f "$R/.git/crew/sessions/s1" ] && echo yes || echo no)"
check "the machine registry is written" yes "$( [ -f "$CREW_HOME/names/s1" ] && echo yes || echo no)"
out="$(crew_as s1 "$R" slot request cpu 5 2>&1)"
check "slots default to the machine queue" yes "$( [ -s "$CREW_HOME/slots" ] && echo yes || echo no)"
check "…no scope notice" no "$(contains "project scope" "$out")"
crew_as s1 "$R" slot done >/dev/null
crew_as s1 "$R" config set slotScope project >/dev/null
crew_as s1 "$R" slot request cpu 5 >/dev/null
check "slotScope=project keeps the queue in the project" yes "$( [ -s "$R/.git/crew/slots" ] && echo yes || echo no)"
out="$(crew_as s1 "$R" slot list 2>&1)"
check "…and a chosen scope is not 'HOME not writable'" no "$(contains "HOME not writable" "$out")"
crew_as s1 "$R" slot done >/dev/null
crew_as s1 "$R" config set slotScope bogus >/dev/null 2>&1; rc=$?
check "slotScope takes machine or project only" 1 "$rc"
crew_as s1 "$R" config set namePrefix always >/dev/null
out="$(cd "$R" && bash "$C" whoami fresh --sid sid-f 2>&1)"
check "namePrefix=always prefixes even with HOME" yes "$(contains "you are repo-home-fresh" "$out")"

echo "-- upgrade: new code on state written by the previous version"
R="$TMP/repo-old"; new_repo "$R"; S="$R/.git/crew"
rm -rf "$CREW_HOME"; mkdir -p "$S/sessions" "$CREW_HOME/names"
printf 'sid=sid-old1\nrole=coordinator\nsince=1791028000\ndisplay=Old Boss\n' > "$S/sessions/old-boss"
printf 'sid=sid-old2\nrole=worker\nsince=1791028000\ndisplay=oldw\n' > "$S/sessions/oldw"
for n in old-boss oldw; do printf 'state=%s\ncrew=repo-old\nsid=%s\n' "$S" "$(sed -n 's/^sid=//p' "$S/sessions/$n")" > "$CREW_HOME/names/$n"; done
printf '1\toldw\tcpu\t10\t2\t1791028000\twaiting\t\told row\trepo-old\t\t\t0\n' > "$CREW_HOME/slots"
printf '1\n' > "$CREW_HOME/slots.seq"
out="$(crew_as old-boss "$R" slot list 2>&1)"
check "an old queue row is read" yes "$(contains "#1 oldw" "$out")"
check "…its owner is live through the old registry" no "$(contains STALE "$out")"
out="$(cd "$R" && bash "$C" whoami oldw --sid sid-old2 2>&1)"
check "an old name re-joins as it was (no prefix)" yes "$(contains "you are oldw (worker)" "$out")"
out="$(crew_as old-boss "$R" status 2>&1)"
check "old members are listed" yes "$(contains "oldw" "$out")"
out="$(cd "$R" && nohome unset env CREW_AS=oldw bash "$C" slot list 2>&1)"; rc=$?
check "the same crew keeps working when HOME later goes away" 0 "$rc"
check "…the old member's slot is still live" no "$(contains STALE "$out")"
out="$(cd "$R" && nohome unset bash "$C" whoami oldw --sid sid-old2 2>&1)"
check "…and its name is still oldw (no prefix on a re-join)" yes "$(contains "you are oldw (worker)" "$out")"


echo "-- HOME a plain file, transcripts under CLAUDE_CONFIG_DIR: still read (PLUG-136)"
R="$TMP/repo-tx"; new_repo "$R"; A="$TMP/acct-tx"; mkdir -p "$A/projects/-repo-tx"
txenv() { env -u CREW_HOME -u CREW_USER_CONFIG -u CREW_TRANSCRIPTS HOME="$TMP/a-file" CLAUDE_CONFIG_DIR="$A" CREW_NOW=1791028800 TZ=UTC "$@"; }
(cd "$R" && txenv bash "$C" whoami txw --sid sid-tx >/dev/null 2>&1)
{ printf '{"parentUuid":null,"isSidechain":false,"type":"user","message":{"role":"user","content":"go"},"uuid":"u","timestamp":"2026-10-03T09:00:00.000Z","origin":{"kind":"human"}}\n'
  printf '{"parentUuid":"p","isSidechain":false,"message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_t","name":"Bash","input":{"command":"npm test","description":"d"}}]},"type":"assistant","uuid":"a","timestamp":"2026-10-03T09:01:00.000Z"}\n'
  printf '{"parentUuid":"p","isSidechain":false,"type":"user","message":{"role":"user","content":[{"tool_use_id":"toolu_t","type":"tool_result","content":"ok"}]},"uuid":"u","timestamp":"2026-10-03T09:21:00.000Z","toolUseResult":{"stdout":"x"}}\n'
} > "$A/projects/-repo-tx/sid-tx.jsonl"
out="$(cd "$R" && txenv env CREW_AS=txw bash "$C" time 2>&1)"; rc=$?
check "crew time exits 0" 0 "$rc"
check "…the transcript under CLAUDE_CONFIG_DIR is read (20 min of a process)" yes "$(contains "20" "$out")"

finish
