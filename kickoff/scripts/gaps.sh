#!/usr/bin/env bash
# gaps.sh [project-root] — what the settled answers say the project has, and it does not.
#
# Prints `ID TAB answer TAB gap TAB evidence` for each gap a file can show, and writes nothing.
# It is the mechanical half of closing the gaps: the skill adds what only reading the code can
# tell, shows one table, and for each gap the user picks do it now, make it a task, or leave it.
# Once a gap is closed it is no longer printed, so a second run on a closed project prints nothing.
#
# The answers are matched by the start of their option text, as conditions are; no option is
# spelled out in full here. Reads files only, like inspect.sh.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

root="$(project_root "${1:-}")"
gap() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }   # gap <ID> <answer> <what is missing> <where it looked>
# found <find tests...> — 0 when a file of the project matches; dependency folders and .git skipped
found() {
    [ -n "$(find "$root" \( -name .git -o -name node_modules -o -name vendor -o -name .venv \) -prune -o \( "$@" \) -print 2>/dev/null | head -1)" ]
}
any() { local f; for f in "$@"; do [ -e "$root/$f" ] && return 0; done; return 1; }
# setup_files — where a tool is set up: manifests and config at the root (not prose: a README
# naming a tool does not set it up, nor do kickoff's own files), scripts/ and .github/
setup_files() {
    find "$root" -maxdepth 1 -type f ! -name '*.md' ! -name .kickoff-answers -print
    find "$root/scripts" "$root/.github" -type f -print 2>/dev/null
    return 0
}
set_up() { # set_up <tool> — 0 when a setup file names it
    local f
    while IFS= read -r f; do grep -qiF -- "$1" "$f" 2>/dev/null && return 0; done <<EOF3
$(setup_files)
EOF3
    return 1
}

answers="$(kickoff_awk settled.awk "$root")"
[ -n "$answers" ] || exit 0

while IFS= read -r row; do
    id="${row%%	*}"; v="${row#*	}"
    case "$id:$v" in
        R4:"One script"*)
            any scripts/dev.sh || gap R4 "$v" "no scripts/dev.sh" "scripts/" ;;
        R4:"A task runner"*)
            any Makefile GNUmakefile justfile Taskfile.yml || gap R4 "$v" "no task runner file" "Makefile, justfile, Taskfile.yml" ;;
        I0:"In containers"*)
            any compose.yml compose.yaml docker-compose.yml docker-compose.yaml Dockerfile docker/compose.yml docker/compose.yaml \
                || gap I0 "$v" "no compose file or Dockerfile" "the project root, docker/" ;;
        R6:"Markdown task files"*)
            any .task-config.json || grep -qsF "\"$root\":" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/project-tasks/config.json" "$HOME/.claude/project-tasks/config.json" \
                || gap R6 "$v" "no task setup" ".task-config.json, the task registry" ;;
        F2:Unit*)
            found -type d \( -name test -o -name tests -o -name spec -o -name __tests__ \) -o -type f \( -name '*_test.*' -o -name '*.test.*' -o -name '*.spec.*' -o -name 'test_*' \) \
                || gap F2 "$v" "no tests" "test/, tests/, spec/, *_test.*, *.test.*, *.spec.*, test_*" ;;
        F2:"E2E success path"*)
            found \( -iname '*e2e*' -o -iname '*playwright*' -o -iname '*cypress*' \) \
                || gap F2 "$v" "no E2E test" "names with e2e, playwright, cypress" ;;
        F13:Yes*)
            # the viewer's command, as kickoff's instructions name it (e2e-view where `:` cannot be used)
            set_up e2e:view || set_up e2e-view \
                || gap F13 "$v" "no E2E viewer command" "e2e:view or e2e-view in manifests and config at the root, scripts/, .github/" ;;
        F7:"Pre-commit"*)
            any .pre-commit-config.yaml .husky lefthook.yml .git/hooks/pre-commit || gap F7 "$v" "no pre-commit hook" ".pre-commit-config.yaml, .husky/, lefthook.yml, .git/hooks/" ;;
        F7:CI*)
            any .github/workflows .gitlab-ci.yml Jenkinsfile azure-pipelines.yml bitbucket-pipelines.yml .circleci \
                || gap F7 "$v" "no CI configuration" ".github/workflows/, .gitlab-ci.yml, Jenkinsfile …" ;;
        F12:*)
            # each tool named should appear in a manifest, a config file, a script or CI
            printf '%s\n' "$v" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]].*$//' | while IFS= read -r t; do
                [ -n "$t" ] || continue
                set_up "$t" \
                    || gap F12 "$v" "$t is not set up" "manifests and config at the root, scripts/, .github/"
            done ;;
        F1:*)
            any docs/project/quality.md || gap F1 "$v" "no quality doc" "docs/project/quality.md" ;;
    esac
done <<EOF2
$answers
EOF2

# not tied to one answer: the ID column is "-"
any CLAUDE.md || gap - "scaffold.sh writes it" "no CLAUDE.md" "the project root"
case " $(installed_plugins "$root") " in
    *" docs-manager "*) any docs/_index.md || gap - "docs-manager installed" "docs/ is not set up" "docs/_index.md" ;;
esac
exit 0
