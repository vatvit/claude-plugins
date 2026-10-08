# lib.awk — kickoff's questionnaire model. Loaded with `awk -f lib.awk -f <program>.awk`.
#
# The questionnaire (skills/kickoff/references/questionnaire.md) is the single source of the
# questions; nothing else in the plugin restates them. Its table conventions are documented
# there, in §Reading the tables — this file is their one implementation.
#
# Inputs, in this order on the command line:
#   1. the answers file   (`ID: value` lines; may be /dev/null)
#   2. the defaults file   (`ID<TAB>value` lines from the user layer; may be /dev/null)
#   3. the questionnaire
# Programs call load() on every record and get the arrays below filled by END.
#
#   nq            number of questions; qid[i], qsec[i], qsectitle[i], qtext[i], qopts[i], qwhen[i], qgoes[i]
#   ans[id]       first answer for id ("" when unanswered); ansn[id] the count; ansv[id, k] k-th value
#   why[id]       the recorded reason, if any
#   udef[id]      the user layer's default for id, if any

function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

# Case-insensitive "s starts with p".
function starts_ci(s, p) { return tolower(substr(s, 1, length(p))) == tolower(p) }

function load(   id, v, n, c, i) {
    if (FILENAME == ARGV[1]) {                       # the answers file
        if ($0 ~ /^[A-Z][0-9]+\.why: /) {
            id = substr($0, 1, index($0, ".") - 1); why[id] = substr($0, index($0, ": ") + 2); return
        }
        if ($0 ~ /^[A-Z][0-9]+: /) {
            id = substr($0, 1, index($0, ":") - 1); v = substr($0, index($0, ": ") + 2)
            n = ++ansn[id]; ansv[id, n] = v; if (n == 1) ans[id] = v
        }
        return
    }
    if (FILENAME == ARGV[2]) {                       # the user layer's defaults
        if (index($0, "\t") > 1) { id = substr($0, 1, index($0, "\t") - 1); udef[id] = substr($0, index($0, "\t") + 1) }
        return
    }
    # the questionnaire
    if ($0 ~ /^## [A-Z]\. /) { cursec = substr($0, 4, 1); cursectitle = substr($0, 7); return }
    if ($0 ~ /^## /) { cursec = ""; return }         # a non-question section ends the tables
    if (cursec != "" && $0 ~ /^\| [A-Z][0-9]+ \|/) {
        n = split($0, c, "|")
        nq++
        qid[nq] = trim(c[2]); qtext[nq] = trim(c[3]); qopts[nq] = trim(c[4])
        qwhen[nq] = trim(c[5]); qgoes[nq] = trim(c[6])
        qsec[nq] = cursec; qsectitle[nq] = cursectitle
        qidx[qid[nq]] = nq
    }
}

# cond(c) — "1", "0", "judge" (wording outside the grammar: Claude decides), or "pending"
# (it depends on a question that is still to be asked, so it is decided after that one).
function cond(c,   parts, n, i, p, r, id, val, judge, pend, st) {
    n = split(c, parts, / or /); judge = 0; pend = 0
    for (i = 1; i <= n; i++) {
        p = trim(parts[i]); r = ""
        if (p ~ /^[A-Z][0-9]+ /) {
            id = substr(p, 1, index(p, " ") - 1)
            if (ans[id] == "" && (id in qidx)) {
                st = state_of(qidx[id]); if (st == "ask" || st == "judge" || st == "pending") { pend = 1; continue }
            }
        }
        if (p == "always") r = 1
        else if (p ~ /^[A-Z][0-9]+ answered$/) { id = substr(p, 1, index(p, " ") - 1); r = (ans[id] != "") }
        else if (match(p, /^[A-Z][0-9]+ = /)) { id = substr(p, 1, index(p, " ") - 1); val = substr(p, RLENGTH + 1); r = starts_ci(ans[id], val) }
        else if (match(p, /^[A-Z][0-9]+ ≠ /)) { id = substr(p, 1, index(p, " ") - 1); val = substr(p, RLENGTH + 1); r = !starts_ci(ans[id], val) }
        else judge = 1
        if (r == 1) return "1"
    }
    return pend ? "pending" : (judge ? "judge" : "0")
}

# option_text(o) — an option without its ★ markers.
function option_text(o) {
    o = trim(o); sub(/^★ /, "", o); sub(/ *\(★ if [^)]*\)$/, "", o); return o
}

# clean_options(opts) — every option without markers, joined by " · ".
function clean_options(opts,   o, n, i, out) {
    n = split(opts, o, / · /); out = ""
    for (i = 1; i <= n; i++) out = out (i > 1 ? " · " : "") option_text(o[i])
    return out
}

# default_of(i) — the default for question i. The user layer wins, then a conditional
# (★ if …) whose condition holds, then the plain ★. "" when the question has none.
function default_of(i,   o, n, k, t, base, cd, c) {
    if (qid[i] in udef) return udef[qid[i]]
    n = split(qopts[i], o, / · /); base = ""; cd = ""
    for (k = 1; k <= n; k++) {
        t = trim(o[k])
        if (t ~ /^★ /) base = option_text(t)
        if (match(t, /\(★ if [^)]*\)$/)) {
            # strip by pattern, not by offset: ★ is one char in gawk but three bytes in mawk/BSD awk
            c = substr(t, RSTART, RLENGTH); sub(/^\(★ if /, "", c); sub(/\)$/, "", c)
            if (cd == "" && cond(c) == "1") cd = option_text(t)
        }
    }
    return cd != "" ? cd : base
}

# state_of(i) — answered | stale (answered, but its condition no longer holds) | ask | judge |
# pending (waits for an earlier answer) | skip.
function state_of(i,   c) {
    c = cond(qwhen[i])
    if (ans[qid[i]] != "") return c == "0" ? "stale" : "answered"
    if (c == "1") return "ask"
    if (c == "pending") return "pending"
    return c == "judge" ? "judge" : "skip"
}

# undecided(v) — "Not decided yet" and its variants.
function undecided(v) { return starts_ci(v, "not decided") }

# not_applicable(v) — "n/a": Claude judged a question irrelevant here (a judgement condition, or
# the user said so). It counts as answered, so the plan moves on, but nothing is generated from it.
function not_applicable(v) { return tolower(v) == "n/a" }
