# infer.awk — turn inspect.sh's hints into proposed answers. Run through kickoff_awk with -v raw=<file>.
#
# A hint is `ID TAB text TAB evidence`. The text picks the question's first option that starts with
# it (ignoring case), so the answer is the questionnaire's exact wording; a hint that matches no
# option (a name, a URL, a port) is proposed as written. Questions already answered are left out:
# the answers file always wins over what the project looks like.

{ load() }

END {
    while ((getline l < raw) > 0) {
        n = split(l, f, "\t"); id = f[1]; hint = f[2]; ev = f[3]
        if (!(id in qidx) || ans[id] != "" || (id in seen)) continue   # the first hint for an id wins
        seen[id] = 1
        v = hint; k = split(qopts[qidx[id]], o, / · /)
        for (j = 1; j <= k; j++) { t = option_text(o[j]); if (starts_ci(t, hint)) { v = t; break } }
        printf "%s\t%s\t%s\n", id, v, ev
    }
}
