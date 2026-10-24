#!/usr/bin/env bash
# extract.sh — read the structure and text out of an external file that cannot be read natively.
# Sourced by docs.sh, never executed. Relies on lib.sh and external.sh being sourced first.
#
# docx, xlsx, pptx (OOXML) and odt, ods, odp (OpenDocument) are zip packages of XML, so
# `unzip -p` plus awk reads them with no runtime and nothing installed: `unzip` ships with macOS
# and with busybox. Every other format falls back to a `none` record saying why — the card is
# then written from what the user says.
#
#   outline   docx, odt:  heading<TAB>level<TAB>text
#             xlsx, ods:  sheet<TAB>name<TAB>range<TAB>A:header | B:header …
#             pptx, odp:  slide<TAB>number<TAB>title   (`-` when the slide has none)
#   text      docx, odt:  one paragraph per line, headings as markdown `#`
#             xlsx, ods:  `## <sheet> (<range>)`, then row<TAB>A<TAB>B… per row
#             pptx, odp:  `## Slide <n>: <title>`, then the slide's other paragraphs
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
function letters(n,   s) {
  s = ""; while (n > 0) { s = substr("ABCDEFGHIJKLMNOPQRSTUVWXYZ", (n - 1) % 26 + 1, 1) s; n = int((n - 1) / 26) }
  return s
}
# para_clean <s> — a paragraph with its runs of spaces collapsed and its ends trimmed
function para_clean(s) { gsub(/  +/, " ", s); return trim(s) }
# para_emit — the finished paragraph `txt` at heading level `plvl` (0: body) as an outline
# record or a text line; docx and odt share it
function para_emit(   h) {
  txt = para_clean(txt); if (txt == "") return
  if (mode == "outline") { if (plvl) printf "heading\t%d\t%s\n", plvl, txt; return }
  h = ""; while (length(h) < plvl) h = h "#"
  print (plvl ? h " " : "") txt
}
# slide_emit <n> <title> <lines> — one slide, `lines` being its other paragraphs, each ending in
# a newline; pptx and odp share it
function slide_emit(n, title, lines) {
  if (mode == "outline") { printf "slide\t%d\t%s\n", n, (title == "" ? "-" : title); return }
  printf "## Slide %d%s\n%s", n, (title == "" ? "" : ": " title), lines
}
'

# ooxml_part <file> <member> -> the member's bytes, or nothing. Info-ZIP exits 11 and busybox
# 0 for a missing member, so "empty" is the only portable test.
ooxml_part() { unzip -p "$1" "$2" 2>/dev/null || true; }

# extract_kind <file> -> docx | xlsx | pptx | odt | ods | odp | none<TAB>reason
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
    pptx)      main="ppt/presentation.xml" ;;
    odt|ods|odp) main="content.xml" ;;
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
        if (depth == 1) para_emit()
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
    }'
}

# ooxml_order <file> <dir> <main> <element> -> name<TAB>member per part, in the order the main
# part lists them (workbook tab order, slide show order), never by file name. Members come from
# the main part's rels; a part with no `name` attribute (a slide) is named by its position.
ooxml_order() {
  { ooxml_part "$1" "$2/$3"; printf '<@@RELS@@>'; ooxml_part "$1" "$2/_rels/$3.rels"; } |
  EL="$4" DIR="$2" awk "$AWK_XML"'
    BEGIN { RS = "<" }
    /^@@RELS@@>/ { rels = 1; next }
    !rels && lname(tag($0)) == ENVIRON["EL"] { n++; name[n] = attr($0, "name"); rid[n] = attr($0, "r:id") }
    rels && lname(tag($0)) == "Relationship" { tgt[attr($0, "Id")] = attr($0, "Target") }
    END {
      for (i = 1; i <= n; i++) {
        p = tgt[rid[i]]; if (p == "") continue
        if (substr(p, 1, 1) == "/") p = substr(p, 2); else p = ENVIRON["DIR"] "/" p
        printf "%s\t%s\n", (name[i] == "" ? i : name[i]), p
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
      END {
        if (mode == "outline") printf "sheet\t%s\t%s\t%s\n", ENVIRON["SHEET"], ref, (header == "" ? "-" : header)
        else if (head) printf "## %s (%s)\n", ENVIRON["SHEET"], ref
      }'
  done <<EOF
$(ooxml_order "$1" xl workbook.xml sheet)
EOF
  return 0
}

# pptx_extract <file> outline|text
#
# Slides in show order (presentation.xml's sldIdLst), numbered from 1. The title is the text of
# the shape whose placeholder is `title` or `ctrTitle`; every other paragraph is the slide's
# text. Speaker notes are parts of their own and are not read.
pptx_extract() {
  local n member
  while IFS=$'\t' read -r n member; do
    [ -n "$member" ] || continue
    ooxml_part "$1" "$member" | N="$n" awk -v mode="$2" "$AWK_XML"'
      BEGIN { RS = "<" }
      {
        t = lname(tag($0))
        if (t == "sp") ph = ""
        else if (t == "ph") ph = attr($0, "type")
        else if (t == "p" && !selfclosing($0)) txt = ""
        else if (t == "/p") {
          txt = para_clean(txt); if (txt == "") next
          if (ph == "title" || ph == "ctrTitle") title = title (title == "" ? "" : " ") txt
          else lines = lines txt "\n"
        }
        else if (t == "t") txt = txt unxml(body($0))
        else if (t == "br") txt = txt " "
      }
      END { slide_emit(ENVIRON["N"], title, lines) }'
  done <<EOF
$(ooxml_order "$1" ppt presentation.xml sldId)
EOF
  return 0
}

# --- OpenDocument: everything is in content.xml -----------------------------------------------
#
# Text sits in the body of every record between a paragraph's open and close tags, including the
# one after a closing span (`/text:span>more`). `text:s` is `text:c` spaces. Comments
# (office:annotation), footnotes (text:note) and speaker notes (presentation:notes) are skipped,
# but the text after their closing tag is the paragraph's again.
AWK_ODF='
function odf_skip(t) {
  if (t == "annotation" || t == "note" || t == "notes") { if (!selfclosing($0)) skip++; return skip > 0 }
  if (t == "/annotation" || t == "/note" || t == "/notes") { if (skip) skip--; return skip > 0 }
  return skip > 0
}
function odf_run(t, rec,   n) {
  if (t == "s") { n = attr(rec, "text:c") + 0; if (n < 1) n = 1; while (n-- > 0) txt = txt " " }
  else if (t == "tab" || t == "line-break") txt = txt " "
  txt = txt unxml(body(rec))
}
'

# odt_extract <file> outline|text — text:h is a heading (its level from text:outline-level),
# text:p a paragraph. A paragraph inside another (a text box) runs into it, as in docx.
odt_extract() {
  ooxml_part "$1" content.xml | awk -v mode="$2" "$AWK_XML$AWK_ODF"'
    BEGIN { RS = "<" }
    {
      t = lname(tag($0)); if (odf_skip(t)) next
      if (t == "h" || t == "p") {
        if (selfclosing($0)) next
        if (++depth == 1) {
          txt = ""; plvl = 0
          if (t == "h") { plvl = attr($0, "text:outline-level") + 0; if (plvl < 1) plvl = 1 }
        }
        txt = txt unxml(body($0))
      } else if (t == "/h" || t == "/p") {
        if (depth == 1) para_emit()
        if (depth > 0) depth--
        if (depth) txt = txt unxml(body($0))
      } else if (depth) odf_run(t, $0)
    }'
}

# odp_extract <file> outline|text — one draw:page per slide; the title is the text of the frame
# whose presentation:class is `title`.
odp_extract() {
  ooxml_part "$1" content.xml | awk -v mode="$2" "$AWK_XML$AWK_ODF"'
    BEGIN { RS = "<" }
    {
      t = lname(tag($0)); if (odf_skip(t)) next
      if (t == "page") { n++; title = ""; lines = ""; cls = "" }
      else if (t == "/page") slide_emit(n, title, lines)
      else if (t == "frame") cls = attr($0, "presentation:class")
      else if (t == "/frame") cls = ""
      else if (t == "p" || t == "h") { if (!selfclosing($0)) { inp = 1; txt = unxml(body($0)) } }
      else if (t == "/p" || t == "/h") {
        inp = 0; txt = para_clean(txt); if (txt == "") next
        if (cls == "title") title = title (title == "" ? "" : " ") txt
        else lines = lines txt "\n"
      }
      else if (inp) odf_run(t, $0)
    }'
}

# ods_extract <file> outline|text — one table:table per sheet. A cell is its displayed text, so a
# date reads as the file shows it, its paragraphs joined by a space. LibreOffice pads every sheet
# with repeated empty cells and rows (`number-columns-repeated="1021"`), so an empty repeat only
# advances the count, and the range runs from A1 to the last row and column that hold something.
ods_extract() {
  ooxml_part "$1" content.xml | awk -v mode="$2" "$AWK_XML$AWK_ODF"'
    BEGIN { RS = "<" }
    {
      t = lname(tag($0)); if (odf_skip(t)) next
      if (t == "table") { if (!selfclosing($0)) { name = attr($0, "table:name"); r = 0; maxr = 0; maxc = 0; nr = 0; hdr = "" } }
      else if (t == "/table") sheet_end()
      else if (t == "table-row") {
        rrep = attr($0, "table:number-rows-repeated") + 0; if (rrep < 1) rrep = 1
        c = 0; rowmax = 0; split("", cell)
        if (selfclosing($0)) row_end()
      }
      else if (t == "/table-row") row_end()
      else if (t == "table-cell" || t == "covered-table-cell") {
        crep = attr($0, "table:number-columns-repeated") + 0; if (crep < 1) crep = 1
        val = ""; if (selfclosing($0)) cell_end()
      }
      else if (t == "/table-cell" || t == "/covered-table-cell") cell_end()
      else if (t == "p" && !selfclosing($0)) { inp = 1; txt = unxml(body($0)) }
      else if (t == "/p") { inp = 0; txt = para_clean(txt); if (txt != "") val = val (val == "" ? "" : " ") txt }
      else if (inp) odf_run(t, $0)
    }
    function cell_end(   k) {
      if (val == "") { c += crep; return }
      for (k = 0; k < crep; k++) { c++; cell[c] = val }
      rowmax = c
    }
    function row_end(   k, i, line) {
      if (!rowmax) { r += rrep; return }
      for (k = 0; k < rrep; k++) {
        r++; line = r
        for (i = 1; i <= rowmax; i++) line = line "\t" cell[i]
        rows[++nr] = line
        if (hdr == "") for (i = 1; i <= rowmax; i++) if (cell[i] != "") hdr = hdr (hdr == "" ? "" : " | ") letters(i) ":" cell[i]
      }
      maxr = r; if (rowmax > maxc) maxc = rowmax
    }
    function sheet_end(   i) {
      if (mode == "outline") printf "sheet\t%s\t%s\t%s\n", name, (maxr ? "A1:" letters(maxc) maxr : "-"), (hdr == "" ? "-" : hdr)
      else {
        printf "## %s (%s)\n", name, (maxr ? "A1:" letters(maxc) maxr : "-")
        for (i = 1; i <= nr; i++) print rows[i]
      }
      split("", rows)
    }'
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
    pptx) pptx_extract "$f" "$mode" ;;
    odt)  odt_extract "$f" "$mode" ;;
    odp)  odp_extract "$f" "$mode" ;;
    ods)  ods_extract "$f" "$mode" ;;
    *)   printf '%s\n' "$kind" ;;
  esac
}
