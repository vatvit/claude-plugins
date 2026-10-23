# kickoff

Start every project with the same questionnaire. Kickoff collects what is known about the project
and makes its starting decisions with you. The questions are always the same; the answers may or
may not be. It is generic: it names no language, stack, vendor or tool. Those come from your
answers, and Claude proposes the options that depend on them.

- **Branching.** The next question depends on the earlier answers: a library is not asked about
  login, and a demo is asked whether it has a gate.
- **Pre-defined options.** You pick an answer instead of typing one, so the question can't be read
  two ways and the answer can't be misread.
- **Defaults.** The likely answer is offered first, and a whole section can be accepted in one go.
  Some defaults follow earlier answers: a client's project keeps its tasks outside the repo. A
  question is asked only after the ones it depends on. A question with a real trade-off (the
  quality level, when backward compatibility starts to apply) is never accepted in one go: it is
  asked on its own, the recommendation first, and you pick.
- **Quality as a level, then the difference.** One question sets the level (None, Basic,
  Standard, Full), which decides the generic checks for each aspect: tests, code checks,
  non-functional, test strength, automation, plus domain checks Claude proposes. Each aspect then
  asks only what to DROP or ADD. The tools for the stack are named last, in one table.
- **Only the plugins you have.** Questions about crew, task and task-roadmap are asked only when
  that plugin is installed.
- **Answers in files, not in chat.** They are recorded in `.kickoff-answers`, and
  `docs/project/charter.md` and `docs/project/quality.md` are generated from them. The charter holds
  an overview, the goal, scope, non-goals, a numbered decisions table with the reason for each, and
  the open questions.

## Use

Ask Claude to *kick off this project* (or *start a new project*). The skill walks the questionnaire
one section at a time, shows a review screen, then writes the charter.

The scripts can also be run directly:

```bash
bash kickoff/scripts/plan.sh  [project] [--next | --review]   # what to ask now, with defaults
bash kickoff/scripts/answer.sh --root <project> [--add|--clear] <ID> "<value>"
bash kickoff/scripts/charter.sh [project] [--force | --stdout]
bash kickoff/scripts/scaffold.sh [project] [--diff | --force]   # CLAUDE.md, quality doc, task config
bash kickoff/scripts/inspect.sh [project]                     # existing project: proposed answers + evidence
bash kickoff/scripts/gaps.sh [project]                        # existing project: what the answers say is missing
bash kickoff/scripts/ports.sh next | allocate <name> | set <name> <port> | release <name> | list [--all]
bash kickoff/scripts/defaults.sh list | set <ID> <value> | unset <ID>   # your own defaults
```

## Setup

After the charter, `scaffold.sh` sets the project up from the answers. It writes a small CLAUDE.md
that holds only this project's instructions (git, identity, how development runs, entry point, crew,
tasks, backward compatibility, the quality level and what a red check stops, approved services, and
how this project differs from how you usually work), `docs/project/quality.md`, and, when you chose
markdown task files, the task config and workflow. The workflow carries the practices you keep:
INVEST when a task is shaped, tests first, SOLID and DRY at architecture and implementation. The
layout of the rest of `docs/` is docs-manager's. In your own project the tasks are in the repo. In
a client's they are kept outside it, in the
task skill's registry, so the client's repo carries neither your tasks nor your home path.
Seeded files are never overwritten; a hand-edited CLAUDE.md is refused rather than replaced.

## An existing project

kickoff also works on a project that already has code or a partial setup (`/kickoff:kickoff init`).
`inspect.sh` reads what is there (the git remote, branches and commit style, the task config, the
manifests' description, stack and test tools, the compose services, stores and ports, deploy and locale
files, the entry point) and Claude reads the README, `docs/` and the code for the rest. Every proposal
comes with its evidence; nothing is recorded until you confirm, and the charter marks the answers that
were recovered from the project.

Then kickoff **closes the gaps**: `gaps.sh` lists what the answers say the project has and it does
not (the entry point, containers, tests, E2E, CI, a tool, the quality doc, `docs/`), Claude adds what
only the code shows, and for each one you pick *do it now* (done and shown working), *make it a task*,
or *leave it*. With docs-manager installed, the docs are onboarded first.
A project kicked off before is asked nothing and changed in nothing. A file edited since is shown as a
diff (`--diff`) and replaced only when you agree (`--force`).

## Your defaults

The ★ defaults come from the questionnaire. Your own defaults win over them. They are kept per Claude
account in `${CLAUDE_CONFIG_DIR:-~/.claude}/kickoff.json`, so a work account can default to *my
employer's project* and a personal one to *mine*. Where your file says nothing, the questionnaire's
defaults apply, including the ones that follow earlier answers.

## Dev ports

`ports.sh` keeps one registry per machine, at `~/.claude/kickoff/ports.json`. It deliberately ignores
`CLAUDE_CONFIG_DIR`: every Claude account on the Mac shares one Docker, so they must share one list.
A port counts as taken when it is in the registry *or* published in any compose file under
`~/projects` (`KICKOFF_PROJECTS_DIR`). Allocation starts at 3030 (`KICKOFF_PORT_BASE`) and is safe to
run from parallel sessions.

## The questionnaire

[`skills/kickoff/references/questionnaire.md`](skills/kickoff/references/questionnaire.md) is
the single source of the questions. The skill reads it and the scripts parse its tables. To change
a question, an option, a default or a condition, edit that file, keeping to its §Reading the tables.

## Requirements

None: bash 3.2+ and awk (BSD, GNU or busybox). It works without the other plugins.
