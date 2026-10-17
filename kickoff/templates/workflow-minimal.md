# Task Workflow

Written at kickoff: one minimal profile. Step definitions resolve from `_workflow/steps/` here
first, then from the global `project-tasks/_workflow/steps/`.

1. context - Orient: docs, prior tasks, code touched; record findings. INVEST: a task of more than one behaviour is split into vertical slices first
2. tests - Tests first; watch each one fail before the code exists
3. implementation - Write the code. SOLID; DRY: refactor duplication now, or file a task for it
4. reflection - Update docs/ and CLAUDE.md with what was learned
