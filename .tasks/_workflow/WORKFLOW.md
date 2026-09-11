# Task Workflow

1. requirements - EARS specifications if needed
2. assessment - Check codebase readiness
3. poc - Prototype risky unknowns (requires approval)
4. domain-lens - DDD constraints/notes
5. architecture - Design decisions
6. tests - Test specifications (project-dependent)
7. subtasks - Break into sub-tickets
8. implementation - Write the code
9. tech-debt - Create debt tickets for shortcuts
10. reflection - Update CLAUDE.md and project docs with lessons learned

Skip steps that don't apply. Each step is a decision point.

## Project notes

`bdd` is intentionally absent. This repo is pure bash + awk Claude Code plugins
with no Cucumber/Gherkin infrastructure; behavioural coverage lives in each task's
acceptance criteria and is implemented at the `tests` step as plain bash test
scripts. Do not re-add the step without introducing the infrastructure first.

Step detail files resolve from `.tasks/_workflow/steps/` first, then fall back to
`~/.claude/project-tasks/_workflow/steps/` — the global definitions are the source
of truth and are deliberately not copied here.
