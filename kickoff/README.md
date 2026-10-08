# kickoff

Start every project with the same questionnaire. The questions are always the same; the answers
may or may not be.

- **Branching.** The next question depends on the earlier answers: a library is not asked about
  login, and a demo is asked whether it has a gate.
- **Pre-defined options.** You pick an answer instead of typing one, so the question can't be read
  two ways and the answer can't be misread.
- **Defaults.** The likely answer is offered first, and a whole section can be accepted in one go.
  Some defaults follow earlier answers: a client's project keeps its tasks outside the repo.
- **Answers in files, not in chat.** They are recorded in `.kickoff-answers`, and
  `docs/project/charter.md` is generated from them. The charter holds an overview, the goal, scope,
  non-goals, a numbered decisions table with the reason for each, and the open questions.

## Use

Ask Claude to *kick off this project* (or *start a new project*). The skill walks the questionnaire
one section at a time, shows a review screen, then writes the charter.

The scripts can also be run directly:

```bash
bash kickoff/scripts/plan.sh  [project] [--next | --review]   # what to ask now, with defaults
bash kickoff/scripts/answer.sh --root <project> [--add|--clear] <ID> "<value>"
bash kickoff/scripts/charter.sh [project] [--force | --stdout]
bash kickoff/scripts/ports.sh next | allocate <name> | set <name> <port> | release <name> | list [--all]
```

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
