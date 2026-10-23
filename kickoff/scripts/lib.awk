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
# and -v plugins="<installed plugin names>" (lib.sh installed_plugins), for `<plugin> installed`.
# Programs call load() on every record and get the arrays below filled by END.
#
#   nq            number of questions; qid[i], qsec[i], qsectitle[i], qtext[i], qopts[i], qwhen[i], qgoes[i]
#   ans[id]       first answer for id ("" when unanswered); ansn[id] the count; ansv[id, k] k-th value
#   why[id]       the recorded reason, if any
#   from[id]      the evidence the answer was recovered from (existing project), if any
#   udef[id]      the user layer's default for id, if any

function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

# Case-insensitive "s starts with p". Lowercase the whole strings, then compare with index():
# macOS awk cuts substr() by bytes but tolower() rejects a broken UTF-8 sequence, so
# tolower(substr(s, 1, n)) aborts ("illegal byte sequence") when the cut lands inside — or ★.
function starts_ci(s, p) { return index(tolower(s), tolower(p)) == 1 }

function load(   id, v, n, c, i) {
    if (FILENAME == ARGV[1]) {                       # the answers file
        if ($0 ~ /^[A-Z][0-9]+\.why: /) {
            id = substr($0, 1, index($0, ".") - 1); why[id] = substr($0, index($0, ": ") + 2); return
        }
        if ($0 ~ /^[A-Z][0-9]+\.from: /) {
            id = substr($0, 1, index($0, ".") - 1); from[id] = substr($0, index($0, ": ") + 2); return
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

# atom(p) — one condition without and/or: "1", "0", "judge" or "pending" (see cond).
# `plugins` (awk -v, from kickoff_awk) is the space-separated list of installed plugins.
function atom(p,   id, val, st, k) {
    p = trim(p)
    if (p == "always" || p == "explicitly") return "1"
    if (match(p, /^[a-z][a-z0-9-]* installed$/)) { id = substr(p, 1, index(p, " ") - 1); return index(" " plugins " ", " " id " ") ? "1" : "0" }
    if (p !~ /^[A-Z][0-9]+ /) return "judge"
    id = substr(p, 1, index(p, " ") - 1)
    if (ans[id] == "" && (id in qidx)) { st = state_of(qidx[id]); if (to_ask(st) || st == "pending") return "pending" }
    if (p ~ /^[A-Z][0-9]+ answered$/) return (ans[id] != "") ? "1" : "0"
    if (match(p, /^[A-Z][0-9]+ = /)) { val = substr(p, RLENGTH + 1); return starts_ci(ans[id], val) ? "1" : "0" }
    if (match(p, /^[A-Z][0-9]+ ≠ /)) { val = substr(p, RLENGTH + 1); return starts_ci(ans[id], val) ? "0" : "1" }
    if (match(p, /^[A-Z][0-9]+ has /)) {
        val = substr(p, RLENGTH + 1)
        for (k = 1; k <= ansn[id]; k++) if (starts_ci(ansv[id, k], val)) return "1"
        return "0"
    }
    return "judge"
}

# cond(c) — "1", "0", "judge" (wording outside the grammar: Claude decides), or "pending"
# (it depends on a question that is still to be asked, so it is decided after that one).
# ` or ` joins groups, ` and ` joins atoms inside a group; a false atom makes its group false
# even when another atom of it is still pending.
function cond(c,   groups, ng, g, atoms, na, k, r, gr, judge, pend) {
    ng = split(c, groups, / or /); judge = 0; pend = 0
    for (g = 1; g <= ng; g++) {
        na = split(groups[g], atoms, / and /); gr = "1"
        for (k = 1; k <= na; k++) {
            r = atom(atoms[k])
            if (r == "0") { gr = "0"; break }
            if (r == "pending") gr = "pending"
            else if (r == "judge" && gr == "1") gr = "judge"
        }
        if (gr == "1") return "1"
        if (gr == "pending") pend = 1
        if (gr == "judge") judge = 1
    }
    return pend ? "pending" : (judge ? "judge" : "0")
}

# default_waits(i) — a (★ if …) default of question i depends on a question still to be asked, so
# the default cannot be offered yet. The user layer's default does not wait: it is fixed.
function default_waits(i,   o, n, k, t, c) {
    if (qid[i] in udef) return 0
    n = split(qopts[i], o, / · /)
    for (k = 1; k <= n; k++) {
        t = trim(o[k])
        if (match(t, /\(★ if [^)]*\)$/)) {
            c = substr(t, RSTART, RLENGTH); sub(/^\(★ if /, "", c); sub(/\)$/, "", c)
            if (cond(c) == "pending") return 1
        }
    }
    return 0
}

# option_text(o) — an option without its ★ markers.
function option_text(o) {
    o = trim(o); sub(/^★ /, "", o); sub(/ *\(★ if [^)]*\)$/, "", o)
    if (o ~ /^".*"$/) o = substr(o, 2, length(o) - 2)   # a quoted option is a sentence to use as is
    return o
}

# clean_options(opts) — every option without markers, joined by " · ".
function clean_options(opts,   o, n, i, out) {
    n = split(opts, o, / · /); out = ""
    for (i = 1; i <= n; i++) out = out (i > 1 ? " · " : "") option_text(o[i])
    return out
}

# computed_of(i, v) — the computed or proposed option (*italics*, possibly followed by an example)
# of question i that v is, with or without its asterisks; "" when v is not one. Such an option says
# how to work a value out, never the value.
function computed_of(i, v,   o, n, k, t) {
    n = split(qopts[i], o, / · /)
    for (k = 1; k <= n; k++) {
        t = option_text(o[k])
        if (!match(t, /^\*[^*]+\*/)) continue
        t = substr(t, 1, RLENGTH)
        if (tolower(v) == tolower(t) || tolower("*" v "*") == tolower(t)) return t
    }
    return ""
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

# to_ask(s) — the state is still to be asked: by the user (ask, explicit) or by Claude (judge).
function to_ask(s) { return s == "ask" || s == "explicit" || s == "judge" }

# state_of(i) — answered | stale (answered, but its condition no longer holds) | ask | explicit (ask, and
# never settle it from a default: the user picks) | judge | pending (waits for an earlier answer) | skip.
function state_of(i,   c) {
    c = cond(qwhen[i])
    if (ans[qid[i]] != "") return c == "0" ? "stale" : "answered"
    if (c == "1" && default_waits(i)) return "pending"     # A6 waits for A4: its default needs it
    if (c == "1") return qwhen[i] == "explicitly" ? "explicit" : "ask"
    if (c == "pending") return "pending"
    return c == "judge" ? "judge" : "skip"
}

# undecided(v) — "Not decided yet" and its variants.
function undecided(v) { return starts_ci(v, "not decided") }

# not_applicable(v) — "n/a": Claude judged a question irrelevant here (a judgement condition, or
# the user said so). It counts as answered, so the plan moves on, but nothing is generated from it.
function not_applicable(v) { return tolower(v) == "n/a" }

# settled(id) — the answer when it is given, applies, and is neither undecided nor n/a; else "".
# What every generator writes from: a pending, stale or undecided answer produces nothing.
function settled(id,   i) {
    i = qidx[id]; if (!i) return ""
    if (state_of(i) != "answered" || undecided(ans[id]) || not_applicable(ans[id])) return ""
    return ans[id]
}

# later_trigger(v) — the trigger of a "Later — from <trigger>" answer (C5), "" for any other answer.
# Matched by pattern: the dash is several bytes in byte-oriented awks, so no offsets are counted past it.
function later_trigger(v) { if (!match(tolower(v), /^later[^a-z]*from /)) return ""; return substr(v, RLENGTH + 1) }

# joined(id, sep) — every value of id's answer, joined by sep (a multi-select answer has several).
function joined(id, sep,   v, k) {
    v = ansv[id, 1]; for (k = 2; k <= ansn[id]; k++) v = v sep ansv[id, k]; return v
}
