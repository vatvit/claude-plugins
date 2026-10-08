# registry-insert.awk — add a project to the task skill's registry (<global>/config.json), keeping
# every other project. Used by scaffold.sh with KO_ROOT, KO_DIR and KO_PREFIX in the environment.
# Exits 3, writing nothing usable, when the file has no "projects" object to insert into.
BEGIN {
    e = "    " json_q(ENVIRON["KO_ROOT"]) ": {\n      \"tasksDir\": " json_q(ENVIRON["KO_DIR"]) ",\n      \"prefix\": " json_q(ENVIRON["KO_PREFIX"]) ",\n      \"nextId\": 1\n    }"
}
{ line[++n] = $0 }
END {
    if (n == 0) { print "{\n  \"projects\": {\n" e "\n  }\n}"; exit }
    for (i = 1; i <= n; i++) {
        print line[i]
        if (!done && line[i] ~ /"projects"[ \t]*:[ \t]*\{[ \t]*$/) { print e ((line[i + 1] ~ /^[ \t]*\}/) ? "" : ","); done = 1 }
    }
    if (!done) exit 3
}
