#!/usr/bin/env bash
# external.sh — external reference files (pdf, docx, xlsx, …) and their cards.
# Sourced by docs.sh, never executed. Relies on lib.sh being sourced first.
#
# An external file is one the project did not author and never edits — a vendor spec, a
# contract, a spreadsheet. Its **card** is an ordinary doc beside it, named after it:
#
#   docs/external/vendor-api/payments-spec.pdf
#   docs/external/vendor-api/payments-spec.pdf.md     <- card
#
# The card is what Claude reads first: what the file holds, when to open it, and where
# inside it to look. The name is the link between the two — there is no `source:` key to
# disagree with it. `digest:` (sha256 of the file's bytes, never of a path) is written only
# by `external stamp`, which is what makes "changed since it was carded" mean anything.
#
# Convention, not config: externals live under `<root>/external/<topic>/`, and the top level
# of `<root>/external/` is the drop zone for files not yet filed. Pure bash 3.2 + POSIX awk.

# The extensions that make a file external. One list, in one place.
EXTERNAL_EXTS="pdf doc docx xls xlsx ppt pptx odt ods odp rtf epub"
EXTERNAL_DIR="external"

# is_external_name <name> -> 0 if the name ends in an external extension (any case)
is_external_name() {
  local ext e
  case "$1" in *.*) ;; *) return 1 ;; esac
  ext="$(printf '%s' "${1##*.}" | tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz')"
  for e in $EXTERNAL_EXTS; do [ "$e" = "$ext" ] && return 0; done
  return 1
}

# is_card <path> -> 0 if <path> is a card, i.e. <name>.<external-ext>.md
is_card() {
  case "$1" in *.md) is_external_name "${1%.md}" ;; *) return 1 ;; esac
}

# list_externals <dir> [maxdepth]
#
# External files under <dir>, sorted, one per line. Dot-files are skipped, and so is a
# diagram's rendered artifact — `x.pdf` beside `x.diagram.md` is output of this plugin,
# not reference material.
list_externals() {
  local f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    is_external_name "$f" || continue
    [ -f "${f%.*}.diagram.md" ] && continue
    printf '%s\n' "$f"
  done <<EOF
$(find "$1" ${2:+-maxdepth "$2"} -type f ! -name '.*' ! -name '*.md' | sort)
EOF
  return 0
}

# list_cards <dir> [maxdepth] -> cards under <dir>, sorted, one per line
list_cards() {
  local f
  while IFS= read -r f; do
    [ -n "$f" ] && is_card "$f" && printf '%s\n' "$f"
  done <<EOF
$(find "$1" ${2:+-maxdepth "$2"} -type f -name '*.md' | sort)
EOF
  return 0
}

# sha256_of <file> -> hex digest. BSD/macOS ships `shasum`, GNU and busybox `sha256sum`.
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{ print $1 }'
  else
    echo "ERROR: neither sha256sum nor shasum is available" >&2
    return 1
  fi
}

# external_place <root> <file> -> filed | unfiled | outside
#   filed    under <root>/external/<topic>/
#   unfiled  at the top level of <root>/external/ — the drop zone
#   outside  anywhere else under <root>
external_place() {
  local rel="${2#"$1"/}"
  case "$rel" in
    "$EXTERNAL_DIR"/*/*) echo filed ;;
    "$EXTERNAL_DIR"/*)   echo unfiled ;;
    *)                   echo outside ;;
  esac
}

# external_status <root>
#
# One tab-separated record per external file or card, for the skill and for `check`:
#
#   state<TAB>place<TAB>file<TAB>card
#
# state: ok | new (no card) | unstamped (card has no digest) | changed (digest differs)
#        | orphan (card whose file is gone). An empty field is "-": tab is whitespace to
#        `read`, so a truly empty field would collapse and shift the ones after it.
external_status() {
  local root="$1" f card want have
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    card="$f.md"
    if [ ! -f "$card" ]; then
      printf 'new\t%s\t%s\t-\n' "$(external_place "$root" "$f")" "$f"; continue
    fi
    have="$(fm_field "$card" digest)"
    if [ -z "$have" ]; then
      printf 'unstamped\t%s\t%s\t%s\n' "$(external_place "$root" "$f")" "$f" "$card"; continue
    fi
    want="sha256:$(sha256_of "$f")"
    if [ "$have" != "$want" ]; then
      printf 'changed\t%s\t%s\t%s\n' "$(external_place "$root" "$f")" "$f" "$card"
    else
      printf 'ok\t%s\t%s\t%s\n' "$(external_place "$root" "$f")" "$f" "$card"
    fi
  done <<EOF
$(list_externals "$root")
EOF
  while IFS= read -r card; do
    [ -n "$card" ] || continue
    [ -f "${card%.md}" ] || printf 'orphan\t-\t-\t%s\n' "$card"
  done <<EOF
$(list_cards "$root")
EOF
  return 0
}

# --- commands ---------------------------------------------------------------

cmd_external_status() {
  local root="${1:-$ROOT_DEFAULT}"
  [ -d "$root" ] || { echo "No such root: $root" >&2; return 1; }
  external_status "$root"
}

# external_related <file> <links-file>
#
# The docs that depend on an external file, one record each, each doc once:
#
#   relates-to<TAB>doc     named in the card's `relates-to:` (paths relative to the card)
#   links<TAB>doc          links to the card or to the file itself
#
# <links-file> holds `doc_links` output, so a check over many changed files parses the
# tree's links once. The card itself and generated `_index.md` listings are not dependants.
# A `relates-to:` entry naming a missing doc is left to `links`, which reports it.
external_related() {
  local f card p t
  f="$(normalize_path "$1")"; card="$f.md"
  {
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      t="$(normalize_path "$(dirname "$card")/$p")"
      [ -f "$t" ] && printf 'relates-to\t%s\n' "$t"
    done <<EOF
$(fm_list "$card" relates-to)
EOF
    awk -F'\t' -v f="$f" -v c="$card" '
      ($3 == f || $3 == c) && $1 != c && $1 !~ /(^|\/)_index\.md$/ { printf "links\t%s\n", $1 }
    ' "$2"
  } | awk -F'\t' '!seen[$2]++'
}

# Placement is reported by `status` and never fails `check`: a carded file kept beside the
# doc that uses it is a choice, not a defect. A missing, unstamped or stale card is — and a
# changed file names every doc that depends on it, since those may now say something untrue.
cmd_external_check() {
  local root="${1:-$ROOT_DEFAULT}" rc=0 state place f card links="" kind doc
  [ -d "$root" ] || { echo "No such root: $root" >&2; return 1; }
  while IFS=$'\t' read -r state place f card; do
    case "$state" in
      new)       echo "NO CARD: $f (catalogue it, then: docs.sh external stamp $f)"; rc=1 ;;
      unstamped) echo "UNSTAMPED: $card (run: docs.sh external stamp $f)"; rc=1 ;;
      changed)   echo "CHANGED: $f — review $card, then: docs.sh external stamp $f"; rc=1
                 [ -n "$links" ] || { links="$(mktemp)"; doc_links "$root" > "$links"; }
                 while IFS=$'\t' read -r kind doc; do
                   [ -n "$doc" ] && echo "  REVIEW: $doc ($kind)"
                 done <<EOF2
$(external_related "$f" "$links")
EOF2
                 ;;
      orphan)    echo "ORPHAN CARD: $card (its file is gone)"; rc=1 ;;
    esac
  done <<EOF
$(external_status "$root")
EOF
  [ -z "$links" ] || rm -f "$links"
  return $rc
}

# related <file-or-card> [root] — the docs to review when the file changes
cmd_external_related() {
  local f root links
  [ -n "${1:-}" ] || { echo "Usage: docs.sh external related <file-or-card> [root]" >&2; return 2; }
  f="$(external_source "$1")"; root="${2:-$ROOT_DEFAULT}"
  [ -d "$root" ] || { echo "No such root: $root" >&2; return 1; }
  [ -e "$f" ] || [ -e "$f.md" ] || { echo "No such file or card: $f" >&2; return 1; }
  links="$(mktemp)"; doc_links "$root" > "$links"
  external_related "$f" "$links"
  rm -f "$links"
}

# external_source <path> -> the external file, given it or its card
external_source() {
  if is_card "$1"; then printf '%s\n' "${1%.md}"; else printf '%s\n' "$1"; fi
}

# stamp <file-or-card> — the ONLY writer of `digest:`. Diff-guarded: a card already
# carrying the current digest is not touched.
cmd_external_stamp() {
  local f card digest
  [ -n "${1:-}" ] || { echo "Usage: docs.sh external stamp <file-or-card>" >&2; return 2; }
  f="$(external_source "$1")"; card="$f.md"
  is_external_name "$f" || { echo "Not an external file: $f" >&2; return 1; }
  [ -f "$f" ]    || { echo "No such file: $f" >&2; return 1; }
  [ -f "$card" ] || { echo "No card: $card — write it first" >&2; return 1; }
  digest="sha256:$(sha256_of "$f")" || return 1
  if [ "$(fm_field "$card" digest)" = "$digest" ]; then
    echo "UNCHANGED: $card"; return 0
  fi
  fm_set "$card" digest "$digest"
  echo "STAMPED: $card"
}

# move <file-or-card> <dest-dir> [root] — relocate a file and its card together, then
# report any link the move broke. Links are reported, never rewritten: which doc should
# point where is a judgement for whoever asked for the move.
cmd_external_move() {
  local f card dest root name moved out has_card=0
  [ -n "${1:-}" ] && [ -n "${2:-}" ] || {
    echo "Usage: docs.sh external move <file-or-card> <dest-dir> [root]" >&2; return 2; }
  f="$(external_source "$1")"; card="$f.md"; dest="${2%/}"; root="${3:-$ROOT_DEFAULT}"
  [ -f "$f" ] || { echo "No such file: $f" >&2; return 1; }
  name="$(basename "$f")"
  [ -e "$dest/$name" ] && { echo "Refusing to overwrite: $dest/$name" >&2; return 1; }
  [ -e "$dest/$name.md" ] && { echo "Refusing to overwrite: $dest/$name.md" >&2; return 1; }
  [ -f "$card" ] && has_card=1
  mkdir -p "$dest"
  mv "$f" "$dest/$name" || return 1
  if [ "$has_card" = 1 ] && ! mv "$card" "$dest/$name.md"; then
    mv "$dest/$name" "$f"                 # never leave a file and its card apart
    echo "Card move failed; $f left where it was" >&2; return 1
  fi
  echo "MOVED: $f -> $dest/$name"
  [ "$has_card" = 0 ] || echo "MOVED: $card -> $dest/$name.md"
  [ -d "$root" ] || return 0
  # Broken links that name the moved file — from other docs, or from the card itself,
  # whose own relative links shift when it changes depth.
  out="$(cmd_links "$root" 2>/dev/null || true)"
  moved="$(printf '%s\n' "$out" | awk -v n="$name" -v c="$(normalize_path "$dest/$name.md")" '
    function names(l, x) { return l == x || substr(l, length(l) - length(x)) == "/" x }
    {
      i = index($0, " -> "); if (!i) next
      src = substr($0, 1, i - 1); sub(/^BROKEN [A-Z]+: /, "", src)
      l = substr($0, i + 4)
      if (names(l, n) || names(l, n ".md") || src == c) print
    }')"
  [ -z "$moved" ] || printf '%s\n' "$moved"
  return 0
}

cmd_external() {
  local op="${1:-status}"; shift || true
  case "$op" in
    status) cmd_external_status "$@" ;;
    check)  cmd_external_check "$@" ;;
    stamp)  cmd_external_stamp "$@" ;;
    move)   cmd_external_move "$@" ;;
    related) cmd_external_related "$@" ;;
    outline|text) cmd_external_extract "$op" "$@" ;;
    *) echo "Usage: docs.sh external {status|check|stamp <file>|move <file> <dest-dir>|related <file>|outline <file>|text <file>} [root]" >&2; return 2 ;;
  esac
}
