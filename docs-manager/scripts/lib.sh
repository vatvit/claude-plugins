#!/usr/bin/env bash
# lib.sh — shared helpers for docs-manager. Sourced, never executed.
#
# SCOPE: this file belongs to docs-manager and is sourced only by docs-manager's own
# scripts. It is NOT a repo-wide library — a plugin ships as its own directory and
# must work with no sibling plugin installed, so nothing here may be shared across
# plugins and nothing here may source another plugin's file.
#
# Pure bash 3.2 + POSIX awk. No associative arrays, no GNU-only flags, no `sed -i`.

# ---------------------------------------------------------------------------
# Walking the docs tree
# ---------------------------------------------------------------------------

# docs_find <root> <maxdepth|""> <find tests...> -> matching paths below <root>, unsorted
#
# Every walk of the docs tree goes through here, so all of them skip the same things:
# any dot-entry at any depth — `.git/` (a docs folder that is its own repository),
# `.obsidian/`, `.vitepress/`, a hidden file — is pruned with everything under it. The
# root itself is never pruned (`-mindepth 1`), so a root named `.site-docs` still works,
# and is not printed: callers that want it add it. The tests are fixed strings from
# this plugin's own scripts, never user input.
#
# DM_KEEP_IGNORED=1 keeps git-ignored paths. Only `external remote` sets it: a local-only
# remote attachment is git-ignored on purpose and must still be findable (PLUG-112).
docs_find() {
  local root="$1" depth="$2"; shift 2
  find "$root" -mindepth 1 ${depth:+-maxdepth "$depth"} -name '.*' -prune -o \( "$@" -print \) \
    | if [ "${DM_KEEP_IGNORED:-}" = 1 ]; then cat; else drop_git_ignored "$root"; fi
}

# drop_git_ignored <root> — stdin: paths below <root> as `find` printed them; stdout: those
# git does not ignore (PLUG-093). A project keeps third-party material in a git-ignored docs
# folder; indexing it would put a link to a folder that is not in git, and its file names,
# into a committed index.
#
# Outside a git repo — or when <root> itself is ignored, which means the user pointed at it
# on purpose — the stream passes through untouched. One `git check-ignore --stdin` per walk,
# never one process per file. A tracked file is never reported ignored, so `git add -f`
# keeps a doc listed. Paths go in relative to <root> (`git -C <root>`), NUL-separated, so a
# root outside the current directory and odd file names both work.
drop_git_ignored() {
  local root="${1%/}" list ignored
  if ! command -v git >/dev/null 2>&1 || ! git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
     || git -C "$root" check-ignore -q -- . 2>/dev/null; then
    cat; return 0
  fi
  list="$(mktemp)"; ignored="$(mktemp)"
  cat > "$list"
  # `|| true`: check-ignore exits 1 when nothing is ignored, which is the normal case.
  DM_PFX="$root/" awk 'BEGIN { p = ENVIRON["DM_PFX"] } index($0, p) == 1 { print substr($0, length(p) + 1) }' "$list" | tr '\n' '\0' \
    | git -C "$root" check-ignore -z --stdin 2>/dev/null | tr '\0' '\n' > "$ignored" || true
  if [ -s "$ignored" ]; then
    DM_PFX="$root/" awk 'BEGIN { p = ENVIRON["DM_PFX"] } NR == FNR { skip[$0] = 1; next } !(substr($0, length(p) + 1) in skip)' "$ignored" "$list"
  else
    cat "$list"
  fi
  rm -f "$list" "$ignored"
}

# ---------------------------------------------------------------------------
# Frontmatter
# ---------------------------------------------------------------------------

# fm_parse <file>
#
# One awk pass over the YAML frontmatter, emitting tab-separated typed records in
# the order the author wrote them:
#
#   scalar<TAB>title<TAB>Auth flow
#   list<TAB>watch<TAB>src/auth/
#   map<TAB>refs<TAB>api<TAB>file:src/api/gateway.ts
#
# A map is never held in bash — consumers filter the stream with awk and read it
# with `while IFS=$'\t' read -r`. That is what keeps this working on bash 3.2,
# which has no associative arrays.
#
# Recognised shapes:
#   key: value            -> scalar
#   key: [a, b]           -> list (inline)
#   key:                  -> list  (following `  - item` lines)
#   key:                  -> map   (following `  sub: value` lines)
fm_parse() {
  awk '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function unquote(s) {
      if (s ~ /^".*"$/ || s ~ /^'"'"'.*'"'"'$/) s = substr(s, 2, length(s) - 2)
      return s
    }
    NR == 1 && $0 != "---" { exit }        # no frontmatter at all
    NR == 1 { next }
    $0 == "---" { exit }                   # end of frontmatter

    # nested entry under a pending key: "  - item"  or  "  sub: value"
    /^[ \t]+-[ \t]*/ {
      if (pending == "") next
      item = unquote(trim(substr($0, index($0, "-") + 1)))
      if (item != "") printf "list\t%s\t%s\n", pending, item
      next
    }
    /^[ \t]+[A-Za-z0-9_.-]+[ \t]*:/ {
      if (pending == "") next
      line = trim($0)
      c = index(line, ":")
      sub_key = trim(substr(line, 1, c - 1))
      val = unquote(trim(substr(line, c + 1)))
      printf "map\t%s\t%s\t%s\n", pending, sub_key, val
      next
    }

    # top-level "key: ..." — anything else ends the pending block
    /^[A-Za-z0-9_.-]+[ \t]*:/ {
      c = index($0, ":")
      key = trim(substr($0, 1, c - 1))
      val = trim(substr($0, c + 1))
      pending = ""

      if (val == "") { pending = key; next }              # block list or map follows

      if (val ~ /^\[.*\]$/) {                             # inline list
        inner = substr(val, 2, length(val) - 2)
        n = split(inner, parts, ",")
        for (i = 1; i <= n; i++) {
          item = unquote(trim(parts[i]))
          if (item != "") printf "list\t%s\t%s\n", key, item
        }
        next
      }

      printf "scalar\t%s\t%s\n", key, unquote(val)
      next
    }

    { pending = "" }
  ' "$1" 2>/dev/null
}

# fm_field <file> <key>  -> first scalar value for key (empty if absent)
#
# Reads to the end rather than `exit`ing on the match: an early exit can SIGPIPE fm_parse
# while it is still writing, and under `pipefail` that kills the caller with rc 141 — only
# sometimes, which is how it hid until the container suite caught it.
fm_field() {
  fm_parse "$1" | awk -F'\t' -v k="$2" '!done && $1=="scalar" && $2==k { print $3; done = 1 }'
}

# fm_list <file> <key>   -> one item per line
fm_list() {
  fm_parse "$1" | awk -F'\t' -v k="$2" '$1=="list" && $2==k { print $3 }'
}

# fm_map <file> <key>    -> "subkey<TAB>value" per line
fm_map() {
  fm_parse "$1" | awk -F'\t' -v k="$2" '$1=="map" && $2==k { printf "%s\t%s\n", $3, $4 }'
}

# fm_set <file> <key> <value>
#
# Set one scalar frontmatter key in place, replacing it if present and appending it
# to the end of the frontmatter if not. **Every other byte of the file is preserved**
# — this writes a review record into someone's document, so it must not reformat,
# reorder or reflow anything it does not own.
#
# Writes via temp file + mv: `sed -i` is not portable (BSD needs `-i ''`, GNU rejects
# it) and the temp-file route is atomic besides.
fm_set() {
  local file="$1" key="$2" val="$3" tmp
  tmp="$(mktemp)"
  awk -v key="$key" -v val="$val" '
    NR == 1 && $0 != "---" { print; nofm = 1; next }   # no frontmatter: leave alone
    nofm { print; next }
    NR == 1 { print; infm = 1; next }
    infm && $0 == "---" {
      if (!seen) print key ": " val                     # append before the closer
      print; infm = 0; next
    }
    infm {
      k = $0; sub(/[ \t]*:.*$/, "", k)
      if (k == key) { print key ": " val; seen = 1; next }
      print; next
    }
    { print }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

# normalize_path <path> — lexically collapse . and .. (no filesystem access).
normalize_path() {
  awk -v p="$1" 'BEGIN{
    n=split(p, parts, "/"); top=0
    for(i=1;i<=n;i++){ s=parts[i]
      if(s=="."||s=="") continue
      if(s==".."){ if(top>0 && stack[top]!="..") top--; else { top++; stack[top]=s } }
      else { top++; stack[top]=s } }
    out=(substr(p,1,1)=="/")?"/":""
    for(i=1;i<=top;i++){ out=out stack[i]; if(i<top) out=out "/" }
    print out }'
}

# md_link_dests <file> -> the destination of every inline link `[text](dest)`, one per line
#
# CommonMark destinations: `<…>` may hold spaces and parentheses; a bare one ends at
# whitespace or at the `)` that balances the opening one — so `a (1).docx` needs the `<…>`
# form or `%20`, and `x.md "Title"` yields `x.md`. A regex stopping at the first `)` gets
# both wrong. Lines inside a fenced code block (``` or ~~~) hold examples and yield nothing.
# With a second argument, each line is `<line number><TAB><dest>`.
md_link_dests() {
  awk -v withline="${2:-}" '
  /^ *(```|~~~)/ { infence = !infence; next }
  infence { next }
  {
    s = $0
    while ((i = index(s, "](")) > 0) {
      s = substr(s, i + 2); sub(/^[ \t]+/, "", s)
      if (substr(s, 1, 1) == "<") {
        j = index(s, ">"); if (!j) continue
        print (withline ? NR "\t" : "") substr(s, 2, j - 2); s = substr(s, j + 1); continue
      }
      d = ""; depth = 0; n = length(s)
      for (k = 1; k <= n; k++) {
        c = substr(s, k, 1)
        if (c == "(") depth++
        else if (c == ")") { if (depth == 0) break; depth-- }
        else if (c == " " || c == "\t") break
        d = d c
      }
      s = substr(s, k)
      if (d != "") print (withline ? NR "\t" : "") d
    }
  }' "$1" 2>/dev/null
}

# url_decode <s> -> <s> with %XX escapes decoded. In the shell, not awk: awk's `%c` emits a
# multibyte character for values over 127 in a UTF-8 locale (gawk), so `%C3%A9` would not
# come back as `é`. printf '%b' with \xHH writes raw bytes on bash 3.2 and 5 alike.
url_decode() {
  printf '%b' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g')"
}

# md_dest <path> -> <path> as a link destination: wrapped in `<…>` when it holds a space or
# a parenthesis (which a bare destination cannot carry), unchanged otherwise — so a link to
# an ordinary name is written byte-identically to what earlier versions wrote.
md_dest() {
  case "$1" in *[\ \(\)]*) printf '<%s>' "$1" ;; *) printf '%s' "$1" ;; esac
}

# doc_link_records <root>
#
# Every relative markdown link in every .md under <root> — including a same-file `#fragment`
# link — one record each, fields tab-separated (an awk consumer splits on tab; fields 4 and 5
# may be empty, so never `read` them):
#
#   file<TAB>line<TAB>target<TAB>fragment<TAB>link
#
# `link` is the destination minus any #fragment or ?query, with %XX escapes decoded (empty for a
# same-file link); `fragment` is decoded the same way; `target` is the path the link resolves to
# (the file itself for a same-file link), normalized, as are the file paths. The **only**
# markdown link parser in this plugin — the broken-link check, the anchor check and the
# back-link search all read this stream, so they cannot disagree about what a link is.
doc_link_records() {
  local file base entry line link frag
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    file="$(normalize_path "$file")"; base="$(dirname "$file")"
    while IFS=$'\t' read -r line entry; do
      [ -n "$entry" ] || continue
      link="$entry"; frag=""
      case "$link" in http://*|https://*|mailto:*|"") continue ;; esac
      case "$link" in *#*) frag="${link#*#}"; link="${link%%#*}" ;; esac
      link="${link%%\?*}"
      [ -n "$link" ] || [ -n "$frag" ] || continue
      case "$link" in *%*) link="$(url_decode "$link")" ;; esac
      case "$frag" in *%*) frag="$(url_decode "$frag")" ;; esac
      if [ -z "$link" ]; then
        printf '%s\t%s\t%s\t%s\t\n' "$file" "$line" "$file" "$frag"
      else
        case "$link" in
          /*) printf '%s\t%s\t%s\t%s\t%s\n' "$file" "$line" "$(normalize_path "$link")" "$frag" "$link" ;;
          *)  printf '%s\t%s\t%s\t%s\t%s\n' "$file" "$line" "$(normalize_path "$base/$link")" "$frag" "$link" ;;
        esac
      fi
    done <<EOF
$(md_link_dests "$file" n)
EOF
  done <<EOF
$(docs_find "$1" "" -type f -name '*.md' | sort)
EOF
  return 0
}

# doc_links <root> -> `file<TAB>link<TAB>target`, one per link that names a file (a same-file
# `#fragment` link names none). What the path-existence check and `external related` read.
doc_links() {
  doc_link_records "$1" | awk -F'\t' '$5 != "" { print $1 "\t" $5 "\t" $3 }'
}

# AWK_FOLD — an awk function `lc(s)`: lower-case for comparing a heading's slug with a link's
# fragment. Run under LC_ALL=C so every awk sees bytes. `tolower` alone is not enough: BSD awk and
# gawk lower-case `Ü`, busybox does not, so the same heading would slug differently per target.
# Folds the UTF-8 letters that matter in practice — Latin-1, Greek, Cyrillic — and leaves the
# rest as written, which can only make a link GitHub accepts look broken on a heading that
# differs from it only in the case of an exotic letter.
AWK_FOLD='
function ord(c) { if (!ORDINIT) { for (i = 128; i < 256; i++) ORD[sprintf("%c", i)] = i; ORDINIT = 1 } return ORD[c] }
function lc(s,   out, n, i, c, d, b) {
  s = tolower(s); out = ""; n = length(s)
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (c == "\303" || c == "\316" || c == "\320") {
      d = substr(s, i + 1, 1); b = ord(d)
      if (c == "\303" && b >= 128 && b <= 158 && b != 151) { out = out c sprintf("%c", b + 32); i++; continue }
      if (c == "\316" && b >= 145 && b <= 159) { out = out c sprintf("%c", b + 32); i++; continue }
      if (c == "\316" && b >= 160 && b <= 171 && b != 162) { out = out "\317" sprintf("%c", b - 32); i++; continue }
      if (c == "\320" && b >= 144 && b <= 159) { out = out c sprintf("%c", b + 32); i++; continue }
      if (c == "\320" && b >= 160 && b <= 175) { out = out "\321" sprintf("%c", b - 32); i++; continue }
      if (c == "\320" && b >= 128 && b <= 143) { out = out "\321" sprintf("%c", b + 16); i++; continue }
    }
    out = out c
  }
  return out
}'

# md_anchors <file> -> every anchor a link into <file> can name, one per line:
#   `s:<slug>`  a heading's GitHub-style slug: lower-cased, punctuation dropped except `-` and
#               `_`, each space a `-`, non-ASCII letters kept; a repeat of a slug gets `-1`, `-2`…
#   `i:<id>`    an explicit anchor — `id="…"` or `name="…"` on any HTML tag, e.g. `<a id="x">`
# ATX headings (`## x`) only; lines inside a code fence count for nothing. A heading's inline
# markup reduces to its text: a link to its text, `<tags>` and punctuation (backticks, `*`) dropped.
# Non-ASCII punctuation GitHub also drops is listed in the split() below; any other is kept,
# which can only make this check accept a link GitHub would reject, never the reverse.
# Bytes >= 0x80 never appear in the ASCII DROP set, so the char loop is the same on gawk
# (chars) and busybox/BSD awk (bytes).
md_anchors() {
  LC_ALL=C awk "$AWK_FOLD"'
  function attr(tag, name,   re, m, v) {
    re = "[ \t]" name "=\"[^\"]*\""
    if (match(tag, re)) { m = substr(tag, RSTART, RLENGTH); v = substr(m, index(m, "\"") + 1); sub(/"$/, "", v); return v }
    re = "[ \t]" name "=\047[^\047]*\047"
    if (match(tag, re)) { m = substr(tag, RSTART, RLENGTH); v = substr(m, index(m, "\047") + 1); sub(/\047$/, "", v); return v }
    return ""
  }
  function slug(h,   i, n, c, out, k, p, m) {
    while (match(h, /\[[^]]*\]\([^)]*\)/)) {
      m = substr(h, RSTART, RLENGTH)
      h = substr(h, 1, RSTART - 1) substr(m, 2, index(m, "](") - 2) substr(h, RSTART + RLENGTH)
    }
    gsub(/<[^>]*>/, "", h)
    h = lc(h)
    for (k = 1; k <= nu; k++) while ((p = index(h, UP[k])) > 0) h = substr(h, 1, p - 1) substr(h, p + length(UP[k]))
    out = ""; n = length(h)
    for (i = 1; i <= n; i++) {
      c = substr(h, i, 1)
      if (c == " " || c == "\t") out = out "-"
      else if (index(DROP, c) == 0) out = out c
    }
    return out
  }
  BEGIN {
    DROP = "!\"#$%&\047()*+,./:;<=>?@[\\]^`{|}~"
    nu = split("— – “ ” ‘ ’ … « » · × ¿ ¡ • ©", UP, " ")
  }
  /^ *(```|~~~)/ { infence = !infence; next }
  infence { next }
  {
    s = $0
    while (match(s, /<[A-Za-z][^>]*>/)) {
      tag = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
      if ((v = attr(tag, "id")) != "") print "i:" v
      if ((v = attr(tag, "name")) != "") print "i:" v
    }
  }
  /^ *#+([ \t]|$)/ {
    h = $0; indent = h; sub(/[^ ].*$/, "", indent); if (length(indent) > 3) next
    sub(/^ +/, "", h)
    hashes = h; sub(/[^#].*$/, "", hashes); if (length(hashes) > 6) next
    sub(/^#+[ \t]*/, "", h)
    sub(/[ \t]+#+[ \t]*$/, "", h); sub(/^#+[ \t]*$/, "", h); sub(/[ \t]+$/, "", h)
    base = slug(h); sl = base
    if (base in seen) {
      n = seen[base]
      do { sl = base "-" n; n++ } while (sl in used)
      seen[base] = n
    } else seen[base] = 1
    used[sl] = 1
    if (sl != "") print "s:" sl
  }' "$1"
}

# relpath <from-dir> <to-path>
#
# The path to <to-path> as seen from <from-dir>. Purely lexical — no filesystem
# access, and both arguments should already be normalized.
#
# Needed because a ref is written relative to the .diagram.md that declares it, but
# the link has to work from each doc that embeds it — and one source may be embedded
# at several depths, which is exactly what makes a stored relative path wrong.
relpath() {
  awk -v from="$1" -v to="$2" 'BEGIN{
    nf = split(from, f, "/"); nt = split(to, t, "/")
    # drop empty components (leading "/" or "./" artefacts)
    af = 0; for (i = 1; i <= nf; i++) if (f[i] != "" && f[i] != ".") F[++af] = f[i]
    at = 0; for (i = 1; i <= nt; i++) if (t[i] != "" && t[i] != ".") T[++at] = t[i]

    c = 0
    while (c < af && c < at && F[c+1] == T[c+1]) c++

    out = ""
    for (i = c + 1; i <= af; i++) out = out "../"
    for (i = c + 1; i <= at; i++) { out = out T[i]; if (i < at) out = out "/" }
    if (out == "") out = "."
    print out
  }'
}

# parse_ref <value>
#
# Split a ref value into "scheme<TAB>path<TAB>label". The label is an optional
# trailing double-quoted string; when absent the field is empty and the caller
# falls back to the ref key.
#
#   file:../../src/api/gateway.ts "API gateway"  ->  file<TAB>../../src/api/gateway.ts<TAB>API gateway
#   url:https://example.com/rfc                  ->  url<TAB>https://example.com/rfc<TAB>
parse_ref() {
  awk -v v="$1" 'BEGIN{
    label = ""
    # a trailing "..." is the label
    if (match(v, /[ \t]+"[^"]*"[ \t]*$/)) {
      lab = substr(v, RSTART, RLENGTH)
      v = substr(v, 1, RSTART - 1)
      sub(/^[ \t]+"/, "", lab); sub(/"[ \t]*$/, "", lab)
      label = lab
    }
    sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
    c = index(v, ":")
    if (c == 0) { printf "\t%s\t%s\n", v, label; exit }
    printf "%s\t%s\t%s\n", substr(v, 1, c - 1), substr(v, c + 1), label
  }'
}

# ---------------------------------------------------------------------------
# Marked-block rewriting
# ---------------------------------------------------------------------------

# block_rewrite <file> <start-marker> <end-marker> <blockfile>
#
# Print <file> to stdout with the region between the markers replaced by the
# contents of <blockfile> (markers included in the replacement). Text outside the
# markers is preserved byte for byte. If the start marker is absent, the file is
# printed unchanged — callers decide whether to append.
#
# The block is passed via a temp file read with getline, never `awk -v`: awk
# variables cannot carry newlines, and doing so reintroduces the "newline in
# string" bug.
block_rewrite() {
  awk -v start="$2" -v end="$3" -v bf="$4" '
    $0==start { while ((getline line < bf) > 0) print line; close(bf); skipping=1; next }
    $0==end   { skipping=0; next }
    !skipping { print }
  ' "$1"
}

# has_marker <file> <marker>
has_marker() { grep -qF "$2" "$1"; }

# ---------------------------------------------------------------------------
# Writing
# ---------------------------------------------------------------------------

# write_if_changed <tmp> <target> [label]
#
# Diff-guarded move: an unchanged target is never touched, which is what makes the
# generators idempotent. Returns 0 and prints "UPDATED: <target>" when it wrote,
# 1 when there was nothing to do.
write_if_changed() {
  local tmp="$1" target="$2" label="${3:-UPDATED}"
  if diff -q "$tmp" "$target" >/dev/null 2>&1; then
    rm -f "$tmp"
    return 1
  fi
  mv "$tmp" "$target"
  echo "$label: $target"
  return 0
}
