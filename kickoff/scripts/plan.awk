# plan.awk — which questions to ask now. Run through kickoff_awk with -v mode=all|next|review.
#
#   all     every question:   section TAB id TAB state TAB value TAB question TAB options
#           value is the answer when answered or stale, else the resolved default
#   next    the same rows, only the first section that still has ask / judge questions
#   review  a markdown table of every answer, for the review screen before files are written

{ load() }

function row(i,   v) {
    v = (ans[qid[i]] != "") ? ans[qid[i]] : default_of(i)
    printf "%s\t%s\t%s\t%s\t%s\t%s\n", qsec[i], qid[i], state_of(i), v, qtext[i], clean_options(qopts[i])
}

END {
    for (id in udef) if (!(id in qidx)) printf "kickoff: your defaults name %s, which is not a question; ignored\n", id > "/dev/stderr"
    if (mode == "next") {
        sec = ""
        for (i = 1; i <= nq; i++) { s = state_of(i); if (to_ask(s)) { sec = qsec[i]; break } }
        for (i = 1; i <= nq; i++) if (qsec[i] == sec) { s = state_of(i); if (to_ask(s)) row(i) }
    } else if (mode == "review") {
        print "| ID | Question | Answer |"
        print "|----|----------|--------|"
        for (i = 1; i <= nq; i++) {
            s = state_of(i); if (s != "answered" && s != "stale") continue
            v = joined(qid[i], "; ")
            gsub(/\|/, "\\|", v)
            printf "| %s | %s | %s%s |\n", qid[i], qtext[i], v, (s == "stale" ? " *(no longer applies)*" : "")
        }
    } else for (i = 1; i <= nq; i++) row(i)
}
