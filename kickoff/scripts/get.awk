# get.awk — print the settled answer of each id in -v ids="A1 R6 …", one per line (empty if none).
{ load() }
END { n = split(ids, w, " "); for (i = 1; i <= n; i++) print settled(w[i]) }
