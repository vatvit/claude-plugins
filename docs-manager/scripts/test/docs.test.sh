#!/usr/bin/env bash
# Tests for docs.sh index/links/check: git-ignored folders are skipped (PLUG-093) and
# #anchor targets of links are verified (PLUG-095).
#
# Dual-target, like the other suites — run on the host (bash 3.2 + BSD) and in a container:
#
#   bash docs-manager/scripts/test/docs.test.sh
#   docker run --rm -v "$PWD":/w -w /w bash:5 bash docs-manager/scripts/test/docs.test.sh
#
# bash:5 has no git: the git cases are reported as skipped there (or run
# `apk add git` first: docker run … bash:5 sh -c 'apk add -q git && bash …').
set -uo pipefail

DOCS="$(cd "$(dirname "$0")/.." && pwd)/docs.sh"
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
HAVE_GIT=no; command -v git >/dev/null 2>&1 && HAVE_GIT=yes
needs_git() { [ "$HAVE_GIT" = yes ] && return 0; skipped=$((skipped+1)); echo "  skip $1 (no git here)"; return 1; }

echo "== git-ignored folders (PLUG-093) =="

# Layout: docs/a.md, docs/external/x.md (ignored folder), docs/secret.md (ignored file)
ignored_fixture() { # ignored_fixture <name> <git|nogit> -> root path on stdout
    local R; R=$(fresh "$1")
    doc "$R/docs/a.md" "Doc A" </dev/null
    doc "$R/docs/external/x.md" "Third party" </dev/null
    doc "$R/docs/external/deep/y.md" "Deeper" </dev/null
    doc "$R/docs/secret.md" "Confidential" </dev/null
    printf 'docs/external/\ndocs/secret.md\n' > "$R/.gitignore"
    [ "$2" = git ] && git -C "$R" init -q
    echo "$R/docs"
}

if needs_git G1; then
  R=$(ignored_fixture g1 git)
  bash "$DOCS" index --write "$R" >/dev/null 2>&1
  idx=$(cat "$R/_index.md")
  check "G1a ignored folder gets no _index.md" "no" "$([ -e "$R/external/_index.md" ] && echo yes || echo no)"
  check "G1b nested folder of an ignored folder gets none" "no" "$([ -e "$R/external/deep/_index.md" ] && echo yes || echo no)"
  check "G1c parent index does not list the ignored folder" "no" "$(has "$idx" 'external')"
  check "G1d parent index does not list the ignored file" "no" "$(has "$idx" 'secret')"
  check "G1e ordinary doc still listed" "yes" "$(has "$idx" '[`a.md`](a.md) — Doc A')"
  bash "$DOCS" index --check "$R" >/dev/null 2>&1; check "G1f index --check clean" "0" "$?"
  bash "$DOCS" check "$R" >/dev/null 2>&1; check "G1g check clean (no MISSING for ignored folder)" "0" "$?"
fi

if needs_git G2; then
  R=$(ignored_fixture g2 git)
  printf '[gone](nowhere.md)\n' >> "$R/external/x.md"
  bash "$DOCS" index --write "$R" >/dev/null 2>&1
  out=$(bash "$DOCS" links "$R" 2>&1); rc=$?
  check "G2 broken link inside an ignored file is not reported" "0" "$rc"
fi

if needs_git G3; then   # a tracked file stays a doc even if a pattern matches it
  R=$(ignored_fixture g3 git)
  git -C "$R" add -f secret.md >/dev/null 2>&1
  bash "$DOCS" index --write "$R" >/dev/null 2>&1
  check "G3 force-added (tracked) file is listed" "yes" "$(has "$(cat "$R/_index.md")" 'secret.md')"
fi

if needs_git G4; then   # the docs root itself being ignored does not blank the tree
  R=$(fresh g4); git -C "$R" init -q; printf 'docs/\n' > "$R/.gitignore"
  doc "$R/docs/a.md" "Doc A" </dev/null
  bash "$DOCS" index --write "$R/docs" >/dev/null 2>&1
  check "G4 explicit root inside an ignored folder still indexed" "yes" "$(has "$(cat "$R/docs/_index.md" 2>/dev/null)" 'a.md')"
fi

R=$(ignored_fixture g5 nogit)   # outside git: unchanged
bash "$DOCS" index --write "$R" >/dev/null 2>&1
check "G5a outside git the folder is indexed as before" "yes" "$([ -e "$R/external/_index.md" ] && echo yes || echo no)"
check "G5b outside git the file is listed as before" "yes" "$(has "$(cat "$R/_index.md")" 'secret.md')"

echo "== #anchor targets (PLUG-095) =="

links_out() { bash "$DOCS" links "$1" 2>&1; }

# --- A1: existing heading passes, missing fails with file, line and fragment ---
R=$(fresh a1)
doc "$R/target.md" <<'X'
# Title

## Some Section

text
X
doc "$R/src.md" <<'X'
[ok](target.md#some-section)
[bad](target.md#renamed-section)
[top of file](target.md)
X
out=$(links_out "$R"); rc=$?
check "A1a missing heading fails" "1" "$rc"
check "A1b names file, line and fragment" "yes" "$(has "$out" "BROKEN ANCHOR: $R/src.md:7 -> target.md#renamed-section")"
check "A1c existing heading not reported" "no" "$(has "$out" "some-section")"
check "A1d plain file link not reported" "no" "$(has "$out" "top of file")"

# --- A2: same-file #fragment is checked too ---
R=$(fresh a2)
doc "$R/a.md" <<'X'
# Intro

[here](#intro) and [gone](#outro)
X
out=$(links_out "$R")
check "A2a same-file ok link passes" "no" "$(has "$out" "#intro")"
check "A2b same-file missing link fails" "yes" "$(has "$out" "a.md:8 -> #outro")"

# --- A3: duplicate headings get -1, -2 ---
R=$(fresh a3)
doc "$R/a.md" <<'X'
# Setup
## Notes
## Notes
## Notes

[1](#notes) [2](#notes-1) [3](#notes-2) [4](#notes-3)
X
out=$(links_out "$R")
check "A3a first three resolve, only the fourth fails" "1" "$(echo "$out" | grep -c 'BROKEN ANCHOR')"
check "A3b suffix beyond the count fails" "yes" "$(has "$out" "-> #notes-3")"

# --- A4: slug rules: punctuation, backticks, non-ASCII, trailing #s, links, emphasis ---
R=$(fresh a4)
doc "$R/a.md" <<'X'
## What's `docs.sh` for? (FAQ)
## Café — Ünïcode ##
## See [the guide](x.md) and **bold** here
## snake_case and kebab-case

[1](#whats-docssh-for-faq)
[2](#café--ünïcode)
[3](#caf%C3%A9--%C3%BCn%C3%AFcode)
[4](#see-the-guide-and-bold-here)
[5](#snake_case-and-kebab-case)
[6](#wrong-slug)
X
out=$(links_out "$R")
check "A4a punctuation and backticks dropped" "no" "$(has "$out" "#whats")"
check "A4b non-ASCII kept, em dash dropped" "no" "$(has "$out" "caf")"
check "A4c link text and emphasis reduce to text" "no" "$(has "$out" "#see-the")"
check "A4d underscore and hyphen kept" "no" "$(has "$out" "#snake")"
check "A4e only the wrong slug reported" "1" "$(echo "$out" | grep -c 'BROKEN ANCHOR')"

# --- A5: explicit anchors count; headings inside code fences do not ---
R=$(fresh a5)
doc "$R/t.md" <<'X'
# T

<a id="custom-anchor"></a>
<a name="old-style"></a>
<a href="x" id='single'>x</a>

```bash
# not a heading
```
X
doc "$R/s.md" <<'X'
[1](t.md#custom-anchor) [2](t.md#old-style) [3](t.md#single) [4](t.md#not-a-heading)
X
out=$(links_out "$R")
check "A5a id, name and single-quoted anchors resolve" "nonono" "$(has "$out" "custom")$(has "$out" "old-style")$(has "$out" "#single")"
check "A5b heading-looking line in a fence is no anchor" "yes" "$(has "$out" "#not-a-heading")"

# --- A6: non-markdown targets, external URLs and #top are untouched ---
R=$(fresh a6)
doc "$R/a.md" <<'X'
[1](https://example.com/p#nope) [2](mailto:x@y.z) [3](pic.png#frag) [4](code.sh#L10) [5](#top)
[6](other.md?plain=1#a-heading)
X
printf 'x' > "$R/pic.png"; printf 'x' > "$R/code.sh"
doc "$R/other.md" <<'X'
# A heading
X
out=$(links_out "$R"); rc=$?
check "A6 nothing reported" "0" "$rc"

# --- A7: broken file still reports BROKEN LINK, not an anchor error ---
R=$(fresh a7)
doc "$R/a.md" <<'X'
[1](missing.md#x)
X
out=$(links_out "$R")
check "A7a BROKEN LINK" "yes" "$(has "$out" "BROKEN LINK")"
check "A7b no anchor error on top of it" "no" "$(has "$out" "BROKEN ANCHOR")"

# --- A8: check reports it and the exit code is non-zero ---
R=$(fresh a8)
doc "$R/a.md" <<'X'
[1](#nope)
X
bash "$DOCS" index --write "$R" >/dev/null 2>&1
out=$(bash "$DOCS" check "$R" 2>&1); rc=$?
check "A8 check fails on a missing anchor" "1:yes" "$rc:$(has "$out" "BROKEN ANCHOR")"

# --- A9: links inside fenced code blocks are examples, not links ---
R=$(fresh a9)
doc "$R/a.md" <<'X'
# Real

```md
[file](nowhere.md) and [anchor](#nope)
```

~~~
[tilde](gone.md)
~~~

[real broken](missing.md) and [real anchor](#nope-real)
X
out=$(links_out "$R"); rc=$?
check "A9a only the two real links are reported" "2" "$(echo "$out" | grep -c 'BROKEN')"
check "A9b fenced file links ignored" "nono" "$(has "$out" "nowhere.md")$(has "$out" "gone.md")"
check "A9c fenced anchor ignored" "no" "$(has "$out" "a.md:8 ->")"
check "A9d real links still reported" "yes" "$(has "$out" "missing.md")"

echo "== local-only remote attachment (PLUG-112) =="

# --- RC9: a git-ignored attachment stays out of _index.md but `external remote` finds it ---
if needs_git RC9; then
  R=$(fresh rc9)
  doc "$R/docs/a.md" "Doc A" </dev/null
  mkdir -p "$R/docs/external/private"
  printf -- '---\ntitle: t\ndescription: Private contract\nread-when: pricing\nremote-id: 1x\nremote-modified: 2026-11-10T13:37:23Z\n---\n' \
    > "$R/docs/external/private/contract.gdrive.md"
  printf -- '---\nprovider: gdrive\npublish: local\n---\n' > "$R/docs/external/private/.source.md"
  printf 'docs/external/private/\n' > "$R/.gitignore"
  git -C "$R" init -q
  bash "$DOCS" index --write "$R/docs" >/dev/null 2>&1
  check "RC9a ignored attachment not in any _index.md" "" "$(grep -rl 'contract' "$R/docs" --include=_index.md)"
  out=$(bash "$DOCS" external remote "$R/docs" 2>&1)
  check "RC9b external remote lists it, publish local" "yes" \
    "$(has "$out" "$(printf '%s/docs/external/private/contract.gdrive.md\tlocal\t2026-11-10T13:37:23Z\tPrivate contract\tpricing' "$R")")"
  bash "$DOCS" check "$R/docs" >/dev/null 2>&1; check "RC9c check clean" "0" "$?"
fi

echo
echo "passed: $pass  failed: $fail  skipped: $skipped"
[ "$fail" -eq 0 ]
