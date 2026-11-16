#!/usr/bin/env bash
# lib.sh — shared helpers for remote-docs. Sourced, never executed.
#
# SCOPE: this file belongs to remote-docs and is sourced only by remote-docs' own scripts. A
# plugin ships as its own directory and must work with no sibling installed, so nothing here
# may source another plugin's file. These helpers began as copies of docs-manager's (PLUG-144):
# a fix to one is checked against the other, since both read the same card format.
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
# RD_KEEP_IGNORED=1 keeps git-ignored paths. `list`, `diff` and the local-copy walk set it: a
# local-only attachment is git-ignored on purpose and must still be findable (PLUG-112).
docs_find() {
  local root="$1" depth="$2"; shift 2
  find "$root" -mindepth 1 ${depth:+-maxdepth "$depth"} -name '.*' -prune -o \( "$@" -print \) \
    | if [ "${RD_KEEP_IGNORED:-}" = 1 ]; then cat; else drop_git_ignored "$root"; fi
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
  RD_PFX="$root/" awk 'BEGIN { p = ENVIRON["RD_PFX"] } index($0, p) == 1 { print substr($0, length(p) + 1) }' "$list" | tr '\n' '\0' \
    | git -C "$root" check-ignore -z --stdin 2>/dev/null | tr '\0' '\n' > "$ignored" || true
  if [ -s "$ignored" ]; then
    RD_PFX="$root/" awk 'BEGIN { p = ENVIRON["RD_PFX"] } NR == FNR { skip[$0] = 1; next } !(substr($0, length(p) + 1) in skip)' "$ignored" "$list"
  else
    cat "$list"
  fi
  rm -f "$list" "$ignored"
}

# ---------------------------------------------------------------------------
# Frontmatter
# ---------------------------------------------------------------------------

# AWK_FM_COMMENT — awk functions for YAML inline comments (PLUG-140), shared by `fm_parse` and
# `fm_set` so the two never disagree about where a value ends.
#   fm_cpos(s) -> where the comment starts in <s> (the text after `key:` or `-`), counting the blanks
#                 before its `#`; 0 when there is none
#   fm_cut(s)  -> <s> without its comment
# A comment is a `#` with a blank before it, outside quotes: `p#frag` and `"a # b"` keep theirs. A
# quote opens a quoted value only where a value starts (first character, or after `[` / `,` in a flow
# list), so the apostrophe in `it's` is a letter, as in YAML. Quotes as octal escapes (\042, \047):
# this string is single-quoted shell. Callers run it under LC_ALL=C: the walk is byte by byte, and
# macOS awk aborts on a regex match against half of a multibyte character (`1AbC…`).
AWK_FM_COMMENT='
function fm_blank(c) { return c == " " || c == "\t" }
function fm_cpos(s,   n, i, c, q, first, start, flow, w) {
  n = length(s); q = ""; first = 1; start = 1; flow = 0
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (q != "") {
      if (q == "\042" && c == "\\") { i++; continue }
      if (c == q) {
        if (q == "\047" && substr(s, i + 1, 1) == "\047") { i++; continue }
        q = ""
      }
      continue
    }
    if (fm_blank(c)) continue
    if (c == "#" && i > 1 && fm_blank(substr(s, i - 1, 1))) {
      w = i; while (w > 1 && fm_blank(substr(s, w - 1, 1))) w--
      return w
    }
    if (start && (c == "\042" || c == "\047")) { q = c; start = 0; first = 0; continue }
    if (first && c == "[") { flow = 1; first = 0; continue }
    first = 0
    if (flow && c == ",") { start = 1; continue }
    start = 0
  }
  return 0
}
function fm_cut(s,   p) { p = fm_cpos(s); return p ? substr(s, 1, p - 1) : s }
'

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
#
# An inline ` # comment` is dropped from every value, and a comment line is skipped without
# ending the block it sits in (AWK_FM_COMMENT).
fm_parse() {
  LC_ALL=C awk "$AWK_FM_COMMENT"'
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function unquote(s) {
      if (s ~ /^".*"$/ || s ~ /^'"'"'.*'"'"'$/) s = substr(s, 2, length(s) - 2)
      return s
    }
    NR == 1 && $0 != "---" { exit }        # no frontmatter at all
    NR == 1 { next }
    $0 == "---" { exit }                   # end of frontmatter
    /^[ \t]*#/ { next }                     # a comment line: the pending block goes on

    # nested entry under a pending key: "  - item"  or  "  sub: value"
    /^[ \t]+-[ \t]*/ {
      if (pending == "") next
      item = unquote(trim(fm_cut(substr($0, index($0, "-") + 1))))
      if (item != "") printf "list\t%s\t%s\n", pending, item
      next
    }
    /^[ \t]+[A-Za-z0-9_.-]+[ \t]*:/ {
      if (pending == "") next
      line = trim($0)
      c = index(line, ":")
      sub_key = trim(substr(line, 1, c - 1))
      val = unquote(trim(fm_cut(substr(line, c + 1))))
      printf "map\t%s\t%s\t%s\n", pending, sub_key, val
      next
    }

    # top-level "key: ..." — anything else ends the pending block
    /^[A-Za-z0-9_.-]+[ \t]*:/ {
      c = index($0, ":")
      key = trim(substr($0, 1, c - 1))
      val = trim(fm_cut(substr($0, c + 1)))
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
# fm_set <file> <key> <value>
#
# Set one scalar frontmatter key in place, replacing it if present and appending it
# to the end of the frontmatter if not. **Every other byte of the file is preserved**
# — this writes a review record into someone's document, so it must not reformat,
# reorder or reflow anything it does not own — a trailing ` # comment` on the line it
# rewrites included (PLUG-140).
#
# Writes via temp file + mv: `sed -i` is not portable (BSD needs `-i ''`, GNU rejects
# it) and the temp-file route is atomic besides.
fm_set() {
  local file="$1" key="$2" val="$3" tmp
  tmp="$(mktemp)"
  LC_ALL=C awk -v key="$key" -v val="$val" "$AWK_FM_COMMENT"'
    NR == 1 && $0 != "---" { print; nofm = 1; next }   # no frontmatter: leave alone
    nofm { print; next }
    NR == 1 { print; infm = 1; next }
    infm && $0 == "---" {
      if (!seen) print key ": " val                     # append before the closer
      print; infm = 0; next
    }
    infm {
      k = $0; sub(/[ \t]*:.*$/, "", k)
      if (k == key) {
        rest = substr($0, index($0, ":") + 1); p = fm_cpos(rest)
        print key ": " val (p ? substr(rest, p) : ""); seen = 1; next
      }
      print; next
    }
    { print }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

