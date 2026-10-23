#!/usr/bin/env bash
# inspect.sh [project-root] — infer answers from what the project already holds (questionnaire A0):
# git, task setup, manifests, compose, deploy and locale files.
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
# hint <ID> <option prefix or value> <evidence>. The first hint for an ID wins, so the
# stronger evidence is hinted first.
hint() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$raw"; }
# json_str <file> <key> — the first "key": "string" in a JSON file; empty when absent.
json_str() { grep -o "\"$2\"[ \t]*:[ \t]*\"[^\"]*\"" "$1" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/' || true; }
# toml_str <file> <key> — the first `key = "string"` in a TOML file; empty when absent.
toml_str() { awk -v k="$2" '$0 ~ "^" k "[ \t]*=[ \t]*\"" { sub(/^[^"]*"/, ""); sub(/".*/, ""); print; exit }' "$1" 2>/dev/null || true; }
# mentions <file> <word...> — the words that appear quoted in <file> (a dependency list), comma-joined.
mentions() { local f="$1" w out=""; shift; for w in "$@"; do grep -qF "\"$w" "$f" 2>/dev/null && out="$out${out:+, }${w%/}"; done; printf '%s' "$out"; }

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

# --- tasks (R6 tracking, R7 where, R8 prefix) -------------------------------------------------
if [ -f "$root/.task-config.json" ]; then
    td="$(json_str "$root/.task-config.json" tasksDir)"
    px="$(json_str "$root/.task-config.json" prefix)"
    hint R6 "Markdown task files" ".task-config.json exists"
    case "$td" in /*|~*) hint R7 "Outside the repo" ".task-config.json: tasksDir $td" ;; ?*) hint R7 "In the repo" ".task-config.json: tasksDir $td" ;; esac
    [ -z "$px" ] || hint R8 "$px" ".task-config.json: prefix"
else
    for reg in "${CLAUDE_CONFIG_DIR:-}/project-tasks/config.json" "$HOME/.claude/project-tasks/config.json"; do
        [ -f "$reg" ] && grep -qF "\"$root\":" "$reg" || continue
        px="$(awk -v r="\"$root\":" 'index($0, r) { o = 1 } o && /"prefix"/ { sub(/.*"prefix"[ \t]*:[ \t]*"/, ""); sub(/".*/, ""); print; exit }' "$reg")"
        hint R6 "Markdown task files" "the task registry lists this project"
        hint R7 "Outside the repo" "the task registry lists this project"
        [ -z "$px" ] || hint R8 "$px" "the task registry: prefix"
        break
    done
fi
[ -f "$root/.task-roadmap.json" ] || [ -f "$root/tasks/roadmap.html" ] && hint R11 "Yes" "a task roadmap exists"
[ -f "$root/.crew.json" ] && hint R5 "Yes" ".crew.json exists"

# --- commit messages, from the reflog: git writes each commit's subject there (R2) ------------
if [ -f "$G/logs/HEAD" ]; then
    read -r nc ncc < <(awk -F'\t' '$1 ~ / [0-9]+ [-+][0-9]+$/ && $2 ~ /^commit[^:]*: / {
            m = $2; sub(/^commit[^:]*: /, "", m); n++
            if (m ~ /^(feat|fix|docs|chore|refactor|test|tests|style|perf|build|ci|revert)(\([^)]*\))?!?: /) c++ }
        END { print n + 0, c + 0 }' "$G/logs/HEAD")
    if [ "$nc" -ge 5 ]; then
        ev="$ncc of the $nc commits in .git/logs/HEAD are Conventional Commits"
        if [ $((ncc * 5)) -ge $((nc * 4)) ]; then hint R2 "Conventional Commits" "$ev"
        elif [ $((ncc * 5)) -le "$nc" ]; then hint R2 "Free form" "$ev"; fi
    fi
fi

# --- what the manifests say: the one-liner, the kind, the stack, the tools (A2, A3, I4, F12) ----
# A stack is what the project is written in, so it is read from the manifests, never guessed from
# file extensions. Each manifest adds `language — frameworks it depends on`; several are joined.
stack="" stackev="" tools="" toolsev=""
add_stack() { stack="$stack${stack:+ + }$1${2:+ — $2}"; stackev="$stackev${stackev:+, }$3"; }
add_tools() { [ -z "$1" ] || { tools="$tools${tools:+, }$1"; toolsev="$toolsev${toolsev:+, }$2"; }; }
M="$root/package.json"
if [ -f "$M" ]; then
    d="$(json_str "$M" description)"; [ -z "$d" ] || hint A2 "$d" "package.json: description"
    grep -q '"bin"[ \t]*:' "$M" && hint A3 "Library / plugin / tool" "package.json declares a bin (a command-line tool)"
    lang="JavaScript / Node.js"; [ -f "$root/tsconfig.json" ] && lang="TypeScript / Node.js"
    add_stack "$lang" "$(mentions "$M" next nuxt react vue svelte @angular/core express fastify @nestjs/core)" package.json
    add_tools "$(mentions "$M" jest vitest mocha @playwright/test cypress eslint prettier @biomejs/biome)" package.json
fi
M="$root/composer.json"
if [ -f "$M" ]; then
    d="$(json_str "$M" description)"; [ -z "$d" ] || hint A2 "$d" "composer.json: description"
    [ "$(json_str "$M" type)" = library ] && hint A3 "Library / plugin / tool" 'composer.json: "type": "library"'
    add_stack PHP "$(mentions "$M" laravel/framework symfony/ slim/slim)" composer.json
    add_tools "$(mentions "$M" phpunit/ pestphp/ phpstan/ vimeo/psalm friendsofphp/php-cs-fixer)" composer.json
fi
M="$root/pyproject.toml"
if [ -f "$M" ]; then
    d="$(toml_str "$M" description)"; [ -z "$d" ] || hint A2 "$d" "pyproject.toml: description"
fi
for M in "$root/pyproject.toml" "$root/requirements.txt" "$root/setup.py"; do
    [ -f "$M" ] || continue
    fw="$(for w in django flask fastapi; do grep -qiE "(^|[\"' ])$w([<>=~! \"'\[]|\$)" "$M" && printf '%s, ' "$w"; done; true)"
    tl="$(for w in pytest ruff black mypy flake8; do grep -qiE "(^|[\"' ])$w([<>=~! \"'\[]|\$)" "$M" && printf '%s, ' "$w"; done; true)"
    add_stack Python "${fw%, }" "${M#"$root"/}"; add_tools "${tl%, }" "${M#"$root"/}"
    break
done
M="$root/Cargo.toml"
if [ -f "$M" ]; then
    d="$(toml_str "$M" description)"; [ -z "$d" ] || hint A2 "$d" "Cargo.toml: description"
    grep -q '^\[lib\]' "$M" && ! grep -q '^\[\[bin\]\]' "$M" && [ ! -f "$root/src/main.rs" ] \
        && hint A3 "Library / plugin / tool" "Cargo.toml has a [lib] and no binary"
    add_stack Rust "$(for w in actix-web axum rocket; do grep -q "^$w[ \t]*=" "$M" && printf '%s ' "$w"; done | sed 's/ $//; s/ /, /g')" Cargo.toml
fi
[ -f "$root/go.mod" ] && add_stack Go "$(for w in gin-gonic/gin labstack/echo gofiber/fiber; do grep -qF "$w" "$root/go.mod" && printf '%s ' "${w#*/}"; done | sed 's/ $//; s/ /, /g')" go.mod
[ -f "$root/Gemfile" ] && add_stack Ruby "$(grep -qE "^[ \t]*gem ['\"]rails['\"]" "$root/Gemfile" && echo rails)" Gemfile
[ -f "$root/Gemfile" ] && add_tools "$(for w in rspec rubocop; do grep -qE "gem ['\"]$w" "$root/Gemfile" && printf '%s ' "$w"; done | sed 's/ $//; s/ /, /g')" Gemfile
for M in pom.xml build.gradle build.gradle.kts; do
    [ -f "$root/$M" ] || continue
    add_stack "Java / JVM" "$(grep -q spring-boot "$root/$M" && echo spring-boot)" "$M"; break
done
[ -f "$root/.golangci.yml" ] && add_tools golangci-lint .golangci.yml
if [ -d "$root/.claude-plugin" ]; then hint A3 "Library / plugin / tool" ".claude-plugin/ (a Claude Code plugin)"; fi
[ -z "$stack" ] || hint I4 "$stack" "$stackev"
[ -z "$tools" ] || hint F12 "$tools" "$toolsev"

# --- languages of the content: two or more locales in a translations folder (D3) --------------
for d in locales locale i18n lang translations src/locales src/i18n app/locales public/locales config/locales; do
    [ -d "$root/$d" ] || continue
    n="$(ls -A "$root/$d" | wc -l | tr -d ' ')"
    [ "$n" -ge 2 ] && { hint D3 "Several" "$d/ has $n entries: $(ls -A "$root/$d" | head -5 | tr '\n' ' ' | sed 's/ $//')"; break; }
done

# --- where it is deployed (I1, I2) ------------------------------------------------------------
for f in serverless.yml serverless.yaml; do [ -f "$root/$f" ] && hint I2 "Serverless / managed" "$f exists"; done
for f in fly.toml vercel.json netlify.toml render.yaml Procfile serverless.yml serverless.yaml Chart.yaml; do
    [ -f "$root/$f" ] && { hint I1 "A cloud" "$f exists"; break; }
done
ls "$root"/*.tf "$root"/terraform/*.tf "$root"/infra/*.tf >/dev/null 2>&1 && hint I1 "A cloud" "Terraform files exist"

# --- commands and infra (R4, I0, I2, I3, I5, I6, I7) ------------------------------------------
if [ -f "$root/scripts/dev.sh" ]; then hint R4 "One script" "scripts/dev.sh exists"
elif [ -f "$root/dev.sh" ]; then hint R4 '`./dev.sh`' "dev.sh exists at the root"
elif [ -f "$root/Makefile" ]; then hint R4 "A task runner" "a Makefile exists"
elif [ -f "$root/justfile" ] || [ -f "$root/Taskfile.yml" ]; then hint R4 "A task runner" "a justfile or Taskfile.yml exists"
elif grep -q '"scripts"[ \t]*:' "$root/package.json" 2>/dev/null; then hint R4 "The stack's own tool" "package.json: scripts"; fi
compose="$(ls "$root"/compose*.y*ml "$root"/docker-compose*.y*ml "$root"/docker/compose*.y*ml 2>/dev/null | head -1 || true)"
if [ -n "$compose" ]; then
    # The state the services keep, from their images: a database, and what sits beside it.
    engines="$(awk '/^services:/ { s = 1; next } s && /^[^ \t#]/ { s = 0 }
        s && /^    image:[ \t]*/ { i = $0; sub(/^    image:[ \t]*/, "", i); gsub(/["\047]/, "", i); n = i; sub(/:.*/, "", n); sub(/.*\//, "", n)
            if (n ~ /^(postgres|postgis|mysql|mariadb|mongo|mssql|clickhouse|cassandra|neo4j|elasticsearch|opensearch|couchdb)/) printf "db\t%s\n", i
            else if (n ~ /^(redis|valkey|memcached|rabbitmq|kafka|nats|minio)/) printf "other\t%s\n", i }' "$compose")"
    if [ -n "$engines" ]; then
        ndb="$(printf '%s\n' "$engines" | grep -c '^db' || true)"; nother="$(printf '%s\n' "$engines" | grep -c '^other' || true)"
        list="$(printf '%s\n' "$engines" | cut -f2 | tr '\n' ',' | sed 's/,$//; s/,/, /g')"
        if [ "$ndb" -gt 0 ] && [ "$nother" -gt 0 ]; then hint I3 "Several stores" "${compose#"$root"/}: $list"
        elif [ "$ndb" -gt 0 ]; then hint I3 "A database" "${compose#"$root"/}: $list"; fi
        hint I5 "$list" "${compose#"$root"/}: the images"
    fi
    grep -qi nvidia "$compose" && hint I7 "GPUs" "${compose#"$root"/} asks for an nvidia device"
    # Services that start by default; ones behind `profiles:` (test runners, tools) are not the app.
    read -r n np < <(awk '
        /^services:/ { s = 1; next } s && /^[^ \t#]/ { s = 0 }
        s && /^  [A-Za-z0-9_.-]+:[ \t]*$/ { cur = $1; svc[cur] = 1 }
        s && cur != "" && /^    profiles:/ { prof[cur] = 1 }
        END { for (k in svc) { t++; if (k in prof) p++ } print t - p, p + 0 }' "$compose")
    ev="${compose#"$root"/}: $n service(s) by default"; [ "$np" = 0 ] || ev="$ev, $np behind profiles"
    if [ "$n" = 1 ]; then hint I2 "One deployable" "$ev"; elif [ "$n" -gt 1 ]; then hint I2 "A few services" "$ev"; fi
    hint I0 "In containers" "$ev"
    port="$(KICKOFF_PROJECTS_DIR="$(dirname "$compose")" bash "$KICKOFF_SCRIPTS/ports.sh" list --all | awk -F'\t' -v f="$compose" '$1 == f { print $2; exit }')"
    [ -z "$port" ] || hint I6 "$port" "the first port $(basename "$compose") publishes"
fi

for d in migrations db/migrate prisma alembic; do
    [ -d "$root/$d" ] && { hint I3 "A database" "$d/ exists"; break; }
done

kickoff_awk infer.awk "$root" -v raw="$raw"
rm -f "$raw"
