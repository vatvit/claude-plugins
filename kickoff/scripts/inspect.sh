#!/usr/bin/env bash
# inspect.sh [project-root] — infer answers from what the project already holds (questionnaire A0).
#
# Prints `ID TAB value TAB evidence` for each unanswered question it has evidence for, and
# writes nothing. Each inference is a proposal: the skill shows it with its evidence, and only a
# confirmed one is recorded with answer.sh. The value is resolved to the questionnaire's own option
# text (infer.awk), so no option wording lives here, only the hint that picks one.
#
# Reads files only. No git binary is needed, which keeps it working in a bare container.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

root="$(project_root "${1:-}")"
raw="$(mktemp)"
hint() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$raw"; }   # hint <ID> <option prefix or value> <evidence>

# --- what is there at all (A0, A1) ------------------------------------------------------------
setup=""
for f in CLAUDE.md docs .task-config.json .kickoff-answers; do [ -e "$root/$f" ] && setup="$setup $f"; done
content="$(ls -A "$root" 2>/dev/null | grep -v -e '^\.git$' -e '^\.kickoff-answers$' | head -1 || true)"
if [ -n "$setup" ]; then hint A0 "Existing, partly set up" "found:$setup"
elif [ -n "$content" ]; then hint A0 "Existing code, no setup" "the directory has files but no CLAUDE.md, docs/ or task config"
else hint A0 "New, empty repo" "the directory is empty"; fi
hint A1 "$(basename "$root")" "the directory name"

# --- git, from .git itself (A5, R1) -----------------------------------------------------------
G="$root/.git"
if [ -f "$G/config" ]; then
    url="$(awk '/^\[remote "origin"\]/ { o = 1; next } /^\[/ { o = 0 } o && /^[ \t]*url[ \t]*=/ { sub(/^[^=]*=[ \t]*/, ""); print; exit }' "$G/config")"
    if [ -n "$url" ]; then hint A5 "$url" "origin in .git/config"; else hint A5 "No remote yet" ".git/config has no origin"; fi
    if [ -f "$G/refs/heads/develop" ] || grep -q ' refs/heads/develop$' "$G/packed-refs" 2>/dev/null; then
        hint R1 "GitFlow" "a develop branch exists"
    fi
fi

# --- tasks (R6, R7) ---------------------------------------------------------------------------
if [ -f "$root/.task-config.json" ]; then
    td="$(grep -o '"tasksDir"[ \t]*:[ \t]*"[^"]*"' "$root/.task-config.json" | sed 's/.*"\([^"]*\)"$/\1/' || true)"
    px="$(grep -o '"prefix"[ \t]*:[ \t]*"[^"]*"' "$root/.task-config.json" | sed 's/.*"\([^"]*\)"$/\1/' || true)"
    case "$td" in /*|~*) hint R6 "Outside the repo" ".task-config.json: tasksDir $td" ;; ?*) hint R6 "In the repo" ".task-config.json: tasksDir $td" ;; esac
    [ -z "$px" ] || hint R7 "$px" ".task-config.json: prefix"
else
    for reg in "${CLAUDE_CONFIG_DIR:-}/project-tasks/config.json" "$HOME/.claude/project-tasks/config.json"; do
        [ -f "$reg" ] && grep -qF "\"$root\":" "$reg" || continue
        px="$(awk -v r="\"$root\":" 'index($0, r) { o = 1 } o && /"prefix"/ { sub(/.*"prefix"[ \t]*:[ \t]*"/, ""); sub(/".*/, ""); print; exit }' "$reg")"
        hint R6 "Outside the repo" "the task registry lists this project"
        [ -z "$px" ] || hint R7 "$px" "the task registry: prefix"
        break
    done
fi
[ -f "$root/.task-roadmap.json" ] || [ -f "$root/tasks/roadmap.html" ] && hint R9 "Yes" "a task roadmap exists"
[ -f "$root/.crew.json" ] && hint R5 "Yes" ".crew.json exists"

# --- commands and infra (R4, I2, I5) ----------------------------------------------------------
if [ -f "$root/scripts/dev.sh" ]; then hint R4 '`scripts/dev.sh`' "scripts/dev.sh exists"
elif [ -f "$root/dev.sh" ]; then hint R4 '`./dev.sh`' "dev.sh exists at the root"
elif [ -f "$root/Makefile" ]; then hint R4 '`make`' "a Makefile exists"; fi
compose="$(ls "$root"/compose*.y*ml "$root"/docker-compose*.y*ml "$root"/docker/compose*.y*ml 2>/dev/null | head -1 || true)"
if [ -n "$compose" ]; then
    # Services that start by default; ones behind `profiles:` (test runners, tools) are not the app.
    read -r n np < <(awk '
        /^services:/ { s = 1; next } s && /^[^ \t#]/ { s = 0 }
        s && /^  [A-Za-z0-9_.-]+:[ \t]*$/ { cur = $1; svc[cur] = 1 }
        s && cur != "" && /^    profiles:/ { prof[cur] = 1 }
        END { for (k in svc) { t++; if (k in prof) p++ } print t - p, p + 0 }' "$compose")
    ev="${compose#"$root"/}: $n service(s) by default"; [ "$np" = 0 ] || ev="$ev, $np behind profiles"
    if [ "$n" = 1 ]; then hint I2 "One container" "$ev"; elif [ "$n" -gt 1 ]; then hint I2 "A few services" "$ev"; fi
    [ -f "$root/scripts/dev.sh" ] || [ -f "$root/dev.sh" ] || [ -f "$root/Makefile" ] || hint R4 '`docker compose`' "$ev, no wrapper script"
    port="$(KICKOFF_PROJECTS_DIR="$(dirname "$compose")" bash "$KICKOFF_SCRIPTS/ports.sh" list --all | awk -F'\t' -v f="$compose" '$1 == f { print $2; exit }')"
    [ -z "$port" ] || hint I5 "$port" "the first port $(basename "$compose") publishes"
fi

# --- docs (K1, C3) ----------------------------------------------------------------------------
if [ -d "$root/docs" ]; then
    if [ -d "$root/docs/architecture" ] || [ -d "$root/docs/dev" ]; then hint K1 '`project/`' "docs/ has more than project/"
    else hint K1 "Minimal" "docs/ has project/ only"; fi
    [ -d "$root/docs/external" ] && hint C3 "Client documents" "docs/external/ exists"
fi

kickoff_awk infer.awk "$root" -v raw="$raw"
rm -f "$raw"
