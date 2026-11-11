#!/usr/bin/env bash
# Tests for external files (pdf, docx, xlsx, …) and their cards: index listing,
# status/check, stamp, move, docx/xlsx extraction (outline/text) and related-doc flagging.
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

echo "== link destinations =="

# --- L1: spaces and parentheses in names — the index writes <…>, and links accepts it -----
R=$(fresh l1)
bin "$R/external/req/Requirements (1) EN.docx" "PK"
doc "$R/external/req/Requirements (1) EN.docx.md" "Revised requirements" </dev/null
bin "$R/external/req/raw notes.pdf"
doc "$R/external/req/our notes.md" "Notes" </dev/null
mkdir -p "$R/external/req/sub dir"; doc "$R/external/req/sub dir/_index.md" "Sub" </dev/null
bash "$DOCS" index --write "$R" >/dev/null 2>&1
idx=$(cat "$R/external/req/_index.md")
check "L1a card link wrapped in <…>" "yes" \
  "$(has "$idx" '- [`Requirements (1) EN.docx`](<Requirements (1) EN.docx.md>) — Revised requirements')"
check "L1b uncarded file, doc and sub-folder wrapped" "yes:yes:yes" \
  "$(has "$idx" '(<raw notes.pdf>)'):$(has "$idx" '(<our notes.md>)'):$(has "$idx" '(<sub dir/_index.md>)')"
out=$(bash "$DOCS" links "$R" 2>&1); rc=$?
check "L1c generated links all resolve" "0:" "$rc:$out"

# --- L2: every CommonMark destination form resolves, %XX decoded ---------------------------
R=$(fresh l2)
doc "$R/a b.md" </dev/null; doc "$R/café.md" </dev/null; doc "$R/sub/(paren).md" </dev/null
bin "$R/Spec (v2).docx"
doc "$R/x.md" <<'EOF'
[p](a%20b.md) [a](<a b.md>) [t](a%20b.md "Title") [e](Spec%20%28v2%29.docx#page=2)
[u](caf%C3%A9.md) [n](sub/(paren).md) and (aside [q](<Spec (v2).docx>)).
EOF
out=$(bash "$DOCS" links "$R" 2>&1); rc=$?
check "L2a %20, <…>, title, %28%29, UTF-8, balanced parens" "0:" "$rc:$out"
doc "$R/y.md" <<'EOF'
[b](<missing file.md>) [c](gone%20too.md)
EOF
out=$(bash "$DOCS" links "$R" 2>&1)
check "L2b broken ones still reported, decoded" "yes:yes" \
  "$(has "$out" "BROKEN LINK: $R/y.md -> missing file.md"):$(has "$out" "BROKEN LINK: $R/y.md -> gone too.md")"

# --- L3: a back-link written with %20 still counts as a dependant ---------------------------
R=$(fresh l3)
bin "$R/external/Spec (v2).docx" "PK"; doc "$R/external/Spec (v2).docx.md" </dev/null
doc "$R/arch/pay.md" <<'EOF'
See [spec](../external/Spec%20%28v2%29.docx.md).
EOF
out=$(bash "$DOCS" external related "$R/external/Spec (v2).docx" "$R" 2>&1)
check "L3 escaped back-link found" "$(printf 'links\t%s/arch/pay.md' "$R")" "$out"

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

echo "== outline / text =="
# Fixtures are built by fixtures/build.sh from the XML under fixtures/src/ — read those to see
# what each case is reaching for.
FX="$(cd "$(dirname "$0")" && pwd)/fixtures"
tab() { printf "$@" | tr "~" "\t"; }   # tab <fmt> [args] — "~" in the format becomes a tab

# --- X1: docx outline — style names, outlineLvl, split runs, entities -----------------
out=$(bash "$DOCS" external outline "$FX/report.docx" 2>&1); rc=$?
check "X1a rc 0" "0" "$rc"
check "X1b headings, levels and order" \
  "$(tab 'heading~1~Payments contract\nheading~1~Fees & charges\nheading~2~Late payment\nheading~3~Interest\nheading~2~Termination')" "$out"
out=$(bash "$DOCS" external outline "$FX/nostyles.docx" 2>&1)
check "X1c no styles.xml: HeadingN style ids, any case" "$(tab 'heading~1~Alpha\nheading~3~Gamma')" "$out"

# --- X2: docx text — headings marked, body kept, deleted text and empty paragraphs dropped ---
out=$(bash "$DOCS" external text "$FX/report.docx" 2>&1)
check "X2a heading marked" "yes" "$(has "$out" '## Late payment')"
check "X2b body paragraph, tab and spaces collapsed" "yes" "$(has "$out" 'The fee is 2% per month.')"
check "X2c table cell text" "yes" "$(has "$out" 'cell text')"
check "X2d deleted text dropped" "no" "$(has "$out" 'deleted')"
check "X2e outlineLvl 9 is body text" "yes" "$(echo "$out" | grep -qx 'Not a heading' && echo yes || echo no)"
check "X2f nine lines, none empty" "9:0" "$(echo "$out" | wc -l | tr -d ' '):$(echo "$out" | grep -c '^$')"

# --- X3: xlsx — workbook order, rels, shared/rich/inline strings, prefixes, sparse rows ---
out=$(bash "$DOCS" external outline "$FX/book.xlsx" 2>&1)
check "X3a sheets in tab order, header columns" \
  "$(tab 'sheet~Rates & fees~A1:C3~A:region | B:rate | C:currency\nsheet~Q3~A1:B2~A:month | B:2026')" "$out"
out=$(bash "$DOCS" external text "$FX/book.xlsx" 2>&1)
check "X3b rows as TSV, sparse cell kept in its column" \
  "$(tab '## Rates & fees (A1:C3)\n1~region~rate~currency\n2~EU~0.25~EUR\n3~US~~1\n## Q3 (A1:B2)\n1~month~2026\n2~Jul')" "$out"
check "X3c phonetic run not read" "no" "$(has "$out" IGNORED)"

# --- X4: fallback — every unreadable case is a `none` record and rc 0, never an error ---------
R=$(fresh x4)
bin "$R/a.pdf"; bin "$R/b.doc"; bin "$R/c.docx" "not a zip"; bin "$R/d.pptx"
for f in a.pdf b.doc c.docx d.pptx; do
  out=$(bash "$DOCS" external outline "$R/$f" 2>&1); rc=$?
  check "X4 $f -> none, rc 0" "0:none" "$rc:$(echo "$out" | cut -f1)"
done
check "X4e pdf says read natively" "yes" "$(has "$(bash "$DOCS" external text "$R/a.pdf")" natively)"
mkdir -p "$TMP/nounzip"
for t in awk sed grep find sort tr dirname basename mktemp cat rm mv head cut; do
  p="$(command -v "$t" 2>/dev/null)" && ln -s "$p" "$TMP/nounzip/$t"
done
out=$(PATH="$TMP/nounzip" "$(command -v bash)" "$DOCS" external outline "$FX/report.docx" 2>&1); rc=$?
check "X4f no unzip -> none, rc 0" "0:yes" "$rc:$(has "$out" "$(tab 'none~unzip not available')")"
cp "$FX/book.xlsx" "$R/e.xlsx"; doc "$R/e.xlsx.md" </dev/null
out=$(bash "$DOCS" external outline "$R/e.xlsx.md" 2>&1)
check "X4g given the card path" "yes" "$(has "$out" "$(tab 'sheet~Q3')")"
bash "$DOCS" external outline "$R/missing.docx" >/dev/null 2>&1; check "X4h missing file is an error" "1" "$?"

# --- X5: pptx — slides in presentation order, title placeholders, groups, breaks (PLUG-023) ---
out=$(bash "$DOCS" external outline "$FX/deck.pptx" 2>&1); rc=$?
check "X5a pptx outline: slides by number, centred title, split runs, no title" \
  "0:$(tab 'slide~1~Q3 review & plan\nslide~2~Revenue\nslide~3~-')" "$rc:$out"
out=$(bash "$DOCS" external text "$FX/deck.pptx" 2>&1)
check "X5b pptx text: a heading per slide, body lines, group and break kept" \
  "$(printf '## Slide 1: Q3 review & plan\nPrepared for the board\n## Slide 2: Revenue\nUp 12%% on Q2\nEU US\nGrouped note\n## Slide 3\nQuestions?')" "$out"

# --- X6: odp — pages, title frame, outline list, speaker notes skipped -----------------------
out=$(bash "$DOCS" external outline "$FX/deck.odp" 2>&1); rc=$?
check "X6a odp outline" "0:$(tab 'slide~1~Roadmap & risks\nslide~2~-')" "$rc:$out"
out=$(bash "$DOCS" external text "$FX/deck.odp" 2>&1)
check "X6b odp text, notes not read" \
  "$(printf '## Slide 1: Roadmap & risks\nShip 2.0\nHire two\n## Slide 2\nThanks')" "$out"

# --- X7: odt — outline-level headings, spans, spaces, footnote and comment skipped -----------
out=$(bash "$DOCS" external outline "$FX/notes.odt" 2>&1); rc=$?
check "X7a odt outline" "0:$(tab 'heading~1~Scope & aims\nheading~2~Late payment\nheading~3~Interest')" "$rc:$out"
out=$(bash "$DOCS" external text "$FX/notes.odt" 2>&1)
check "X7b odt text: headings marked, list, tab/break, table cell, no empty lines" \
  "$(printf '# Scope & aims\nThe fee is 2%%.\n## Late payment\nFirst item\n### Interest\nA B C\ncell text')" "$out"

# --- X8: ods — repeated cells and rows, display text, covered cells, comments skipped --------
out=$(bash "$DOCS" external outline "$FX/sheet.ods" 2>&1); rc=$?
check "X8a ods outline: range from the cells with content, header row" \
  "0:$(tab 'sheet~Rates & fees~A1:C4~A:region | B:rate | C:currency\nsheet~Q3~A1:B3~A:month | B:2026')" "$rc:$out"
out=$(bash "$DOCS" external text "$FX/sheet.ods" 2>&1)
check "X8b ods text: rows as TSV, a date as displayed, a repeated value repeated" \
  "$(tab '## Rates & fees (A1:C4)\n1~region~rate~currency\n2~EU~0.25~EUR\n3~US~~24/10/2026\n4~x~x\n## Q3 (A1:B3)\n2~month~2026\n3~Jul')" "$out"
R=$(fresh x9); bin "$R/e.odt" "not a zip"
check "X9 an unreadable odt is none, rc 0" "0:none" "$(o=$(bash "$DOCS" external outline "$R/e.odt" 2>&1); echo "$?:$(echo "$o" | cut -f1)")"

echo "== related =="

# --- R1: a changed file names its relates-to docs and its back-links, each once ---------
R=$(fresh r1)
bin "$R/external/law/c.pdf" "version one"
cat > "$R/external/law/c.pdf.md" <<'EOF'
---
title: Contract
description: The contract
relates-to: [../../arch/pay.md, ../../arch/gone.md]
---
EOF
doc "$R/arch/pay.md" <<'EOF'
Fees: [contract, p. 3](../external/law/c.pdf.md).
EOF
doc "$R/arch/guide.md" <<'EOF'
See [the contract](../external/law/c.pdf#page=3).
EOF
doc "$R/arch/other.md" <<'EOF'
Nothing to do with it. [pay](pay.md)
EOF
bash "$DOCS" index --write "$R" >/dev/null 2>&1
out=$(bash "$DOCS" external related "$R/external/law/c.pdf" "$R" 2>&1); rc=$?
check "R1a related records, relates-to first, each doc once" \
  "0:$(tab 'relates-to~%s/arch/pay.md\nlinks~%s/arch/guide.md' "$R" "$R")" "$rc:$out"
check "R1b generated _index.md is not a dependant" "no" "$(has "$out" _index.md)"
out=$(bash "$DOCS" links "$R" 2>&1)
check "R1c a missing relates-to doc is a broken ref" "yes" \
  "$(has "$out" "BROKEN REF: $R/external/law/c.pdf.md -> relates-to:../../arch/gone.md")"
# drop the missing entry, so what follows is about change only
printf -- '---\ntitle: Contract\ndescription: The contract\nrelates-to: [../../arch/pay.md]\n---\n' > "$R/external/law/c.pdf.md"
bash "$DOCS" external stamp "$R/external/law/c.pdf" >/dev/null 2>&1
out=$(bash "$DOCS" check "$R" 2>&1); rc=$?
check "R1d stamped and unchanged: check clean, no REVIEW" "0:no" "$rc:$(has "$out" REVIEW)"
printf 'version two' > "$R/external/law/c.pdf"
out=$(bash "$DOCS" check "$R" 2>&1); rc=$?
check "R1e changed: check fails" "1" "$rc"
check "R1f changed: relates-to doc to review" "yes" "$(has "$out" "  REVIEW: $R/arch/pay.md (relates-to)")"
check "R1g changed: back-linking doc to review" "yes" "$(has "$out" "  REVIEW: $R/arch/guide.md (links)")"
check "R1h unrelated doc not listed" "no" "$(has "$out" other.md)"
check "R1i REVIEW lines follow their CHANGED line" "CHANGED" \
  "$(echo "$out" | grep -B1 -m1 'REVIEW:' | head -1 | cut -d: -f1)"

# --- R2: related with no dependants is empty; needs the file or its card ------------------
R=$(fresh r2)
bin "$R/external/x.pdf"; doc "$R/external/x.pdf.md" </dev/null
out=$(bash "$DOCS" external related "$R/external/x.pdf.md" "$R" 2>&1); rc=$?
check "R2a nothing depends on it" "0:" "$rc:$out"
bash "$DOCS" external related "$R/external/none.pdf" "$R" >/dev/null 2>&1
check "R2b neither file nor card is an error" "1" "$?"

echo "== dot-folders (PLUG-079) =="

# --- D1: a docs folder that is itself a git repository, plus other dot-folders ---
dotted() { # dotted <root> -> a docs tree with .git/, .obsidian/ and a hidden file in it
    doc "$1/guide/intro.md" "Intro" </dev/null
    mkdir -p "$1/.git/refs/heads" "$1/.git/objects/ab"
    printf 'ref: refs/heads/main\n' > "$1/.git/HEAD"
    printf 'abc\n' > "$1/.git/refs/heads/main"
    bin "$1/.git/objects/ab/blob.pdf"
    doc "$1/.obsidian/notes.md" "Editor notes" <<'EOF'
[gone](nowhere.md)
EOF
    doc "$1/.obsidian/x.diagram.md" "stray source" </dev/null
    doc "$1/.hidden.md" "Hidden" </dev/null
}
R=$(fresh d1); dotted "$R"
out=$(bash "$DOCS" index --write "$R" 2>&1)
check "D1a no _index.md written into .git"      "" "$(find "$R/.git" -name _index.md)"
check "D1b none into another dot-folder"        "" "$(find "$R/.obsidian" -name _index.md)"
idx=$(cat "$R/_index.md")
check "D1c real sub-folder listed"              "yes" "$(has "$idx" 'guide/')"
check "D1d .git not listed"                     "no"  "$(has "$idx" '.git')"
check "D1e .obsidian not listed"                "no"  "$(has "$idx" '.obsidian')"
check "D1f hidden file not listed"              "no"  "$(has "$idx" '.hidden.md')"
out=$(bash "$DOCS" check "$R" 2>&1); rc=$?
check "D1g check passes"                        "0" "$rc"
check "D1h no MISSING for .git"                 "no" "$(has "$out" 'MISSING')"
check "D1i link in a dot-folder not checked"    "no" "$(has "$out" 'nowhere.md')"
check "D1j external in .git not reported"       "no" "$(has "$out" 'blob.pdf')"

# --- D2: a root whose own name starts with a dot is still walked ------------
R=$(fresh d2)/.site-docs; mkdir -p "$R"; dotted "$R"
bash "$DOCS" index --write "$R" >/dev/null 2>&1
check "D2a dot-named root indexed"              "yes" "$([ -f "$R/_index.md" ] && [ -f "$R/guide/_index.md" ] && echo yes || echo no)"
out=$(bash "$DOCS" check "$R" 2>&1); rc=$?
check "D2b check passes on a dot-named root"    "0" "$rc"

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

# --- RC1: listed with ☁ under External documents, not as a document ------------
R=$(fresh rc1)
rcard "$R/external/vendor/spec-v3.pdf.gdrive.md" "Vendor spec on Drive"
bin "$R/external/vendor/local.pdf"; doc "$R/external/vendor/local.pdf.md" "Local copy" </dev/null
doc "$R/external/vendor/notes.md" "Our notes" </dev/null
bash "$DOCS" index --write "$R" >/dev/null 2>&1
idx=$(cat "$R/external/vendor/_index.md")
check "RC1a remote card listed with ☁" "yes" \
  "$(has "$idx" '- ☁ [`spec-v3.pdf`](spec-v3.pdf.gdrive.md) — Vendor spec on Drive')"
check "RC1b remote card not a document" "no" "$(has "$idx" '[`spec-v3.pdf.gdrive.md`]')"
check "RC1c local external still listed" "yes" "$(has "$idx" '- [`local.pdf`](local.pdf.md) — Local copy')"
check "RC1d remote after local" "yes" \
  "$(echo "$idx" | awk '/local\.pdf\.md/ { l = NR } /spec-v3\.pdf\.gdrive\.md/ { r = NR } END { print (l && r > l) ? "yes" : "no" }')"
before="$idx"
bash "$DOCS" index --write "$R" >/dev/null 2>&1
check "RC1e idempotent" "same" "$([ "$before" = "$(cat "$R/external/vendor/_index.md")" ] && echo same || echo changed)"
bash "$DOCS" index --check "$R" >/dev/null 2>&1; check "RC1f index --check clean" "0" "$?"

# --- RC2: a folder holding only a remote card still gets the section --------------
R=$(fresh rc2)
rcard "$R/external/drive/pricing-model.gdrive.md" "Pricing model"
bash "$DOCS" index --write "$R" >/dev/null 2>&1
idx=$(cat "$R/external/drive/_index.md")
check "RC2a section opens for remote cards alone" "yes" "$(has "$idx" '### External documents')"
check "RC2b native file, no extension" "yes" "$(has "$idx" '- ☁ [`pricing-model`](pricing-model.gdrive.md) — Pricing model')"

# --- RC4/RC5: status row, never an orphan; check needs id + modified -----------
R=$(fresh rc4)
rcard "$R/external/drive/ok.gdrive.md"
rcard "$R/external/drive/noid.gdrive.md" "x" remote-id
rcard "$R/external/drive/nomod.gdrive.md" "x" remote-modified
st=$(bash "$DOCS" external status "$R" 2>&1)
check "RC4a remote row" "yes" "$(has "$st" "$(printf 'remote\tfiled\t-\t%s/external/drive/ok.gdrive.md' "$R")")"
check "RC4b never an orphan" "no" "$(has "$st" 'orphan')"
out=$(bash "$DOCS" external check "$R" 2>&1); rc=$?
check "RC5a incomplete fails check" "1" "$rc"
check "RC5b missing id reported" "yes" "$(has "$out" "REMOTE INCOMPLETE: $R/external/drive/noid.gdrive.md")"
check "RC5c missing modified reported" "yes" "$(has "$out" "REMOTE INCOMPLETE: $R/external/drive/nomod.gdrive.md")"
check "RC5d complete card not reported" "no" "$(has "$out" "ok.gdrive.md")"
R=$(fresh rc5)
rcard "$R/external/drive/ok.gdrive.md"
bash "$DOCS" index --write "$R" >/dev/null 2>&1
out=$(bash "$DOCS" check "$R" 2>&1); rc=$?
check "RC5e complete remote card: docs.sh check clean" "0" "$rc"
check "RC5f remote-url not checked as a link" "no" "$(has "$out" 'docs.google.com')"

# --- RC6: relates-to of a remote card is checked --------------------------------
R=$(fresh rc6)
rcard "$R/external/drive/spec.gdrive.md"
awk 'NR == 2 { print "relates-to: [../../arch/missing.md]" } { print }' "$R/external/drive/spec.gdrive.md" > "$R/t" \
  && mv "$R/t" "$R/external/drive/spec.gdrive.md"
bash "$DOCS" index --write "$R" >/dev/null 2>&1
out=$(bash "$DOCS" check "$R" 2>&1)
check "RC6 broken relates-to in a remote card" "yes" "$(has "$out" "BROKEN REF: $R/external/drive/spec.gdrive.md -> relates-to:../../arch/missing.md")"

# --- RC7: remote-stamp is the one writer of remote-modified ------------------------
R=$(fresh rc7)
rcard "$R/c.gdrive.md" "x" remote-modified
out=$(bash "$DOCS" external remote-stamp "$R/c.gdrive.md" 2026-11-11T10:15:12.524Z 2>&1); rc=$?
check "RC7a stamped" "0:yes" "$rc:$(has "$out" "STAMPED: $R/c.gdrive.md")"
check "RC7b field written" "yes" "$(has "$(cat "$R/c.gdrive.md")" 'remote-modified: 2026-11-11T10:15:12.524Z')"
before=$(cat "$R/c.gdrive.md")
out=$(bash "$DOCS" external remote-stamp "$R/c.gdrive.md" 2026-11-11T10:15:12.524Z 2>&1)
check "RC7c repeat is UNCHANGED, bytes kept" "yes:same" \
  "$(has "$out" UNCHANGED):$([ "$before" = "$(cat "$R/c.gdrive.md")" ] && echo same || echo changed)"
bash "$DOCS" external remote-stamp "$R/c.gdrive.md" 2026-11-11T10:15:12Z >/dev/null 2>&1
check "RC7d whole seconds accepted" "yes" "$(has "$(cat "$R/c.gdrive.md")" 'remote-modified: 2026-11-11T10:15:12Z')"
before=$(cat "$R/c.gdrive.md")
bash "$DOCS" external remote-stamp "$R/c.gdrive.md" "yesterday" >/dev/null 2>&1; rc=$?
check "RC7e malformed time rejected, file untouched" "nz:same" \
  "$([ "$rc" -ne 0 ] && echo nz || echo z):$([ "$before" = "$(cat "$R/c.gdrive.md")" ] && echo same || echo changed)"
doc "$R/plain.md" </dev/null
bash "$DOCS" external remote-stamp "$R/plain.md" 2026-11-11T10:15:12Z >/dev/null 2>&1; rc=$?
check "RC7f not a remote card rejected" "nz:no" \
  "$([ "$rc" -ne 0 ] && echo nz || echo z):$(has "$(cat "$R/plain.md")" 'remote-modified')"

# --- RC8: external remote lists every remote card with its attachment's publish --
R=$(fresh rc8)
rcard "$R/external/vendor/spec.pdf.gdrive.md" "Vendor spec"
printf -- '---\nprovider: gdrive\ncontent: remote\nprocessed: none\npublish: commit\n---\n' > "$R/external/vendor/.source.md"
rcard "$R/external/loose/pricing.gdrive.md" "Pricing"
out=$(bash "$DOCS" external remote "$R" 2>&1); rc=$?
check "RC8a rc 0" "0" "$rc"
check "RC8b record with publish" "yes" "$(has "$out" "$(printf '%s/external/vendor/spec.pdf.gdrive.md\tcommit\t2026-11-10T13:37:23.036Z\tVendor spec\tmapping vendor codes' "$R")")"
check "RC8c no .source.md -> -" "yes" "$(has "$out" "$(printf '%s/external/loose/pricing.gdrive.md\t-\t' "$R")")"
check "RC8d .source.md is not a doc" "no" "$(bash "$DOCS" index --write "$R" >/dev/null 2>&1; has "$(cat "$R/external/vendor/_index.md")" 'source')"

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
diff_of() { bash "$DOCS" external remote-diff "$1" "$2" 2>/dev/null; }   # stdout only

# --- RF1/RF2/RF3/RF4/RF5: in sync, new, changed (by id, not name), gone, folders skipped ---------
R=$(fresh rf1); A=$(attach "$R")
listing "1a|a|$DOCMIME|$T1" "S1|sub|$DIRMIME|$T1" "1b|sub/b|$DOCMIME|$T1" "1z|old|$DOCMIME|$T1" > "$R/l.tsv"
out=$(bash "$DOCS" external remote-diff "$A" "$R/l.tsv" 2>&1); rc=$?
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
out=$(bash "$DOCS" external remote-diff "$A" "$R/l.tsv" 2>/dev/null); rc=$?
err=$(bash "$DOCS" external remote-diff "$A" "$R/l.tsv" 2>&1 >/dev/null)
check "RF8a short row: rc 1, stdout empty" "1:" "$rc:$out"
check "RF8b error names line 2" "yes" "$(has "$err" 'line 2')"
listing "|a|$DOCMIME|$T1" > "$R/l.tsv"
bash "$DOCS" external remote-diff "$A" "$R/l.tsv" >/dev/null 2>&1; check "RF8c empty id rejected" "1" "$?"
mkdir -p "$R/plain"; listing "1a|a|$DOCMIME|$T1" > "$R/l.tsv"
bash "$DOCS" external remote-diff "$R/plain" "$R/l.tsv" >/dev/null 2>&1; check "RF11a no .source.md" "1" "$?"
printf -- '---\nprovider: gdrive\n---\n' > "$R/plain/.source.md"
err=$(bash "$DOCS" external remote-diff "$R/plain" "$R/l.tsv" 2>&1); rc=$?
check "RF11b .source.md without remote-id" "1:yes" "$rc:$(has "$err" 'remote-id')"

# --- RF9/RF10: remote-gone marks, check reports, remote-stamp clears --------------------------
R=$(fresh rf9); A=$(attach "$R")
out=$(bash "$DOCS" external remote-gone "$A/old.gdrive.md" 2>&1); rc=$?
check "RF9a marked" "0:yes" "$rc:$(has "$out" "MARKED GONE: $A/old.gdrive.md")"
check "RF9b field written" "yes" "$(has "$(cat "$A/old.gdrive.md")" 'remote-gone: yes')"
before=$(cat "$A/old.gdrive.md")
out=$(bash "$DOCS" external remote-gone "$A/old.gdrive.md" 2>&1)
check "RF9c repeat UNCHANGED, bytes kept" "yes:same" \
  "$(has "$out" UNCHANGED):$([ "$before" = "$(cat "$A/old.gdrive.md")" ] && echo same || echo changed)"
doc "$R/plain.md" </dev/null
bash "$DOCS" external remote-gone "$R/plain.md" >/dev/null 2>&1; rc=$?
check "RF9d not a remote card rejected" "nz:no" "$([ "$rc" -ne 0 ] && echo nz || echo z):$(has "$(cat "$R/plain.md")" 'remote-gone')"
rm -f "$R/plain.md"
st=$(bash "$DOCS" external status "$R" 2>&1)
check "RF10a status: gone row" "yes" "$(has "$st" "$(printf 'gone\tfiled\t-\t%s/old.gdrive.md' "$A")")"
out=$(bash "$DOCS" external check "$R" 2>&1); rc=$?
check "RF10b check fails on a gone card" "1:yes" "$rc:$(has "$out" "REMOTE GONE: $A/old.gdrive.md")"
bash "$DOCS" external remote-stamp "$A/old.gdrive.md" "$T2" >/dev/null 2>&1
check "RF10c remote-stamp clears the mark" "yes" "$(has "$(cat "$A/old.gdrive.md")" 'remote-gone: no')"
bash "$DOCS" external check "$R" >/dev/null 2>&1; check "RF10d check clean again" "0" "$?"
bash "$DOCS" external remote-stamp "$A/a.gdrive.md" "$T2" >/dev/null 2>&1
check "RF10e a card never gone gets no remote-gone key" "no" "$(has "$(cat "$A/a.gdrive.md")" 'remote-gone')"

# --- RF12: a card in a sub-folder of an attachment takes publish from the attachment's .source.md --
# (found by the e2e run: `external remote` looked only beside the card, so sub/ cards read "-")
R=$(fresh rf12); A=$(attach "$R")
mkdir -p "$R/external/plain"; rcard "$R/external/plain/lone.gdrive.md" "Lone"
out=$(bash "$DOCS" external remote "$R")
check "RF12a sub-folder card: publish from the nearest .source.md above" "yes" \
    "$(has "$out" "$(printf '%s/sub/b.gdrive.md\tcommit\t' "$A")")"
check "RF12b no .source.md anywhere above: -" "yes" \
    "$(has "$out" "$(printf '%s/external/plain/lone.gdrive.md\t-\t' "$R")")"
printf -- '---\npublish: local\n---\n' > "$A/sub/.source.md"
check "RF12c the nearest one wins" "yes" \
    "$(has "$(bash "$DOCS" external remote "$R")" "$(printf '%s/sub/b.gdrive.md\tlocal\t' "$A")")"

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

# --- LC1: a copy is never a document in _index.md; its card is still ☁ ----------------------------
R=$(fresh lc1); A=$(lattach "$R" local); copy "$A/spec.gdrive.local.md"
bash "$DOCS" index --write "$R" >/dev/null 2>&1
idx=$(cat "$A/_index.md")
check "LC1a copy not indexed" "no" "$(has "$idx" 'spec.gdrive.local')"
check "LC1b card still listed" "yes" "$(has "$idx" '☁')"

# --- LC2/LC3: copy-stamp refuses an unagreed or missing copy ----------------------------------------
R=$(fresh lc2); A=$(lattach "$R" none); copy "$A/spec.gdrive.local.md"
before=$(cat "$A/spec.gdrive.md")
err=$(bash "$DOCS" external copy-stamp "$A/spec.gdrive.md" "$TC1" 2>&1); rc=$?
check "LC2a refused without processed: local" "1:yes" "$rc:$(has "$err" 'processed: local')"
check "LC2b card untouched" "$before" "$(cat "$A/spec.gdrive.md")"
R=$(fresh lc2b); A=$(lattach "$R" -); copy "$A/spec.gdrive.local.md"
bash "$DOCS" external copy-stamp "$A/spec.gdrive.md" "$TC1" >/dev/null 2>&1; check "LC2c refused with no .source.md" "1" "$?"
R=$(fresh lc3); A=$(lattach "$R" local)
err=$(bash "$DOCS" external copy-stamp "$A/spec.gdrive.md" "$TC1" 2>&1); rc=$?
check "LC3 refused with no copy" "1:yes" "$rc:$(has "$err" 'spec.gdrive.local.md')"

# --- LC4: copy-stamp writes copy-modified, idempotent, checks the time shape ---------------------
R=$(fresh lc4); A=$(lattach "$R" local); copy "$A/spec.gdrive.local.md"
out=$(bash "$DOCS" external copy-stamp "$A/spec.gdrive.md" "$TC1" 2>&1); rc=$?
check "LC4a stamped" "0:yes" "$rc:$(has "$out" "STAMPED: $A/spec.gdrive.md")"
check "LC4b field" "yes" "$(has "$(cat "$A/spec.gdrive.md")" "copy-modified: $TC1")"
out=$(bash "$DOCS" external copy-stamp "$A/spec.gdrive.md" "$TC1" 2>&1)
check "LC4c unchanged on repeat" "yes" "$(has "$out" 'UNCHANGED')"
bash "$DOCS" external copy-stamp "$A/spec.gdrive.md" "yesterday" >/dev/null 2>&1; check "LC4d bad time rejected" "1" "$?"
bash "$DOCS" external copy-stamp "$A/spec.gdrive.local.md" "$TC1" >/dev/null 2>&1; check "LC4e not a card" "1" "$?"

# --- LC5/LC6: in step, then stale after the card is refreshed, then clean again -----------------
st=$(bash "$DOCS" external status "$R")
check "LC5a status copy" "yes" "$(has "$st" "$(printf 'copy\tfiled\t%s/spec.gdrive.local.md\t%s/spec.gdrive.md' "$A" "$A")")"
bash "$DOCS" external check "$R" >/dev/null 2>&1; check "LC5b check clean" "0" "$?"
bash "$DOCS" external remote-stamp "$A/spec.gdrive.md" "$TC2" >/dev/null 2>&1
out=$(bash "$DOCS" external check "$R" 2>&1); rc=$?
check "LC6a stale after the card moved on" "1:yes" "$rc:$(has "$out" "LOCAL COPY STALE: $A/spec.gdrive.local.md")"
check "LC6b status copy-stale" "yes" "$(has "$(bash "$DOCS" external status "$R")" "$(printf 'copy-stale\t')")"
bash "$DOCS" external copy-stamp "$A/spec.gdrive.md" "$TC2" >/dev/null 2>&1
bash "$DOCS" external check "$R" >/dev/null 2>&1; check "LC6c clean after copy-stamp" "0" "$?"

# --- LC7/LC8/LC9: unstamped, unagreed, orphan ---------------------------------------------------
R=$(fresh lc7); A=$(lattach "$R" local); copy "$A/spec.gdrive.local.md"
out=$(bash "$DOCS" external check "$R" 2>&1); rc=$?
check "LC7 unstamped" "1:yes" "$rc:$(has "$out" "LOCAL COPY UNSTAMPED: $A/spec.gdrive.local.md")"
R=$(fresh lc8); A=$(lattach "$R" none); copy "$A/spec.gdrive.local.md"
out=$(bash "$DOCS" external check "$R" 2>&1); rc=$?
check "LC8 not agreed" "1:yes" "$rc:$(has "$out" "LOCAL COPY NOT AGREED: $A/spec.gdrive.local.md")"
R=$(fresh lc9); A=$(lattach "$R" local); copy "$A/gone.gdrive.local.md"
out=$(bash "$DOCS" external check "$R" 2>&1); rc=$?
check "LC9 orphan copy" "1:yes" "$rc:$(has "$out" "LOCAL COPY ORPHAN: $A/gone.gdrive.local.md")"
check "LC9b a copy is not a remote card" "no" "$(has "$out" "REMOTE INCOMPLETE: $A/gone.gdrive.local.md")"

# --- LC11: external remote names the copy in a 6th field ----------------------------------------
R=$(fresh lc11); A=$(lattach "$R" local); copy "$A/spec.gdrive.local.md"
rcard "$A/other.gdrive.md" "Other"
out=$(bash "$DOCS" external remote "$R")
check "LC11a copy named" "$A/spec.gdrive.local.md" "$(echo "$out" | awk -F'\t' -v c="$A/spec.gdrive.md" '($1 "") == c { print $6 }')"
check "LC11b no copy: -" "-" "$(echo "$out" | awk -F'\t' -v c="$A/other.gdrive.md" '($1 "") == c { print $6 }')"
check "LC11c the copy is not listed as a card" "no" "$(has "$out" "$(printf '%s/spec.gdrive.local.md\t' "$A")")"

echo
echo "passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
