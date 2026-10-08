# defaults-write.awk — the user layer as JSON from sorted ID TAB value lines. Used by defaults.sh.
BEGIN { FS = "\t"; print "{" }
{ line[NR] = "  \"" $1 "\": " json_q($2) }
END { for (i = 1; i <= NR; i++) print line[i] (i < NR ? "," : ""); print "}" }
