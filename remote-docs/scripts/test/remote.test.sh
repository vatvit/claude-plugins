#!/usr/bin/env bash
# Tests for remote cards (Google Drive, Claude Artifacts): status/check, stamp, gone, local copies,
# the provider diff and the listing. Moved from docs-manager's external.test.sh (PLUG-144) with only
# the command names changed, so a green run proves the move kept behaviour.
#
# Dual-target — run on the host (bash 3.2 + BSD) and in a container:
#
#   bash remote-docs/scripts/test/remote.test.sh
#   docker run --rm -v "$PWD":/w -w /w bash:5 bash remote-docs/scripts/test/remote.test.sh
set -uo pipefail


RD="$(cd "$(dirname "$0")/.." && pwd)/remote.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0 skipped=0

check() { # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"
    else fail=$((fail+1)); echo "  FAIL $1"; echo "         expected: [$2]"; echo "         actual:   [$3]"; fi
}
has() { echo "$1" | grep -qF -- "$2" && echo yes || echo no; }   # has <haystack> <needle>

fresh() { rm -rf "$TMP/$1"; mkdir -p "$TMP/$1"; echo "$TMP/$1"; }
doc() { # doc <path> [description] — body from stdin
    mkdir -p "$(dirname "$1")"
    { printf -- '---\ntitle: t\ndescription: %s\n---\n\n' "${2:-d}"; cat; } > "$1"
}


echo "== remote cards (PLUG-112) =="

# rcard <path> [description] [omit-field] [id] [modified] — a remote card (Drive doc kept on
# Drive), no local file. omit-field drops remote-id or remote-modified; "-" omits nothing.
rcard() {
    local id="${4:-1AbC-dEf_9}" mod="${5:-2026-11-10T13:37:23.036Z}"
    mkdir -p "$(dirname "$1")"
    {
      printf -- '---\ntitle: t\ndescription: %s\nread-when: mapping vendor codes\n' "${2:-Remote spec}"
      [ "${3:-}" = remote-id ]       || printf 'remote-id: %s\n' "$id"
      printf 'remote-url: https://docs.google.com/document/d/%s/edit\n' "$id"
      printf 'remote-type: application/pdf\n'
      [ "${3:-}" = remote-modified ] || printf 'remote-modified: %s\n' "$mod"
      printf -- '---\n\n# Spec\n'
    } > "$1"
}

# --- RC4/RC5: status row, never an orphan; check needs id + modified -----------
R=$(fresh rc4)
rcard "$R/external/drive/ok.gdrive.md"
rcard "$R/external/drive/noid.gdrive.md" "x" remote-id
rcard "$R/external/drive/nomod.gdrive.md" "x" remote-modified
st=$(bash "$RD" status "$R" 2>&1)
check "RC4a remote row" "yes" "$(has "$st" "$(printf 'remote\tfiled\t-\t%s/external/drive/ok.gdrive.md' "$R")")"
check "RC4b never an orphan" "no" "$(has "$st" 'orphan')"
out=$(bash "$RD" check "$R" 2>&1); rc=$?
check "RC5a incomplete fails check" "1" "$rc"
check "RC5b missing id reported" "yes" "$(has "$out" "REMOTE INCOMPLETE: $R/external/drive/noid.gdrive.md")"
check "RC5c missing modified reported" "yes" "$(has "$out" "REMOTE INCOMPLETE: $R/external/drive/nomod.gdrive.md")"
check "RC5d complete card not reported" "no" "$(has "$out" "ok.gdrive.md")"
R=$(fresh rc5)
rcard "$R/external/drive/ok.gdrive.md"
out=$(bash "$RD" check "$R" 2>&1); rc=$?
check "RC5e complete remote card: check clean" "0" "$rc"

# --- RC7: stamp is the one writer of remote-modified ------------------------
R=$(fresh rc7)
rcard "$R/c.gdrive.md" "x" remote-modified
out=$(bash "$RD" stamp "$R/c.gdrive.md" 2026-11-11T10:15:12.524Z 2>&1); rc=$?
check "RC7a stamped" "0:yes" "$rc:$(has "$out" "STAMPED: $R/c.gdrive.md")"
check "RC7b field written" "yes" "$(has "$(cat "$R/c.gdrive.md")" 'remote-modified: 2026-11-11T10:15:12.524Z')"
before=$(cat "$R/c.gdrive.md")
out=$(bash "$RD" stamp "$R/c.gdrive.md" 2026-11-11T10:15:12.524Z 2>&1)
check "RC7c repeat is UNCHANGED, bytes kept" "yes:same" \
  "$(has "$out" UNCHANGED):$([ "$before" = "$(cat "$R/c.gdrive.md")" ] && echo same || echo changed)"
bash "$RD" stamp "$R/c.gdrive.md" 2026-11-11T10:15:12Z >/dev/null 2>&1
check "RC7d whole seconds accepted" "yes" "$(has "$(cat "$R/c.gdrive.md")" 'remote-modified: 2026-11-11T10:15:12Z')"
before=$(cat "$R/c.gdrive.md")
bash "$RD" stamp "$R/c.gdrive.md" "yesterday" >/dev/null 2>&1; rc=$?
check "RC7e malformed time rejected, file untouched" "nz:same" \
  "$([ "$rc" -ne 0 ] && echo nz || echo z):$([ "$before" = "$(cat "$R/c.gdrive.md")" ] && echo same || echo changed)"
doc "$R/plain.md" </dev/null
bash "$RD" stamp "$R/plain.md" 2026-11-11T10:15:12Z >/dev/null 2>&1; rc=$?
check "RC7f not a remote card rejected" "nz:no" \
  "$([ "$rc" -ne 0 ] && echo nz || echo z):$(has "$(cat "$R/plain.md")" 'remote-modified')"

# --- RC8: list lists every remote card with its attachment's publish --
R=$(fresh rc8)
rcard "$R/external/vendor/spec.pdf.gdrive.md" "Vendor spec"
printf -- '---\nprovider: gdrive\ncontent: remote\nprocessed: none\npublish: commit\n---\n' > "$R/external/vendor/.source.md"
rcard "$R/external/loose/pricing.gdrive.md" "Pricing"
out=$(bash "$RD" list "$R" 2>&1); rc=$?
check "RC8a rc 0" "0" "$rc"
check "RC8b record with publish" "yes" "$(has "$out" "$(printf '%s/external/vendor/spec.pdf.gdrive.md\tcommit\t2026-11-10T13:37:23.036Z\tVendor spec\tmapping vendor codes' "$R")")"
check "RC8c no .source.md -> -" "yes" "$(has "$out" "$(printf '%s/external/loose/pricing.gdrive.md\t-\t' "$R")")"

echo "== remote folders (PLUG-113) =="

T1=2026-11-10T13:37:23.036Z; T2=2026-11-11T09:00:00.000Z
DOCMIME=application/vnd.google-apps.document; DIRMIME=application/vnd.google-apps.folder
# attach <root> [extra .source.md lines] — the attached folder external/acme, three cards
attach() {
    local A="$1/external/acme"
    mkdir -p "$A"
    { printf -- '---\nprovider: gdrive\nremote-id: F0\nrecursive: true\n'; [ -n "${2:-}" ] && printf '%s\n' "$2"
      printf -- 'publish: commit\n---\n'; } > "$A/.source.md"
    rcard "$A/a.gdrive.md" "A" - 1a "$T1"
    rcard "$A/sub/b.gdrive.md" "B" - 1b "$T1"
    rcard "$A/old.gdrive.md" "Old" - 1z "$T1"
    echo "$A"
}
# listing rows: id path mime modified (tab-separated), one argument per row
listing() { local r; for r in "$@"; do printf '%s\n' "$r" | tr '|' '\t'; done; }
diff_of() { bash "$RD" diff "$1" "$2" 2>/dev/null; }   # stdout only

# --- RF1/RF2/RF3/RF4/RF5: in sync, new, changed (by id, not name), gone, folders skipped ---------
R=$(fresh rf1); A=$(attach "$R")
listing "1a|a|$DOCMIME|$T1" "S1|sub|$DIRMIME|$T1" "1b|sub/b|$DOCMIME|$T1" "1z|old|$DOCMIME|$T1" > "$R/l.tsv"
out=$(bash "$RD" diff "$A" "$R/l.tsv" 2>&1); rc=$?
check "RF1 in sync: nothing, rc 0" "0:" "$rc:$out"
listing "1a|renamed-a|$DOCMIME|$T2" "S1|sub|$DIRMIME|$T1" "1b|sub/b|$DOCMIME|$T1" "1n|sub/new doc|$DOCMIME|$T1" > "$R/l.tsv"
out=$(diff_of "$A" "$R/l.tsv")
check "RF2 new row" "yes" "$(has "$out" "$(printf 'new\t1n\tsub/new doc\t%s\t%s' "$DOCMIME" "$T1")")"
check "RF3a changed by id, Drive time given" "yes" "$(has "$out" "$(printf 'changed\t1a\t%s/a.gdrive.md\t%s' "$A" "$T2")")"
check "RF3b renamed is not new" "no" "$(has "$out" 'renamed-a')"
check "RF4 gone" "yes" "$(has "$out" "$(printf 'gone\t1z\t%s/old.gdrive.md' "$A")")"
check "RF5 folder row never new" "no" "$(has "$out" "$(printf 'new\tS1')")"
check "RF2b exactly three records" "3" "$(echo "$out" | grep -c .)"

# --- RF6: scope — recursive: false, include, exclude ------------------------------------------
R=$(fresh rf6a); A=$(attach "$R")
awk '{ sub(/^recursive: true$/, "recursive: false"); print }' "$A/.source.md" > "$R/t" && mv "$R/t" "$A/.source.md"
listing "1a|a|$DOCMIME|$T1" "1b|sub/b|$DOCMIME|$T1" "1z|old|$DOCMIME|$T1" "1n|sub/n|$DOCMIME|$T1" > "$R/l.tsv"
out=$(diff_of "$A" "$R/l.tsv")
check "RF6a not recursive: sub-folder row not new" "no" "$(has "$out" '1n')"
check "RF6b not recursive: card of a sub-folder row is gone" "yes" "$(has "$out" "$(printf 'gone\t1b\t')")"
R=$(fresh rf6b); A=$(attach "$R" "$(printf 'include: [sub/*, a]\nexclude: [*draft*]')")
listing "1a|a|$DOCMIME|$T1" "1b|sub/b|$DOCMIME|$T1" "1z|old|$DOCMIME|$T1" \
        "1d|sub/b draft|$DOCMIME|$T1" "1n|sub/n|$DOCMIME|$T1" > "$R/l.tsv"
out=$(diff_of "$A" "$R/l.tsv")
check "RF6c include admits sub/n" "yes" "$(has "$out" "$(printf 'new\t1n\t')")"
check "RF6d exclude drops the draft" "no" "$(has "$out" '1d')"
check "RF6e outside include: old is gone" "yes" "$(has "$out" "$(printf 'gone\t1z\t')")"
check "RF6f included cards in sync" "nono" "$(has "$out" "$(printf '\t1a\t')")$(has "$out" "$(printf '\t1b\t')")"

# --- RF7: ids are strings, never numbers --------------------------------------------------------
R=$(fresh rf7); A="$R/external/num"; mkdir -p "$A"
printf -- '---\nprovider: gdrive\nremote-id: F1\n---\n' > "$A/.source.md"
rcard "$A/x.gdrive.md" "X" - 010 "$T1"; rcard "$A/y.gdrive.md" "Y" - 75e763 "$T1"
listing "10|x|$DOCMIME|$T1" "7e1794|y|$DOCMIME|$T1" > "$R/l.tsv"
out=$(diff_of "$A" "$R/l.tsv")
check "RF7 numeric-looking ids stay distinct" "2:2" \
  "$(echo "$out" | grep -c '^new'):$(echo "$out" | grep -c '^gone')"

# --- RF8/RF11: bad input is an error, nothing on stdout ----------------------------------------
R=$(fresh rf8); A=$(attach "$R")
listing "1a|a|$DOCMIME|$T1" "1b|sub/b|$DOCMIME" > "$R/l.tsv"
out=$(bash "$RD" diff "$A" "$R/l.tsv" 2>/dev/null); rc=$?
err=$(bash "$RD" diff "$A" "$R/l.tsv" 2>&1 >/dev/null)
check "RF8a short row: rc 1, stdout empty" "1:" "$rc:$out"
check "RF8b error names line 2" "yes" "$(has "$err" 'line 2')"
listing "|a|$DOCMIME|$T1" > "$R/l.tsv"
bash "$RD" diff "$A" "$R/l.tsv" >/dev/null 2>&1; check "RF8c empty id rejected" "1" "$?"
mkdir -p "$R/plain"; listing "1a|a|$DOCMIME|$T1" > "$R/l.tsv"
bash "$RD" diff "$R/plain" "$R/l.tsv" >/dev/null 2>&1; check "RF11a no .source.md" "1" "$?"
printf -- '---\nprovider: gdrive\n---\n' > "$R/plain/.source.md"
out=$(bash "$RD" diff "$R/plain" "$R/l.tsv" 2>&1); rc=$?
check "RF11b .source.md without remote-id: carded only, no new (PLUG-141)" "0:" "$rc:$out"

# --- RF9/RF10: gone marks, check reports, stamp clears --------------------------
R=$(fresh rf9); A=$(attach "$R")
out=$(bash "$RD" gone "$A/old.gdrive.md" 2>&1); rc=$?
check "RF9a marked" "0:yes" "$rc:$(has "$out" "MARKED GONE: $A/old.gdrive.md")"
check "RF9b field written" "yes" "$(has "$(cat "$A/old.gdrive.md")" 'remote-gone: yes')"
before=$(cat "$A/old.gdrive.md")
out=$(bash "$RD" gone "$A/old.gdrive.md" 2>&1)
check "RF9c repeat UNCHANGED, bytes kept" "yes:same" \
  "$(has "$out" UNCHANGED):$([ "$before" = "$(cat "$A/old.gdrive.md")" ] && echo same || echo changed)"
doc "$R/plain.md" </dev/null
bash "$RD" gone "$R/plain.md" >/dev/null 2>&1; rc=$?
check "RF9d not a remote card rejected" "nz:no" "$([ "$rc" -ne 0 ] && echo nz || echo z):$(has "$(cat "$R/plain.md")" 'remote-gone')"
rm -f "$R/plain.md"
st=$(bash "$RD" status "$R" 2>&1)
check "RF10a status: gone row" "yes" "$(has "$st" "$(printf 'gone\tfiled\t-\t%s/old.gdrive.md' "$A")")"
out=$(bash "$RD" check "$R" 2>&1); rc=$?
check "RF10b check fails on a gone card" "1:yes" "$rc:$(has "$out" "REMOTE GONE: $A/old.gdrive.md")"
bash "$RD" stamp "$A/old.gdrive.md" "$T2" >/dev/null 2>&1
check "RF10c stamp clears the mark" "yes" "$(has "$(cat "$A/old.gdrive.md")" 'remote-gone: no')"
bash "$RD" check "$R" >/dev/null 2>&1; check "RF10d check clean again" "0" "$?"
bash "$RD" stamp "$A/a.gdrive.md" "$T2" >/dev/null 2>&1
check "RF10e a card never gone gets no remote-gone key" "no" "$(has "$(cat "$A/a.gdrive.md")" 'remote-gone')"

# --- RF12: a card in a sub-folder of an attachment takes publish from the attachment's .source.md --
# (found by the e2e run: `list` looked only beside the card, so sub/ cards read "-")
R=$(fresh rf12); A=$(attach "$R")
mkdir -p "$R/external/plain"; rcard "$R/external/plain/lone.gdrive.md" "Lone"
out=$(bash "$RD" list "$R")
check "RF12a sub-folder card: publish from the nearest .source.md above" "yes" \
    "$(has "$out" "$(printf '%s/sub/b.gdrive.md\tcommit\t' "$A")")"
check "RF12b no .source.md anywhere above: -" "yes" \
    "$(has "$out" "$(printf '%s/external/plain/lone.gdrive.md\t-\t' "$R")")"
printf -- '---\npublish: local\n---\n' > "$A/sub/.source.md"
check "RF12c the nearest one wins" "yes" \
    "$(has "$(bash "$RD" list "$R")" "$(printf '%s/sub/b.gdrive.md\tlocal\t' "$A")")"

echo "== local copies (PLUG-115) =="

# lattach <root> <processed> — an attachment with one remote card (modified T1) and, unless
# processed is "-", a .source.md saying so. Prints the attachment dir.
TC1=2026-11-11T17:27:11.986Z; TC2=2026-11-12T09:00:00Z
lattach() {
    local A="$1/external/acme"
    mkdir -p "$A"
    [ "$2" = - ] || printf -- '---\nprovider: gdrive\nprocessed: %s\ncopy-publish: commit\n---\n' "$2" > "$A/.source.md"
    rcard "$A/spec.gdrive.md" "Spec" - 1s "$TC1"
    echo "$A"
}
copy() { printf 'Spec\n\n1\\. Authentication\n' > "$1"; }   # copy <path> — a Drive text rendering


# --- LC2/LC3: copy-stamp refuses an unagreed or missing copy ----------------------------------------
R=$(fresh lc2); A=$(lattach "$R" none); copy "$A/spec.gdrive.local.md"
before=$(cat "$A/spec.gdrive.md")
err=$(bash "$RD" copy-stamp "$A/spec.gdrive.md" "$TC1" 2>&1); rc=$?
check "LC2a refused without processed: local" "1:yes" "$rc:$(has "$err" 'processed: local')"
check "LC2b card untouched" "$before" "$(cat "$A/spec.gdrive.md")"
R=$(fresh lc2b); A=$(lattach "$R" -); copy "$A/spec.gdrive.local.md"
bash "$RD" copy-stamp "$A/spec.gdrive.md" "$TC1" >/dev/null 2>&1; check "LC2c refused with no .source.md" "1" "$?"
R=$(fresh lc3); A=$(lattach "$R" local)
err=$(bash "$RD" copy-stamp "$A/spec.gdrive.md" "$TC1" 2>&1); rc=$?
check "LC3 refused with no copy" "1:yes" "$rc:$(has "$err" 'spec.gdrive.local.md')"

# --- LC4: copy-stamp writes copy-modified, idempotent, checks the time shape ---------------------
R=$(fresh lc4); A=$(lattach "$R" local); copy "$A/spec.gdrive.local.md"
out=$(bash "$RD" copy-stamp "$A/spec.gdrive.md" "$TC1" 2>&1); rc=$?
check "LC4a stamped" "0:yes" "$rc:$(has "$out" "STAMPED: $A/spec.gdrive.md")"
check "LC4b field" "yes" "$(has "$(cat "$A/spec.gdrive.md")" "copy-modified: $TC1")"
out=$(bash "$RD" copy-stamp "$A/spec.gdrive.md" "$TC1" 2>&1)
check "LC4c unchanged on repeat" "yes" "$(has "$out" 'UNCHANGED')"
bash "$RD" copy-stamp "$A/spec.gdrive.md" "yesterday" >/dev/null 2>&1; check "LC4d bad time rejected" "1" "$?"
bash "$RD" copy-stamp "$A/spec.gdrive.local.md" "$TC1" >/dev/null 2>&1; check "LC4e not a card" "1" "$?"

# --- LC5/LC6: in step, then stale after the card is refreshed, then clean again -----------------
st=$(bash "$RD" status "$R")
check "LC5a status copy" "yes" "$(has "$st" "$(printf 'copy\tfiled\t%s/spec.gdrive.local.md\t%s/spec.gdrive.md' "$A" "$A")")"
bash "$RD" check "$R" >/dev/null 2>&1; check "LC5b check clean" "0" "$?"
bash "$RD" stamp "$A/spec.gdrive.md" "$TC2" >/dev/null 2>&1
out=$(bash "$RD" check "$R" 2>&1); rc=$?
check "LC6a stale after the card moved on" "1:yes" "$rc:$(has "$out" "LOCAL COPY STALE: $A/spec.gdrive.local.md")"
check "LC6b status copy-stale" "yes" "$(has "$(bash "$RD" status "$R")" "$(printf 'copy-stale\t')")"
bash "$RD" copy-stamp "$A/spec.gdrive.md" "$TC2" >/dev/null 2>&1
bash "$RD" check "$R" >/dev/null 2>&1; check "LC6c clean after copy-stamp" "0" "$?"

# --- LC7/LC8/LC9: unstamped, unagreed, orphan ---------------------------------------------------
R=$(fresh lc7); A=$(lattach "$R" local); copy "$A/spec.gdrive.local.md"
out=$(bash "$RD" check "$R" 2>&1); rc=$?
check "LC7 unstamped" "1:yes" "$rc:$(has "$out" "LOCAL COPY UNSTAMPED: $A/spec.gdrive.local.md")"
R=$(fresh lc8); A=$(lattach "$R" none); copy "$A/spec.gdrive.local.md"
out=$(bash "$RD" check "$R" 2>&1); rc=$?
check "LC8 not agreed" "1:yes" "$rc:$(has "$out" "LOCAL COPY NOT AGREED: $A/spec.gdrive.local.md")"
R=$(fresh lc9); A=$(lattach "$R" local); copy "$A/gone.gdrive.local.md"
out=$(bash "$RD" check "$R" 2>&1); rc=$?
check "LC9 orphan copy" "1:yes" "$rc:$(has "$out" "LOCAL COPY ORPHAN: $A/gone.gdrive.local.md")"
check "LC9b a copy is not a remote card" "no" "$(has "$out" "REMOTE INCOMPLETE: $A/gone.gdrive.local.md")"

# --- LC11: list names the copy in a 6th field ----------------------------------------
R=$(fresh lc11); A=$(lattach "$R" local); copy "$A/spec.gdrive.local.md"
rcard "$A/other.gdrive.md" "Other"
out=$(bash "$RD" list "$R")
check "LC11a copy named" "$A/spec.gdrive.local.md" "$(echo "$out" | awk -F'\t' -v c="$A/spec.gdrive.md" '($1 "") == c { print $6 }')"
check "LC11b no copy: -" "-" "$(echo "$out" | awk -F'\t' -v c="$A/other.gdrive.md" '($1 "") == c { print $6 }')"
check "LC11c the copy is not listed as a card" "no" "$(has "$out" "$(printf '%s/spec.gdrive.local.md\t' "$A")")"

echo "== artifact remote cards (PLUG-141) =="

TA1=2026-11-16T10:00:00Z; TA2=2026-11-16T12:30:00+01:00
# acard <path> <description> <id> [modified] [url-suffix] — a Claude Artifact remote card
acard() {
    mkdir -p "$(dirname "$1")"
    printf -- '---\ntitle: t\ndescription: %s\nread-when: x\nremote-id: %s\nremote-url: https://claude.ai/artifact/%s%s\nremote-type: html\nremote-modified: %s\n---\n\n# A\n' \
      "$2" "$3" "$3" "${5:-}" "${4:-$TA1}" > "$1"
}
# aattach <root> [publish] — external/proto: .source.md for artifacts (no container) and two cards
aattach() {
    local A="$1/external/proto"
    mkdir -p "$A"
    printf -- '---\nprovider: artifact\ncontent: remote\nprocessed: none\npublish: %s\n---\n' "${2:-commit}" > "$A/.source.md"
    acard "$A/dashboard.artifact.md" "Dashboard" a1
    acard "$A/prototype.artifact.md" "Prototype" b2
    echo "$A"
}

# --- AR1: an artifact card is a remote card like any other ---------------------------------
R=$(fresh ar1); A=$(aattach "$R")
st=$(bash "$RD" status "$R" 2>&1)
check "AR1b status: remote row" "yes" "$(has "$st" "$(printf 'remote\tfiled\t-\t%s/dashboard.artifact.md' "$A")")"
for c in dashboard prototype; do bash "$RD" extracted "$A/$c.artifact.md" >/dev/null; done   # reviewed for decisions (PLUG-149)
bash "$RD" check "$R" >/dev/null 2>&1; check "AR1c check clean" "0" "$?"
out=$(bash "$RD" list "$R")
check "AR1d list lists it" "yes" "$(has "$out" "$(printf '%s/prototype.artifact.md\tcommit\t%s\tPrototype' "$A" "$TA1")")"

# --- AR2: stamp takes a time with an offset, still rejects junk --------------------
out=$(bash "$RD" stamp "$A/dashboard.artifact.md" "$TA2" 2>&1); rc=$?
check "AR2a offset time stamped" "0:yes" "$rc:$(has "$(cat "$A/dashboard.artifact.md")" "remote-modified: $TA2")"
bash "$RD" stamp "$A/dashboard.artifact.md" "2026-11-16 12:30" >/dev/null 2>&1
check "AR2b a time without T and zone rejected" "1" "$?"
bash "$RD" stamp "$A/dashboard.artifact.md" "2026-11-16T12:30:00+0100" >/dev/null 2>&1
check "AR2c an offset without a colon rejected" "1" "$?"

# --- AR3: no container in .source.md -> carded only: changed and gone, never new ------------
R=$(fresh ar3); A=$(aattach "$R")
listing "a1|Dashboard|html|$TA2" "c3|Somebody's other artifact|html|$TA1" > "$R/l.tsv"
out=$(diff_of "$A" "$R/l.tsv")
check "AR3a changed" "yes" "$(has "$out" "$(printf 'changed\ta1\t%s/dashboard.artifact.md\t%s' "$A" "$TA2")")"
check "AR3b missing from the listing: gone" "yes" "$(has "$out" "$(printf 'gone\tb2\t%s/prototype.artifact.md' "$A")")"
check "AR3c an uncarded artifact is never new" "no" "$(has "$out" 'c3')"
check "AR3d exactly two records" "2" "$(echo "$out" | grep -c .)"

# --- AR4: the diff compares only the cards of the attachment's provider ---------------------
R=$(fresh ar4); A=$(aattach "$R")
rcard "$A/sheet.gdrive.md" "Sheet" - 1g "$T1"
listing "a1|Dashboard|html|$TA1" "b2|Prototype|html|$TA1" > "$R/l.tsv"
out=$(diff_of "$A" "$R/l.tsv")
check "AR4a a Drive card beside artifact cards is not gone" "0" "$(echo "$out" | grep -c .)"
printf -- '---\nremote-id: F0\n---\n' > "$R/s.md"
mkdir -p "$R/external/old"; cp "$R/s.md" "$R/external/old/.source.md"
rcard "$R/external/old/a.gdrive.md" "A" - 1a "$T1"
listing "1a|a|$DOCMIME|$T1" > "$R/l2.tsv"
out=$(diff_of "$R/external/old" "$R/l2.tsv")
check "AR4b no provider: field means gdrive (older .source.md)" "0" "$(echo "$out" | grep -c .)"

# --- AR5: an access key never sits in a committed card ---------------------------------------
R=$(fresh ar5); A=$(aattach "$R")
acard "$A/keyed.artifact.md" "Keyed" k9 "$TA1" "?sk=s3cr3t"
acard "$A/task.artifact.md" "Task" t1 "$TA1" "?task=1&ask=2"
out=$(bash "$RD" check "$R" 2>&1); rc=$?
check "AR5a key in remote-url fails check" "1:yes" "$rc:$(has "$out" "REMOTE KEY: $A/keyed.artifact.md")"
check "AR5b a parameter merely ending in sk is no key" "no" "$(has "$out" "REMOTE KEY: $A/task.artifact.md")"
check "AR5c the key itself is not printed" "no" "$(has "$out" 's3cr3t')"
st=$(bash "$RD" status "$R" 2>&1)
check "AR5d status: keyed row" "yes" "$(has "$st" "$(printf 'keyed\tfiled\t-\t%s/keyed.artifact.md' "$A")")"
acard "$A/keyed.artifact.md" "Keyed" k9
printf '\n[open](https://claude.ai/artifact/k9?x=1&sk=s3cr3t)\n' >> "$A/keyed.artifact.md"
out=$(bash "$RD" check "$R" 2>&1)
check "AR5e key in a body link fails too" "yes" "$(has "$out" "REMOTE KEY: $A/keyed.artifact.md")"
R=$(fresh ar5b); A=$(aattach "$R" local)
acard "$A/keyed.artifact.md" "Keyed" k9
printf 'remote-key-url: https://claude.ai/artifact/k9?sk=s3cr3t\n' > "$R/kl"
awk -v f="$R/kl" 'NR > 1 && /^---$/ && !d { while ((getline l < f) > 0) print l; d = 1 } { print }' \
  "$A/keyed.artifact.md" > "$R/t" && mv "$R/t" "$A/keyed.artifact.md"
out=$(bash "$RD" check "$R" 2>&1)
check "AR5f a publish: local folder may keep the key" "no" "$(has "$out" 'REMOTE KEY')"
rcard "$R/external/drive/doc.gdrive.md" "D" - 1d "$T1"
printf '\n[x](https://docs.google.com/document/d/1d/edit?usp=sharing&sk=1)\n' >> "$R/external/drive/doc.gdrive.md"
out=$(bash "$RD" check "$R" 2>&1)
check "AR5g key parameters are per provider (Drive has none)" "no" "$(has "$out" 'REMOTE KEY: '"$R/external/drive/doc.gdrive.md")"

echo "== git-ignored attachments and copies (PLUG-112, PLUG-115) =="

# bash:5 has no git: these cases are reported as skipped there (or `apk add git` first).
HAVE_GIT=no; command -v git >/dev/null 2>&1 && HAVE_GIT=yes
needs_git() { [ "$HAVE_GIT" = yes ] && return 0; skipped=$((skipped+1)); echo "  skip $1 (no git here)"; return 1; }

# --- RC9: a git-ignored attachment is still listed --------------------------------------------
if needs_git RC9; then
  R=$(fresh rc9)
  doc "$R/docs/a.md" "Doc A" </dev/null
  mkdir -p "$R/docs/external/private"
  printf -- '---\ntitle: t\ndescription: Private contract\nread-when: pricing\nremote-id: 1x\nremote-modified: 2026-11-10T13:37:23Z\n---\n' \
    > "$R/docs/external/private/contract.gdrive.md"
  printf -- '---\nprovider: gdrive\npublish: local\n---\n' > "$R/docs/external/private/.source.md"
  printf 'docs/external/private/\n' > "$R/.gitignore"
  git -C "$R" init -q
  out=$(bash "$RD" list "$R/docs" 2>&1)
  check "RC9b list names it, publish local" "yes" \
    "$(has "$out" "$(printf '%s/docs/external/private/contract.gdrive.md\tlocal\t2026-11-10T13:37:23Z\tPrivate contract\tpricing' "$R")")"
fi

# --- LC10: a git-ignored local copy is still checked -------------------------------------------
if needs_git LC10; then
  R=$(fresh lc10)
  doc "$R/docs/a.md" "Doc A" </dev/null
  mkdir -p "$R/docs/external/acme"
  printf -- '---\ntitle: t\ndescription: Spec\nread-when: x\nremote-id: 1s\nremote-modified: 2026-11-12T09:00:00Z\ncopy-modified: 2026-11-11T17:27:11Z\n---\n' \
    > "$R/docs/external/acme/spec.gdrive.md"
  printf -- '---\nprovider: gdrive\nprocessed: local\ncopy-publish: local\n---\n' > "$R/docs/external/acme/.source.md"
  printf 'text\n' > "$R/docs/external/acme/spec.gdrive.local.md"
  printf 'docs/external/acme/*.gdrive.local.md\n' > "$R/.gitignore"
  git -C "$R" init -q
  out=$(bash "$RD" check "$R/docs" 2>&1)
  check "LC10 ignored copy still reported stale" "yes" "$(has "$out" "LOCAL COPY STALE: $R/docs/external/acme/spec.gdrive.local.md")"
fi

echo "== folder purpose and scope (PLUG-145) =="

# src <dir> <line>... — write <dir>/.source.md holding the given `key: value` lines
src() { local d="$1"; shift; mkdir -p "$d"; { echo ---; for l in "$@"; do echo "$l"; done; echo ---; } > "$d/.source.md"; }
pur() { bash "$RD" purpose "$@" 2>&1 | tr '\t' '|'; }   # pur <path> <root> -> record, | for tab

# --- PP1: a suggested purpose brings its settings; folders inherit, per key ---------------------
R=$(fresh pp1); A="$R/external/team"
src "$A" "provider: gdrive" "purpose: agreements" "scope: team"
src "$A/drafts" "purpose: collaboration"
mkdir -p "$A/specs/deep"
check "PP1a suggested purpose brings writes, truth, cards" "agreements|propose|yes|team|files|$A/.source.md" "$(pur "$A" "$R")"
check "PP1b a folder without .source.md inherits" "agreements|propose|yes|team|files|$A/.source.md" "$(pur "$A/specs/deep" "$R")"
check "PP1c the nearer purpose wins; scope still inherited" "collaboration|free|no|team|pointer|$A/drafts/.source.md" "$(pur "$A/drafts" "$R")"
check "PP1d a file resolves as its folder" "$(pur "$A/drafts" "$R")" "$(pur "$A/drafts/x.gdrive.md" "$R")"
check "PP1e a purpose-only .source.md keeps the parent's provider for list" "yes" \
    "$(rcard "$A/drafts/n.gdrive.md"; src "$A" "provider: gdrive" "purpose: agreements" "scope: team" "publish: local"; has "$(bash "$RD" list "$R")" "$(printf '%s/drafts/n.gdrive.md\tlocal\t' "$A")")"

# --- PP2: an explicit key overrides the purpose's default ----------------------------------------
src "$A/drafts" "purpose: collaboration" "writes: propose" "cards: files"
check "PP2 explicit writes and cards win" "collaboration|propose|no|team|files|$A/drafts/.source.md" "$(pur "$A/drafts" "$R")"

# --- PP3: nothing declared: the fallback, and a note that is not a failure ----------------------
R=$(fresh pp3); X="$R/external/x"; mkdir -p "$X"
check "PP3a fallback" "-|never|no|project|files|-" "$(pur "$X" "$R")"
src "$X" "provider: gdrive"
out=$(bash "$RD" check "$R" 2>&1); rc=$?
check "PP3b undeclared attachment: PURPOSE? note, check passes" "0:yes" "$rc:$(has "$out" "PURPOSE?: $X")"
src "$R/external" "scopes: [user, project, team, company]"
out=$(bash "$RD" check "$R" 2>&1)
check "PP3c a .source.md that is no attachment gets no note" "no" "$(has "$out" "PURPOSE?: $R/external ")"

# --- PP4: a custom purpose implies nothing; it needs writes and truth -----------------------------
src "$X" "provider: gdrive" "purpose: client deliverables for review"
out=$(bash "$RD" check "$R" 2>&1); rc=$?
check "PP4a custom purpose without writes/truth fails" "1:yes" "$rc:$(has "$out" "PURPOSE INCOMPLETE: $X")"
check "PP4b custom purpose implies nothing" "client deliverables for review|never|no|project|files|$X/.source.md" "$(pur "$X" "$R")"
src "$X" "provider: gdrive" "purpose: client deliverables for review" "writes: propose" "truth: no"
bash "$RD" check "$R" >/dev/null 2>&1; check "PP4c complete custom purpose passes" "0" "$?"

# --- PP5: a value outside the lists fails --------------------------------------------------------
src "$X" "provider: gdrive" "purpose: output" "writes: sometimes"
out=$(bash "$RD" check "$R" 2>&1); rc=$?
check "PP5 BAD SETTING" "1:yes" "$rc:$(has "$out" "BAD SETTING: $X/.source.md writes=sometimes")"

# --- PP6: a custom scope must be placed in the order ----------------------------------------------
src "$X" "provider: gdrive" "purpose: output" "scope: client"
out=$(bash "$RD" check "$R" 2>&1); rc=$?
check "PP6a scope outside scopes fails" "1:yes" "$rc:$(has "$out" "SCOPE UNKNOWN: $X/.source.md client")"
src "$R/external" "scopes: [user, project, client, team, company]"
bash "$RD" check "$R" >/dev/null 2>&1; check "PP6b placed in scopes: passes" "0" "$?"
check "PP6c resolved scope" "output|free|no|client|files|$X/.source.md" "$(pur "$X" "$R")"

# --- PP7: purposes — the map of every declared folder ---------------------------------------------
out=$(bash "$RD" purposes "$R" | tr '\t' '|')
check "PP7a one row per .source.md folder" "2" "$(echo "$out" | grep -c .)"
check "PP7b row" "yes" "$(has "$out" "$X|output|free|no|client|files|$X/.source.md")"

# --- PP8: a collaboration folder has one pointer card; diff compares the newest time ------------
R=$(fresh pp8); A="$R/external/collab"
src "$A" "provider: gdrive" "purpose: collaboration" "remote-id: FOLD"
printf 'f1\tnotes\tapplication/vnd.google-apps.document\t2026-11-10T09:00:00.000Z\nf2\tsub/plan\tapplication/vnd.google-apps.spreadsheet\t2026-11-10T10:00:00.000Z\n' > "$R/l.tsv"
out=$(bash "$RD" diff "$A" "$R/l.tsv" 2>&1)
check "PP8a no pointer card yet: the folder is new" "$(printf 'new\tFOLD\t.\tapplication/vnd.google-apps.folder\t2026-11-10T10:00:00.000Z')" "$out"
rcard "$A/collab.gdrive.md" "Team working folder" - FOLD "2026-11-10T10:00:00.000Z"
check "PP8b in step: nothing, and no file is new" "" "$(bash "$RD" diff "$A" "$R/l.tsv" 2>&1)"
printf 'f2\tsub/plan\tapplication/vnd.google-apps.spreadsheet\t2026-11-10T11:00:00.000Z\n' >> "$R/l.tsv"
check "PP8c a file changed: the pointer is changed" "$(printf 'changed\tFOLD\t%s/collab.gdrive.md\t2026-11-10T11:00:00.000Z' "$A")" "$(bash "$RD" diff "$A" "$R/l.tsv" 2>&1)"
src "$A" "provider: gdrive" "purpose: collaboration"
bash "$RD" diff "$A" "$R/l.tsv" >/dev/null 2>&1; check "PP8d pointer without remote-id: refused" "1" "$?"

echo "== attachment questions (PLUG-146) =="

q() { bash "$RD" questions "$@" 2>&1 | paste -sd, -; }   # q <dir> <root> -> unanswered, comma-joined

# --- AQ1: no git: never the publish questions ---------------------------------------------------
R=$(fresh aq1); A="$R/external/new"
check "AQ1a new folder, no git: purpose and cards-at" "purpose,cards-at" "$(q "$A" "$R")"
src "$A" "provider: gdrive" "purpose: reference"
check "AQ1b a recorded answer is not asked again" "cards-at" "$(q "$A" "$R")"
src "$A" "provider: gdrive" "purpose: reference" "cards-at: local" "processed: local"
check "AQ1c all answered; no publish or copy-publish without git" "" "$(q "$A" "$R")"
src "$A" "provider: gdrive" "purpose: our client's drafts" "cards-at: local"
check "AQ1d a custom purpose asks writes and truth" "writes,truth" "$(q "$A" "$R")"
src "$R/external" "purpose: reference" "cards-at: drive"
check "AQ1e answers inherited from a parent count" "" "$(q "$R/external/other" "$R")"
src "$A" "provider: gdrive" "purpose: reference" "cards-at: cloud"
out=$(bash "$RD" check "$R" 2>&1); rc=$?
check "AQ1f cards-at is local or drive" "1:yes" "$rc:$(has "$out" "BAD SETTING: $A/.source.md cards-at=cloud")"

# --- AQ2: in a git repo the publish questions come back ------------------------------------------
if needs_git AQ2; then
  R=$(fresh aq2); git -C "$R" init -q; A="$R/docs/external/new"
  check "AQ2a git: publish asked too" "purpose,cards-at,publish" "$(q "$A" "$R/docs")"
  src "$A" "provider: gdrive" "purpose: reference" "cards-at: local" "publish: commit" "processed: local"
  check "AQ2b local copies agreed: copy-publish asked" "copy-publish" "$(q "$A" "$R/docs")"
  src "$A" "provider: gdrive" "purpose: reference" "cards-at: local" "publish: commit" "processed: local" "copy-publish: local"
  check "AQ2c all answered" "" "$(q "$A" "$R/docs")"
fi

echo "== writing to the provider (PLUG-147) =="

W1=2026-11-10T13:37:23.036Z; W2=2026-11-12T08:00:00.000Z
gd() { bash "$RD" guard "$@" 2>&1; }

# --- WG: guard — read-only, stale, propose, ok; inherited; wider scope proposes -----------------
R=$(fresh wg); A="$R/external/team"
src "$A" "provider: gdrive" "purpose: reference"
rcard "$A/spec.gdrive.md" "Spec" - ID1 "$W1"
out=$(gd "$A/spec.gdrive.md" "$W1"); rc=$?
check "WG1 writes: never -> READ-ONLY, exit 3" "3:yes" "$rc:$(has "$out" "READ-ONLY")"
src "$A" "provider: gdrive" "purpose: agreements"
out=$(gd "$A/spec.gdrive.md" "$W2"); rc=$?
check "WG2 changed since the card was stamped -> STALE, exit 1" "1:yes" "$rc:$(has "$out" "STALE: $A/spec.gdrive.md card $W1, provider $W2")"
out=$(gd "$A/spec.gdrive.md" "$W1"); rc=$?
check "WG3 writes: propose -> PROPOSE, exit 0" "0:yes" "$rc:$(has "$out" "PROPOSE")"
src "$A" "provider: gdrive" "purpose: output"
out=$(gd "$A/spec.gdrive.md" "$W1"); rc=$?
check "WG4 writes: free, project scope -> OK" "0:OK" "$rc:$out"
rcard "$A/sub/deep.gdrive.md" "Deep" - ID2 "$W1"
check "WG5 a sub-folder card inherits writes" "OK" "$(gd "$A/sub/deep.gdrive.md" "$W1")"
src "$A" "provider: gdrive" "purpose: output" "scope: team"
out=$(gd "$A/spec.gdrive.md" "$W1"); rc=$?
check "WG6 writes: free in a team folder still proposes" "0:yes" "$rc:$(has "$out" "PROPOSE (scope team")"
gd "$A/spec.gdrive.md" "yesterday" >/dev/null; check "WG7 a bad time is refused" "1" "$?"
gd "$A/nope.gdrive.md" "$W1" >/dev/null; check "WG8 a missing card is refused" "1" "$?"

# --- RP: repoint — an Office file converted to a Google file: new id, new name ------------------
R=$(fresh rp); A="$R/external/team"
src "$A" "provider: gdrive" "purpose: output" "processed: local"
rcard "$A/plan.docx.gdrive.md" "Plan" - OLD "$W1"; printf 'text\n' > "$A/plan.docx.gdrive.local.md"
out=$(bash "$RD" repoint "$A/plan.docx.gdrive.md" NEW "https://docs.google.com/document/d/NEW/edit" application/vnd.google-apps.document "$W2" 2>&1); rc=$?
c="$A/plan.gdrive.md"
check "RP1a renamed without the Office extension" "0:no:yes" "$rc:$([ -f "$A/plan.docx.gdrive.md" ] && echo yes || echo no):$([ -f "$c" ] && echo yes || echo no)"
check "RP1b says where" "yes" "$(has "$out" "REPOINTED: $c (was $A/plan.docx.gdrive.md)")"
check "RP1c fields" "NEW|https://docs.google.com/document/d/NEW/edit|application/vnd.google-apps.document|$W2|OLD" \
    "$( . "$(dirname "$RD")/lib.sh"; for k in remote-id remote-url remote-type remote-modified converted-from; do fm_field "$c" "$k"; done | paste -sd'|' - )"
check "RP1d the local copy follows" "yes" "$([ -f "$A/plan.gdrive.local.md" ] && echo yes || echo no)"
rcard "$A/a.gdrive.md" "A" - A1 "$W1"
bash "$RD" repoint "$A/a.gdrive.md" A2 "https://docs.google.com/document/d/A2/edit" application/vnd.google-apps.document "$W2" >/dev/null 2>&1
check "RP2 a card without an Office extension keeps its name" "yes:A2" "$([ -f "$A/a.gdrive.md" ] && echo yes):$( . "$(dirname "$RD")/lib.sh"; fm_field "$A/a.gdrive.md" remote-id)"
rcard "$A/b.xlsx.gdrive.md" "B" - B1 "$W1"; rcard "$A/b.gdrive.md" "B taken" - B9 "$W1"
bash "$RD" repoint "$A/b.xlsx.gdrive.md" B2 "u" application/vnd.google-apps.spreadsheet "$W2" >/dev/null 2>&1
check "RP3 refused when the new name is taken" "1:B1" "$?:$( . "$(dirname "$RD")/lib.sh"; fm_field "$A/b.xlsx.gdrive.md" remote-id)"
bash "$RD" repoint "$A/a.gdrive.md" A3 u t "soon" >/dev/null 2>&1; check "RP4 a bad time is refused" "1" "$?"

echo "== cards kept on Drive: pack and unpack (PLUG-148) =="

same() { cmp -s "$1" "$2" && echo yes || echo no; }

# --- CD1: pack -> unpack -> pack is byte-identical; local copies stay out -------------------------
R=$(fresh cd); A="$R/external/team"
src "$A" "provider: gdrive" "purpose: agreements" "remote-id: FOLD" "cards-at: drive"
src "$A/drafts" "purpose: collaboration"
rcard "$A/a.gdrive.md" "A" - A1 "$W1"; rcard "$A/drafts/b.gdrive.md" "B" - B1 "$W1"
printf 'copy\n' > "$A/a.gdrive.local.md"
bash "$RD" pack "$A" > "$R/doc.md" 2>"$R/err"; rc=$?
check "CD1a pack succeeds" "0" "$rc"
check "CD1b .source.md files first, then cards, sorted" ".source.md|drafts/.source.md|a.gdrive.md|drafts/b.gdrive.md" \
    "$(sed -n 's/^<!-- remote-docs: \(.*\) -->$/\1/p' "$R/doc.md" | paste -sd'|' -)"
check "CD1c a local copy is never packed" "no" "$(has "$(cat "$R/doc.md")" 'a.gdrive.local.md')"
U="$R/unpacked"
bash "$RD" unpack "$R/doc.md" "$U" >/dev/null 2>&1; check "CD1d unpack succeeds" "0" "$?"
check "CD1e every file comes back as it was" "yes|yes|yes|yes" \
    "$(same "$A/.source.md" "$U/.source.md")|$(same "$A/drafts/.source.md" "$U/drafts/.source.md")|$(same "$A/a.gdrive.md" "$U/a.gdrive.md")|$(same "$A/drafts/b.gdrive.md" "$U/drafts/b.gdrive.md")"
bash "$RD" pack "$U" > "$R/doc2.md"; check "CD1f pack of the unpacked set is byte-identical" "yes" "$(same "$R/doc.md" "$R/doc2.md")"
printf '# Team cards\n\nKept by remote-docs.\n\n' | cat - "$R/doc.md" > "$R/doc3.md"
bash "$RD" unpack "$R/doc3.md" "$R/u3" >/dev/null 2>&1
check "CD1g text before the first marker (a title) is ignored" "0:yes" "$?:$(same "$A/a.gdrive.md" "$R/u3/a.gdrive.md")"

# --- CD2: the scripts work on an unpacked set as on a local one -----------------------------------
rm -f "$A/a.gdrive.local.md"   # local copies never travel (CD1c), so compare without one
o1=$(bash "$RD" check "$A" 2>&1 | sed "s#$A#X#g"); o2=$(bash "$RD" check "$U" 2>&1 | sed "s#$U#X#g")
check "CD2a check gives the same result" "$o1" "$o2"
printf 'A1\ta\tapplication/pdf\t%s\nB1\tdrafts/b\tapplication/pdf\t%s\n' "$W2" "$W1" > "$R/l.tsv"
o1=$(bash "$RD" diff "$A" "$R/l.tsv" | sed "s#$A#X#g"); o2=$(bash "$RD" diff "$U" "$R/l.tsv" | sed "s#$U#X#g")
check "CD2b diff gives the same result" "$o1" "$o2"
check "CD2c and it is not empty" "yes" "$(has "$o2" 'changed')"

# --- CD3: unpack refuses anything that is not a card set, and writes nothing then -----------------
bad() { printf '<!-- remote-docs: %s -->\nx\n' "$1" > "$R/bad.md"; rm -rf "$R/ub"; bash "$RD" unpack "$R/bad.md" "$R/ub" >/dev/null 2>&1; echo "$?:$(ls -A "$R/ub" 2>/dev/null | wc -l | tr -d ' ')"; }
check "CD3a ../ refused" "1:0" "$(bad '../escape.gdrive.md')"
check "CD3b an absolute path refused" "1:0" "$(bad '/tmp/abs.gdrive.md')"
check "CD3c a file that is no card refused" "1:0" "$(bad 'notes.txt')"
check "CD3d a local copy refused" "1:0" "$(bad 'a.gdrive.local.md')"
{ cat "$R/doc.md"; printf '<!-- remote-docs: ../x.gdrive.md -->\nx\n'; } > "$R/bad2.md"; rm -rf "$R/ub"
bash "$RD" unpack "$R/bad2.md" "$R/ub" >/dev/null 2>&1
check "CD3e one bad path: nothing at all is written" "1:0" "$?:$(ls -A "$R/ub" 2>/dev/null | wc -l | tr -d ' ')"
bash "$RD" unpack "$R/doc.md" "$U" >/dev/null 2>&1; check "CD3f a folder that is not empty is refused" "1" "$?"
printf '<!-- remote-docs: x.gdrive.md -->\n' >> "$A/a.gdrive.md"
bash "$RD" pack "$A" >/dev/null 2>&1; check "CD3g pack refuses a card holding a marker line" "1" "$?"

echo "== extracting decisions (PLUG-149) =="

fmv() { ( . "$(dirname "$RD")/lib.sh"; fm_field "$1" "$2" ); }

# --- EX1: a card in a truth: no folder is reviewed for decisions; the stamp says when -------------
R=$(fresh ex); A="$R/external/out"
src "$A" "provider: gdrive" "purpose: output"
rcard "$A/report.gdrive.md" "Report" - R1 "$W1"
out=$(bash "$RD" check "$R" 2>&1); rc=$?
check "EX1a never extracted: EXTRACT?, check fails" "1:yes" "$rc:$(has "$out" "EXTRACT?: $A/report.gdrive.md")"
out=$(bash "$RD" extracted "$A/report.gdrive.md" 2>&1)
check "EX1b extracted records the card's time" "$W1:yes" "$(fmv "$A/report.gdrive.md" extracted-at):$(has "$out" 'STAMPED')"
bash "$RD" check "$R" >/dev/null 2>&1; check "EX1c check clean after it" "0" "$?"
check "EX1d a second run changes nothing" "yes" "$(has "$(bash "$RD" extracted "$A/report.gdrive.md")" 'UNCHANGED')"
bash "$RD" stamp "$A/report.gdrive.md" "$W2" >/dev/null 2>&1
out=$(bash "$RD" check "$R" 2>&1); rc=$?
check "EX1e the file changed: EXTRACT? again; stamp never writes extracted-at" "1:yes:$W1" "$rc:$(has "$out" "EXTRACT?: $A/report.gdrive.md")$(:):$(fmv "$A/report.gdrive.md" extracted-at)"

# --- EX2: where decisions live, reference material, or nothing declared: never asked --------------
for p in agreements reference; do
  src "$A" "provider: gdrive" "purpose: $p"
  bash "$RD" check "$R" >/dev/null 2>&1; check "EX2 $p folder: no EXTRACT?" "0" "$?"
done
src "$A" "provider: gdrive"
out=$(bash "$RD" check "$R" 2>&1)
check "EX2 undeclared folder: no EXTRACT?" "no" "$(has "$out" 'EXTRACT?')"
src "$A" "provider: gdrive" "purpose: client review copies" "writes: free" "truth: no"
out=$(bash "$RD" check "$R" 2>&1)
check "EX3 a custom purpose with truth: no is reviewed" "yes" "$(has "$out" "EXTRACT?: $A/report.gdrive.md")"

# --- EX4: an artifact is never where a decision lives, whatever its folder says -------------------
R=$(fresh ex4); A="$R/external/proto"
src "$A" "provider: artifact" "purpose: reference"
printf -- '---\ntitle: t\ndescription: Dashboard\nremote-id: a1\nremote-url: https://claude.ai/artifact/a1\nremote-modified: %s\n---\n' "$W1" > "$A/dash.artifact.md"
out=$(bash "$RD" check "$R" 2>&1)
check "EX4 artifact in a reference folder: EXTRACT?" "yes" "$(has "$out" "EXTRACT?: $A/dash.artifact.md")"

# --- EX5: extracted needs a complete card ----------------------------------------------------------
rcard "$A/x.gdrive.md" "X" remote-modified
bash "$RD" extracted "$A/x.gdrive.md" >/dev/null 2>&1; check "EX5 incomplete card refused" "1" "$?"

echo "== how-to examples (PLUG-140) =="
# The how-to examples parse as their prose says (moved from docs-manager, PLUG-140/PLUG-144): the folder attachment's .source.md, the only
# unindented `provider: gdrive` block in the how-to, copied out as a user would
HOWTO="$(dirname "$RD")/../skills/remote-docs/references/how-to-remote-docs.md"; LIB="$(dirname "$RD")/lib.sh"
R=$(fresh fc14)
awk '/^provider: gdrive$/ { on = 1 } on && /^---$/ { exit } on { print }' "$HOWTO" \
  | { echo ---; cat; echo ---; } > "$R/src.md"
check "FC14 how-to folder example: include is a list" "specs/*,*.pdf" \
  "$( . "$LIB"; fm_list "$R/src.md" include | paste -sd, - )"
check "FC15 how-to folder example: recursive is true" "true" "$( . "$LIB"; fm_field "$R/src.md" recursive )"

echo "== the card contract shared with docs-manager (PLUG-144) =="

# --- CT1: the names and fields this plugin reads. docs-manager lists the same names with ☁; a change
# here is a change to both plugins, so this case and docs-manager's CT1 move together. ----------
R=$(fresh ct1); A="$R/external/c"; mkdir -p "$A"
printf -- '---\nprovider: gdrive\npublish: commit\nprocessed: local\n---\n' > "$A/.source.md"
rcard "$A/d.gdrive.md" "Drive doc"; acard "$A/p.artifact.md" "Artifact" a1
copy "$A/d.gdrive.local.md"; doc "$A/plain.md" </dev/null; doc "$A/x.notaprovider.md" </dev/null
st=$(bash "$RD" status "$R")
check "CT1a cards: <name>.gdrive.md and <name>.artifact.md" "2" "$(echo "$st" | grep -c "^remote	")"
check "CT1b copy: <name>.<provider>.local.md" "yes" "$(has "$st" "$A/d.gdrive.local.md")"
check "CT1c any other .md is not a card" "nono" "$(has "$st" plain.md)$(has "$st" notaprovider)"
li=$(bash "$RD" list "$R")
check "CT1d fields read: description, read-when, remote-modified; publish from .source.md" "yes" \
  "$(has "$li" "$(printf '%s/d.gdrive.md\tcommit\t2026-11-10T13:37:23.036Z\tDrive doc\tmapping vendor codes\t%s/d.gdrive.local.md' "$A" "$A")")"

echo
echo "passed: $pass   failed: $fail   skipped: $skipped"
[ "$fail" -eq 0 ]
