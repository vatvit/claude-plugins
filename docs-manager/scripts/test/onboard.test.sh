#!/usr/bin/env bash
# Tests for onboarding a legacy project: `survey` (read-only plan) and `onboard` (apply it).
# The legacy project is generated here, fake data only.
#
# Dual-target, like the other suites — run on the host (bash 3.2 + BSD) and in a container:
#
#   bash docs-manager/scripts/test/onboard.test.sh
#   docker run --rm -v "$PWD":/w -w /w bash:5 bash docs-manager/scripts/test/onboard.test.sh
#
# The git cases (history kept, .gitignore respected) need a git binary; without one they are
# reported as skipped, not passed. bash:5 has none, so the host run is what covers them.
set -uo pipefail

DOCS="$(cd "$(dirname "$0")/.." && pwd)/docs.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0 skipped=0

check() { # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"
    else fail=$((fail+1)); echo "  FAIL $1"; echo "         expected: [$2]"; echo "         actual:   [$3]"; fi
}
skip() { skipped=$((skipped+1)); echo "  skip $1"; }
has() { echo "$1" | grep -qF -- "$2" && echo yes || echo no; }   # has <haystack> <needle>
put() { mkdir -p "$(dirname "$1")"; cat > "$1"; }                 # put <path> — body from stdin
# tree_sum <dir> -> one line per file, path and checksum, so any change to the tree shows
tree_sum() { (cd "$1" && find . -type f ! -path './.git/*' | sort | while IFS= read -r f; do printf '%s %s\n' "$f" "$(cksum < "$f")"; done); }
rows() { printf '%s\n' "$1" | grep -v '^#' | cut -f1-4; }        # plan rows without the bytes column

# legacy <dir> — a project that grew without docs-manager: a README with run instructions,
# a doc/ folder with an image and a vendor PDF, a root-level doc, an ADR folder, docs beside
# the code, CI and build files, a dependency folder, and one dead link.
legacy() {
    local R="$1"
    put "$R/README.md" <<'EOF'
# Shop

Run it with `make up`. Setup details: [setup](doc/setup.md), [the old guide](<doc/how to (v2).md>).
Architecture: [here](ARCHITECTURE.md).
EOF
    put "$R/ARCHITECTURE.md" <<'EOF'
# Architecture

![overview](doc/img/overview.png) — see also the [README](README.md) and [setup](doc/setup.md#ports).
EOF
    put "$R/doc/setup.md" <<'EOF'
---
title: Setup
description: How to set the shop up
---

# Setup

Back to the [README](../README.md). API: [api](api.md). Gone: [old](missing.md).
EOF
    put "$R/doc/api.md" <<'EOF'
# API

See [setup](setup.md) and the [vendor spec](vendor-spec.pdf).
EOF
    put "$R/doc/how to (v2).md" <<'EOF'
# Old guide

Superseded by [setup](setup.md).
EOF
    printf 'PNG fake' | put "$R/doc/img/overview.png"
    printf '%%PDF-1.4 fake' | put "$R/doc/vendor-spec.pdf"
    printf '# Use Postgres\n\nAccepted.\n' | put "$R/adr/0001-use-postgres.md"
    printf '# Payments\n\nSee [notes](NOTES.md).\n' | put "$R/src/payments/README.md"
    printf '# Notes\n' | put "$R/src/payments/NOTES.md"
    printf '%%PDF-1.4 brochure' | put "$R/public/brochure.pdf"
    printf 'openapi: 3.0.0\n' | put "$R/openapi.yaml"
    printf '# Agent rules\n' | put "$R/CLAUDE.md"
    printf 'up:\n\tdocker compose up\n' | put "$R/Makefile"
    printf 'services: {}\n' | put "$R/docker-compose.yml"
    printf 'on: push\n' | put "$R/.github/workflows/ci.yml"
    printf 'flask\n' | put "$R/requirements.txt"
    printf '# pkg\n' | put "$R/node_modules/pkg/README.md"
    printf '# hidden\n' | put "$R/.idea/notes.md"
}

echo "== survey =="

R="$TMP/plain"; legacy "$R"
before="$(tree_sum "$R")"
plan="$(bash "$DOCS" survey "$R")"; rc=$?
check "S1 survey exits 0" "0" "$rc"
check "S2 survey writes nothing" "same" "$([ "$before" = "$(tree_sum "$R")" ] && echo same || echo changed)"
expected="$(printf '%s\n' \
  'cite	build	.github/workflows/ci.yml	-' \
  'move	doc	ARCHITECTURE.md	docs/architecture.md' \
  'link	agent	CLAUDE.md	-' \
  'cite	build	Makefile	-' \
  'link	meta	README.md	-' \
  'move	adr	adr/0001-use-postgres.md	docs/decisions/0001-use-postgres.md' \
  'move	doc	doc/api.md	docs/api.md' \
  'move	doc	doc/how to (v2).md	docs/how to (v2).md' \
  'move	asset	doc/img/overview.png	docs/img/overview.png' \
  'move	doc	doc/setup.md	docs/setup.md' \
  'move	external	doc/vendor-spec.pdf	docs/external/vendor-spec.pdf' \
  'cite	build	docker-compose.yml	-' \
  'link	api	openapi.yaml	-' \
  'ignore	external	public/brochure.pdf	-' \
  'link	doc	src/payments/NOTES.md	-' \
  'link	meta	src/payments/README.md	-' \
  'write	from-code	-	docs/overview.md' \
  'write	from-code	-	docs/how-to-run.md')"
check "S3 every source, one action each" "$expected" "$(rows "$plan")"
check "S4 dependency, dot and non-doc files left out" "no no no" \
  "$(has "$plan" node_modules) $(has "$plan" .idea) $(has "$plan" requirements.txt)"
check "S5 bytes column" "yes" "$(has "$plan" "$(printf 'doc/setup.md\tdocs/setup.md\t')")"

echo "== plan check =="

bad="$TMP/bad.plan"
printf 'move\tdoc\tREADME.md\tdocs/x.md\t1\nexec\tdoc\tREADME.md\t-\t1\nmove\tdoc\tCLAUDE.md\t../out.md\t1\n' > "$bad"
out="$(bash "$DOCS" onboard "$bad" "$R" 2>&1)"; rc=$?
check "P1 bad plan rejected" "1" "$rc"
check "P2 unknown action named" "yes" "$(has "$out" "unknown action 'exec'")"
check "P3 destination outside docs/ named" "yes" "$(has "$out" "must be under docs/: CLAUDE.md")"
check "P4 rejected plan changes nothing" "same" "$([ "$before" = "$(tree_sum "$R")" ] && echo same || echo changed)"

echo "== onboard =="

printf '%s\n' "$plan" > "$TMP/plain.plan"
out="$(bash "$DOCS" onboard "$TMP/plain.plan" "$R" 2>&1)"; rc=$?
check "O1 onboard exits 0" "0" "$rc"
check "O2 doc folder moved wholesale" "yes yes yes no" \
  "$([ -f "$R/docs/setup.md" ] && echo yes || echo no) $([ -f "$R/docs/img/overview.png" ] && echo yes || echo no) $([ -f "$R/docs/external/vendor-spec.pdf" ] && echo yes || echo no) $([ -d "$R/doc" ] && echo yes || echo no)"
check "O3 inbound links rewritten (file left in place)" \
  'Run it with `make up`. Setup details: [setup](docs/setup.md), [the old guide](<docs/how to (v2).md>).' \
  "$(sed -n 3p "$R/README.md")"
check "O4 outbound links of a moved file, fragment kept" \
  '![overview](img/overview.png) — see also the [README](../README.md) and [setup](setup.md#ports).' \
  "$(tail -n 1 "$R/docs/architecture.md")"
check "O5 link between two moved files untouched" "See [setup](setup.md) and the [vendor spec](external/vendor-spec.pdf)." \
  "$(tail -n 1 "$R/docs/api.md")"
check "O6 frontmatter added, title from the heading" "API|TODO" \
  "$(awk -F': ' 'NR==2{t=$2} NR==3{d=$2} END{print t "|" d}' "$R/docs/api.md")"
check "O7 existing frontmatter kept" "How to set the shop up" "$(awk -F': ' 'NR==3{print $2}' "$R/docs/setup.md")"
check "O8 _index.md everywhere" "yes yes yes yes" \
  "$(for d in docs docs/img docs/decisions docs/external; do [ -f "$R/$d/_index.md" ] && printf 'yes ' || printf 'no '; done | sed 's/ $//')"
idx="$(cat "$R/docs/_index.md")"
check "O9 sources block links what stays" "yes yes yes" \
  "$(has "$idx" '- [`README.md`](../README.md) — meta') $(has "$idx" '- [`src/payments/NOTES.md`](../src/payments/NOTES.md) — doc') $(has "$idx" '- [`openapi.yaml`](../openapi.yaml) — api')"
check "O10 ignored sources listed apart" "yes" \
  "$(has "$(sed -n '/### Not documentation/,$p' "$R/docs/_index.md")" '- [`public/brochure.pdf`](../public/brochure.pdf) — external')"
check "O11 docs to write reported" "yes yes" "$(has "$out" 'TO WRITE: docs/overview.md') $(has "$out" 'TO WRITE: docs/how-to-run.md')"
check "O12 the dead link reported" "yes" "$(has "$out" 'BROKEN LINK: docs/setup.md -> missing.md')"

echo "== after onboarding =="

# What Claude does next: fix the dead link, card the external file, describe the TODOs.
f="$R/docs/setup.md"; awk '{ sub(/ Gone: \[old\]\(missing.md\)\./, "") } 1' "$f" > "$f.t" && mv "$f.t" "$f"
printf -- '---\ntitle: Vendor spec\ndescription: d\n---\n' > "$R/docs/external/vendor-spec.pdf.md"
(cd "$R" && bash "$DOCS" external stamp docs/external/vendor-spec.pdf >/dev/null && bash "$DOCS" index --write docs >/dev/null)
out="$(cd "$R" && bash "$DOCS" check docs 2>&1)"; rc=$?
check "A1 check clean" "0" "$rc"
[ "$rc" = 0 ] || printf '%s\n' "$out"
after="$(tree_sum "$R")"
again="$(bash "$DOCS" survey "$R")"
check "A2 second survey proposes nothing" "" "$(rows "$again")"
printf '%s\n' "$again" > "$TMP/again.plan"
bash "$DOCS" onboard "$TMP/again.plan" "$R" >/dev/null 2>&1
check "A3 second onboard changes nothing" "same" "$([ "$after" = "$(tree_sum "$R")" ] && echo same || echo changed)"

echo "== adopt =="

R="$TMP/adopt"; mkdir -p "$R/docs/guide"
printf '# Guide\n' > "$R/docs/guide/start.md"
printf -- '---\ntitle: t\ndescription: d\n---\n' > "$R/docs/ok.md"
plan="$(bash "$DOCS" survey "$R")"
check "D1 a doc under docs/ without frontmatter is adopted" "adopt	docs	docs/guide/start.md	docs/guide/start.md" \
  "$(rows "$plan" | grep -v '^write')"
printf '%s\n' "$plan" > "$TMP/adopt.plan"
bash "$DOCS" onboard "$TMP/adopt.plan" "$R" >/dev/null 2>&1
check "D2 frontmatter added in place" "title: Guide" "$(sed -n 2p "$R/docs/guide/start.md")"

echo "== git =="

if command -v git >/dev/null 2>&1; then
    R="$TMP/repo"; legacy "$R"
    printf '# scratch\n' | put "$R/scratch/notes.md"
    printf 'scratch/\n' > "$R/.gitignore"
    (cd "$R" && git init -q && git add -A && git -c user.email=t@example.com -c user.name=t commit -qm init)
    plan="$(bash "$DOCS" survey "$R")"
    check "G1 .gitignore respected" "no" "$(has "$plan" scratch/)"
    printf '%s\n' "$plan" > "$TMP/repo.plan"
    bash "$DOCS" onboard "$TMP/repo.plan" "$R" >/dev/null 2>&1
    st="$(cd "$R" && git status --porcelain)"
    check "G2 a tracked file moves with git mv (history kept)" "yes" "$(has "$st" 'R  doc/img/overview.png -> docs/img/overview.png')"
    check "G3 a rewritten file is still a rename" "yes" "$(echo "$st" | grep -q '^R. doc/api.md -> docs/api.md' && echo yes || echo no)"
else
    skip "G1-G3 no git binary"
fi

echo
echo "onboard: $pass passed, $fail failed, $skipped skipped"
[ "$fail" -eq 0 ]
