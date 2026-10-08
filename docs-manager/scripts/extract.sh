#!/usr/bin/env bash
# extract.sh — read the structure and text out of an external file that cannot be read natively.
# Sourced by docs.sh, never executed. Relies on lib.sh and external.sh being sourced first.
#
# docx and xlsx are zip packages of XML (OOXML), so `unzip -p` plus awk reads them with no
# runtime and nothing installed: `unzip` ships with macOS and with busybox. Every other format
# falls back to a `none` record saying why — the card is then written from what the user says.
#
#   outline   docx: heading<TAB>level<TAB>text
#             xlsx: sheet<TAB>name<TAB>range<TAB>A:header | B:header …
#   text      docx: one paragraph per line, headings as markdown `#`
#             xlsx: `## <sheet> (<range>)`, then row<TAB>A<TAB>B… per row
#   either    none<TAB>reason            (exit 0: no extractor is the normal case, not an error)
#
# Output goes to stdout only. A caller keeping it writes it to a temp dir, never the repo.

# awk helpers shared by every OOXML program, prepended to each. Records are split on "<", so
# each record is one tag plus the text that follows it: `w:t xml:space="preserve">Fees`.
AWK_XML='
function tag(r) { match(r, /^\/?[^ \t\r\n\/>]+/); return substr(r, 1, RLENGTH) }
function lname(t,   c, s) { c = substr(t, 1, 1) == "/"; s = c ? substr(t, 2) : t; sub(/^[^:]*:/, "", s); return (c ? "/" : "") s }
function body(r,   i) { i = index(r, ">"); return i ? substr(r, i + 1) : "" }
function selfclosing(r,   i) { i = index(r, ">"); return i > 1 && substr(r, i - 1, 1) == "/" }
function unxml(s) {
  gsub(/[\t\r\n]/, " ", s)
  gsub(/&lt;/, "<", s); gsub(/&gt;/, ">", s); gsub(/&quot;/, "\"", s); gsub(/&apos;/, "\047", s)
  gsub(/&amp;/, "\\&", s)
  return s
}
function attr(r, n,   s, q, e) {
  if (!match(r, "[ \t\r\n]" n "=[\"\047]")) return ""
  q = substr(r, RSTART + RLENGTH - 1, 1); s = substr(r, RSTART + RLENGTH)
  e = index(s, q); return e ? unxml(substr(s, 1, e - 1)) : ""
}
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
'

# ooxml_part <file> <member> -> the member's bytes, or nothing. Info-ZIP exits 11 and busybox
# 0 for a missing member, so "empty" is the only portable test.
ooxml_part() { unzip -p "$1" "$2" 2>/dev/null || true; }

# extract_kind <file> -> docx | xlsx | none<TAB>reason
#
# The one place that decides whether a file can be extracted, and with what. Absence of a
# tool or of a readable package yields `none`, never an error.
extract_kind() {
  local f="$1" ext main
  ext="$(printf '%s' "${f##*.}" | tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz')"
  case "$ext" in
    pdf)       printf 'none\tpdf: read it natively, in page ranges\n'; return 0 ;;
    docx)      main="word/document.xml" ;;
    xlsx)      main="xl/workbook.xml" ;;
    doc|xls|ppt)
      printf 'none\t%s: legacy binary format; ask for a PDF export or a description\n' "$ext"; return 0 ;;
    *)         printf 'none\t%s: no extractor; ask for a PDF export or a description\n' "$ext"; return 0 ;;
  esac
  command -v unzip >/dev/null 2>&1 || { printf 'none\tunzip not available\n'; return 0; }
  if [ -z "$(ooxml_part "$f" "$main" | awk 'NR == 1 { print "y" } { exit }')" ]; then
    printf 'none\tnot a readable %s package\n' "$ext"; return 0
  fi
  printf '%s\n' "$ext"
}

# docx_extract <file> outline|text
#
# styles.xml first, then document.xml, split by a sentinel record so one awk pass sees both
# (FNR==NR breaks when the first input is empty, and styles.xml is optional). A heading level
# comes from the paragraph's own outlineLvl, else its style's — by name ("heading 2"), by the
# style's outlineLvl, or, without styles.xml, by a HeadingN style id.
docx_extract() {
  { ooxml_part "$1" word/styles.xml; printf '<@@DOC@@>'; ooxml_part "$1" word/document.xml; } |
  awk -v mode="$2" "$AWK_XML"'
    BEGIN { RS = "<" }
    /^@@DOC@@>/ { doc = 1; next }
    !doc {
      t = tag($0)
      if (t == "w:style") cur = attr($0, "w:styleId")
      else if (t == "/w:style") cur = ""
      else if (t == "w:name" && cur != "") {
        n = tolower(attr($0, "w:val"))
        if (n ~ /^heading [1-9]$/) lvl[cur] = substr(n, 9) + 0
        else if (n == "title") lvl[cur] = 1
      } else if (t == "w:outlineLvl" && cur != "" && !(cur in lvl)) {
        v = attr($0, "w:val") + 1; if (v >= 1 && v <= 9) lvl[cur] = v
      }
      next
    }
    {
      t = tag($0)
      if (t == "w:p") {
        if (selfclosing($0)) next
        if (++depth == 1) { txt = ""; plvl = 0 }
      } else if (t == "/w:p") {
        if (depth == 1) emit()
        if (depth > 0) depth--
      } else if (depth) {
        if (t == "w:pStyle") {
          s = attr($0, "w:val")
          if (s in lvl) plvl = lvl[s]
          else if (tolower(s) ~ /^heading[1-9]$/) plvl = substr(s, 8) + 0
          else if (tolower(s) == "title") plvl = 1
        } else if (t == "w:outlineLvl") {
          v = attr($0, "w:val") + 1; if (v >= 1 && v <= 9) plvl = v
        } else if (t == "w:t") txt = txt unxml(body($0))
        else if (t == "w:tab" || t == "w:br" || t == "w:cr") txt = txt " "
      }
    }
    function emit(   h) {
      gsub(/  +/, " ", txt); txt = trim(txt); if (txt == "") return
      if (mode == "outline") { if (plvl) printf "heading\t%d\t%s\n", plvl, txt; return }
      h = ""; while (length(h) < plvl) h = h "#"
      print (plvl ? h " " : "") txt
    }'
}

# xlsx_sheets <file> -> name<TAB>member per sheet, in workbook (tab) order, not file order.
xlsx_sheets() {
  { ooxml_part "$1" xl/workbook.xml; printf '<@@RELS@@>'; ooxml_part "$1" xl/_rels/workbook.xml.rels; } |
  awk "$AWK_XML"'
    BEGIN { RS = "<" }
    /^@@RELS@@>/ { rels = 1; next }
    !rels && lname(tag($0)) == "sheet" { n++; name[n] = attr($0, "name"); rid[n] = attr($0, "r:id") }
    rels && lname(tag($0)) == "Relationship" { tgt[attr($0, "Id")] = attr($0, "Target") }
    END {
      for (i = 1; i <= n; i++) {
        p = tgt[rid[i]]; if (p == "") continue
        if (substr(p, 1, 1) == "/") p = substr(p, 2); else p = "xl/" p
        printf "%s\t%s\n", name[i], p
      }
    }'
}

# xlsx_extract <file> outline|text
#
# Per sheet: sharedStrings.xml, a sentinel, then the sheet. Cells are placed by their `r`
# reference, so a sparse row keeps its columns. Element names are compared without their
# namespace prefix — some writers emit `x:row`, most emit `row`.
xlsx_extract() {
  local name member
  while IFS=$'\t' read -r name member; do
    [ -n "$member" ] || continue
    { ooxml_part "$1" xl/sharedStrings.xml; printf '<@@SHEET@@>'; ooxml_part "$1" "$member"; } |
    SHEET="$name" awk -v mode="$2" "$AWK_XML"'
      BEGIN { RS = "<"; k = -1; ref = "-" }
      /^@@SHEET@@>/ { sheet = 1; if (mode == "text") head = 1; next }
      !sheet {
        t = lname(tag($0))
        if (t == "si") k++
        else if (t == "rPh") rph = 1
        else if (t == "/rPh") rph = 0
        else if (t == "t" && !rph && k >= 0) sst[k] = sst[k] unxml(body($0))
        next
      }
      {
        t = lname(tag($0))
        if (t == "dimension") ref = attr($0, "ref")
        else if (t == "row") {
          if (head) { printf "## %s (%s)\n", ENVIRON["SHEET"], ref; head = 0 }
          row = attr($0, "r"); last = 0; maxc = 0; split("", cell)
          if (selfclosing($0)) endrow()
        } else if (t == "/row") endrow()
        else if (t == "c") {
          col = colnum(attr($0, "r")); if (!col) col = last + 1
          last = col; ct = attr($0, "t"); val = ""
          if (selfclosing($0)) put()
        } else if (t == "/c") put()
        else if (t == "v") val = unxml(body($0))
        else if (t == "t") val = val unxml(body($0))
      }
      function put() {
        if (ct == "s" && val != "") val = sst[val + 0]
        cell[col] = val; if (col > maxc) maxc = col
      }
      function endrow(   i, out) {
        if (mode == "outline") {
          if (header != "" || done) return
          for (i = 1; i <= maxc; i++) if (cell[i] != "")
            header = header (header == "" ? "" : " | ") letters(i) ":" cell[i]
          if (header != "") done = 1
          return
        }
        out = row; for (i = 1; i <= maxc; i++) out = out "\t" cell[i]
        print out
      }
      function colnum(r,   i, c, n) {
        n = 0
        for (i = 1; i <= length(r); i++) {
          c = index("ABCDEFGHIJKLMNOPQRSTUVWXYZ", substr(r, i, 1)); if (!c) break
          n = n * 26 + c
        }
        return n
      }
      function letters(n,   s) {
        s = ""; while (n > 0) { s = substr("ABCDEFGHIJKLMNOPQRSTUVWXYZ", (n - 1) % 26 + 1, 1) s; n = int((n - 1) / 26) }
        return s
      }
      END {
        if (mode == "outline") printf "sheet\t%s\t%s\t%s\n", ENVIRON["SHEET"], ref, (header == "" ? "-" : header)
        else if (head) printf "## %s (%s)\n", ENVIRON["SHEET"], ref
      }'
  done <<EOF
$(xlsx_sheets "$1")
EOF
  return 0
}

# --- commands ---------------------------------------------------------------

# outline|text <file-or-card>
cmd_external_extract() {
  local mode="$1" f kind
  [ -n "${2:-}" ] || { echo "Usage: docs.sh external $mode <file-or-card>" >&2; return 2; }
  f="$(external_source "$2")"
  [ -f "$f" ] || { echo "No such file: $f" >&2; return 1; }
  kind="$(extract_kind "$f")"
  case "$kind" in
    docx) docx_extract "$f" "$mode" ;;
    xlsx) xlsx_extract "$f" "$mode" ;;
    *)    printf '%s\n' "$kind" ;;
  esac
}
