#!/usr/bin/env bash
# PLUG-047: adopting crew mid-project — config set/unset, hold import.
. "$(dirname "$0")/helpers.sh"
R="$TMP/repo"; new_repo "$R"
(cd "$R" && bash "$C" whoami "Max Coordinator" coordinator --sid sid-g) >/dev/null
join "$R" s2; join "$R" s3
cfgv() { (cd "$R" && bash "$C" config) | grep "^$1="; }                  # cfgv <key> -> "key=v (layer)"
inode() { ls -i "$1" | awk '{ print $1 }'; }

echo "-- config set: project"
printf '{"committer":"each-session","x-note":"kept"}\n' > "$R/.crew.json"
out="$(cd "$R" && bash "$C" config set hotSpots a.ts 'src/*.ts')"; rc=$?
check "set an array key" 0 "$rc"
check "…effective" "hotSpots=a.ts,src/*.ts (project)" "$(cfgv hotSpots)"
check "…other keys kept" "committer=each-session (project)" "$(cfgv committer)"
check "…unknown keys kept" yes "$(contains '"x-note": "kept"' "$(cat "$R/.crew.json")")"
check "…array written as JSON" yes "$(contains '"hotSpots": ["a.ts", "src/*.ts"]' "$(cat "$R/.crew.json")")"
(cd "$R" && bash "$C" config set snapshotKeep 5) >/dev/null
check "a number is written bare" yes "$(contains '"snapshotKeep": 5' "$(cat "$R/.crew.json")")"
check "…and read back" "snapshotKeep=5 (project)" "$(cfgv snapshotKeep)"
(cd "$R" && bash "$C" config set hotSpots one.ts) >/dev/null
check "a one-element array stays an array" yes "$(contains '"hotSpots": ["one.ts"]' "$(cat "$R/.crew.json")")"
i="$(inode "$R/.crew.json")"
(cd "$R" && bash "$C" config set hotSpots one.ts) >/dev/null
check "an unchanged value leaves the file untouched" "$i" "$(inode "$R/.crew.json")"

echo "-- config set: refused"
before="$(cat "$R/.crew.json")"
for a in 'nope x' 'committer bogus' 'push maybe' 'hookMode maybe' 'snapshotKeep many' 'crewId a b' 'hotSpots' 'crewId' 'crewId a"b'; do
    out="$(cd "$R" && bash "$C" config set $a 2>&1)"; rc=$?
    check "refused: set $a" 1 "$rc"
done
check "…file unchanged" "$before" "$(cat "$R/.crew.json")"
out="$(cd "$R" && bash "$C" config set --user sharedBranch x 2>&1)"; rc=$?
check "--user with a project-only key is refused" 1 "$rc"
check "…saying why" yes "$(contains "project-only" "$out")"
check "…no user file written" no "$( [ -f "$CREW_USER_CONFIG" ] && echo yes || echo no)"

echo "-- config set: user layer"
out="$(cd "$R" && bash "$C" config set --user hookMode warn)"; rc=$?
check "--user writes the user file" 0 "$rc"
check "…effective from user" "hookMode=warn (user)" "$(cfgv hookMode)"
check "…project file untouched" no "$(contains hookMode "$(cat "$R/.crew.json")")"

echo "-- config unset"
(cd "$R" && bash "$C" config unset hotSpots) >/dev/null
check "unset drops the key" "hotSpots= (default)" "$(cfgv hotSpots)"
check "…keeps the rest" "committer=each-session (project)" "$(cfgv committer)"
(cd "$R" && bash "$C" config unset --user hookMode) >/dev/null
check "unset --user" "hookMode=deny (default)" "$(cfgv hookMode)"
out="$(cd "$R" && bash "$C" config unset nope 2>&1)"; rc=$?
check "unset of an unknown key is refused" 1 "$rc"
rm -f "$R/.crew.json"
R2="$TMP/nocrew"; new_repo "$R2"
(cd "$R2" && bash "$C" config set hotSpots x.ts) >/dev/null
check "config set before any crew: written" yes "$(contains '"hotSpots": ["x.ts"]' "$(cat "$R2/.crew.json")")"
check "…without switching crew on" no "$( [ -d "$R2/.git/crew" ] && echo yes || echo no)"

echo "-- hold import"
cat > "$TMP/holds.md" <<'EOF'
# Holds (hand-kept)

- crew/a.txt — s2 (PLUG-12, since 09:00)
- `b.txt` - Max Coordinator
- c.txt: s3
- d.txt by s2
- src/land-x.sh – s3 (PLUG-7)
- h.txt — s3 (PLUG-3: schema - by noon)
* e.txt — ghost (PLUG-9)
- scenes/*.ts — s2
- f.txt — s3
- g.txt — s2
some prose, not a bullet
- no separator here
EOF
crew_as s3 "$R" hold f.txt g.txt >/dev/null
out="$(crew_as s2 "$R" hold import "$TMP/holds.md" 2>&1)"; rc=$?
check "a worker cannot import" 1 "$rc"
before="$(crew_as s2 "$R" who)"
out="$(crew_as "Max Coordinator" "$R" hold import "$TMP/holds.md" --dry-run 2>&1)"; rc=$?
check "dry run: nothing changed" "$before" "$(crew_as s2 "$R" who)"
check "…shows the plan" yes "$(contains "would hold: crew/a.txt — s2 (PLUG-12)" "$out")"
check "…a display-name holder resolves" yes "$(contains "would hold: b.txt — max-coordinator" "$out")"
check "…exits non-zero while something is unresolved" 1 "$rc"
out="$(crew_as "Max Coordinator" "$R" hold import "$TMP/holds.md" 2>&1)"; rc=$?
who="$(crew_as s2 "$R" who)"
check "import: em dash + task" yes "$(contains "crew/a.txt — s2 since" "$who")"
check "…task kept" yes "$(contains "(PLUG-12)" "$who")"
check "import: hyphen, backticks, display name" yes "$(contains "b.txt — max-coordinator since" "$who")"
check "import: colon" yes "$(contains "c.txt — s3 since" "$who")"
check "import: by" yes "$(contains "d.txt — s2 since" "$who")"
check "import: en dash, hyphen inside the path" yes "$(contains "src/land-x.sh — s3 since" "$who")"
check "the earliest separator wins (later ones in the note)" yes "$(contains "h.txt — s3 since" "$who")"
check "unknown holder: listed" yes "$(contains "not in the crew: ghost (e.txt)" "$out")"
check "…not held" no "$(contains "e.txt" "$who")"
check "a glob is not a path: skipped" yes "$(contains "skipped: scenes/*.ts" "$out")"
check "…not held" no "$(contains "scenes/" "$who")"
check "already held by the same holder: fine" yes "$(contains "f.txt — already held by s3" "$out")"
check "held by someone else: conflict" yes "$(contains "g.txt — REFUSED, held by s3" "$out")"
check "a bullet with no separator is reported" yes "$(contains "skipped: no separator here" "$out")"
check "prose lines ignored" no "$(contains "prose" "$out")"
check "import exits non-zero (ghost, conflict)" 1 "$rc"
out="$(crew_as "Max Coordinator" "$R" hold import "$TMP/nope.md" 2>&1)"; rc=$?
check "a missing file is an error" 1 "$rc"

finish
