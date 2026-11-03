# crew time (PLUG-097), two stages; time.sh runs them as  events | sort | report.
#
# stage=events — input: lines "name<TAB>transcript path". Reads each transcript (Claude Code JSONL) and prints
#   one event per counted entry:  name  epoch  category  detail
# A gap between two entries is later charged to what ended it, so each event carries what the session was
# waiting for until then. Only the category and a tool name or message kind leave this stage: never any
# transcript text.
#
# stage=report — input: sorted events. -v since, idle (seconds), slotlog (path), names (space separated,
#   display order). Prints one table: a row per category, a column per member and the crew total.
#
# JSON without a parser: escapes are dropped first (\\ and \" can then never close a string), the line is split
# on quotes, odd parts are structure and even parts are strings; a string followed by ":" is a key, and the
# braces counted in the structure parts give its depth. Top-level keys sit at depth 1.

function ts_epoch(t,   y, mo, d, h, mi, s, a, m, yy) {   # 2026-11-03T13:38:08.941Z -> epoch (UTC), no date calls
    if (t !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9]/) return -1
    y = substr(t, 1, 4) + 0; mo = substr(t, 6, 2) + 0; d = substr(t, 9, 2) + 0
    h = substr(t, 12, 2) + 0; mi = substr(t, 15, 2) + 0; s = substr(t, 18) + 0
    a = int((14 - mo) / 12); yy = y + 4800 - a; m = mo + 12 * a - 3
    return (d + int((153 * m + 2) / 5) + 365 * yy + int(yy / 4) - int(yy / 100) + int(yy / 400) - 32045 - 2440588) * 86400 \
           + h * 3600 + mi * 60 + s
}

function tool_cat(id,   n, c) {
    n = TN[id]; c = TC[id]
    if (n == "Bash") {
        if (c ~ /(crew|crew\.sh)[^|;&]* slot run([^a-z]|$)/) return "queue"          # split into queue/run by the slot log
        if (c ~ /(crew|crew\.sh)[^|;&]* (land|hold|apply|release)([^a-z]|$)/) return "tree"
        return "process"
    }
    if (n == "Agent" || n == "Task") return "process"
    return "tools"
}

function msg_cat(s,   k, w) {    # a peer message: the KIND in its header "[crew] from → to: KIND …"
    if (!match(s, /\] [^ ]+ (→|\\u2192) [^:]+: [A-Z][A-Z0-9 _-]*/)) return "peer"
    k = substr(s, RSTART, RLENGTH); sub(/^.*: /, "", k)
    if (k ~ /^[A-Z]+-[0-9]+/) return "decision"
    w = k; sub(/ .*$/, "", w)
    if (w ~ /^(GATE|QUEUE|HOLD|HOT|RELEASE|RELEASED|COLLISION|LANDED|HEAD|SEAM)$/) return "tree"
    if (w ~ /^(DECISION|AGREED|GO|OK|YES|ANSWER|ACK|ASSIGN|USER)$/) return "decision"
    return "peer"
}

function entry(name, line,   s, P, n, i, depth, t, nx, key, val, top, typ, ts, side, meta, compact, okind, tr, cur, cat, det, bg, e) {
    s = line; gsub(/\\\\/, "", s); gsub(/\\"/, "'", s)
    n = split(s, P, "\"")
    for (i = 1; i <= n; i++) {
        if (i % 2) { t = P[i]; depth += gsub(/[{[]/, "", t); t = P[i]; depth -= gsub(/[]}]/, "", t); continue }
        nx = (i < n ? P[i + 1] : "")
        if (substr(nx, 1, 1) != ":") continue
        key = P[i]
        if (nx == ":") val = P[i + 2]; else { val = substr(nx, 2); sub(/[],}].*$/, "", val) }
        if (depth == 1) {
            top = key
            if (key == "type") typ = val; else if (key == "timestamp") ts = val
            else if (key == "isSidechain") side = val; else if (key == "isMeta") meta = val
            else if (key == "isCompactSummary") compact = val
        } else if (top == "origin" && depth == 2 && key == "kind") okind = val
        else if (top == "message") {
            if (key == "id" && val ~ /^toolu_/) cur = val
            else if (key == "name" && cur != "" && !(cur in TN)) TN[cur] = val
            else if (key == "command" && cur != "" && !(cur in TC)) TC[cur] = val
            else if (key == "tool_use_id") tr = val
        }
    }
    if (side == "true" || (typ != "user" && typ != "assistant")) return
    e = ts_epoch(ts); if (e < 0) return
    if (typ == "assistant") { cat = "working"; det = "-" }
    else if (compact == "true") { cat = "compaction"; det = "-" }
    else if (tr != "") {
        cat = tool_cat(tr); det = TN[tr]
        if (match(s, /with ID: [A-Za-z0-9_-]+/)) { bg = substr(s, RSTART + 9, RLENGTH - 9); BG[bg] = cat; cat = "tools" }
    }
    else if (okind == "task-notification") {
        det = "background"; cat = "process"
        if (match(s, /<task-id>[A-Za-z0-9_-]+<\/task-id>/)) { bg = substr(s, RSTART + 9, RLENGTH - 19); if (bg in BG) cat = BG[bg] }
    }
    else if (okind == "peer") { cat = msg_cat(s); det = "message" }
    else if (meta == "true") return
    else { cat = "user"; det = "-" }
    printf "%s\t%.3f\t%s\t%s\n", name, e, cat, det
}

stage == "events" {
    name = $1; path = $0; sub(/^[^\t]*\t/, "", path)
    split("", TN); split("", TC); split("", BG)
    while ((getline line < path) > 0) entry(name, line)
    close(path); next
}

# ---- report ----------------------------------------------------------------------------------------------
function hm(sec,   m) { m = int(sec / 60 + 0.5); return sprintf("%d:%02d", int(m / 60), m % 60) }
function add(name, cat, sec) { if (sec > 0) { A[name, cat] += sec; A["(crew)", cat] += sec } }
function slot_split(name, a, b,   j, st, id, q) {    # a gap [a,b] that ended in a `slot run`: queue, then run
    for (j = 1; j <= NS[name]; j++) {
        st = SS[name, j]; id = SI[name, j]
        if (st > a && st <= b) { add(name, "queue", st - a); add(name, "process", b - st); return }
        if (st <= a && (!(id in EN) || EN[id] > a)) { add(name, "process", b - a); return }
    }
    add(name, "slot?", b - a)
}
stage == "report" && FNR == 1 && !loaded {
    loaded = 1
    while (slotlog != "" && (getline l < slotlog) > 0) {
        split(l, F, "\t")                         # time event id name class min …
        if (F[2] == "start") { k = ++NS[F[4]]; SS[F[4], k] = F[1] + 0; SI[F[4], k] = F[3] }
        else if (F[2] != "request") EN[F[3]] = F[1] + 0
    }
}
stage == "report" {
    name = $1; t = $2 + 0; cat = $3
    if (!(name in prev)) { prev[name] = t; next }
    a = prev[name]; prev[name] = t
    if (t <= since) next
    if (a < since) a = since
    if (t - a > idle) { add(name, "cut", t - a); next }
    if (cat == "queue") slot_split(name, a, t); else add(name, cat, t - a)
}
END {
    if (stage != "report") exit
    nc = split("working tools process queue slot? tree decision peer user compaction", C, " ")
    L["working"] = "Claude working"; L["tools"] = "a tool (not Bash)"; L["process"] = "a process running"
    L["queue"] = "the slot queue"; L["slot?"] = "slot: queue or run, unknown"; L["tree"] = "the shared tree"
    L["decision"] = "a decision from a peer"; L["peer"] = "a peer's work"; L["user"] = "the user"
    L["compaction"] = "compaction"
    nm = split(names " (crew)", M, " ")
    for (j = 1; j <= nm; j++) for (i = 1; i <= nc; i++) T[M[j]] += A[M[j], C[i]]
    if (T["(crew)"] == 0 && A["(crew)", "cut"] == 0) { print "nothing to count in this window"; exit }
    printf "%-30s", ""; for (j = 1; j <= nm; j++) printf "  %13s", M[j]; printf "\n"
    for (i = 1; i <= nc; i++) {
        any = 0; for (j = 1; j <= nm; j++) if (A[M[j], C[i]] > 0) any = 1
        if (!any) continue
        printf "%-30s", L[C[i]]
        for (j = 1; j <= nm; j++) printf "  %13s", (A[M[j], C[i]] > 0 ? sprintf("%s %3d%%", hm(A[M[j], C[i]]), int(100 * A[M[j], C[i]] / T[M[j]] + 0.5)) : "-")
        printf "\n"
    }
    printf "%-30s", "counted"; for (j = 1; j <= nm; j++) printf "  %13s", hm(T[M[j]]); printf "\n"
    any = 0; for (j = 1; j <= nm; j++) if (A[M[j], "cut"] > 0) any = 1
    if (any) { printf "%-30s", "idle, not counted"; for (j = 1; j <= nm; j++) printf "  %13s", (A[M[j], "cut"] > 0 ? hm(A[M[j], "cut"]) : "-"); printf "\n" }
}
