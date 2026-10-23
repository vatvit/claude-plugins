#!/usr/bin/env bash
# Tests for existing-project mode: inspect.sh's inferences, and that a project already kicked off
# is neither asked nor changed. No git binary: .git is built by hand, as inspect.sh only reads it.
#
#   bash kickoff/scripts/test/existing.test.sh
#   docker run --rm -v "$PWD":/w -w /w bash:5 bash kickoff/scripts/test/existing.test.sh
set -uo pipefail
. "$(dirname "$0")/helpers.sh"

export HOME="$TMP/home"; mkdir -p "$HOME"; unset CLAUDE_CONFIG_DIR
inspect() { bash "$S/inspect.sh" "$P"; }
inferred() { inspect | awk -F'\t' -v id="$1" '$2 != "" && $1 == id { print $2 }'; }
exists() { [ -e "$1" ] && echo yes || echo no; }

echo "== what an empty or bare directory says =="
P=$(fresh empty)
check "1a an empty directory is a new repo" "New, empty repo" "$(inferred A0)"
check "1b the name is the directory" "empty" "$(inferred A1)"
check "1c no .git, no remote inference" "" "$(inferred A5)"
P=$(fresh code); echo 'print(1)' > "$P/main.py"
check "1d files but no setup" "Existing code, no setup" "$(inferred A0)"

echo "== a set-up project =="
P=$(fresh full)
mkdir -p "$P/.git/refs/heads" "$P/docs/architecture" "$P/docs/external" "$P/scripts"
printf '[core]\n\tbare = false\n[remote "origin"]\n\turl = git@example.com:acme/full.git\n\tfetch = +refs/heads/*:refs/remotes/origin/*\n' > "$P/.git/config"
: > "$P/.git/refs/heads/develop"
printf '{\n  "tasksDir": "tasks",\n  "prefix": "FUL",\n  "nextId": 4\n}\n' > "$P/.task-config.json"
echo '#!/usr/bin/env bash' > "$P/scripts/dev.sh"; echo '# x' > "$P/CLAUDE.md"
printf 'services:\n  app:\n    ports:\n      - "3041:3000"\n  e2e:\n    profiles: [e2e]\n    image: x\nvolumes:\n  data:\n' > "$P/compose.yaml"
check "2a partly set up, with what was found" "yes" "$(has $'A0\tExisting, partly set up\tfound: CLAUDE.md docs .task-config.json' "$(inspect)")"
check "2b the remote from .git/config" "git@example.com:acme/full.git" "$(inferred A5)"
check "2c a develop branch means GitFlow, in the questionnaire's words" "GitFlow" "$(inferred R1)"
check "2d task files found" "Markdown task files (task plugin)" "$(inferred R6)"
check "2e tasks in the repo, full option text" 'In the repo, `tasks/`' "$(inferred R7)"
check "2f the prefix" "FUL" "$(inferred R8)"
check "2g the entry point" 'One script, `scripts/dev.sh` (up, down, test, sh)' "$(inferred R4)"
check "2h services behind profiles do not count" "One deployable" "$(inferred I2)"
check "2i the dev port" "3041" "$(inferred I6)"
check "2j a compose file means development in containers" "yes" "$(has 'In containers' "$(inferred I0)")"
check "2k every proposal carries its evidence" "0" "$(inspect | awk -F'\t' '$3 == ""' | wc -l | tr -d ' ')"
check "2l inspecting writes nothing" "no" "$(exists "$P/.kickoff-answers")"
bash "$S/answer.sh" --root "$P" R8 OTHER
check "2m an answer wins: answered questions are not proposed" "" "$(inferred R8)"

echo "== tasks outside the repo =="
P=$(fresh outside); mkdir -p "$HOME/.claude/project-tasks"
printf '{\n  "projects": {\n    "%s": {\n      "tasksDir": "/t",\n      "prefix": "OUT",\n      "nextId": 1\n    }\n  }\n}\n' "$P" > "$HOME/.claude/project-tasks/config.json"
check "3a found in the task registry" "Outside the repo" "$(inferred R7)"
check "3b its prefix" "OUT" "$(inferred R8)"

echo "== a project kicked off before: nothing asked, nothing changed =="
P=$(fresh done)
autofill "$P" A1=done A4=Mine A5="No remote yet" R8=DON D3=English K2=English I6=n/a C4=n/a C5="Never — always free to break" F1="Basic"
bash "$S/charter.sh" "$P" >/dev/null; bash "$S/scaffold.sh" "$P" >/dev/null
before=$(cd "$P" && find . -type f | sort | while read -r f; do echo "$f $(cksum < "$f")"; done)
check "4a nothing left to ask" "" "$(bash "$S/plan.sh" "$P" --next)"
check "4b the charter is unchanged" "unchanged" "$(bash "$S/charter.sh" "$P")"
out=$(bash "$S/scaffold.sh" "$P")
check "4c the scaffold creates or updates nothing" "no" "$(echo "$out" | grep -qE '^(created|updated)' && echo yes || echo no)"
after=$(cd "$P" && find . -type f | sort | while read -r f; do echo "$f $(cksum < "$f")"; done)
check "4d no file changed" "$before" "$after"

echo "== an edited file is shown, not overwritten =="
echo "my rule" >> "$P/CLAUDE.md"; echo "my decision" >> "$P/docs/project/charter.md"
out=$(bash "$S/scaffold.sh" "$P" --diff)
check "5a --diff shows the change to CLAUDE.md" "yes" "$(has '-my rule' "$out")"
check "5b --diff reports it as differs" "yes" "$(has 'differs   CLAUDE.md' "$out")"
check "5c --diff wrote nothing" "my rule" "$(tail -1 "$P/CLAUDE.md")"
bash "$S/scaffold.sh" "$P" >/dev/null; check "5d without --force it is refused" "3" "$?"
check "5e --force replaces it once approved" "no" "$(bash "$S/scaffold.sh" "$P" --force >/dev/null; has 'my rule' "$(cat "$P/CLAUDE.md")")"
out=$(bash "$S/charter.sh" "$P" --diff)
check "5f charter --diff shows the hand edit" "yes" "$(has '-my decision' "$out")"
check "5g ... and writes nothing" "my decision" "$(tail -1 "$P/docs/project/charter.md")"
P2=$(fresh fresh2); bash "$S/answer.sh" --root "$P2" A1 x
check "5h charter --diff on a new project" "would-create docs/project/charter.md" "$(bash "$S/charter.sh" "$P2" --diff)"

echo "== a legacy project: manifests, compose, deploy, locales, the commit log =="
# legacy <dir> — a project grown without kickoff. Fake data only.
legacy() {
    local P="$1" i
    mkdir -p "$P/.git/logs" "$P/locales/en" "$P/locales/de" "$P/src" "$P/migrations"   # migrations: a second I3 hint
    printf '[core]\n\tbare = false\n' > "$P/.git/config"
    for i in 1 2 3 4 5; do
        printf '%040d %040d Dev <dev@example.com> 170000000%s +0000\tcommit: feat(cart): step %s\n' 0 "$i" "$i" "$i" >> "$P/.git/logs/HEAD"
    done
    printf '%040d %040d Dev <dev@example.com> 1700000009 +0000\tcommit: wip\n' 0 9 >> "$P/.git/logs/HEAD"
    cat > "$P/package.json" <<'JSON'
{
  "name": "shop",
  "description": "A small shop for second-hand bikes",
  "private": true,
  "scripts": { "dev": "next dev", "test": "jest" },
  "dependencies": { "next": "14.0.0", "react": "18.2.0" },
  "devDependencies": { "jest": "29.0.0", "eslint": "8.0.0", "typescript": "5.0.0" }
}
JSON
    echo '{}' > "$P/tsconfig.json"
    printf 'services:\n  app:\n    build: .\n    ports:\n      - "3077:3000"\n  db:\n    image: postgres:16\n  cache:\n    image: "redis:7"\n  worker:\n    image: x\n    runtime: nvidia\n' > "$P/compose.yaml"
    echo 'app = "shop"' > "$P/fly.toml"
    echo 'export default {}' > "$P/src/index.ts"
}
P=$(fresh legacy); legacy "$P"
check "6a the one-liner from the manifest" "A small shop for second-hand bikes" "$(inferred A2)"
check "6b the stack from the manifests" "TypeScript / Node.js — next, react" "$(inferred I4)"
check "6c the tools from the manifests" "jest, eslint" "$(inferred F12)"
check "6d a database beside a cache, in the questionnaire's words" "yes" "$(has 'Several stores' "$(inferred I3)")"
check "6e the engines from the images" "postgres:16, redis:7" "$(inferred I5)"
check "6f an nvidia device means GPUs" "yes" "$(has 'GPUs' "$(inferred I7)")"
check "6g a deploy file means a cloud" "A cloud" "$(inferred I1)"
check "6h two locales mean several languages" "yes" "$(has 'Several' "$(inferred D3)")"
check "6i 5 of 6 commits conventional" "yes" "$(has 'Conventional Commits' "$(inferred R2)")"
check "6j package.json scripts mean the stack's own tool" "yes" "$(has "The stack's own tool" "$(inferred R4)")"
check "6k every proposal carries its evidence" "0" "$(inspect | awk -F'\t' '$3 == ""' | wc -l | tr -d ' ')"
check "6l one proposal per question" "0" "$(inspect | cut -f1 | sort | uniq -d | wc -l | tr -d ' ')"
check "6m 16 questions proposed on this project (6 before PLUG-072)" "16" "$(inspect | wc -l | tr -d ' ')"
check "6n inspecting writes nothing" "no" "$(exists "$P/.kickoff-answers")"

P=$(fresh pylib); mkdir -p "$P/migrations"
printf '[project]\nname = "geo"\ndescription = "Geocoding helpers"\ndependencies = ["fastapi>=0.1"]\n[project.optional-dependencies]\ndev = ["pytest", "ruff"]\n' > "$P/pyproject.toml"
printf '{\n  "name": "acme/geo",\n  "type": "library"\n}\n' > "$P/composer.json"
check "6o pyproject: the one-liner" "Geocoding helpers" "$(inferred A2)"
check "6p a library manifest proposes the kind" "yes" "$(has 'Library' "$(inferred A3)")"
check "6q two manifests, two stacks" "PHP + Python — fastapi" "$(inferred I4)"
check "6r a migrations folder means a database" "yes" "$(has 'A database' "$(inferred I3)")"

echo "== confirming proposals: recorded with their evidence, only the rest is asked =="
P=$(fresh confirm); legacy "$P"
proposed="$(inspect | cut -f1 | sort)"
while IFS= read -r row; do
    id="$(echo "$row" | cut -f1)"
    bash "$S/answer.sh" --root "$P" "$id" "$(echo "$row" | cut -f2)"
    bash "$S/answer.sh" --root "$P" "$id.from" "$(echo "$row" | cut -f3)"
done <<< "$(inspect)"
check "7a nothing proposed is asked again" "" "$(bash "$S/plan.sh" "$P" --next | cut -f2 | sort | comm -12 - <(echo "$proposed"))"
check "7b the evidence is kept with the answer" "package.json: description" "$(sed -n 's/^A2\.from: //p' "$P/.kickoff-answers")"
check "7c nothing left to propose" "" "$(inspect)"
autofill "$P" A4=Mine A5="No remote yet" R8=SHP K2=English I6=n/a C4=n/a C5="Never — always free to break" F1="Basic" >/dev/null
bash "$S/charter.sh" "$P" >/dev/null; ch="$(cat "$P/docs/project/charter.md")"
check "7d the charter marks the one-liner recovered" "yes" "$(has 'A small shop for second-hand bikes *(recovered from package.json: description)*' "$ch")"
check "7e ... and a recovered decision, in its Why column" "yes" "$(echo "$ch" | grep -F 'TypeScript / Node.js' | grep -qF 'recovered from package.json' && echo yes || echo no)"
check "7f ... and says what the mark means" "yes" "$(has 'Marked recovered' "$ch")"
check "7g a decision taken at kickoff is not marked" "no" "$(echo "$ch" | grep -F 'Quality level' | grep -qF recovered && echo yes || echo no)"

echo "== closing the gaps =="
P=$(fresh gaps); legacy "$P"
for a in "A1=shop" "A3=Product / app / service" 'R4=One script, `scripts/dev.sh` (up, down, test, sh)' \
         "I0=In containers — nothing installed on the machine but the container runtime" \
         "I4=TypeScript / Node.js — next, react" "F1=Basic — unit tests, E2E success path, formatter and linter, one command runs them"; do
    bash "$S/answer.sh" --root "$P" "${a%%=*}" "${a#*=}"
done
bash "$S/answer.sh" --root "$P" F2 "Unit"; bash "$S/answer.sh" --root "$P" --add F2 "E2E success path"
bash "$S/answer.sh" --root "$P" F7 "CI on push and merge request"; bash "$S/answer.sh" --root "$P" F12 "jest, eslint, vitest"
before=$(cd "$P" && find . -type f | sort | while read -r f; do echo "$f $(cksum < "$f")"; done)
g="$(bash "$S/gaps.sh" "$P")"
gapof() { echo "$g" | awk -F'\t' -v id="$1" '$1 == id { print $3 }' | paste -sd'|' -; }
check "8a the entry point the answer names" "no scripts/dev.sh" "$(gapof R4)"
check "8b no tests, no E2E" "no tests|no E2E test" "$(gapof F2)"
check "8c no CI" "no CI configuration" "$(gapof F7)"
check "8d a tool named but not set up; one set up is not a gap" "vitest is not set up" "$(gapof F12)"
check "8e no quality doc, no CLAUDE.md, no docs/" "no quality doc|no CLAUDE.md|docs/ is not set up" "$(gapof F1)|$(gapof -)"
check "8f in containers: compose is there, no gap" "" "$(gapof I0)"
check "8g every gap says where it looked" "0" "$(echo "$g" | awk -F'\t' '$4 == ""' | wc -l | tr -d ' ')"
after=$(cd "$P" && find . -type f | sort | while read -r f; do echo "$f $(cksum < "$f")"; done)
check "8h gaps.sh writes nothing" "$before" "$after"
# close them, as Claude would after the user said "do it now"
mkdir -p "$P/scripts" "$P/tests" "$P/e2e" "$P/.github/workflows" "$P/docs/project"
echo '#!/usr/bin/env bash' > "$P/scripts/dev.sh"; echo 'test("x", () => {})' > "$P/tests/cart.test.ts"
echo 'test("home", () => {})' > "$P/e2e/home.spec.ts"; printf 'on: push\njobs: {}\n' > "$P/.github/workflows/ci.yml"
echo 'export default { test: {} } // vitest' > "$P/vitest.config.ts"
echo '# shop' > "$P/CLAUDE.md"; echo '# quality' > "$P/docs/project/quality.md"; echo '# docs' > "$P/docs/_index.md"
check "8i closed gaps are not reported again" "" "$(bash "$S/gaps.sh" "$P")"
P=$(fresh nodocsmgr); legacy "$P"; bash "$S/answer.sh" --root "$P" A1 x
check "8j without docs-manager, docs/ is not kickoff's gap" "no" "$(KICKOFF_PLUGINS="" bash "$S/gaps.sh" "$P" | grep -q 'docs/' && echo yes || echo no)"

summary
