# Task Workflow

1. context - Orient: epic, docs, prior tasks, code touched; record findings
2. requirements - EARS specifications if needed
3. assessment - Check codebase readiness
4. poc - Prototype risky unknowns (requires approval)
5. domain-lens - DDD constraints/notes
6. architecture - Design decisions
7. tests - Test specifications (project-dependent)
8. subtasks - Break into sub-tickets
9. implementation - Write the code
10. tech-debt - Create debt tickets for shortcuts
11. reflection - Update CLAUDE.md and project docs with lessons learned

Skip steps that don't apply. Each step is a decision point.

## Project notes

`bdd` is intentionally absent. This repo is pure bash + awk Claude Code plugins
with no Cucumber/Gherkin infrastructure; behavioural coverage lives in each task's
acceptance criteria and is implemented at the `tests` step as plain bash test
scripts. Do not re-add the step without introducing the infrastructure first.

`context` is a global step, not a local addition — see the global `WORKFLOW.md` for why
it is not a duplicate of `assessment`, and `steps/context.md` for how to run it. The only
project-specific note: this repo's docs are the plugin `README.md`/`CLAUDE.md` files rather
than a `docs/` tree, so orienting means reading the affected plugin's `CLAUDE.md` first —
it records which behaviours must not regress and why.

Step detail files resolve from `.tasks/_workflow/steps/` first, then fall back to
`~/.claude/project-tasks/_workflow/steps/` — the global definitions are the source
of truth and are deliberately not copied here.
