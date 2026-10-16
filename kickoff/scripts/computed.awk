# computed.awk — print the computed option (*italics*) that ENVIRON["KO_VALUE"] is for question
# ENVIRON["KO_ID"], or nothing. answer.sh refuses such a value: it describes how to work the answer out.
{ load() }
END { i = qidx[ENVIRON["KO_ID"]]; if (i) print computed_of(i, ENVIRON["KO_VALUE"]) }
