# settled.awk — every settled answer as `ID TAB value`, one line per value (a multi-select gives several).
{ load() }
END { for (i = 1; i <= nq; i++) { id = qid[i]; if (settled(id) == "") continue; for (k = 1; k <= ansn[id]; k++) printf "%s\t%s\n", id, ansv[id, k] } }
