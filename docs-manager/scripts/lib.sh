#!/bin/bash
# lib.sh — shared helpers for docs-manager. Sourced, never executed.
#
# SCOPE: this file belongs to docs-manager and is sourced only by docs-manager's own
# scripts. It is NOT a repo-wide library — a plugin ships as its own directory and
# must work with no sibling plugin installed, so nothing here may be shared across
# plugins and nothing here may source another plugin's file.
#
# Pure bash 3.2 + POSIX awk. No associative arrays, no GNU-only flags, no `sed -i`.

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
fm_field() {
  fm_parse "$1" | awk -F'\t' -v k="$2" '$1=="scalar" && $2==k { print $3; exit }'
}

# fm_list <file> <key>   -> one item per line
fm_list() {
  fm_parse "$1" | awk -F'\t' -v k="$2" '$1=="list" && $2==k { print $3 }'
}

# fm_map <file> <key>    -> "subkey<TAB>value" per line
fm_map() {
  fm_parse "$1" | awk -F'\t' -v k="$2" '$1=="map" && $2==k { printf "%s\t%s\n", $3, $4 }'
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
