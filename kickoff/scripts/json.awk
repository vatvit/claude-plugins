# json.awk — a JSON string literal for kickoff's writers. Loaded with -f before the program.
#
# A character loop on purpose: gsub replacement strings treat backslashes differently in busybox
# awk than in gawk and BSD awk, so gsub(/\\/, "\\\\") doubles a backslash on two of the three and
# drops it on the third.
function json_q(s,   out, i, c) {
    out = ""
    for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "\\" || c == "\"") out = out "\\"
        out = out c
    }
    return "\"" out "\""
}
