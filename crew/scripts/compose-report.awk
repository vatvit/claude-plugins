# compose-report.awk — PLUG-068, Docker option D. Reads the normalized YAML that
# `docker compose config --no-interpolate` prints and names, once, what stops the project from
# running twice side by side (one copy per worktree, each its own compose project by folder name):
# a fixed project name, container_name, a fixed tag on a built image, host ports, mounts outside the
# project, external volumes. Prints nothing when there is nothing to say. Read-only by design: crew
# never writes, wraps or rewrites a project's Docker setup.
#   awk -v proj=<the name compose derives from the folder> -v root=<the folder, absolute> -f compose-report.awk
# Values naming COMPOSE_PROJECT_NAME differ per copy already, so they are not traps.

function key(s) { sub(/^- /, "", s); sub(/:.*/, "", s); return s }
function val(s) {
    sub(/^- /, "", s); sub(/^[^:]*:[ ]*/, "", s)
    if (s ~ /^".*"$/ || s ~ /^'.*'$/) s = substr(s, 2, length(s) - 2)
    return s
}
function say(s) { out = out "  - " s "\n"; n++ }
function perproj(s) { return index(s, "COMPOSE_PROJECT_NAME") > 0 }
function image_trap() {
    if (build && image != "" && !perproj(image)) say(svc ": builds image " image " — every copy builds over the same tag")
}
function short_port(s,    a, m) { # "127.0.0.1:8080:80" / "8080:80/tcp" / "80" — the host side, or ""
    sub(/^- /, "", s); gsub(/["']/, "", s)
    m = split(s, a, ":")
    return m >= 2 ? a[m - 1] : ""
}

/^[ ]*$/ || /^[ ]*#/ { next }
{
    ind = match($0, /[^ ]/) - 1; t = substr($0, ind + 1)
    if (ind == 0) {
        top = key(t)
        if (top == "name" && val(t) != proj) say("name: " val(t) " — a fixed project name, so every copy is the same project")
        next
    }
    if (top == "services") {
        if (ind == 2) { svc = key(t); sect = ""; build = 0; image = ""; next }
        if (ind == 4) {
            sect = key(t)
            if (sect == "build") { build = 1; image_trap() }
            else if (sect == "image") { image = val(t); image_trap() }
            else if (sect == "container_name" && !perproj(val(t))) say(svc ": container_name " val(t) " — one container name for every copy")
            next
        }
        if (sect == "ports") {
            if (key(t) == "published") say(svc ": host port " val(t) " — two copies cannot both publish it")
            else if (ind == 6 && t !~ /^- [A-Za-z_]+:/) { p = short_port(t); if (p != "") say(svc ": host port " p " — two copies cannot both publish it") }
        } else if (sect == "volumes") {
            if (key(t) == "type") vtype = val(t)
            else if (key(t) == "source" && vtype == "bind" && index(val(t) "/", root "/") != 1)
                say(svc ": mounts " val(t) ", outside the project — every copy shares it")
        }
    } else if (top == "volumes") {
        if (ind == 2) vol = key(t)
        else if (ind == 4 && key(t) == "external" && val(t) == "true") say("volume " vol ": external — every copy shares it")
    }
}
END {
    if (!n) exit
    printf "crew: this compose setup cannot run twice side by side (one copy per worktree):\n%s", out
    print "Run Docker from the main tree only, or make those values differ per copy. crew does not change your compose files."
}
