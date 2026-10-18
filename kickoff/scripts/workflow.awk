# workflow.awk — the seeded task workflow with the practices the user dropped (R10) taken out.
# Run through kickoff_awk with -v template=<templates/workflow-*.md>.
#
# A practice is an R10 option, "<Tag> — <what it means>". In a template it is one sentence of a step,
# "<Tag>: …." ending in a full stop, so a dropped one comes out cleanly and the step still reads.
# R10 unanswered or n/a keeps every practice; its answer is the set kept, `None` when all were dropped.

{ load() }

END {
    i = qidx["R10"]; keep = settled("R10"); nd = 0
    if (i && keep != "") {
        n = split(qopts[i], o, / · /)
        for (k = 1; k <= n; k++) {
            tag = option_text(o[k]); sub(/ — .*/, "", tag)
            kept = 0
            for (j = 1; j <= ansn["R10"]; j++) if (starts_ci(ansv["R10", j], tag)) kept = 1
            if (!kept) { nd++; dropped[nd] = tag }
        }
    }
    while ((getline l < template) > 0) {
        for (k = 1; k <= nd; k++) gsub(" " dropped[k] ": [^.]*[.]", "", l)
        print l
    }
}
