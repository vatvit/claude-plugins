#!/usr/bin/env bash
# Tests for external files (pdf, docx, xlsx, …) and their cards: index listing,
# status/check, stamp and move.
#
# Dual-target, like diagram.test.sh — run on the host (bash 3.2 + BSD) and in a container:
#
#   bash docs-manager/scripts/test/external.test.sh
#   docker run --rm -v "$PWD":/w -w /w bash:5 bash docs-manager/scripts/test/external.test.sh
set -uo pipefail

DOCS="$(cd "$(dirname "$0")/.." && pwd)/docs.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0

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
bin() { mkdir -p "$(dirname "$1")"; printf '%s' "${2:-%PDF-1.4 fake}" > "$1"; }   # bin <path> [bytes]

echo "== index =="

# --- E1: a card is listed under its external file, not as a document --------
R=$(fresh e1)
bin "$R/external/vendor/spec.pdf"
doc "$R/external/vendor/spec.pdf.md" "Vendor payments contract" </dev/null
doc "$R/external/vendor/notes.md" "Our notes" </dev/null
bin "$R/external/vendor/budget.xlsx" "PK fake"
bash "$DOCS" index --write "$R" >/dev/null 2>&1
idx=$(cat "$R/external/vendor/_index.md")
check "E1a External documents section" "yes" "$(has "$idx" '### External documents')"
check "E1b card listed by its file, linked to the card" "yes" \
  "$(has "$idx" '- [`spec.pdf`](spec.pdf.md) — Vendor payments contract')"
check "E1c card not listed as a document" "no" "$(has "$idx" '[`spec.pdf.md`]')"
check "E1d authored doc still a document" "yes" "$(has "$idx" '- [`notes.md`](notes.md) — Our notes')"
check "E1e uncarded file listed, linked to itself" "yes" \
  "$(has "$idx" '- [`budget.xlsx`](budget.xlsx) — _(no card yet)_')"
before=$(cat "$R/external/vendor/_index.md")
bash "$DOCS" index --write "$R" >/dev/null 2>&1
check "E1f idempotent" "same" "$([ "$before" = "$(cat "$R/external/vendor/_index.md")" ] && echo same || echo changed)"
bash "$DOCS" index --check "$R" >/dev/null 2>&1; check "E1g index --check clean" "0" "$?"

# --- E2: no externals -> no section, so existing indexes do not drift ---------
R=$(fresh e2)
doc "$R/a.md" </dev/null
bash "$DOCS" index --write "$R" >/dev/null 2>&1
check "E2 no External section without externals" "no" "$(has "$(cat "$R/_index.md")" 'External documents')"

# --- E3: a rendered diagram artifact is not an external file ------------------
R=$(fresh e3)
doc "$R/a.md" </dev/null
printf -- '---\ntitle: s\n---\n\n```mermaid\na-->b\n```\n' > "$R/flow.diagram.md"
bin "$R/flow.pdf"
bash "$DOCS" index --write "$R" >/dev/null 2>&1
check "E3a artifact not indexed as external" "no" "$(has "$(cat "$R/_index.md")" 'flow.pdf')"
check "E3b artifact not reported" "" "$(bash "$DOCS" external status "$R" 2>&1)"

# --- E4: links to a card and to the file resolve; a missing file is caught ----
R=$(fresh e4)
bin "$R/external/vendor/spec.pdf"
doc "$R/external/vendor/spec.pdf.md" </dev/null
doc "$R/arch/pay.md" <<'EOF'
See [the spec card](../external/vendor/spec.pdf.md) and [the spec](../external/vendor/spec.pdf#page=4).
EOF
bash "$DOCS" links "$R" >/dev/null 2>&1; check "E4a links to card and file resolve" "0" "$?"
rm "$R/external/vendor/spec.pdf"
out=$(bash "$DOCS" links "$R" 2>&1)
check "E4b link to a missing file reported" "yes" "$(has "$out" 'BROKEN LINK: '"$R"'/arch/pay.md -> ../external/vendor/spec.pdf')"

echo "== status / check / stamp =="

# --- S1: the four states, and placement ---------------------------------------
R=$(fresh s1)
bin "$R/external/inbox.pdf"                                     # new, unfiled
bin "$R/arch/diagram.DOCX" "PK"                                 # new, outside, upper-case ext
bin "$R/external/law/contract.pdf"; doc "$R/external/law/contract.pdf.md" </dev/null   # unstamped, filed
doc "$R/external/law/gone.pdf.md" </dev/null                    # orphan
st=$(bash "$DOCS" external status "$R" 2>&1)
check "S1a new + unfiled" "yes" "$(has "$st" "$(printf 'new\tunfiled\t%s/external/inbox.pdf\t-' "$R")")"
check "S1b new + outside, any case" "yes" "$(has "$st" "$(printf 'new\toutside\t%s/arch/diagram.DOCX\t-' "$R")")"
check "S1c unstamped + filed" "yes" \
  "$(has "$st" "$(printf 'unstamped\tfiled\t%s/external/law/contract.pdf\t%s/external/law/contract.pdf.md' "$R" "$R")")"
check "S1d orphan" "yes" "$(has "$st" "$(printf 'orphan\t-\t-\t%s/external/law/gone.pdf.md' "$R")")"
out=$(bash "$DOCS" external check "$R" 2>&1); rc=$?
check "S1e check fails" "1" "$rc"
check "S1f NO CARD reported" "yes" "$(has "$out" "NO CARD: $R/external/inbox.pdf")"
check "S1g UNSTAMPED reported" "yes" "$(has "$out" "UNSTAMPED: $R/external/law/contract.pdf.md")"
check "S1h ORPHAN reported" "yes" "$(has "$out" "ORPHAN CARD: $R/external/law/gone.pdf.md")"
out=$(bash "$DOCS" check "$R" 2>&1); rc=$?
check "S1i docs.sh check includes externals" "1:yes" "$rc:$(has "$out" "NO CARD: $R/external/inbox.pdf")"

# --- S2: stamp, idempotence, byte preservation, change detection ----------------
R=$(fresh s2)
bin "$R/external/law/contract.pdf" "version one"
cat > "$R/external/law/contract.pdf.md" <<'EOF'
---
title: Contract
description: The contract
read-when: legal questions
---

# Contract

## Where to look
| Topic | Location |
|---|---|
| Fees | p. 3 |
EOF
body_before=$(sed '1,/^---$/d' "$R/external/law/contract.pdf.md" | sed '1,/^---$/d')
out=$(bash "$DOCS" external stamp "$R/external/law/contract.pdf" 2>&1)
check "S2a STAMPED" "yes" "$(has "$out" "STAMPED: $R/external/law/contract.pdf.md")"
check "S2b digest recorded" "yes" "$(grep -q '^digest: sha256:[0-9a-f]\{64\}$' "$R/external/law/contract.pdf.md" && echo yes || echo no)"
check "S2c other frontmatter kept" "yes" "$(grep -q '^read-when: legal questions$' "$R/external/law/contract.pdf.md" && echo yes || echo no)"
check "S2d body byte-identical" "same" \
  "$([ "$body_before" = "$(sed '1,/^---$/d' "$R/external/law/contract.pdf.md" | sed '1,/^---$/d')" ] && echo same || echo changed)"
out=$(bash "$DOCS" external check "$R" 2>&1); rc=$?
check "S2e check clean after stamp, and silent" "0:" "$rc:$out"
check "S2e2 status says ok" "yes" "$(has "$(bash "$DOCS" external status "$R")" "$(printf 'ok\tfiled\t%s/external/law/contract.pdf' "$R")")"
snap=$(cat "$R/external/law/contract.pdf.md")
out=$(bash "$DOCS" external stamp "$R/external/law/contract.pdf.md" 2>&1)
check "S2f re-stamp via the card path is a no-op" "yes:same" \
  "$(has "$out" UNCHANGED):$([ "$snap" = "$(cat "$R/external/law/contract.pdf.md")" ] && echo same || echo changed)"
printf 'version two' > "$R/external/law/contract.pdf"
out=$(bash "$DOCS" external check "$R" 2>&1); rc=$?
check "S2g CHANGED after the file changes" "1:yes" "$rc:$(has "$out" "CHANGED: $R/external/law/contract.pdf")"

# --- S3: the digest is of bytes, not of a path — a copied tree stays clean -------
cp -R "$R" "$TMP/s3copy"
printf 'version one' > "$TMP/s3copy/external/law/contract.pdf"
bash "$DOCS" external stamp "$TMP/s3copy/external/law/contract.pdf" >/dev/null 2>&1
mv "$TMP/s3copy" "$TMP/s3moved"
bash "$DOCS" external check "$TMP/s3moved" >/dev/null 2>&1; check "S3 digest survives moving the checkout" "0" "$?"

# --- S4: stamp errors -----------------------------------------------------------
R=$(fresh s4)
bin "$R/a.pdf"
bash "$DOCS" external stamp "$R/a.pdf" >/dev/null 2>&1; check "S4a stamp without a card fails" "1" "$?"
doc "$R/notes.md" </dev/null
bash "$DOCS" external stamp "$R/notes.md" >/dev/null 2>&1; check "S4b stamp of a non-external fails" "1" "$?"

echo "== move =="

# --- M1: file and card move together; links it broke are reported --------------
R=$(fresh m1)
bin "$R/external/spec.pdf"; doc "$R/external/spec.pdf.md" </dev/null
doc "$R/arch/pay.md" <<'EOF'
See [card](../external/spec.pdf.md) and [unrelated](../nowhere.md).
EOF
out=$(bash "$DOCS" external move "$R/external/spec.pdf" "$R/external/vendor" "$R" 2>&1); rc=$?
check "M1a rc 0" "0" "$rc"
check "M1b file moved" "yes" "$([ -f "$R/external/vendor/spec.pdf" ] && [ ! -e "$R/external/spec.pdf" ] && echo yes || echo no)"
check "M1c card moved with it" "yes" "$([ -f "$R/external/vendor/spec.pdf.md" ] && [ ! -e "$R/external/spec.pdf.md" ] && echo yes || echo no)"
check "M1d broken link to the old path reported" "yes" "$(has "$out" "BROKEN LINK: $R/arch/pay.md -> ../external/spec.pdf.md")"
check "M1e unrelated breakage not reported" "no" "$(has "$out" 'nowhere.md')"

# --- M2: given the card path, without links broken; refusing to overwrite --------
R=$(fresh m2)
bin "$R/external/a.pdf"; doc "$R/external/a.pdf.md" </dev/null
out=$(bash "$DOCS" external move "$R/external/a.pdf.md" "$R/external/x/" "$R" 2>&1)
check "M2a move by card path" "yes" "$([ -f "$R/external/x/a.pdf" ] && [ -f "$R/external/x/a.pdf.md" ] && echo yes || echo no)"
check "M2b nothing broken, nothing reported" "no" "$(has "$out" BROKEN)"
bin "$R/external/a.pdf"
bash "$DOCS" external move "$R/external/a.pdf" "$R/external/x" "$R" >/dev/null 2>&1; rc=$?
check "M2c refuses to overwrite" "1:yes" "$rc:$([ -f "$R/external/a.pdf" ] && echo yes || echo no)"

# --- M3: an uncarded file moves alone; a stale card at the target is never adopted ---
R=$(fresh m3)
bin "$R/external/b.pdf"
out=$(bash "$DOCS" external move "$R/external/b.pdf" "$R/external/y" "$R" 2>&1)
check "M3a uncarded file moves, one MOVED line" "1" "$(echo "$out" | grep -c '^MOVED:')"
bin "$R/external/c.pdf"; doc "$R/external/z/c.pdf.md" </dev/null
bash "$DOCS" external move "$R/external/c.pdf" "$R/external/z" "$R" >/dev/null 2>&1; rc=$?
check "M3b refuses to pair with an existing card" "1:yes" "$rc:$([ -f "$R/external/c.pdf" ] && echo yes || echo no)"

echo
echo "passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
