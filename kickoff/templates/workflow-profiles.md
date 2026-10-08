# Task Workflow

Written at kickoff. Step definitions resolve from `_workflow/steps/` here first, then from the
global `project-tasks/_workflow/steps/`, so a step only needs a file here when this project does
it differently.

## Steps

1. context - Orient: epic, docs, prior tasks, code touched; record findings
2. requirements - What, not how: acceptance criteria and the E2E success scenario
3. assessment - Check codebase readiness
4. architecture - Design decisions, written into docs/
5. tests - Tests first; watch each one fail before the code exists
6. implementation - Write the code
7. tech-debt - Create debt tickets for shortcuts
8. reflection - Update docs/ and CLAUDE.md with what was learned
9. draft - Write the doc (docs tasks)
10. review - Check it against the code and the related docs (docs tasks)
11. publish - Regenerate the indexes and check the links (docs tasks)

## Profiles

Stamp only the profile's steps into a new task, renumbered 10, 20, 30…

- `type: docs` → context → requirements → assessment → draft → review → publish → reflection
- any other type → context → requirements → assessment → architecture → tests → implementation → tech-debt → reflection
