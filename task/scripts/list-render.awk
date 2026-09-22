# Renderer for list-tasks.sh. Reads one tab-separated stream:
#
#   #C  key    value                 configuration
#   #F  field  op     values         filter (op is = or ~)
#   #E  epic-name    task-id         epic index entry
#   #V  epic-name    task-id         render this epic as a group
#   <task-id>  <key>  <value>        task frontmatter record
#
# and prints the finished listing. Output shapes are the ones /task list
# documents: flat table, grouped table, epic group with its closed sub-tasks
# collapsed to a count, and summary.

function max(a, b)      { return a > b ? a : b }
function status_of(id,   s) { s = V[id, "status"]; return s == "" ? "proposed" : s }
function is_epic(id)    { return (V[id, "type"] == "epic" || V[id, "title"] ~ /^EPIC:/) }
function is_closed(id,   s) { s = status_of(id); return (s == "completed" || s == "rejected") }

# The Epic column never shows the epic-name code: an epic shows [Epic], a
# member shows its epic's task id, and an unresolvable name falls back to itself.
function epic_col(id,   e) {
    if (is_epic(id)) return "[Epic]"
    e = V[id, "epic"]
    if (e == "") return ""
    return (e in EIDX) ? EIDX[e] : e
}
function prank(p) {
    if (p == "critical") return 1
    if (p == "high")     return 2
    if (p == "medium")   return 3
    if (p == "low")      return 4
    return 5
}
function srank(s) {
    if (s == "in-progress") return 1
    if (s == "blocked")     return 2
    if (s == "approved")    return 3
    if (s == "proposed")    return 4
    if (s == "completed")   return 6
    if (s == "rejected")    return 7
    return 5
}
function passes(id,   i, f, op, n, a, j, val, ok) {
    for (i = 1; i <= nf; i++) {
        f = FF[i]; op = FO[i]; val = V[id, f]
        n = split(FV[i], a, ","); ok = 0
        for (j = 1; j <= n; j++) {
            if (a[j] == "_")       { if (val == "") ok = 1 }
            else if (op == "=")    { if (val == a[j]) ok = 1 }
            else                   { if (val != "" && index(tolower(val), tolower(a[j])) > 0) ok = 1 }
        }
        if (!ok) return 0
    }
    return 1
}
# Default order is priority then id; sort=<field> replaces the primary key.
function sortkey(id,   v) {
    if (C["sort"] != "") {
        v = V[id, C["sort"]]
        if (v == "") v = "~~~"
        return v "|" id
    }
    return prank(V[id, "priority"]) "|" id
}
# Insertion sort — POSIX awk has no asort, and busybox awk has no sorting at all.
function ssort(arr, keys, n,   i, j, t, tk) {
    for (i = 2; i <= n; i++) {
        t = arr[i]; tk = keys[i]; j = i - 1
        while (j >= 1 && keys[j] > tk) { arr[j+1] = arr[j]; keys[j+1] = keys[j]; j-- }
        arr[j+1] = t; keys[j+1] = tk
    }
}
function out_text(s) { no++; OT[no] = "text"; OA[no] = s }
function out_row(id) { no++; OT[no] = "row";  OA[no] = id }
function pad(s, w,   r) { r = s; while (length(r) < w) r = r " "; return r }

function group_label(v, field) { return v == "" ? "(no " field ")" : v }
function group_hint(v, field) { return "/task list " field "=" (v == "" ? "_" : v) }

BEGIN { FS = "\t" }
$1 == "#C" { C[$2] = $3; next }
$1 == "#F" { nf++; FF[nf] = $2; FO[nf] = $3; FV[nf] = $4; next }
$1 == "#E" { EIDX[$2] = $3; next }
$1 == "#V" { nv++; VN[nv] = $2; VI[nv] = $3; next }
{
    if (!($1 in seen)) { seen[$1] = 1; ids[++nids] = $1 }
    V[$1, $2] = $3
}

END {
    expand = (C["all"] == "1" || C["statusfilter"] == "1")
    if (C["active"] != "") { n = split(C["active"], aa, ","); for (i = 1; i <= n; i++) ACT[aa[i]] = 1 }

    if (C["mode"] == "summary")      render_summary()
    else if (nv > 0)                 render_epics()
    else                             render_classic()

    print_out()
}

# --- epic views -----------------------------------------------------------
function render_epics(   v, i, id, nopen, nclosed, ncomp, nrej, k, note, total) {
    for (v = 1; v <= nv; v++) {
        nopen = 0; nclosed = 0; ncomp = 0; nrej = 0
        for (i = 1; i <= nids; i++) {
            id = ids[i]
            if (id != VI[v] && V[id, "epic"] != VN[v]) continue
            if (!passes(id)) continue
            if (is_closed(id) && !expand) {
                nclosed++
                if (status_of(id) == "completed") ncomp++; else nrej++
                CL[nclosed] = id
                continue
            }
            nopen++
            OPEN[nopen] = id
            # The epic's own line sits above its sub-tasks; the rest go
            # in-progress -> blocked -> approved -> proposed, then priority.
            OPENK[nopen] = (id == VI[v] ? "0" : "1") srank(status_of(id)) sortkey(id)
        }
        ssort(OPEN, OPENK, nopen)
        total = nopen + nclosed
        if (v > 1) out_text("")
        out_text("── epic: " VN[v] " — " nopen " open / " total " total ──")
        for (i = 1; i <= nopen; i++) out_row(OPEN[i])
        if (nclosed > 0) {
            note = "✓ " nclosed " closed ("
            if (ncomp > 0 && nrej > 0)  note = note ncomp " completed, " nrej " rejected)"
            else if (nrej > 0)          note = note nrej " rejected)"
            else                        note = note ncomp " completed)"
            out_text("")
            out_text("  " note " — /task list " VI[v] " status=completed,rejected")
        }
    }
    if (C["noepic"] == "1") render_noepic()
    indent = 1
}

function render_noepic(   i, id, n, hidden) {
    n = 0
    for (i = 1; i <= nids; i++) {
        id = ids[i]
        if (V[id, "epic"] != "" || is_epic(id)) continue
        if (!passes(id)) continue
        if (is_closed(id) && !expand) continue
        n++; G[n] = id; GK[n] = sortkey(id)
    }
    if (n == 0) return
    ssort(G, GK, n)
    out_text("")
    out_text("── no epic (" n ") ──")
    hidden = 0
    for (i = 1; i <= n; i++) {
        if (i > 5) { hidden++; continue }
        out_row(G[i])
    }
    if (hidden > 0) { out_text(""); out_text("... and " hidden " more (use /task list epic=_)") }
}

# --- classic list ---------------------------------------------------------
function render_classic(   i, id, n, gf, gn, gname, j, hidden, cnt) {
    n = 0
    for (i = 1; i <= nids; i++) {
        id = ids[i]
        if (!passes(id)) continue
        if (is_closed(id) && !expand) continue
        n++; SEL[n] = id
    }
    if (n == 0) { out_text("No matching tasks."); return }

    gf = C["group"]
    if (gf == "" && n > 15) gf = "status"

    if (gf == "") {
        # Flat: by id, which is the classic shape, unless sort= asks otherwise.
        for (i = 1; i <= n; i++) SELK[i] = (C["sort"] == "" ? SEL[i] : sortkey(SEL[i]))
        ssort(SEL, SELK, n)
        showheader = 1
        for (i = 1; i <= n; i++) out_row(SEL[i])
        return
    }

    indent = 1
    if (gf == "status") hidestatus = 1
    gn = collect_groups(SEL, n, gf)
    for (j = 1; j <= gn; j++) {
        gname = GN[j]
        cnt = GC[gname]
        if (j > 1) out_text("")
        out_text("── " group_label(gname, gf) " (" cnt ") ──")
        hidden = 0
        for (i = 1; i <= cnt; i++) {
            if (i > 5) { hidden++; continue }
            out_row(GM[gname, i])
        }
        if (hidden > 0) {
            out_text("")
            out_text("... and " hidden " more (use " group_hint(gname, gf) ")")
        }
    }
}

# --- summary --------------------------------------------------------------
function render_summary(   i, id, n, gf, gn, j, gname, cnt, line, shown, total) {
    n = 0
    for (i = 1; i <= nids; i++) {
        id = ids[i]
        if (!passes(id)) continue
        if (is_closed(id) && !expand) continue
        n++; SEL[n] = id
    }
    gf = C["group"]; if (gf == "") gf = "status"
    gn = collect_groups(SEL, n, gf)
    total = 0
    for (j = 1; j <= gn; j++) {
        gname = GN[j]; cnt = GC[gname]; total += cnt
        line = "── " group_label(gname, gf) " (" cnt ") ── "
        shown = cnt > 5 ? 5 : cnt
        for (i = 1; i <= shown; i++) line = line GM[gname, i] (i < shown ? ", " : "")
        if (cnt > shown) line = line " +" (cnt - shown)
        out_text(line)
    }
    out_text("─────────────────")
    out_text((expand ? "Total: " : "Total open: ") total)
}

# Buckets SEL[1..n] by field gf, sorted inside each bucket and between them.
function collect_groups(SEL, n, gf,   i, id, gname, gn, j, k) {
    gn = 0
    for (i = 1; i <= n; i++) {
        id = SEL[i]
        gname = V[id, gf]
        if (!(gname in GC)) { GC[gname] = 0; GN[++gn] = gname }
        GM[gname, ++GC[gname]] = id
    }
    for (j = 1; j <= gn; j++) {
        gname = GN[j]
        for (k = 1; k <= GC[gname]; k++) { TMP[k] = GM[gname, k]; TMPK[k] = sortkey(GM[gname, k]) }
        ssort(TMP, TMPK, GC[gname])
        for (k = 1; k <= GC[gname]; k++) GM[gname, k] = TMP[k]
        # Status groups have a meaningful order; anything else sorts by name,
        # with the unset bucket last.
        GNK[j] = (gf == "status") ? srank(GN[j]) : (GN[j] == "" ? "~~~" : GN[j])
    }
    ssort(GN, GNK, gn)
    return gn
}

# --- printing -------------------------------------------------------------
function print_out(   i, id, wid, wst, wpr, wep, anyp, anye, line, ind, mk, wmk) {
    wid = 2; wst = 6; wpr = 8; wep = 4; anyp = 0; anye = 0; wmk = 0
    for (i = 1; i <= no; i++) {
        if (OT[i] != "row") continue
        id = OA[i]
        wid = max(wid, length(id))
        wst = max(wst, length(status_of(id)))
        if (V[id, "priority"] != "") { anyp = 1; wpr = max(wpr, length(V[id, "priority"])) }
        if (epic_col(id) != "")      { anye = 1; wep = max(wep, length(epic_col(id))) }
    }
    if (C["active"] != "") wmk = 2
    ind = indent ? "  " : ""

    if (showheader) {
        line = ind
        if (wmk) line = line pad("", wmk)
        line = line pad("ID", wid + 2)
        if (!hidestatus) line = line pad("Status", wst + 2)
        if (anyp) line = line pad("Priority", wpr + 2)
        if (anye) line = line pad("Epic", wep + 2)
        line = line "Title"
        print line
    }
    for (i = 1; i <= no; i++) {
        if (OT[i] == "text") { line = OA[i]; sub(/[ \t]+$/, "", line); print line; continue }
        id = OA[i]
        mk = (id in ACT) ? "* " : "  "
        line = ind
        if (wmk) line = line mk
        line = line pad(id, wid + 2)
        if (!hidestatus) line = line pad(status_of(id), wst + 2)
        if (anyp) line = line pad(V[id, "priority"], wpr + 2)
        if (anye) line = line pad(epic_col(id), wep + 2)
        line = line V[id, "title"]
        sub(/[ \t]+$/, "", line)
        print line
    }
}
